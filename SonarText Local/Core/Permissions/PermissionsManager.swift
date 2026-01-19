import AVFoundation
import ScreenCaptureKit

enum PermissionStatus: Sendable {
    case authorized
    case denied
    case notDetermined
    
    nonisolated static func == (lhs: PermissionStatus, rhs: PermissionStatus) -> Bool {
        switch (lhs, rhs) {
        case (.authorized, .authorized), (.denied, .denied), (.notDetermined, .notDetermined):
            return true
        default:
            return false
        }
    }
}

actor PermissionsManager {
    static let shared = PermissionsManager()
    
    private init() {}
    
    func checkMicrophonePermission() async -> PermissionStatus {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return .authorized
        case .denied, .restricted:
            return .denied
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .notDetermined
        }
    }
    
    func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }
    }
    
    func checkSystemAudioPermission() async -> PermissionStatus {
        if #available(macOS 14.0, *) {
            do {
                _ = try await SCShareableContent.current
                return .authorized
            } catch let error as NSError {
                if error.code == -3801 {
                    return .denied
                }
                print("System audio permission check error: \(error)")
                return .denied
            }
        } else {
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
                return content.displays.isEmpty ? .denied : .authorized
            } catch {
                return .denied
            }
        }
    }
    
    func ensureMicrophoneAccess() async throws {
        let status = await checkMicrophonePermission()
        switch status {
        case .authorized:
            return
        case .notDetermined:
            let granted = await requestMicrophonePermission()
            if !granted {
                throw PermissionError.microphoneDenied
            }
        case .denied:
            throw PermissionError.microphoneDenied
        }
    }
    
    func ensureScreenRecordingAccess() async throws {
        let status = await checkSystemAudioPermission()
        if status != .authorized {
            throw PermissionError.screenRecordingDenied
        }
    }
}

enum PermissionError: LocalizedError, Sendable {
    case microphoneDenied
    case screenRecordingDenied
    
    var errorDescription: String? {
        switch self {
        case .microphoneDenied:
            return "Microphone access denied. Please enable in System Settings > Privacy & Security > Microphone."
        case .screenRecordingDenied:
            return "System Audio Recording access denied. Please enable in System Settings > Privacy & Security > Screen & System Audio Recording."
        }
    }
}
