import Foundation
import CloudKit

// MARK: - Record Type Constants

enum CloudKitRecordType: String {
    case userPreferences = "UserPreferences"
    case gameOverride = "GameOverride"
    case recentLaunch = "RecentLaunch"
    case syncMetadata = "SyncMetadata"
}

// MARK: - Syncable Protocol

protocol CloudKitSyncable {
    var recordType: CloudKitRecordType { get }
    var recordID: CKRecord.ID { get }
    func toCKRecord() -> CKRecord
    static func from(record: CKRecord) -> Self?
}

// MARK: - Sync Data Models

/// User preferences that sync across devices
/// Note: All devices write to the same "preferences" record (last-writer-wins).
/// deviceId is informational only - it shows which device last modified the prefs,
/// but does not represent ownership or authority.
struct SyncablePreferences: Codable, Equatable, CloudKitSyncable {
    // Identity (informational - shows last modifier, not ownership)
    var deviceId: String
    
    // Theme & UI
    var theme: String
    var uiScale: Double
    var feedbackPosition: String
    
    // Launch Settings
    var defaultLaunchEnvironment: String
    var selectedLauncher: String
    var enableLogging: Bool
    var useGPTK: Bool
    
    // Sync metadata
    var modifiedAt: Date
    // TODO: Add syncVersion when implementing optimistic locking / conflict resolution
    // var syncVersion: Int64
    
    // MARK: - CloudKitSyncable
    
    var recordType: CloudKitRecordType { .userPreferences }
    
    var recordID: CKRecord.ID {
        CKRecord.ID(recordName: "preferences", zoneID: CloudKitManager.syncZoneID)
    }
    
    func toCKRecord() -> CKRecord {
        let record = CKRecord(recordType: recordType.rawValue, recordID: recordID)
        record["deviceId"] = deviceId
        record["theme"] = theme
        record["uiScale"] = uiScale
        record["feedbackPosition"] = feedbackPosition
        record["defaultLaunchEnvironment"] = defaultLaunchEnvironment
        record["selectedLauncher"] = selectedLauncher
        record["enableLogging"] = enableLogging ? 1 : 0
        record["useGPTK"] = useGPTK ? 1 : 0
        record["modifiedAt"] = modifiedAt
        return record
    }
    
    static func from(record: CKRecord) -> SyncablePreferences? {
        guard record.recordType == CloudKitRecordType.userPreferences.rawValue else { return nil }
        
        return SyncablePreferences(
            deviceId: record["deviceId"] as? String ?? "",
            theme: record["theme"] as? String ?? "Midnight",
            uiScale: record["uiScale"] as? Double ?? 1.0,
            feedbackPosition: record["feedbackPosition"] as? String ?? "bottomLeft",
            defaultLaunchEnvironment: record["defaultLaunchEnvironment"] as? String ?? "x86",
            selectedLauncher: record["selectedLauncher"] as? String ?? "steam",
            enableLogging: (record["enableLogging"] as? Int64 ?? 1) == 1,
            useGPTK: (record["useGPTK"] as? Int64 ?? 0) == 1,
            modifiedAt: record["modifiedAt"] as? Date ?? Date()
        )
    }
    
    // MARK: - Factory
    
    static func from(settings: SettingsManager, theme: ThemeManager) -> SyncablePreferences {
        SyncablePreferences(
            deviceId: CloudKitManager.deviceIdentifier,
            theme: theme.currentTheme.rawValue,
            uiScale: settings.uiScale,
            feedbackPosition: settings.feedbackButtonPosition,
            defaultLaunchEnvironment: settings.defaultLaunchEnvironment,
            selectedLauncher: settings.selectedLauncher,
            enableLogging: settings.enableLogging,
            useGPTK: settings.useGPTK,
            modifiedAt: Date()
        )
    }
}

/// Per-game override settings
struct SyncableGameOverride: Codable, Equatable, CloudKitSyncable {
    var gameKey: String          // "steam:322170" or "path:<hash>"
    var gameName: String
    var launchMethod: String?
    var gptkMode: String?
    var graphicsAPI: String?
    var modifiedAt: Date
    
    // MARK: - CloudKitSyncable
    
    var recordType: CloudKitRecordType { .gameOverride }
    
    var recordID: CKRecord.ID {
        // Sanitize gameKey for CloudKit record names (alphanumeric + _ only)
        // Hash complex keys to avoid issues with slashes, spaces, special chars
        let sanitized: String
        if gameKey.rangeOfCharacter(from: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_")).inverted) != nil {
            // Contains special chars - use hash
            let hash = abs(gameKey.hashValue)
            sanitized = "hash_\(hash)"
        } else {
            // Safe characters only
            sanitized = gameKey.replacingOccurrences(of: ":", with: "_")
        }
        return CKRecord.ID(recordName: "override_\(sanitized)", zoneID: CloudKitManager.syncZoneID)
    }
    
    func toCKRecord() -> CKRecord {
        let record = CKRecord(recordType: recordType.rawValue, recordID: recordID)
        record["gameKey"] = gameKey
        record["gameName"] = gameName
        record["launchMethod"] = launchMethod
        record["gptkMode"] = gptkMode
        record["graphicsAPI"] = graphicsAPI
        record["modifiedAt"] = modifiedAt
        return record
    }
    
