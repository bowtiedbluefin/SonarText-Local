import Foundation

struct AppConfiguration {
    var transcriptionBaseURL: String
    var morpheusBaseURL: String
    
    static var `default`: AppConfiguration {
        AppConfiguration(
            transcriptionBaseURL: ProcessInfo.processInfo.environment["TRANSCRIBE_BASE_URL"] ?? "https://api.transcription.example.com",
            morpheusBaseURL: ProcessInfo.processInfo.environment["MORPHEUS_BASE_URL"] ?? "https://api.morpheus.example.com"
        )
    }
    
    static func load() -> AppConfiguration {
        let defaults = UserDefaults.standard
        
        return AppConfiguration(
            transcriptionBaseURL: defaults.string(forKey: "transcriptionBaseURL") ?? Self.default.transcriptionBaseURL,
            morpheusBaseURL: defaults.string(forKey: "morpheusBaseURL") ?? Self.default.morpheusBaseURL
        )
    }
    
    func save() {
        let defaults = UserDefaults.standard
        defaults.set(transcriptionBaseURL, forKey: "transcriptionBaseURL")
        defaults.set(morpheusBaseURL, forKey: "morpheusBaseURL")
    }
}
