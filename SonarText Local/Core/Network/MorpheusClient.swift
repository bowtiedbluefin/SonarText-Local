import Foundation

struct MorpheusAnalysisResponse: Sendable {
    let summary: String?
    let keyPoints: [String]?
    let actionItems: [String]?
    let decisions: [String]?
    let openQuestions: [String]?
    let participants: [String]?
    let rawResponse: String?
    
    enum CodingKeys: String, CodingKey {
        case summary
        case keyPoints = "key_points"
        case actionItems = "action_items"
        case decisions
        case openQuestions = "open_questions"
        case participants
        case rawResponse = "raw_response"
    }
}

extension MorpheusAnalysisResponse: Codable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        summary = try container.decodeIfPresent(String.self, forKey: .summary)
        keyPoints = try container.decodeIfPresent([String].self, forKey: .keyPoints)
        actionItems = try container.decodeIfPresent([String].self, forKey: .actionItems)
        decisions = try container.decodeIfPresent([String].self, forKey: .decisions)
        openQuestions = try container.decodeIfPresent([String].self, forKey: .openQuestions)
        participants = try container.decodeIfPresent([String].self, forKey: .participants)
        rawResponse = try container.decodeIfPresent(String.self, forKey: .rawResponse)
    }
    
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(summary, forKey: .summary)
        try container.encodeIfPresent(keyPoints, forKey: .keyPoints)
        try container.encodeIfPresent(actionItems, forKey: .actionItems)
        try container.encodeIfPresent(decisions, forKey: .decisions)
        try container.encodeIfPresent(openQuestions, forKey: .openQuestions)
        try container.encodeIfPresent(participants, forKey: .participants)
        try container.encodeIfPresent(rawResponse, forKey: .rawResponse)
    }
}

struct ChatCompletionRequest: Sendable {
    let model: String
    let messages: [ChatMessage]
    let temperature: Double?
    let maxTokens: Int?
    let stream: Bool?
    
    enum CodingKeys: String, CodingKey {
        case model, messages, temperature, stream
        case maxTokens = "max_tokens"
    }
}

extension ChatCompletionRequest: Codable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        model = try container.decode(String.self, forKey: .model)
        messages = try container.decode([ChatMessage].self, forKey: .messages)
        temperature = try container.decodeIfPresent(Double.self, forKey: .temperature)
        maxTokens = try container.decodeIfPresent(Int.self, forKey: .maxTokens)
        stream = try container.decodeIfPresent(Bool.self, forKey: .stream)
    }
    
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(model, forKey: .model)
        try container.encode(messages, forKey: .messages)
        try container.encodeIfPresent(temperature, forKey: .temperature)
        try container.encodeIfPresent(maxTokens, forKey: .maxTokens)
        try container.encodeIfPresent(stream, forKey: .stream)
    }
}

struct ChatMessage: Sendable {
    let role: String
    let content: String
}

extension ChatMessage: Codable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        role = try container.decode(String.self, forKey: .role)
        content = try container.decode(String.self, forKey: .content)
    }
    
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(role, forKey: .role)
        try container.encode(content, forKey: .content)
    }
    
    enum CodingKeys: String, CodingKey {
        case role, content
    }
}

struct ChatCompletionResponse: Sendable {
    let id: String?
    let choices: [ChatChoice]?
    let usage: ChatUsage?
}

extension ChatCompletionResponse: Codable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        choices = try container.decodeIfPresent([ChatChoice].self, forKey: .choices)
        usage = try container.decodeIfPresent(ChatUsage.self, forKey: .usage)
    }
    
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encodeIfPresent(choices, forKey: .choices)
        try container.encodeIfPresent(usage, forKey: .usage)
    }
    
    enum CodingKeys: String, CodingKey {
        case id, choices, usage
    }
}

struct ChatChoice: Sendable {
    let index: Int?
    let message: ChatMessage?
    let finishReason: String?
    
