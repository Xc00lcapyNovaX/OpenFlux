import Foundation
import Darwin

/// SystemHealthMonitor - Singleton that tracks system resource usage
/// Monitors RAM, CPU, and disk I/O with configurable thresholds
/// Provides process termination when thresholds are exceeded
class SystemHealthMonitor: ObservableObject {
    
    // MARK: - Singleton
    static let shared = SystemHealthMonitor()
    
    // MARK: - Published State
    @Published private(set) var currentHealth: HealthSnapshot = HealthSnapshot()
    @Published private(set) var isMonitoring = false
    @Published private(set) var alerts: [HealthAlert] = []
    
    // MARK: - Configuration
    struct Thresholds {
        /// RAM usage threshold (0.0 - 1.0, e.g., 0.90 = 90%)
        var ramUsagePercent: Double = 0.90
        /// CPU usage threshold (0.0 - 1.0, e.g., 0.95 = 95%)
        var cpuUsagePercent: Double = 0.95
        /// Disk write rate threshold in MB/s
        var diskWriteMBPerSec: Double = 500.0
        /// Minimum available RAM in bytes before alert
        var minAvailableRAMBytes: UInt64 = 512 * 1024 * 1024  // 512 MB
    }
    
    var thresholds = Thresholds()
    
    // MARK: - Health Data Structures
    struct HealthSnapshot: Equatable {
        var timestamp: Date = Date()
        
        // RAM
        var totalRAMBytes: UInt64 = 0
        var usedRAMBytes: UInt64 = 0
        var availableRAMBytes: UInt64 = 0
        var ramUsagePercent: Double = 0.0
        
        // CPU
        var cpuUsagePercent: Double = 0.0
        var userCPUTime: Double = 0.0
        var systemCPUTime: Double = 0.0
        
        // Disk I/O
        var pageInsCount: UInt64 = 0
        var pageOutsCount: UInt64 = 0
        var diskWritesMB: Double = 0.0
        var diskWriteRate: Double = 0.0  // MB/s since last check
        
        var isHealthy: Bool {
            return ramUsagePercent < 0.95 && cpuUsagePercent < 0.98
        }
    }
    
    struct HealthAlert: Identifiable {
        let id = UUID()
        let timestamp: Date
        let type: AlertType
        let message: String
        let value: Double
        let threshold: Double
        
        enum AlertType: String {
            case ramCritical = "RAM Critical"
            case cpuCritical = "CPU Critical"
            case diskWriteHigh = "Disk Write High"
            case processTerminated = "Process Terminated"
        }
    }
    
    // MARK: - Private State
    private var monitorTimer: Timer?
    private let monitorQueue = DispatchQueue(label: "com.flux.healthmonitor", qos: .utility)
    private var lastSnapshot: HealthSnapshot?
    private var lastCPUInfo: host_cpu_load_info?
    private var lastPageOuts: UInt64 = 0
    private var lastCheckTime: Date?
    
    // MARK: - Initialization
    private init() {
        // Private init for singleton
    }
    
    // MARK: - Public API
    
    /// Start periodic health monitoring
    /// - Parameter interval: Check interval in seconds (default 5.0)
    func startMonitoring(interval: TimeInterval = 5.0) {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        lastCheckTime = Date()
        
        // Initial snapshot
        updateHealthSnapshot()
        
        // Schedule periodic checks on main run loop
        DispatchQueue.main.async { [weak self] in
            self?.monitorTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                self?.performHealthCheck()
            }
        }
        
