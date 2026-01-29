import Foundation

/// Comprehensive system detection service
/// Checks for Steam, launchers, versions, mods, and available updates
class SystemDetector {
    static let shared = SystemDetector()

    // MARK: - File paths for supported launchers
    let launcherFilePaths: [String: [String]] = [
        "steam": [
            "~/Library/Application Support/Steam",
            "~/Applications/Steam.app",
            "/Applications/Steam.app",
        ],
        "epic": [
            "~/Library/Application Support/Epic/Launcher",
            "~/Library/Application Support/Epic Games",
        ],
        "gog": [
            "~/Library/Application Support/GOG.com",
            "~/Applications/GOG Galaxy.app",
        ],
        "ubisoft": [
            "~/Library/Application Support/Ubisoft",
            "~/Applications/Ubisoft Connect.app",
        ],
    ]

    // MARK: - Public Helper Methods

    /// Check if a specific launcher is installed (file-based check)
    func isLauncherInstalled(_ launcherId: String) -> Bool {
        guard let paths = launcherFilePaths[launcherId] else { return false }

        for path in paths {
            let expandedPath = (path as NSString).expandingTildeInPath
            if FileManager.default.fileExists(atPath: expandedPath) {
                return true
            }
        }
        return false
    }

    // MARK: - Wine & GPTK Detection

    /// Check Wine availability (independent from GPTK)
    func isWineAvailable() -> Bool {
        WineDetector.shared.isAvailable
    }

    /// Check GPTK availability (independent from Wine)
    func isGPTKAvailable() -> Bool {
        GPTKDetector.shared.isAvailable
    }

    /// Get launch readiness status
    func getLaunchReadiness() -> LaunchReadiness {
        let wineAvailable = isWineAvailable()
        let gptkAvailable = isGPTKAvailable()

        return LaunchReadiness(
            wineAvailable: wineAvailable,
            gptkAvailable: gptkAvailable,
            canLaunchNonD3D: wineAvailable,  // Only need Wine
            canLaunchD3D: wineAvailable && gptkAvailable  // Need both
        )
    }

    struct LaunchReadiness {
        let wineAvailable: Bool
        let gptkAvailable: Bool
        let canLaunchNonD3D: Bool
        let canLaunchD3D: Bool

        var status: String {
            switch (wineAvailable, gptkAvailable) {
            case (true, true):
                return "✓ Ready for all games"
            case (true, false):
                return "✓ Ready for OpenGL/Vulkan games (D3D games need GPTK)"
            case (false, true):
                return "✗ GPTK found but Wine missing (install: brew install --cask wine-stable)"
            case (false, false):
                return "✗ Wine and GPTK both missing"
            }
        }
    }

    // MARK: - Models

    struct SystemInfo {
        let steamInstalled: Bool
        let steamVersion: String?
        let launcherVersions: [String: String]  // name -> version
        let detectedMods: [ModInfo]
        let metalGPU: String?
        let metalSupport: Bool
        let updateAvailable: Bool
        let updateDetails: String?
        let steamwebhelperRunning: Bool
        let x64Support: Bool
        let x86Support: Bool
    }

    struct ModInfo: Identifiable {
        let id: String
        let name: String
        let path: String
        let arch: Architecture  // x86 or x64
        let size: Int64
        let lastModified: Date
        let compatible: Bool

        enum Architecture: String {
            case x86 = "x86"
            case x64 = "x64"
            case unknown = "unknown"
        }
    }

    // MARK: - Detection Methods

    /// Perform complete system detection
    func detectSystem() -> SystemInfo {

        let steamInfo = detectSteam()
        let launcherVersions = detectLaunchers()
        let mods = detectMods()
        let metalGPU = detectMetalGPU()
        let steamwebhelper = checkSteamwebhelper()
        let (updateAvailable, updateDetails) = checkForUpdates()

        let info = SystemInfo(
            steamInstalled: steamInfo.0,
            steamVersion: steamInfo.1,
            launcherVersions: launcherVersions,
            detectedMods: mods,
            metalGPU: metalGPU,
            metalSupport: metalGPU != nil,
            updateAvailable: updateAvailable,
            updateDetails: updateDetails,
            steamwebhelperRunning: steamwebhelper,
            x64Support: checkArchSupport(.x64),
            x86Support: checkArchSupport(.x86)
        )

        return info
    }

