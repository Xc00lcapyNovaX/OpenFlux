import Foundation

final class DLLInjector {
    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    /// Copy any DLLs placed in ~/.flux/inject/<game-slug>/ into the game folder and set overrides.
    /// Returns a WINEDLLOVERRIDES string if DLLs were injected.
    @discardableResult
    func injectDLLs(for game: Game) -> String? {
        let slug = game.name
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))

        let sourceDir = NSHomeDirectory() + "/.flux/inject/\(slug)"
        let destDir = (game.executablePath as NSString).deletingLastPathComponent

        guard FileManager.default.fileExists(atPath: sourceDir) else {
            return nil
        }

        var overrides: [String] = []

        do {
            let files = try FileManager.default.contentsOfDirectory(atPath: sourceDir)
            for file in files where file.lowercased().hasSuffix(".dll") {
                let src = (sourceDir as NSString).appendingPathComponent(file)
                let dst = (destDir as NSString).appendingPathComponent(file)

                // Overwrite existing to ensure latest copy
                if FileManager.default.fileExists(atPath: dst) {
                    try? FileManager.default.removeItem(atPath: dst)
                }
                try FileManager.default.copyItem(atPath: src, toPath: dst)
                overrides.append("\(file)=n,b")
                appState.log("Injected DLL: \(file)", category: .dependencies)
            }
        } catch {
            appState.warning(
                "DLL injection failed: \(error.localizedDescription)", category: .dependencies)
        }

        guard !overrides.isEmpty else { return nil }
        return overrides.joined(separator: ";")
    }
}
