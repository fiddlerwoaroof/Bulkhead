import Foundation

enum DockerLogStreamType: UInt8 {
  case stdout = 1
  case stderr = 2
  case unknown = 0
}

struct DockerLogLine {
  let stream: DockerLogStreamType
  let message: [UInt8]  // still raw so it supports ANSI
}

final class DockerLogStreamParser {
  private var buffer = Data()
  private var lineBuffer: [UInt8] = []
  private let addCarriageReturn: Bool

  init(addCarriageReturn: Bool = true) {
    self.addCarriageReturn = addCarriageReturn
  }

  func append(data: Data) -> [DockerLogLine] {
    buffer.append(data)
    var parsedLines: [DockerLogLine] = []

    while buffer.count >= 8 {
      let streamTypeByte = buffer[0]
      let payloadLengthData = buffer[4..<8]
      let payloadLength = payloadLengthData.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }

      debugPrintBytes([UInt8](payloadLengthData))
      guard buffer.count >= 8 + Int(payloadLength) else { break }

      let payloadData = buffer.subdata(in: 8..<(8 + Int(payloadLength)))
      let stream = DockerLogStreamType(rawValue: streamTypeByte) ?? .unknown

      for byte in payloadData {
        if byte == 0x0A {  // newline (\n)
          if addCarriageReturn {
            lineBuffer.append(0x0d)
          }
          lineBuffer.append(byte)
          parsedLines.append(DockerLogLine(stream: stream, message: lineBuffer))
          lineBuffer.removeAll()
        } else {
          lineBuffer.append(byte)
        }
      }

      buffer.removeSubrange(0..<(8 + Int(payloadLength)))
    }

    return parsedLines
  }

  func flush() -> [DockerLogLine] {
    guard !lineBuffer.isEmpty else { return [] }
    let line = DockerLogLine(stream: .stdout, message: lineBuffer)
    lineBuffer.removeAll()
    return [line]
  }
}