    // MARK: - Steam Detection

    private func detectSteam() -> (Bool, String?) {
        let steamPaths = [
            "~/Library/Application Support/Steam",
            "~/Applications/Steam.app",
            "/Applications/Steam.app",
        ]

        for path in steamPaths {
            let expandedPath = (path as NSString).expandingTildeInPath
            if FileManager.default.fileExists(atPath: expandedPath) {

                let version = extractSteamVersion(path: expandedPath)
                return (true, version)
            }
        }

        return (false, nil)
    }

    private func extractSteamVersion(path: String) -> String? {
        // Try to read version from Steam's info.plist or version files
        let infoPlist = "\(path)/Contents/Info.plist"

        if FileManager.default.fileExists(atPath: infoPlist) {
            if let plist = NSDictionary(contentsOfFile: infoPlist),
                let version = plist["CFBundleShortVersionString"] as? String
            {
                return version
            }
        }

        // Fallback: get from application
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        process.arguments = ["read", path + "/Contents/Info", "CFBundleShortVersionString"]

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if !data.isEmpty,
                let output = String(data: data, encoding: .utf8)?.trimmingCharacters(
                    in: .whitespacesAndNewlines)
            {
                return output
            }
        } catch {
            // Continue to next fallback
        }

        return nil
    }

    // MARK: - Launcher Detection

    private func detectLaunchers() -> [String: String] {
        var launchers: [String: String] = [:]

        let launcherMap = [
            ("Epic Games", "~/Library/Application Support/Epic/Launcher"),
            ("GOG Galaxy", "~/Library/Application Support/GOG.com"),
            ("Battle.net", "~/Library/Application Support/Blizzard Entertainment"),
            ("Uplay", "~/Library/Application Support/Uplay"),
        ]

        for (name, path) in launcherMap {
            let expandedPath = (path as NSString).expandingTildeInPath
            if FileManager.default.fileExists(atPath: expandedPath) {

                if let version = extractLauncherVersion(name: name, path: expandedPath) {
                    launchers[name] = version
                }
            }
        }

        return launchers
    }

    private func extractLauncherVersion(name: String, path: String) -> String? {
        let versionFile = path.appending("/.version")

        if FileManager.default.fileExists(atPath: versionFile),
            let content = try? String(contentsOfFile: versionFile, encoding: .utf8)
        {
            return content.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return "Installed"
    }

    // MARK: - Mod Detection

    private func detectMods() -> [ModInfo] {
        var mods: [ModInfo] = []
        let modPaths = [
            "~/.flux/prefix/drive_c/Program Files (x86)",
            "~/.flux/prefix/drive_c/Program Files",
            "~/.flux/mods",
        ]

        for modPath in modPaths {
            let expandedPath = (modPath as NSString).expandingTildeInPath

            if let contents = try? FileManager.default.contentsOfDirectory(atPath: expandedPath) {
                for item in contents {
                    let itemPath = expandedPath.appending("/\(item)")

                    if let modInfo = analyzeMod(at: itemPath, name: item) {
                        mods.append(modInfo)
                    }
                }
            }
        }

        return mods
    }

    private func analyzeMod(at path: String, name: String) -> ModInfo? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path) else {
            return nil
        }

        let fileSize = attributes[.size] as? Int64 ?? 0
        let modDate = attributes[.modificationDate] as? Date ?? Date()

        let arch = detectModArchitecture(path: path)
        let compatible = checkModCompatibility(arch: arch)

        return ModInfo(
            id: UUID().uuidString,
            name: name,
            path: path,
            arch: arch,
            size: fileSize,
            lastModified: modDate,
            compatible: compatible
        )
    }

    private func detectModArchitecture(path: String) -> ModInfo.Architecture {
        // Check file headers to determine architecture
        if let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: .alwaysMapped) {
            // MZ header (PE executable)
            if data.count > 4 && data[0] == 0x4D && data[1] == 0x5A {
                // Check machine type at offset 0x3C
                if data.count > 60 {
                    let peOffset = Int(
                        UInt32(
                            littleEndian: data.withUnsafeBytes {
                                $0.load(fromByteOffset: 0x3C, as: UInt32.self)
                            }))

                    if data.count > peOffset + 4 {
                        let machineType = UInt16(
                            littleEndian: data.withUnsafeBytes {
                                $0.load(fromByteOffset: peOffset + 4, as: UInt16.self)
                            })

                        switch machineType {
                        case 0x014C: return .x86  // i386
                        case 0x8664: return .x64  // x86-64
                        default: return .unknown
                        }
                    }
                }
            }
        }

        return .unknown
    }

    private func checkModCompatibility(arch: ModInfo.Architecture) -> Bool {
        switch arch {
        case .x86:
            return checkArchSupport(.x86)
        case .x64:
            return checkArchSupport(.x64)
        case .unknown:
            return false
        }
    }

    private func checkArchSupport(_ arch: ModInfo.Architecture) -> Bool {
        // Check if Wine is available (wine binary is universal enough; wine64 often missing on ARM)
        let wineDetector = WineDetector.shared
        guard let winePath = wineDetector.wineExecutablePath else { return false }

        // If we have any Wine, we treat both x86/x64 as supported for now.
        // TODO: refine when per-arch checks are needed.
        return FileManager.default.isExecutableFile(atPath: winePath)
    }

    // MARK: - Metal GPU Detection

    private func detectMetalGPU() -> String? {
        let metalDetector = MetalDeviceDetector.shared
        return metalDetector.metalInfo?.deviceName
    }

    // MARK: - Steamwebhelper Check

    private func checkSteamwebhelper() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", "pgrep -f steamwebhelper"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()

            let running = process.terminationStatus == 0
            return running
        } catch {
            return false
        }
    }

    // MARK: - Update Checking

    private func checkForUpdates() -> (Bool, String?) {
        // Check for Flux updates
        let fluxUpdate: (available: Bool, version: String?) = (false, nil)

        // In production, this would check GitHub releases
        // For now, we just log that we checked

        // Check for game updates
        let gameUpdatesAvailable: [String] = []

        // Placeholder for future implementation
        // This would check Steam for game updates

        let details =
            gameUpdatesAvailable.isEmpty
            ? nil : "Games with updates available: \(gameUpdatesAvailable.joined(separator: ", "))"

        return (fluxUpdate.available || !gameUpdatesAvailable.isEmpty, details)
    }

    // MARK: - Performance Overhead Calculation

    /// Calculate performance overhead for mod architecture support
    /// Returns overhead percentage (0-5% typical)
    func calculatePerformanceOverhead(forMods mods: [ModInfo]) -> Double {
        // Base overhead: <1%
        var overhead: Double = 0.5

        // Add small overhead for architecture translation if mixing x86/x64
        let hasX86 = mods.contains { $0.arch == .x86 }
        let hasX64 = mods.contains { $0.arch == .x64 }

        if hasX86 && hasX64 {
            overhead += 1.0  // +1% for mixed architecture handling
        }

        // Cap overhead at 5%
        return min(overhead, 5.0)
    }

    // MARK: - Status Reporting

    func generateSystemReport() -> String {
        let info = detectSystem()

        var report = """
            ╔════════════════════════════════════════════════╗
            ║          FLUX SYSTEM DETECTION REPORT          ║
            ╚════════════════════════════════════════════════╝

            STEAM STATUS:
            • Installed: \(info.steamInstalled ? "✅ Yes" : "❌ No")
            • Version: \(info.steamVersion ?? "Unknown")
            • Steamwebhelper: \(info.steamwebhelperRunning ? "✅ Running" : "❌ Not Running")

            GAME LAUNCHERS:
            """

        if info.launcherVersions.isEmpty {
            report += "\n• No additional launchers detected"
        } else {
            for (name, version) in info.launcherVersions {
                report += "\n• \(name): \(version)"
            }
        }

        report += """

            SYSTEM CAPABILITIES:
            • Metal GPU: \(info.metalGPU ?? "None detected")
            • Metal Support: \(info.metalSupport ? "✅ Yes" : "❌ No")
            • x86 Support: \(info.x86Support ? "✅ Yes" : "❌ No")
            • x64 Support: \(info.x64Support ? "✅ Yes" : "❌ No")

            MODS DETECTED: \(info.detectedMods.count)
            """

        for mod in info.detectedMods {
            report += "\n• \(mod.name) [\(mod.arch.rawValue)] - \(formatBytes(mod.size))"
        }

        if info.updateAvailable {
            report += """

                UPDATES AVAILABLE:
                • \(info.updateDetails ?? "Updates found")
                """
        }

        report += "\n\n✅ System detection complete"

        return report
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
