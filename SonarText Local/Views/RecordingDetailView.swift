import SwiftUI
import AVKit
import Combine

struct RecordingDetailView: View {
    let recording: Recording
    let onRefresh: () -> Void
    let onDelete: () -> Void
    
    @State private var currentRecording: Recording?
    @State private var transcript: Transcript?
    @State private var analysis: Analysis?
    @State private var parsedAnalysis: MorpheusAnalysisResponse?
    @State private var isTranscribing = false
    @State private var isAnalyzing = false
    @State private var errorMessage: String?
    @State private var showErrorAlert = false
    @State private var showDeleteConfirmation = false
    @State private var refreshTask: Task<Void, Never>?
    @State private var transcriptionStatus: String = ""
    @State private var isEditingTitle = false
    @State private var editedTitle = ""
    @State private var showTimestamps = false
    @State private var showSpeakers = true
    @State private var showSpeakerMappingSheet = false
    @State private var speakerMappings: [String: String] = [:]
    @State private var copiedTranscript = false
    @State private var copiedAnalysis = false
    @State private var analysisMode: AnalysisMode = .meeting
    
    private var displayRecording: Recording {
        currentRecording ?? recording
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                
                if let error = displayRecording.lastError {
                    errorBanner(error)
                }
                
                audioPlayerSection
                
                actionsSection
                
                if let transcript {
                    transcriptSection(transcript)
                }
                
                if let analysis = parsedAnalysis {
                    analysisSection(analysis)
                }
            }
            .padding()
        }
        .task {
            await loadData()
        }
        .onDisappear {
            refreshTask?.cancel()
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK") {
                errorMessage = nil
                showErrorAlert = false
            }
        } message: {
            Text(errorMessage ?? "An error occurred")
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if isEditingTitle {
                    TextField("Title", text: $editedTitle)
                        .font(.title)
                        .textFieldStyle(.plain)
                        .onSubmit { saveTitle() }
                    
                    Button("Save") { saveTitle() }
                    Button("Cancel") { isEditingTitle = false }
                } else {
                    Text(displayRecording.title)
                        .font(.title)
                    
                    Button {
                        editedTitle = displayRecording.title
                        isEditingTitle = true
                    } label: {
                        Image(systemName: "pencil")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                }
            }
            
            HStack(spacing: 16) {
                Label(formattedDate, systemImage: "calendar")
                
                if let duration = displayRecording.durationSeconds {
                    Label(formattedDuration(duration), systemImage: "clock")
                }
                
                Label(sourceDescription, systemImage: "mic")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
    }
    
    private func saveTitle() {
        guard !editedTitle.trimmingCharacters(in: .whitespaces).isEmpty else {
            isEditingTitle = false
            return
        }
        
        var updatedRecording = displayRecording
        updatedRecording.title = editedTitle.trimmingCharacters(in: .whitespaces)
        updatedRecording.updatedAt = Date()
        
        Task {
            do {
                try await DatabaseManager.shared.update(updatedRecording)
                currentRecording = updatedRecording
                isEditingTitle = false
                onRefresh()
            } catch {
                errorMessage = "Failed to rename: \(error.localizedDescription)"
                showErrorAlert = true
            }
        }
    }
    
    private func errorBanner(_ error: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            Text(error)
                .font(.caption)
            Spacer()
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
    }
    
    private var audioPlayerSection: some View {
        GroupBox("Audio") {
            VStack(alignment: .leading, spacing: 12) {
                if let url = audioURL {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(audioSourceLabel)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        AudioPlayerView(url: url)
                    }
                } else {
                    Text("No audio file available")
                        .foregroundColor(.secondary)
                }
                
                if hasMultipleAudioSources {
                    Divider()
                    
                    DisclosureGroup("Individual Tracks") {
                        VStack(alignment: .leading, spacing: 8) {
                            if let micPath = displayRecording.micFilePath,
                               FileManager.default.fileExists(atPath: micPath) {
                                HStack {
                                    Image(systemName: "mic.fill")
                                        .foregroundColor(.blue)
                                    Text("Microphone")
                                        .font(.caption)
                                    Spacer()
                                    Button("Play") {
                                        NSWorkspace.shared.open(URL(fileURLWithPath: micPath))
                                    }
                                    .buttonStyle(.link)
                                    .font(.caption)
                                }
                            }
                            
                            if let systemPath = displayRecording.systemFilePath,
                               FileManager.default.fileExists(atPath: systemPath) {
                                HStack {
                                    Image(systemName: "speaker.wave.2.fill")
                                        .foregroundColor(.green)
                                    Text("System Audio")
                                        .font(.caption)
                                    Spacer()
                                    Button("Play") {
                                        NSWorkspace.shared.open(URL(fileURLWithPath: systemPath))
                                    }
                                    .buttonStyle(.link)
                                    .font(.caption)
                                }
                            }
                        }
                        .padding(.top, 4)
                    }
                    .font(.caption)
                }
            }
        }
    }
    
    private var hasMultipleAudioSources: Bool {
        let hasMic = displayRecording.micFilePath != nil
        let hasSystem = displayRecording.systemFilePath != nil
        return hasMic && hasSystem
    }
    
    private var audioSourceLabel: String {
        if displayRecording.mergedFilePath != nil {
            return "Combined (Mic + System)"
        } else if displayRecording.systemFilePath != nil && displayRecording.micFilePath != nil {
            return "System Audio (merge pending)"
        } else if displayRecording.systemFilePath != nil {
            return "System Audio"
        } else if displayRecording.micFilePath != nil {
            return "Microphone"
        }
        return "Audio"
    }
    
    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Button {
                    Task {
                        await transcribe()
                    }
                } label: {
                    HStack(spacing: 6) {
                        if isTranscribing {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 16, height: 16)
                            Text("Transcribing...")
                        } else {
                            Label("Transcribe", systemImage: "text.bubble")
                        }
                    }
                }
                .disabled(isTranscribing || displayRecording.status == .recording)
                
                Menu {
                    Button {
                        analysisMode = .meeting
                        Task { await analyze() }
                    } label: {
                        Label("Analyze Meeting", systemImage: "person.3")
                    }
                    
                    Button {
                        analysisMode = .speech
                        Task { await analyze() }
                    } label: {
                        Label("Analyze Speech", systemImage: "text.quote")
                    }
                } label: {
                    HStack(spacing: 6) {
                        if isAnalyzing {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 16, height: 16)
                            Text("Analyzing...")
                        } else {
                            Label("Analyze", systemImage: "sparkles")
                        }
                    }
                }
                .disabled(isAnalyzing || transcript == nil)
                
                Spacer()
                
                Button {
                    revealInFinder()
                } label: {
                    Label("Show in Finder", systemImage: "folder")
                }
                
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .confirmationDialog(
                    "Delete Recording?",
                    isPresented: $showDeleteConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Delete", role: .destructive) {
                        Task {
                            await deleteRecording()
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This will permanently delete the recording and all associated files.")
                }
            }
            
            if isTranscribing && !transcriptionStatus.isEmpty {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                    Text(transcriptionStatus)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 4)
            }
        }
    }
    
    private func transcriptSection(_ transcript: Transcript) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Transcript")
                        .font(.headline)
                    
                    Spacer()
                    
                    Toggle("Timestamps", isOn: $showTimestamps)
                        .toggleStyle(.checkbox)
                        .font(.caption)
                    
                    Toggle("Speakers", isOn: $showSpeakers)
                        .toggleStyle(.checkbox)
                        .font(.caption)
                    
                    Button {
                        showSpeakerMappingSheet = true
                    } label: {
                        Image(systemName: "person.2")
                    }
                    .help("Assign speaker names")
                    
                    Button {
                        copyTranscript(transcript)
                    } label: {
                        Image(systemName: copiedTranscript ? "checkmark" : "doc.on.doc")
                    }
                    .help("Copy transcript")
                }
                
                ScrollView {
                    Text(formattedTranscript(transcript))
                        .font(.body)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 200)
            }
        }
        .sheet(isPresented: $showSpeakerMappingSheet) {
            SpeakerMappingSheet(
                transcript: transcript,
                mappings: $speakerMappings,
                onSave: { saveSpeakerMappings() }
            )
        }
    }
    
    private func formattedTranscript(_ transcript: Transcript) -> String {
        guard let jsonData = transcript.jsonBlob,
              let response = try? JSONDecoder().decode(TranscriptionResultResponse.self, from: jsonData),
              let segments = response.segments, !segments.isEmpty else {
            return applyMappingsToText(transcript.text)
        }
        
        var lines: [String] = []
        var currentSpeaker: String? = nil
        var currentText = ""
        var currentStartTime: Double? = nil
        
        for segment in segments {
            let speaker = segment.speaker ?? "Unknown"
            
            if speaker != currentSpeaker {
                if !currentText.isEmpty {
                    lines.append(formatSegmentLine(
                        speaker: currentSpeaker.map { speakerMappings[$0] ?? $0 },
                        startTime: currentStartTime,
                        text: currentText
                    ))
                }
                currentSpeaker = speaker
                currentText = segment.text
                currentStartTime = segment.start
            } else {
                currentText += " " + segment.text
            }
        }
        
        if !currentText.isEmpty {
            lines.append(formatSegmentLine(
                speaker: currentSpeaker.map { speakerMappings[$0] ?? $0 },
                startTime: currentStartTime,
                text: currentText
            ))
        }
        
        return lines.joined(separator: "\n\n")
    }
    
    private func formatSegmentLine(speaker: String?, startTime: Double?, text: String) -> String {
        var prefix = ""
        
        if showTimestamps, let time = startTime {
            let minutes = Int(time) / 60
            let seconds = Int(time) % 60
            prefix += "[\(String(format: "%02d:%02d", minutes, seconds))] "
        }
        
        if showSpeakers, let spk = speaker {
            prefix += "\(spk): "
        }
        
        return prefix + text.trimmingCharacters(in: .whitespaces)
    }
    
    private func applyMappingsToText(_ text: String) -> String {
        var result = text
        for (original, mapped) in speakerMappings {
            result = result.replacingOccurrences(of: original, with: mapped)
        }
        return result
    }
    
    private func copyTranscript(_ transcript: Transcript) {
        let text = formattedTranscript(transcript)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        copiedTranscript = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            copiedTranscript = false
        }
    }
    
    private func analysisSection(_ analysis: MorpheusAnalysisResponse) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Analysis")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button {
                    copyAnalysis(analysis)
                } label: {
                    Image(systemName: copiedAnalysis ? "checkmark" : "doc.on.doc")
                }
                .help("Copy analysis")
            }
            
            if let summary = analysis.summary, !summary.isEmpty {
                GroupBox("Summary") {
                    Text(summary)
                        .textSelection(.enabled)
                }
            }
            
            if let keyPoints = analysis.keyPoints, !keyPoints.isEmpty {
                GroupBox("Key Points") {
                    ForEach(keyPoints.indices, id: \.self) { index in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 6))
                                .foregroundColor(.blue)
                                .padding(.top, 6)
                            Text(keyPoints[index])
                                .textSelection(.enabled)
                        }
                    }
                }
            }
            
            if let actionItems = analysis.actionItems, !actionItems.isEmpty {
                GroupBox("Action Items & Next Steps") {
                    ForEach(actionItems.indices, id: \.self) { index in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle")
                                .foregroundColor(.blue)
                            Text(actionItems[index])
                                .textSelection(.enabled)
                        }
                    }
                }
            }
            
            if let decisions = analysis.decisions, !decisions.isEmpty {
                GroupBox("Decisions Made") {
                    ForEach(decisions.indices, id: \.self) { index in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.green)
                            Text(decisions[index])
                                .textSelection(.enabled)
                        }
                    }
                }
            }
            
            if let questions = analysis.openQuestions, !questions.isEmpty {
                GroupBox("Open Questions") {
                    ForEach(questions.indices, id: \.self) { index in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "questionmark.circle")
                                .foregroundColor(.orange)
                            Text(questions[index])
                                .textSelection(.enabled)
                        }
                    }
                }
            }
            
            if let participants = analysis.participants, !participants.isEmpty {
                GroupBox("Participants") {
                    FlowLayout(spacing: 8) {
                        ForEach(participants, id: \.self) { participant in
                            Text(participant)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.secondary.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                }
            }
            
            if let rawResponse = analysis.rawResponse, !rawResponse.isEmpty,
               analysis.summary == nil && analysis.keyPoints == nil {
                GroupBox("Analysis") {
                    Text(rawResponse)
                        .textSelection(.enabled)
                }
            }
        }
    }
    
    struct FlowLayout: Layout {
        var spacing: CGFloat = 8
        
        func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
            let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
            return layout(sizes: sizes, containerWidth: proposal.width ?? .infinity).size
        }
        
        func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
            let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
            let offsets = layout(sizes: sizes, containerWidth: bounds.width).offsets
            for (offset, subview) in zip(offsets, subviews) {
                subview.place(at: CGPoint(x: bounds.minX + offset.x, y: bounds.minY + offset.y), proposal: .unspecified)
            }
        }
        
        private func layout(sizes: [CGSize], containerWidth: CGFloat) -> (offsets: [CGPoint], size: CGSize) {
            var offsets: [CGPoint] = []
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            var maxWidth: CGFloat = 0
            
            for size in sizes {
                if currentX + size.width > containerWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                offsets.append(CGPoint(x: currentX, y: currentY))
                currentX += size.width + spacing
                lineHeight = max(lineHeight, size.height)
                maxWidth = max(maxWidth, currentX)
            }
            
            return (offsets, CGSize(width: maxWidth, height: currentY + lineHeight))
        }
    }
    
    private var audioURL: URL? {
        if let path = displayRecording.mergedFilePath {
            return URL(fileURLWithPath: path)
        } else if let path = displayRecording.systemFilePath {
            return URL(fileURLWithPath: path)
        } else if let path = displayRecording.micFilePath {
            return URL(fileURLWithPath: path)
        }
        return nil
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: displayRecording.createdAt)
    }
    
    private func formattedDuration(_ seconds: Double) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }
    
    private var sourceDescription: String {
        switch displayRecording.sourceFlags {
        case .microphone:
            return "Microphone"
        case .system:
            return "System Audio"
        case .both:
            return "Mic + System"
        }
    }
    
    private func loadData() async {
        do {
            print("RecordingDetailView: Loading data for recording \(recording.id.uuidString)")
            transcript = try await DatabaseManager.shared.fetchTranscript(forRecordingId: recording.id)
            print("RecordingDetailView: Transcript loaded: \(transcript != nil), text length: \(transcript?.text.count ?? 0)")
            analysis = try await DatabaseManager.shared.fetchAnalysis(forRecordingId: recording.id)
            print("RecordingDetailView: Analysis loaded: \(analysis != nil)")
            
            if let analysisData = analysis?.jsonBlob {
                parsedAnalysis = try? JSONDecoder().decode(MorpheusAnalysisResponse.self, from: analysisData)
                print("RecordingDetailView: Parsed analysis: \(parsedAnalysis != nil)")
            }
        } catch {
            print("RecordingDetailView: loadData error: \(error)")
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }
    
    private func transcribe() async {
        isTranscribing = true
        transcriptionStatus = "Queuing transcription job..."
        
        do {
            try await JobQueue.shared.enqueueTranscription(for: recording.id)
            transcriptionStatus = "Job queued. Processing audio..."
            onRefresh()
            startPollingForCompletion()
        } catch {
            isTranscribing = false
            transcriptionStatus = ""
            errorMessage = "Transcription failed: \(error.localizedDescription)"
            showErrorAlert = true
        }
    }
    
    private func startPollingForCompletion() {
        refreshTask?.cancel()
        let recordingId = recording.id
        refreshTask = Task { @MainActor in
            var pollCount = 0
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                if Task.isCancelled { break }
                
                pollCount += 1
                transcriptionStatus = "Processing... (\(pollCount * 5)s elapsed)"
                
                await loadData()
                
                if transcript != nil {
                    isTranscribing = false
                    transcriptionStatus = ""
                    onRefresh()
                    break
                }
                
                do {
                    if let updatedRecording = try await DatabaseManager.shared.fetch(id: recordingId, type: Recording.self) {
                        if updatedRecording.status == .failed {
                            isTranscribing = false
                            transcriptionStatus = ""
                            errorMessage = updatedRecording.lastError ?? "Transcription failed"
                            showErrorAlert = true
                            onRefresh()
                            break
                        }
                    }
                } catch { }
                
                if pollCount > 180 {
                    isTranscribing = false
                    transcriptionStatus = ""
                    errorMessage = "Transcription timed out. Check console for details."
                    showErrorAlert = true
                    break
                }
            }
        }
    }
    
    private func analyze() async {
        isAnalyzing = true
        
        do {
            try await JobQueue.shared.enqueueAnalysis(for: recording.id, mode: analysisMode)
            startPollingForAnalysis()
        } catch {
            isAnalyzing = false
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }
    
    private func copyAnalysis(_ analysis: MorpheusAnalysisResponse) {
        var text = ""
        
        if let summary = analysis.summary, !summary.isEmpty {
            text += "## Summary\n\(summary)\n\n"
        }
        
        if let keyPoints = analysis.keyPoints, !keyPoints.isEmpty {
            text += "## Key Points\n"
            keyPoints.forEach { text += "- \($0)\n" }
            text += "\n"
        }
        
        if let actionItems = analysis.actionItems, !actionItems.isEmpty {
            text += "## Action Items\n"
            actionItems.forEach { text += "- \($0)\n" }
            text += "\n"
        }
        
        if let decisions = analysis.decisions, !decisions.isEmpty {
            text += "## Decisions\n"
            decisions.forEach { text += "- \($0)\n" }
            text += "\n"
        }
        
        if let questions = analysis.openQuestions, !questions.isEmpty {
            text += "## Open Questions\n"
            questions.forEach { text += "- \($0)\n" }
            text += "\n"
        }
        
        if let participants = analysis.participants, !participants.isEmpty {
            text += "## Participants\n"
            text += participants.joined(separator: ", ")
        }
        
        if let raw = analysis.rawResponse, !raw.isEmpty, text.isEmpty {
            text = raw
        }
        
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        copiedAnalysis = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            copiedAnalysis = false
        }
    }
    
    private func saveSpeakerMappings() {
        Task {
            await loadData()
        }
    }
    
    private func startPollingForAnalysis() {
        refreshTask?.cancel()
        refreshTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                if Task.isCancelled { break }
                
                await loadData()
                
                if parsedAnalysis != nil {
                    isAnalyzing = false
                    onRefresh()
                    break
                }
            }
        }
    }
    
    private func revealInFinder() {
        if let url = audioURL {
            NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
        }
    }
    
    private func deleteRecording() async {
        do {
            print("Deleting recording: \(recording.id)")
            try await DatabaseManager.shared.deleteRecording(recording.id)
            print("Database record deleted")
            try? await FileStorage.shared.deleteRecordingFiles(for: recording.id)
            print("Files deleted")
            onDelete()
        } catch {
            print("Delete failed: \(error)")
            errorMessage = "Failed to delete: \(error.localizedDescription)"
            showErrorAlert = true
        }
    }
}

