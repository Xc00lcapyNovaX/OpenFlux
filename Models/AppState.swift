import Combine
import Foundation

/// SPINE: Single source of truth for entire application
/// Owns logs, services, system info, and runtime state.
/// Everything flows through here.
class AppState: ObservableObject {
    // MARK: - Error Codes

    /// OpenFlux Error Codes for debugging and support
    enum ErrorCode: String {
        // Launch Errors (OF-L0XX)
        case launchWineNotFound = "OF-L001"
        case launchExecutableNotFound = "OF-L002"
        case launchProcessFailed = "OF-L003"
        case launchDRMDetected = "OF-L004"
        case launchPrefixMissing = "OF-L005"
        case launchUnsupportedArch = "OF-L006"

        // File Errors (OF-F0XX)
        case fileNotFound = "OF-F001"
        case fileAccessDenied = "OF-F002"
        case fileUnsupportedType = "OF-F003"
        case fileNoExecutable = "OF-F004"

        // Steam Errors (OF-S0XX)
        case steamNotInstalled = "OF-S001"
        case steamLibraryNotFound = "OF-S002"
        case steamGameNotFound = "OF-S003"

        // Dependency Errors (OF-D0XX)
        case dependencyMissing = "OF-D001"
        case dependencyInstallFailed = "OF-D002"
        case winetricksNotFound = "OF-D003"

        // Network Errors (OF-N0XX)
        case networkFeedbackFailed = "OF-N001"
        case networkTimeout = "OF-N002"

        // System Errors (OF-X0XX)
        case systemMetalNotSupported = "OF-X001"
        case systemGPTKNotFound = "OF-X002"
        case systemPrefixCreationFailed = "OF-X003"

        var description: String {
            switch self {
            case .launchWineNotFound: return "Wine is not installed"
            case .launchExecutableNotFound: return "Game executable not found"
            case .launchProcessFailed: return "Failed to start game process"
            case .launchDRMDetected: return "DRM detected - game may not run"
            case .launchPrefixMissing: return "Wine prefix not found"
            case .launchUnsupportedArch: return "Unsupported architecture"
            case .fileNotFound: return "File not found"
            case .fileAccessDenied: return "Cannot access file"
            case .fileUnsupportedType: return "Unsupported file type"
            case .fileNoExecutable: return "No executable found"
            case .steamNotInstalled: return "Steam not installed"
            case .steamLibraryNotFound: return "Steam library not found"
            case .steamGameNotFound: return "Steam game not found"
            case .dependencyMissing: return "Missing dependency"
            case .dependencyInstallFailed: return "Dependency installation failed"
            case .winetricksNotFound: return "winetricks not installed"
            case .networkFeedbackFailed: return "Failed to send feedback"
            case .networkTimeout: return "Network request timed out"
            case .systemMetalNotSupported: return "Metal not supported"
            case .systemGPTKNotFound: return "Game Porting Toolkit not found"
            case .systemPrefixCreationFailed: return "Failed to create Wine prefix"
            }
        }
    }

    /// Set error with code
    func setError(_ code: ErrorCode, details: String? = nil) {
        let message =
            details != nil
            ? "[\(code.rawValue)] \(code.description): \(details!)"
            : "[\(code.rawValue)] \(code.description)"
        errorMessage = message
        error(message, category: .engine)
    }

    // MARK: - Logging (formerly LogManager)
    @Published var logs: [LogEntry] = []

    struct LogEntry: Identifiable {
        let id = UUID()
        let timestamp: Date
        let level: LogLevel
        let message: String
        let category: Category
    }

    enum LogLevel: String, CaseIterable {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
    }

    enum Category: String, CaseIterable {
        case engine = "Engine"
        case games = "Games"
        case prefixes = "Prefixes"
        case dependencies = "Dependencies"
        case services = "Services"
        case drm = "DRM"
        case gpu = "GPU"
        case environment = "Environment"
        case gameOutput = "Game Output"
        case gameError = "Game Error"
        case installation = "Installation"
        case ui = "UI"
    }

    private let maxLogEntries = 1000
    private let maxRecentLaunches = 10

    struct RecentLaunch: Identifiable {
        let id = UUID()
        let name: String
        let executablePath: String
        let steamAppId: Int
        let launchMethod: LaunchMethod
        let launchedAt: Date
    }

