import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    @State private var selection: SidebarSelection = .games

    enum SidebarSelection {
        case dashboard
        case games
        case prefixes
        case logs
        case settings
    }

    var themeColors: ThemeManager.Colors {
        themeManager.colors(for: themeManager.currentTheme)
    }

    // Show startup only if onboarding is NOT complete
    var shouldShowStartup: Bool {
        !appState.settingsManager.hasCompletedOnboarding
    }

    var body: some View {
        if shouldShowStartup {
            StartupView()
                .environmentObject(appState)
                .environmentObject(themeManager)
        } else {
            ZStack {
                themeColors.background.ignoresSafeArea()

                HStack(spacing: 0) {
                    // Sidebar
                    VStack(spacing: 0) {
                        List(selection: $selection) {
                            NavigationLink(value: SidebarSelection.dashboard) {
                                Label("Dashboard", systemImage: "rectangle.grid.2x2.fill")
                                    .foregroundStyle(themeColors.text.opacity(0.95))
                            }

                            NavigationLink(value: SidebarSelection.games) {
                                Label("Games", systemImage: "gamecontroller.fill")
                                    .foregroundStyle(themeColors.text.opacity(0.95))  // Brighter
                            }

                            NavigationLink(value: SidebarSelection.prefixes) {
                                Label("Prefixes", systemImage: "folder.fill")
                                    .foregroundStyle(themeColors.text.opacity(0.95))  // Brighter
                            }

                            NavigationLink(value: SidebarSelection.logs) {
                                Label("Logs", systemImage: "terminal.fill")
                                    .foregroundStyle(themeColors.text.opacity(0.95))  // Brighter
                            }

                            NavigationLink(value: SidebarSelection.settings) {
                                Label("Settings", systemImage: "gear")
                                    .foregroundStyle(themeColors.text.opacity(0.95))  // Brighter
                            }
                        }
                        .listStyle(.sidebar)
                        .scrollContentBackground(.hidden)
                        .frame(maxWidth: 180)
                    }
                    .background(themeColors.secondaryBackground)

                    // Main content
                    VStack {
                        switch selection {
                        case .dashboard:
                            DashboardView()
                        case .games:
                            GamesView()
                        case .prefixes:
                            PrefixesView()
                        case .logs:
                            LogsView()
                        case .settings:
                            SettingsView()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .sheet(
                isPresented: Binding(
                    get: { appState.shouldShowPatchNotes },
                    set: { appState.shouldShowPatchNotes = $0 }
                )
            ) {
                if let notes = appState.activePatchNotes {
                    PatchNotesSheet(
                        notes: notes,
                        themeColors: themeColors,
                        onDismiss: {
                            appState.dismissPatchNotes()
                        })
                } else {
                    EmptyView()
                }
            }
        }
    }
}

// MARK: - Patch Notes Sheet

struct PatchNotesSheet: View {
    let notes: AppState.PatchNotesEntry
    let themeColors: ThemeManager.Colors
    var onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("What's New in OpenFlux \(notes.version)")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(themeColors.text)
                Text(notes.date)
                    .font(.caption)
                    .foregroundStyle(themeColors.text.opacity(0.7))
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(notes.highlights, id: \.self) { item in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(themeColors.accent)
                        Text(item)
                            .foregroundStyle(themeColors.text.opacity(0.9))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(.vertical, 4)

            Divider()
                .background(themeColors.text.opacity(0.2))

            HStack {
                Spacer()
                Button(action: onDismiss) {
                    Text("Got it")
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(themeColors.accent.opacity(0.15))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(22)
        .frame(minWidth: 520)
        .background(
            ZStack {
                LinearGradient(
                    colors: [
                        themeColors.secondaryBackground,
                        themeColors.background,
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                RoundedRectangle(cornerRadius: 18)
                    .stroke(themeColors.accent.opacity(0.25), lineWidth: 1)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .padding()
        .presentationDetents([.medium])
    }
}

// MARK: - Dashboard

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager

    var themeColors: ThemeManager.Colors {
        themeManager.colors(for: themeManager.currentTheme)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Dashboard")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(themeColors.text)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Recents")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(themeColors.text)

                    if appState.recentLaunches.isEmpty {
                        Text("No recent launches yet.")
                            .font(.caption)
                            .foregroundStyle(themeColors.secondaryText)
                    } else {
                        ForEach(appState.recentLaunches) { launch in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(launch.name)
                                        .font(.headline)
                                        .foregroundStyle(themeColors.text)
                                    Text(
                                        "\(launch.launchMethod.rawValue) • \(launch.launchedAt.formatted(date: .abbreviated, time: .shortened))"
                                    )
                                    .font(.caption)
                                    .foregroundStyle(themeColors.secondaryText)
                                }
                                Spacer()
                            }
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(themeColors.cardBackground)
                            )
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(themeColors.background.ignoresSafeArea())
    }
}
#if canImport(PreviewsMacros)
    #Preview {
        ContentView()
            .environmentObject(AppState.shared)
            .environmentObject(ThemeManager.shared)
    }
#endif
