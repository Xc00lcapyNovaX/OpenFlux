import Foundation

class ProcessMonitor {
    private(set) var runningProcesses: [ProcessInfo] = []
    private let monitorQueue = DispatchQueue(label: "com.flux.monitor")
    
    struct ProcessInfo: Identifiable {
        let id = UUID()
        let pid: Int32
        let name: String
        let startTime: Date
        var cpuUsage: Double = 0
        var memoryUsage: UInt64 = 0
    }
    
    func startMonitoring(pid: Int32, gameName: String) -> ProcessInfo {
        let processInfo = ProcessInfo(
            pid: pid,
            name: gameName,
            startTime: Date()
        )
        
        monitorQueue.async { [weak self] in
            self?.runningProcesses.append(processInfo)
        }
        
        return processInfo
    }
    
    func stopMonitoring(pid: Int32) {
        monitorQueue.async { [weak self] in
            self?.runningProcesses.removeAll { $0.pid == pid }
        }
    }
    
    func getProcessStats(pid: Int32) -> (cpu: Double, memory: UInt64)? {
        // Would use Darwin APIs to get process statistics
        return nil
    }
    
    func isProcessRunning(pid: Int32) -> Bool {
        return kill(pid, 0) == 0
    }
    
    func terminateProcess(pid: Int32, force: Bool = false) -> Bool {
        let signal = force ? SIGKILL : SIGTERM
        return kill(pid, signal) == 0
    }
}
