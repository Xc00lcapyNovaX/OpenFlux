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

        // Setup output capture
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        // Read output streams
        DispatchQueue.global(qos: .background).async { [weak self] in
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: outputData, encoding: .utf8), !output.isEmpty {
                self?.appState.log(output, category: .gameOutput)
            }
        }

        DispatchQueue.global(qos: .background).async { [weak self] in
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            if let error = String(data: errorData, encoding: .utf8), !error.isEmpty {
                self?.appState.warning(error, category: .gameError)
            }
        }

        do {
            try process.run()
            appState.log(
                "App process started with PID: \(process.processIdentifier)", category: .games)
            process.waitUntilExit()
            appState.log("App exited with status: \(process.terminationStatus)", category: .games)
            if process.terminationStatus != 0, let game {
                appState.markLaunchFailed(
                    game,
                    message: "App exited with status: \(process.terminationStatus)"
                )
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
