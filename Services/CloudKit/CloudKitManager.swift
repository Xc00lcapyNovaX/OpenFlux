import Foundation
import CloudKit
import Combine

/// CloudKitManager - Singleton service for all CloudKit operations
/// Handles sync, conflict resolution, offline support, and error handling
class CloudKitManager: ObservableObject {
    
    // MARK: - Singleton
    static let shared = CloudKitManager()
    
    // MARK: - CloudKit Configuration
    static let containerIdentifier = "iCloud.com.openflux.app"
    static let syncZoneName = "OpenFluxSync"
    static let syncZoneID = CKRecordZone.ID(zoneName: syncZoneName, ownerName: CKCurrentUserDefaultName)
    
    // MARK: - Device Identification
    // Note: These are static constants for device info display.
    // Access via CloudKitManager.deviceName/deviceIdentifier directly.
    // Instance state (syncEnabled, syncState, etc.) should be accessed via appState.cloudKitManager.
    
    static var deviceIdentifier: String {
        #if os(macOS)
        return Host.current().localizedName ?? UUID().uuidString
        #else
        return UUID().uuidString
        #endif
    }
    
    static var deviceName: String {
        #if os(macOS)
        return Host.current().localizedName ?? "Mac"
        #else
        return "Mac"
        #endif
    }
    
    // MARK: - Published State
    @Published private(set) var syncState: SyncState = .idle
    @Published private(set) var iCloudAvailable: Bool = false
    @Published private(set) var lastSyncDate: Date?
    @Published private(set) var syncEnabled: Bool = false
    @Published private(set) var accountStatus: CKAccountStatus = .couldNotDetermine
    
    // MARK: - Private Properties
    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private var syncZone: CKRecordZone?
    private var changeToken: CKServerChangeToken?
    private var subscriptionID: String?
    
    private let syncQueue = DispatchQueue(label: "com.flux.cloudkit.sync", qos: .utility)
    private var cancellables = Set<AnyCancellable>()
    private var pendingChanges: [CKRecord] = []
    private var isInitialized = false
    
    // Sync timing
    private var lastSyncAttempt: Date?
    private let minSyncInterval: TimeInterval = 30  // Don't sync more than every 30 seconds
    private var syncTimer: Timer?
    
    // Offline queue
    private var offlineQueue: [CKRecord] = []
    private let offlineQueueKey = "com.flux.cloudkit.offlineQueue"
    
    // MARK: - Initialization
    
    private init() {
        container = CKContainer(identifier: Self.containerIdentifier)
        privateDatabase = container.privateCloudDatabase
        
        // Load sync preference
        syncEnabled = UserDefaults.standard.bool(forKey: "com.flux.syncEnabled")
        
        // Load change token
        if let tokenData = UserDefaults.standard.data(forKey: "com.flux.cloudkit.changeToken") {
            changeToken = try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: tokenData)
        }
        
        // Check iCloud status
        checkAccountStatus()
        
