import Foundation

public enum DockerLogStreamType: UInt8 {
  public case stdout = 1
  public case stderr = 2
  public case unknown = 0
}

struct DockerLogStreamLine {
  var stream: DockerLogStreamType
  var message: [UInt8]
}

class DockerLogStreamParser {
  private var buffer: [UInt8] = []
  private var lines: [DockerLogStreamLine] = []
  private var lineBuffer: [UInt8] = []
  private let addCarriageReturn: Bool

  init(addCarriageReturn: Bool = true) {
    self.addCarriageReturn = addCarriageReturn
  }

  func append(data: [UInt8]) -> [DockerLogStreamLine] {
    buffer.append(contentsOf: data)
    return processBuffer()
  }

  func flush() -> [DockerLogStreamLine] {
    let remaining = processBuffer()
    buffer = []
    return remaining
  }

  private func processBuffer() -> [DockerLogStreamLine] {
    var processedLines: [DockerLogStreamLine] = []
    while buffer.count >= 8 {
      let header = Array(buffer[..<8])
      let streamType = DockerLogStreamType(rawValue: header[0]) ?? .unknown
      let length = UInt32(bigEndian: header[4...].withUnsafeBytes { $0.load(as: UInt32.self) })

      if buffer.count < 8 + Int(length) {
        break
      }

      let message = Array(buffer[8..<(8 + Int(length))])
      processedLines.append(DockerLogStreamLine(stream: streamType, message: message))
      buffer.removeFirst(8 + Int(length))
    }
    return processedLines
  }
}
