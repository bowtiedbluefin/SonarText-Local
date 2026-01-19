import SwiftUI
import Combine

@main
struct AudioRecorderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()
    @Environment(\.openWindow) private var openWindow
    
    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState)
        } label: {
            Image(systemName: appState.recordingController.state.isRecording ? "record.circle.fill" : "record.circle")
                .symbolRenderingMode(.multicolor)
        }
        
        Window("SonarText Library", id: "library") {
            ContentView()
                .environmentObject(appState)
                .onReceive(NotificationCenter.default.publisher(for: .openLibraryWindow)) { _ in
                    NSApp.activate(ignoringOtherApps: true)
                }
        }
        .defaultSize(width: 800, height: 600)
        
        Window("Settings", id: "settings-fallback") {
            SettingsView()
                .environmentObject(appState)
        }
        .defaultSize(width: 500, height: 400)
        
        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
    
    init() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NotificationCenter.default.post(name: .openLibraryWindow, object: nil)
        }
    }
}

extension Notification.Name {
    static let openLibraryWindow = Notification.Name("openLibraryWindow")
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if let window = NSApp.windows.first(where: { $0.title.contains("Library") }) {
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    let recordingController = RecordingController()
    @Published var configuration = AppConfiguration.load()
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        recordingController.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        Task {
            await initialize()
        }
    }
    
    private func initialize() async {
        do {
            try await DatabaseManager.shared.initialize()
            try await FileStorage.shared.initialize()
            await recordingController.recoverFromCrash()
            
            let transcriptionKey = try? KeychainManager.shared.load(key: .transcriptionApiKey)
            let morpheusKey = try? KeychainManager.shared.load(key: .morpheusApiKey)
            
            print("Configuring JobQueue with transcription URL: \(configuration.transcriptionBaseURL)")
            try? await JobQueue.shared.configure(
                transcriptionBaseURL: configuration.transcriptionBaseURL,
                transcriptionApiKey: transcriptionKey,
                morpheusBaseURL: configuration.morpheusBaseURL,
                morpheusApiKey: morpheusKey ?? ""
            )
        } catch {
            print("Initialization error: \(error)")
        }
    }
}
