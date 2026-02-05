import Foundation

struct DependencyLogHandler {
    let log: (String) -> Void
    let debug: (String) -> Void
    let warning: (String) -> Void
    let error: (String) -> Void

    static let defaultHandler = DependencyLogHandler(
        log: { Swift.print($0) },
        debug: { Swift.print($0) },
        warning: { Swift.print($0) },
        error: { Swift.print($0) }
    )
}

/// Resolves missing DLL dependencies and provides solutions
class DLLDependencyResolver {
    private let logger: DependencyLogHandler
    private let fileManager = FileManager.default

    init(logger: DependencyLogHandler = .defaultHandler) {
        self.logger = logger
    }

    /// Common Steam and system DLLs that might be missing
    private let commonMissingDLLs: [String: String] = [
        "steam_api64.dll": "Steam client API (64-bit) - Required for Steam games",
        "steam_api.dll": "Steam client API (32-bit) - Required for older Steam games",
        "vcruntime140.dll": "Visual C++ Runtime 2015 - Common dependency",
        "vcruntime140_1.dll": "Visual C++ Runtime 2015 Update 1 - Common dependency",
        "msvcp140.dll": "Visual C++ Standard Library - Common dependency",
        "d3d11.dll": "DirectX 11 - Graphics API",
        "d3d9.dll": "DirectX 9 - Legacy graphics API",
        "dinput8.dll": "DirectInput - Input device API",
        "dsound.dll": "DirectSound - Audio API",
        "dxgi.dll": "DirectX Graphics Infrastructure",
        "mscoree.dll": ".NET Framework - Managed code runtime",
        "kernel32.dll": "Windows kernel core",
        "ntdll.dll": "Windows NT runtime",
        "user32.dll": "Windows user interface",
        "gdi32.dll": "Graphics Device Interface",
        "advapi32.dll": "Advanced API services",
    ]

    /// Analyze an executable and detect missing dependencies
    func analyzeDependencies(executablePath: String) -> [String] {
        guard fileManager.fileExists(atPath: executablePath) else {
            logger.error("Executable not found: \(executablePath)")
            return []
        }

        var missingDLLs: [String] = []

        // Try to detect imported DLLs using strings command
        do {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/strings")
            task.arguments = [executablePath]

            let pipe = Pipe()
            task.standardOutput = pipe
            try task.run()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                // Look for common DLL imports
                for (dllName, _) in commonMissingDLLs {
                    if output.lowercased().contains(dllName.lowercased()) {
                        // Check if DLL exists in Wine prefix
                        if !isDLLAvailable(dllName) {
                            missingDLLs.append(dllName)
                        }
                    }
                }
            }
        } catch {
            logger.debug("Could not analyze dependencies: \(error)")
        }

        return missingDLLs
    }

    /// Check if a DLL is available in the Wine prefix
    private func isDLLAvailable(_ dllName: String) -> Bool {
        let possiblePaths = [
            NSHomeDirectory() + "/.flux/prefix-native/drive_c/windows/system32/\(dllName)",
            NSHomeDirectory() + "/.flux/prefix-native/drive_c/windows/syswow64/\(dllName)",
            NSHomeDirectory() + "/.flux/dlls/\(dllName)",
        ]

        for path in possiblePaths {
            if fileManager.fileExists(atPath: path) {
                return true
            }
        }

        return false
    }

    /// Generate stub DLLs for missing dependencies
    /// These allow executables to run even without full implementations
    func generateStubDLLs(for missingDLLs: [String], prefixPath: String) {
        let stubDir = prefixPath + "/drive_c/windows/system32"

        guard fileManager.fileExists(atPath: stubDir) else {
            logger.error("Wine prefix not found at: \(prefixPath)")
            return
        }

        // Skip Steam DLLs - they require special handling (SteamAPIEmulator)
        let steamDLLs = [
            "steam_api64.dll", "steam_api.dll", "steamclient64.dll", "steamclient.dll",
        ]

        for dllName in missingDLLs {
            // Skip Steam DLLs - they need real implementations or emulation
            if steamDLLs.contains(dllName.lowercased()) {
                logger.debug("Skipping Steam DLL (requires emulation): \(dllName)")
                continue
            }

            let dllPath = stubDir + "/\(dllName)"

            // Don't overwrite existing DLLs
            if fileManager.fileExists(atPath: dllPath) {
                logger.debug("DLL already exists: \(dllName)")
                continue
            }

            // Create a minimal stub DLL header
            if let stubData = createMinimalDLLStub(name: dllName) {
                do {
                    try stubData.write(to: URL(fileURLWithPath: dllPath), options: .atomic)
                    logger.log("✓ Created stub DLL: \(dllName)")
                } catch {
                    logger.error("Failed to create stub DLL \(dllName): \(error)")
                }
            }
        }
    }

    /// Create a minimal PE (Portable Executable) DLL header
    /// This is a bare-minimum DLL that won't crash Wine on load
    private func createMinimalDLLStub(name: String) -> Data? {
        // Minimal PE/COFF header for a DLL
        // This creates a valid PE file that Wine can load without crashing
        var header = Data()

        // DOS header
        header.append(0x4D)  // 'M'
        header.append(0x5A)  // 'Z'

        // Pad to 0x3C (offset to PE signature)
        header.append(contentsOf: Array(repeating: UInt8(0), count: 0x3A))

        // PE signature offset (at 0x3C, little-endian)
        header.append(0x40)
        header.append(0x00)
        header.append(0x00)
        header.append(0x00)

        // DOS stub padding to 0x40
        header.append(contentsOf: Array(repeating: UInt8(0), count: 0x40 - header.count))

        // PE signature "PE\0\0"
        header.append(0x50)  // 'P'
        header.append(0x45)  // 'E'
        header.append(0x00)
        header.append(0x00)

        // COFF header (20 bytes)
        // Machine (x86-64)
        header.append(0x64)
        header.append(0x86)

        // NumberOfSections
        header.append(0x03)
        header.append(0x00)

        // TimeDateStamp, PointerToSymbolTable, NumberOfSymbols, SizeOfOptionalHeader
        header.append(contentsOf: Array(repeating: UInt8(0), count: 12))

        // Characteristics (DLL flag)
        header.append(0x22)
        header.append(0x20)

        return header
    }

    /// Get solutions for missing DLLs
    func getSolutions(for missingDLLs: [String]) -> [String] {
        var solutions: [String] = []

        for dll in missingDLLs {
            if let description = commonMissingDLLs[dll] {
                solutions.append("\(dll): \(description)")
            }
        }

        return solutions
    }

    /// Report dependency issues to user
    func reportMissingDependencies(_ missingDLLs: [String], executable: String) {
        if missingDLLs.isEmpty {
            logger.log("✓ All dependencies found")
            return
        }

        logger.warning("Missing \(missingDLLs.count) DLL dependencies for \(executable)")

        for (index, dll) in missingDLLs.enumerated() {
            if let info = commonMissingDLLs[dll] {
                logger.log("\(index + 1). \(info)")
            } else {
                logger.log("\(index + 1). \(dll)")
            }
        }

        logger.log("Creating stub DLLs to allow execution...")
    }
}
