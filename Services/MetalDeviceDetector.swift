import Foundation

class MetalDeviceDetector {
    static let shared = MetalDeviceDetector()
    
    struct MetalInfo {
        let deviceName: String
        let architecture: String
        let maxThreads: Int
        let supportsD3D11: Bool
        let supportsD3D12: Bool
    }
    
    private(set) var metalInfo: MetalInfo?
    
    init() {
        detectMetalDevice()
    }
    
    private func detectMetalDevice() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/system_profiler")
        process.arguments = ["SPDisplaysDataType"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                parseMetalInfo(from: output)
            }
        } catch {
            print("Failed to detect Metal device: \(error)")
        }
    }
    
    private func parseMetalInfo(from output: String) {
        var deviceName = "Unknown"
        var architecture = "Unknown"
        
        let lines = output.split(separator: "\n")
        for line in lines {
            let trimmed = String(line).trimmingCharacters(in: .whitespaces)
            
            if trimmed.contains("Chipset Model") {
                if let model = trimmed.split(separator: ":").last {
                    deviceName = String(model).trimmingCharacters(in: .whitespaces)
                }
            }
            
            if trimmed.contains("Vendor") && trimmed.contains("Apple") {
                architecture = "Apple Silicon"
            }
        }
        
        metalInfo = MetalInfo(
            deviceName: deviceName,
            architecture: architecture,
            maxThreads: ProcessInfo.processInfo.processorCount,
            supportsD3D11: true,
            supportsD3D12: true
        )
    }
    
    func getDetailedInfo() -> String? {
        guard let info = metalInfo else { return nil }
        
        return """
        Metal Device: \(info.deviceName)
        Architecture: \(info.architecture)
        Max Threads: \(info.maxThreads)
        D3D11 Support: \(info.supportsD3D11 ? "Yes" : "No")
        D3D12 Support: \(info.supportsD3D12 ? "Yes" : "No")
        """
    }
}
