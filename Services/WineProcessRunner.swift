import Darwin
import Foundation

final class WineProcessRunner {
    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    struct RunResult {
        let exitCode: Int32
        let stdout: String
        let stderr: String
        let timedOut: Bool
    }

    func executeGame(command: [String], environment: [String: String], game: Game) {
        executeProcess(
            executablePath: "/usr/bin/env",
            arguments: command,
            environment: environment,
            workingDirectory: (game.executablePath as NSString).deletingLastPathComponent,
            game: game
        )
    }

    func executeDirect(
        wineExecutablePath: String,
        executablePath: String,
        environment: [String: String],
        workingDirectory: String
    ) {
        executeProcess(
            executablePath: wineExecutablePath,
            arguments: [executablePath],
            environment: environment,
            workingDirectory: workingDirectory,
            game: nil
        )
    }

    func runAndCapture(
        executablePath: String,
        arguments: [String],
        environment: [String: String],
        workingDirectory: String,
        timeoutSeconds: TimeInterval
    ) -> RunResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        process.environment = environment
        process.currentDirectoryPath = workingDirectory

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        var stdoutData = Data()
        var stderrData = Data()
        let lock = NSLock()

        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty { return }
            lock.lock()
            stdoutData.append(data)
            lock.unlock()
        }
        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty { return }
            lock.lock()
            stderrData.append(data)
            lock.unlock()
        }

        let sema = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in sema.signal() }

        do {
            try process.run()
        } catch {
            return RunResult(
                exitCode: -1, stdout: "", stderr: error.localizedDescription, timedOut: false)
        }

        let waitResult = sema.wait(timeout: .now() + timeoutSeconds)
        let timedOut = (waitResult == .timedOut)

        if timedOut {
            process.terminate()
            _ = sema.wait(timeout: .now() + 2)
            if process.isRunning {
                kill(process.processIdentifier, SIGKILL)
                _ = sema.wait(timeout: .now() + 2)
            }
        }

        stdoutPipe.fileHandleForReading.readabilityHandler = nil
        stderrPipe.fileHandleForReading.readabilityHandler = nil

        lock.lock()
        let out = String(data: stdoutData, encoding: .utf8) ?? ""
        let err = String(data: stderrData, encoding: .utf8) ?? ""
        lock.unlock()

        return RunResult(
            exitCode: process.terminationStatus, stdout: out, stderr: err, timedOut: timedOut)
    }

    private func executeProcess(
        executablePath: String,
        arguments: [String],
        environment: [String: String],
        workingDirectory: String,
        game: Game?
    ) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        process.environment = environment
        process.currentDirectoryPath = workingDirectory

        // Disable output streaming to reduce disk I/O - just discard output
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            let pid = process.processIdentifier
            appState.log("App process started with PID: \(pid)", category: .games)

            // Register with process monitor if we have a game
            if let game = game {
                DispatchQueue.main.async { [weak self] in
                    self?.appState.runningGames[game.id] = ProcessMonitor.ProcessInfo(
                        pid: pid,
                        name: game.name,
                        startTime: Date()
                    )
                }
            }

            // Wait for process in background to not block
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                process.waitUntilExit()

                // Close pipes
                outputPipe.fileHandleForReading.closeFile()
                errorPipe.fileHandleForReading.closeFile()

                let exitStatus = process.terminationStatus

                DispatchQueue.main.async {
                    self?.appState.log("App exited with status: \(exitStatus)", category: .games)

                    if let game = game {
                        self?.appState.runningGames.removeValue(forKey: game.id)

                        if exitStatus != 0 {
                            self?.appState.markLaunchFailed(
                                game,
                                message: "App exited with status: \(exitStatus)"
                            )
                        }
                    }
                }
            }
        } catch {
            appState.error("Failed to launch app: \(error.localizedDescription)", category: .games)
            if let game {
                appState.markLaunchFailed(
                    game,
                    message: "Failed to launch app: \(error.localizedDescription)"
                )
            }
        }
    }
}