    enum CodingKeys: String, CodingKey {
        case index, message
        case finishReason = "finish_reason"
    }
}

extension ChatChoice: Codable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        index = try container.decodeIfPresent(Int.self, forKey: .index)
        message = try container.decodeIfPresent(ChatMessage.self, forKey: .message)
        finishReason = try container.decodeIfPresent(String.self, forKey: .finishReason)
    }
    
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(index, forKey: .index)
        try container.encodeIfPresent(message, forKey: .message)
        try container.encodeIfPresent(finishReason, forKey: .finishReason)
    }
}

struct ChatUsage: Sendable {
    let promptTokens: Int?
    let completionTokens: Int?
    let totalTokens: Int?
    
    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
    }
}

extension ChatUsage: Codable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        promptTokens = try container.decodeIfPresent(Int.self, forKey: .promptTokens)
        completionTokens = try container.decodeIfPresent(Int.self, forKey: .completionTokens)
        totalTokens = try container.decodeIfPresent(Int.self, forKey: .totalTokens)
    }
    
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(promptTokens, forKey: .promptTokens)
        try container.encodeIfPresent(completionTokens, forKey: .completionTokens)
        try container.encodeIfPresent(totalTokens, forKey: .totalTokens)
    }
}

actor MorpheusClient {
    private let session: URLSession
    private var baseURL: URL?
    private var apiKey: String?
    private let model = "glm-4.7"
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    func configure(baseURL: String, apiKey: String) throws {
        guard let url = URL(string: baseURL) else {
            throw NetworkError.invalidURL
        }
        self.baseURL = url
        self.apiKey = apiKey
        print("MorpheusClient: Configured with baseURL: \(url), model: \(model)")
    }
    
    func analyze(transcript: String, title: String?, durationSeconds: Double?, mode: AnalysisMode = .meeting) async throws -> MorpheusAnalysisResponse {
        guard let baseURL else { throw MorpheusError.notConfigured }
        guard let apiKey, !apiKey.isEmpty else { throw MorpheusError.noApiKey }
        
        let url = baseURL.appendingPathComponent("chat/completions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 180
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let systemPrompt = getSystemPrompt(for: mode)
        
        let titleInfo = title.map { "Title: \($0)\n" } ?? ""
        let durationInfo = durationSeconds.map { "Duration: \(Int($0 / 60)) minutes\n" } ?? ""
        
        let userMessage = """
        \(titleInfo)\(durationInfo)
        Transcript:
        \(transcript)
        """
        
        let messages = [
            ChatMessage(role: "system", content: systemPrompt),
            ChatMessage(role: "user", content: userMessage)
        ]
        
        let requestBody = ChatCompletionRequest(
            model: model,
            messages: messages,
            temperature: 0.3,
            maxTokens: 4096,
            stream: false
        )
        
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(requestBody)
        
        print("MorpheusClient: Sending analysis request to \(url)")
        print("MorpheusClient: Model: \(model)")
        print("MorpheusClient: Transcript length: \(transcript.count) chars")
        print("MorpheusClient: Request timeout: \(request.timeoutInterval) seconds")
        print("MorpheusClient: Stream disabled: true")
        
        let startTime = Date()
        let (data, response) = try await session.data(for: request)
        let elapsed = Date().timeIntervalSince(startTime)
        
        print("MorpheusClient: Response received in \(String(format: "%.2f", elapsed)) seconds")
        print("MorpheusClient: Response data size: \(data.count) bytes")
        
        if let responseString = String(data: data, encoding: .utf8) {
            print("MorpheusClient: Response preview: \(responseString.prefix(500))...")
        }
        
        try validateResponse(response, data: data)
        
        let chatResponse = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        
        guard let content = chatResponse.choices?.first?.message?.content else {
            throw MorpheusError.noContent
        }
        
        print("MorpheusClient: Got response content, length: \(content.count)")
        
        return parseAnalysisResponse(content)
    }
    
    private func getSystemPrompt(for mode: AnalysisMode) -> String {
        switch mode {
        case .meeting:
            return """
            You are an expert meeting analyst. Analyze the following transcript and provide a structured analysis.
            
            Return your analysis in the following JSON format:
            {
                "summary": "A concise 2-3 sentence summary of the meeting/conversation",
                "key_points": ["Key point 1", "Key point 2", ...],
                "action_items": ["Action item 1 with owner if mentioned", "Action item 2", ...],
                "decisions": ["Decision 1", "Decision 2", ...],
                "open_questions": ["Unresolved question 1", "Question needing follow-up", ...],
                "participants": ["Speaker 1", "Speaker 2", ...]
            }
            
            Guidelines:
            - Be concise but comprehensive
            - Extract actionable items with owners when mentioned
            - Note any decisions that were made
            - Identify questions that were raised but not answered
            - If speakers are labeled (e.g., SPEAKER_00), include them in participants
            - Return ONLY the JSON object, no additional text
            """
            
        case .speech:
            return """
            You are an expert speech and presentation analyst. Analyze the following transcript of a speech, lecture, or presentation.
            
            Return your analysis in the following JSON format:
            {
                "summary": "A concise 2-3 sentence summary of the main message and purpose",
                "key_points": ["Main argument or theme 1", "Key insight 2", "Important point 3", ...],
                "action_items": ["Recommended action or takeaway 1", "Call to action 2", ...],
                "decisions": ["Key conclusions or positions stated", ...],
                "open_questions": ["Topics for further exploration", "Unanswered questions raised", ...],
                "participants": ["Speaker name if mentioned"]
            }
            
            Guidelines:
            - Focus on the speaker's main arguments, themes, and message
            - Identify the core thesis or purpose of the speech
            - Extract memorable quotes or key phrases
            - Note any calls to action or recommendations
            - Identify the intended audience if apparent
            - Summarize supporting evidence or examples used
            - Return ONLY the JSON object, no additional text
            """
        }
    }
    
    private func parseAnalysisResponse(_ content: String) -> MorpheusAnalysisResponse {
        var jsonString = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if jsonString.hasPrefix("```json") {
            jsonString = String(jsonString.dropFirst(7))
        } else if jsonString.hasPrefix("```") {
            jsonString = String(jsonString.dropFirst(3))
        }
        if jsonString.hasSuffix("```") {
            jsonString = String(jsonString.dropLast(3))
        }
        jsonString = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let jsonData = jsonString.data(using: .utf8),
           let parsed = try? JSONDecoder().decode(MorpheusAnalysisResponse.self, from: jsonData) {
            return parsed
        }
        
        return MorpheusAnalysisResponse(
            summary: nil,
            keyPoints: nil,
            actionItems: nil,
            decisions: nil,
            openQuestions: nil,
            participants: nil,
            rawResponse: content
        )
    }
    
    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        print("MorpheusClient: HTTP Status: \(httpResponse.statusCode)")
        
        switch httpResponse.statusCode {
        case 200..<300:
            return
        case 429:
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After").flatMap { TimeInterval($0) }
            throw NetworkError.rateLimited(retryAfter: retryAfter)
        case 500..<600:
            let body = String(data: data, encoding: .utf8) ?? "No body"
            print("MorpheusClient: Server error: \(body)")
            throw NetworkError.serverError(statusCode: httpResponse.statusCode)
        default:
            let body = String(data: data, encoding: .utf8)
            print("MorpheusClient: HTTP error: \(body ?? "No body")")
            throw NetworkError.httpError(statusCode: httpResponse.statusCode, body: body)
        }
    }
}

enum MorpheusError: LocalizedError {
    case notConfigured
    case noApiKey
    case noContent
    case parseError
    
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Morpheus API not configured. Go to Settings > API to configure."
        case .noApiKey:
            return "Morpheus API key not set"
        case .noContent:
            return "No content in API response"
        case .parseError:
            return "Failed to parse analysis response"
        }
    }
}
