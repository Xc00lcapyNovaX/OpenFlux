import Foundation

enum GraphicsAPI: String, Codable {
    case unknown = "unknown"
    case directX = "directx"
    case openGL = "opengl"
    case vulkan = "vulkan"
}

enum LaunchMethod: String, Codable, CaseIterable {
    case steam = "Steam"
    case direct = "Direct"
}

enum GPTKMode: String, Codable, CaseIterable {
    case inherit = "Inherit"
    case enabled = "Enabled"
    case disabled = "Disabled"
}

struct Game: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let executablePath: String
    let installPath: String
    let steamAppId: Int
    var lastLaunchDate: Date?
    var playtime: Int = 0  // in minutes
    var hasDRMWarning = false
    var missingDependencies: [String] = []
    var executionEnvironment: ExecutionEnvironment = .native  // Which environment to run in
    var launchMethod: LaunchMethod = .direct
    var gptkMode: GPTKMode = .inherit
    var graphicsAPI: GraphicsAPI = .unknown
    var isSteamGame: Bool {
        steamAppId > 0
    }

    @discardableResult
    init(
        id: UUID = UUID(), name: String, executablePath: String, installPath: String,
        steamAppId: Int,
        environment: ExecutionEnvironment = .native,
        launchMethod: LaunchMethod? = nil,
        gptkMode: GPTKMode = .inherit,
        graphicsAPI: GraphicsAPI = .unknown
    ) {
        self.id = id
        self.name = name
        self.executablePath = executablePath
        self.installPath = installPath
        self.steamAppId = steamAppId
        self.executionEnvironment = environment
        self.gptkMode = gptkMode
        self.graphicsAPI = graphicsAPI
        if let launchMethod = launchMethod {
            self.launchMethod = launchMethod
        } else {
            self.launchMethod = steamAppId > 0 ? .steam : .direct
        }
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Game, rhs: Game) -> Bool {
        lhs.id == rhs.id
    }
}

struct GamePrefix: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let path: String
    let createdAt: Date
    var lastModified: Date?
    var isDefault: Bool = false
    var wineVersion: String?
    var gptkVersion: String?
}

struct GameConfig: Codable {
    var gameId: UUID = UUID()
    var prefixId: UUID?
    var environmentVariables: [String: String] = [:]
    var launchArgs: String = ""
    var useGPTK: Bool = false
    var graphicsAPI: GraphicsAPI = .directX  // Most Windows games use D3D
}
