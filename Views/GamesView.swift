import SwiftUI

struct GamesView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    @State private var selectedGame: Game?
    @State private var showLaunchConfirm = false
    @State private var selectedLaunchMethod: LaunchMethod = .direct
    @State private var selectedGPTKMode: GPTKMode = .inherit
    @State private var selectedGraphicsAPI: GraphicsAPI = .unknown
    @State private var includeOptionalGraphics = false

    var themeColors: ThemeManager.Colors {
        themeManager.colors(for: themeManager.currentTheme)
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                if let errorMsg = appState.errorMessage, !errorMsg.isEmpty {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(themeColors.warning)
                    Text(errorMsg)
                        .font(.caption)
                        .lineLimit(2)
                        .foregroundStyle(themeColors.text)
                    Spacer()
                    if let failed = appState.lastFailedLaunch {
                        Button(action: {
                            appState.clearLaunchFailure()
                            appState.launchGame(failed)
                        }) {
                            Text("Retry")
                                .font(.caption)
                                .foregroundStyle(themeColors.primary)
                        }
                        .buttonStyle(.plain)
                    }
                    Button(action: { appState.clearLaunchFailure() }) {
                        Image(systemName: "xmark")
                            .font(.caption)
                            .foregroundStyle(themeColors.warning)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(themeColors.warning.opacity(0.1))
                }

                if appState.isLoading {
                    VStack {
                        ProgressView()
                            .controlSize(.large)
                            .tint(themeColors.primary)
                        Text("Detecting Steam games...")
                            .foregroundStyle(themeColors.secondaryText)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if appState.games.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "gamecontroller")
                            .font(.system(size: 48))
                            .foregroundStyle(themeColors.secondaryText)
                        Text("No games found")
                            .font(.headline)
                            .foregroundStyle(themeColors.text)
                        Text("Make sure Steam is installed and configured")
                            .font(.caption)
                            .foregroundStyle(themeColors.secondaryText)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(appState.games, selection: $selectedGame) { game in
                        GameRow(game: game)
                            .environmentObject(themeManager)
                    }
                    .scrollContentBackground(.hidden)
                    .listRowBackground(themeColors.cardBackground)
                }

                Divider()
                    .background(themeColors.secondaryText.opacity(0.1))

                // Status bar
                HStack(spacing: 16) {
                    Text("\(appState.games.count) games detected")
                        .font(.caption)
                        .foregroundStyle(themeColors.secondaryText)

                    Spacer()

                    Button(action: { appState.detectGames() }) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .foregroundStyle(themeColors.primary)

                    Button(action: { appState.launchTestGame() }) {
                        Label("🧪 Test", systemImage: "checkmark.circle")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .foregroundStyle(themeColors.warning)

                    if selectedGame != nil {
                        Button(action: { showLaunchConfirm = true }) {
                            Label("Launch", systemImage: "play.fill")
                                .font(.caption)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(themeColors.success)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(themeColors.cardBackground)
            }

            if appState.isLaunchLoading {
                LaunchLoadingOverlay(
                    title: appState.launchLoadingTitle,
                    message: appState.launchLoadingMessage,
                    themeColors: themeColors
                )
            }
        }
        .background(themeColors.background.ignoresSafeArea())
        .sheet(item: $appState.activeDependencyPrompt) { prompt in
            DependencyPromptView(
                prompt: prompt,
                includeOptional: $includeOptionalGraphics
            )
            .environmentObject(appState)
            .environmentObject(themeManager)
        }
        .confirmationDialog(
            "Launch \(selectedGame?.name ?? "")?",
            isPresented: $showLaunchConfirm
        ) {
            if let game = selectedGame {
                if game.steamAppId != 0 {
                    Picker("Launch Method", selection: Binding(
                        get: { selectedLaunchMethod },
                        set: { newValue in
                            selectedLaunchMethod = newValue
                            appState.updateLaunchMethod(for: game.id, method: newValue)
                        }
                    )) {
                        Text("Steam (recommended)").tag(LaunchMethod.steam)
                        Text("Direct executable").tag(LaunchMethod.direct)
                    }
                }

                Picker("GPTK", selection: Binding(
                    get: { selectedGPTKMode },
                    set: { newValue in
                        selectedGPTKMode = newValue
                        appState.updateGPTKMode(for: game.id, mode: newValue)
                    }
                )) {
                    Text("Inherit").tag(GPTKMode.inherit)
                    Text("Enabled").tag(GPTKMode.enabled)
                    Text("Disabled").tag(GPTKMode.disabled)
                }

                Picker("Graphics API", selection: Binding(
                    get: { selectedGraphicsAPI },
                    set: { newValue in
                        selectedGraphicsAPI = newValue
                        appState.updateGraphicsAPI(for: game.id, api: newValue)
                    }
                )) {
                    Text("Unknown").tag(GraphicsAPI.unknown)
                    Text("DirectX").tag(GraphicsAPI.directX)
                    Text("OpenGL").tag(GraphicsAPI.openGL)
                    Text("Vulkan").tag(GraphicsAPI.vulkan)
                }

                Button(
                    "Launch",
                    action: {
                        var launchGame = game
                        launchGame.launchMethod = selectedLaunchMethod
                        launchGame.gptkMode = selectedGPTKMode
                        launchGame.graphicsAPI = selectedGraphicsAPI
                        includeOptionalGraphics = false
                        appState.launchGame(launchGame)
                        appState.log("Game launch initiated: \(game.name)", category: .ui)
                    }
                )
                .keyboardShortcut(.defaultAction)

                Button("Cancel", role: .cancel) {}
            }
        }
        .onChange(of: selectedGame?.id) { _ in
            if let game = selectedGame {
                selectedLaunchMethod = game.launchMethod
                selectedGPTKMode = game.gptkMode
                selectedGraphicsAPI = game.graphicsAPI
            } else {
                selectedLaunchMethod = .direct
                selectedGPTKMode = .inherit
                selectedGraphicsAPI = .unknown
            }
        }
    }
}

struct GameRow: View {
    let game: Game
    @EnvironmentObject var themeManager: ThemeManager

    var themeColors: ThemeManager.Colors {
        themeManager.colors(for: themeManager.currentTheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(game.name)
                        .font(.headline)
                        .lineLimit(1)
                        .foregroundStyle(themeColors.text)

                    HStack(spacing: 12) {
                        if !game.missingDependencies.isEmpty {
                            Label(
                                "Missing dependencies",
                                systemImage: "exclamationmark.triangle.fill"
                            )
                            .font(.caption)
                            .foregroundStyle(themeColors.warning)
                        }

                        if game.hasDRMWarning {
                            Label(
                                "DRM detected",
                                systemImage: "lock.fill"
                            )
                            .font(.caption)
                            .foregroundStyle(themeColors.warning)
                        }

                        Text("Steam: \(game.steamAppId)")
                            .font(.caption)
                            .foregroundStyle(themeColors.secondaryText)

                        if game.steamAppId != 0 {
                            Text("Launch: \(game.launchMethod.rawValue)")
                                .font(.caption)
                                .foregroundStyle(themeColors.secondaryText)
                        }
                    }
                }

                Spacer()

                if let lastLaunch = game.lastLaunchDate {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(lastLaunch.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundStyle(themeColors.secondaryText)
                        Text("\(game.playtime)m played")
                            .font(.caption2)
                            .foregroundStyle(themeColors.secondaryText)
                    }
                }
            }

            if !game.installPath.isEmpty {
                Text(game.installPath)
                    .font(.caption)
                    .foregroundStyle(themeColors.secondaryText)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 8)
    }
}

struct LaunchLoadingOverlay: View {
    let title: String
    let message: String
    let themeColors: ThemeManager.Colors

    var body: some View {
        ZStack {
            themeColors.background.opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .controlSize(.large)
                    .tint(themeColors.primary)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(themeColors.text)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(themeColors.secondaryText)
            }
            .padding(24)
            .background(themeColors.cardBackground)
            .cornerRadius(16)
            .shadow(color: themeColors.background.opacity(0.4), radius: 20, x: 0, y: 10)
        }
    }
}

