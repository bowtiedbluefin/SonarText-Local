import Foundation

struct TranscriptionJobResponse: Sendable {
    let jobId: String?
    let status: String?
    let message: String?
    
    enum CodingKeys: String, CodingKey {
        case jobId = "job_id"
        case status
        case message
    }
}

extension TranscriptionJobResponse: Codable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        jobId = try container.decodeIfPresent(String.self, forKey: .jobId)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        message = try container.decodeIfPresent(String.self, forKey: .message)
    }
    
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(jobId, forKey: .jobId)
        try container.encodeIfPresent(status, forKey: .status)
        try container.encodeIfPresent(message, forKey: .message)
    }
    
    nonisolated static func decode(from data: Data) throws -> TranscriptionJobResponse {
        try JSONDecoder().decode(TranscriptionJobResponse.self, from: data)
    }
}

struct TranscriptionStatusResponse: Sendable {
    let jobId: String
    let status: String
    let progress: String?
    let elapsedTime: Double?
    let result: TranscriptionResultWrapper?
    let error: String?
    
    enum CodingKeys: String, CodingKey {
        case jobId = "job_id"
        case status
        case progress
        case elapsedTime = "elapsed_time"
        case result
        case error
    }
}

extension TranscriptionStatusResponse: Codable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        jobId = try container.decode(String.self, forKey: .jobId)
        status = try container.decode(String.self, forKey: .status)
        progress = try container.decodeIfPresent(String.self, forKey: .progress)
        elapsedTime = try container.decodeIfPresent(Double.self, forKey: .elapsedTime)
        result = try container.decodeIfPresent(TranscriptionResultWrapper.self, forKey: .result)
        error = try container.decodeIfPresent(String.self, forKey: .error)
    }
    
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(jobId, forKey: .jobId)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(progress, forKey: .progress)
        try container.encodeIfPresent(elapsedTime, forKey: .elapsedTime)
        try container.encodeIfPresent(result, forKey: .result)
        try container.encodeIfPresent(error, forKey: .error)
    }
    
    nonisolated static func decode(from data: Data) throws -> TranscriptionStatusResponse {
        try JSONDecoder().decode(TranscriptionStatusResponse.self, from: data)
    }
}

struct TranscriptionResultWrapper: Sendable {
    let status: String?
    let text: String?
    let result: TranscriptionSegmentsContainer?
    let processingInfo: TranscriptionProcessingInfo?
    let jobId: String?
    let processingTime: Double?
    
    enum CodingKeys: String, CodingKey {
        case status, text, result
        case processingInfo = "processing_info"
        case jobId = "job_id"
        case processingTime = "processing_time"
    }
}

extension TranscriptionResultWrapper: Codable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        text = try container.decodeIfPresent(String.self, forKey: .text)
        result = try container.decodeIfPresent(TranscriptionSegmentsContainer.self, forKey: .result)
        processingInfo = try container.decodeIfPresent(TranscriptionProcessingInfo.self, forKey: .processingInfo)
        jobId = try container.decodeIfPresent(String.self, forKey: .jobId)
        processingTime = try container.decodeIfPresent(Double.self, forKey: .processingTime)
    }
    
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(status, forKey: .status)
        try container.encodeIfPresent(text, forKey: .text)
        try container.encodeIfPresent(result, forKey: .result)
        try container.encodeIfPresent(processingInfo, forKey: .processingInfo)
        try container.encodeIfPresent(jobId, forKey: .jobId)
        try container.encodeIfPresent(processingTime, forKey: .processingTime)
    }
}

struct TranscriptionSegmentsContainer: Sendable {
    let segments: [TranscriptionSegment]?
}

extension TranscriptionSegmentsContainer: Codable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        segments = try container.decodeIfPresent([TranscriptionSegment].self, forKey: .segments)
    }
    
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(segments, forKey: .segments)
    }
    
    enum CodingKeys: String, CodingKey {
        case segments
    }
}

struct TranscriptionProcessingInfo: Sendable {
    let device: String?
    let languageDetected: String?
    let audioDuration: Double?
    let totalSpeakers: Int?
    let confidentSpeakers: Int?
    
