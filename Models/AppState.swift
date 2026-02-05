import Combine
import Foundation
import CloudKit

/// SPINE: Single source of truth for entire application
/// Owns logs, services, system info, and runtime state.
/// Everything flows through here.
class AppState: ObservableObject {
    
    // MARK: - CloudKit Sync State
    @Published var syncState: SyncState = .disabled
    @Published var lastSyncDate: Date?
    @Published var syncError: String?
    @Published var iCloudAvailable: Bool = false
    
    // Rate limiting for syncs (30s minimum)
    private var lastSyncRequest: Date?
    private let minSyncInterval: TimeInterval = 30
    private var pendingSyncWorkItem: DispatchWorkItem?
    private var cloudKitCancellables = Set<AnyCancellable>()
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
    private let currentSessionId = UUID().uuidString  // Unique ID for this app launch

    struct LogEntry: Identifiable, Codable {
        var id = UUID()
        let timestamp: Date
        let level: LogLevel
        let message: String
        let category: Category
        let sessionId: String  // Groups logs by app launch session
        let appName: String?  // App being launched (e.g., "Geometry Dash", "Steam", etc.)

        enum CodingKeys: String, CodingKey {
            case id, timestamp, level, message, category, sessionId, appName
        }

        // Custom init for backwards compatibility with cached logs
        init(
            timestamp: Date, level: LogLevel, message: String, category: Category,
            sessionId: String, appName: String? = nil
        ) {
            self.timestamp = timestamp
            self.level = level
            self.message = message
            self.category = category
            self.sessionId = sessionId
            self.appName = appName
        }

