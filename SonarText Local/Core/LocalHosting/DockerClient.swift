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
        guard Self.findDockerExecutable() != nil else {
            print("DockerClient: Docker executable not found")
            return false
        }
        
        let result = await runDockerCommand(["version", "--format", "{{.Server.Version}}"])
        print("DockerClient: isDockerRunning check - exitCode: \(result.exitCode), stdout: \(result.stdout), stderr: \(result.stderr)")
        
        if result.exitCode != 0 {
            if result.stderr.contains("Cannot connect to the Docker daemon") {
                print("DockerClient: Docker daemon not running")
            } else if result.stderr.contains("permission denied") {
                print("DockerClient: Docker permission denied")
            }
        }
        
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
            Task.detached {
                let process = Process()
                
                guard let executablePath = await Self.findDockerExecutable() else {
                    continuation.yield(PullProgress(fraction: 0, status: "Docker not found"))
                    continuation.finish()
                    return
                }
                
                process.executableURL = URL(fileURLWithPath: executablePath)
                process.arguments = ["pull", image]
                
                let stdoutPipe = Pipe()
                let stderrPipe = Pipe()
                process.standardOutput = stdoutPipe
                process.standardError = stderrPipe
                
                let progressActor = ProgressTracker()
                
                actor OutputCollector {
                    var stderr = ""
                    
                    func append(_ text: String) {
                        stderr += text
                    }
                    
                    func getStderr() -> String {
                        return stderr
                    }
                }
                
                let stderrCollector = OutputCollector()
                
                stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
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
                            } else if output.contains("Image is up to date") {
                                status = "Already downloaded"
                            } else {
                                status = "Downloading..."
                            }
                            
                            continuation.yield(PullProgress(fraction: newFraction, status: status))
                        }
                    }
                }
                
                stderrPipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                        Task {
                            await stderrCollector.append(output)
                        }
                    }
                }
                
                do {
                    try process.run()
                    
                    let timeoutTask = Task {
                        try await Task.sleep(nanoseconds: 600_000_000_000)
                        if process.isRunning {
                            process.terminate()
                        }
                    }
                    
                    process.waitUntilExit()
                    timeoutTask.cancel()
                    
                    stdoutPipe.fileHandleForReading.readabilityHandler = nil
                    stderrPipe.fileHandleForReading.readabilityHandler = nil
                    
                    if process.terminationStatus == 0 {
                        continuation.yield(PullProgress(fraction: 1.0, status: "Complete"))
                    } else {
                        let stderrContent = await stderrCollector.getStderr()
                        var errorMessage = "Failed"
                        if stderrContent.contains("429") || stderrContent.contains("rate limit") {
                            errorMessage = "Rate limited by Docker Hub. Try again later."
                        } else if stderrContent.contains("no space left") || stderrContent.contains("insufficient space") {
                            errorMessage = "Insufficient disk space"
                        } else if stderrContent.contains("denied") || stderrContent.contains("permission") {
                            errorMessage = "Permission denied - check Docker access"
                        } else if !stderrContent.isEmpty {
                            errorMessage = "Failed: \(stderrContent.prefix(100))"
                        }
                        continuation.yield(PullProgress(fraction: 0, status: errorMessage))
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
    ) async -> (success: Bool, error: String?) {
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
            return (false, result.stderr.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return (true, nil)
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
        
        guard let executablePath = Self.findDockerExecutable() else {
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
    
    nonisolated private static func findDockerExecutable() -> String? {
        let dockerPaths = [
            "/Applications/Docker.app/Contents/Resources/bin/docker",
            "/opt/homebrew/bin/docker",
            "/usr/local/bin/docker",
            "/usr/bin/docker"
        ]
        
        let fileManager = FileManager.default
        for path in dockerPaths {
            var isDirectory: ObjCBool = false
            let exists = fileManager.fileExists(atPath: path, isDirectory: &isDirectory)
            guard exists && !isDirectory.boolValue else { continue }
            
            let resolved = (path as NSString).resolvingSymlinksInPath
            if fileManager.isExecutableFile(atPath: resolved) {
                return path
            }
        }
        return nil
    }
}

private struct ProcessResult {
    let exitCode: Int32
    let stdout: String
    let stderr: String
}
