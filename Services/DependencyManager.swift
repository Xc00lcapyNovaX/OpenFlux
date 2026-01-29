import Foundation

enum DependencyCategory: String, CaseIterable {
    case runtime = "Runtime Components"
    case gameFiles = "Game Files"
    case graphicsBackend = "Graphics Backend"
}

struct DependencyItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let fileName: String
    let category: DependencyCategory
    let isRequired: Bool
    let details: String
}

struct DependencyReport {
    let game: Game
    let required: [DependencyItem]
    let optional: [DependencyItem]

    var isEmpty: Bool {
        required.isEmpty && optional.isEmpty
    }

    func items(for category: DependencyCategory, requiredOnly: Bool) -> [DependencyItem] {
        let source = requiredOnly ? required : optional
        return source.filter { $0.category == category }
    }
}

class DependencyManager {
    private let fileManager = FileManager.default
    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    private let runtimeComponents = [
        ("DirectX 9 Runtime", "d3dx9_43.dll", "Installs d3dx9 runtime components into the Wine prefix."),
        ("XInput Runtime", "xinput1_3.dll", "Installs xinput runtime components into the Wine prefix."),
        ("XAudio 2.7", "xaudio2_7.dll", "Installs legacy XAudio runtime into the Wine prefix."),
    ]

    private let graphicsComponents = [
        ("DXVK Configuration", "dxvk_config.dll", "Optional DXVK runtime for DirectX translation."),
    ]

    private let gameFileComponents = [
        ("Steam API (64-bit)", "steam_api64.dll",
         "Required for Steam games when launching directly (not bundled)."),
    ]


    func checkDependencies(for game: Game) -> [String] {
        let report = dependencyReport(for: game)
        return report.required.map { $0.fileName }
    }

    func dependencyReport(for game: Game) -> DependencyReport {
        var required: [DependencyItem] = []
        var optional: [DependencyItem] = []

        let prefixPath = getEnvironmentPrefixPath(for: game.executionEnvironment)
        let system32Path = prefixPath + "/drive_c/windows/system32"
        let installPath = game.installPath

        for component in runtimeComponents {
            let dllPath = (system32Path as NSString).appendingPathComponent(component.1)
            if !fileManager.fileExists(atPath: dllPath) {
                appState.debug("Missing runtime DLL: \(component.1)", category: .dependencies)
                required.append(
                    DependencyItem(
                        name: component.0,
                        fileName: component.1,
                        category: .runtime,
                        isRequired: true,
                        details: component.2
                    )
                )
            }
        }

        let steamGameLikely = game.isSteamGame
            || game.installPath.lowercased().contains("steamapps")

        for component in gameFileComponents {
            let dllPath = (installPath as NSString).appendingPathComponent(component.1)
            if !fileManager.fileExists(atPath: dllPath), steamGameLikely {
                appState.debug("Missing game file: \(component.1)", category: .dependencies)
                required.append(
                    DependencyItem(
                        name: component.0,
                        fileName: component.1,
                        category: .gameFiles,
                        isRequired: true,
                        details: component.2
                    )
                )
            }
        }

        for component in graphicsComponents {
            let dllPath = (system32Path as NSString).appendingPathComponent(component.1)
            if !fileManager.fileExists(atPath: dllPath) {
                appState.debug("Missing graphics backend: \(component.1)", category: .dependencies)
                optional.append(
                    DependencyItem(
                        name: component.0,
                        fileName: component.1,
                        category: .graphicsBackend,
                        isRequired: false,
                        details: component.2
                    )
                )
            }
        }

        return DependencyReport(game: game, required: required, optional: optional)
    }

    func installDependencies(
        for report: DependencyReport,
        includeOptional: Bool,
        completion: @escaping (Bool) -> Void
    ) {
        let game = report.game
        appState.log("Installing dependencies for \(game.name)...", category: .dependencies)
        appState.log("Environment: \(game.executionEnvironment.displayName)", category: .dependencies)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                completion(false)
                return
            }

            let prefixPath = self.getEnvironmentPrefixPath(for: game.executionEnvironment)
            var success = true

            let missingRuntime = report.required.filter { $0.category == .runtime }
            if !missingRuntime.isEmpty {
                appState.log("Installing runtime components...", category: .dependencies)
                var components: [String] = []
                if missingRuntime.contains(where: { $0.fileName == "d3dx9_43.dll" }) {
                    components.append("d3dx9")
                }
                if missingRuntime.contains(where: { $0.fileName == "xinput1_3.dll" }) {
                    components.append("xinput")
                }
                if missingRuntime.contains(where: { $0.fileName == "xaudio2_7.dll" }) {
                    components.append("xaudio2")
                }
                if !self.installViaWinetricks(
                    components,
                    prefix: prefixPath,
                    environment: game.executionEnvironment
                ) {
                    appState.warning("Failed to install runtime components", category: .dependencies)
                    success = false
                }
            }

