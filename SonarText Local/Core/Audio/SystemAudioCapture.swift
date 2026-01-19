import AVFoundation
import ScreenCaptureKit
import Foundation

@available(macOS 13.0, *)
final class SystemAudioCapture: NSObject, AudioCapture, SCStreamDelegate, SCStreamOutput {
    weak var delegate: AudioCaptureDelegate?
    
    private var stream: SCStream?
    private var assetWriter: AVAssetWriter?
    private var audioInput: AVAssetWriterInput?
    private(set) var outputURL: URL?
    private var startTime: CMTime?
    private var lastSampleTime: CMTime = .zero
    private var isCapturing = false
    
    var isRecording: Bool { isCapturing }
    
    func start(outputURL: URL) throws {
        self.outputURL = outputURL
        isCapturing = true
        
        Task {
            do {
                try await startCapture(outputURL: outputURL)
            } catch {
                isCapturing = false
                await MainActor.run {
                    self.delegate?.audioCaptureDidFail(self, error: error)
                }
                throw error
            }
        }
    }
    
    private func startCapture(outputURL: URL) async throws {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        
        guard let display = content.displays.first else {
            throw SystemAudioCaptureError.noDisplayFound
        }
        
        let filter = SCContentFilter(display: display, excludingWindows: [])
        
        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.excludesCurrentProcessAudio = true
        config.sampleRate = 44100
        config.channelCount = 2
        config.width = 2
        config.height = 2
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1)
        config.showsCursor = false
        
        assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: .m4a)
        
        let audioSettings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 2,
            AVEncoderBitRateKey: 128000
        ]
        
        audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        audioInput?.expectsMediaDataInRealTime = true
        
        if let audioInput = audioInput, assetWriter?.canAdd(audioInput) == true {
            assetWriter?.add(audioInput)
        }
        
        assetWriter?.startWriting()
        
        stream = SCStream(filter: filter, configuration: config, delegate: self)
        
        try stream?.addStreamOutput(self, type: .audio, sampleHandlerQueue: DispatchQueue(label: "SystemAudioCapture"))
        
        try await stream?.startCapture()
        
        print("System audio capture started successfully")
        isCapturing = true
        await MainActor.run {
            self.delegate?.audioCaptureDidStart(self)
        }
    }
    
    func stop() async throws -> TimeInterval {
        guard isCapturing else {
            throw SystemAudioCaptureError.notRecording
        }
        
        isCapturing = false
        
        try await stream?.stopCapture()
        stream = nil
        
        audioInput?.markAsFinished()
        await assetWriter?.finishWriting()
        
        let duration = CMTimeGetSeconds(lastSampleTime - (startTime ?? .zero))
        
        assetWriter = nil
        audioInput = nil
        startTime = nil
        
        await MainActor.run {
            self.delegate?.audioCaptureDidStop(self, duration: max(0, duration))
        }
        
        return max(0, duration)
    }
    
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio, isCapturing else { return }
        guard sampleBuffer.isValid else { return }
        
        let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        
        if startTime == nil {
            startTime = presentationTime
            assetWriter?.startSession(atSourceTime: presentationTime)
        }
        
        lastSampleTime = presentationTime
        
        if audioInput?.isReadyForMoreMediaData == true {
            audioInput?.append(sampleBuffer)
        }
    }
    
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        isCapturing = false
        delegate?.audioCaptureDidFail(self, error: error)
    }
}

enum SystemAudioCaptureError: LocalizedError {
    case noDisplayFound
    case notRecording
    case captureSetupFailed
    
    var errorDescription: String? {
        switch self {
        case .noDisplayFound:
            return "No display found for system audio capture"
        case .notRecording:
            return "System audio is not currently recording"
        case .captureSetupFailed:
            return "Failed to set up system audio capture"
        }
    }
}

final class FallbackSystemAudioCapture: AudioCapture {
    weak var delegate: AudioCaptureDelegate?
    private(set) var outputURL: URL?
    var isRecording: Bool { false }
    
    func start(outputURL: URL) throws {
        throw FallbackError.virtualDeviceRequired
    }
    
    func stop() async throws -> TimeInterval {
        throw FallbackError.notRecording
    }
    
    static var setupInstructions: String {
        """
        System audio capture requires Screen Recording permission (macOS 13+).
        
        If ScreenCaptureKit is unavailable, you can use a virtual audio device:
        
        1. Install BlackHole (https://existential.audio/blackhole/)
        2. Open Audio MIDI Setup
        3. Create a Multi-Output Device combining your speakers + BlackHole
        4. Set this as your system output
        5. Configure this app to record from BlackHole as mic input
        
        This routes system audio through a virtual device that the app can capture.
        """
    }
}

enum FallbackError: LocalizedError {
    case virtualDeviceRequired
    case notRecording
    
    var errorDescription: String? {
        switch self {
        case .virtualDeviceRequired:
            return "System audio capture unavailable. See setup instructions for virtual device fallback."
        case .notRecording:
            return "Not recording"
        }
    }
}
