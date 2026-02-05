import SwiftUI

struct LogsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    @State private var autoScroll = true
    @State private var filterLevel: AppState.LogLevel?
    @State private var expandedApps: Set<String> = []  // Track which apps are expanded
    @State private var expandedSessions: Set<String> = []  // Track which sessions are expanded
    @State private var highlightedLogId: UUID? = nil  // Track highlighted log

    var themeColors: ThemeManager.Colors {
        themeManager.colors(for: themeManager.currentTheme)
    }

    var filteredLogs: [AppState.LogEntry] {
        if let level = filterLevel {
            return appState.logs.filter { $0.level == level }
        }
        return appState.logs
    }

    // Group logs by app name, then by session ID
    var logsByAppAndSession:
        [(
            appName: String,
            sessions: [(
                sessionId: String, startTime: Date, logCount: Int, logs: [AppState.LogEntry]
            )]
        )]
    {
        guard !filteredLogs.isEmpty else { return [] }

        // Group by app name first
        var appMap: [String: [AppState.LogEntry]] = [:]
        for log in filteredLogs {
            let appName = log.appName ?? "System"
            if appMap[appName] == nil {
                appMap[appName] = []
            }
            appMap[appName]?.append(log)
        }

        // For each app, group by session
        return appMap.sorted { $0.key < $1.key }.map { appName, logs in
            var sessionMap: [String: (startTime: Date, logs: [AppState.LogEntry])] = [:]

            for log in logs {
                if sessionMap[log.sessionId] == nil {
                    sessionMap[log.sessionId] = (startTime: log.timestamp, logs: [])
                }
                sessionMap[log.sessionId]?.logs.append(log)
            }

            let sessions = sessionMap.sorted { a, b in
                a.value.startTime.compare(b.value.startTime) == .orderedDescending
            }.map { sessionId, data in
                (
                    sessionId: sessionId,
                    startTime: data.startTime,
                    logCount: data.logs.count,
                    logs: data.logs
                )
            }

            return (appName: appName, sessions: sessions)
        }
    }

    // Status helpers
    private var wineStatus: String {
        if let path = WineDetector.shared.wineExecutablePath {
            return "Wine: found at \(path)"
        }
        return "Wine: not installed"
    }

    private var gptkStatus: String {
        if let path = GPTKDetector.shared.libraryPath {
            return "GPTK: found at \(path)"
        }
        let expected = SettingsManager.shared.gptkPath + "/lib"
        return "GPTK: not installed (expected at \(expected))"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Runtime status bar
            HStack(spacing: 12) {
                Label(wineStatus, systemImage: "wineglass")
                    .font(.caption)
                    .foregroundStyle(themeColors.text)
                Label(gptkStatus, systemImage: "shippingbox")
                    .font(.caption)
                    .foregroundStyle(themeColors.text)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(themeColors.cardBackground)

            if appState.logs.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "terminal")
                        .font(.system(size: 48))
                        .foregroundStyle(themeColors.secondaryText)
                    Text("No logs yet")
                        .font(.headline)
                        .foregroundStyle(themeColors.text)
                    Text("Game output and system messages will appear here")
                        .font(.caption)
                        .foregroundStyle(themeColors.secondaryText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    List {
                        // Apps level
                        ForEach(logsByAppAndSession, id: \.appName) { appGroup in
                            DisclosureGroup(
                                isExpanded: Binding(
                                    get: { expandedApps.contains(appGroup.appName) },
                                    set: { isExpanded in
                                        if isExpanded {
                                            expandedApps.insert(appGroup.appName)
                                        } else {
                                            expandedApps.remove(appGroup.appName)
                                        }
                                    }
                                )
                            ) {
                                // Sessions level
                                ForEach(appGroup.sessions, id: \.sessionId) { session in
                                    DisclosureGroup(
                                        isExpanded: Binding(
                                            get: { expandedSessions.contains(session.sessionId) },
                                            set: { isExpanded in
                                                if isExpanded {
                                                    expandedSessions.insert(session.sessionId)
                                                } else {
                                                    expandedSessions.remove(session.sessionId)
                                                }
                                            }
                                        )
                                    ) {
                                        // Logs
                                        ForEach(session.logs) { entry in
                                            LogEntryRow(
                                                entry: entry,
                                                isHighlighted: highlightedLogId == entry.id
                                            )
                                            .environmentObject(themeManager)
                                            .id(entry.id)
                                            .onTapGesture {
                                                highlightedLogId =
                                                    (highlightedLogId == entry.id) ? nil : entry.id
                                            }
                                        }
                                    } label: {
                                        HStack(spacing: 8) {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text("Launched")
                                                    .font(.caption)
                                                    .fontWeight(.semibold)
                                                    .foregroundStyle(themeColors.text)

                                                Text(
                                                    session.startTime.formatted(
                                                        date: .omitted, time: .standard)
                                                )
                                                .font(.caption2)
                                                .foregroundStyle(themeColors.secondaryText)
                                            }

                                            Spacer()

                                            HStack(spacing: 6) {
                                                Text("\(session.logCount)")
                                                    .font(.caption2)
                                                    .foregroundStyle(themeColors.accent)

                                                Button(action: {
                                                    let sessionLogs = session.logs
                                                        .map {
                                                            "[\($0.timestamp.formatted(date: .omitted, time: .standard))] [\($0.level.rawValue)] [\($0.category.rawValue)] \($0.message)"
                                                        }
                                                        .joined(separator: "\n")
                                                    NSPasteboard.general.clearContents()
                                                    NSPasteboard.general.setString(
                                                        sessionLogs, forType: .string)
                                                }) {
                                                    Image(systemName: "doc.on.doc")
                                                        .font(.caption2)
                                                        .foregroundStyle(themeColors.primary)
                                                }
                                                .buttonStyle(.plain)
                                                .help("Copy session logs")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "app.badge")
                                        .font(.caption)
                                        .foregroundStyle(themeColors.primary)

                                    Text(appGroup.appName)
                                        .font(.callout)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(themeColors.text)

                                    Spacer()

                                    Text(
                                        "\(appGroup.sessions.count) session\(appGroup.sessions.count != 1 ? "s" : "")"
                                    )
                                    .font(.caption2)
                                    .foregroundStyle(themeColors.accent)
                                }
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .listStyle(.plain)
                    .onChange(of: filteredLogs.count) { newCount in
                        if autoScroll, let lastId = filteredLogs.last?.id {
                            proxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()
                .background(themeColors.secondaryText.opacity(0.1))

            // Filter bar and controls
            HStack(spacing: 12) {
                Menu {
                    Button("All") {
                        filterLevel = nil
                    }

                    Divider()

                    ForEach(AppState.LogLevel.allCases, id: \.self) { level in
                        Button(level.rawValue) {
                            filterLevel = level
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                        Text(filterLevel?.rawValue ?? "All")
                    }
                    .font(.caption)
                    .foregroundStyle(themeColors.primary)
                }
                .menuStyle(.button)
                .buttonStyle(.bordered)
                .foregroundStyle(themeColors.primary)

                Spacer()

                Toggle(isOn: $autoScroll) {
                    Label("Auto-scroll", systemImage: "arrow.down")
                        .font(.caption)
                        .foregroundStyle(themeColors.text)
                }
                .controlSize(.small)
                .tint(themeColors.primary)

                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(appState.exportLogs(), forType: .string)
                }) {
                    Label("Copy All", systemImage: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .foregroundStyle(themeColors.primary)

                Button(action: { appState.clearLogs() }) {
                    Label("Clear", systemImage: "trash")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .foregroundStyle(themeColors.destructive)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(themeColors.cardBackground)
        }
        .background(themeColors.background.ignoresSafeArea())
    }
}

struct LogEntryRow: View {
    let entry: AppState.LogEntry
    let isHighlighted: Bool
    @EnvironmentObject var themeManager: ThemeManager

    var themeColors: ThemeManager.Colors {
        themeManager.colors(for: themeManager.currentTheme)
    }

    var levelColor: Color {
        switch entry.level {
        case .debug:
            return themeColors.secondaryText
        case .info:
            return themeColors.primary
        case .warning:
            return themeColors.warning
        case .error:
            return themeColors.destructive
        }
    }

    var levelIcon: String {
        switch entry.level {
        case .debug:
            return "o.circle"
        case .info:
            return "info.circle"
        case .warning:
            return "exclamationmark.triangle"
        case .error:
            return "x.circle"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Image(systemName: levelIcon)
                    .foregroundStyle(levelColor)
                    .frame(width: 16)

                Text(entry.timestamp.formatted(date: .omitted, time: .standard))
                    .font(.caption2)
                    .foregroundStyle(themeColors.secondaryText)
                    .frame(width: 60, alignment: .leading)

                Text(entry.category.rawValue)
                    .font(.caption)
                    .foregroundStyle(themeColors.accent)
                    .frame(width: 80, alignment: .leading)

                Text(entry.message)
                    .font(.caption)
                    .foregroundStyle(themeColors.text)
                    .lineLimit(3)

                Spacer()

                // Copy button
                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(entry.message, forType: .string)
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.caption2)
                        .foregroundStyle(themeColors.primary)
                }
                .buttonStyle(.plain)
                .opacity(isHighlighted ? 1 : 0.5)
                .help("Copy log entry")
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(isHighlighted ? themeColors.primary.opacity(0.2) : Color.clear)
        .cornerRadius(4)
    }
}

#if canImport(PreviewsMacros)
    #if canImport(PreviewsMacros)
        #Preview {
            LogsView()
                .environmentObject(AppState.shared)
                .environmentObject(ThemeManager.shared)
        }
    #endif
#endif
