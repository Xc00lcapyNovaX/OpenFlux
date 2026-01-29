import Foundation

enum PEArch: Equatable {
    case x86
    case x64
    case arm64
    case unknown
}

/// Minimal PE header inspection (Windows .exe/.dll) to determine CPU architecture.
/// This is used to select the correct Wine prefix (win32 vs wow64/64-bit).
final class PEInspector {
    static let shared = PEInspector()

    func detectArch(path: String) -> PEArch {
        guard let handle = try? FileHandle(forReadingFrom: URL(fileURLWithPath: path)) else {
            return .unknown
        }
        defer { try? handle.close() }

        // Minimal PE parse:
        // - 0x3C -> uint32 e_lfanew (PE header offset)
        // - e_lfanew + 4 -> uint16 Machine
        do {
            let header = try handle.read(upToCount: 64) ?? Data()
            if header.count < 64 { return .unknown }
            if header[0] != 0x4D || header[1] != 0x5A { return .unknown } // "MZ"

            let e_lfanew: UInt32 = header.withUnsafeBytes { ptr in
                let base = ptr.bindMemory(to: UInt8.self).baseAddress!
                return base.advanced(by: 0x3C).withMemoryRebound(to: UInt32.self, capacity: 1) { p in
                    UInt32(littleEndian: p.pointee)
                }
            }

            try handle.seek(toOffset: UInt64(e_lfanew))
            let peSigAndMachine = try handle.read(upToCount: 6) ?? Data()
            if peSigAndMachine.count < 6 { return .unknown }
            if peSigAndMachine[0] != 0x50 || peSigAndMachine[1] != 0x45
                || peSigAndMachine[2] != 0x00 || peSigAndMachine[3] != 0x00
            {
                return .unknown // "PE\0\0"
            }

            let machine = UInt16(littleEndian: peSigAndMachine[4..<6].withUnsafeBytes { $0.load(as: UInt16.self) })
            switch machine {
            case 0x014c: return .x86   // IMAGE_FILE_MACHINE_I386
            case 0x8664: return .x64   // IMAGE_FILE_MACHINE_AMD64
            case 0xAA64: return .arm64 // IMAGE_FILE_MACHINE_ARM64 (Windows ARM64)
            default: return .unknown
            }
        } catch {
            return .unknown
        }
    }
}

