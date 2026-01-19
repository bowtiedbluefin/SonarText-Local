import Foundation

enum NetworkError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, body: String?)
    case decodingFailed(Error)
    case uploadFailed(Error)
    case timeout
    case rateLimited(retryAfter: TimeInterval?)
    case serverError(statusCode: Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code, let body):
            return "HTTP error \(code): \(body ?? "unknown")"
        case .decodingFailed(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .uploadFailed(let error):
            return "Upload failed: \(error.localizedDescription)"
        case .timeout:
            return "Request timed out"
        case .rateLimited(let retryAfter):
            if let retryAfter {
                return "Rate limited. Retry after \(Int(retryAfter)) seconds."
            }
            return "Rate limited"
        case .serverError(let code):
            return "Server error: \(code)"
        }
    }
    
    var isRetryable: Bool {
        switch self {
        case .rateLimited, .serverError, .timeout:
            return true
        default:
            return false
        }
    }
}
