import Foundation
import os.log

public class LogManager: ObservableObject {
  public static let shared = LogManager()
  private static var subsystem = Bundle.main.bundleIdentifier!
  private var loggers: [String: OSLog]
  private let loggersAccessQueue: DispatchQueue
  @Published public var logs: [LogEntry]

  public init() {
    self.loggers = [:]
    self.logs = []
    self.loggersAccessQueue = DispatchQueue(label: "com.yourapp.loggersAccessQueue")
  }

  public func addLog(_ message: String, level: String = "INFO", source: String = "main") {
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
    DispatchQueue.main.async {
      self.logs.append(logEntry)
    }
  }
}