        // Listen for account changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(accountChanged),
            name: .CKAccountChanged,
            object: nil
        )
    }
    
    deinit {
        syncTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Public API
    
    /// Initialize CloudKit (call on app launch if sync is enabled)
    func initialize() async throws {
        guard syncEnabled else {
            syncState = .disabled
            return
        }
        
        guard iCloudAvailable else {
            syncState = .noAccount
            throw CloudKitError.noAccount
        }
        
        // Create custom zone if needed
        try await createZoneIfNeeded()
        
        // Subscribe to changes
        try await subscribeToChanges()
        
        isInitialized = true
        log("CloudKit initialized successfully")
    }
    
    /// Enable or disable sync
    func setSyncEnabled(_ enabled: Bool) async {
        syncEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "com.flux.syncEnabled")
        
        if enabled {
            do {
                try await initialize()
                await performSync(direction: .merge)
            } catch {
                log("Failed to enable sync: \(error.localizedDescription)")
                syncState = .error(error.localizedDescription)
            }
        } else {
            syncState = .disabled
            syncTimer?.invalidate()
            syncTimer = nil
        }
    }
    
    /// Perform a full sync
    func performSync(direction: SyncDirection = .merge) async {
        guard syncEnabled, iCloudAvailable else { return }
        
        // Rate limiting
        if let lastSync = lastSyncAttempt,
           Date().timeIntervalSince(lastSync) < minSyncInterval {
            log("Sync rate limited, skipping")
            return
        }
        
        lastSyncAttempt = Date()
        
        await MainActor.run {
            syncState = .syncing
        }
        
        do {
            switch direction {
            case .upload:
                try await uploadLocalChanges()
            case .download:
                try await fetchRemoteChanges()
            case .merge:
                try await fetchRemoteChanges()
                try await uploadLocalChanges()
                try await processOfflineQueue()
            }
            
            await MainActor.run {
                lastSyncDate = Date()
                syncState = .idle
            }
            
            // Save last sync date
            UserDefaults.standard.set(Date(), forKey: "com.flux.lastSyncDate")
            
            log("Sync completed successfully")
            
        } catch {
            await MainActor.run {
                syncState = .error(error.localizedDescription)
            }
            log("Sync failed: \(error.localizedDescription)")
        }
    }
    
    /// Sync preferences
    func syncPreferences(_ preferences: SyncablePreferences) async throws {
        guard syncEnabled, iCloudAvailable else { return }
        
        let record = preferences.toCKRecord()
        try await saveRecord(record)
    }
    
    /// Sync a game override
    func syncGameOverride(_ override: SyncableGameOverride) async throws {
        guard syncEnabled, iCloudAvailable else { return }
        
        let record = override.toCKRecord()
        try await saveRecord(record)
    }
    
    /// Sync a recent launch
    func syncRecentLaunch(_ launch: SyncableRecentLaunch) async throws {
        guard syncEnabled, iCloudAvailable else { return }
        
        let record = launch.toCKRecord()
        try await saveRecord(record)
    }
    
    /// Fetch all preferences from cloud
    func fetchPreferences() async throws -> SyncablePreferences? {
        guard syncEnabled, iCloudAvailable else { return nil }
        
        let recordID = CKRecord.ID(recordName: "preferences", zoneID: Self.syncZoneID)
        
        do {
            let record = try await privateDatabase.record(for: recordID)
            return SyncablePreferences.from(record: record)
        } catch let error as CKError where error.code == .unknownItem {
            return nil  // No preferences saved yet
        }
    }
    
    /// Fetch all game overrides from cloud
    func fetchGameOverrides() async throws -> [SyncableGameOverride] {
        guard syncEnabled, iCloudAvailable else { return [] }
        
        let query = CKQuery(
            recordType: CloudKitRecordType.gameOverride.rawValue,
            predicate: NSPredicate(value: true)
        )
        
        let (results, _) = try await privateDatabase.records(
            matching: query,
            inZoneWith: Self.syncZoneID
        )
        
        return results.compactMap { _, result in
            guard case .success(let record) = result else { return nil }
            return SyncableGameOverride.from(record: record)
        }
    }
    
    /// Fetch recent launches from cloud
    func fetchRecentLaunches(limit: Int = 50) async throws -> [SyncableRecentLaunch] {
        guard syncEnabled, iCloudAvailable else { return [] }
        
        let query = CKQuery(
            recordType: CloudKitRecordType.recentLaunch.rawValue,
            predicate: NSPredicate(value: true)
        )
        query.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        
        let (results, _) = try await privateDatabase.records(
            matching: query,
            inZoneWith: Self.syncZoneID,
            resultsLimit: limit
        )
        
        return results.compactMap { _, result in
            guard case .success(let record) = result else { return nil }
            return SyncableRecentLaunch.from(record: record)
        }
    }
    
    /// Delete old recent launches (keep only most recent 50)
    func pruneRecentLaunches() async throws {
        guard syncEnabled, iCloudAvailable else { return }
        
        let allLaunches = try await fetchRecentLaunches(limit: 100)
        
        if allLaunches.count > 50 {
            let toDelete = allLaunches.suffix(from: 50)
            let recordIDs = toDelete.map { $0.recordID }
            
            let results = try await privateDatabase.modifyRecords(
                saving: [],
                deleting: recordIDs
            )
            
            log("Pruned \(results.deleteResults.count) old recent launches")
        }
    }
    
    // MARK: - Account Status
    
    func checkAccountStatus() {
        container.accountStatus { [weak self] status, error in
            DispatchQueue.main.async {
                self?.accountStatus = status
                self?.iCloudAvailable = (status == .available)
                
                if status != .available {
                    self?.syncState = .noAccount
                }
            }
            
            if let error = error {
                self?.log("Account status error: \(error.localizedDescription)")
            }
        }
    }
    
    @objc private func accountChanged() {
        checkAccountStatus()
    }
    
    // MARK: - Private Implementation
    
    private func createZoneIfNeeded() async throws {
        let zone = CKRecordZone(zoneID: Self.syncZoneID)
        
        do {
            let savedZone = try await privateDatabase.save(zone)
            syncZone = savedZone
            log("Created sync zone: \(savedZone.zoneID.zoneName)")
        } catch let error as CKError where error.code == .serverRecordChanged {
            // Zone already exists, that's fine
            syncZone = zone
        }
    }
    
    private func subscribeToChanges() async throws {
        let subscriptionID = "openflux-sync-subscription"
        
        // Check if subscription exists
        do {
            _ = try await privateDatabase.subscription(for: subscriptionID)
            self.subscriptionID = subscriptionID
            return  // Already subscribed
        } catch {
            // Need to create subscription
        }
        
        let subscription = CKDatabaseSubscription(subscriptionID: subscriptionID)
        
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo
        
        let savedSubscription = try await privateDatabase.save(subscription)
        self.subscriptionID = savedSubscription.subscriptionID
        
        log("Subscribed to CloudKit changes")
    }
    
    private func saveRecord(_ record: CKRecord) async throws {
        do {
            _ = try await privateDatabase.save(record)
        } catch let error as CKError {
            if error.code == .networkFailure || error.code == .networkUnavailable {
                // Queue for later
                queueForOffline(record)
            } else if error.code == .serverRecordChanged {
                // Conflict - fetch server version and merge
                try await handleConflict(for: record, serverRecord: error.serverRecord)
            } else {
                throw error
            }
        }
    }
    
    private func handleConflict(for localRecord: CKRecord, serverRecord: CKRecord?) async throws {
        guard let serverRecord = serverRecord else {
            // No server record, just save local
            _ = try await privateDatabase.save(localRecord)
            return
        }
        
        // Default: use most recent (compare modifiedAt)
        let localModified = localRecord["modifiedAt"] as? Date ?? Date.distantPast
        let serverModified = serverRecord["modifiedAt"] as? Date ?? Date.distantPast
        
        if localModified > serverModified {
            // Local is newer - save with server's record change tag
            localRecord.encryptedValues["_mergedFromServer"] = Data()
            _ = try await privateDatabase.save(localRecord)
            log("Conflict resolved: used local (newer)")
        } else {
            // Server is newer - apply server record to local state
            await applyServerRecord(serverRecord)
            log("Conflict resolved: used server (newer)")
        }
    }
    
    private func applyServerRecord(_ record: CKRecord) async {
        await MainActor.run {
            switch record.recordType {
            case CloudKitRecordType.userPreferences.rawValue:
                if let prefs = SyncablePreferences.from(record: record) {
                    applyPreferencesToLocal(prefs)
                }
            case CloudKitRecordType.gameOverride.rawValue:
                if let override = SyncableGameOverride.from(record: record) {
                    applyGameOverrideToLocal(override)
                }
            default:
                break
            }
        }
    }
    
    private func applyPreferencesToLocal(_ prefs: SyncablePreferences) {
        let settings = SettingsManager.shared
        let theme = ThemeManager.shared
        
        // Apply theme
        if let themeValue = ThemeManager.Theme(rawValue: prefs.theme) {
            theme.currentTheme = themeValue
            UserDefaults.standard.set(themeValue.rawValue, forKey: "selectedTheme")
        }
        
        // Apply settings
        settings.uiScale = prefs.uiScale
        settings.feedbackButtonPosition = prefs.feedbackPosition
        settings.defaultLaunchEnvironment = prefs.defaultLaunchEnvironment
        settings.selectedLauncher = prefs.selectedLauncher
        settings.enableLogging = prefs.enableLogging
        settings.useGPTK = prefs.useGPTK
        settings.save()
        
        log("Applied remote preferences to local")
    }
    
    private func applyGameOverrideToLocal(_ override: SyncableGameOverride) {
        let settings = SettingsManager.shared
        
        if let method = override.launchMethod {
            settings.launchMethodOverrides[override.gameKey] = method
        }
        if let mode = override.gptkMode {
            settings.gptkModeOverrides[override.gameKey] = mode
        }
        if let api = override.graphicsAPI {
            settings.graphicsAPIOverrides[override.gameKey] = api
        }
        
        settings.save()
        log("Applied game override for: \(override.gameName)")
    }
    
    private func uploadLocalChanges() async throws {
        // Gather current local state
        let settings = SettingsManager.shared
        let theme = ThemeManager.shared
        
        // Upload preferences
        let prefs = SyncablePreferences.from(settings: settings, theme: theme)
        try await syncPreferences(prefs)
        
        // Upload game overrides
        for (key, method) in settings.launchMethodOverrides {
            let override = SyncableGameOverride(
                gameKey: key,
                gameName: extractGameName(from: key),
                launchMethod: method,
                gptkMode: settings.gptkModeOverrides[key],
                graphicsAPI: settings.graphicsAPIOverrides[key],
                modifiedAt: Date()
            )
            try await syncGameOverride(override)
        }
    }
    
    private func fetchRemoteChanges() async throws {
        // Fetch and apply remote preferences
        if let remotePrefs = try await fetchPreferences() {
            await MainActor.run {
                applyPreferencesToLocal(remotePrefs)
            }
        }
        
        // Fetch and apply game overrides
        let overrides = try await fetchGameOverrides()
        await MainActor.run {
            for override in overrides {
                applyGameOverrideToLocal(override)
            }
        }
    }
    
    // MARK: - Offline Queue
    
    private func queueForOffline(_ record: CKRecord) {
        offlineQueue.append(record)
        saveOfflineQueue()
        log("Queued record for offline: \(record.recordType)")
    }
    
    private func saveOfflineQueue() {
        let data = offlineQueue.compactMap { record -> Data? in
            try? NSKeyedArchiver.archivedData(withRootObject: record, requiringSecureCoding: true)
        }
        UserDefaults.standard.set(data, forKey: offlineQueueKey)
    }
    
    private func loadOfflineQueue() {
        guard let dataArray = UserDefaults.standard.array(forKey: offlineQueueKey) as? [Data] else {
            return
        }
        
        offlineQueue = dataArray.compactMap { data in
            try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKRecord.self, from: data)
        }
    }
    
    private func processOfflineQueue() async throws {
        loadOfflineQueue()
        
        guard !offlineQueue.isEmpty else { return }
        
        log("Processing \(offlineQueue.count) offline records")
        
        var successfulRecords: [CKRecord] = []
        
        for record in offlineQueue {
            do {
                _ = try await privateDatabase.save(record)
                successfulRecords.append(record)
            } catch {
                log("Failed to sync offline record: \(error.localizedDescription)")
            }
        }
        
        // Remove successful records from queue
        offlineQueue.removeAll { record in
            successfulRecords.contains { $0.recordID == record.recordID }
        }
        
        saveOfflineQueue()
        log("Processed offline queue, \(offlineQueue.count) remaining")
    }
    
    // MARK: - Helpers
    
    private func extractGameName(from key: String) -> String {
        if key.hasPrefix("steam:") {
            return "Steam Game \(key.replacingOccurrences(of: "steam:", with: ""))"
        } else if key.hasPrefix("path:") {
            let path = key.replacingOccurrences(of: "path:", with: "")
            return URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
        }
        return "Unknown Game"
    }
    
    private func log(_ message: String) {
        DispatchQueue.main.async {
            AppState.shared.log("[CloudKit] \(message)", category: .engine)
        }
    }
}

