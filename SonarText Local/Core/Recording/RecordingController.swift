import Foundation
import Combine

@MainActor
final class RecordingController: ObservableObject {
    @Published private(set) var state: RecordingState = .idle
    @Published private(set) var currentRecording: Recording?
    @Published var errorMessage: String?
    @Published var warningMessage: String?
    @Published private(set) var recordingStartTime: Date?
    
    private var stateMachine = RecordingStateMachine()
    private let micCapture = MicCapture()
    private let systemCapture: any AudioCapture
    private let audioDeviceManager = AudioDeviceManager.shared
    
    private let permissionsManager = PermissionsManager.shared
    private let databaseManager = DatabaseManager.shared
    private let fileStorage = FileStorage.shared
    
    private var enableMicrophone = true
    private var enableSystemAudio = true
    private var systemAudioActuallyStarted = false
    
    init() {
        if #available(macOS 13.0, *) {
            systemCapture = SystemAudioCapture()
        } else {
            systemCapture = FallbackSystemAudioCapture()
        }
    }
    
    func configure(microphone: Bool, systemAudio: Bool) {
        enableMicrophone = microphone
        enableSystemAudio = systemAudio
    }
    
    func startRecording() async {
        guard state.canStart else {
            print("RecordingController: Cannot start - current state: \(state)")
            return
        }
        
        print("RecordingController: Starting recording...")
        state = stateMachine.handle(.startRequested)
        warningMessage = nil
        systemAudioActuallyStarted = false
        
        do {
            if enableMicrophone {
                try await permissionsManager.ensureMicrophoneAccess()
            }
            
            var canCaptureSystemAudio = false
            if enableSystemAudio {
                do {
                    try await permissionsManager.ensureScreenRecordingAccess()
                    canCaptureSystemAudio = true
                } catch {
                    print("Screen recording permission denied, falling back to mic-only: \(error)")
                    warningMessage = "System audio unavailable (no Screen Recording permission). Recording mic only."
                    canCaptureSystemAudio = false
                }
            }
            
            let sourceFlags: RecordingSource
            if enableMicrophone && canCaptureSystemAudio {
                sourceFlags = .both
            } else if enableMicrophone {
                sourceFlags = .microphone
            } else {
                sourceFlags = .system
            }
            
            var recording = Recording(sourceFlags: sourceFlags)
            
            if enableMicrophone {
                let micURL = try await fileStorage.micFilePath(for: recording.id)
                recording.micFilePath = micURL.path
                micCapture.selectedDeviceUID = audioDeviceManager.selectedInputDeviceUID
                try micCapture.start(outputURL: micURL)
                print("Mic recording started: \(micURL.path)")
            }
            
            if canCaptureSystemAudio {
                do {
                    let systemURL = try await fileStorage.systemFilePath(for: recording.id)
                    recording.systemFilePath = systemURL.path
                    try systemCapture.start(outputURL: systemURL)
                    systemAudioActuallyStarted = true
                    print("System audio recording started: \(systemURL.path)")
                } catch {
                    print("System audio capture failed to start: \(error)")
                    warningMessage = "System audio failed to start: \(error.localizedDescription). Recording mic only."
                    recording.sourceFlags = .microphone
                    recording.systemFilePath = nil
                }
            }
            
            try await databaseManager.insert(recording)
            
            currentRecording = recording
            recordingStartTime = Date()
            state = stateMachine.handle(.startSucceeded(recordingId: recording.id))
            errorMessage = nil
            
        } catch {
            state = stateMachine.handle(.startFailed(error: error.localizedDescription))
            errorMessage = error.localizedDescription
        }
    }
    
    func stopRecording() async {
        guard state.canStop else { return }
        
        state = stateMachine.handle(.stopRequested)
        
        do {
            var micDuration: TimeInterval = 0
            var systemDuration: TimeInterval = 0
            
            if enableMicrophone && micCapture.isRecording {
                micDuration = try await micCapture.stop()
                print("Mic recording stopped, duration: \(micDuration)s")
            }
            
            if systemAudioActuallyStarted && systemCapture.isRecording {
                systemDuration = try await systemCapture.stop()
                print("System audio recording stopped, duration: \(systemDuration)s")
            }
            
            if var recording = currentRecording {
                recording.durationSeconds = max(micDuration, systemDuration)
                
                let hasBothSources = recording.micFilePath != nil && recording.systemFilePath != nil
                if hasBothSources {
                    do {
                        let mergedURL = try await fileStorage.mergedFilePath(for: recording.id)
                        if let mergedPath = try await AudioMerger.shared.mergeIfNeeded(
                            micPath: recording.micFilePath,
                            systemPath: recording.systemFilePath,
                            outputURL: mergedURL
                        ) {
                            recording.mergedFilePath = mergedPath.path
                            print("Audio files merged successfully: \(mergedPath.path)")
                        }
                    } catch {
                        print("Failed to merge audio files: \(error.localizedDescription)")
                        warningMessage = "Audio files recorded separately (merge failed)"
                    }
                }
                
                recording.status = .recorded
                recording.updatedAt = Date()
                try await databaseManager.update(recording)
                print("Recording saved with duration: \(recording.durationSeconds ?? 0)s")
            }
            
            currentRecording = nil
            recordingStartTime = nil
            systemAudioActuallyStarted = false
            state = stateMachine.handle(.stopSucceeded)
            errorMessage = nil
            
        } catch {
            state = stateMachine.handle(.stopFailed(error: error.localizedDescription))
            errorMessage = error.localizedDescription
        }
    }
    
    func toggle() async {
        if state.isRecording {
            await stopRecording()
        } else {
            await startRecording()
        }
    }
    
    func recoverFromCrash() async {
        do {
            try await databaseManager.markIncompleteRecordings()
        } catch {
            errorMessage = "Failed to recover recordings: \(error.localizedDescription)"
        }
    }
}