    static func from(record: CKRecord) -> SyncableGameOverride? {
        guard record.recordType == CloudKitRecordType.gameOverride.rawValue,
              let gameKey = record["gameKey"] as? String else { return nil }
        
        return SyncableGameOverride(
            gameKey: gameKey,
            gameName: record["gameName"] as? String ?? "Unknown",
            launchMethod: record["launchMethod"] as? String,
            gptkMode: record["gptkMode"] as? String,
            graphicsAPI: record["graphicsAPI"] as? String,
            modifiedAt: record["modifiedAt"] as? Date ?? Date()
        )
    }
}

/// Recent app launch for cross-device history
struct SyncableRecentLaunch: Codable, Equatable, CloudKitSyncable {
    var id: String               // UUID string
    var gameKey: String
    var gameName: String
    var launchMethod: String
    var timestamp: Date
    var success: Bool
    var deviceName: String
    
    // MARK: - CloudKitSyncable
    
    var recordType: CloudKitRecordType { .recentLaunch }
    
    var recordID: CKRecord.ID {
        CKRecord.ID(recordName: "recent_\(id)", zoneID: CloudKitManager.syncZoneID)
    }
    
    func toCKRecord() -> CKRecord {
        let record = CKRecord(recordType: recordType.rawValue, recordID: recordID)
        record["id"] = id
        record["gameKey"] = gameKey
        record["gameName"] = gameName
        record["launchMethod"] = launchMethod
        record["timestamp"] = timestamp
        record["success"] = success ? 1 : 0
        record["deviceName"] = deviceName
        return record
    }
    
    static func from(record: CKRecord) -> SyncableRecentLaunch? {
        guard record.recordType == CloudKitRecordType.recentLaunch.rawValue,
              let id = record["id"] as? String,
              let gameKey = record["gameKey"] as? String else { return nil }
        
        return SyncableRecentLaunch(
            id: id,
            gameKey: gameKey,
            gameName: record["gameName"] as? String ?? "Unknown",
            launchMethod: record["launchMethod"] as? String ?? "unknown",
            timestamp: record["timestamp"] as? Date ?? Date(),
            success: (record["success"] as? Int64 ?? 1) == 1,
            deviceName: record["deviceName"] as? String ?? "Unknown Mac"
        )
    }
}

/// Sync state metadata
struct SyncMetadata: Codable, CloudKitSyncable {
    var lastSyncDate: Date
    var lastSyncDevice: String
    var schemaVersion: Int64
    var modifiedAt: Date  // Universal conflict comparator
    
    static let currentSchemaVersion: Int64 = 1
    
    // MARK: - CloudKitSyncable
    
    var recordType: CloudKitRecordType { .syncMetadata }
    
    var recordID: CKRecord.ID {
        CKRecord.ID(recordName: "sync_metadata", zoneID: CloudKitManager.syncZoneID)
    }
    
    func toCKRecord() -> CKRecord {
        let record = CKRecord(recordType: recordType.rawValue, recordID: recordID)
        record["lastSyncDate"] = lastSyncDate
        record["lastSyncDevice"] = lastSyncDevice
        record["schemaVersion"] = schemaVersion
        record["modifiedAt"] = modifiedAt
        return record
    }
    
    static func from(record: CKRecord) -> SyncMetadata? {
        guard record.recordType == CloudKitRecordType.syncMetadata.rawValue else { return nil }
        
        return SyncMetadata(
            lastSyncDate: record["lastSyncDate"] as? Date ?? Date(),
            lastSyncDevice: record["lastSyncDevice"] as? String ?? "",
            schemaVersion: record["schemaVersion"] as? Int64 ?? currentSchemaVersion,
            modifiedAt: record["modifiedAt"] as? Date ?? Date()
        )
    }
}

// MARK: - Sync State

enum SyncState: Equatable {
    case idle
    case syncing
    case error(String)
    case disabled
    case noAccount
    
    var description: String {
        switch self {
        case .idle: return "Synced"
        case .syncing: return "Syncing..."
        case .error(let msg): return "Error: \(msg)"
        case .disabled: return "Sync Disabled"
        case .noAccount: return "No iCloud Account"
        }
    }
}

// MARK: - Sync Direction

enum SyncDirection {
    case upload      // Local → Cloud
    case download    // Cloud → Local
    case merge       // Bidirectional with conflict resolution
}

// MARK: - Conflict Resolution

/// Conflict resolution strategies for CloudKit sync conflicts.
/// TODO: Wire this into CloudKitManager.handleConflict() to make resolution policy configurable.
/// Currently using hardcoded .useMostRecent (timestamp comparison).
/// Future: Allow per-record-type resolution strategies.
enum ConflictResolution {
    case useLocal       // Always prefer local changes
    case useRemote      // Always prefer server version
    case useMostRecent  // Default: compare modifiedAt timestamps (currently implemented)
    case merge          // For arrays/collections: combine both (planned for recentLaunches)
}
