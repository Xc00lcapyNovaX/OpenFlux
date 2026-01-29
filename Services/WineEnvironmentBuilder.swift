import Foundation

final class WineEnvironmentBuilder {
    private let appState: AppState
    private let settingsManager: SettingsManager
    private let wineDetector: WineDetector
    private let envManager: AppEnvironmentManager

    init(
        appState: AppState,
        envManager: AppEnvironmentManager = .shared,
        settingsManager: SettingsManager = .shared,
        wineDetector: WineDetector = .shared
    ) {
        self.appState = appState
        self.settingsManager = settingsManager
        self.wineDetector = wineDetector
        self.envManager = envManager
    }

    func setupExecutionEnvironment(
        _ environment: inout [String: String],
        for game: Game,
        useGPTK: Bool
    ) {
        // Get environment-specific paths
        let prefixPath = envManager.getPrefixPath(for: game.executionEnvironment)
        let wineExecutable = envManager.getWineExecutablePath(for: game.executionEnvironment)
        let wineserverPath = wineDetector.wineserverPath

        environment = Self.buildEnvironment(
            base: environment,
            prefixPath: prefixPath,
            wineExecutable: wineExecutable,
            wineserverPath: wineserverPath,
            useGPTK: useGPTK,
            gptkPath: settingsManager.gptkPath,
            executionEnvironment: game.executionEnvironment,
            steamAppId: game.steamAppId
        )

        appState.debug(
            "Execution Environment: \(game.executionEnvironment.displayName)",
            category: .environment)
        appState.debug("Wine prefix: \(prefixPath)", category: .environment)
        appState.debug("Wine executable: \(wineExecutable)", category: .environment)
        appState.debug("GPTK enabled: \(useGPTK)", category: .environment)

        if let device = getMTLDevice() {
            appState.debug("Metal device: \(device)", category: .gpu)
        }
    }

    func buildWineCommand(for game: Game) -> [String] {
        let wineExe = envManager.getWineExecutablePath(for: game.executionEnvironment)
        return Self.buildCommand(wineExecutable: wineExe, executablePath: game.executablePath)
    }

    private func getMTLDevice() -> String? {
        return MetalDeviceDetector.shared.metalInfo?.deviceName
    }

    static func buildCommand(wineExecutable: String, executablePath: String) -> [String] {
        return [wineExecutable, executablePath]
    }

    static func buildEnvironment(
        base: [String: String],
        prefixPath: String,
        wineExecutable: String,
        wineserverPath: String?,
        useGPTK: Bool,
        gptkPath: String,
        executionEnvironment: ExecutionEnvironment,
        steamAppId: Int
    ) -> [String: String] {
        var environment = base

        environment["WINEPREFIX"] = prefixPath
        if executionEnvironment == .x86 {
            environment["WINEARCH"] = "win32"
        }
        environment["WINE"] = wineExecutable
        if let wineserverPath {
            environment["WINESERVER"] = wineserverPath
        } else {
            environment.removeValue(forKey: "WINESERVER")
        }
        environment.removeValue(forKey: "WINE64")

        // GPTK configuration (opt-in)
        if useGPTK {
            environment["DYLD_LIBRARY_PATH"] = gptkPath + "/lib"
            environment["METAL_DEVICE_CAPTURE_ENABLED"] = "1"
        } else {
            environment.removeValue(forKey: "DYLD_LIBRARY_PATH")
            environment.removeValue(forKey: "METAL_DEVICE_CAPTURE_ENABLED")
        }

        // Steam context (helps Steam DRM and Geometry Dash)
        if steamAppId != 0 {
            let appId = String(steamAppId)
            environment["SteamAppId"] = appId
            environment["SteamGameId"] = appId
        }

        // Wine staging features
        environment["STAGING_SHARED_MEMORY"] = "1"
        environment["DXVK_HUD"] = "off"
        environment["WINE_CPU_TOPOLOGY"] = "\(ProcessInfo.processInfo.processorCount)"

        return environment
    }
}
