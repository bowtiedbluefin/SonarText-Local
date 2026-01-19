import AVFoundation
import CoreAudio
import Combine

struct AudioDevice: Identifiable, Hashable {
    let id: AudioDeviceID
    let name: String
    let uid: String
    let isInput: Bool
}

final class AudioDeviceManager: ObservableObject {
    static let shared = AudioDeviceManager()
    
    @Published var inputDevices: [AudioDevice] = []
    @Published var selectedInputDeviceUID: String?
    
    private init() {
        refreshDevices()
        selectedInputDeviceUID = UserDefaults.standard.string(forKey: "selectedInputDeviceUID")
    }
    
    func refreshDevices() {
        inputDevices = getInputDevices()
    }
    
    func selectDevice(uid: String?) {
        selectedInputDeviceUID = uid
        UserDefaults.standard.set(uid, forKey: "selectedInputDeviceUID")
    }
    
    private func getInputDevices() -> [AudioDevice] {
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
            return []
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
            return []
        }
        
        return deviceIDs.compactMap { deviceID -> AudioDevice? in
            guard hasInputChannels(deviceID: deviceID) else { return nil }
            
            guard let name = getDeviceName(deviceID: deviceID),
                  let uid = getDeviceUID(deviceID: deviceID) else {
                return nil
            }
            
            return AudioDevice(id: deviceID, name: name, uid: uid, isInput: true)
        }
    }
    
    private func hasInputChannels(deviceID: AudioDeviceID) -> Bool {
        var propertySize: UInt32 = 0
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        guard AudioObjectGetPropertyDataSize(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &propertySize
        ) == noErr else {
            return false
        }
        
        let bufferListPointer = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: 1)
        defer { bufferListPointer.deallocate() }
        
        guard AudioObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &propertySize,
            bufferListPointer
        ) == noErr else {
            return false
        }
        
        let bufferList = bufferListPointer.pointee
        return bufferList.mNumberBuffers > 0
    }
    
    private func getDeviceName(deviceID: AudioDeviceID) -> String? {
        var propertySize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var nameUnmanaged: Unmanaged<CFString>?
        let status = withUnsafeMutablePointer(to: &nameUnmanaged) { ptr in
            AudioObjectGetPropertyData(
                deviceID,
                &propertyAddress,
                0,
                nil,
                &propertySize,
                ptr
            )
        }
        
        guard status == noErr, let cfName = nameUnmanaged?.takeRetainedValue() else {
            return nil
        }
        
        return cfName as String
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
}