struct AudioPlayerView: View {
    let url: URL
    
    @StateObject private var playerManager = AudioPlayerManager()
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(url.lastPathComponent)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(playerManager.durationString)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Slider(
                value: $playerManager.currentTime,
                in: 0...max(playerManager.duration, 0.01),
                onEditingChanged: { editing in
                    if !editing {
                        playerManager.seek(to: playerManager.currentTime)
                    }
                }
            )
            .disabled(playerManager.duration == 0)
            
            HStack {
                Text(playerManager.currentTimeString)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button {
                    playerManager.skipBackward(seconds: 10)
                } label: {
                    Image(systemName: "gobackward.10")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .disabled(playerManager.duration == 0)
                
                Button {
                    playerManager.togglePlayback()
                } label: {
                    Image(systemName: playerManager.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.largeTitle)
                }
                .buttonStyle(.plain)
                .disabled(playerManager.duration == 0)
                
                Button {
                    playerManager.skipForward(seconds: 10)
                } label: {
                    Image(systemName: "goforward.10")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .disabled(playerManager.duration == 0)
                
                Spacer()
                
                Text(playerManager.remainingTimeString)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
        .onAppear {
            playerManager.load(url: url)
        }
        .onDisappear {
            playerManager.stop()
        }
    }
}

@MainActor
final class AudioPlayerManager: ObservableObject {
    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    
    private var player: AVPlayer?
    private var timeObserver: Any?
    
    var currentTimeString: String {
        formatTime(currentTime)
    }
    
    var durationString: String {
        formatTime(duration)
    }
    
    var remainingTimeString: String {
        "-" + formatTime(max(0, duration - currentTime))
    }
    
    func load(url: URL) {
        stop()
        
        let asset = AVURLAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)
        player = AVPlayer(playerItem: playerItem)
        
        Task { @MainActor in
            do {
                let loadedDuration = try await asset.load(.duration)
                self.duration = CMTimeGetSeconds(loadedDuration)
                if self.duration.isNaN || self.duration.isInfinite {
                    self.duration = 0
                }
            } catch {
                print("Failed to load duration: \(error)")
            }
        }
        
        timeObserver = player?.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.1, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                let seconds = CMTimeGetSeconds(time)
                if !seconds.isNaN && !seconds.isInfinite {
                    self.currentTime = seconds
                }
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isPlaying = false
                self.currentTime = 0
                self.player?.seek(to: .zero)
            }
        }
    }
    
    func togglePlayback() {
        guard let player else { return }
        
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
    }
    
    func seek(to time: Double) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
    }
    
    func skipForward(seconds: Double) {
        let newTime = min(currentTime + seconds, duration)
        seek(to: newTime)
        currentTime = newTime
    }
    
    func skipBackward(seconds: Double) {
        let newTime = max(currentTime - seconds, 0)
        seek(to: newTime)
        currentTime = newTime
    }
    
    func stop() {
        player?.pause()
        isPlaying = false
        
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        
        player = nil
        currentTime = 0
        duration = 0
    }
    
    private func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN && !seconds.isInfinite && seconds >= 0 else {
            return "0:00"
        }
        
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }
}

