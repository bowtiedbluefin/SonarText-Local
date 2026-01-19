import Foundation

actor FileStorage {
    static let shared = FileStorage()
    
    private var recordingsDirectory: URL?
    
    private init() {}
    
    func initialize() throws {
        let fileManager = FileManager.default
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw FileStorageError.appSupportNotFound
        }
        let appDirectory = appSupport.appendingPathComponent("AudioRecorder", isDirectory: true)
        let recordingsDir = appDirectory.appendingPathComponent("Recordings", isDirectory: true)
        
        try fileManager.createDirectory(at: recordingsDir, withIntermediateDirectories: true)
        recordingsDirectory = recordingsDir
    }
    
    func recordingDirectory(for recordingId: UUID) throws -> URL {
        guard let recordingsDirectory else { throw FileStorageError.notInitialized }
        
        let dir = recordingsDirectory.appendingPathComponent(recordingId.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    
    func micFilePath(for recordingId: UUID) throws -> URL {
        try recordingDirectory(for: recordingId).appendingPathComponent("mic.m4a")
    }
    
    func systemFilePath(for recordingId: UUID) throws -> URL {
        try recordingDirectory(for: recordingId).appendingPathComponent("system.m4a")
    }
    
    func mergedFilePath(for recordingId: UUID) throws -> URL {
        try recordingDirectory(for: recordingId).appendingPathComponent("merged.m4a")
    }
    
    func transcriptionFilePath(for recordingId: UUID) throws -> URL {
        try recordingDirectory(for: recordingId).appendingPathComponent("transcription.wav")
    }
    
    func deleteRecordingFiles(for recordingId: UUID) throws {
        guard let recordingsDirectory else { throw FileStorageError.notInitialized }
        
        let dir = recordingsDirectory.appendingPathComponent(recordingId.uuidString, isDirectory: true)
        if FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.removeItem(at: dir)
        }
    }
    
    func fileExists(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }
    
    func fileSize(at url: URL) throws -> Int64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return attributes[.size] as? Int64 ?? 0
    }
}

enum FileStorageError: LocalizedError {
    case notInitialized
    case appSupportNotFound
    
    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "File storage not initialized"
        case .appSupportNotFound:
            return "Application Support directory not found"
        }
    }
}
