import Foundation
import Combine

/// SyncCoordinator - Bridges AppState/Services with CloudKitManager
/// Handles when to sync, debouncing, and local-remote state reconciliation
class SyncCoordinator: ObservableObject {
    
    // MARK: - Singleton
    static let shared = SyncCoordinator()
    
    // MARK: - Dependencies
    private let cloudKit = CloudKitManager.shared
    private let settings = SettingsManager.shared
    private let theme = ThemeManager.shared
    
    // MARK: - Published State
    @Published var isSyncing: Bool = false
    @Published var lastSyncDescription: String = "Never synced"
    
    // MARK: - Private State
    private var cancellables = Set<AnyCancellable>()
    private var debounceWorkItem: DispatchWorkItem?
    private let debounceInterval: TimeInterval = 2.0  // Wait 2 seconds after last change
    
    // MARK: - Initialization
    
    private init() {
        setupObservers()
    }
    
    // MARK: - Public API
    
    /// Initialize sync on app launch
    func initializeOnLaunch() async {
        guard cloudKit.syncEnabled else { return }
        
        do {
            try await cloudKit.initialize()
            
            // Perform initial sync
            await cloudKit.performSync(direction: .merge)
            
            updateLastSyncDescription()
            
        } catch {
            log("Sync initialization failed: \(error.localizedDescription)")
        }
    }
    
    /// Force a full sync now
    func syncNow() async {
        await cloudKit.performSync(direction: .merge)
        updateLastSyncDescription()
    }
    
    /// Enable or disable sync
    func setEnabled(_ enabled: Bool) async {
        await cloudKit.setSyncEnabled(enabled)
        
        if enabled {
            updateLastSyncDescription()
        }
    }
    
    /// Sync a recent launch (call when game is launched)
    func recordLaunch(gameName: String, gameKey: String, method: String, success: Bool) async {
        guard cloudKit.syncEnabled, cloudKit.iCloudAvailable else { return }
        
        let launch = SyncableRecentLaunch(
            id: UUID().uuidString,
            gameKey: gameKey,
            gameName: gameName,
            launchMethod: method,
            timestamp: Date(),
            success: success,
            deviceName: CloudKitManager.deviceName
        )
        
        do {
            try await cloudKit.syncRecentLaunch(launch)
            
            // Prune old launches periodically
            try await cloudKit.pruneRecentLaunches()
            
        } catch {
            log("Failed to sync launch: \(error.localizedDescription)")
        }
    }
    
    /// Get combined recent launches (local + remote)
    func getCombinedRecentLaunches() async -> [SyncableRecentLaunch] {
        guard cloudKit.syncEnabled, cloudKit.iCloudAvailable else { return [] }
        
        do {
            return try await cloudKit.fetchRecentLaunches()
        } catch {
            log("Failed to fetch recent launches: \(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: - Auto-Sync on Changes
    
    private func setupObservers() {
        // Observe settings changes
        settings.$uiScale
            .dropFirst()
            .sink { [weak self] _ in self?.scheduleSync() }
            .store(in: &cancellables)
        
        settings.$feedbackButtonPosition
            .dropFirst()
            .sink { [weak self] _ in self?.scheduleSync() }
            .store(in: &cancellables)
        
        settings.$defaultLaunchEnvironment
            .dropFirst()
            .sink { [weak self] _ in self?.scheduleSync() }
            .store(in: &cancellables)
        
        settings.$selectedLauncher
            .dropFirst()
            .sink { [weak self] _ in self?.scheduleSync() }
            .store(in: &cancellables)
        
        settings.$enableLogging
            .dropFirst()
            .sink { [weak self] _ in self?.scheduleSync() }
            .store(in: &cancellables)
        
        settings.$useGPTK
            .dropFirst()
            .sink { [weak self] _ in self?.scheduleSync() }
            .store(in: &cancellables)
        
        // Observe theme changes
        theme.$currentTheme
            .dropFirst()
            .sink { [weak self] _ in self?.scheduleSync() }
            .store(in: &cancellables)
        
        // Observe CloudKit state
        cloudKit.$syncState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.isSyncing = (state == .syncing)
            }
            .store(in: &cancellables)
        
        cloudKit.$lastSyncDate
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateLastSyncDescription()
            }
            .store(in: &cancellables)
    }
    
    /// Debounced sync - waits for changes to settle before syncing
    private func scheduleSync() {
        debounceWorkItem?.cancel()
        
        let workItem = DispatchWorkItem { [weak self] in
            Task {
                await self?.cloudKit.performSync(direction: .upload)
            }
        }
        
        debounceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + debounceInterval, execute: workItem)
    }
    
    private func updateLastSyncDescription() {
        if let date = cloudKit.lastSyncDate {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            lastSyncDescription = "Last synced \(formatter.localizedString(for: date, relativeTo: Date()))"
        } else {
            lastSyncDescription = "Never synced"
        }
    }
    
    private func log(_ message: String) {
        AppState.shared.log("[SyncCoordinator] \(message)", category: .engine)
    }
}

// MARK: - AppState Integration Points

extension AppState {
    
    /// Call on app launch to initialize sync
    func initializeCloudSync() {
        Task {
            await SyncCoordinator.shared.initializeOnLaunch()
        }
    }
    
    /// Call when a game is launched to record in sync history
    func recordGameLaunch(game: Game, method: LaunchMethod, success: Bool) {
        let gameKey: String
        if game.steamAppId != 0 {
            gameKey = "steam:\(game.steamAppId)"
        } else {
            gameKey = "path:\(game.executablePath.hashValue)"
        }
        
        Task {
            await SyncCoordinator.shared.recordLaunch(
                gameName: game.name,
                gameKey: gameKey,
                method: method.rawValue,
                success: success
            )
        }
    }
}

// MARK: - Sync Settings View Model

class SyncSettingsViewModel: ObservableObject {
    @Published var syncEnabled: Bool = false
    @Published var iCloudAvailable: Bool = false
    @Published var syncState: SyncState = .idle
    @Published var lastSyncDescription: String = "Never synced"
    
    private let cloudKit = CloudKitManager.shared
    private let coordinator = SyncCoordinator.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Bind to CloudKitManager state
        cloudKit.$syncEnabled
            .receive(on: DispatchQueue.main)
            .assign(to: &$syncEnabled)
        
        cloudKit.$iCloudAvailable
            .receive(on: DispatchQueue.main)
            .assign(to: &$iCloudAvailable)
        
        cloudKit.$syncState
            .receive(on: DispatchQueue.main)
            .assign(to: &$syncState)
        
        coordinator.$lastSyncDescription
            .receive(on: DispatchQueue.main)
            .assign(to: &$lastSyncDescription)
    }
    
    func toggleSync() async {
        await coordinator.setEnabled(!syncEnabled)
    }
    
    func syncNow() async {
        await coordinator.syncNow()
    }
}
