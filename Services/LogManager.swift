import Foundation
import Combine

class LogManager: ObservableObject {
    static let shared = LogManager()
    
    @Published var logs: [LogEntry] = []
    @Published var currentLevel: LogLevel = .info
    
    private let maxLogEntries = 1000
    private let logQueue = DispatchQueue(label: "com.flux.logging", attributes: .concurrent)
    
    struct LogEntry: Identifiable {
        let id = UUID()
        let timestamp: Date
        let level: LogLevel
        let message: String
        let category: String
    }
    
    enum LogLevel: String, CaseIterable {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
    }
    
    func log(_ message: String, category: String = "General") {
        addEntry(message, level: .info, category: category)
    }
    
    func debug(_ message: String, category: String = "Debug") {
        addEntry(message, level: .debug, category: category)
    }
    
    func warning(_ message: String, category: String = "Warning") {
        addEntry(message, level: .warning, category: category)
    }
    
    func error(_ message: String, category: String = "Error") {
        addEntry(message, level: .error, category: category)
    }
    
    private func addEntry(_ message: String, level: LogLevel, category: String) {
        let entry = LogEntry(
            timestamp: Date(),
            level: level,
            message: message,
            category: category
        )
        
        logQueue.async(flags: .barrier) { [weak self] in
            DispatchQueue.main.async {
                self?.logs.append(entry)
                
                // Trim old logs if over limit
                if self?.logs.count ?? 0 > 1000 {
                    let excess = (self?.logs.count ?? 0) - 500
                    self?.logs.removeFirst(excess)
                }
            }
            
            // Also write to console for debugging
            let timestamp = ISO8601DateFormatter().string(from: entry.timestamp)
            print("[\(timestamp)] [\(level.rawValue)] [\(category)] \(message)")
        }
    }
    
    func clearLogs() {
        logQueue.async(flags: .barrier) { [weak self] in
            DispatchQueue.main.async {
                self?.logs.removeAll()
            }
        }
    }
    
    func exportLogs() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        
        return logs.map { entry in
            "[\(dateFormatter.string(from: entry.timestamp))] [\(entry.level.rawValue)] [\(entry.category)] \(entry.message)"
        }.joined(separator: "\n")
    }
    
    func getLogs(for level: LogLevel) -> [LogEntry] {
        return logs.filter { $0.level == level }
    }
}
