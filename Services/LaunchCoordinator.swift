import AppKit
import Foundation

final class LaunchCoordinator {
    private let appState: AppState
    private let settingsManager = SettingsManager.shared
    private let gptkDetector = GPTKDetector.shared
    private let wineDetector = WineDetector.shared
    private let envManager = AppEnvironmentManager.shared
    private let environmentBuilder: WineEnvironmentBuilder
    private let processRunner: WineProcessRunner
    private let dllInjector: DLLInjector
    private let dependencyResolver: DLLDependencyResolver

    init(
        appState: AppState,
        environmentBuilder: WineEnvironmentBuilder,
        processRunner: WineProcessRunner,
        dllInjector: DLLInjector
    ) {
        self.appState = appState
        self.environmentBuilder = environmentBuilder
        self.processRunner = processRunner
        self.dllInjector = dllInjector
        self.dependencyResolver = DLLDependencyResolver(
            logger: DependencyLogHandler(
                log: { [weak appState] in
                    appState?.log($0, category: .dependencies) ?? print($0)
                },
                debug: { [weak appState] in
                    appState?.debug($0, category: .dependencies) ?? print($0)
                },
                warning: { [weak appState] in
                    appState?.warning($0, category: .dependencies) ?? print($0)
                },
                error: { [weak appState] in
                    appState?.error($0, category: .dependencies) ?? print($0)
                }
            )
        )
    }

    func launch(_ game: Game) {
        appState.log("═══════════════════════════════════════════", category: .games)
        appState.log("Launching: \(game.name)", category: .games)
        appState.log("Steam ID: \(game.steamAppId)", category: .games)
        var resolvedGame = game
        let exeArch = PEInspector.shared.detectArch(path: game.executablePath)
        if exeArch == .arm64 {
            appState.markLaunchFailed(
                game,
                message: "Windows ARM64 executables are not supported yet. Use an x86 or x64 build."
            )
            return
        }
        if exeArch == .x64, game.executionEnvironment == .x86 {
            appState.log(
                "Detected 64-bit EXE; overriding x86 prefix to x64 prefix", category: .games)
            resolvedGame.executionEnvironment = .native
        }

        appState.log(
            "Environment: \(resolvedGame.executionEnvironment.icon) \(resolvedGame.executionEnvironment.displayName)",
            category: .games)
        appState.log("Launch method: \(game.launchMethod.rawValue)", category: .games)
        appState.log("Path: \(game.installPath)", category: .games)
        appState.log("═══════════════════════════════════════════", category: .games)

        appState.recordRecentLaunch(resolvedGame)

        // Check Wine availability (always required for launching)
        guard wineDetector.isAvailable else {
            appState.log("Game launching disabled: Wine not installed", category: .games)
            appState.markLaunchFailed(
                game,
                message:
                    "Wine is required to launch games. Install via: brew install --cask wine-stable"
            )
            return
        }

        if resolvedGame.launchMethod == .steam, resolvedGame.steamAppId != 0 {
            launchViaSteam(resolvedGame.steamAppId)
            return
        }

        let useGPTK = shouldUseGPTK(for: resolvedGame)

        // GPTK is optional and opt-in. Only require it when enabled for this game.
        if useGPTK {
            // TODO: gate on game.requiresDirectX when we add per-game graphics metadata
            guard gptkDetector.isAvailable else {
                appState.log(
                    "GPTK enabled but not installed at \(settingsManager.gptkPath)",
                    category: .games)
                appState.markLaunchFailed(
                    game,
                    message:
                        "GPTK is enabled but not installed. Disable GPTK or install it at the configured path."
                )
                return
            }
        }

        if useGPTK, resolvedGame.graphicsAPI == .openGL || resolvedGame.graphicsAPI == .vulkan {
            appState.warning(
                "GPTK enabled for a non-D3D game (\(resolvedGame.graphicsAPI.rawValue)); launch may not need GPTK.",
                category: .games
            )
        }

        // Verify execution environment is available
        guard envManager.isEnvironmentAvailable(resolvedGame.executionEnvironment) else {
            appState.log(
                "Execution environment not available: \(resolvedGame.executionEnvironment.displayName)",
                category: .games)
            appState.markLaunchFailed(
                resolvedGame,
                message: "Selected execution environment is not properly configured."
            )
            return
        }

        launchGameProcess(resolvedGame, useGPTK: useGPTK)
    }

    func launchTestGame() {
        appState.log("╔════════════════════════════════════════════", category: .games)
        appState.log("║ TEST GAME LAUNCH - Minimal Viable Product", category: .games)
        appState.log("╚════════════════════════════════════════════", category: .games)

        // Hardcoded test game path
        let testExePath = NSHomeDirectory() + "/Games/TestGame/game.exe"

        // Verify test EXE exists
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: testExePath) else {
            appState.error(
                "Test game not found at: \(testExePath)",
                category: .games)
            appState.error(
                "To test: mkdir -p ~/Games/TestGame && cp YOUR_GAME.exe ~/Games/TestGame/game.exe",
                category: .games)
            return
        }

        appState.log("Test EXE found: \(testExePath)", category: .games)

        // Setup environment for test launch
        var environment = ProcessInfo.processInfo.environment

