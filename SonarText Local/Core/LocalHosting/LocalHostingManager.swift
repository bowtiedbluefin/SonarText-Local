import Foundation
import Combine

/// Manages the local WhisperX Docker container for transcription
@MainActor
final class LocalHostingManager: ObservableObject {
    static let shared = LocalHostingManager()
    
    // MARK: - Types
    
    enum ContainerState: Equatable {
        case notInstalled
        case stopped
        case starting
        case running
        case stopping
        case downloading(progress: Double, status: String)
        case error(String)
        
        var isOperational: Bool {
            if case .running = self { return true }
            return false
        }
        
        var canStart: Bool {
            if case .stopped = self { return true }
            return false
        }
        
        var canStop: Bool {
            if case .running = self { return true }
            return false
        }
    }
    
    enum WhisperModel: String, CaseIterable, Identifiable {
        case base = "base"
        case small = "small"
        case medium = "medium"
        case largeV3 = "large-v3"
        
        var id: String { rawValue }
        
        var displayName: String {
            switch self {
            case .base: return "Whisper Base"
            case .small: return "Whisper Small"
            case .medium: return "Whisper Medium"
            case .largeV3: return "Whisper Large v3"
            }
        }
        
        var description: String {
            switch self {
            case .base: return "Fastest, ~150MB, basic accuracy"
            case .small: return "Fast, ~500MB, good accuracy"
            case .medium: return "Balanced, ~1.5GB, great accuracy"
            case .largeV3: return "Slowest, ~3GB, best accuracy"
            }
        }
        
        var estimatedSize: String {
            switch self {
            case .base: return "~2GB"
            case .small: return "~3GB"
            case .medium: return "~5GB"
            case .largeV3: return "~8GB"
            }
        }
    }
    
    // MARK: - Constants
    
    static let containerName = "sonartext-whisperx"
    static let port: Int = 17394
    static let internalPort: Int = 9000
    static let dockerImage = "kylecohen01/whisperx-api:latest"
    
    // MARK: - Published State
    
    @Published private(set) var state: ContainerState = .notInstalled
    @Published private(set) var logs: [String] = []
    @Published var selectedModel: WhisperModel = .small
    
    // MARK: - Private
    
    private let dockerClient = DockerClient.shared
    private var healthCheckTask: Task<Void, Never>?
    
    private init() {
        // Load saved model selection
        if let savedModel = UserDefaults.standard.string(forKey: "localServerModel"),
           let model = WhisperModel(rawValue: savedModel) {
            selectedModel = model
        }
    }
    
    // MARK: - Public API
    
    /// Check current container status on launch
    func checkStatus() async {
        guard await dockerClient.isDockerRunning() else {
            let isInstalled = UserDefaults.standard.bool(forKey: "localServerInstalled")
            state = isInstalled ? .error("Docker Desktop is not running") : .notInstalled
            return
        }
        
        if let status = await dockerClient.getContainerStatus(name: Self.containerName) {
            if !UserDefaults.standard.bool(forKey: "localServerInstalled") {
                UserDefaults.standard.set(true, forKey: "localServerInstalled")
                print("LocalHostingManager: Container exists but flag was false - synced UserDefaults")
            }
            
            switch status {
            case "running":
                state = .running
                startHealthCheck()
            case "exited", "created":
                state = .stopped
            default:
                state = .stopped
            }
        } else {
            if UserDefaults.standard.bool(forKey: "localServerInstalled") {
                UserDefaults.standard.set(false, forKey: "localServerInstalled")
                print("LocalHostingManager: Container missing but flag was true - reset UserDefaults")
            }
            state = .notInstalled
        }
    }
    
