import Foundation
import GRDB

actor DatabaseManager {
    static let shared = DatabaseManager()
    
    private var dbQueue: DatabaseQueue?
    
    private init() {}
    
    func initialize() throws {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirectory = appSupport.appendingPathComponent("AudioRecorder", isDirectory: true)
        
        try fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true)
        
        let dbPath = appDirectory.appendingPathComponent("recordings.sqlite")
        dbQueue = try DatabaseQueue(path: dbPath.path)
        
        try migrate()
    }
    
    private func migrate() throws {
        guard let dbQueue else { throw DatabaseError.notInitialized }
        
        var migrator = DatabaseMigrator()
        
        migrator.registerMigration("v1") { db in
            try db.create(table: "recordings") { t in
                t.column("id", .text).primaryKey()
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
                t.column("title", .text).notNull()
                t.column("durationSeconds", .double)
                t.column("sourceFlags", .integer).notNull()
                t.column("micFilePath", .text)
                t.column("systemFilePath", .text)
                t.column("mergedFilePath", .text)
                t.column("status", .text).notNull()
                t.column("lastError", .text)
            }
            
            try db.create(table: "transcripts") { t in
                t.column("id", .text).primaryKey()
                t.column("recordingId", .text).notNull().references("recordings", onDelete: .cascade)
                t.column("text", .text).notNull()
                t.column("jsonBlob", .blob)
                t.column("providerJobId", .text)
                t.column("createdAt", .datetime).notNull()
            }
            
            try db.create(table: "analyses") { t in
                t.column("id", .text).primaryKey()
                t.column("recordingId", .text).notNull().references("recordings", onDelete: .cascade)
                t.column("jsonBlob", .blob).notNull()
                t.column("createdAt", .datetime).notNull()
            }
            
            try db.create(table: "jobs") { t in
                t.column("id", .text).primaryKey()
                t.column("type", .text).notNull()
                t.column("recordingId", .text).notNull().references("recordings", onDelete: .cascade)
                t.column("state", .text).notNull()
                t.column("attemptCount", .integer).notNull().defaults(to: 0)
                t.column("lastError", .text)
                t.column("remoteJobId", .text)
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }
        }
        
        migrator.registerMigration("v2_analysis_mode") { db in
            try db.alter(table: "jobs") { t in
                t.add(column: "analysisMode", .text)
            }
            
            try db.alter(table: "recordings") { t in
                t.add(column: "folderId", .text)
            }
        }
        
        migrator.registerMigration("v3_folders") { db in
            try db.create(table: "folders") { t in
                t.column("id", .text).primaryKey()
                t.column("name", .text).notNull()
                t.column("parentId", .text).references("folders", onDelete: .cascade)
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }
        }
        
        try migrator.migrate(dbQueue)
    }
    
    func insert<T: PersistableRecord>(_ record: T) throws {
        guard let dbQueue else { throw DatabaseError.notInitialized }
        try dbQueue.write { db in
            try record.insert(db)
        }
    }
    
    func update<T: PersistableRecord>(_ record: T) throws {
        guard let dbQueue else { throw DatabaseError.notInitialized }
        try dbQueue.write { db in
            try record.update(db)
        }
    }
    
    func delete<T: PersistableRecord>(_ record: T) throws {
        guard let dbQueue else { throw DatabaseError.notInitialized }
        try dbQueue.write { db in
            _ = try record.delete(db)
        }
    }
    
    func fetchAll<T: FetchableRecord & TableRecord>(_ type: T.Type) throws -> [T] {
        guard let dbQueue else { throw DatabaseError.notInitialized }
        return try dbQueue.read { db in
            try T.fetchAll(db)
        }
    }
    
    func fetch<T: FetchableRecord & TableRecord>(id: UUID, type: T.Type) throws -> T? {
        guard let dbQueue else { throw DatabaseError.notInitialized }
        print("DatabaseManager: Fetching \(T.self) with id: \(id.uuidString)")
        return try dbQueue.read { db in
            let result = try T.filter(Column("id") == id).fetchOne(db)
            print("DatabaseManager: Fetch result: \(result != nil ? "found" : "not found")")
            return result
        }
    }
    
    func fetchRecordings() throws -> [Recording] {
        guard let dbQueue else { throw DatabaseError.notInitialized }
        return try dbQueue.read { db in
            try Recording.order(Column("createdAt").desc).fetchAll(db)
        }
    }
    
    func fetchTranscript(forRecordingId recordingId: UUID) throws -> Transcript? {
        guard let dbQueue else { throw DatabaseError.notInitialized }
        print("DatabaseManager: Fetching transcript for recordingId: \(recordingId.uuidString)")
        return try dbQueue.read { db in
            let transcript = try Transcript.filter(Column("recordingId") == recordingId).fetchOne(db)
            print("DatabaseManager: Transcript found: \(transcript != nil)")
            return transcript
        }
    }
    
    func fetchAnalysis(forRecordingId recordingId: UUID) throws -> Analysis? {
        guard let dbQueue else { throw DatabaseError.notInitialized }
        print("DatabaseManager: Fetching analysis for recordingId: \(recordingId.uuidString)")
        return try dbQueue.read { db in
            let analysis = try Analysis.filter(Column("recordingId") == recordingId).fetchOne(db)
            print("DatabaseManager: Analysis found: \(analysis != nil)")
            return analysis
        }
    }
    
    func fetchPendingJobs() throws -> [Job] {
        guard let dbQueue else { throw DatabaseError.notInitialized }
        return try dbQueue.read { db in
            try Job.filter(Column("state") == JobState.queued.rawValue || Column("state") == JobState.running.rawValue)
                .order(Column("createdAt").asc)
                .fetchAll(db)
        }
    }
    
    func fetchJob(forRecordingId recordingId: UUID, type: JobType) throws -> Job? {
        guard let dbQueue else { throw DatabaseError.notInitialized }
        return try dbQueue.read { db in
            try Job.filter(Column("recordingId") == recordingId && Column("type") == type.rawValue)
                .fetchOne(db)
        }
    }
    
    func markIncompleteRecordings() throws {
        guard let dbQueue else { throw DatabaseError.notInitialized }
        try dbQueue.write { db in
            try db.execute(
                sql: "UPDATE recordings SET status = ?, lastError = ? WHERE status = ?",
                arguments: [RecordingStatus.incomplete.rawValue, "Recording interrupted", RecordingStatus.recording.rawValue]
            )
        }
    }
    
    func deleteRecording(_ id: UUID) throws {
        guard let dbQueue else { throw DatabaseError.notInitialized }
        let idString = id.uuidString
        print("DatabaseManager: Deleting recording with id: \(idString)")
        
        try dbQueue.write { db in
            try Job.filter(Column("recordingId") == id).deleteAll(db)
            try Analysis.filter(Column("recordingId") == id).deleteAll(db)
            try Transcript.filter(Column("recordingId") == id).deleteAll(db)
            let deleted = try Recording.filter(Column("id") == id).deleteAll(db)
            print("DatabaseManager: Deleted \(deleted) recording(s)")
        }
    }
}

enum DatabaseError: LocalizedError {
    case notInitialized
    case migrationFailed(Error)
    case queryFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Database not initialized"
        case .migrationFailed(let error):
            return "Database migration failed: \(error.localizedDescription)"
        case .queryFailed(let error):
            return "Database query failed: \(error.localizedDescription)"
        }
    }
}
