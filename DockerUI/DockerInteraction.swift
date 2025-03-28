import Foundation
import SwiftUI

struct DockerHTTPRequest {
  let path: String
  let method: String
  let body: Data?

  func rawData() -> Data {
    var request = "\(method) \(path) HTTP/1.1\r\n"
    request += "Host: docker\r\n"
    request += "User-Agent: DockerUI/1.0\r\n"
    request += "Accept: */*\r\n"
    request += "Connection: close\r\n"
    request += "Content-Type: application/json\r\n"
    if let body = body {
      request += "Content-Length: \(body.count)\r\n"
    }
    request += "\r\n"

    var data = Data(request.utf8)
    if let body = body {
      data.append(body)
    }
    return data
  }
}

class SocketConnection {
  private let socket: Int32

  init(path: URL) throws {
    socket = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
    guard socket >= 0 else {
      throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: nil)
    }

    var addr = sockaddr_un()
    addr.sun_family = sa_family_t(AF_UNIX)
    let socketPath = path.path
    _ = withUnsafeMutablePointer(to: &addr.sun_path) {
      $0.withMemoryRebound(to: CChar.self, capacity: 104) { ptr in
        strncpy(ptr, socketPath, 104)
      }
    }

    let size = socklen_t(MemoryLayout.size(ofValue: addr))
    let result = withUnsafePointer(to: &addr) {
      $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        Darwin.connect(socket, $0, size)
      }
    }

    guard result >= 0 else {
      close(socket)
      throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: nil)
    }
  }

  func write(_ data: Data) throws {
    let result = data.withUnsafeBytes {
      Darwin.send(socket, $0.baseAddress!, data.count, 0)
    }
    guard result >= 0 else {
      throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: nil)
    }
  }

  func readResponse(timeout: TimeInterval = 5.0) throws -> (
    statusLine: String, headers: [String: String], body: Data
  ) {
    LogManager.shared.addLog(
      "Reading response from socket...", level: "DEBUG", source: "socket-connection")

    var buffer = [UInt8](repeating: 0, count: 4096)
    var response = Data()
    let startTime = Date()

    while Date().timeIntervalSince(startTime) < timeout {
      let bytesRead = Darwin.recv(socket, &buffer, buffer.count, 0)
      if bytesRead > 0 {
        response.append(buffer, count: bytesRead)
      } else if bytesRead == 0 {
        break
      } else {
        if errno == EWOULDBLOCK || errno == EAGAIN {
          usleep(100_000)
          continue
        } else {
          throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: nil)
        }
      }
    }

    LogManager.shared.addLog(
      "Raw response data: \(String(data: response, encoding: .utf8) ?? "<binary>")", level: "DEBUG",
      source: "socket-connection")

    guard let headerEndRange = response.range(of: "\r\n\r\n".data(using: .utf8)!) else {
      throw NSError(
        domain: "SocketConnection", code: -1,
        userInfo: [NSLocalizedDescriptionKey: "Malformed HTTP response"])
    }

    let headerData = response[..<headerEndRange.lowerBound]
    var bodyData = response[headerEndRange.upperBound...]

    guard let headerString = String(data: headerData, encoding: .utf8) else {
      throw NSError(
        domain: "SocketConnection", code: -2,
        userInfo: [NSLocalizedDescriptionKey: "Failed to decode headers"])
    }

    let lines = headerString.components(separatedBy: "\r\n")
    let statusLine = lines.first ?? ""
    var headers: [String: String] = [:]
    for line in lines.dropFirst() {
      let parts = line.split(separator: ":", maxSplits: 1)
      if parts.count == 2 {
        headers[String(parts[0]).trimmingCharacters(in: .whitespaces)] = String(parts[1])
          .trimmingCharacters(in: .whitespaces)
      }
    }

    if headers["Transfer-Encoding"]?.lowercased() == "chunked" {
      bodyData = try dechunk(bodyData)
    }

    return (statusLine, headers, Data(bodyData))
  }

  private func dechunk(_ data: Data) throws -> Data {
    var result = Data()
    var index = data.startIndex

    while index < data.endIndex {
      guard let crlfRange = data[index...].range(of: "\r\n".data(using: .utf8)!) else { break }
      let sizeLine = data[index..<crlfRange.lowerBound]
      guard let sizeString = String(data: sizeLine, encoding: .utf8),
        let size = Int(sizeString, radix: 16)
      else { break }
      index = crlfRange.upperBound
      if size == 0 {
        if let endCRLF = data[index...].range(of: "\r\n".data(using: .utf8)!) {
          index = endCRLF.upperBound
        }
        break
      }
      let chunkEnd = data.index(index, offsetBy: size, limitedBy: data.endIndex) ?? data.endIndex
      result.append(data[index..<chunkEnd])
      index = chunkEnd
      if let nextCRLF = data[index...].range(of: "\r\n".data(using: .utf8)!) {
        index = nextCRLF.upperBound
      } else {
        break
      }
    }

    return result
  }

  deinit {
    close(socket)
  }
}

class DockerExecutor {
  let socketPath: String

  init(socketPath: String) {
    self.socketPath = socketPath
  }
  private func log(_ message: String, level: String) {
    LogManager.shared.addLog(message, level: level, source: "docker-executor")
  }

  func makeRequest(path: String, method: String = "GET", body: Data? = nil) throws -> Data {
    let socket = try SocketConnection(path: URL(fileURLWithPath: socketPath))
    let request = DockerHTTPRequest(path: path, method: method, body: body)
    let requestData = request.rawData()
    log("Request: \(String(data: requestData, encoding: .utf8) ?? "<invalid>")", level: "DEBUG")

    try socket.write(requestData)
    let (_, _, bodyData) = try socket.readResponse()

    return bodyData
  }

  func listContainers() throws -> [DockerContainer] {
    log("listing containers", level: "INFO")
    let data = try makeRequest(path: "/v1.41/containers/json?all=true")
    return try JSONDecoder().decode([DockerContainer].self, from: data)
  }

  func listImages() throws -> [DockerImage] {
    log("listing images", level: "INFO")
    let data = try makeRequest(path: "/v1.41/images/json")
    return try JSONDecoder().decode([DockerImage].self, from: data)
  }

  func startContainer(id: String) throws {
    log("start container \(id)", level: "INFO")
    _ = try makeRequest(path: "/v1.41/containers/\(id)/start", method: "POST")
  }

  func stopContainer(id: String) throws {
    log("stop container \(id)", level: "INFO")
    _ = try makeRequest(path: "/v1.41/containers/\(id)/stop", method: "POST")
  }

  func getContainerLogs(id: String, tail: Int = 100) throws -> Data {
    log("get logs for container \(id)", level: "INFO")
    return try makeRequest(
      path: "/v1.41/containers/\(id)/logs?stdout=true&stderr=false&tail=\(tail)&follow=false")
  }
}
