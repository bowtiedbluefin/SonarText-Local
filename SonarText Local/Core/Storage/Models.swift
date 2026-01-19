import Foundation
import GRDB

enum RecordingStatus: String, Codable, DatabaseValueConvertible, Sendable {
    case recording
    case recorded
    case transcribing
    case transcribed
    case analyzing
    case analyzed
    case failed
    case incomplete
}

enum RecordingSource: Int, Codable, DatabaseValueConvertible, Sendable {
    case microphone = 1
    case system = 2
    case both = 3
}

struct Recording: Codable, FetchableRecord, PersistableRecord, Identifiable, Hashable, Sendable {
    var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var title: String
    var durationSeconds: Double?
    var sourceFlags: RecordingSource
    var micFilePath: String?
    var systemFilePath: String?
    var mergedFilePath: String?
    var status: RecordingStatus
    var lastError: String?
    var folderId: UUID?
    
    static let databaseTableName = "recordings"
    
    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        title: String? = nil,
        sourceFlags: RecordingSource = .both,
        folderId: UUID? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.title = title ?? Self.defaultTitle(for: createdAt)
        self.durationSeconds = nil
        self.sourceFlags = sourceFlags
        self.micFilePath = nil
        self.systemFilePath = nil
        self.mergedFilePath = nil
        self.status = .recording
        self.lastError = nil
        self.folderId = folderId
    }
    
    private static func defaultTitle(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return "Recording \(formatter.string(from: date))"
    }
}

struct Folder: Codable, FetchableRecord, PersistableRecord, Identifiable, Hashable, Sendable {
    var id: UUID
    var name: String
    var parentId: UUID?
    var createdAt: Date
    var updatedAt: Date
    
    static let databaseTableName = "folders"
    
    init(name: String, parentId: UUID? = nil) {
        self.id = UUID()
        self.name = name
        self.parentId = parentId
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

struct Transcript: Codable, FetchableRecord, PersistableRecord, Identifiable, Sendable {
    var id: UUID
    var recordingId: UUID
    var text: String
    var jsonBlob: Data?
    var providerJobId: String?
    var createdAt: Date
    
    static let databaseTableName = "transcripts"
    
    init(recordingId: UUID, text: String, jsonBlob: Data? = nil, providerJobId: String? = nil) {
        self.id = UUID()
        self.recordingId = recordingId
        self.text = text
        self.jsonBlob = jsonBlob
        self.providerJobId = providerJobId
        self.createdAt = Date()
    }
}

struct Analysis: Codable, FetchableRecord, PersistableRecord, Identifiable, Sendable {
    var id: UUID
    var recordingId: UUID
    var jsonBlob: Data
    var createdAt: Date
    
    static let databaseTableName = "analyses"
    
    init(recordingId: UUID, jsonBlob: Data) {
        self.id = UUID()
        self.recordingId = recordingId
        self.jsonBlob = jsonBlob
        self.createdAt = Date()
    }
}

enum JobType: String, Codable, DatabaseValueConvertible, Sendable {
    case transcribe
    case analyze
}

enum JobState: String, Codable, DatabaseValueConvertible, Sendable {
    case queued
    case running
    case succeeded
    case failed
    case canceled
}

enum AnalysisMode: String, Codable, DatabaseValueConvertible, Sendable {
    case meeting
    case speech
}

struct Job: Codable, FetchableRecord, PersistableRecord, Identifiable, Sendable {
    var id: UUID
    var type: JobType
    var recordingId: UUID
    var state: JobState
    var attemptCount: Int
    var lastError: String?
    var remoteJobId: String?
    var analysisMode: AnalysisMode?
    var createdAt: Date
    var updatedAt: Date
    
    static let databaseTableName = "jobs"
    
    init(type: JobType, recordingId: UUID, analysisMode: AnalysisMode? = nil) {
        self.id = UUID()
        self.type = type
        self.recordingId = recordingId
        self.state = .queued
        self.attemptCount = 0
        self.lastError = nil
        self.remoteJobId = nil
        self.analysisMode = analysisMode
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