    enum CodingKeys: String, CodingKey {
        case device
        case languageDetected = "language_detected"
        case audioDuration = "audio_duration"
        case totalSpeakers = "total_speakers"
        case confidentSpeakers = "confident_speakers"
    }
}

extension TranscriptionProcessingInfo: Codable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        device = try container.decodeIfPresent(String.self, forKey: .device)
        languageDetected = try container.decodeIfPresent(String.self, forKey: .languageDetected)
        audioDuration = try container.decodeIfPresent(Double.self, forKey: .audioDuration)
        totalSpeakers = try container.decodeIfPresent(Int.self, forKey: .totalSpeakers)
        confidentSpeakers = try container.decodeIfPresent(Int.self, forKey: .confidentSpeakers)
    }
    
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(device, forKey: .device)
        try container.encodeIfPresent(languageDetected, forKey: .languageDetected)
        try container.encodeIfPresent(audioDuration, forKey: .audioDuration)
        try container.encodeIfPresent(totalSpeakers, forKey: .totalSpeakers)
        try container.encodeIfPresent(confidentSpeakers, forKey: .confidentSpeakers)
    }
}

struct TranscriptionResultResponse: Sendable {
    let text: String?
    let segments: [TranscriptionSegment]?
    let language: String?
}

extension TranscriptionResultResponse: Codable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        text = try container.decodeIfPresent(String.self, forKey: .text)
        segments = try container.decodeIfPresent([TranscriptionSegment].self, forKey: .segments)
        language = try container.decodeIfPresent(String.self, forKey: .language)
    }
    
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(text, forKey: .text)
        try container.encodeIfPresent(segments, forKey: .segments)
        try container.encodeIfPresent(language, forKey: .language)
    }
    
    enum CodingKeys: String, CodingKey {
        case text, segments, language
    }
}

struct TranscriptionSegment: Sendable {
    let start: Double?
    let end: Double?
    let text: String
    let speaker: String?
    let speakerConfidence: Double?
    
    enum CodingKeys: String, CodingKey {
        case start, end, text, speaker
        case speakerConfidence = "speaker_confidence"
    }
}

extension TranscriptionSegment: Codable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        start = try container.decodeIfPresent(Double.self, forKey: .start)
        end = try container.decodeIfPresent(Double.self, forKey: .end)
        text = try container.decode(String.self, forKey: .text)
        speaker = try container.decodeIfPresent(String.self, forKey: .speaker)
        speakerConfidence = try container.decodeIfPresent(Double.self, forKey: .speakerConfidence)
    }
    
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(start, forKey: .start)
        try container.encodeIfPresent(end, forKey: .end)
        try container.encode(text, forKey: .text)
        try container.encodeIfPresent(speaker, forKey: .speaker)
        try container.encodeIfPresent(speakerConfidence, forKey: .speakerConfidence)
    }
}

