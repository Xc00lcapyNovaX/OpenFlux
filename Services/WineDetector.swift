import Foundation

/// Detects and manages Wine installation
/// Wine must be installed separately (via Homebrew, MacPorts, etc.)
/// This is independent from GPTK - you can have Wine without GPTK and vice versa
///
/// Correct Logic (as per Whisky/CrossOver):
/// - Use `wine` executable (64-bit by default, compatible with both ARM and Intel)
/// - Assume 64-bit unless explicitly x86-only
/// - Never require wine64 on ARM Macs (doesn't exist on Apple Silicon)
class WineDetector {
    private let fileManager = FileManager.default
    private let settingsManager = SettingsManager.shared
    private let appState = AppState.shared

    /// Cached wine executable path (detected once on first access)
    private lazy var cachedWinePath: String? = detectWine()

    /// Cached wineserver executable path (detected once on first access)
    private lazy var cachedWineserverPath: String? = detectWineserver()

    /// Check if wine executable is available
    var isAvailable: Bool {
        wineExecutablePath != nil
    }

    /// Get the full path to wine executable (cached after first detection)
    /// Uses `wine` (64-bit by default) rather than architecture-specific variants
    var wineExecutablePath: String? {
        cachedWinePath
    }

    /// Get the full path to wineserver executable (cached after first detection)
    /// Prevents "Wine launches but hangs forever" bugs
    var wineserverPath: String? {
        cachedWineserverPath
    }

    /// Detect wine executable by searching standard locations
    /// Only called once and cached for performance
    private func detectWine() -> String? {
        let candidates = [
            settingsManager.wineDirectory + "/bin/wine",  // Custom path
            "/opt/homebrew/bin/wine",  // Homebrew ARM64
            "/usr/local/bin/wine",  // Homebrew Intel
            "/Applications/Wine Stable.app/Contents/Resources/wine/bin/wine",  // Wine Stable app
        ]

        for path in candidates {
            if fileManager.isExecutableFile(atPath: path) {
                appState.debug("✓ Found wine at \(path)", category: .installation)
                return path
            }
        }

        appState.debug("✗ wine not found in standard locations", category: .installation)
        return nil
    }

    /// Detect wineserver executable by searching standard locations
    /// Only called once and cached for performance
    private func detectWineserver() -> String? {
        let candidates = [
            settingsManager.wineDirectory + "/bin/wineserver",  // Custom path
            "/opt/homebrew/bin/wineserver",  // Homebrew ARM64
            "/usr/local/bin/wineserver",  // Homebrew Intel
            "/Applications/Wine Stable.app/Contents/Resources/wine/bin/wineserver",  // Wine Stable app
        ]

        return candidates.first { fileManager.isExecutableFile(atPath: $0) }
    }

    /// Get Wine version if available
    var version: String? {
        guard let wineExe = wineExecutablePath else { return nil }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: wineExe)
        process.arguments = ["--version"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()  // Suppress stderr

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                return output.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } catch {
            appState.debug("Could not detect Wine version: \(error)", category: .installation)
        }

        return nil
    }

    /// Shared singleton instance
    static let shared = WineDetector()
}