    // MARK: - App Data
    @Published var games: [Game] = []
    @Published var prefixes: [GamePrefix] = []
    @Published var selectedGame: Game?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var runningGames: [UUID: ProcessMonitor.ProcessInfo] = [:]
    @Published var recentLaunches: [RecentLaunch] = []
    @Published var lastFailedLaunch: Game?
    @Published var isLaunchLoading = false
    @Published var launchLoadingTitle = "Preparing Launch"
    @Published var launchLoadingMessage = "Analyzing dependencies..."

    struct DependencyPrompt: Identifiable {
        let id = UUID()
        let report: DependencyReport
    }

    @Published var activeDependencyPrompt: DependencyPrompt?

    // MARK: - System Info
    @Published var systemInfo: SystemDetector.SystemInfo?
    @Published var updateAvailable = false
    @Published var updateMessage: String?

    // MARK: - Patch Notes
    struct PatchNotesEntry {
        let version: String
        let date: String
        let highlights: [String]
    }

    @Published var currentVersion: String = ""
    @Published var shouldShowPatchNotes = false
    @Published var activePatchNotes: PatchNotesEntry?

    private let latestPatchNotes = PatchNotesEntry(
        version: "1.0.1",
        date: "Jan 30, 2026",
        highlights: [
            "🎮 First stable release of OpenFlux!",
            "▶️ Run button on Dashboard - launch any .exe directly",
            "📧 Developer feedback system with Formspree integration",
            "🎨 UI Scale slider (75%-150%) for accessibility",
            "🔧 Fixed wow64 Wine compatibility for modern Homebrew Wine",
            "📋 Comprehensive error codes for troubleshooting",
        ]
    )

    // MARK: - Services (owned by spine)
    private let steamDetector = SteamLibraryDetector()
    private lazy var launcher = GameLauncher(appState: self)  // ← LAZY + passes self
    private lazy var dependencyManager = DependencyManager(appState: self)  // ← LAZY + passes self
    private lazy var systemDetector = SystemDetector()  // ← LAZY to prevent recursive init
    private lazy var developerFeedback = DeveloperFeedback.shared  // ← LAZY to prevent recursive init
    let settingsManager = SettingsManager.shared
    let processMonitor = ProcessMonitor()

    // MARK: - Singleton for global access
    static let shared = AppState()

    init() {
        logOnce("AppState spine initialized", category: .engine)
        currentVersion = Self.lookupVersion()
        evaluatePatchNotes()
        loadPrefixes()

        // Defer system and game detection to async after init complete
        DispatchQueue.main.async { [weak self] in
            self?.detectSystem()
            self?.detectGames()
        }
    }

    // MARK: - Onboarding

    /// Complete onboarding with selected launcher
    /// Explicitly notifies observers and persists to disk
    func completeOnboarding(with launcher: String) {
        // Save launcher selection
        settingsManager.selectedLauncher = launcher

        // Mark onboarding as complete
        settingsManager.hasCompletedOnboarding = true

        // Persist to disk
        settingsManager.save()

        // Explicit notification to ensure views re-render
        objectWillChange.send()
    }

    // MARK: - Authentication

    /// Complete login with user email
    /// Placeholder for now - real auth will be added later
    func completeLogin(with email: String) {
        // Save user email
        settingsManager.userEmail = email

        // Mark as logged in
        settingsManager.hasLoggedIn = true

        // Persist to disk
        settingsManager.save()

        // Explicit notification to ensure views re-render
        objectWillChange.send()

        log("User logged in: \(email)", category: .engine)
    }

    /// Logout current user
    func logout() {
        settingsManager.userEmail = ""
        settingsManager.hasLoggedIn = false
        settingsManager.save()

        objectWillChange.send()

        log("User logged out", category: .engine)
    }

    // MARK: - Patch Notes