actor TranscriptionClient {
    private let session: URLSession
    private var baseURL: URL?
    private var apiKey: String?
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    func configure(baseURL: String, apiKey: String?) throws {
        var urlString = baseURL
        if !urlString.hasSuffix("/") {
            urlString += "/"
        }
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL
        }
        self.baseURL = url
        self.apiKey = apiKey
        print("TranscriptionClient configured with baseURL: \(url)")
    }
    
    func submitJob(audioFileURL: URL) async throws -> String {
        guard let baseURL else { throw TranscriptionError.notConfigured }
        
        let url = baseURL.appendingPathComponent("v1/audio/transcriptions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 300
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        if let apiKey, !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        
        let audioData = try Data(contentsOf: audioFileURL)
        var body = Data()
        
        let filename = audioFileURL.lastPathComponent
        let mimeType = filename.hasSuffix(".m4a") ? "audio/mp4" : "audio/mpeg"
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"stored_output\"\r\n\r\n".data(using: .utf8)!)
        body.append("true\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"enable_diarization\"\r\n\r\n".data(using: .utf8)!)
        body.append("true\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n".data(using: .utf8)!)
        body.append("en\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"output_content\"\r\n\r\n".data(using: .utf8)!)
        body.append("both\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"timestamp_granularities\"\r\n\r\n".data(using: .utf8)!)
        body.append("segment\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        print("Submitting transcription job to: \(url)")
        print("Audio file size: \(audioData.count) bytes")
        
        let (data, response) = try await session.data(for: request)
        
        if let responseString = String(data: data, encoding: .utf8) {
            print("Transcription submit response: \(responseString)")
        }
        
        try validateResponse(response, data: data)
        
        let result = try TranscriptionJobResponse.decode(from: data)
        
        guard let jobId = result.jobId else {
            throw TranscriptionError.jobFailed(result.message ?? "No job ID returned")
        }
        
        print("Transcription job submitted with ID: \(jobId)")
        return jobId
    }
    
    func checkStatus(jobId: String) async throws -> TranscriptionStatusResponse {
        guard let baseURL else { throw TranscriptionError.notConfigured }
        
        let url = baseURL.appendingPathComponent("v1/jobs/\(jobId)")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        
        if let apiKey, !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await session.data(for: request)
        
        try validateResponse(response, data: data)
        
        if let responseString = String(data: data, encoding: .utf8) {
            print("Job status raw response: \(responseString.prefix(2000))")
        }
        
        let statusResponse = try TranscriptionStatusResponse.decode(from: data)
        print("Job \(jobId) status: \(statusResponse.status), progress: \(statusResponse.progress ?? "unknown")")
        
        return statusResponse
    }
    
    func pollUntilComplete(jobId: String, maxAttempts: Int = 4320, intervalSeconds: TimeInterval = 5) async throws -> TranscriptionResultResponse {
        print("Polling for job completion: \(jobId)")
        
        for attempt in 0..<maxAttempts {
            let status = try await checkStatus(jobId: jobId)
            
            switch status.status.lowercased() {
            case "completed", "succeeded":
                if let resultWrapper = status.result {
                    print("Job completed successfully")
                    let segments = resultWrapper.result?.segments ?? []
                    print("Segments count: \(segments.count)")
                    if let firstSeg = segments.first {
                        print("First segment - start: \(String(describing: firstSeg.start)), end: \(String(describing: firstSeg.end)), speaker: \(firstSeg.speaker ?? "none"), text: \(firstSeg.text.prefix(50))")
                    }
                    return TranscriptionResultResponse(
                        text: resultWrapper.text,
                        segments: segments,
                        language: resultWrapper.processingInfo?.languageDetected
                    )
                } else {
                    throw TranscriptionError.jobFailed("Job completed but no result returned")
                }
            case "failed", "error":
                throw TranscriptionError.jobFailed(status.error ?? status.progress ?? "Unknown error")
            case "queued", "processing", "running", "pending", "in_progress":
                print("Job still processing (attempt \(attempt + 1)/\(maxAttempts))...")
                try await Task.sleep(nanoseconds: UInt64(intervalSeconds * 1_000_000_000))
            default:
                print("Unknown status: \(status.status), continuing to poll...")
                try await Task.sleep(nanoseconds: UInt64(intervalSeconds * 1_000_000_000))
            }
            
            if Task.isCancelled {
                throw CancellationError()
            }
        }
        
        throw TranscriptionError.timeout
    }
    
    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        print("HTTP Status: \(httpResponse.statusCode)")
        
        switch httpResponse.statusCode {
        case 200..<300:
            return
        case 429:
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After").flatMap { TimeInterval($0) }
            throw NetworkError.rateLimited(retryAfter: retryAfter)
        case 500..<600:
            let body = String(data: data, encoding: .utf8) ?? "No body"
            print("Server error response: \(body)")
            throw NetworkError.serverError(statusCode: httpResponse.statusCode)
        default:
            let body = String(data: data, encoding: .utf8)
            print("HTTP error response: \(body ?? "No body")")
            throw NetworkError.httpError(statusCode: httpResponse.statusCode, body: body)
        }
    }
}

enum TranscriptionError: LocalizedError {
    case notConfigured
    case jobFailed(String)
    case unknownStatus(String)
    case timeout
    
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Transcription service not configured. Go to Settings > API to configure."
        case .jobFailed(let message):
            return "Transcription failed: \(message)"
        case .unknownStatus(let status):
            return "Unknown transcription status: \(status)"
        case .timeout:
            return "Transcription timed out after 6 hours"
        }
    }
}