struct SpeakerMappingSheet: View {
    let transcript: Transcript
    @Binding var mappings: [String: String]
    let onSave: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var detectedSpeakers: [String] = []
    @State private var localMappings: [String: String] = [:]
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Assign Speaker Names")
                .font(.headline)
            
            if detectedSpeakers.isEmpty {
                Text("No speakers detected in transcript")
                    .foregroundColor(.secondary)
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(detectedSpeakers, id: \.self) { speaker in
                            HStack {
                                Text(speaker)
                                    .frame(width: 100, alignment: .leading)
                                    .foregroundColor(.secondary)
                                
                                Image(systemName: "arrow.right")
                                    .foregroundColor(.secondary)
                                
                                TextField("Enter name", text: binding(for: speaker))
                                    .textFieldStyle(.roundedBorder)
                            }
                        }
                    }
                    .padding()
                }
            }
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                
                Spacer()
                
                Button("Clear All") {
                    localMappings = [:]
                }
                
                Button("Save") {
                    mappings = localMappings.filter { !$0.value.isEmpty }
                    onSave()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 400, height: 300)
        .onAppear {
            loadSpeakers()
            localMappings = mappings
        }
    }
    
    private func binding(for speaker: String) -> Binding<String> {
        Binding(
            get: { localMappings[speaker] ?? "" },
            set: { localMappings[speaker] = $0 }
        )
    }
    
    private func loadSpeakers() {
        guard let jsonData = transcript.jsonBlob,
              let response = try? JSONDecoder().decode(TranscriptionResultResponse.self, from: jsonData),
              let segments = response.segments else {
            return
        }
        
        var speakers = Set<String>()
        for segment in segments {
            if let speaker = segment.speaker {
                speakers.insert(speaker)
            }
        }
        detectedSpeakers = speakers.sorted()
    }
}
