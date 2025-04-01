import Foundation
import OSLog
import os.log

func getDateFormatter() -> DateFormatter {
  let dateFormatter = DateFormatter()
  dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
  return dateFormatter
}

struct LogEntry: CustomStringConvertible {
  static let dateFormatter = getDateFormatter()
  var timestamp: String
  var message: String
  var level: String
  var source: String

  var description: String {
    "\(level)\t\(source)\t\(message)"
  }

  init(timestamp: Date, message: String, level: String = "INFO", source: String = "main") {
    self.timestamp = Self.dateFormatter.string(from: timestamp)
    self.message = message
    self.level = level
    self.source = source

  }
}

class LogManager: ObservableObject {
  //  static let shared = LogManager()
  private static let subsystem = Bundle.main.bundleIdentifier ?? "<no bundle>"
  private var loggers: [String: OSLog]
  private let loggersAccessQueue: DispatchQueue
  private let maxEntries = 1000  // Limit the number of log entries
  @Published var logs: [LogEntry]

  init() {
    self.loggers = [:]
    self.logs = []
    self.loggersAccessQueue = DispatchQueue(label: "com.yourapp.loggersAccessQueue")
  }

  func addLog(_ message: String, level: String = "INFO", source: String = "main") {
    let logEntry = LogEntry(timestamp: Date(), message: message, level: level, source: source)
    loggersAccessQueue.sync {  // Use sync for immediate access/update
      if let logger = self.loggers[source] {
        os_log("%@", log: logger, type: .info, logEntry.description)
      } else {
        let logger = OSLog(subsystem: Self.subsystem, category: source)
        loggers[source] = logger
        os_log("%@", log: logger, type: .info, logEntry.description)
      }
    }
    NSLog("%@", logEntry.description)

    var logs = self.logs

    if !Thread.isMainThread {
      logs.append(logEntry)
    } else {
      DispatchQueue.main.async {
        logs.append(logEntry)
      }
    }
  }
}
