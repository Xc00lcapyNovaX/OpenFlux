import Foundation

struct WineSmokeTestResult {
    let passed: Bool
    let summary: String
}

/// A practical "does it work?" check: validates Wine can initialize a prefix and run a basic Windows command.
/// This avoids relying on GUI apps (which are harder to verify programmatically).
final class WineSmokeTestRunner {
    private let appState: AppState
    private let wineDetector = WineDetector.shared
    private let gptkDetector = GPTKDetector.shared
    private let envManager = AppEnvironmentManager.shared
    private let settingsManager = SettingsManager.shared

    init(appState: AppState) {
        self.appState = appState
    }

    func run(environment: ExecutionEnvironment) -> WineSmokeTestResult {
        appState.log("═══════════════════════════════════════════", category: .games)
        appState.log("Wine smoke test started", category: .games)
        appState.log("Environment: \(environment.displayName)", category: .games)

        guard wineDetector.isAvailable else {
            return WineSmokeTestResult(
                passed: false,
                summary: "Wine not available. Install Wine first."
            )
        }

        // Log GPTK availability once (no render-loop logging).
        gptkDetector.logAvailability(using: appState)

        let wineExe = envManager.getWineExecutablePath(for: environment)
        let wineserver = wineDetector.wineserverPath

        let tempPrefix = (NSTemporaryDirectory() as NSString).appendingPathComponent(
            "OpenFluxSmokePrefix-\(UUID().uuidString)"
        )
        do {
            try FileManager.default.createDirectory(
                atPath: tempPrefix,
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            return WineSmokeTestResult(
                passed: false, summary: "Failed to create temp prefix: \(error)")
        }

        defer {
            try? FileManager.default.removeItem(atPath: tempPrefix)
        }

        var env = ProcessInfo.processInfo.environment
        env["WINEPREFIX"] = tempPrefix
        if environment == .x86 {
            // Note: Don't set WINEARCH - wow64 Wine handles both architectures
            env.removeValue(forKey: "WINEARCH")
        }
        env["WINE"] = wineExe
        if let wineserver {
            env["WINESERVER"] = wineserver
        } else {
            env.removeValue(forKey: "WINESERVER")
        }
        env.removeValue(forKey: "WINE64")

        // We keep GPTK disabled for the smoke test by default; it should validate Wine correctness first.
        env.removeValue(forKey: "DYLD_LIBRARY_PATH")
        env.removeValue(forKey: "METAL_DEVICE_CAPTURE_ENABLED")

        let runner = WineProcessRunner(appState: appState)

        // 1) wine --version
        let versionRes = runner.runAndCapture(
            executablePath: wineExe,
            arguments: ["--version"],
            environment: env,
            workingDirectory: NSHomeDirectory(),
            timeoutSeconds: 10
        )
        appState.log(
            "wine --version stdout: \(versionRes.stdout.trimmingCharacters(in: .whitespacesAndNewlines))",
            category: .games)
        if versionRes.timedOut || versionRes.exitCode != 0 {
            return WineSmokeTestResult(
                passed: false,
                summary:
                    "wine --version failed (exit \(versionRes.exitCode), timedOut=\(versionRes.timedOut))."
            )
        }

        // 2) Initialize prefix (wineboot -u)
        let bootRes = runner.runAndCapture(
            executablePath: wineExe,
            arguments: ["wineboot", "-u"],
            environment: env,
            workingDirectory: NSHomeDirectory(),
            timeoutSeconds: 60
        )
        if bootRes.timedOut || bootRes.exitCode != 0 {
            return WineSmokeTestResult(
                passed: false,
                summary:
                    "wineboot -u failed (exit \(bootRes.exitCode), timedOut=\(bootRes.timedOut))."
            )
        }

        // 3) cmd /c echo (functional Windows process execution)
        let marker = "OPENFLUX_OK"
        let cmdRes = runner.runAndCapture(
            executablePath: wineExe,
            arguments: ["cmd", "/c", "echo", marker],
            environment: env,
            workingDirectory: NSHomeDirectory(),
            timeoutSeconds: 20
        )
        let stdout = cmdRes.stdout
        if cmdRes.timedOut || cmdRes.exitCode != 0 || !stdout.contains(marker) {
            return WineSmokeTestResult(
                passed: false,
                summary:
                    "cmd /c echo failed (exit \(cmdRes.exitCode), timedOut=\(cmdRes.timedOut))."
            )
        }

        // If user has GPTK enabled globally, provide a hint (but don't fail the Wine smoke test).
        if settingsManager.useGPTK {
            appState.log(
                "Note: GPTK is enabled in Settings; smoke test validated Wine without GPTK.",
                category: .games)
        }

        return WineSmokeTestResult(
            passed: true,
            summary: "Wine smoke test passed: prefix init + cmd execution OK."
        )
    }
}
