import SwiftUI

struct DeveloperFeedbackView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var logManager: LogManager
    @State private var password: String = ""
    @State private var isAuthenticated = false
    @State private var showingPassword = false
    @State private var feedbackText = ""
    @State private var showExportSuccess = false
    
    var body: some View {
        VStack(spacing: 16) {
            if !isAuthenticated {
                authenticationSection
            } else {
                developerDashboard
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.controlBackgroundColor))
    }
    
    // MARK: - Authentication Section
    
    private var authenticationSection: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Text("🔐 Developer Mode")
                    .font(.headline)
                
                Text("Enter password to access developer feedback system")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    authenticateAndOpen()
                }
            
            Button(action: authenticateAndOpen) {
                Label("Access Developer Mode", systemImage: "lock.open")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(password.isEmpty)
            
            Spacer()
        }
    }
    
    private func authenticateAndOpen() {
        if appState.authenticateDeveloper(password: password) {
            isAuthenticated = true
            password = ""
        } else {
            logManager.error("Failed developer authentication attempt", category: "Engine")
        }
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
                
                Button(action: {
                    DeveloperFeedback.shared.logout()
                    isAuthenticated = false
                }) {
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
                processingLogsTab
                successLogsTab
                errorLogsTab
                systemReportTab
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
        }
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
                            reportRow("Steamwebhelper", systemInfo.steamwebhelperRunning ? "✅ Running" : "❌ Stopped")
                        }
                        
                        reportSection("System Capabilities") {
                            reportRow("Metal GPU", systemInfo.metalGPU ?? "None")
                            reportRow("Metal Support", systemInfo.metalSupport ? "✅ Yes" : "❌ No")
                            reportRow("x86 Support", systemInfo.x86Support ? "✅ Yes" : "❌ No")
                            reportRow("x64 Support", systemInfo.x64Support ? "✅ Yes" : "❌ No")
                        }
                        
                        if !systemInfo.launcherVersions.isEmpty {
                            reportSection("Game Launchers") {
                                ForEach(systemInfo.launcherVersions.sorted(by: { $0.key < $1.key }), id: \.key) { name, version in
                                    reportRow(name, version)
                                }
                            }
                        }
                        
                        if !systemInfo.detectedMods.isEmpty {
                            reportSection("Detected Mods (\(systemInfo.detectedMods.count))") {
                                ForEach(systemInfo.detectedMods) { mod in
                                    reportRow(mod.name, "\(mod.arch.rawValue) - \(formatBytes(mod.size))")
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
    
    private func reportSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
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
            logManager.log("Session exported to: \(fileURL.path)", category: "Engine")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                showExportSuccess = false
            }
        }
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
#if canImport(PreviewsMacros)
#Preview {
    DeveloperFeedbackView()
        .environmentObject(AppState.shared)
}
#endif
#endif