// MARK: - Error Types

enum CloudKitError: LocalizedError {
    case noAccount
    case networkUnavailable
    case quotaExceeded
    case serverError(String)
    case conflictUnresolved
    case zoneNotFound
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .noAccount:
            return "No iCloud account available. Sign in to iCloud in System Settings."
        case .networkUnavailable:
            return "Network unavailable. Changes will sync when connection is restored."
        case .quotaExceeded:
            return "iCloud storage quota exceeded. Free up space or upgrade storage."
        case .serverError(let msg):
            return "CloudKit server error: \(msg)"
        case .conflictUnresolved:
            return "Unable to resolve sync conflict."
        case .zoneNotFound:
            return "Sync zone not found. Try re-enabling sync."
        case .permissionDenied:
            return "Permission denied. Check iCloud settings for this app."
        }
    }
}

// MARK: - CKError Extension

extension CKError {
    var serverRecord: CKRecord? {
        return userInfo[CKRecordChangedErrorServerRecordKey] as? CKRecord
    }
    
    var isRetryable: Bool {
        switch code {
        case .networkFailure, .networkUnavailable, .serviceUnavailable, .requestRateLimited:
            return true
        default:
            return false
        }
    }
    
    var retryAfterSeconds: Double? {
        return userInfo[CKErrorRetryAfterKey] as? Double
    }
}
