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
            if appState.recordingController.state.isRecording {
                Image(systemName: "record.circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.red, .red)
            } else {
                Image(systemName: "record.circle")
            }
        }
        
        Window("SonarText Library", id: "library") {
            LibraryWindowContent()
                .environmentObject(appState)
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
    
    init() {}
}

struct LibraryWindowContent: View {
    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        ContentView()
            .onAppear {
                AppDelegate.openWindowAction = openWindow
                NSApp.activate(ignoringOtherApps: true)
            }
    }
}



extension Notification.Name {
    static let openLibraryWindow = Notification.Name("openLibraryWindow")
}

class AppDelegate: NSObject, NSApplicationDelegate {
    static var openWindowAction: OpenWindowAction?
    private var hasLaunched = false
    
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        hasLaunched = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            Self.showLibraryWindow()
        }
    }
    
    func applicationDidBecomeActive(_ notification: Notification) {
        guard hasLaunched else { return }
        Self.showLibraryWindow()
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        Self.showLibraryWindow()
        return true
    }
    
    static func showLibraryWindow() {
        if let window = NSApp.windows.first(where: { $0.title.contains("Library") }) {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        } else if let openWindow = openWindowAction {
            openWindow(id: "library")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if let window = NSApp.windows.first(where: { $0.title.contains("Library") }) {
                    window.makeKeyAndOrderFront(nil)
                }
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
            
            await initializeLocalHosting()
            
            let transcriptionURL = configuration.transcriptionBaseURL
            print("Configuring JobQueue with transcription URL: \(transcriptionURL)")
            try? await JobQueue.shared.configure(
                transcriptionBaseURL: transcriptionURL,
                transcriptionApiKey: transcriptionKey,
                morpheusBaseURL: configuration.morpheusBaseURL,
                morpheusApiKey: morpheusKey ?? ""
            )
        } catch {
            print("Initialization error: \(error)")
        }
    }
    
    private func initializeLocalHosting() async {
        let localHosting = LocalHostingManager.shared
        
        await localHosting.checkStatus()
        
        if localHosting.isInstalled {
            print("Local server installed, attempting auto-start...")
            do {
                try await localHosting.start()
                
                if localHosting.state == .running {
                    configuration.transcriptionBaseURL = localHosting.serverURL
                    configuration.save()
                    print("Local transcription server started and configured: \(localHosting.serverURL)")
                }
            } catch {
                print("Failed to auto-start local server: \(error)")
            }
        }
    }
}
