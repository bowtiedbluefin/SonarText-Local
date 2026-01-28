import SwiftUI

struct LocalHostingTabView: View {
    var body: some View {
        if AppDistribution.isAppStore {
            AppStoreLocalHostingView()
        } else {
            DirectLocalHostingView()
        }
    }
}

struct AppStoreLocalHostingView: View {
    private let githubURL = "https://github.com/bowtiedbluefin/SonarText-Local"
    private let releasesURL = "https://github.com/bowtiedbluefin/SonarText-Local/releases"
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "desktopcomputer")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("Local Transcription")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Run transcription locally without sending audio to external servers. This feature requires Docker Desktop and is only available in the direct download version.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 32)
            
            Divider()
                .padding(.horizontal, 48)
            
            VStack(spacing: 16) {
                Text("Get the Direct Download Version")
                    .font(.headline)
                
                HStack(spacing: 16) {
                    Link(destination: URL(string: releasesURL)!) {
                        HStack {
                            Image(systemName: "arrow.down.circle.fill")
                            Text("Download Latest Release")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .padding(.horizontal, 48)
                
                Link(destination: URL(string: githubURL)!) {
                    HStack {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                        Text("View on GitHub")
                    }
                }
                .font(.callout)
            }
            
            Divider()
                .padding(.horizontal, 48)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Why Direct Download?")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 4) {
                    BulletPoint(text: "macOS App Store apps run in a sandbox that prevents Docker access")
                    BulletPoint(text: "The direct version can communicate with Docker Desktop")
                    BulletPoint(text: "All other features work identically in both versions")
                }
                .font(.callout)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 32)
            
            Spacer()
        }
        .padding()
    }
}

struct BulletPoint: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
            Text(text)
        }
    }
}

