import SwiftUI
import AppKit

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.openWindow) private var openWindow
    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            recordingToggle
            
            Divider()
            
            if appState.recordingController.state.isRecording {
                recordingTimer
                consentNotice
                Divider()
            }
            
            if let errorMessage = appState.recordingController.errorMessage {
                errorNotice(errorMessage)
                Divider()
            }
            
            if let warningMessage = appState.recordingController.warningMessage {
                warningNotice(warningMessage)
                Divider()
            }
            
            stateIndicator
            
            Divider()
            
            Button("Open Library") {
                openWindow(id: "library")
                NSApp.activate(ignoringOtherApps: true)
            }
            
            if #available(macOS 14.0, *) {
                SettingsLink {
                    Text("Settings...")
                }
                .keyboardShortcut(",", modifiers: .command)
            } else {
                Button("Settings...") {
                    openWindow(id: "settings-fallback")
                    NSApp.activate(ignoringOtherApps: true)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            
            Divider()
            
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
        .padding(8)
    }
    
    private var recordingToggle: some View {
        Button {
            Task {
                await appState.recordingController.toggle()
            }
        } label: {
            HStack {
                Circle()
                    .fill(appState.recordingController.state.isRecording ? Color.red : Color.gray)
                    .frame(width: 12, height: 12)
                
                Text(appState.recordingController.state.isRecording ? "Stop Recording" : "Start Recording")
            }
        }
        .disabled(!appState.recordingController.state.canStart && !appState.recordingController.state.canStop)
    }
    
    private var recordingTimer: some View {
        HStack {
            Image(systemName: "record.circle")
                .foregroundColor(.red)
            Text(formattedElapsedTime)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.primary)
        }
        .onAppear {
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
        .onChange(of: appState.recordingController.state.isRecording) { isRecording in
            if isRecording {
                startTimer()
            } else {
                stopTimer()
            }
        }
    }
    
    private var formattedElapsedTime: String {
        let hours = Int(elapsedTime) / 3600
        let minutes = (Int(elapsedTime) % 3600) / 60
        let seconds = Int(elapsedTime) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    private func startTimer() {
        stopTimer()
        let startTime = appState.recordingController.recordingStartTime ?? Date()
        elapsedTime = Date().timeIntervalSince(startTime)
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                elapsedTime = Date().timeIntervalSince(startTime)
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        elapsedTime = 0
    }
    
    private var consentNotice: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Recording in progress", systemImage: "waveform")
                .font(.caption)
                .foregroundColor(.red)
            
            Text("Ensure all participants have consented to recording.")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    private func errorNotice(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Error", systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundColor(.red)
            
            Text(message)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(3)
        }
    }
    
    private func warningNotice(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Warning", systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundColor(.orange)
            
            Text(message)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(3)
        }
    }
    
    private var stateIndicator: some View {
        HStack {
            Text("State:")
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(stateDescription)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    private var stateDescription: String {
        switch appState.recordingController.state {
        case .idle:
            return "Ready"
        case .starting:
            return "Starting..."
        case .recording:
            return "Recording"
        case .stopping:
            return "Stopping..."
        case .error(let msg):
            return "Error: \(msg)"
        }
    }
    
}
