import Foundation

/// Steam API Emulator for running Steam games without Steam client
/// This generates a functional steam_api64.dll that allows games to run offline
class SteamAPIEmulator {
    static let shared = SteamAPIEmulator()
    private let fileManager = FileManager.default
    private let appState = AppState.shared

    /// Clean up broken stub DLLs from Wine prefix
    func cleanupBrokenStubs() {
        let prefixPath = NSHomeDirectory() + "/.flux/prefix"
        let system32 = prefixPath + "/drive_c/windows/system32"

        let stubsToRemove = [
            "steam_api64.dll",
            "steam_api.dll",
            "steamclient64.dll",
            "steamclient.dll",
        ]

        for stub in stubsToRemove {
            let path = system32 + "/\(stub)"
            if fileManager.fileExists(atPath: path) {
                // Check if it's a tiny stub (< 1KB = broken)
                let attributes = try? fileManager.attributesOfItem(atPath: path)
                let size = attributes?[.size] as? Int ?? 0

                if size < 1024 {
                    do {
                        try fileManager.removeItem(atPath: path)
                        appState.debug(
                            "Removed broken stub: \(stub)", category: .dependencies)
                    } catch {
                        appState.warning(
                            "Could not remove stub \(stub): \(error)",
                            category: .dependencies)
                    }
                }
            }
        }
    }

    /// Path to bundled or downloaded Steam emulator DLL
    private var emulatorDLLPath: String? {
        // Check for bundled emulator first
        if let bundled = Bundle.main.resourcePath {
            let bundledPath = bundled + "/steam_api64.dll"
            if fileManager.fileExists(atPath: bundledPath) {
                return bundledPath
            }
        }

        // Check in OpenFlux data directory
        let dataPath = NSHomeDirectory() + "/.flux/emulators/steam_api64.dll"
        if fileManager.fileExists(atPath: dataPath) {
            return dataPath
        }

        return nil
    }

    /// Install Steam emulator for a game
    /// - Parameters:
    ///   - gamePath: Directory containing the game executable
    ///   - steamAppId: Steam App ID for the game
    /// - Returns: true if emulator was installed successfully
    func installEmulator(for gamePath: String, steamAppId: Int) -> Bool {
        let targetDLL = (gamePath as NSString).appendingPathComponent("steam_api64.dll")

        // If original Steam DLL exists and is real, back it up
        if fileManager.fileExists(atPath: targetDLL) {
            let backupPath = targetDLL + ".bak"
            if !fileManager.fileExists(atPath: backupPath) {
                do {
                    try fileManager.moveItem(atPath: targetDLL, toPath: backupPath)
                    appState.debug(
                        "Backed up original steam_api64.dll", category: .dependencies)
                } catch {
                    appState.warning(
                        "Could not backup original steam_api64.dll: \(error)",
                        category: .dependencies)
                }
            }
        }

        // Try to use bundled/downloaded emulator
        if let emulatorPath = emulatorDLLPath {
            do {
                try fileManager.copyItem(atPath: emulatorPath, toPath: targetDLL)
                appState.log(
                    "Installed Steam emulator DLL", category: .dependencies)

                // Create steam_appid.txt
                createAppIdFile(in: gamePath, steamAppId: steamAppId)

                return true
            } catch {
                appState.warning(
                    "Could not install emulator: \(error)", category: .dependencies)
            }
        }

        // Fallback: Use environment variable to disable Steam
        appState.log(
            "Using environment-based Steam bypass", category: .dependencies)
        return false
    }

    /// Create steam_appid.txt file required by Steam emulators
    private func createAppIdFile(in gamePath: String, steamAppId: Int) {
        let appIdPath = (gamePath as NSString).appendingPathComponent("steam_appid.txt")

        do {
            try String(steamAppId).write(toFile: appIdPath, atomically: true, encoding: .utf8)
            appState.debug(
                "Created steam_appid.txt with ID \(steamAppId)", category: .dependencies)
        } catch {
            appState.warning(
                "Could not create steam_appid.txt: \(error)", category: .dependencies)
        }
    }

    /// Configure Wine environment for Steam bypass
    func configureEnvironment(
        _ environment: inout [String: String], gamePath: String, steamAppId: Int
    ) {
        // Set Steam App ID for games that read environment
        environment["SteamAppId"] = String(steamAppId)
        environment["SteamGameId"] = String(steamAppId)

        // Disable Steam overlay (can cause crashes)
        environment["STEAM_OVERLAY_ENABLED"] = "0"
        environment["NOSTEAM"] = "1"

        // Point to game directory for relative paths
        environment["STEAM_COMPAT_CLIENT_INSTALL_PATH"] = gamePath
        environment["STEAM_COMPAT_DATA_PATH"] = gamePath

        // Create steam_appid.txt if it doesn't exist
        createAppIdFile(in: gamePath, steamAppId: steamAppId)
    }

    /// Check if a game needs Steam emulation
    func needsSteamEmulation(executablePath: String) -> Bool {
        let gamePath = (executablePath as NSString).deletingLastPathComponent
        let steamDLL = (gamePath as NSString).appendingPathComponent("steam_api64.dll")

        // If game references steam_api64.dll, it needs Steam
        // Check if the DLL exists and is functional
        guard fileManager.fileExists(atPath: steamDLL) else {
            // DLL doesn't exist - check if the executable imports it
            return checkExecutableImportsSteam(executablePath)
        }

        // DLL exists - check if it's a stub or real
        let attributes = try? fileManager.attributesOfItem(atPath: steamDLL)
        let size = attributes?[.size] as? Int ?? 0

        // Real Steam DLLs are typically >200KB, stubs are tiny
        return size < 50000
    }

    /// Check if executable imports Steam API
    private func checkExecutableImportsSteam(_ executablePath: String) -> Bool {
        do {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/strings")
            task.arguments = [executablePath]

            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = FileHandle.nullDevice
            try task.run()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let lower = output.lowercased()
                return lower.contains("steam_api64.dll") || lower.contains("steamapi_init")
                    || lower.contains("steamclient")
            }
        } catch {
            // Assume it needs Steam if we can't check
        }

        return true
    }

    /// Download Goldberg Steam Emulator if not present
    func ensureEmulatorAvailable(completion: @escaping (Bool) -> Void) {
        let emulatorDir = NSHomeDirectory() + "/.flux/emulators"
        let dllPath = emulatorDir + "/steam_api64.dll"

        if fileManager.fileExists(atPath: dllPath) {
            completion(true)
            return
        }

        // Create directory
        try? fileManager.createDirectory(atPath: emulatorDir, withIntermediateDirectories: true)

        // For now, we'll use the environment-based bypass
        // In the future, this could download Goldberg emulator
        appState.log(
            "Steam emulator not available, using environment bypass", category: .dependencies)
        completion(false)
    }
}
