import AVFoundation
import CoreAudio
import Foundation

protocol AudioCaptureDelegate: AnyObject {
    func audioCaptureDidStart(_ capture: any AudioCapture)
    func audioCaptureDidStop(_ capture: any AudioCapture, duration: TimeInterval)
    func audioCaptureDidFail(_ capture: any AudioCapture, error: Error)
}

protocol AudioCapture: AnyObject {
    var delegate: AudioCaptureDelegate? { get set }
    var isRecording: Bool { get }
    var outputURL: URL? { get }
    func start(outputURL: URL) throws
    func stop() async throws -> TimeInterval
}

final class MicCapture: NSObject, AudioCapture, AVAudioRecorderDelegate {
    weak var delegate: AudioCaptureDelegate?
    
    private var audioRecorder: AVAudioRecorder?
    private(set) var outputURL: URL?
    private var startTime: Date?
    
    /// The device UID to use for recording. If nil, uses system default.
    var selectedDeviceUID: String?
    
    private let settings: [String: Any] = [
        AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
        AVSampleRateKey: 44100.0,
        AVNumberOfChannelsKey: 1,
        AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
    ]
    
    var isRecording: Bool {
        audioRecorder?.isRecording ?? false
    }
    
    func start(outputURL: URL) throws {
        self.outputURL = outputURL
        
        #if os(macOS)
        // Set the selected input device before recording
        if let deviceUID = selectedDeviceUID {
            try setInputDevice(uid: deviceUID)
        }
        #endif
        
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
        try session.setActive(true)
        #endif
        
        audioRecorder = try AVAudioRecorder(url: outputURL, settings: settings)
        audioRecorder?.delegate = self
        audioRecorder?.isMeteringEnabled = true
        
        guard audioRecorder?.record() == true else {
            throw MicCaptureError.recordingFailed
        }
        
        startTime = Date()
        delegate?.audioCaptureDidStart(self)
    }
    
    func stop() async throws -> TimeInterval {
        guard let recorder = audioRecorder, recorder.isRecording else {
            throw MicCaptureError.notRecording
        }
        
        let duration = recorder.currentTime
        recorder.stop()
        
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
        #endif
        
        audioRecorder = nil
        startTime = nil
        
        delegate?.audioCaptureDidStop(self, duration: duration)
        return duration
    }
    
    #if os(macOS)
    /// Sets the default input device for the system (used by AVAudioRecorder)
    private func setInputDevice(uid: String) throws {
        guard let deviceID = getDeviceID(forUID: uid) else {
            print("MicCapture: Device with UID '\(uid)' not found, using system default")
            return
        }
        
        var deviceIDVar = deviceID
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let status = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            UInt32(MemoryLayout<AudioDeviceID>.size),
            &deviceIDVar
        )
        
        if status != noErr {
            print("MicCapture: Failed to set input device (error \(status)), using system default")
        } else {
            print("MicCapture: Set input device to '\(uid)'")
        }
    }
    
    private func getDeviceID(forUID uid: String) -> AudioDeviceID? {
        var propertySize: UInt32 = 0
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        guard AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize
        ) == noErr else {
            return nil
        }
        
        let deviceCount = Int(propertySize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
        
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &deviceIDs
        ) == noErr else {
            return nil
        }
        
        for deviceID in deviceIDs {
            if getDeviceUID(deviceID: deviceID) == uid {
                return deviceID
            }
        }
        
        return nil
    }
    
    private func getDeviceUID(deviceID: AudioDeviceID) -> String? {
        var propertySize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var uidUnmanaged: Unmanaged<CFString>?
        let status = withUnsafeMutablePointer(to: &uidUnmanaged) { ptr in
            AudioObjectGetPropertyData(
                deviceID,
                &propertyAddress,
                0,
                nil,
                &propertySize,
                ptr
            )
        }
        
        guard status == noErr, let cfUID = uidUnmanaged?.takeRetainedValue() else {
            return nil
        }
        
        return cfUID as String
    }
    #endif
    
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            delegate?.audioCaptureDidFail(self, error: MicCaptureError.recordingInterrupted)
        }
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error = error {
            delegate?.audioCaptureDidFail(self, error: error)
        }
    }
}

enum MicCaptureError: LocalizedError {
    case recordingFailed
    case notRecording
    case recordingInterrupted
    
    var errorDescription: String? {
        switch self {
        case .recordingFailed:
            return "Failed to start microphone recording"
        case .notRecording:
            return "Microphone is not currently recording"
        case .recordingInterrupted:
            return "Microphone recording was interrupted"
        }
    }
}
