import Foundation

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    @Published var wineDirectory: String
    @Published var gptkPath: String
    @Published var useGPTK: Bool
    @Published var enableLogging: Bool
    @Published var selectedLauncher: String = "steam"  // Default launcher
    @Published var hasCompletedOnboarding: Bool = false
    @Published var hasLoggedIn: Bool = false  // Login state
    @Published var userEmail: String = ""  // Currently logged in user
    @Published var lastSeenVersion: String = ""  // Tracks last version that showed patch notes
    @Published var defaultLaunchEnvironment: String = ExecutionEnvironment.x86.rawValue
    @Published var launchMethodOverrides: [String: String] = [:]
    @Published var gptkModeOverrides: [String: String] = [:]
    @Published var graphicsAPIOverrides: [String: String] = [:]

    private let defaults = UserDefaults.standard
    private let prefix = "com.flux."

    init() {
        wineDirectory =
            defaults.string(forKey: prefix + "wineDirectory") ?? NSHomeDirectory() + "/.wine"
        gptkPath = defaults.string(forKey: prefix + "gptkPath") ?? "/opt/gptk"
        if defaults.object(forKey: prefix + "useGPTK") != nil {
            useGPTK = defaults.bool(forKey: prefix + "useGPTK")
        } else {
            useGPTK = false
        }
        if defaults.object(forKey: prefix + "enableLogging") != nil {
            enableLogging = defaults.bool(forKey: prefix + "enableLogging")
        } else {
            enableLogging = true
        }
        selectedLauncher = defaults.string(forKey: prefix + "selectedLauncher") ?? "steam"
        hasCompletedOnboarding = defaults.bool(forKey: prefix + "hasCompletedOnboarding")
        hasLoggedIn = defaults.bool(forKey: prefix + "hasLoggedIn")
        userEmail = defaults.string(forKey: prefix + "userEmail") ?? ""
        lastSeenVersion = defaults.string(forKey: prefix + "lastSeenVersion") ?? ""
        defaultLaunchEnvironment =
            defaults.string(forKey: prefix + "defaultLaunchEnvironment")
            ?? ExecutionEnvironment.x86.rawValue
        if let data = defaults.data(forKey: prefix + "launchMethodOverrides"),
            let decoded = try? JSONDecoder().decode([String: String].self, from: data)
        {
            launchMethodOverrides = decoded
        } else {
            launchMethodOverrides = [:]
        }
        if let data = defaults.data(forKey: prefix + "gptkModeOverrides"),
            let decoded = try? JSONDecoder().decode([String: String].self, from: data)
        {
            gptkModeOverrides = decoded
        } else {
            gptkModeOverrides = [:]
        }
        if let data = defaults.data(forKey: prefix + "graphicsAPIOverrides"),
            let decoded = try? JSONDecoder().decode([String: String].self, from: data)
        {
            graphicsAPIOverrides = decoded
        } else {
            graphicsAPIOverrides = [:]
        }

        setupDirectories()
    }

    func setupDirectories() {
        createDirectoryIfNeeded(getAppDirectory())
        createDirectoryIfNeeded(getPrefixDirectory())
        createDirectoryIfNeeded(getLogsDirectory())
        createDirectoryIfNeeded(getPrefixesDirectory())
    }

    private func createDirectoryIfNeeded(_ path: String) {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: path) {
            try? fileManager.createDirectory(
                atPath: path,
                withIntermediateDirectories: true)
        }
    }

    func save() {
        defaults.set(wineDirectory, forKey: prefix + "wineDirectory")
        defaults.set(gptkPath, forKey: prefix + "gptkPath")
        defaults.set(useGPTK, forKey: prefix + "useGPTK")
        defaults.set(enableLogging, forKey: prefix + "enableLogging")
        defaults.set(selectedLauncher, forKey: prefix + "selectedLauncher")
        defaults.set(hasCompletedOnboarding, forKey: prefix + "hasCompletedOnboarding")
        defaults.set(hasLoggedIn, forKey: prefix + "hasLoggedIn")
        defaults.set(userEmail, forKey: prefix + "userEmail")
        defaults.set(lastSeenVersion, forKey: prefix + "lastSeenVersion")
        defaults.set(defaultLaunchEnvironment, forKey: prefix + "defaultLaunchEnvironment")
        if let data = try? JSONEncoder().encode(launchMethodOverrides) {
            defaults.set(data, forKey: prefix + "launchMethodOverrides")
        }
        if let data = try? JSONEncoder().encode(gptkModeOverrides) {
            defaults.set(data, forKey: prefix + "gptkModeOverrides")
        }
        if let data = try? JSONEncoder().encode(graphicsAPIOverrides) {
            defaults.set(data, forKey: prefix + "graphicsAPIOverrides")
        }
        defaults.synchronize()
    }

    var preferredLaunchEnvironment: ExecutionEnvironment {
        get { ExecutionEnvironment(rawValue: defaultLaunchEnvironment) ?? .x86 }
        set {
            defaultLaunchEnvironment = newValue.rawValue
            save()
        }
    }

    func launchMethodKey(for game: Game) -> String {
        if game.steamAppId != 0 {
            return "steam:\(game.steamAppId)"
        }
        return "path:\(game.executablePath)"
    }

    func gptkModeKey(for game: Game) -> String {
        if game.steamAppId != 0 {
            return "steam:\(game.steamAppId)"
        }
        return "path:\(game.executablePath)"
    }

    func graphicsAPIKey(for game: Game) -> String {
        if game.steamAppId != 0 {
            return "steam:\(game.steamAppId)"
        }
        return "path:\(game.executablePath)"
    }

    func launchMethod(for game: Game) -> LaunchMethod? {
        let key = launchMethodKey(for: game)
        if let raw = launchMethodOverrides[key] {
            return LaunchMethod(rawValue: raw)
        }
        return nil
    }

    func setLaunchMethod(_ method: LaunchMethod, for game: Game) {
        let key = launchMethodKey(for: game)
        launchMethodOverrides[key] = method.rawValue
        save()
    }

    func gptkMode(for game: Game) -> GPTKMode? {
        let key = gptkModeKey(for: game)
        if let raw = gptkModeOverrides[key] {
            return GPTKMode(rawValue: raw)
        }
        return nil
    }

    func setGPTKMode(_ mode: GPTKMode, for game: Game) {
        let key = gptkModeKey(for: game)
        gptkModeOverrides[key] = mode.rawValue
        save()
    }

    func graphicsAPI(for game: Game) -> GraphicsAPI? {
        let key = graphicsAPIKey(for: game)
        if let raw = graphicsAPIOverrides[key] {
            return GraphicsAPI(rawValue: raw)
        }
        return nil
    }

    func setGraphicsAPI(_ api: GraphicsAPI, for game: Game) {
        let key = graphicsAPIKey(for: game)
        graphicsAPIOverrides[key] = api.rawValue
        save()
    }

    func getAppDirectory() -> String {
        return NSHomeDirectory() + "/.flux"
    }

    func getPrefixDirectory() -> String {
        return getAppDirectory() + "/prefix"
    }

    func getPrefixesDirectory() -> String {
        return getAppDirectory() + "/prefixes"
    }

    func getLogsDirectory() -> String {
        return getAppDirectory() + "/logs"
    }
}
