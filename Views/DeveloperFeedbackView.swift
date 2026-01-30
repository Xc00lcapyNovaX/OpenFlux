import SwiftUI

private enum Constants {
    // Obfuscated to prevent spam scraping
    private static let _ep = ["aHR0cHM6Ly9mb3Jtc3ByZWUuaW8vZi94ZWVrenFhcQ=="]
    private static let _em = ["ZGV2Lm9wZW5mbHV4QGdtYWlsLmNvbQ=="]

    static var emailEndpoint: String {
        guard let data = Data(base64Encoded: _ep[0]),
            let str = String(data: data, encoding: .utf8)
        else { return "" }
        return str
    }

    static var devEmail: String {
        guard let data = Data(base64Encoded: _em[0]),
            let str = String(data: data, encoding: .utf8)
        else { return "" }
        return str
    }

    static let appVersion = "1.0.1"
}

struct DeveloperFeedbackView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var feedbackText = ""
    @State private var showExportSuccess = false
    @State private var showSendSuccess = false
    @State private var showSendError = false
    @State private var isSending = false

    var body: some View {
        VStack(spacing: 16) {
            developerDashboard
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.controlBackgroundColor))
    }

    // MARK: - Developer Dashboard

    private var developerDashboard: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("👨‍💻 Developer Feedback System")
                        .font(.headline)
                    Text("Monitor all processes, errors, and successes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Session Info
            if let session = appState.getDeveloperSession() {
                sessionInfoSection(session)
            }

            Divider()

            // Log Sections
            TabView {
                feedbackTab
                    .tabItem {
                        Label("Feedback", systemImage: "bubble.left.and.bubble.right")
                    }
                processingLogsTab
                    .tabItem {
                        Label("Processing", systemImage: "gearshape")
                    }
                successLogsTab
                    .tabItem {
                        Label("Success", systemImage: "checkmark.circle")
                    }
                errorLogsTab
                    .tabItem {
                        Label("Errors", systemImage: "xmark.octagon")
                    }
                systemReportTab
                    .tabItem {
                        Label("System", systemImage: "desktopcomputer")
                    }
            }
            .tabViewStyle(.automatic)

            Divider()

            // Export Buttons
            HStack(spacing: 12) {
                Button(action: exportToClipboard) {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)

                Button(action: exportToFile) {
                    Label("Export", systemImage: "arrow.down.doc")
                }
                .buttonStyle(.bordered)

                Button(role: .destructive, action: clearLogs) {
                    Label("Clear", systemImage: "trash")
                }
                .buttonStyle(.bordered)

                Spacer()
            }

            if showExportSuccess {
                Text("✅ Exported successfully")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
            if showSendSuccess {
                Text("✅ Feedback sent successfully!")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
            if showSendError {
                Text("❌ Failed to send feedback")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var feedbackTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Send Feedback to Developers")
                .font(.subheadline)
                .fontWeight(.semibold)

            TextEditor(text: $feedbackText)
                .font(.caption)
                .frame(height: 120)
                .border(Color.gray.opacity(0.3))
                .cornerRadius(4)
                .lineLimit(8)

            Button(action: sendFeedback) {
                if isSending {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(maxWidth: .infinity)
                } else {
                    Label("Send Feedback", systemImage: "paperplane.fill")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(feedbackText.trimmingCharacters(in: .whitespaces).isEmpty || isSending)

            Spacer()
        }
        .padding()
    }

    // MARK: - Session Info

    private func sessionInfoSection(_ session: DeveloperFeedback.FeedbackSession) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Session Info")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Processes")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(session.processLogs.count)")
                                .font(.caption2)
                                .fontWeight(.semibold)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Success")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(session.successLogs.count)")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.green)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Errors")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(session.errorLogs.count)")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.red)
                        }
                    }
                }

                Spacer()
            }
        }
        .padding(12)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
    }

    // MARK: - Log Tabs

    private var processingLogsTab: some View {
        VStack {
            if let session = appState.getDeveloperSession(), !session.processLogs.isEmpty {
                List(session.processLogs) { log in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(log.processName)
                                .font(.caption)
                                .fontWeight(.semibold)

                            Text(log.action)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Spacer()

                            Text(formatTime(log.timestamp))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }

                        if !log.details.isEmpty {
                            Text(log.details)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } else {
                emptyState("No process logs")
            }
        }
    }

    private var successLogsTab: some View {
        VStack {
            if let session = appState.getDeveloperSession(), !session.successLogs.isEmpty {
                List(session.successLogs) { log in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)

                            Text(log.source)
                                .font(.caption)
                                .fontWeight(.semibold)

                            Spacer()

                            Text(formatTime(log.timestamp))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }

                        Text(log.message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                emptyState("No successes yet")
            }
        }
    }

    private var errorLogsTab: some View {
        VStack {
            if let session = appState.getDeveloperSession(), !session.errorLogs.isEmpty {
                List(session.errorLogs) { log in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.red)

                            Text(log.source)
                                .font(.caption)
                                .fontWeight(.semibold)

                            Spacer()

                            Text(formatTime(log.timestamp))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }

                        Text(log.message)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if let stackTrace = log.stackTrace {
                            Text(stackTrace)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .padding(.top, 4)
                        }
                    }
                }
            } else {
                emptyState("No errors")
            }
        }
    }

    private var systemReportTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView {
                if let systemInfo = appState.systemInfo {
                    VStack(alignment: .leading, spacing: 12) {
                        reportSection("Steam Status") {
                            reportRow("Installed", systemInfo.steamInstalled ? "✅ Yes" : "❌ No")
                            reportRow("Version", systemInfo.steamVersion ?? "Unknown")
                        }

                        reportSection("System Capabilities") {
                            reportRow("Metal GPU", systemInfo.metalGPU ?? "None")
                            reportRow("Metal Support", systemInfo.metalSupport ? "✅ Yes" : "❌ No")
                            reportRow("x86 Support", systemInfo.x86Support ? "✅ Yes" : "❌ No")
                            reportRow("x64 Support", systemInfo.x64Support ? "✅ Yes" : "❌ No")
                        }

                        if !systemInfo.launcherVersions.isEmpty {
                            reportSection("Game Launchers") {
                                ForEach(
                                    systemInfo.launcherVersions.sorted(by: { $0.key < $1.key }),
                                    id: \.key
                                ) { name, version in
                                    reportRow(name, version)
                                }
                            }
                        }

                        if !systemInfo.detectedMods.isEmpty {
                            reportSection("Detected Mods (\(systemInfo.detectedMods.count))") {
                                ForEach(systemInfo.detectedMods) { mod in
                                    reportRow(
                                        mod.name, "\(mod.arch.rawValue) - \(formatBytes(mod.size))")
                                }
                            }
                        }
                    }
                    .padding()
                } else {
                    emptyState("Run system detection")
                }
            }
        }
    }

    // MARK: - Helper Views

    private func reportSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content)
        -> some View
    {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                content()
            }
            .padding(12)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(6)
        }
    }

    private func reportRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
        }
    }

    private func emptyState(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "square.stack.3d.up.slash")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.controlBackgroundColor))
    }

    // MARK: - Actions

    private func exportToClipboard() {
        if let export = appState.exportDeveloperSession() {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(export, forType: .string)
            showExportSuccess = true

            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                showExportSuccess = false
            }
        }
    }

    private func exportToFile() {
        if let fileURL = appState.exportDeveloperSessionToFile() {
            showExportSuccess = true
            let logCategory = AppState.Category(rawValue: "Engine") ?? .engine
            appState.log("Session exported to: \(fileURL.path)", category: logCategory)

            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                showExportSuccess = false
            }
        }
    }

    private func sendFeedback() {
        let feedbackContent = feedbackText.trimmingCharacters(in: .whitespaces)
        guard !feedbackContent.isEmpty else { return }

        isSending = true
        showSendSuccess = false
        showSendError = false

        // Prepare feedback with metadata
        let timestamp = DateFormatter.localizedString(
            from: Date(), dateStyle: .medium, timeStyle: .medium)
        let feedbackWithMetadata = """
            Feedback: \(feedbackContent)
            Time: \(timestamp)
            App Version: \(Constants.appVersion)
            """

        // POST to Formspree
        postFeedbackToEmail(feedbackWithMetadata) { success in
            DispatchQueue.main.async {
                self.isSending = false
                if success {
                    self.showSendSuccess = true
                    self.feedbackText = ""
                    appState.log("Feedback sent successfully", category: .engine)

                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        self.showSendSuccess = false
                    }
                } else {
                    self.showSendError = true
                    appState.error("Failed to send feedback", category: .engine)

                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        self.showSendError = false
                    }
                }
            }
        }
    }

    private func postFeedbackToEmail(_ content: String, completion: @escaping (Bool) -> Void) {
        // POST feedback via Formspree
        guard let url = URL(string: Constants.emailEndpoint) else {
            completion(false)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // Formspree expects 'message' field and optional '_replyto' for reply address
        let payload: [String: String] = [
            "message": content,
            "email": Constants.devEmail,
            "_subject": "OpenFlux Feedback from User",
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("[OF-E001] Failed to send feedback: \(error.localizedDescription)")
                completion(false)
            } else if let httpResponse = response as? HTTPURLResponse {
                print("[OF-I001] Feedback sent with status: \(httpResponse.statusCode)")
                // Formspree returns 200 on success
                completion(httpResponse.statusCode == 200)
            } else {
                completion(false)
            }
        }.resume()
    }

    private func clearLogs() {
        DeveloperFeedback.shared.clearSession()
    }

    // MARK: - Formatting Helpers

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

#if canImport(PreviewsMacros)
    #Preview {
        DeveloperFeedbackView()
            .environmentObject(AppState.shared)
    }
#endif
