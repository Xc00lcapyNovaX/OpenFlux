import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var settingsManager = SettingsManager.shared
    @State private var wineVersion = "Detecting..."
    @State private var gptkVersion = "Detecting..."
    @State private var metalDevice = "Detecting..."
    @State private var installStatus = ""
    @State private var showDeveloperFeedback = false
    @State private var developerDoubleClickCount = 0

    var themeColors: ThemeManager.Colors {
        themeManager.colors(for: themeManager.currentTheme)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header with theme info
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("⚙️ Settings")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(themeColors.primary)

                            Text(themeManager.currentTheme.rawValue)
                                .font(.caption)
                                .foregroundStyle(themeColors.secondaryText)
                        }
                        Spacer()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                // Status Banners
                if let errorMsg = appState.errorMessage, !errorMsg.isEmpty {
                    statusBanner(message: errorMsg, color: themeColors.destructive)
                }

                if appState.updateAvailable {
                    statusBanner(
                        message: "🆕 " + (appState.updateMessage ?? "Updates available"),
                        color: themeColors.warning)
                }

                // Appearance/Theme Section
                themedSection("🎨 Appearance") {
                    appearanceSection
                }

                // Paths section
                themedSection("⚙️ Configuration") {
                    configurationSection
                }

                // System Info
                themedSection("🎮 System Capabilities") {
                    systemInfoSection
                }

                // Quick Actions
                themedSection("🚀 Quick Actions") {
                    quickActionsSection
                }

                // System Report
                if let systemInfo = appState.systemInfo {
                    themedSection("📊 System Report") {
                        systemReportSection(systemInfo)
                    }
                }

                // Feedback Settings
                themedSection("💬 Feedback") {
                    feedbackSettingsSection
                }

                Spacer()

                // Footer with developer access
                VStack {
                    Button(action: handleDeveloperClick) {
                        Text("v1.0 • © 2026 OpenFlux")
                            .font(.caption2)
                            .foregroundStyle(themeColors.secondaryText)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 16)
            }
        }
        .background(themeColors.background.ignoresSafeArea())
        .sheet(isPresented: $showDeveloperFeedback) {
            DeveloperFeedbackView()
                .environmentObject(themeManager)
        }
        .onAppear {
            detectVersions()
            appState.detectSystem()
        }
    }

    // MARK: - Theme Section

    @State private var showHexPicker = false
    @State private var selectedPickerColor = Color.blue

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Theme selection
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Choose Your Theme")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(themeColors.text)
                    Spacer()
                    Text("\(ThemeManager.Theme.allCases.count) themes")
                        .font(.caption)
                        .foregroundStyle(themeColors.secondaryText)
                }

                VStack(spacing: 8) {
                    ForEach(ThemeManager.Theme.allCases, id: \.self) { theme in
                        themeOptionButton(theme)
                    }
                }
            }

            Divider()
                .background(themeColors.secondaryText.opacity(0.2))

            // Hex Color Picker
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("🎨 Color Picker")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(themeColors.text)

                    Spacer()

                    Button(action: { showHexPicker.toggle() }) {
                        Text("Edit Colors")
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(themeColors.primary.opacity(0.2))
                            .foregroundStyle(themeColors.primary)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }

                if showHexPicker {
                    VStack(alignment: .leading, spacing: 12) {
                        ColorPickerView(selectedColor: $selectedPickerColor)

                        Button(action: copyColorToClipboard) {
                            HStack {
                                Image(systemName: "doc.on.doc")
                                Text("Copy Hex Code")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(10)
                            .background(themeColors.primary.opacity(0.15))
                            .foregroundStyle(themeColors.primary)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(12)
                    .background(themeColors.cardBackground)
                    .cornerRadius(8)
                }
            }

            Divider()
                .background(themeColors.secondaryText.opacity(0.2))

            // DPI Scaling
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("📐 UI Scale")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(themeColors.text)

                    Spacer()

                    Text("\(Int(settingsManager.uiScale * 100))%")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(themeColors.primary)
                        .frame(width: 45)
                }

                HStack(spacing: 12) {
                    Text("75%")
                        .font(.caption2)
                        .foregroundStyle(themeColors.secondaryText)

                    Slider(value: $settingsManager.uiScale, in: 0.75...1.5, step: 0.05)
                        .onChange(of: settingsManager.uiScale) { _ in
                            settingsManager.save()
                        }

                    Text("150%")
                        .font(.caption2)
                        .foregroundStyle(themeColors.secondaryText)
                }

                Text("Adjusts the size of UI elements. Restart app for full effect.")
                    .font(.caption2)
                    .foregroundStyle(themeColors.secondaryText)
            }
        }
    }

    private func copyColorToClipboard() {
        let hexCode = HexColorPicker.colorToHex(selectedPickerColor)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(hexCode, forType: .string)
    }

    private func themeOptionButton(_ theme: ThemeManager.Theme) -> some View {
        let isSelected = themeManager.currentTheme == theme
        let themeColors = themeManager.colors(for: theme)

        return Button(action: { themeManager.setTheme(theme) }) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(theme.rawValue)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(
                                themeManager.colors(for: themeManager.currentTheme).text)

                        Text(themeManager.themeDescription(theme))
                            .font(.caption)
                            .foregroundStyle(
                                themeManager.colors(for: themeManager.currentTheme).secondaryText)
                    }

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(self.themeColors.primary)
                    }
                }

                // Color preview
                HStack(spacing: 4) {
                    ForEach(
                        [themeColors.primary, themeColors.secondary, themeColors.accent], id: \.self
                    ) { color in
                        RoundedRectangle(cornerRadius: 3)
                            .frame(height: 8)
                            .foregroundStyle(color)
                    }
                }
            }
            .padding(12)
            .background(self.themeColors.cardBackground.opacity(isSelected ? 0.8 : 0.5))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        isSelected
                            ? self.themeColors.primary
                            : self.themeColors.secondaryText.opacity(0.2),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Themed Card

    private func themedSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content)
        -> some View
    {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(themeColors.primary)
                .padding(.horizontal, 12)

            VStack(alignment: .leading, spacing: 12) {
                content()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(themeColors.cardBackground)
                    .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
            )
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Configuration Section

    private var configurationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Wine Directory")
                    .font(.caption)
                    .foregroundStyle(themeColors.secondaryText)
                HStack(spacing: 8) {
                    TextField("Wine path", text: $settingsManager.wineDirectory)
                        .textFieldStyle(.roundedBorder)
                        .foregroundStyle(themeColors.text)
                        .onChange(of: settingsManager.wineDirectory) { _ in
                            settingsManager.save()
                        }
                    Button(action: selectWineDirectory) {
                        Image(systemName: "folder")
                            .foregroundStyle(themeColors.primary)
                    }
                    .buttonStyle(.bordered)
                }
            }

            Divider()
                .background(themeColors.secondaryText.opacity(0.2))

            VStack(alignment: .leading, spacing: 8) {
                Text("GPTK Installation Path")
                    .font(.caption)
                    .foregroundStyle(themeColors.secondaryText)
                HStack(spacing: 8) {
                    TextField("GPTK path", text: $settingsManager.gptkPath)
                        .textFieldStyle(.roundedBorder)
                        .foregroundStyle(themeColors.text)
                        .onChange(of: settingsManager.gptkPath) { _ in
                            settingsManager.save()
                        }
                    Button(action: selectGPTKDirectory) {
                        Image(systemName: "folder")
                            .foregroundStyle(themeColors.primary)
                    }
                    .buttonStyle(.bordered)
                }
            }

            Divider()
                .background(themeColors.secondaryText.opacity(0.2))

            Toggle("Use Game Porting Toolkit", isOn: $settingsManager.useGPTK)
                .onChange(of: settingsManager.useGPTK) { _ in
                    settingsManager.save()
                }
                .tint(themeColors.primary)

            Divider()
                .background(themeColors.secondaryText.opacity(0.2))

            VStack(alignment: .leading, spacing: 8) {
                Text("Default Launch Environment")
                    .font(.caption)
                    .foregroundStyle(themeColors.secondaryText)
                Picker(
                    "Default Launch Environment",
                    selection: Binding(
                        get: { settingsManager.preferredLaunchEnvironment },
                        set: { settingsManager.preferredLaunchEnvironment = $0 }
                    )
                ) {
                    Text("x86 (32-bit)").tag(ExecutionEnvironment.x86)
                    Text("x64 (Default)").tag(ExecutionEnvironment.native)
                }
                .pickerStyle(.segmented)
            }
        }
    }

    // MARK: - System Info Section

    private var systemInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            infoBadge("Wine Version", wineVersion)
            infoBadge("GPTK Version", gptkVersion)
            infoBadge("Metal GPU", metalDevice)

            if !installStatus.isEmpty {
                infoBadge("Installation Status", installStatus)
            }

            if let systemInfo = appState.systemInfo {
                HStack(spacing: 8) {
                    infoBadgeSmall("x86", systemInfo.x86Support ? "✅" : "❌")
                    infoBadgeSmall("x64", systemInfo.x64Support ? "✅" : "❌")
                }
            }
        }
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            actionButton(
                "🔍 Verify Installation",
                action: {
                    appState.detectSystem()
                    verifyInstallation()
                })

            actionButton(
                "🧪 Run Wine Smoke Test",
                action: {
                    appState.runWineSmokeTest()
                })

            actionButton("📁 Open Prefix Folder", action: openPrefixDirectory)
            actionButton("📋 Open Logs Folder", action: openLogsDirectory)
            actionButton("↺ Reset Settings", action: resetSettings, isDestructive: true)
        }
    }

    private var feedbackSettingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Feedback Button Position")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(themeColors.text)
                Spacer()
            }

            Picker(
                "Position",
                selection: Binding(
                    get: { settingsManager.feedbackButtonPosition },
                    set: { newValue in
                        settingsManager.feedbackButtonPosition = newValue
                        settingsManager.save()
                    }
                )
            ) {
                Text("Bottom Left").tag("bottomLeft")
                Text("Bottom Right").tag("bottomRight")
            }
            .pickerStyle(.segmented)

            Text("Choose where the feedback button appears in the app")
                .font(.caption)
                .foregroundStyle(themeColors.secondaryText)
        }
    }

    private func actionButton(
        _ label: String, action: @escaping () -> Void, isDestructive: Bool = false
    ) -> some View {
        Button(action: action) {
            Text(label)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            isDestructive
                                ? themeColors.destructive.opacity(0.15)
                                : themeColors.primary.opacity(0.15))
                )
                .foregroundStyle(isDestructive ? themeColors.destructive : themeColors.primary)
                .font(.subheadline)
        }
        .buttonStyle(.plain)
    }

    // MARK: - System Report

    private func systemReportSection(_ systemInfo: SystemDetector.SystemInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if !systemInfo.launcherVersions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Game Launchers")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(themeColors.secondary)

                    ForEach(systemInfo.launcherVersions.sorted(by: { $0.key < $1.key }), id: \.key)
                    { name, version in
                        HStack {
                            Text(name)
                                .font(.caption)
                            Spacer()
                            Text(version)
                                .font(.caption2)
                                .foregroundStyle(themeColors.secondaryText)
                        }
                        .foregroundStyle(themeColors.text)
                    }
                }
                .padding(10)
                .background(themeColors.primary.opacity(0.1))
                .cornerRadius(8)
            }

            if !systemInfo.detectedMods.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Detected Mods (\(systemInfo.detectedMods.count))")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(themeColors.accent)

                    ForEach(systemInfo.detectedMods.prefix(5)) { mod in
                        HStack(spacing: 8) {
                            Text(mod.name)
                                .font(.caption)
                                .lineLimit(1)
                            Text("[\(mod.arch.rawValue)]")
                                .font(.caption2)
                                .foregroundStyle(themeColors.secondaryText)
                            Spacer()
                            Text(formatBytes(mod.size))
                                .font(.caption)
                                .foregroundStyle(themeColors.secondaryText)
                        }
                        .foregroundStyle(themeColors.text)
                    }
                }
                .padding(10)
                .background(themeColors.accent.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }

    // MARK: - Helper Views

    private func statusBanner(message: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "info.circle.fill")
            Text(message)
                .font(.caption)
            Spacer()
        }
        .padding(12)
        .background(color.opacity(0.15))
        .cornerRadius(8)
        .foregroundStyle(color)
        .padding(.horizontal, 16)
    }

    private func infoBadge(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(themeColors.secondaryText)
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(themeColors.primary)
        }
    }

    private func infoBadgeSmall(_ label: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
            Text(label)
                .font(.caption2)
                .foregroundStyle(themeColors.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(6)
        .background(themeColors.primary.opacity(0.1))
        .cornerRadius(6)
    }

    // MARK: - Actions

    private func handleDeveloperClick() {
        developerDoubleClickCount += 1
        if developerDoubleClickCount >= 3 {
            showDeveloperFeedback = true
            developerDoubleClickCount = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            developerDoubleClickCount = 0
        }
    }

    private func selectWineDirectory() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        if panel.runModal() == .OK, let url = panel.url {
            settingsManager.wineDirectory = url.path
            settingsManager.save()
        }
    }

    private func selectGPTKDirectory() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        if panel.runModal() == .OK, let url = panel.url {
            settingsManager.gptkPath = url.path
            settingsManager.save()
        }
    }

    private func detectVersions() {
        detectWineVersion()
        detectGPTKVersion()
        detectMetalDevice()
        verifyInstallation()
    }

    private func detectWineVersion() {
        if let wineExe = WineDetector.shared.wineExecutablePath {
            DispatchQueue.main.async {
                self.wineVersion = "Detected at \(wineExe)"
            }
        } else {
            DispatchQueue.main.async {
                wineVersion = "Not found"
            }
        }
    }

    private func detectGPTKVersion() {
        let versionFile = settingsManager.gptkPath + "/VERSION"
        if let version = try? String(contentsOfFile: versionFile, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        {
            DispatchQueue.main.async {
                gptkVersion = version
            }
            return
        }

        DispatchQueue.main.async {
            gptkVersion = "Not found"
        }
    }

    private func detectMetalDevice() {
        if let metalInfo = MetalDeviceDetector.shared.metalInfo {
            DispatchQueue.main.async {
                metalDevice = metalInfo.deviceName
            }
        } else {
            DispatchQueue.main.async {
                metalDevice = "Unable to detect"
            }
        }
    }

    private func verifyInstallation() {
        // Dependencies are verified during launch and shown via a user confirmation prompt
        installStatus = ""
    }

    private func openPrefixDirectory() {
        let prefixPath = settingsManager.getPrefixDirectory()
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: prefixPath)
    }

    private func openLogsDirectory() {
        let logsPath = settingsManager.getLogsDirectory()
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: logsPath)
    }

    private func resetSettings() {
        settingsManager.wineDirectory = NSHomeDirectory() + "/.wine"
        settingsManager.gptkPath = "/opt/gptk"
        settingsManager.useGPTK = false
        settingsManager.enableLogging = true
        settingsManager.save()
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
        SettingsView()
            .environmentObject(AppState.shared)
    }
#endif
