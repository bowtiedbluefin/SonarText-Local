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
    
    nonisolated init(jobId: String, status: String, progress: String?, elapsedTime: Double?, result: TranscriptionResultWrapper?, error: String?) {
        self.jobId = jobId
        self.status = status
        self.progress = progress
        self.elapsedTime = elapsedTime
        self.result = result
        self.error = error
    }
    
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
    
    nonisolated init(status: String?, text: String?, result: TranscriptionSegmentsContainer?, processingInfo: TranscriptionProcessingInfo?, jobId: String?, processingTime: Double?) {
        self.status = status
        self.text = text
        self.result = result
        self.processingInfo = processingInfo
        self.jobId = jobId
        self.processingTime = processingTime
    }
    
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
    
    nonisolated init(segments: [TranscriptionSegment]?) {
        self.segments = segments
    }
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
    
    nonisolated init(device: String?, languageDetected: String?, audioDuration: Double?, totalSpeakers: Int?, confidentSpeakers: Int?) {
        self.device = device
        self.languageDetected = languageDetected
        self.audioDuration = audioDuration
        self.totalSpeakers = totalSpeakers
        self.confidentSpeakers = confidentSpeakers
    }
    
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
    
    nonisolated init(start: Double?, end: Double?, text: String, speaker: String?, speakerConfidence: Double?) {
        self.start = start
        self.end = end
        self.text = text
        self.speaker = speaker
        self.speakerConfidence = speakerConfidence
    }
    
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

enum TranscriptionAPIFormat {
    case sonartext
    case whisperxFastAPI
    case whisperASRWebservice
}

struct WhisperASRResponse: Sendable {
    let text: String?
    let segments: [WhisperASRSegment]?
    let language: String?
}

extension WhisperASRResponse: Codable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        text = try container.decodeIfPresent(String.self, forKey: .text)
        segments = try container.decodeIfPresent([WhisperASRSegment].self, forKey: .segments)
        language = try container.decodeIfPresent(String.self, forKey: .language)
    }
    
    enum CodingKeys: String, CodingKey {
        case text, segments, language
    }
}

struct WhisperASRSegment: Sendable {
    let start: Double?
    let end: Double?
    let text: String
    let speaker: String?
}

extension WhisperASRSegment: Codable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        start = try container.decodeIfPresent(Double.self, forKey: .start)
        end = try container.decodeIfPresent(Double.self, forKey: .end)
        text = try container.decode(String.self, forKey: .text)
        speaker = try container.decodeIfPresent(String.self, forKey: .speaker)
    }
    
    enum CodingKeys: String, CodingKey {
        case start, end, text, speaker
    }
}

struct WhisperXJobResponse: Sendable {
    let identifier: String?
    let message: String?
}

extension WhisperXJobResponse: Codable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        identifier = try container.decodeIfPresent(String.self, forKey: .identifier)
        message = try container.decodeIfPresent(String.self, forKey: .message)
    }
    
    enum CodingKeys: String, CodingKey {
        case identifier, message
    }
}

struct WhisperXTaskResponse: Sendable {
    let status: String
    let result: WhisperXResult?
    let metadata: WhisperXMetadata?
    let error: String?
}

extension WhisperXTaskResponse: Codable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = try container.decode(String.self, forKey: .status)
        result = try container.decodeIfPresent(WhisperXResult.self, forKey: .result)
        metadata = try container.decodeIfPresent(WhisperXMetadata.self, forKey: .metadata)
        error = try container.decodeIfPresent(String.self, forKey: .error)
    }
    
    enum CodingKeys: String, CodingKey {
        case status, result, metadata, error
    }
}

struct WhisperXResult: Sendable {
    let segments: [WhisperXSegment]?
}

extension WhisperXResult: Codable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        segments = try container.decodeIfPresent([WhisperXSegment].self, forKey: .segments)
    }
    
    enum CodingKeys: String, CodingKey {
        case segments
    }
}

struct WhisperXSegment: Sendable {
    let start: Double?
    let end: Double?
    let text: String
    let speaker: String?
}

extension WhisperXSegment: Codable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        start = try container.decodeIfPresent(Double.self, forKey: .start)
        end = try container.decodeIfPresent(Double.self, forKey: .end)
        text = try container.decode(String.self, forKey: .text)
        speaker = try container.decodeIfPresent(String.self, forKey: .speaker)
    }
    
    enum CodingKeys: String, CodingKey {
        case start, end, text, speaker
    }
}

struct WhisperXMetadata: Sendable {
    let taskType: String?
    let language: String?
    let duration: Double?
    let audioDuration: Double?
}

extension WhisperXMetadata: Codable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        taskType = try container.decodeIfPresent(String.self, forKey: .taskType)
        language = try container.decodeIfPresent(String.self, forKey: .language)
        duration = try container.decodeIfPresent(Double.self, forKey: .duration)
        audioDuration = try container.decodeIfPresent(Double.self, forKey: .audioDuration)
    }
    
    enum CodingKeys: String, CodingKey {
        case taskType = "task_type"
        case language
        case duration
        case audioDuration = "audio_duration"
    }
}

