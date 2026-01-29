import Foundation

/// Defines execution environments for running games and applications
enum ExecutionEnvironment: String, Codable, CaseIterable {
    // NOTE: These names are UI-facing. Internally, this is a Wine prefix split:
    // - .native: 64-bit (WOW64-capable) prefix
    // - .x86: 32-bit (win32) prefix
    case native = "Native"
    case x86 = "x86"
    
    var displayName: String {
        switch self {
        case .native:
            return "x64 (Default)"
        case .x86:
            return "x86 (32-bit)"
        }
    }
    
    var description: String {
        switch self {
        case .native:
            return "64-bit Wine prefix (WOW64-capable); use for most modern Windows apps"
        case .x86:
            return "32-bit Wine prefix (win32); use for legacy 32-bit apps and installers"
        }
    }
    
    var icon: String {
        switch self {
        case .native:
            return "🧩"  // Puzzle for default prefix
        case .x86:
            return "🧱"  // Brick for legacy/32-bit
        }
    }
    
    var color: String {
        switch self {
        case .native:
            return "#4DB8FF"  // Blue for native
        case .x86:
            return "#FF9D4D"  // Orange for virtualized
        }
    }
}

/// Manages execution environments and routing
class AppEnvironmentManager {
    private let appState = AppState.shared
    private let settingsManager = SettingsManager.shared
    private let wineDetector = WineDetector.shared
    
    // Environment prefixes
    private let nativePrefixPath: String
    private let x86PrefixPath: String
    
    static let shared = AppEnvironmentManager()
    
    init() {
        let basePrefix = settingsManager.getPrefixDirectory()
        self.nativePrefixPath = basePrefix + "-native"
        self.x86PrefixPath = basePrefix + "-x86"
        
        setupEnvironments()
    }
    
    /// Setup separate Wine prefixes for each environment
    private func setupEnvironments() {
        let fileManager = FileManager.default
        
        // Ensure native prefix exists
        if !fileManager.fileExists(atPath: nativePrefixPath) {
            do {
                try fileManager.createDirectory(atPath: nativePrefixPath, 
                                               withIntermediateDirectories: true)
                appState.debug("Created native prefix: \(nativePrefixPath)", category: .environment)
            } catch {
                appState.error("Failed to create native prefix: \(error)", category: .environment)
            }
        }
        
        // Ensure x86 prefix exists
        if !fileManager.fileExists(atPath: x86PrefixPath) {
            do {
                try fileManager.createDirectory(atPath: x86PrefixPath, 
                                               withIntermediateDirectories: true)
                appState.debug("Created x86 prefix: \(x86PrefixPath)", category: .environment)
            } catch {
                appState.error("Failed to create x86 prefix: \(error)", category: .environment)
            }
        }
    }
    
    /// Get Wine prefix for environment
    func getPrefixPath(for environment: ExecutionEnvironment) -> String {
        switch environment {
        case .native:
            return nativePrefixPath
        case .x86:
            return x86PrefixPath
        }
    }
    
    /// Get wine executable path for environment (ARM uses `wine`, not wine64)
    func getWineExecutablePath(for environment: ExecutionEnvironment) -> String {
        if let detected = wineDetector.wineExecutablePath {
            return detected
        }

        // Fallback: use configured wine directory's wine binary
        let wineDir = settingsManager.wineDirectory
        let winePath = wineDir + "/bin/wine"
        return winePath
    }
    
    /// Check if environment is properly configured
    func isEnvironmentAvailable(_ environment: ExecutionEnvironment) -> Bool {
        let prefixPath = getPrefixPath(for: environment)
        let wineExe = getWineExecutablePath(for: environment)
        
        return FileManager.default.fileExists(atPath: prefixPath) &&
               FileManager.default.fileExists(atPath: wineExe)
    }
    
    /// Get all available environments
    func availableEnvironments() -> [ExecutionEnvironment] {
        return ExecutionEnvironment.allCases.filter { isEnvironmentAvailable($0) }
    }
    
    /// Log environment status
    func logEnvironmentStatus() {
        appState.log("═══════════════════════════════════════════", category: .environment)
        appState.log("Execution Environments Available:", category: .environment)
        appState.log("═══════════════════════════════════════════", category: .environment)
        
        for env in ExecutionEnvironment.allCases {
            let status = isEnvironmentAvailable(env) ? "✓" : "✗"
            let prefix = getPrefixPath(for: env)
            appState.log("\(status) \(env.icon) \(env.displayName)", category: .environment)
            appState.debug("   Prefix: \(prefix)", category: .environment)
            appState.debug("   Wine: \(getWineExecutablePath(for: env))", category: .environment)
        }
    }
}
