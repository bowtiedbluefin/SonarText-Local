import AVFoundation

actor AudioMerger {
    static let shared = AudioMerger()
    
    private init() {}
    
    func mergeAudioFiles(micURL: URL, systemURL: URL, outputURL: URL) async throws {
        print("Merging audio files...")
        print("  Mic: \(micURL.path)")
        print("  System: \(systemURL.path)")
        print("  Output: \(outputURL.path)")
        
        let composition = AVMutableComposition()
        
        let micAsset = AVURLAsset(url: micURL)
        let systemAsset = AVURLAsset(url: systemURL)
        
        let micDuration = try await micAsset.load(.duration)
        let systemDuration = try await systemAsset.load(.duration)
        let maxDuration = CMTimeMaximum(micDuration, systemDuration)
        
        print("  Mic duration: \(CMTimeGetSeconds(micDuration))s")
        print("  System duration: \(CMTimeGetSeconds(systemDuration))s")
        
        if let micTrack = try await micAsset.loadTracks(withMediaType: .audio).first {
            if let compositionMicTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) {
                try compositionMicTrack.insertTimeRange(
                    CMTimeRange(start: .zero, duration: micDuration),
                    of: micTrack,
                    at: .zero
                )
            }
        }
        
        if let systemTrack = try await systemAsset.loadTracks(withMediaType: .audio).first {
            if let compositionSystemTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) {
                try compositionSystemTrack.insertTimeRange(
                    CMTimeRange(start: .zero, duration: systemDuration),
                    of: systemTrack,
                    at: .zero
                )
            }
        }
        
        let audioMix = AVMutableAudioMix()
        var inputParameters: [AVMutableAudioMixInputParameters] = []
        
        for track in composition.tracks(withMediaType: .audio) {
            let parameters = AVMutableAudioMixInputParameters(track: track)
            parameters.setVolume(1.0, at: .zero)
            inputParameters.append(parameters)
        }
        audioMix.inputParameters = inputParameters
        
        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            throw AudioMergerError.exportSessionCreationFailed
        }
        
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a
        exportSession.audioMix = audioMix
        exportSession.timeRange = CMTimeRange(start: .zero, duration: maxDuration)
        
        try await exportSession.export(to: outputURL, as: .m4a)
        
        print("Audio merge completed successfully")
        
        if let attributes = try? FileManager.default.attributesOfItem(atPath: outputURL.path),
           let fileSize = attributes[.size] as? Int64 {
            print("  Merged file size: \(fileSize) bytes")
        }
    }
    
    func mergeIfNeeded(
        micPath: String?,
        systemPath: String?,
        outputURL: URL
    ) async throws -> URL? {
        let micExists = micPath.map { FileManager.default.fileExists(atPath: $0) } ?? false
        let systemExists = systemPath.map { FileManager.default.fileExists(atPath: $0) } ?? false
        
        if micExists && systemExists {
            let micURL = URL(fileURLWithPath: micPath!)
            let systemURL = URL(fileURLWithPath: systemPath!)
            try await mergeAudioFiles(micURL: micURL, systemURL: systemURL, outputURL: outputURL)
            return outputURL
        } else if systemExists {
            return URL(fileURLWithPath: systemPath!)
        } else if micExists {
            return URL(fileURLWithPath: micPath!)
        }
        
        return nil
    }
}

enum AudioMergerError: LocalizedError {
    case exportSessionCreationFailed
    case exportFailed(String)
    case exportCancelled
    case noAudioTracks
    
    var errorDescription: String? {
        switch self {
        case .exportSessionCreationFailed:
            return "Failed to create audio export session"
        case .exportFailed(let message):
            return "Audio merge failed: \(message)"
        case .exportCancelled:
            return "Audio merge was cancelled"
        case .noAudioTracks:
            return "No audio tracks found to merge"
        }
    }
}
