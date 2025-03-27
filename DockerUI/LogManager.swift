import Foundation

struct LogEntry {
    var timestamp: String
    var message: String
    var level: String
    var source: String?

    // Initialize with a basic timestamp and message, optional level and source
    init(timestamp: String, message: String, level: String = "INFO", source: String? = nil) {
        self.timestamp = timestamp
        self.message = message
        self.level = level
        self.source = source
    }
}

class LogManager: ObservableObject {
    static let shared = LogManager()
    @Published var logs: [LogEntry] = []

    func addLog(_ message: String, level: String = "INFO", source: String? = nil) {
        let timestamp = self.getCurrentTimestamp()
        let logEntry = LogEntry(timestamp: timestamp, message: message, level: level, source: source)
        DispatchQueue.main.async {
            self.logs.append(logEntry)
        }
    }

    private func getCurrentTimestamp() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return dateFormatter.string(from: Date())
    }
}
