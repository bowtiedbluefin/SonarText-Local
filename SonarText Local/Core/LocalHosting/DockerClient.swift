import Foundation

struct PullProgress: Sendable {
    let fraction: Double
    let status: String
}

private actor ProgressTracker {
    private var fraction: Double = 0.0
    
    func increment() -> Double {
        fraction = min(fraction + 0.05, 0.9)
        return fraction
    }
}

actor DockerClient {
    static let shared = DockerClient()
    
    private let session: URLSession
    private let dockerAPIBase = "http://localhost:2375"
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300
        self.session = URLSession(configuration: config)
    }
    
    func isDockerRunning() async -> Bool {
        let result = await runDockerCommand(["version", "--format", "{{.Server.Version}}"])
        print("DockerClient: isDockerRunning check - exitCode: \(result.exitCode), stdout: \(result.stdout), stderr: \(result.stderr)")
        return result.exitCode == 0
    }
    
    func getContainerStatus(name: String) async -> String? {
        let result = await runDockerCommand([
            "ps", "-a",
            "--filter", "name=^\(name)$",
            "--format", "{{.Status}}"
        ])
        
        guard result.exitCode == 0, !result.stdout.isEmpty else {
            return nil
        }
        
        let status = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        if status.contains("up") {
            return "running"
        } else if status.contains("exited") {
            return "exited"
        } else if status.contains("created") {
            return "created"
        }
        
        return status.isEmpty ? nil : status
    }
    
    nonisolated func pullImage(_ image: String) -> AsyncStream<PullProgress> {
        AsyncStream { continuation in
            Task { @MainActor in
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/local/bin/docker")
                process.arguments = ["pull", image]
                
                if !FileManager.default.fileExists(atPath: "/usr/local/bin/docker") {
                    if FileManager.default.fileExists(atPath: "/usr/bin/docker") {
                        process.executableURL = URL(fileURLWithPath: "/usr/bin/docker")
                    } else if FileManager.default.fileExists(atPath: "/opt/homebrew/bin/docker") {
                        process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/docker")
                    }
                }
                
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe
                
                let progressActor = ProgressTracker()
                
                pipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                        Task {
                            let newFraction = await progressActor.increment()
                            
                            let status: String
                            if output.contains("Pulling") {
                                status = "Downloading layers..."
                            } else if output.contains("Extracting") {
                                status = "Extracting..."
                            } else if output.contains("Pull complete") {
                                status = "Layer complete"
                            } else {
                                status = "Downloading..."
                            }
                            
                            continuation.yield(PullProgress(fraction: newFraction, status: status))
                        }
                    }
                }
                
                do {
                    try process.run()
                    process.waitUntilExit()
                    
                    pipe.fileHandleForReading.readabilityHandler = nil
                    
                    if process.terminationStatus == 0 {
                        continuation.yield(PullProgress(fraction: 1.0, status: "Complete"))
                    } else {
                        continuation.yield(PullProgress(fraction: 0, status: "Failed"))
                    }
                } catch {
                    continuation.yield(PullProgress(fraction: 0, status: "Error: \(error.localizedDescription)"))
                }
                
                continuation.finish()
            }
        }
    }
    
    func createContainer(
        name: String,
        image: String,
        ports: [String],
        environment: [String: String],
        platform: String
    ) async -> Bool {
        var args = [
            "create",
            "--name", name
        ]
        
        if !platform.isEmpty {
            args.append(contentsOf: ["--platform", platform])
        }
        
        for port in ports {
            args.append(contentsOf: ["-p", port])
        }
        
        for (key, value) in environment {
            args.append(contentsOf: ["-e", "\(key)=\(value)"])
        }
        
        args.append(image)
        
        let result = await runDockerCommand(args)
        if result.exitCode != 0 {
            print("DockerClient: createContainer failed - exitCode: \(result.exitCode), stderr: \(result.stderr)")
        }
        return result.exitCode == 0
    }
    
    func startContainer(name: String) async -> Bool {
        let result = await runDockerCommand(["start", name])
        return result.exitCode == 0
    }
    
    func stopContainer(name: String) async -> Bool {
        let result = await runDockerCommand(["stop", name])
        return result.exitCode == 0
    }
    
    func removeContainer(name: String) async -> Bool {
        let result = await runDockerCommand(["rm", "-f", name])
        return result.exitCode == 0
    }
    
    func getLogs(containerName: String, lines: Int) async -> [String] {
        let result = await runDockerCommand(["logs", "--tail", "\(lines)", containerName])
        
        let allOutput = result.stdout + result.stderr
        return allOutput
            .components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
    }
    
    private func runDockerCommand(_ args: [String]) async -> ProcessResult {
        let process = Process()
        
        // Find Docker executable
        let dockerPaths = [
            "/usr/local/bin/docker",
            "/usr/bin/docker",
            "/opt/homebrew/bin/docker",
            "/Applications/Docker.app/Contents/Resources/bin/docker"
        ]
        
        var dockerPath: String?
        for path in dockerPaths {
            if FileManager.default.fileExists(atPath: path) {
                dockerPath = path
                break
            }
        }
        
        guard let executablePath = dockerPath else {
            return ProcessResult(exitCode: -1, stdout: "", stderr: "Docker not found")
        }
        
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = args
        
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            
            return ProcessResult(
                exitCode: process.terminationStatus,
                stdout: String(data: stdoutData, encoding: .utf8) ?? "",
                stderr: String(data: stderrData, encoding: .utf8) ?? ""
            )
        } catch {
            return ProcessResult(exitCode: -1, stdout: "", stderr: error.localizedDescription)
        }
    }
}

private struct ProcessResult {
    let exitCode: Int32
    let stdout: String
    let stderr: String
}
