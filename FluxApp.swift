import SwiftUI

// MARK: - App Delegate for handling Finder "Open With"

#if os(macOS)
    class AppDelegate: NSObject, NSApplicationDelegate {
        func application(_ application: NSApplication, open urls: [URL]) {
            // Handle files opened via Finder "Open With"
            for url in urls {
                if url.isFileURL {
                    AppState.shared.handleOpenURL(url)
                }
            }
        }
    }
#endif

@main
struct FluxApp: App {
    #if os(macOS)
        @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif

    @StateObject private var appState = AppState.shared
    @StateObject private var themeManager = ThemeManager.shared
    @AppStorage("hasCompletedFirstBoot") private var hasCompletedFirstBoot = false
    @State private var showUpdateAlert = false

    init() {
        // Ensure app data directories exist
        SettingsManager.shared.setupDirectories()

        // Initialize logging system (through AppState spine)
        AppState.shared.log("App launched", category: .engine)
        
        // Health monitoring is auto-started by AppState
        AppState.shared.log("System health monitoring enabled", category: .engine)

        // Load saved theme
        ThemeManager.shared.loadTheme()

        // Set window to 80% of screen size on launch
        #if os(macOS)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if let window = NSApplication.shared.windows.first,
                    let screen = NSScreen.main
                {
                    let screenFrame = screen.visibleFrame
                    let width = screenFrame.width * 0.8
                    let height = screenFrame.height * 0.8
                    let x = screenFrame.origin.x + (screenFrame.width - width) / 2
                    let y = screenFrame.origin.y + (screenFrame.height - height) / 2
                    window.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
                }
            }
        #endif
    }

    var body: some Scene {
        WindowGroup("OpenFlux", id: "main") {
            if hasCompletedFirstBoot {
                ContentView()
                    .environmentObject(appState)
                    .environmentObject(themeManager)
                    .onOpenURL { url in
                        appState.handleOpenURL(url)
                    }
                    .onChange(of: appState.updateAvailable) { newValue in
                        if newValue {
                            showUpdateAlert = true
                        }
                    }
                    .alert("📦 Updates Available", isPresented: $showUpdateAlert) {
                        Button("Got it") {}
                    } message: {
                        Text(appState.updateMessage ?? "A new version of OpenFlux is available.")
                    }
            } else {
                FirstBootView {
                    hasCompletedFirstBoot = true
                }
                .environmentObject(appState)
                .environmentObject(themeManager)
            }
        }
        .windowStyle(.automatic)
        .commands {
            CommandGroup(replacing: .windowSize) {
                Button("Enter Full Screen") {
                    #if os(macOS)
                        if let window = NSApplication.shared.windows.first {
                            window.toggleFullScreen(nil)
                        }
                    #endif
                }
                .keyboardShortcut("f", modifiers: [.command, .control])
            }
        }

        #if os(macOS)
            Settings {
                SettingsView()
                    .environmentObject(appState)
                    .environmentObject(themeManager)
            }
        #endif
    }
}

#if os(macOS)
    extension NSApplication {
        /// Toggle fullscreen for the main window on app launch
        func enterFullScreenOnLaunch() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if let window = self.windows.first {
                    // Maximize window first
                    window.setFrame(NSScreen.main?.visibleFrame ?? window.frame, display: true)

                    // Then enter fullscreen if available
                    if !window.styleMask.contains(.fullScreen) {
                        window.toggleFullScreen(nil)
                    }
                }
            }
        }
    }
#endif