struct DependencyPromptView: View {
    let prompt: AppState.DependencyPrompt
    @Binding var includeOptional: Bool
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager

    private var themeColors: ThemeManager.Colors {
        themeManager.colors(for: themeManager.currentTheme)
    }

    private var requiredByCategory: [DependencyCategory: [DependencyItem]] {
        Dictionary(grouping: prompt.report.required, by: \.category)
    }

    private var optionalByCategory: [DependencyCategory: [DependencyItem]] {
        Dictionary(grouping: prompt.report.optional, by: \.category)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Missing Components Detected")
                .font(.headline)
                .foregroundStyle(themeColors.text)

            Text("Install the required components before launching.")
                .font(.caption)
                .foregroundStyle(themeColors.secondaryText)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(DependencyCategory.allCases, id: \.self) { category in
                        if let items = requiredByCategory[category], !items.isEmpty {
                            DependencyCategorySection(
                                title: category.rawValue,
                                items: items,
                                themeColors: themeColors
                            )
                        }
                    }

                    if !prompt.report.optional.isEmpty {
                        Divider()
                        ForEach(DependencyCategory.allCases, id: \.self) { category in
                            if let items = optionalByCategory[category], !items.isEmpty {
                                DependencyCategorySection(
                                    title: "\(category.rawValue) (Optional)",
                                    items: items,
                                    themeColors: themeColors
                                )
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: 260)

            if !prompt.report.optional.isEmpty {
                Toggle("Install optional graphics components (DXVK)", isOn: $includeOptional)
                    .toggleStyle(.switch)
            }

            HStack {
                Button("Cancel Launch") {
                    appState.cancelDependencyPrompt(for: prompt.report)
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Install Required") {
                    appState.installDependenciesAndLaunch(
                        report: prompt.report,
                        includeOptional: includeOptional
                    )
                }
                .buttonStyle(.borderedProminent)
                .tint(themeColors.primary)
            }
        }
        .padding(20)
        .background(themeColors.background)
        .frame(minWidth: 420, minHeight: 420)
        .onAppear {
            includeOptional = false
        }
    }
}

struct DependencyCategorySection: View {
    let title: String
    let items: [DependencyItem]
    let themeColors: ThemeManager.Colors

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(themeColors.text)

            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 2) {
                    Text("• \(item.name)")
                        .font(.caption)
                        .foregroundStyle(themeColors.text)
                    Text(item.fileName)
                        .font(.caption2)
                        .foregroundStyle(themeColors.secondaryText)
                    Text(item.details)
                        .font(.caption2)
                        .foregroundStyle(themeColors.secondaryText)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#if canImport(PreviewsMacros)
#if canImport(PreviewsMacros)
#Preview {
    GamesView()
        .environmentObject(AppState.shared)
        .environmentObject(ThemeManager.shared)
}
#endif
#endif
