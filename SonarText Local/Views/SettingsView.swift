import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var audioDeviceManager = AudioDeviceManager.shared
    
    @State private var transcriptionURL: String = ""
    @State private var morpheusURL: String = ""
    @State private var transcriptionApiKey: String = ""
    @State private var morpheusApiKey: String = ""
    @State private var showSavedMessage = false
    @State private var showDeleteAllConfirmation = false
    
    var body: some View {
        TabView {
            audioSettingsTab
                .tabItem {
                    Label("Audio", systemImage: "mic")
                }
            
            apiSettingsTab
                .tabItem {
                    Label("API", systemImage: "network")
                }
            
            permissionsTab
                .tabItem {
                    Label("Permissions", systemImage: "lock.shield")
                }
            
            aboutTab
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 500, height: 450)
        .onAppear {
            loadSettings()
            audioDeviceManager.refreshDevices()
        }
    }
    
    private var audioSettingsTab: some View {
        Form {
            Section("Microphone Input") {
                Picker("Input Device", selection: Binding(
                    get: { audioDeviceManager.selectedInputDeviceUID ?? "" },
                    set: { audioDeviceManager.selectDevice(uid: $0.isEmpty ? nil : $0) }
                )) {
                    Text("System Default").tag("")
                    ForEach(audioDeviceManager.inputDevices) { device in
                        Text(device.name).tag(device.uid)
                    }
                }
                .pickerStyle(.menu)
                
                Button("Refresh Devices") {
                    audioDeviceManager.refreshDevices()
                }
            }
            
            Section("Recording Options") {
                Toggle("Record Microphone", isOn: .constant(true))
                    .disabled(true)
                
                Toggle("Record System Audio", isOn: .constant(true))
                    .disabled(true)
                
                Text("Both mic and system audio are recorded. System audio requires Screen Recording permission.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
    
    private var apiSettingsTab: some View {
        Form {
            Section("Transcription Service") {
                TextField("Base URL", text: $transcriptionURL)
                    .textFieldStyle(.roundedBorder)
                
                SecureField("API Key (optional)", text: $transcriptionApiKey)
                    .textFieldStyle(.roundedBorder)
            }
            
            Section("Morpheus API") {
                TextField("Base URL", text: $morpheusURL)
                    .textFieldStyle(.roundedBorder)
                
                SecureField("API Key", text: $morpheusApiKey)
                    .textFieldStyle(.roundedBorder)
            }
            
            Section {
                HStack {
                    Spacer()
                    
                    if showSavedMessage {
                        Text("Settings saved!")
                            .foregroundColor(.green)
                    }
                    
                    Button("Save") {
                        saveSettings()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding()
    }
    
    private var permissionsTab: some View {
        Form {
            Section("Required Permissions") {
                PermissionRow(
                    title: "Microphone",
                    description: "Required for recording audio from your microphone",
                    systemImage: "mic.fill"
                )
                
                PermissionRow(
                    title: "Screen Recording",
                    description: "Required for capturing system audio (Zoom, other apps)",
                    systemImage: "rectangle.on.rectangle"
                )
            }
            
            Section {
                Button("Open System Settings") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!)
                }
            }
        }
        .padding()
    }
    
    private var aboutTab: some View {
        VStack(spacing: 20) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)
            
            Text("SonarText Local")
                .font(.title)
            
            Text("Build 2025.01.24.1")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("Record, transcribe, and analyze audio")
                .foregroundColor(.secondary)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Consent Notice")
                    .font(.headline)
                
                Text("Recording conversations may require consent from all participants depending on your jurisdiction. Always ensure you have appropriate permissions before recording.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.yellow.opacity(0.1))
            .cornerRadius(8)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Data Management")
                    .font(.headline)
                
                Button("Delete All Recordings", role: .destructive) {
                    showDeleteAllConfirmation = true
                }
                .confirmationDialog(
                    "Delete All Recordings?",
                    isPresented: $showDeleteAllConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Delete All", role: .destructive) {
                        Task {
                            await deleteAllData()
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This will permanently delete all recordings, transcripts, and analysis data. This cannot be undone.")
                }
                
                Button("Open Data Folder") {
                    if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                        let appDir = appSupport.appendingPathComponent("AudioRecorder")
                        NSWorkspace.shared.open(appDir)
                    }
                }
            }
            
            Spacer()
        }
        .padding()
    }
    
    private func loadSettings() {
        transcriptionURL = appState.configuration.transcriptionBaseURL
        morpheusURL = appState.configuration.morpheusBaseURL
        
        transcriptionApiKey = (try? KeychainManager.shared.load(key: .transcriptionApiKey)) ?? ""
        morpheusApiKey = (try? KeychainManager.shared.load(key: .morpheusApiKey)) ?? ""
    }
    
    private func saveSettings() {
        appState.configuration.transcriptionBaseURL = transcriptionURL
        appState.configuration.morpheusBaseURL = morpheusURL
        appState.configuration.save()
        
        if !transcriptionApiKey.isEmpty {
            try? KeychainManager.shared.save(key: .transcriptionApiKey, value: transcriptionApiKey)
        }
        
        if !morpheusApiKey.isEmpty {
            try? KeychainManager.shared.save(key: .morpheusApiKey, value: morpheusApiKey)
        }
        
        Task {
            try? await JobQueue.shared.configure(
                transcriptionBaseURL: transcriptionURL,
                transcriptionApiKey: transcriptionApiKey.isEmpty ? nil : transcriptionApiKey,
                morpheusBaseURL: morpheusURL,
                morpheusApiKey: morpheusApiKey
            )
        }
        
        showSavedMessage = true
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            showSavedMessage = false
        }
    }
    
    private func deleteAllData() async {
        do {
            let recordings = try await DatabaseManager.shared.fetchRecordings()
            for recording in recordings {
                try await DatabaseManager.shared.deleteRecording(recording.id)
                try? await FileStorage.shared.deleteRecordingFiles(for: recording.id)
            }
            print("SettingsView: Deleted all \(recordings.count) recordings")
        } catch {
            print("SettingsView: Failed to delete all data: \(error)")
        }
    }
}

struct PermissionRow: View {
    let title: String
    let description: String
    let systemImage: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.title2)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