        // Use native (64-bit) environment for Apple Silicon compatibility
        let prefixPath = settingsManager.getPrefixDirectory() + "-native"
        let wineExe = envManager.getWineExecutablePath(for: .native)
        guard FileManager.default.fileExists(atPath: wineExe) else {
            appState.setError(
                .launchWineNotFound, details: "Install via: brew install --cask wine-stable")
            return
        }

        // Wine + GPTK environment setup
        environment["WINEPREFIX"] = prefixPath
        environment["WINE"] = wineExe
        environment["WINESERVER"] = wineDetector.wineserverPath
        environment.removeValue(forKey: "WINE64")
        environment.removeValue(forKey: "WINEARCH")

        // GPTK configuration (opt-in)
        if settingsManager.useGPTK {
            guard gptkDetector.isAvailable else {
                appState.error(
                    "GPTK enabled but not available. Install at \(settingsManager.gptkPath) or disable GPTK.",
                    category: .games)
                return
            }
            environment["DYLD_LIBRARY_PATH"] = settingsManager.gptkPath + "/lib"
            environment["METAL_DEVICE_CAPTURE_ENABLED"] = "1"
        }

        // Wine optimizations
        environment["STAGING_SHARED_MEMORY"] = "1"
        environment["DXVK_HUD"] = "off"
        environment["WINE_CPU_TOPOLOGY"] = "\(ProcessInfo.processInfo.processorCount)"

        appState.log("Wine prefix: \(prefixPath)", category: .environment)
        appState.log("Wine executable: \(wineExe)", category: .environment)
        appState.log("GPTK enabled: \(settingsManager.useGPTK)", category: .environment)
        if settingsManager.useGPTK {
            appState.log("GPTK path: \(settingsManager.gptkPath)", category: .environment)
        }
        appState.log(
            "CPU cores available: \(ProcessInfo.processInfo.processorCount)",
            category: .environment)

        // Add support for DLL injection (e.g., MegaHack v9 Pro)
        let dllPath = NSHomeDirectory() + "/.flux/dlls"
        if FileManager.default.fileExists(atPath: dllPath) {
            if let dllFiles = try? FileManager.default.contentsOfDirectory(atPath: dllPath) {
                let dllNames = dllFiles.filter { $0.lowercased().hasSuffix(".dll") }
                if !dllNames.isEmpty {
                    var overrides: [String] = []
                    for dllName in dllNames {
                        let baseName = (dllName as NSString).deletingPathExtension
                        overrides.append("\(baseName)=n,b")  // native, builtin
                    }
                    environment["WINEDLLOVERRIDES"] = overrides.joined(separator: ";")
                    appState.log(
                        "DLL Injection enabled: \(dllNames.joined(separator: ", "))",
                        category: .environment)
                }
            }
        }

        appState.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━", category: .games)
        appState.log("LAUNCHING: game.exe", category: .games)
        appState.log("Command: \(wineExe) \(testExePath)", category: .games)
        appState.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━", category: .games)

        processRunner.executeDirect(
            wineExecutablePath: wineExe,
            executablePath: testExePath,
            environment: environment,
            workingDirectory: (testExePath as NSString).deletingLastPathComponent
        )

        appState.log("╔════════════════════════════════════════════", category: .games)
        appState.log("║ TEST LAUNCH COMPLETE", category: .games)
        appState.log("╚════════════════════════════════════════════", category: .games)
    }

    private func launchGameProcess(_ game: Game, useGPTK: Bool) {
        // Setup environment
        var environment = ProcessInfo.processInfo.environment
        environmentBuilder.setupExecutionEnvironment(&environment, for: game, useGPTK: useGPTK)

        // Analyze and handle missing DLL dependencies
        let missingDLLs = dependencyResolver.analyzeDependencies(
            executablePath: game.executablePath)
        if !missingDLLs.isEmpty {
            dependencyResolver.reportMissingDependencies(missingDLLs, executable: game.name)
            let prefixPath = envManager.getPrefixPath(for: game.executionEnvironment)
            dependencyResolver.generateStubDLLs(for: missingDLLs, prefixPath: prefixPath)
        }

        // Inject DLLs (optional per-game folder)
        if let overrides = dllInjector.injectDLLs(for: game) {
            environment["WINEDLLOVERRIDES"] = overrides
        }

        // Prepare Wine command
        guard !game.executablePath.isEmpty else {
            appState.error("Invalid executable path", category: .games)
            return
        }

        let wineCommand = environmentBuilder.buildWineCommand(for: game)

        // Execute
        processRunner.executeGame(command: wineCommand, environment: environment, game: game)
    }

    private func shouldUseGPTK(for game: Game) -> Bool {
        switch game.gptkMode {
        case .enabled:
            return true
        case .disabled:
            return false
        case .inherit:
            return settingsManager.useGPTK
        }
    }

    private func launchViaSteam(_ appId: Int) {
        guard let url = URL(string: "steam://run/\(appId)") else {
            appState.error("Invalid Steam URL for appId \(appId)", category: .games)
            return
        }
        appState.log("Launching via Steam: \(url.absoluteString)", category: .games)
        NSWorkspace.shared.open(url)
    }
}
