import Foundation

public func debugPrintBytes(_ bytes: [UInt8], label: String = "DEBUG") {
  print("\(label): ", terminator: "")
  for byte in bytes {
    print(String(format: "%02x ", byte), terminator: "")
  }
  print()
}
