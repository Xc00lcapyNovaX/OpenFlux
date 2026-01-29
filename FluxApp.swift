import SwiftUI

@main
struct FluxApp: App {
    @StateObject private var appState = AppState.shared
    @StateObject private var themeManager = ThemeManager.shared
    @AppStorage("hasCompletedFirstBoot") private var hasCompletedFirstBoot = false
    @State private var showUpdateAlert = false

    init() {
        // Ensure app data directories exist
        SettingsManager.shared.setupDirectories()

        // Initialize logging system (through AppState spine)
        AppState.shared.log("App launched", category: .engine)

        // Load saved theme
        ThemeManager.shared.loadTheme()

        // Enter fullscreen on launch
        #if os(macOS)
            NSApplication.shared.enterFullScreenOnLaunch()
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
