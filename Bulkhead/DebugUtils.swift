func debugPrintBytes(_ bytes: [UInt8], label: String = "DEBUG") {
  let asString = String(bytes: bytes, encoding: .utf8) ?? "<invalid utf8>"
  let asHex = bytes.map { String(format: "%02x", $0) }.joined(separator: " ")
  print("[\(label)] UTF-8: \(asString)")
  print("[\(label)] HEX: \(asHex)")
}
