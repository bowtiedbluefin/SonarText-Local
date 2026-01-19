import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var recordings: [Recording] = []
    @State private var folders: [Folder] = []
    @State private var selectedRecordingId: UUID?
    @State private var selectedFolderId: UUID?
    @State private var errorMessage: String?
    @State private var showErrorAlert = false
    @State private var showNewFolderAlert = false
    @State private var newFolderName = ""
    @State private var showMoveSheet = false
    @State private var recordingToMove: Recording?
    
    private var selectedRecording: Recording? {
        guard let id = selectedRecordingId else { return nil }
        return recordings.first { $0.id == id }
    }
    
    private var selectedFolder: Folder? {
        guard let id = selectedFolderId else { return nil }
        return folders.first { $0.id == id }
    }
    
    var body: some View {
        NavigationSplitView {
            libraryList
        } detail: {
            if let recording = selectedRecording {
                RecordingDetailView(
                    recording: recording,
                    onRefresh: loadRecordings,
                    onDelete: {
                        selectedRecordingId = nil
                        loadRecordings()
                    }
                )
                .id(recording.id)
            } else {
                Text("Select a recording")
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Audio Recorder")
        .task {
            loadRecordings()
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
    
    private var libraryList: some View {
        List(selection: $selectedRecordingId) {
            Section("Folders") {
                HStack {
                    Image(systemName: selectedFolderId == nil ? "tray.full.fill" : "tray.full")
                        .foregroundColor(selectedFolderId == nil ? .accentColor : .secondary)
                    Text("All Recordings")
                        .fontWeight(selectedFolderId == nil ? .semibold : .regular)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedFolderId = nil
                }
                
                ForEach(folders) { folder in
                    FolderRow(folder: folder, isSelected: selectedFolderId == folder.id)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedFolderId == folder.id {
                                selectedFolderId = nil
                            } else {
                                selectedFolderId = folder.id
                            }
                        }
                        .onDrop(of: [.text], isTargeted: nil) { providers in
                            handleDrop(providers: providers, toFolderId: folder.id)
                        }
                        .contextMenu {
                            Button("Delete Folder") {
                                Task { await deleteFolder(folder) }
                            }
                        }
                }
                
                Button {
                    showNewFolderAlert = true
                } label: {
                    Label("New Folder", systemImage: "folder.badge.plus")
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
            
            Section(selectedFolder?.name ?? "All Recordings") {
                ForEach(filteredRecordings) { recording in
                    RecordingRow(recording: recording)
                        .tag(recording.id)
                        .draggable(recording.id.uuidString)
                        .contextMenu {
                            Button("Move to Folder...") {
                                recordingToMove = recording
                                showMoveSheet = true
                            }
                            if recording.folderId != nil {
                                Button("Remove from Folder") {
                                    Task { await removeFromFolder(recording) }
                                }
                            }
                        }
                }
            }
        }
        .listStyle(.sidebar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task {
                        await appState.recordingController.toggle()
                        try? await Task.sleep(nanoseconds: 500_000_000)
                        loadRecordings()
                    }
                } label: {
                    Image(systemName: appState.recordingController.state.isRecording ? "stop.circle.fill" : "record.circle")
                        .foregroundColor(appState.recordingController.state.isRecording ? .red : .primary)
                }
                .help(appState.recordingController.state.isRecording ? "Stop Recording" : "Start Recording")
            }
            
            ToolbarItem(placement: .automatic) {
                Button {
                    loadRecordings()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh")
            }
        }
        .alert("New Folder", isPresented: $showNewFolderAlert) {
            TextField("Folder name", text: $newFolderName)
            Button("Cancel", role: .cancel) { newFolderName = "" }
            Button("Create") {
                Task { await createFolder() }
            }
        }
        .sheet(isPresented: $showMoveSheet) {
            if let recording = recordingToMove {
                MoveToFolderSheet(recording: recording, folders: folders) { folderId in
                    Task { await moveToFolder(recording, folderId: folderId) }
                }
            }
        }
    }
    
    private func handleDrop(providers: [NSItemProvider], toFolderId: UUID) -> Bool {
        for provider in providers {
            provider.loadObject(ofClass: NSString.self) { item, _ in
                guard let uuidString = item as? String,
                      let recordingId = UUID(uuidString: uuidString),
                      let recording = recordings.first(where: { $0.id == recordingId }) else {
                    return
                }
                Task { @MainActor in
                    await moveToFolder(recording, folderId: toFolderId)
                }
            }
        }
        return true
    }
    
    private var filteredRecordings: [Recording] {
        if let folderId = selectedFolderId {
            return recordings.filter { $0.folderId == folderId }
        }
        return recordings
    }
    
    private func createFolder() async {
        guard !newFolderName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let folder = Folder(name: newFolderName.trimmingCharacters(in: .whitespaces))
        do {
            try await DatabaseManager.shared.insert(folder)
            newFolderName = ""
            loadRecordings()
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }
    
    private func deleteFolder(_ folder: Folder) async {
        do {
            try await DatabaseManager.shared.delete(folder)
            if selectedFolderId == folder.id {
                selectedFolderId = nil
            }
            loadRecordings()
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }
    
    private func moveToFolder(_ recording: Recording, folderId: UUID?) async {
        var updated = recording
        updated.folderId = folderId
        updated.updatedAt = Date()
        do {
            try await DatabaseManager.shared.update(updated)
            showMoveSheet = false
            recordingToMove = nil
            loadRecordings()
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }
    
    private func removeFromFolder(_ recording: Recording) async {
        await moveToFolder(recording, folderId: nil)
    }
    
    private func loadRecordings() {
        Task {
            do {
                print("ContentView: Loading recordings...")
                recordings = try await DatabaseManager.shared.fetchRecordings()
                folders = try await DatabaseManager.shared.fetchAll(Folder.self)
                print("ContentView: Loaded \(recordings.count) recordings, \(folders.count) folders")
                if let selectedId = selectedRecordingId {
                    if !recordings.contains(where: { $0.id == selectedId }) {
                        selectedRecordingId = nil
                    }
                }
            } catch {
                print("ContentView: Failed to load recordings: \(error)")
                errorMessage = error.localizedDescription
                showErrorAlert = true
            }
        }
    }
}

struct FolderRow: View {
    let folder: Folder
    let isSelected: Bool
    
    var body: some View {
        HStack {
            Image(systemName: isSelected ? "folder.fill" : "folder")
                .foregroundColor(isSelected ? .accentColor : .secondary)
            Text(folder.name)
                .fontWeight(isSelected ? .semibold : .regular)
        }
    }
}

struct MoveToFolderSheet: View {
    let recording: Recording
    let folders: [Folder]
    let onMove: (UUID?) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Move to Folder")
                .font(.headline)
            
            List {
                Button("No Folder (Root)") {
                    onMove(nil)
                    dismiss()
                }
                
                ForEach(folders) { folder in
                    Button(folder.name) {
                        onMove(folder.id)
                        dismiss()
                    }
                }
            }
            .frame(height: 200)
            
            Button("Cancel") {
                dismiss()
            }
        }
        .padding()
        .frame(width: 300, height: 300)
    }
}

struct RecordingRow: View {
    let recording: Recording
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(recording.title)
                .font(.headline)
                .lineLimit(1)
            
            HStack(spacing: 8) {
                Text(formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let duration = recording.durationSeconds {
                    Text(formattedDuration(duration))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                statusBadge
            }
        }
        .padding(.vertical, 4)
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: recording.createdAt)
    }
    
    private func formattedDuration(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }
    
    private var statusBadge: some View {
        Group {
            switch recording.status {
            case .recording:
                Label("Recording", systemImage: "waveform")
                    .foregroundColor(.red)
            case .recorded:
                Label("Ready", systemImage: "checkmark.circle")
                    .foregroundColor(.green)
            case .transcribing:
                Label("Transcribing", systemImage: "text.bubble")
                    .foregroundColor(.orange)
            case .transcribed:
                Label("Transcribed", systemImage: "doc.text")
                    .foregroundColor(.blue)
            case .analyzing:
                Label("Analyzing", systemImage: "brain")
                    .foregroundColor(.purple)
            case .analyzed:
                Label("Analyzed", systemImage: "sparkles")
                    .foregroundColor(.purple)
            case .failed:
                Label("Failed", systemImage: "exclamationmark.triangle")
                    .foregroundColor(.red)
            case .incomplete:
                Label("Incomplete", systemImage: "exclamationmark.circle")
                    .foregroundColor(.orange)
            }
        }
        .font(.caption2)
    }
}
