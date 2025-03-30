import Foundation

func getDateFormatter() -> DateFormatter {
  let dateFormatter = DateFormatter()
  dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
  return dateFormatter
}

public struct LogEntry: CustomStringConvertible {
  static let dateFormatter = getDateFormatter()
  public var timestamp: String
  public var message: String
  public var level: String
  public var source: String

  public var description: String {
    "\(level)\t\(source)\t\(message)"
  }

  public init(timestamp: Date, message: String, level: String = "INFO", source: String = "main") {
    self.timestamp = Self.dateFormatter.string(from: timestamp)
    self.message = message
    self.level = level
    self.source = source
  }
}