        // Decoding with fallback sessionId and appName for old cached logs
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.id = (try? container.decode(UUID.self, forKey: .id)) ?? UUID()
            self.timestamp = try container.decode(Date.self, forKey: .timestamp)
            self.level = try container.decode(LogLevel.self, forKey: .level)
            self.message = try container.decode(String.self, forKey: .message)
            self.category = try container.decode(Category.self, forKey: .category)
            // Fallback to "legacy" if sessionId not present (old cached logs)
            self.sessionId = (try? container.decode(String.self, forKey: .sessionId)) ?? "legacy"
            // appName is optional, may not exist in old logs
            self.appName = try? container.decode(String.self, forKey: .appName)
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(timestamp, forKey: .timestamp)
            try container.encode(level, forKey: .level)
            try container.encode(message, forKey: .message)
            try container.encode(category, forKey: .category)
            try container.encode(sessionId, forKey: .sessionId)
            try container.encode(appName, forKey: .appName)
        }
    }

    enum LogLevel: String, CaseIterable, Codable {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
    }

    enum Category: String, CaseIterable, Codable {
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

    private let cacheQueue = DispatchQueue(label: "com.flux.cache", qos: .utility)
    private var logsCacheWorkItem: DispatchWorkItem?

    private enum CacheFile: String {
        case games = "games.json"
        case prefixes = "prefixes.json"
        case logs = "logs.json"
        case recents = "recents.json"
    }

    struct RecentLaunch: Identifiable, Codable {
        var id = UUID()
        let name: String
        let executablePath: String
        let steamAppId: Int
        let launchMethod: LaunchMethod
        let launchedAt: Date
    }

    private func cacheURL(for file: CacheFile) -> URL {
        let cacheDir = settingsManager.getCacheDirectory()
        return URL(fileURLWithPath: (cacheDir as NSString).appendingPathComponent(file.rawValue))
    }

    private func loadCachedState() {
        loadCachedPrefixes()
        loadCachedGames()
        loadCachedLogs()
        loadCachedRecents()
    }

    private func loadCachedGames() {
        let url = cacheURL(for: .games)
        guard let data = try? Data(contentsOf: url) else { return }
        if let decoded = try? JSONDecoder().decode([Game].self, from: data) {
            games = decoded
        }
    }

    private func loadCachedPrefixes() {
        let url = cacheURL(for: .prefixes)
        guard let data = try? Data(contentsOf: url) else { return }
        if let decoded = try? JSONDecoder().decode([GamePrefix].self, from: data) {
            prefixes = decoded
        }
    }

    private func loadCachedLogs() {
        let url = cacheURL(for: .logs)
        guard let data = try? Data(contentsOf: url) else { return }
        if let decoded = try? JSONDecoder().decode([LogEntry].self, from: data) {
            logs = decoded
        }
    }

    private func loadCachedRecents() {
        let url = cacheURL(for: .recents)
        guard let data = try? Data(contentsOf: url) else { return }
        if let decoded = try? JSONDecoder().decode([RecentLaunch].self, from: data) {
            recentLaunches = decoded
        }
    }

    private func saveGamesCache() {
        let url = cacheURL(for: .games)
        cacheQueue.async { [games] in
            if let data = try? JSONEncoder().encode(games) {
                try? data.write(to: url)
            }
        }
    }

    private func savePrefixesCache() {
        let url = cacheURL(for: .prefixes)
        cacheQueue.async { [prefixes] in
            if let data = try? JSONEncoder().encode(prefixes) {
                try? data.write(to: url)
            }
        }
    }

    private func saveRecentsCache() {
        let url = cacheURL(for: .recents)
        cacheQueue.async { [recentLaunches] in
            if let data = try? JSONEncoder().encode(recentLaunches) {
                try? data.write(to: url)
            }
        }
    }

    private func scheduleLogsCacheSave() {
        logsCacheWorkItem?.cancel()
        let workItem = DispatchWorkItem { [logs] in
            let url = self.cacheURL(for: .logs)
            let trimmed = Array(logs.suffix(500))
            if let data = try? JSONEncoder().encode(trimmed) {
                try? data.write(to: url)
            }
        }
        logsCacheWorkItem = workItem
        cacheQueue.asyncAfter(deadline: .now() + 0.75, execute: workItem)
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
    let healthMonitor = SystemHealthMonitor.shared  // System health tracking
    let cloudKitManager = CloudKitManager.shared    // CloudKit sync service

    // MARK: - Singleton for global access
    static let shared = AppState()

    init() {
        logOnce("AppState spine initialized", category: .engine)
        currentVersion = Self.lookupVersion()
        evaluatePatchNotes()
        loadCachedState()
        loadPrefixes()
        
        // Set up CloudKit observers
        setupCloudKitObservers()

        // Defer system and game detection to async after init complete
        DispatchQueue.main.async { [weak self] in
            self?.detectSystem()
            self?.detectGames()
            // Start health monitoring with 5-second interval
            self?.healthMonitor.startMonitoring(interval: 5.0)
            // Initialize CloudKit if enabled
            self?.initializeCloudKitIfNeeded()
        }
    }
    
    // MARK: - CloudKit Integration
    
    /// Set up observers for CloudKitManager state changes
    private func setupCloudKitObservers() {
        // Observe sync state
        cloudKitManager.$syncState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.syncState = state
                if case .error(let message) = state {
                    self?.syncError = message
                } else {
                    self?.syncError = nil
                }
            }
            .store(in: &cloudKitCancellables)
        
        // Observe last sync date
        cloudKitManager.$lastSyncDate
            .receive(on: DispatchQueue.main)
            .assign(to: &$lastSyncDate)
        
        // Observe iCloud availability
        cloudKitManager.$iCloudAvailable
            .receive(on: DispatchQueue.main)
            .assign(to: &$iCloudAvailable)
    }
    
    /// Initialize CloudKit on app launch if sync is enabled
    private func initializeCloudKitIfNeeded() {
        Task {
            do {
                try await cloudKitManager.initialize()
                log("CloudKit initialized", category: .services)
                
                // Perform initial sync
                await cloudKitManager.performSync(direction: .merge)
            } catch {
                if !iCloudAvailable {
                    warning("iCloud not available - sync disabled. Sign in to iCloud to enable sync.", category: .services)
                } else {
                    log("CloudKit init failed: \(error.localizedDescription)", category: .services)
                }
            }
        }
    }
    
    /// Request a sync (rate-limited to 30s minimum)
    /// Call this after any change that should sync to cloud
    func requestSync() {
        guard cloudKitManager.syncEnabled else { return }
        
        // Cancel any pending sync request
        pendingSyncWorkItem?.cancel()
        
        // Check rate limiting
        if let lastRequest = lastSyncRequest,
           Date().timeIntervalSince(lastRequest) < minSyncInterval {
            // Schedule sync for later
            let delay = minSyncInterval - Date().timeIntervalSince(lastRequest)
            let workItem = DispatchWorkItem { [weak self] in
                self?.performDebouncedSync()
            }
            pendingSyncWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
            debug("Sync scheduled in \(Int(delay))s (rate limited)", category: .services)
            return
        }
        
        performDebouncedSync()
    }
    
    private func performDebouncedSync() {
        lastSyncRequest = Date()
        
        Task {
            await cloudKitManager.performSync(direction: .upload)
            log("Sync completed", category: .services)
        }
    }
    
    /// Sync current preferences to CloudKit
    func syncPreferencesToCloud() {
        guard cloudKitManager.syncEnabled else { return }
        
        let themeManager = ThemeManager.shared
        let preferences = SyncablePreferences.from(settings: settingsManager, theme: themeManager)
        
        Task {
            do {
                try await cloudKitManager.syncPreferences(preferences)
                debug("Preferences synced to cloud", category: .services)
            } catch {
                warning("Failed to sync preferences: \(error.localizedDescription)", category: .services)
            }
        }
    }
    
    /// Sync a game override to CloudKit
    func syncGameOverrideToCloud(_ game: Game) {
        guard cloudKitManager.syncEnabled else { return }
        
        let gameKey = game.steamAppId > 0 ? "steam:\(game.steamAppId)" : "path:\(game.executablePath.hashValue)"
        
        let override = SyncableGameOverride(
            gameKey: gameKey,
            gameName: game.name,
            launchMethod: game.launchMethod.rawValue,
            gptkMode: game.gptkMode.rawValue,
            graphicsAPI: game.graphicsAPI.rawValue,
            modifiedAt: Date()
        )
        
        Task {
            do {
                try await cloudKitManager.syncGameOverride(override)
                debug("Game override synced: \(game.name)", category: .services)
            } catch {
                warning("Failed to sync game override: \(error.localizedDescription)", category: .services)
            }
        }
    }
    
    /// Sync a recent launch to CloudKit
    func syncRecentLaunchToCloud(_ game: Game, success: Bool) {
        guard cloudKitManager.syncEnabled else { return }
        
        let gameKey = game.steamAppId > 0 ? "steam:\(game.steamAppId)" : "path:\(game.executablePath.hashValue)"
        
        let launch = SyncableRecentLaunch(
            id: UUID().uuidString,
            gameKey: gameKey,
            gameName: game.name,
            launchMethod: game.launchMethod.rawValue,
            timestamp: Date(),
            success: success,
            deviceName: CloudKitManager.deviceName
        )
        
        Task {
            do {
                try await cloudKitManager.syncRecentLaunch(launch)
                debug("Recent launch synced: \(game.name)", category: .services)
                
                // Prune old launches periodically
                try await cloudKitManager.pruneRecentLaunches()
            } catch {
                warning("Failed to sync recent launch: \(error.localizedDescription)", category: .services)
            }
        }
    }
    
    /// Enable or disable CloudKit sync
    func setSyncEnabled(_ enabled: Bool) {
        // Check iCloud availability before enabling
        if enabled && !iCloudAvailable {
            errorMessage = "iCloud is not available. Please sign in to iCloud in System Settings and try again."
            error("Cannot enable sync: iCloud not available", category: .services)
            return
        }
        
        Task {
            await cloudKitManager.setSyncEnabled(enabled)
            if enabled {
                log("CloudKit sync enabled", category: .services)
                syncPreferencesToCloud()
            } else {
                log("CloudKit sync disabled", category: .services)
            }
        }
    }
    
    /// Force a full sync (user-initiated)
    func forceFullSync() {
        // Check iCloud availability
        if !iCloudAvailable {
            errorMessage = "iCloud is not available. Please sign in to iCloud in System Settings."
            error("Cannot sync: iCloud not available", category: .services)
            return
        }
        
        Task {
            log("Starting full sync...", category: .services)
            await cloudKitManager.performSync(direction: .merge)
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
        
        // Sync preferences to CloudKit
        syncPreferencesToCloud()
        requestSync()
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

    func log(_ message: String, category: Category = .engine, appName: String? = nil) {
        addLogEntry(message, level: .info, category: category, appName: appName)
    }

    func debug(_ message: String, category: Category = .engine, appName: String? = nil) {
        addLogEntry(message, level: .debug, category: category, appName: appName)
    }

    func warning(_ message: String, category: Category = .engine, appName: String? = nil) {
        addLogEntry(message, level: .warning, category: category, appName: appName)
    }

    func error(_ message: String, category: Category = .engine, appName: String? = nil) {
        addLogEntry(message, level: .error, category: category, appName: appName)
    }

    private func logOnce(_ message: String, category: Category) {
        // For init, use same pattern as addLogEntry
        addLogEntry(message, level: .info, category: category)
    }

    private func addLogEntry(
        _ message: String, level: LogLevel, category: Category, appName: String? = nil
    ) {
        let entry = LogEntry(
            timestamp: Date(),
            level: level,
            message: message,
            category: category,
            sessionId: currentSessionId,
            appName: appName
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

            self?.scheduleLogsCacheSave()
        }
    }

    func clearLogs() {
        DispatchQueue.main.async { [weak self] in
            self?.logs.removeAll()
            self?.scheduleLogsCacheSave()
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
        // Ensure at least one prefix exists
        if prefixes.isEmpty {
            let defaultPrefix = GamePrefix(
                id: UUID(),
                name: "Default",
                path: settingsManager.getPrefixDirectory(),
                createdAt: Date(),
                isDefault: true
            )
            prefixes.append(defaultPrefix)
            savePrefixesCache()
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
                    self.saveGamesCache()
                    self.developerFeedback.logSuccess(
                        "GameDetection",
                        message: "Found \(self.games.count) games")
                    self.log("Detected \(self.games.count) games", category: .games)
                }
            } else {
                DispatchQueue.main.async {
                    self.games = []
                    self.isLoading = false
                    self.saveGamesCache()
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

                // Launch if no required dependencies (optional-only is OK)
                if report.isEmpty || report.required.isEmpty {
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

    func recordRecentLaunch(_ game: Game, success: Bool = true) {
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
            self.saveRecentsCache()
            
            // Sync to CloudKit
            self.syncRecentLaunchToCloud(game, success: success)
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
            // Sync game override to CloudKit
            syncGameOverrideToCloud(games[index])
            requestSync()
        }
    }

    func updateGPTKMode(for gameId: UUID, mode: GPTKMode) {
        if let index = games.firstIndex(where: { $0.id == gameId }) {
            games[index].gptkMode = mode
            settingsManager.setGPTKMode(mode, for: games[index])
            // Sync game override to CloudKit
            syncGameOverrideToCloud(games[index])
            requestSync()
        }
    }

    func updateGraphicsAPI(for gameId: UUID, api: GraphicsAPI) {
        if let index = games.firstIndex(where: { $0.id == gameId }) {
            games[index].graphicsAPI = api
            settingsManager.setGraphicsAPI(api, for: games[index])
            // Sync game override to CloudKit
            syncGameOverrideToCloud(games[index])
            requestSync()
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
        savePrefixesCache()
        developerFeedback.logSuccess("PrefixManager", message: "Created prefix: \(name)")
        log("Prefix created: \(name)", category: .prefixes)
    }

    func deletePrefix(_ prefix: GamePrefix) {
        prefixes.removeAll { $0.id == prefix.id }
        savePrefixesCache()

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