struct DirectLocalHostingView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var manager = LocalHostingManager.shared
    @State private var hfToken: String = ""
    @State private var showLogs = false
    @State private var showRemoveConfirmation = false
    @State private var errorMessage: String?
    @State private var showError = false
    
    var body: some View {
        Form {
            statusSection
            
            switch manager.state {
            case .notInstalled:
                setupSection
            case .downloading:
                downloadingSection
            case .stopped, .running, .starting, .stopping:
                controlsSection
            case .error(let message):
                errorSection(message)
            }
            
            if manager.isInstalled {
                requirementsSection
            }
        }
        .padding()
        .onAppear {
            loadHFToken()
            Task {
                await manager.checkStatus()
            }
        }
        .sheet(isPresented: $showLogs) {
            LogsSheetView(manager: manager)
        }
        .alert("Remove Local Server?", isPresented: $showRemoveConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) {
                Task {
                    try? await manager.remove()
                }
            }
        } message: {
            Text("This will remove the local transcription server and free up disk space. You can reinstall it later.")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
        }
    }
    
    private var statusSection: some View {
        Section {
            HStack {
                statusIndicator
                VStack(alignment: .leading, spacing: 4) {
                    Text(statusTitle)
                        .font(.headline)
                    Text(statusSubtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
        }
    }
    
    @ViewBuilder
    private var statusIndicator: some View {
        switch manager.state {
        case .running:
            Circle()
                .fill(.green)
                .frame(width: 12, height: 12)
        case .starting, .stopping, .downloading:
            ProgressView()
                .scaleEffect(0.7)
                .frame(width: 12, height: 12)
        case .stopped:
            Circle()
                .fill(.orange)
                .frame(width: 12, height: 12)
        case .error:
            Circle()
                .fill(.red)
                .frame(width: 12, height: 12)
        case .notInstalled:
            Circle()
                .strokeBorder(.secondary, lineWidth: 2)
                .frame(width: 12, height: 12)
        }
    }
    
    private var statusTitle: String {
        switch manager.state {
        case .running:
            return "Running on localhost:\(LocalHostingManager.port)"
        case .starting:
            return "Starting..."
        case .stopping:
            return "Stopping..."
        case .stopped:
            return "Stopped"
        case .downloading(_, let status):
            return status
        case .error:
            return "Error"
        case .notInstalled:
            return "Not Installed"
        }
    }
    
    private var statusSubtitle: String {
        switch manager.state {
        case .running:
            return "Ready for transcription"
        case .starting:
            return "Please wait..."
        case .stopping:
            return "Please wait..."
        case .stopped:
            return "Click Start to begin"
        case .downloading(let progress, _):
            return "\(Int(progress * 100))% complete"
        case .error(let msg):
            return msg
        case .notInstalled:
            return "Set up local transcription below"
        }
    }
    
    private var setupSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 16) {
                Text("Run transcription locally without sending audio to external servers. Requires Docker Desktop.")
                    .font(.callout)
                    .foregroundColor(.secondary)
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Select Model")
                        .font(.headline)
                    
                    ForEach(LocalHostingManager.WhisperModel.allCases) { model in
                        HStack {
                            Image(systemName: manager.selectedModel == model ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(manager.selectedModel == model ? .accentColor : .secondary)
                            
                            VStack(alignment: .leading) {
                                Text(model.displayName)
                                    .fontWeight(.medium)
                                Text(model.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Text(model.estimatedSize)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            manager.selectedModel = model
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("HuggingFace Token (Optional)")
                        .font(.headline)
                    
                    SecureField("Token for speaker diarization", text: $hfToken)
                        .textFieldStyle(.roundedBorder)
                    
                    Link("Get token at huggingface.co", destination: URL(string: "https://huggingface.co/settings/tokens")!)
                        .font(.caption)
                }
                
                Divider()
                
                Button(action: downloadAndInstall) {
                    HStack {
                        Image(systemName: "arrow.down.circle")
                        Text("Download & Setup Local Server")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
    }
    
    private var downloadingSection: some View {
        Section {
            if case .downloading(let progress, let status) = manager.state {
                VStack(alignment: .leading, spacing: 12) {
                    Text(status)
                        .font(.headline)
                    
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                    
                    Text("\(Int(progress * 100))% complete")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var controlsSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    if manager.state.canStart {
                        Button(action: startServer) {
                            Label("Start", systemImage: "play.fill")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    
                    if manager.state.canStop {
                        Button(action: stopServer) {
                            Label("Stop", systemImage: "stop.fill")
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    if manager.state == .running {
                        Button(action: restartServer) {
                            Label("Restart", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    Button(action: { showLogs = true }) {
                        Label("Logs", systemImage: "doc.text")
                    }
                    .buttonStyle(.bordered)
                }
                
                if manager.state == .running {
                    HStack {
                        Text("Endpoint:")
                            .foregroundColor(.secondary)
                        Text(manager.serverURL)
                            .font(.system(.body, design: .monospaced))
                        Button(action: copyEndpoint) {
                            Image(systemName: "doc.on.doc")
                        }
                        .buttonStyle(.borderless)
                    }
                    .font(.callout)
                }
                
                Divider()
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("Model: \(manager.selectedModel.displayName)")
                        Text("Device: CPU")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button("Remove Server", role: .destructive) {
                        showRemoveConfirmation = true
                    }
                    .font(.caption)
                }
            }
        }
    }
    
    private func errorSection(_ message: String) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(message)
                        .foregroundColor(.red)
                }
                
                HStack {
                    Button("Retry") {
                        Task {
                            try? await manager.restart()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("View Logs") {
                        showLogs = true
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Remove", role: .destructive) {
                        showRemoveConfirmation = true
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }
    
    private var requirementsSection: some View {
        Section("Requirements") {
            RequirementRow(title: "Docker Desktop", isRequired: true, isMet: true)
            RequirementRow(title: "Disk Space (~\(manager.selectedModel.estimatedSize))", isRequired: true, isMet: true)
            RequirementRow(
                title: "HuggingFace Token",
                isRequired: true,
                isMet: !hfToken.isEmpty,
                subtitle: "Required for speaker diarization"
            )
        }
    }
    
    private func downloadAndInstall() {
        saveHFToken()
        Task {
            do {
                try await manager.downloadAndInstall(hfToken: hfToken.isEmpty ? nil : hfToken)
                try await manager.start()
                
                await configureLocalServer()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    private func configureLocalServer() async {
        guard manager.state == .running else { return }
        
        appState.configuration.transcriptionBaseURL = manager.serverURL
        appState.configuration.save()
        
        let transcriptionKey = try? KeychainManager.shared.load(key: .transcriptionApiKey)
        try? await JobQueue.shared.configure(
            transcriptionBaseURL: manager.serverURL,
            transcriptionApiKey: transcriptionKey,
            morpheusBaseURL: appState.configuration.morpheusBaseURL,
            morpheusApiKey: (try? KeychainManager.shared.load(key: .morpheusApiKey)) ?? ""
        )
        
        print("LocalHostingTabView: Configured app to use local server at \(manager.serverURL)")
    }
    
    private func startServer() {
        Task {
            do {
                try await manager.start()
                await configureLocalServer()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    private func stopServer() {
        Task {
            do {
                try await manager.stop()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    private func restartServer() {
        Task {
            do {
                try await manager.restart()
                await configureLocalServer()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    private func copyEndpoint() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(manager.serverURL, forType: .string)
    }
    
    private func loadHFToken() {
        hfToken = (try? KeychainManager.shared.load(key: .huggingFaceToken)) ?? ""
    }
    
    private func saveHFToken() {
        if !hfToken.isEmpty {
            try? KeychainManager.shared.save(key: .huggingFaceToken, value: hfToken)
        }
    }
}

struct RequirementRow: View {
    let title: String
    let isRequired: Bool
    let isMet: Bool
    var subtitle: String? = nil
    
    var body: some View {
        HStack {
            Image(systemName: isMet ? "checkmark.circle.fill" : (isRequired ? "xmark.circle" : "circle"))
                .foregroundColor(isMet ? .green : (isRequired ? .red : .secondary))
            
            VStack(alignment: .leading) {
                Text(title)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

struct LogsSheetView: View {
    @ObservedObject var manager: LocalHostingManager
    @Environment(\.dismiss) private var dismiss
    @State private var autoScroll = true
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Container Logs")
                    .font(.headline)
                
                Spacer()
                
                Toggle("Auto-scroll", isOn: $autoScroll)
                    .toggleStyle(.checkbox)
                
                Button("Refresh") {
                    Task {
                        await manager.fetchLogs()
                    }
                }
                
                Button("Clear") {
                    manager.clearLogs()
                }
                
                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
            }
            .padding()
            
            Divider()
            
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(manager.logs.enumerated()), id: \.offset) { index, line in
                            Text(line)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(logColor(for: line))
                                .textSelection(.enabled)
                                .id(index)
                        }
                    }
                    .padding()
                }
                .background(Color(nsColor: .textBackgroundColor))
                .onChange(of: manager.logs.count) { _ in
                    if autoScroll, let lastIndex = manager.logs.indices.last {
                        proxy.scrollTo(lastIndex, anchor: .bottom)
                    }
                }
            }
        }
        .frame(width: 700, height: 500)
        .onAppear {
            Task {
                await manager.fetchLogs()
            }
        }
    }
    
    private func logColor(for line: String) -> Color {
        let lowercased = line.lowercased()
        if lowercased.contains("error") || lowercased.contains("exception") {
            return .red
        } else if lowercased.contains("warning") || lowercased.contains("warn") {
            return .orange
        } else if lowercased.contains("info") {
            return .primary
        }
        return .secondary
    }
}
