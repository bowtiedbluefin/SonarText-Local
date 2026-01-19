import Foundation

enum RecordingState: Equatable {
    case idle
    case starting
    case recording(recordingId: UUID)
    case stopping
    case error(message: String)
    
    var isRecording: Bool {
        if case .recording = self { return true }
        return false
    }
    
    var canStart: Bool {
        switch self {
        case .idle, .error:
            return true
        default:
            return false
        }
    }
    
    var canStop: Bool {
        if case .recording = self { return true }
        return false
    }
}

enum RecordingEvent {
    case startRequested
    case startSucceeded(recordingId: UUID)
    case startFailed(error: String)
    case stopRequested
    case stopSucceeded
    case stopFailed(error: String)
    case reset
}

struct RecordingStateMachine {
    private(set) var state: RecordingState = .idle
    
    mutating func handle(_ event: RecordingEvent) -> RecordingState {
        switch (state, event) {
        case (.idle, .startRequested),
             (.error, .startRequested):
            state = .starting
            
        case (.starting, .startSucceeded(let recordingId)):
            state = .recording(recordingId: recordingId)
            
        case (.starting, .startFailed(let error)):
            state = .error(message: error)
            
        case (.recording, .stopRequested):
            state = .stopping
            
        case (.stopping, .stopSucceeded):
            state = .idle
            
        case (.stopping, .stopFailed(let error)):
            state = .error(message: error)
            
        case (_, .reset):
            state = .idle
            
        default:
            break
        }
        
        return state
    }
}