    /// Download and install the Docker image
    func downloadAndInstall(hfToken: String?) async throws {
        guard await dockerClient.isDockerRunning() else {
            throw LocalHostingError.dockerNotRunning
        }
        
        state = .downloading(progress: 0, status: "Pulling Docker image...")
        
        do {
            var pullSucceeded = false
            for await progress in dockerClient.pullImage(Self.dockerImage) {
                state = .downloading(progress: progress.fraction, status: progress.status)
                if progress.fraction >= 1.0 && progress.status == "Complete" {
                    pullSucceeded = true
                }
            }
            
            if !pullSucceeded {
                throw LocalHostingError.pullFailed
            }
            
            state = .downloading(progress: 0.95, status: "Creating container...")
            
            try await createContainer(hfToken: hfToken)
            
            // Mark as installed
            UserDefaults.standard.set(true, forKey: "localServerInstalled")
            UserDefaults.standard.set(selectedModel.rawValue, forKey: "localServerModel")
            
            state = .stopped
            
            print("LocalHostingManager: Successfully installed local transcription server")
            
        } catch {
            state = .error("Installation failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Start the container
    func start() async throws {
        guard state.canStart || state == .notInstalled else {
            throw LocalHostingError.invalidState
        }
        
        guard await dockerClient.isDockerRunning() else {
            throw LocalHostingError.dockerNotRunning
        }
        
        state = .starting
        
        do {
            let success = await dockerClient.startContainer(name: Self.containerName)
            
            if success {
                // Wait for health check
                var attempts = 0
                while attempts < 60 { // Wait up to 60 seconds
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                    if await healthCheck() {
                        state = .running
                        startHealthCheck()
                        print("LocalHostingManager: Container started and healthy")
                        return
                    }
                    attempts += 1
                }
                
                state = .error("Container started but health check failed")
                throw LocalHostingError.healthCheckFailed
            } else {
                state = .error("Failed to start container")
                throw LocalHostingError.startFailed
            }
        } catch {
            state = .error("Start failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Stop the container
    func stop() async throws {
        guard state.canStop else {
            throw LocalHostingError.invalidState
        }
        
        state = .stopping
        healthCheckTask?.cancel()
        
        let success = await dockerClient.stopContainer(name: Self.containerName)
        
        if success {
            state = .stopped
            print("LocalHostingManager: Container stopped")
        } else {
            state = .error("Failed to stop container")
            throw LocalHostingError.stopFailed
        }
    }
    
    /// Restart the container
    func restart() async throws {
        if state.canStop {
            try await stop()
        }
        try await Task.sleep(nanoseconds: 500_000_000)
        try await start()
    }
    
    /// Remove the container and image
    func remove() async throws {
        healthCheckTask?.cancel()
        
        // Stop if running
        if state.canStop {
            _ = await dockerClient.stopContainer(name: Self.containerName)
        }
        
        // Remove container
        _ = await dockerClient.removeContainer(name: Self.containerName)
        
        // Clear installation flag
        UserDefaults.standard.set(false, forKey: "localServerInstalled")
        UserDefaults.standard.removeObject(forKey: "localServerModel")
        
        state = .notInstalled
        logs = []
        
        print("LocalHostingManager: Container removed")
    }
    
    /// Get container logs
    func fetchLogs(lines: Int = 100) async {
        let newLogs = await dockerClient.getLogs(containerName: Self.containerName, lines: lines)
        logs = newLogs
    }
    
    /// Clear logs
    func clearLogs() {
        logs = []
    }
    
    /// Check if local server is installed
    var isInstalled: Bool {
        UserDefaults.standard.bool(forKey: "localServerInstalled")
    }
    
    /// Get the local server URL
    var serverURL: String {
        "http://localhost:\(Self.port)"
    }
    
    // MARK: - Private Methods
    
    private func createContainer(hfToken: String?) async throws {
        var env: [String: String] = [:]
        
        if let token = hfToken, !token.isEmpty {
            env["HF_TOKEN"] = token
        }
        
        let result = await dockerClient.createContainer(
            name: Self.containerName,
            image: Self.dockerImage,
            ports: ["\(Self.port):\(Self.internalPort)"],
            environment: env,
            platform: ""
        )
        
        if !result.success {
            throw LocalHostingError.createContainerFailedWithMessage(result.error ?? "Unknown error")
        }
    }
    
    private func healthCheck() async -> Bool {
        let url = URL(string: "\(serverURL)/health")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 5
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
            return false
        } catch {
            return false
        }
    }
    
    private func startHealthCheck() {
        healthCheckTask?.cancel()
        healthCheckTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000) // Check every 30 seconds
                
                if Task.isCancelled { break }
                
                let healthy = await healthCheck()
                if !healthy && state == .running {
                    await MainActor.run {
                        state = .error("Server stopped responding")
                    }
                } else if healthy && state != .running {
                    await MainActor.run {
                        state = .running
                    }
                }
            }
        }
    }
}

// MARK: - Errors

enum LocalHostingError: LocalizedError {
    case dockerNotInstalled
    case dockerNotRunning
    case invalidState
    case pullFailed
    case createContainerFailed
    case createContainerFailedWithMessage(String)
    case startFailed
    case stopFailed
    case healthCheckFailed
    case portInUse
    
    var errorDescription: String? {
        switch self {
        case .dockerNotInstalled:
            return "Docker Desktop is not installed. Please install it from docker.com"
        case .dockerNotRunning:
            return "Docker Desktop is not running. Please start Docker Desktop."
        case .invalidState:
            return "Cannot perform this action in the current state"
        case .pullFailed:
            return "Failed to download the Docker image. Check your internet connection and try again."
        case .createContainerFailed:
            return "Failed to create the container"
        case .createContainerFailedWithMessage(let message):
            return "Failed to create container: \(message)"
        case .startFailed:
            return "Failed to start the container"
        case .stopFailed:
            return "Failed to stop the container"
        case .healthCheckFailed:
            return "Container started but is not responding"
        case .portInUse:
            return "Port 17394 is already in use"
        }
    }
}