        log("Health monitoring started (interval: \(interval)s)")
    }
    
    /// Stop periodic health monitoring
    func stopMonitoring() {
        monitorTimer?.invalidate()
        monitorTimer = nil
        isMonitoring = false
        log("Health monitoring stopped")
    }
    
    /// Perform a single health check (can be called manually)
    func performHealthCheck() {
        monitorQueue.async { [weak self] in
            self?.updateHealthSnapshot()
            self?.evaluateThresholds()
        }
    }
    
    /// Get current RAM usage
    func getRAMUsage() -> (total: UInt64, used: UInt64, available: UInt64, percent: Double) {
        let snapshot = captureRAMUsage()
        return (snapshot.totalRAMBytes, snapshot.usedRAMBytes, snapshot.availableRAMBytes, snapshot.ramUsagePercent)
    }
    
    /// Get current CPU usage
    func getCPUUsage() -> (user: Double, system: Double, total: Double) {
        let snapshot = captureCPUUsage()
        return (snapshot.userCPUTime, snapshot.systemCPUTime, snapshot.cpuUsagePercent)
    }
    
    /// Get disk I/O statistics
    func getDiskIOStats() -> (pageIns: UInt64, pageOuts: UInt64, writeMBPerSec: Double) {
        let snapshot = captureDiskIO()
        return (snapshot.pageInsCount, snapshot.pageOutsCount, snapshot.diskWriteRate)
    }
    
    /// Terminate a process if health thresholds are exceeded
    /// - Parameters:
    ///   - pid: Process ID to terminate
    ///   - force: Use SIGKILL instead of SIGTERM
    /// - Returns: True if termination signal was sent successfully
    @discardableResult
    func terminateProcessIfUnhealthy(pid: Int32, force: Bool = false) -> Bool {
        let health = currentHealth
        
        // Check if thresholds are exceeded
        let ramExceeded = health.ramUsagePercent > thresholds.ramUsagePercent ||
                          health.availableRAMBytes < thresholds.minAvailableRAMBytes
        let cpuExceeded = health.cpuUsagePercent > thresholds.cpuUsagePercent
        let diskExceeded = health.diskWriteRate > thresholds.diskWriteMBPerSec
        
        if ramExceeded || cpuExceeded || diskExceeded {
            return terminateProcess(pid: pid, force: force, reason: "Health threshold exceeded")
        }
        
        return false
    }
    
    /// Force terminate a process
    /// - Parameters:
    ///   - pid: Process ID to terminate
    ///   - force: Use SIGKILL instead of SIGTERM
    ///   - reason: Reason for termination (for logging)
    /// - Returns: True if termination signal was sent successfully
    @discardableResult
    func terminateProcess(pid: Int32, force: Bool = false, reason: String = "User requested") -> Bool {
        let signal = force ? SIGKILL : SIGTERM
        let result = kill(pid, signal)
        
        if result == 0 {
            let alert = HealthAlert(
                timestamp: Date(),
                type: .processTerminated,
                message: "Process \(pid) terminated: \(reason)",
                value: Double(pid),
                threshold: 0
            )
            addAlert(alert)
            log("Terminated process \(pid) (\(force ? "SIGKILL" : "SIGTERM")): \(reason)")
            return true
        } else {
            log("Failed to terminate process \(pid): errno \(errno)")
            return false
        }
    }
    
    /// Clear all alerts
    func clearAlerts() {
        DispatchQueue.main.async { [weak self] in
            self?.alerts.removeAll()
        }
    }
    
    // MARK: - Private Implementation
    
    private func updateHealthSnapshot() {
        var snapshot = HealthSnapshot()
        snapshot.timestamp = Date()
        
        // Capture RAM
        let ram = captureRAMUsage()
        snapshot.totalRAMBytes = ram.totalRAMBytes
        snapshot.usedRAMBytes = ram.usedRAMBytes
        snapshot.availableRAMBytes = ram.availableRAMBytes
        snapshot.ramUsagePercent = ram.ramUsagePercent
        
        // Capture CPU
        let cpu = captureCPUUsage()
        snapshot.cpuUsagePercent = cpu.cpuUsagePercent
        snapshot.userCPUTime = cpu.userCPUTime
        snapshot.systemCPUTime = cpu.systemCPUTime
        
        // Capture Disk I/O
        let disk = captureDiskIO()
        snapshot.pageInsCount = disk.pageInsCount
        snapshot.pageOutsCount = disk.pageOutsCount
        snapshot.diskWritesMB = disk.diskWritesMB
        snapshot.diskWriteRate = disk.diskWriteRate
        
        lastSnapshot = currentHealth
        lastCheckTime = Date()
        
        DispatchQueue.main.async { [weak self] in
            self?.currentHealth = snapshot
        }
    }
    
    private func captureRAMUsage() -> HealthSnapshot {
        var snapshot = HealthSnapshot()
        
        // Get total physical memory
        var size = MemoryLayout<UInt64>.size
        var totalMemory: UInt64 = 0
        sysctlbyname("hw.memsize", &totalMemory, &size, nil, 0)
        snapshot.totalRAMBytes = totalMemory
        
        // Get memory usage via host_statistics64 (works on all macOS versions)
        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        
        let result = withUnsafeMutablePointer(to: &vmStats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, intPtr, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            let pageSize = UInt64(vm_page_size)
            
            // Calculate used memory (wired + active + inactive + compressed)
            let wired = UInt64(vmStats.wire_count) * pageSize
            let active = UInt64(vmStats.active_count) * pageSize
            let compressed = UInt64(vmStats.compressor_page_count) * pageSize
            
            // Free memory = free_count + speculative
            let free = UInt64(vmStats.free_count) * pageSize
            let speculative = UInt64(vmStats.speculative_count) * pageSize
            
            snapshot.availableRAMBytes = free + speculative
            snapshot.usedRAMBytes = wired + active + compressed
            
            // Calculate percentage
            if totalMemory > 0 {
                snapshot.ramUsagePercent = Double(snapshot.usedRAMBytes) / Double(totalMemory)
            }
        }
        
        return snapshot
    }
    
    private func captureCPUUsage() -> HealthSnapshot {
        var snapshot = HealthSnapshot()
        
        // Method 1: getrusage for self process
        var usage = rusage()
        if getrusage(RUSAGE_SELF, &usage) == 0 {
            snapshot.userCPUTime = Double(usage.ru_utime.tv_sec) + Double(usage.ru_utime.tv_usec) / 1_000_000.0
            snapshot.systemCPUTime = Double(usage.ru_stime.tv_sec) + Double(usage.ru_stime.tv_usec) / 1_000_000.0
        }
        
        // Method 2: host_processor_info for system-wide CPU
        var cpuInfo: host_cpu_load_info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
        
        let result = withUnsafeMutablePointer(to: &cpuInfo) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, intPtr, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            let user = Double(cpuInfo.cpu_ticks.0)    // CPU_STATE_USER
            let system = Double(cpuInfo.cpu_ticks.1)  // CPU_STATE_SYSTEM
            let idle = Double(cpuInfo.cpu_ticks.2)    // CPU_STATE_IDLE
            let nice = Double(cpuInfo.cpu_ticks.3)    // CPU_STATE_NICE
            
            if let lastInfo = lastCPUInfo {
                let userDiff = user - Double(lastInfo.cpu_ticks.0)
                let systemDiff = system - Double(lastInfo.cpu_ticks.1)
                let idleDiff = idle - Double(lastInfo.cpu_ticks.2)
                let niceDiff = nice - Double(lastInfo.cpu_ticks.3)
                
                let totalDiff = userDiff + systemDiff + idleDiff + niceDiff
                if totalDiff > 0 {
                    snapshot.cpuUsagePercent = (userDiff + systemDiff + niceDiff) / totalDiff
                }
            }
            
            lastCPUInfo = cpuInfo
        }
        
        return snapshot
    }
    
    private func captureDiskIO() -> HealthSnapshot {
        var snapshot = HealthSnapshot()
        
        // Use vm_statistics64 to get page-out information (disk writes)
        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        
        let result = withUnsafeMutablePointer(to: &vmStats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, intPtr, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            snapshot.pageInsCount = UInt64(vmStats.pageins)
            snapshot.pageOutsCount = UInt64(vmStats.pageouts)
            
            // Get page size
            let pageSize = UInt64(vm_page_size)
            
            // Calculate disk writes in MB
            snapshot.diskWritesMB = Double(snapshot.pageOutsCount * pageSize) / (1024 * 1024)
            
            // Calculate write rate since last check
            if let lastCheck = lastCheckTime, lastPageOuts > 0 {
                let elapsed = Date().timeIntervalSince(lastCheck)
                if elapsed > 0 {
                    let pageOutsDiff = snapshot.pageOutsCount > lastPageOuts ? snapshot.pageOutsCount - lastPageOuts : 0
                    let bytesDiff = Double(pageOutsDiff * pageSize)
                    snapshot.diskWriteRate = (bytesDiff / (1024 * 1024)) / elapsed  // MB/s
                }
            }
            
            lastPageOuts = snapshot.pageOutsCount
        }
        
        return snapshot
    }
    
    private func evaluateThresholds() {
        let health = currentHealth
        
        // Check RAM threshold
        if health.ramUsagePercent > thresholds.ramUsagePercent ||
           health.availableRAMBytes < thresholds.minAvailableRAMBytes {
            let alert = HealthAlert(
                timestamp: Date(),
                type: .ramCritical,
                message: "RAM usage critical: \(String(format: "%.1f", health.ramUsagePercent * 100))%",
                value: health.ramUsagePercent * 100,
                threshold: thresholds.ramUsagePercent * 100
            )
            addAlert(alert)
        }
        
        // Check CPU threshold
        if health.cpuUsagePercent > thresholds.cpuUsagePercent {
            let alert = HealthAlert(
                timestamp: Date(),
                type: .cpuCritical,
                message: "CPU usage critical: \(String(format: "%.1f", health.cpuUsagePercent * 100))%",
                value: health.cpuUsagePercent * 100,
                threshold: thresholds.cpuUsagePercent * 100
            )
            addAlert(alert)
        }
        
        // Check disk write threshold
        if health.diskWriteRate > thresholds.diskWriteMBPerSec {
            let alert = HealthAlert(
                timestamp: Date(),
                type: .diskWriteHigh,
                message: "Disk write rate high: \(String(format: "%.1f", health.diskWriteRate)) MB/s",
                value: health.diskWriteRate,
                threshold: thresholds.diskWriteMBPerSec
            )
            addAlert(alert)
        }
    }
    
    private func addAlert(_ alert: HealthAlert) {
        DispatchQueue.main.async { [weak self] in
            self?.alerts.append(alert)
            // Keep only last 50 alerts
            if let count = self?.alerts.count, count > 50 {
                self?.alerts.removeFirst(count - 50)
            }
        }
        log("Health Alert: \(alert.type.rawValue) - \(alert.message)")
    }
    
    private func log(_ message: String) {
        // Use AppState logging if available, otherwise print
        DispatchQueue.main.async {
            AppState.shared.log("[HealthMonitor] \(message)", category: .engine)
        }
    }
}

// MARK: - Convenience Extensions

extension SystemHealthMonitor.HealthSnapshot {
    /// Formatted RAM usage string
    var formattedRAMUsage: String {
        let usedGB = Double(usedRAMBytes) / (1024 * 1024 * 1024)
        let totalGB = Double(totalRAMBytes) / (1024 * 1024 * 1024)
        return String(format: "%.1f / %.1f GB (%.0f%%)", usedGB, totalGB, ramUsagePercent * 100)
    }
    
    /// Formatted CPU usage string
    var formattedCPUUsage: String {
        return String(format: "%.1f%%", cpuUsagePercent * 100)
    }
    
    /// Formatted disk write rate string
    var formattedDiskWriteRate: String {
        return String(format: "%.1f MB/s", diskWriteRate)
    }
}
