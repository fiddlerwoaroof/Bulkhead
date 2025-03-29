//
//  DockerRawLogParser.swift
//  DockerUI
//
//  Created by Edward Langley on 3/28/25.
//

import Foundation

final class DockerRawLogParser {
  private var buffer: [UInt8] = []

  /// Appends data and returns complete log lines (as `[UInt8]`) for rendering.
  func append(data: Data) -> [[UInt8]] {
    var lines: [[UInt8]] = []

    for byte in data {
      if byte == 0x0A {  // LF = \n
        buffer.append(0x0D)  // optional CR = \r for SwiftTerm
        buffer.append(byte)  // optional CR = \r for SwiftTerm
        lines.append(buffer)
        buffer.removeAll()
      } else {
        buffer.append(byte)
      }
    }

    return lines
  }

  /// Call at the end to flush any incomplete final line.
  func flush() -> [[UInt8]] {
    guard !buffer.isEmpty else { return [] }
    let remaining = buffer
    buffer.removeAll()
    return [remaining]
  }
}