    private static func lookupVersion() -> String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            return version
        }
        return "0.1.0"
    }

    /// Evaluate whether to show patch notes for the current app version.
    private func evaluatePatchNotes() {
        if settingsManager.lastSeenVersion != currentVersion {
            if latestPatchNotes.version == currentVersion {
                activePatchNotes = latestPatchNotes
            } else {
                // Fallback: reuse latest highlights but label with current version
                activePatchNotes = PatchNotesEntry(
                    version: currentVersion,
                    date: latestPatchNotes.date,
                    highlights: latestPatchNotes.highlights
                )
            }
            shouldShowPatchNotes = true
            log("Showing patch notes for version \(currentVersion)", category: .ui)
        }
    }

    /// Dismiss patch notes and persist that the user has seen them.
    func dismissPatchNotes() {
        settingsManager.lastSeenVersion = currentVersion
        settingsManager.save()
        shouldShowPatchNotes = false
    }

    // MARK: - Logging Methods (merged from LogManager)

    func log(_ message: String, category: Category = .engine) {
        addLogEntry(message, level: .info, category: category)
    }

    func debug(_ message: String, category: Category = .engine) {
        addLogEntry(message, level: .debug, category: category)
    }

    func warning(_ message: String, category: Category = .engine) {
        addLogEntry(message, level: .warning, category: category)
    }

    func error(_ message: String, category: Category = .engine) {
        addLogEntry(message, level: .error, category: category)
    }

    private func logOnce(_ message: String, category: Category) {
        // For init, use same pattern as addLogEntry
        addLogEntry(message, level: .info, category: category)
    }

    private func addLogEntry(_ message: String, level: LogLevel, category: Category) {
        let entry = LogEntry(
            timestamp: Date(),
            level: level,
            message: message,
            category: category
        )

        // Console logging synchronously
        let timestamp = ISO8601DateFormatter().string(from: entry.timestamp)
        print("[\(timestamp)] [\(level.rawValue)] [\(category.rawValue)] \(message)")

        // UI updates on main thread
        DispatchQueue.main.async { [weak self] in
            self?.logs.append(entry)

            // Trim old logs if over limit
            if self?.logs.count ?? 0 > 1000 {
                let excess = (self?.logs.count ?? 0) - 500
                self?.logs.removeFirst(excess)
            }
        }
    }

    func clearLogs() {
        DispatchQueue.main.async { [weak self] in
            self?.logs.removeAll()
        }
    }

    func exportLogs() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"

        return logs.map { entry in
            "[\(dateFormatter.string(from: entry.timestamp))] [\(entry.level.rawValue)] [\(entry.category)] \(entry.message)"
        }.joined(separator: "\n")
    }

    func getLogs(for level: LogLevel) -> [LogEntry] {
        return logs.filter { $0.level == level }
    }

    // MARK: - System Detection

    func detectSystem() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let info = self.systemDetector.detectSystem()

            DispatchQueue.main.async {
                self.systemInfo = info

                // Alert if updates are available
                if info.updateAvailable {
                    self.updateAvailable = true
                    self.updateMessage = info.updateDetails ?? "Updates available"
                    self.warning(self.updateMessage ?? "", category: .engine)
                }

                self.developerFeedback.logProcess(
                    "SystemDetector",
                    action: "System scan complete",
                    details: "Steam: \(info.steamInstalled), Mods: \(info.detectedMods.count)"
                )
            }
        }
    }

    // MARK: - Game Detection & Management

    func loadPrefixes() {
        // Load persisted prefixes from defaults
        if prefixes.isEmpty {
            let defaultPrefix = GamePrefix(
                id: UUID(),
                name: "Default",
                path: settingsManager.getPrefixDirectory(),
                createdAt: Date(),
                isDefault: true
            )
            prefixes.append(defaultPrefix)
        }
    }

    func detectGames() {
        isLoading = true
        errorMessage = nil
        developerFeedback.logProcess("GameDetection", action: "Starting scan")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            if let games = self.steamDetector.detectInstalledGames() {
                DispatchQueue.main.async {
                    // Enrich games with dependency and DRM info
                    let enrichedGames = games.map { game -> Game in
                        var updatedGame = game
                        updatedGame.missingDependencies = self.dependencyManager.checkDependencies(
                            for: game)
                        updatedGame.hasDRMWarning = self.dependencyManager.detectDRM(in: game)
                        if let override = self.settingsManager.launchMethod(for: updatedGame) {
                            updatedGame.launchMethod = override
                        }
                        if let override = self.settingsManager.gptkMode(for: updatedGame) {
                            updatedGame.gptkMode = override
                        }
                        if let override = self.settingsManager.graphicsAPI(for: updatedGame) {
                            updatedGame.graphicsAPI = override
                        }
                        return updatedGame
                    }

                    self.games = enrichedGames.sorted { $0.name < $1.name }
                    self.isLoading = false
                    self.developerFeedback.logSuccess(
                        "GameDetection",
                        message: "Found \(self.games.count) games")
                    self.log("Detected \(self.games.count) games", category: .games)
                }
            } else {
                DispatchQueue.main.async {
                    self.games = []
                    self.isLoading = false
                    self.setError(
                        .steamNotInstalled, details: "Make sure Steam is installed and has games")
                }
            }
        }
    }

    func launchGame(_ game: Game) {
        errorMessage = nil
        developerFeedback.logProcess(
            "GameLauncher", action: "Attempting launch", details: game.name)

        // Warn about DRM
        if game.hasDRMWarning {
            setError(.launchDRMDetected, details: game.name)
            developerFeedback.logProcess("GameLauncher", action: "DRM warning", details: game.name)
        }

        if game.launchMethod == .steam {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.launcher.launch(game)
            }
            return
        }

        let shouldProbeDependencies = dependencyManager.shouldProbeDependencies(for: game)
        let shouldShowLoading =
            shouldProbeDependencies && dependencyManager.isLauncherExecutable(game)

        if !shouldProbeDependencies {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.launcher.launch(game)
            }
            return
        }

        if shouldShowLoading {
            DispatchQueue.main.async { [weak self] in
                self?.launchLoadingTitle = "Preparing Launcher"
                self?.launchLoadingMessage = "Checking required components..."
                self?.isLaunchLoading = true
            }
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let report = self.dependencyManager.dependencyReport(for: game)

            DispatchQueue.main.async {
                if shouldShowLoading {
                    self.isLaunchLoading = false
                }

                if report.isEmpty {
                    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                        self?.launcher.launch(game)
                    }
                } else {
                    self.activeDependencyPrompt = DependencyPrompt(report: report)
                }
            }
        }
    }

    func installDependenciesAndLaunch(
        report: DependencyReport,
        includeOptional: Bool
    ) {
        activeDependencyPrompt = nil
        launchLoadingTitle = "Installing Components"
        launchLoadingMessage = "Applying required dependencies..."
        isLaunchLoading = true

        dependencyManager.installDependencies(
            for: report,
            includeOptional: includeOptional
        ) { [weak self] success in
            guard let self = self else { return }
            self.isLaunchLoading = false
            if success {
                DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                    self?.launcher.launch(report.game)
                }
            } else {
                self.setError(.dependencyInstallFailed, details: "Check logs for details")
                self.lastFailedLaunch = report.game
            }
        }
    }

    func cancelDependencyPrompt(for report: DependencyReport) {
        activeDependencyPrompt = nil
        markLaunchFailed(report.game, message: "Launch cancelled — dependencies not installed.")
    }

    func runWineSmokeTest() {
        errorMessage = nil
        log("Running Wine smoke test…", category: .ui)

        let env = settingsManager.preferredLaunchEnvironment
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let runner = WineSmokeTestRunner(appState: self)
            let result = runner.run(environment: env)

            DispatchQueue.main.async {
                if result.passed {
                    self.log(result.summary, category: .games)
                } else {
                    self.errorMessage = result.summary
                    self.error(result.summary, category: .games)
                }
            }
        }
    }

    func recordRecentLaunch(_ game: Game) {
        let entry = RecentLaunch(
            name: game.name,
            executablePath: game.executablePath,
            steamAppId: game.steamAppId,
            launchMethod: game.launchMethod,
            launchedAt: Date()
        )

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.recentLaunches.insert(entry, at: 0)
            if self.recentLaunches.count > self.maxRecentLaunches {
                self.recentLaunches = Array(self.recentLaunches.prefix(self.maxRecentLaunches))
            }
        }
    }

    func markLaunchFailed(_ game: Game, message: String) {
        DispatchQueue.main.async { [weak self] in
            self?.errorMessage = message
            self?.lastFailedLaunch = game
        }
    }

    func clearLaunchFailure() {
        lastFailedLaunch = nil
        errorMessage = nil
    }

    func updateLaunchMethod(for gameId: UUID, method: LaunchMethod) {
        if let index = games.firstIndex(where: { $0.id == gameId }) {
            games[index].launchMethod = method
            settingsManager.setLaunchMethod(method, for: games[index])
        }
    }

    func updateGPTKMode(for gameId: UUID, mode: GPTKMode) {
        if let index = games.firstIndex(where: { $0.id == gameId }) {
            games[index].gptkMode = mode
            settingsManager.setGPTKMode(mode, for: games[index])
        }
    }

    func updateGraphicsAPI(for gameId: UUID, api: GraphicsAPI) {
        if let index = games.firstIndex(where: { $0.id == gameId }) {
            games[index].graphicsAPI = api
            settingsManager.setGraphicsAPI(api, for: games[index])
        }
    }

    // MARK: - Test Launch (Minimal Viable Product)
    /// Launch a test Windows game to prove the Wine pipeline works (GPTK optional)
    func launchTestGame() {
        errorMessage = nil
        log("🧪 TEST LAUNCH INITIATED", category: .ui)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.launcher.launchTestGame()
        }
    }

    func createPrefix(name: String) {
        let sanitizedName = name.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: " ", with: "_")

        let path = settingsManager.getPrefixesDirectory() + "/\(sanitizedName)"

        let prefix = GamePrefix(
            id: UUID(),
            name: name,
            path: path,
            createdAt: Date()
        )

        prefixes.append(prefix)
        developerFeedback.logSuccess("PrefixManager", message: "Created prefix: \(name)")
        log("Prefix created: \(name)", category: .prefixes)
    }

    func deletePrefix(_ prefix: GamePrefix) {
        prefixes.removeAll { $0.id == prefix.id }

        // Clean up filesystem
        let fileManager = FileManager.default
        try? fileManager.removeItem(atPath: prefix.path)

        developerFeedback.logSuccess("PrefixManager", message: "Deleted prefix: \(prefix.name)")
        log("Prefix deleted: \(prefix.name)", category: .prefixes)
    }

    // MARK: - Developer Mode

    func authenticateDeveloper(password: String) -> Bool {
        return developerFeedback.authenticate(with: password)
    }

    func getDeveloperSession() -> DeveloperFeedback.FeedbackSession? {
        return developerFeedback.getCurrentSession()
    }

    func exportDeveloperSession() -> String? {
        return developerFeedback.exportSession()
    }

    func exportDeveloperSessionToFile() -> URL? {
        return developerFeedback.exportSessionToFile()
    }

    // MARK: - Open With (Finder)

    func handleOpenURL(_ url: URL) {
        guard url.isFileURL else { return }

        var resolvedURL = url

        // If user opens a folder, try to locate an .exe inside (prefer installers)
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
            isDirectory.boolValue
        {
            if let exeURL = findExecutable(in: url) {
                resolvedURL = exeURL
            } else {
                setError(.fileNoExecutable, details: url.lastPathComponent)
                return
            }
        }

        let path = resolvedURL.path
        let ext = path.lowercased()
        guard ext.hasSuffix(".exe") || ext.hasSuffix(".msi") || ext.hasSuffix(".dll") else {
            setError(.fileUnsupportedType, details: "Expected .exe, .msi, or .dll")
            return
        }

        let filename = resolvedURL.deletingPathExtension().lastPathComponent
        var gameName = filename
        var steamAppId = 0

        let lowerPath = path.lowercased()
        if lowerPath.contains("geometrydash.exe") || lowerPath.contains("322170") {
            gameName = "Geometry Dash"
            steamAppId = 322170
        }

        let arch = PEInspector.shared.detectArch(path: path)
        if arch == .arm64 {
            setError(
                .launchUnsupportedArch, details: "Windows ARM64 not supported. Use x86 or x64.")
            return
        }

        var env = settingsManager.preferredLaunchEnvironment
        if env == .x86, arch == .x64 {
            // Avoid forcing a win32 prefix for a 64-bit Windows executable.
            log(
                "Detected 64-bit EXE; overriding default x86 environment to x64 prefix",
                category: .games)
            env = .native
        }

        let game = Game(
            name: gameName,
            executablePath: path,
            installPath: resolvedURL.deletingLastPathComponent().path,
            steamAppId: steamAppId,
            environment: env,
            launchMethod: .direct
        )

        log("Open with OpenFlux: \(path)", category: .games)
        launchGame(game)
    }

    private func findExecutable(in folderURL: URL) -> URL? {
        guard
            let contents = try? FileManager.default.contentsOfDirectory(
                at: folderURL,
                includingPropertiesForKeys: nil
            )
        else {
            return nil
        }

        let exeFiles = contents.filter { $0.pathExtension.lowercased() == "exe" }
        if exeFiles.isEmpty {
            return nil
        }

        if let installer = exeFiles.first(where: {
            $0.lastPathComponent.lowercased().contains("installer")
        }) {
            return installer
        }

        return exeFiles.first
    }

}
