@_exported import Foundation
import SwiftUI
import UniformTypeIdentifiers

// MARK: - UTType Extensions for Windows Executables

extension UTType {
    static var exe: UTType {
        UTType(filenameExtension: "exe") ?? .data
    }
    static var msi: UTType {
        UTType(filenameExtension: "msi") ?? .data
    }
    static var dll: UTType {
        UTType(filenameExtension: "dll") ?? .data
    }
}

// Ensure AppState is imported - check your project structure
// Common locations: Models/AppState.swift or Core/AppState.swift
// If AppState is in a separate module/framework: import ModuleName

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    @State private var selection: SidebarSelection = .games
    @State private var showFeedback = false

    enum SidebarSelection {
        case dashboard
        case games
        case prefixes
        case logs
        case settings
        case account
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
                            
                            Divider()
                                .padding(.vertical, 8)
                            
                            NavigationLink(value: SidebarSelection.account) {
                                Label("Account", systemImage: "person.circle.fill")
                                    .foregroundStyle(themeColors.text.opacity(0.95))
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
                        case .account:
                            AccountView()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .scaleEffect(appState.settingsManager.uiScale)
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity
                )

                // Feedback Button Overlay
                VStack {
                    Spacer()
                    HStack {
                        if appState.settingsManager.feedbackButtonPosition == "bottomRight" {
                            Spacer()
                            feedbackButton
                        } else {
                            feedbackButton
                            Spacer()
                        }
                    }
                }
                .padding(16)
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
            .sheet(isPresented: $showFeedback) {
                DeveloperFeedbackView()
                    .environmentObject(themeManager)
                    .environmentObject(appState)
            }
        }
    }

    private var feedbackButton: some View {
        Button(action: { showFeedback = true }) {
            Label("Feedback", systemImage: "bubbles.and.sparkles")
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(themeColors.primary.opacity(0.9))
                )
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
        .help("Send feedback to the developers")
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
    @State private var showFilePicker = false

    var themeColors: ThemeManager.Colors {
        themeManager.colors(for: themeManager.currentTheme)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header row with Dashboard title and Run button
                HStack(alignment: .center) {
                    Text("Dashboard")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(themeColors.text)

                    Spacer()
                        .frame(maxWidth: 60)

                    // Run button - positioned between left and middle
                    Button(action: { showFilePicker = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Run")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(themeColors.accent)
                        )
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .help("Run a Windows executable (.exe, .msi)")

                    Spacer()
                }

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
                            HStack(spacing: 12) {
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

                                Button(action: { launchRecent(launch) }) {
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.white)
                                        .padding(8)
                                        .background(
                                            Circle()
                                                .fill(themeColors.primary)
                                        )
                                }
                                .buttonStyle(.plain)
                                .help("Launch \(launch.name)")
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
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.exe, .msi, .dll],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    // Start accessing the security-scoped resource
                    guard url.startAccessingSecurityScopedResource() else {
                        appState.setError(.fileAccessDenied, details: url.lastPathComponent)
                        return
                    }
                    defer { url.stopAccessingSecurityScopedResource() }
                    appState.handleOpenURL(url)
                }
            case .failure(let error):
                appState.setError(.fileAccessDenied, details: error.localizedDescription)
            }
        }
    }

    private func launchRecent(_ launch: AppState.RecentLaunch) {
        // Find the game with matching executable path and steam ID
        if let game = appState.games.first(where: {
            $0.executablePath == launch.executablePath && $0.steamAppId == launch.steamAppId
        }) {
            appState.launchGame(game)
        } else {
            // Create a temporary game object if not found in current list
            let tempGame = Game(
                name: launch.name,
                executablePath: launch.executablePath,
                installPath: (launch.executablePath as NSString).deletingLastPathComponent,
                steamAppId: launch.steamAppId,
                launchMethod: launch.launchMethod
            )
            appState.launchGame(tempGame)
        }
    }
}

#if canImport(PreviewsMacros)
    #Preview {
        ContentView()
            .environmentObject(AppState.shared)
            .environmentObject(ThemeManager.shared)
    }
#endif
