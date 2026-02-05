import CryptoKit
import Foundation

/// Developer feedback system with authentication
/// Access via developer password (set in code)
class DeveloperFeedback {
    static let shared = DeveloperFeedback()
    private let appState = AppState.shared

    // MARK: - Models

    struct FeedbackSession: Identifiable {
        let id: UUID = UUID()
        let timestamp: Date
        let sessionLog: String
        let processLogs: [ProcessLog]
        let errorLogs: [ErrorLog]
        let successLogs: [SuccessLog]
    }

    struct ProcessLog: Identifiable {
        let id: UUID = UUID()
        let timestamp: Date
        let processName: String
        let action: String
        let details: String
    }

    struct ErrorLog: Identifiable {
        let id: UUID = UUID()
        let timestamp: Date
        let source: String
        let message: String
        let stackTrace: String?
    }

    struct SuccessLog: Identifiable {
        let id: UUID = UUID()
        let timestamp: Date
        let source: String
        let message: String
    }

    // MARK: - Properties

    private var sessionStartTime: Date = Date()
    private var processLogs: [ProcessLog] = []
    private var errorLogs: [ErrorLog] = []
    private var successLogs: [SuccessLog] = []
    private var _isAuthenticated = false

    // Developer password hash
    // SHA256 hash: 8d969eef6ecad3c29a3a873e9c9e44e47c6d1e1e3a90be2a3c5e48c12c3c4d5
    private let hashedPassword = "8d969eef6ecad3c29a3a873e9c9e44e47c6d1e1e3a90be2a3c5e48c12c3c4d5"

    // MARK: - Authentication

    func authenticate(with password: String) -> Bool {
        let hash = SHA256.hash(data: password.data(using: .utf8) ?? Data())
        let hashString = hash.map { String(format: "%02x", $0) }.joined()

        _isAuthenticated = hashString == hashedPassword

        if _isAuthenticated {
            appState.log("Developer mode authenticated", category: .engine)
        } else {
            appState.warning("Failed developer authentication attempt", category: .engine)
        }

        return _isAuthenticated
    }

    func isAuthenticated() -> Bool {
        return _isAuthenticated
    }

    func logout() {
        _isAuthenticated = false
        appState.log("Developer mode logged out", category: .engine)
    }

    // MARK: - Logging Methods

    func logProcess(_ processName: String, action: String, details: String = "") {
        guard isAuthenticated() else { return }

        let log = ProcessLog(
            timestamp: Date(),
            processName: processName,
            action: action,
            details: details
        )
        processLogs.append(log)
        appState.log("[\(processName)] \(action): \(details)", category: .engine)
    }

    func logError(_ source: String, message: String, stackTrace: String? = nil) {
        guard isAuthenticated() else { return }

        let log = ErrorLog(
            timestamp: Date(),
            source: source,
            message: message,
            stackTrace: stackTrace
        )
        errorLogs.append(log)
        appState.error("[\(source)] \(message)", category: .engine)
    }

    func logSuccess(_ source: String, message: String) {
        guard isAuthenticated() else { return }

        let log = SuccessLog(
            timestamp: Date(),
            source: source,
            message: message
        )
        successLogs.append(log)
        appState.log("✅ [\(source)] \(message)", category: .engine)
    }

    // MARK: - Session Management

    func getCurrentSession() -> FeedbackSession? {
        guard isAuthenticated() else { return nil }

        let sessionLog = generateSessionLog()

        return FeedbackSession(
            timestamp: sessionStartTime,
            sessionLog: sessionLog,
            processLogs: processLogs,
            errorLogs: errorLogs,
            successLogs: successLogs
        )
    }

    func exportSession() -> String? {
        guard let session = getCurrentSession() else { return nil }

        var export = """
            ╔════════════════════════════════════════════════════════╗
            ║        FLUX DEVELOPER SESSION REPORT                   ║
            ║        Generated: \(formatDate(session.timestamp))
            ╚════════════════════════════════════════════════════════╝

            SESSION DURATION: \(formatDuration(from: sessionStartTime, to: Date()))

            ═══════════════════════════════════════════════════════════
            PROCESS LOGS (\(session.processLogs.count) entries)
            ═══════════════════════════════════════════════════════════
            """

        for log in session.processLogs {
            export += """

                [\(formatTime(log.timestamp))] \(log.processName)
                Action: \(log.action)
                Details: \(log.details)
                """
        }

        export += """

            ═══════════════════════════════════════════════════════════
            SUCCESS LOGS (\(session.successLogs.count) entries)
            ═══════════════════════════════════════════════════════════
            """

        for log in session.successLogs {
            export += """

                [\(formatTime(log.timestamp))] \(log.source)
                ✅ \(log.message)
                """
        }

        export += """

            ═══════════════════════════════════════════════════════════
            ERROR LOGS (\(session.errorLogs.count) entries)
            ═══════════════════════════════════════════════════════════
            """

        for log in session.errorLogs {
            export += """

                [\(formatTime(log.timestamp))] \(log.source)
                ❌ \(log.message)
                """
            if let stackTrace = log.stackTrace {
                export += "\nStack Trace:\n\(stackTrace)"
            }
        }

        export += "\n\n✅ Session report generated successfully"

        return export
    }

    func clearSession() {
        guard isAuthenticated() else { return }

        processLogs.removeAll()
        errorLogs.removeAll()
        successLogs.removeAll()
        sessionStartTime = Date()

        appState.log("Developer session cleared", category: .engine)
    }

    // MARK: - Report Generation

    private func generateSessionLog() -> String {
        return """
            Session Started: \(formatDate(sessionStartTime))
            Duration: \(formatDuration(from: sessionStartTime, to: Date()))
            Processes Logged: \(processLogs.count)
            Success Events: \(successLogs.count)
            Errors: \(errorLogs.count)
            """
    }

    // MARK: - Formatting Helpers

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: date)
    }

    private func formatDuration(from start: Date, to end: Date) -> String {
        let interval = Int(end.timeIntervalSince(start))
        let hours = interval / 3600
        let minutes = (interval % 3600) / 60
        let seconds = interval % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m \(seconds)s"
        } else if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }

    // MARK: - File Export

    func exportSessionToFile() -> URL? {
        guard let exportContent = exportSession() else { return nil }

        let fileName = "FluxDeveloperSession_\(ISO8601DateFormatter().string(from: Date())).txt"

        let logsDir = SettingsManager.shared.getLogsDirectory()
        let filePath = (logsDir as NSString).appendingPathComponent(fileName)

        do {
            try exportContent.write(toFile: filePath, atomically: true, encoding: .utf8)
            appState.log("Developer session exported to: \(filePath)", category: .engine)
            return URL(fileURLWithPath: filePath)
        } catch {
            appState.error(
                "Failed to export session: \(error.localizedDescription)", category: .engine)
            return nil
        }
    }
}
