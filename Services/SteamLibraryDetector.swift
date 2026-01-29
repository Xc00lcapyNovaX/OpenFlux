import Foundation

class SteamLibraryDetector {
    private let fileManager = FileManager.default

    func detectInstalledGames() -> [Game]? {
        guard let steamPath = findSteamInstallation() else {
            print("Steam not found")
            return nil
        }

        let libraryFolders = findSteamLibraries(basePath: steamPath)
        var games: [Game] = []

        for libPath in libraryFolders {
            if let libGames = parseLibrary(at: libPath) {
                games.append(contentsOf: libGames)
            }
        }

        return games
    }

    private func findSteamInstallation() -> String? {
        let possiblePaths = [
            "~/Library/Application Support/Steam",
            "~/.steam",
            "~/.steampaths",
        ].map { NSString(string: $0).expandingTildeInPath }

        for path in possiblePaths {
            if fileManager.fileExists(atPath: path) {
                return path
            }
        }
        return nil
    }

    private func findSteamLibraries(basePath: String) -> [String] {
        var libraries = [basePath + "/steamapps"]

        let libraryFoldersPath = basePath + "/steamapps/libraryfolders.vdf"
        if let content = try? String(contentsOfFile: libraryFoldersPath, encoding: .utf8) {
            // Parse VDF to find additional library paths
            let lines = content.split(separator: "\n")
            for line in lines {
                if line.contains("path") {
                    if let path = extractPathFromVDF(line: String(line)) {
                        let steamappsPath = path + "/steamapps"
                        if fileManager.fileExists(atPath: steamappsPath) {
                            libraries.append(steamappsPath)
                        }
                    }
                }
            }
        }

        return libraries
    }

    private func parseLibrary(at path: String) -> [Game]? {
        var games: [Game] = []

        guard let contents = try? fileManager.contentsOfDirectory(atPath: path) else {
            return nil
        }

        for item in contents {
            if item.hasSuffix(".acf") {
                let manifestPath = (path as NSString).appendingPathComponent(item)
                if let game = parseManifest(at: manifestPath) {
                    games.append(game)
                }
            }
        }

        return games.isEmpty ? nil : games
    }

    private func parseManifest(at path: String) -> Game? {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            return nil
        }

        var appId = 0
        var name = ""
        var installDir = ""

        let lines = content.split(separator: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.contains("\"appid\"") {
                if let id = extractValue(from: String(trimmed)) {
                    appId = Int(id) ?? 0
                }
            } else if trimmed.contains("\"name\"") {
                name = extractValue(from: String(trimmed)) ?? ""
            } else if trimmed.contains("\"installdir\"") {
                installDir = extractValue(from: String(trimmed)) ?? ""
            }
        }

        guard appId > 0, !name.isEmpty, !installDir.isEmpty else {
            return nil
        }

        let libraryPath = (path as NSString).deletingLastPathComponent
        let gamePath = (libraryPath as NSString).appendingPathComponent(installDir)
        let exePath = findExecutable(in: gamePath)

        guard !exePath.isEmpty else {
            return nil
        }

        return Game(
            name: name,
            executablePath: exePath,
            installPath: gamePath,
            steamAppId: appId
        )
    }

    private func findExecutable(in path: String) -> String {
        guard let contents = try? fileManager.contentsOfDirectory(atPath: path) else {
            return ""
        }

        // Skip macOS native games (.app bundles)
        // OpenFlux is specifically for Windows games via Wine/GPTK
        for item in contents {
            if item.hasSuffix(".app") {
                print("Skipping macOS native game: \(item)")
                return ""
            }
        }

        // Search root directory for .exe/.bat
        for item in contents {
            if item.lowercased().hasSuffix(".exe") || item.lowercased().hasSuffix(".bat") {
                return (path as NSString).appendingPathComponent(item)
            }
        }

        // Search subdirectories for .exe/.bat (many games have these in subdirs)
        for item in contents {
            let itemPath = (path as NSString).appendingPathComponent(item)
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: itemPath, isDirectory: &isDir), isDir.boolValue {
                if let subExe = findExecutableRecursive(in: itemPath, depth: 0) {
                    return subExe
                }
            }
        }

        return ""
    }

    private func findExecutableRecursive(in path: String, depth: Int) -> String? {
        // Limit recursion depth to avoid scanning too deep
        guard depth < 3 else { return nil }

        guard let contents = try? fileManager.contentsOfDirectory(atPath: path) else {
            return nil
        }

        // First check this directory for .exe/.bat
        for item in contents {
            if item.lowercased().hasSuffix(".exe") || item.lowercased().hasSuffix(".bat") {
                return (path as NSString).appendingPathComponent(item)
            }
        }

        // Then check subdirectories
        for item in contents {
            let itemPath = (path as NSString).appendingPathComponent(item)
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: itemPath, isDirectory: &isDir), isDir.boolValue {
                if let subExe = findExecutableRecursive(in: itemPath, depth: depth + 1) {
                    return subExe
                }
            }
        }

        return nil
    }

    private func extractValue(from line: String) -> String? {
        guard let startIdx = line.firstIndex(of: "\""),
            let endIdx = line.lastIndex(of: "\"")
        else {
            return nil
        }

        let start = line.index(after: startIdx)
        if start < endIdx {
            return String(line[start..<endIdx])
        }
        return nil
    }

    private func extractPathFromVDF(line: String) -> String? {
        let components = line.split(separator: "\"")
        if components.count >= 4 {
            return String(components[3])
        }
        return nil
    }
}
