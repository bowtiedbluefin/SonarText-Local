import Foundation

actor JobQueue {
    static let shared = JobQueue()
    
    private let databaseManager = DatabaseManager.shared
    private let transcriptionClient = TranscriptionClient()
    private let morpheusClient = MorpheusClient()
    
    private var isProcessing = false
    private var activeTask: Task<Void, Never>?
    
    private let maxRetries = 3
    private let baseRetryDelay: TimeInterval = 5
    
    private init() {}
    
    func configure(
        transcriptionBaseURL: String,
        transcriptionApiKey: String?,
        morpheusBaseURL: String,
        morpheusApiKey: String
    ) async throws {
        print("JobQueue: Configuring transcription client with URL: \(transcriptionBaseURL)")
        try await transcriptionClient.configure(baseURL: transcriptionBaseURL, apiKey: transcriptionApiKey)
        if !morpheusApiKey.isEmpty {
            try await morpheusClient.configure(baseURL: morpheusBaseURL, apiKey: morpheusApiKey)
        }
        print("JobQueue: Configuration complete")
    }
    
    func enqueueTranscription(for recordingId: UUID) async throws {
        print("JobQueue: Enqueuing transcription for recording \(recordingId)")
        let job = Job(type: .transcribe, recordingId: recordingId)
        try await databaseManager.insert(job)
        print("JobQueue: Job inserted, starting processing")
        await startProcessingIfNeeded()
    }
    
    func enqueueAnalysis(for recordingId: UUID, mode: AnalysisMode = .meeting) async throws {
        let job = Job(type: .analyze, recordingId: recordingId, analysisMode: mode)
        try await databaseManager.insert(job)
        await startProcessingIfNeeded()
    }
    
    func cancelJob(id: UUID) async throws {
        guard var job = try await fetchJob(id: id) else { return }
        job.state = .canceled
        job.updatedAt = Date()
        try await databaseManager.update(job)
    }
    
    func retryJob(id: UUID) async throws {
        guard var job = try await fetchJob(id: id) else { return }
        job.state = .queued
        job.attemptCount = 0
        job.lastError = nil
        job.updatedAt = Date()
        try await databaseManager.update(job)
        await startProcessingIfNeeded()
    }
    
    private func fetchJob(id: UUID) async throws -> Job? {
        let jobs = try await databaseManager.fetchAll(Job.self)
        return jobs.first { $0.id == id }
    }
    
    private func startProcessingIfNeeded() async {
        guard !isProcessing else {
            print("JobQueue: Already processing, skipping")
            return
        }
        isProcessing = true
        print("JobQueue: Starting job processing")
        
        activeTask = Task {
            await processJobs()
        }
    }
    
    private func processJobs() async {
        print("JobQueue: processJobs started")
        while true {
            do {
                let pendingJobs = try await databaseManager.fetchPendingJobs()
                print("JobQueue: Found \(pendingJobs.count) pending jobs")
                
                guard let job = pendingJobs.first(where: { $0.state == .queued }) else {
                    print("JobQueue: No queued jobs found, stopping")
                    isProcessing = false
                    return
                }
                
                print("JobQueue: Processing job \(job.id) of type \(job.type)")
                await processJob(job)
                
            } catch {
                print("JobQueue: Error fetching jobs: \(error)")
                isProcessing = false
                return
            }
            
            if Task.isCancelled {
                print("JobQueue: Task cancelled")
                isProcessing = false
                return
            }
        }
    }
    
    private func processJob(_ job: Job) async {
        var mutableJob = job
        mutableJob.state = .running
        mutableJob.attemptCount += 1
        mutableJob.updatedAt = Date()
        
        do {
            try await databaseManager.update(mutableJob)
        } catch {
            return
        }
        
        do {
            switch job.type {
            case .transcribe:
                try await processTranscription(job: &mutableJob)
            case .analyze:
                try await processAnalysis(job: &mutableJob)
            }
            
            mutableJob.state = .succeeded
            mutableJob.lastError = nil
            mutableJob.updatedAt = Date()
            try await databaseManager.update(mutableJob)
            
        } catch {
            print("JobQueue: Job failed with error: \(error)")
            mutableJob.lastError = error.localizedDescription
            mutableJob.updatedAt = Date()
            
            if mutableJob.attemptCount < maxRetries && (error as? NetworkError)?.isRetryable == true {
                mutableJob.state = .queued
                let delay = baseRetryDelay * pow(2.0, Double(mutableJob.attemptCount - 1))
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            } else {
                mutableJob.state = .failed
                await updateRecordingStatus(recordingId: mutableJob.recordingId, status: .failed, error: error.localizedDescription)
            }
            
            try? await databaseManager.update(mutableJob)
        }
    }
    
    private func processTranscription(job: inout Job) async throws {
        print("JobQueue: processTranscription started for job \(job.id)")
        guard let recording = try await databaseManager.fetch(id: job.recordingId, type: Recording.self) else {
            print("JobQueue: Recording not found for id \(job.recordingId)")
            throw JobError.recordingNotFound
        }
        
        print("JobQueue: Found recording: \(recording.title)")
        await updateRecordingStatus(recordingId: job.recordingId, status: .transcribing, error: nil)
        
        let audioPath: String
        if let merged = recording.mergedFilePath {
            audioPath = merged
            print("JobQueue: Using merged file")
        } else if let system = recording.systemFilePath {
            audioPath = system
            print("JobQueue: Using system file")
        } else if let mic = recording.micFilePath {
            audioPath = mic
            print("JobQueue: Using mic file")
        } else {
            print("JobQueue: No audio file found")
            throw JobError.noAudioFile
        }
        
        let audioURL = URL(fileURLWithPath: audioPath)
        print("JobQueue: Processing transcription for file: \(audioURL.path)")
        
        let jobId: String
        if let existingJobId = job.remoteJobId {
            jobId = existingJobId
            print("Resuming existing job: \(jobId)")
        } else {
            jobId = try await transcriptionClient.submitJob(audioFileURL: audioURL)
            job.remoteJobId = jobId
            try await databaseManager.update(job)
            print("Started new transcription job: \(jobId)")
        }
        
        let result = try await transcriptionClient.pollUntilComplete(jobId: jobId)
        
        let transcriptText = result.text ?? ""
        let jsonData = try JSONEncoder().encode(result)
        let transcript = Transcript(
            recordingId: job.recordingId,
            text: transcriptText,
            jsonBlob: jsonData,
            providerJobId: jobId
        )
        
        try await databaseManager.insert(transcript)
        await updateRecordingStatus(recordingId: job.recordingId, status: .transcribed, error: nil)
        print("Transcription completed and saved")
    }
    
    private func processAnalysis(job: inout Job) async throws {
        print("JobQueue: processAnalysis started")
        guard let recording = try await databaseManager.fetch(id: job.recordingId, type: Recording.self) else {
            print("JobQueue: Recording not found for analysis")
            throw JobError.recordingNotFound
        }
        
        guard let transcript = try await databaseManager.fetchTranscript(forRecordingId: job.recordingId) else {
            print("JobQueue: Transcript not found for analysis")
            throw JobError.noTranscript
        }
        
        print("JobQueue: Sending to Morpheus API, transcript length: \(transcript.text.count)")
        await updateRecordingStatus(recordingId: job.recordingId, status: .analyzing, error: nil)
        
        let mode = job.analysisMode ?? .meeting
        let result = try await morpheusClient.analyze(
            transcript: transcript.text,
            title: recording.title,
            durationSeconds: recording.durationSeconds,
            mode: mode
        )
        
        print("JobQueue: Morpheus analysis received")
        let jsonData = try JSONEncoder().encode(result)
        let analysis = Analysis(recordingId: job.recordingId, jsonBlob: jsonData)
        
        try await databaseManager.insert(analysis)
        await updateRecordingStatus(recordingId: job.recordingId, status: .analyzed, error: nil)
        print("JobQueue: Analysis completed and saved")
    }
    
    private func updateRecordingStatus(recordingId: UUID, status: RecordingStatus, error: String?) async {
        do {
            guard var recording = try await databaseManager.fetch(id: recordingId, type: Recording.self) else { return }
            recording.status = status
            recording.lastError = error
            recording.updatedAt = Date()
            try await databaseManager.update(recording)
        } catch {
        }
    }
}

enum JobError: LocalizedError {
    case recordingNotFound
    case noAudioFile
    case noTranscript
    
    var errorDescription: String? {
        switch self {
        case .recordingNotFound:
            return "Recording not found"
        case .noAudioFile:
            return "No audio file available for transcription"
        case .noTranscript:
            return "No transcript available for analysis"
        }
    }
}