actor TranscriptionClient {
    private let session: URLSession
    private var baseURL: URL?
    private var apiKey: String?
    private var apiFormat: TranscriptionAPIFormat = .sonartext
    private var cachedASRResults: [String: TranscriptionResultResponse] = [:]
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    func configure(baseURL: String, apiKey: String?) async throws {
        var urlString = baseURL
        if !urlString.hasSuffix("/") {
            urlString += "/"
        }
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL
        }
        self.baseURL = url
        self.apiKey = apiKey
        
        self.apiFormat = await detectAPIFormat(baseURL: url)
        print("TranscriptionClient configured with baseURL: \(url), format: \(apiFormat)")
    }
    
    private func detectAPIFormat(baseURL: URL) async -> TranscriptionAPIFormat {
        let healthURL = baseURL.appendingPathComponent("health")
        var healthRequest = URLRequest(url: healthURL)
        healthRequest.timeoutInterval = 5
        
        print("TranscriptionClient: Detecting API format at \(healthURL)")
        
        do {
            let (data, response) = try await session.data(for: healthRequest)
            if let httpResponse = response as? HTTPURLResponse {
                print("TranscriptionClient: Health check returned status \(httpResponse.statusCode)")
                if let responseText = String(data: data, encoding: .utf8) {
                    print("TranscriptionClient: Health response body: \(responseText)")
                }
                if httpResponse.statusCode == 200 {
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        print("TranscriptionClient: Parsed JSON: \(json)")
                        
                        // Check for sonartext API format first (has models_loaded or concurrency fields)
                        if json["models_loaded"] != nil || json["concurrency"] != nil {
                            print("TranscriptionClient: Detected sonartext format (has models_loaded/concurrency)")
                            return .sonartext
                        }
                        
                        if let status = json["status"] as? String {
                            print("TranscriptionClient: Status value: '\(status)'")
                            if status == "healthy" {
                                print("TranscriptionClient: Detected whisperASRWebservice format")
                                return .whisperASRWebservice
                            }
                        }
                    } else {
                        print("TranscriptionClient: Failed to parse JSON")
                    }
                    return .whisperxFastAPI
                }
            }
        } catch {
            print("TranscriptionClient: Health check failed: \(error)")
        }
        
        return .sonartext
    }
    
    func submitJob(audioFileURL: URL) async throws -> String {
        guard let baseURL else { throw TranscriptionError.notConfigured }
        
        switch apiFormat {
        case .sonartext:
            return try await submitJobSonartext(audioFileURL: audioFileURL, baseURL: baseURL)
        case .whisperxFastAPI:
            return try await submitJobWhisperX(audioFileURL: audioFileURL, baseURL: baseURL)
        case .whisperASRWebservice:
            return try await submitJobWhisperASR(audioFileURL: audioFileURL, baseURL: baseURL)
        }
    }
    
    private func submitJobSonartext(audioFileURL: URL, baseURL: URL) async throws -> String {
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
    
    private func submitJobWhisperX(audioFileURL: URL, baseURL: URL) async throws -> String {
        let url = baseURL.appendingPathComponent("speech-to-text")
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
        body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n".data(using: .utf8)!)
        body.append("en\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"min_speakers\"\r\n\r\n".data(using: .utf8)!)
        body.append("1\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"max_speakers\"\r\n\r\n".data(using: .utf8)!)
        body.append("10\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        print("Submitting WhisperX transcription job to: \(url)")
        print("Audio file size: \(audioData.count) bytes")
        
        let (data, response) = try await session.data(for: request)
        
        if let responseString = String(data: data, encoding: .utf8) {
            print("WhisperX submit response: \(responseString)")
        }
        
        try validateResponse(response, data: data)
        
        let result = try JSONDecoder().decode(WhisperXJobResponse.self, from: data)
        
        guard let identifier = result.identifier else {
            throw TranscriptionError.jobFailed(result.message ?? "No task identifier returned")
        }
        
        print("WhisperX job submitted with identifier: \(identifier)")
        return identifier
    }
    
    private func submitJobWhisperASR(audioFileURL: URL, baseURL: URL) async throws -> String {
        let url = baseURL.appendingPathComponent("asr")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "output", value: "json"),
            URLQueryItem(name: "language", value: "en"),
            URLQueryItem(name: "encode", value: "true"),
            URLQueryItem(name: "word_timestamps", value: "true")
        ]
        
        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.timeoutInterval = 600
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        let audioData = try Data(contentsOf: audioFileURL)
        var body = Data()
        
        let filename = audioFileURL.lastPathComponent
        let mimeType = filename.hasSuffix(".m4a") ? "audio/mp4" : "audio/mpeg"
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"audio_file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        print("Submitting WhisperASR transcription to: \(components.url!)")
        print("Audio file size: \(audioData.count) bytes")
        
        let (data, response) = try await session.data(for: request)
        
        if let responseString = String(data: data, encoding: .utf8) {
            print("WhisperASR response: \(responseString.prefix(2000))")
        }
        
        try validateResponse(response, data: data)
        
        let asrResponse = try JSONDecoder().decode(WhisperASRResponse.self, from: data)
        
        let segments = asrResponse.segments?.map { seg in
            TranscriptionSegment(
                start: seg.start,
                end: seg.end,
                text: seg.text,
                speaker: seg.speaker,
                speakerConfidence: nil
            )
        } ?? []
        
        let resultResponse = TranscriptionResultResponse(
            text: asrResponse.text,
            segments: segments,
            language: asrResponse.language
        )
        
        let jobId = UUID().uuidString
        cachedASRResults[jobId] = resultResponse
        
        print("WhisperASR transcription complete, cached with jobId: \(jobId)")
        return jobId
    }
    
    func checkStatus(jobId: String) async throws -> TranscriptionStatusResponse {
        guard let baseURL else { throw TranscriptionError.notConfigured }
        
        switch apiFormat {
        case .sonartext:
            return try await checkStatusSonartext(jobId: jobId, baseURL: baseURL)
        case .whisperxFastAPI:
            return try await checkStatusWhisperX(jobId: jobId, baseURL: baseURL)
        case .whisperASRWebservice:
            return checkStatusWhisperASR(jobId: jobId)
        }
    }
    
    private func checkStatusWhisperASR(jobId: String) -> TranscriptionStatusResponse {
        if let result = cachedASRResults[jobId] {
            let segments = result.segments ?? []
            return TranscriptionStatusResponse(
                jobId: jobId,
                status: "completed",
                progress: nil,
                elapsedTime: nil,
                result: TranscriptionResultWrapper(
                    status: "completed",
                    text: result.text,
                    result: TranscriptionSegmentsContainer(segments: segments),
                    processingInfo: TranscriptionProcessingInfo(
                        device: nil,
                        languageDetected: result.language,
                        audioDuration: nil,
                        totalSpeakers: nil,
                        confidentSpeakers: nil
                    ),
                    jobId: jobId,
                    processingTime: nil
                ),
                error: nil
            )
        } else {
            return TranscriptionStatusResponse(
                jobId: jobId,
                status: "failed",
                progress: nil,
                elapsedTime: nil,
                result: nil,
                error: "Result not found in cache"
            )
        }
    }
    
    private func checkStatusSonartext(jobId: String, baseURL: URL) async throws -> TranscriptionStatusResponse {
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
    
    private func checkStatusWhisperX(jobId: String, baseURL: URL) async throws -> TranscriptionStatusResponse {
        let url = baseURL.appendingPathComponent("task/\(jobId)")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        
        if let apiKey, !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await session.data(for: request)
        
        try validateResponse(response, data: data)
        
        if let responseString = String(data: data, encoding: .utf8) {
            print("WhisperX task status raw response: \(responseString.prefix(2000))")
        }
        
        let taskResponse = try JSONDecoder().decode(WhisperXTaskResponse.self, from: data)
        
        let mappedStatus: String
        switch taskResponse.status.lowercased() {
        case "completed", "succeeded", "success":
            mappedStatus = "completed"
        case "failed", "error":
            mappedStatus = "failed"
        case "queued", "pending":
            mappedStatus = "queued"
        case "processing", "running", "in_progress":
            mappedStatus = "processing"
        default:
            mappedStatus = taskResponse.status
        }
        
        var resultWrapper: TranscriptionResultWrapper?
        if let whisperXResult = taskResponse.result {
            let segments = whisperXResult.segments?.map { seg in
                TranscriptionSegment(
                    start: seg.start,
                    end: seg.end,
                    text: seg.text,
                    speaker: seg.speaker,
                    speakerConfidence: nil
                )
            }
            
            resultWrapper = TranscriptionResultWrapper(
                status: mappedStatus,
                text: whisperXResult.segments?.map { $0.text }.joined(separator: " "),
                result: TranscriptionSegmentsContainer(segments: segments),
                processingInfo: TranscriptionProcessingInfo(
                    device: nil,
                    languageDetected: taskResponse.metadata?.language,
                    audioDuration: taskResponse.metadata?.audioDuration,
                    totalSpeakers: nil,
                    confidentSpeakers: nil
                ),
                jobId: jobId,
                processingTime: taskResponse.metadata?.duration
            )
        }
        
        print("WhisperX job \(jobId) status: \(mappedStatus)")
        
        return TranscriptionStatusResponse(
            jobId: jobId,
            status: mappedStatus,
            progress: nil,
            elapsedTime: taskResponse.metadata?.duration,
            result: resultWrapper,
            error: taskResponse.error
        )
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