            let missingGameFiles = report.required.filter { $0.category == .gameFiles }
            if !missingGameFiles.isEmpty {
                appState.log("Resolving game files...", category: .dependencies)
                if !self.installGameFileDependencies(
                    missingGameFiles,
                    for: game
                ) {
                    appState.warning("Failed to resolve game files", category: .dependencies)
                    success = false
                }
            }

            if includeOptional {
                let missingGraphics = report.optional.filter { $0.category == .graphicsBackend }
                if !missingGraphics.isEmpty {
                    appState.log("Installing graphics backend...", category: .dependencies)
                    if !self.installViaWinetricks(
                        ["dxvk"],
                        prefix: prefixPath,
                        environment: game.executionEnvironment
                    ) {
                        appState.warning("Failed to install graphics backend", category: .dependencies)
                        success = false
                    }
                }
            }

            if success {
                appState.log("✓ All dependencies installed successfully", category: .dependencies)
            } else {
                appState.warning("⚠️ Some dependencies failed to install", category: .dependencies)
            }

            DispatchQueue.main.async {
                completion(success)
            }
        }
    }

    /// Install components via winetricks
    private func installViaWinetricks(
        _ components: [String],
        prefix: String,
        environment: ExecutionEnvironment
    ) -> Bool {
        let wineExePath = AppEnvironmentManager.shared.getWineExecutablePath(for: environment)

        for component in components {
            appState.debug("Installing \(component) via winetricks...", category: .dependencies)

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = [
                "-c",
                "export WINEPREFIX='\(prefix)' && " + "export WINE='\(wineExePath)' && "
                    + "winetricks --unattended \(component) 2>&1",
            ]

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            do {
                try process.run()
                process.waitUntilExit()

                if process.terminationStatus == 0 {
                    appState.debug("✓ \(component) installed", category: .dependencies)
                } else {
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8) ?? "Unknown error"
                    appState.warning(
                        "Failed to install \(component): \(output)", category: .dependencies)
                    return false
                }
            } catch {
                appState.error("Failed to run winetricks: \(error)", category: .dependencies)
                return false
            }
        }

        return true
    }

    private func installGameFileDependencies(
        _ missing: [DependencyItem],
        for game: Game
    ) -> Bool {
        var success = true
        for item in missing {
            switch item.fileName {
            case "steam_api64.dll":
                if !resolveSteamApi64(for: game) {
                    appState.warning(
                        "steam_api64.dll missing. Verify files in Steam or launch via Steam.",
                        category: .dependencies
                    )
                    success = false
                }
            default:
                appState.warning("No installer for \(item.fileName)", category: .dependencies)
                success = false
            }
        }
        return success
    }

    private func resolveSteamApi64(for game: Game) -> Bool {
        let installPath = game.installPath
        let target = (installPath as NSString).appendingPathComponent("steam_api64.dll")

        if fileManager.fileExists(atPath: target) {
            return true
        }

        let candidates = [
            installPath + "/_CommonRedist/Steamworks Shared/_CommonRedist/redistributable_bin/steam_api64.dll",
            installPath + "/_CommonRedist/Steamworks Shared/redistributable_bin/steam_api64.dll",
            installPath + "/_CommonRedist/Steamworks Shared/steam_api64.dll",
        ]

        for source in candidates where fileManager.fileExists(atPath: source) {
            do {
                try fileManager.copyItem(atPath: source, toPath: target)
                appState.debug("Copied steam_api64.dll from \(source)", category: .dependencies)
                return true
            } catch {
                appState.warning("Failed to copy steam_api64.dll: \(error)", category: .dependencies)
                return false
            }
        }

        return false
    }

    /// Get Wine prefix path for environment
    private func getEnvironmentPrefixPath(for environment: ExecutionEnvironment) -> String {
        return AppEnvironmentManager.shared.getPrefixPath(for: environment)
    }

    func detectDRM(in game: Game) -> Bool {
        let drmPatterns = [
            "denuvo",
            "securom",
            "starforce",
            "securedisc",
            "safedisc",
            "arxan",
            "themida",
        ]

        let gameName = game.name.lowercased()
        let hasKnownDRM = drmPatterns.contains { gameName.contains($0) }

        if hasKnownDRM {
            appState.debug("DRM detected: \(game.name)", category: .drm)
        }

        return hasKnownDRM
    }

    func isLauncherExecutable(_ game: Game) -> Bool {
        let name = (game.executablePath as NSString).lastPathComponent.lowercased()
        let markers = [
            "launcher", "installer", "setup", "bootstrap", "updater", "patcher",
        ]
        return markers.contains { name.contains($0) }
    }

    func shouldProbeDependencies(for game: Game) -> Bool {
        if game.launchMethod == .steam {
            return false
        }
        if isLauncherExecutable(game) {
            return true
        }
        let install = game.installPath.lowercased()
        // Common case: direct-launching a Steam-installed game EXE.
        if install.contains("steamapps") || install.contains("steam") {
            return true
        }
        return false
    }
}
