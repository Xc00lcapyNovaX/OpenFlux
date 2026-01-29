import SwiftUI

struct LogsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    @State private var autoScroll = true
    @State private var filterLevel: AppState.LogLevel?
    
    var themeColors: ThemeManager.Colors {
        themeManager.colors(for: themeManager.currentTheme)
    }
    
    var filteredLogs: [AppState.LogEntry] {
        if let level = filterLevel {
            return appState.logs.filter { $0.level == level }
        }
        return appState.logs
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
                    List(filteredLogs) { entry in
                        LogEntryRow(entry: entry)
                            .environmentObject(themeManager)
                            .id(entry.id)
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
                    Label("Copy", systemImage: "doc.on.doc")
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
            }
        }
        .padding(.vertical, 4)
        .contextMenu {
            Button(action: {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(entry.message, forType: .string)
            }) {
                Label("Copy", systemImage: "doc.on.doc")
            }
        }
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
