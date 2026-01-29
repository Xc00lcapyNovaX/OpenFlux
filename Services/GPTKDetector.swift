import Foundation

/// Detects and manages Apple Game Porting Toolkit (GPTK) availability
///
/// GPTK provides DirectX/Metal translation layer (optional)
/// Wine is installed SEPARATELY - they are independent dependencies
///
/// You need:
/// - Wine (from Homebrew or other distribution) for launching
/// - GPTK libraries (in /opt/gptk/lib) for D3D translation
class GPTKDetector {
    private let fileManager = FileManager.default
    private let settingsManager = SettingsManager.shared

    /// Check if GPTK is installed and properly available on disk.
    /// This is independent from whether the user has enabled GPTK usage.
    var isAvailable: Bool {
        let gptkLib = settingsManager.gptkPath + "/lib"
        // IMPORTANT: no side effects here.
        // SwiftUI and launch code may access this repeatedly; logging here can create a render loop.
        return fileManager.fileExists(atPath: gptkLib)
    }

    /// Whether GPTK usage is enabled in settings (opt-in).
    var isEnabled: Bool {
        settingsManager.useGPTK
    }

    /// Get GPTK library path (when available)
    var libraryPath: String? {
        guard isAvailable else { return nil }
        return settingsManager.gptkPath + "/lib"
    }

    /// Log GPTK availability once from a caller-controlled context (avoid SwiftUI feedback loops).
    func logAvailability(using appState: AppState) {
        if isAvailable {
            appState.debug("✓ GPTK available at \(settingsManager.gptkPath)", category: .installation)
        } else {
            appState.debug("✗ GPTK not found at \(settingsManager.gptkPath)", category: .installation)
        }
    }

    /// Get GPTK version if available
    var version: String? {
        guard isAvailable else { return nil }

        let versionFile = settingsManager.gptkPath + "/VERSION"
        if let version = try? String(contentsOfFile: versionFile, encoding: .utf8) {
            return version.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }

    /// Shared singleton instance
    static let shared = GPTKDetector()
}
