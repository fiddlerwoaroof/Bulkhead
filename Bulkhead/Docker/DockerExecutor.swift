import Foundation
import Network
import SwiftUI  // For URL

struct DockerHTTPRequest {
  let path: String
  let method: String
  let body: Data?

  func rawData() -> Data {
    var request = "\(method) \(path) HTTP/1.1\r\n"
    request += "Host: docker\r\n"
    request += "User-Agent: Bulkhead/1.0\r\n"
    request += "Accept: */*\r\n"
    request += "Connection: close\r\n"
    request += "Content-Type: application/json\r\n"
    if let body {
      request += "Content-Length: \(body.count)\r\n"
    }
    request += "\r\n"

    var data = Data(request.utf8)
    if let body {
      data.append(body)
    }
    return data
  }
}

class SocketConnection {
  private static var crlfData = Data("\r\n".utf8)
  private static var crlf2Data = Data("\r\n\r\n".utf8)

  private let socket: Int32
  private let logManager: LogManager

  init(path: URL, logManager: LogManager) throws {
    self.logManager = logManager
    socket = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
    guard socket >= 0 else {
      let underlyingError = NSError(
        domain: NSPOSIXErrorDomain, code: Int(errno),
        userInfo: [
          NSLocalizedDescriptionKey: "Failed to create socket (\(errno)) for path \(path.path)"
        ])
      throw DockerError.connectionFailed(underlyingError)
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
      let underlyingError = NSError(
        domain: NSPOSIXErrorDomain, code: Int(errno),
        userInfo: [
          NSLocalizedDescriptionKey:
            "Failed to connect socket to \(path.path) (\(errno): \(String(cString: strerror(errno))))\""
        ])
      throw DockerError.connectionFailed(underlyingError)
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
    logManager.addLog(
      "Reading response from socket...", level: "DEBUG", source: "socket-connection")

    var buffer = [UInt8](repeating: 0, count: 4096)
    var response = Data()
    let startTime = Date()
    var readError: Error?

    while Date().timeIntervalSince(startTime) < timeout {
      let bytesRead = Darwin.recv(socket, &buffer, buffer.count, 0)

      if bytesRead > 0 {
        response.append(buffer, count: bytesRead)
      } else if bytesRead == 0 {
        logManager.addLog(
          "Connection closed by peer.", level: "DEBUG", source: "socket-connection")
        break
      } else {
        let currentErrno = errno
        if currentErrno == EWOULDBLOCK || currentErrno == EAGAIN {
          usleep(50_000)
          continue
        }
        readError = DockerError.socketReadError(
          NSError(domain: NSPOSIXErrorDomain, code: Int(currentErrno), userInfo: nil)
        )
        break
      }
    }

    if let error = readError {
      throw error
    }

    if Date().timeIntervalSince(startTime) >= timeout && !response.contains(Self.crlf2Data) {
      throw DockerError.timeoutOccurred
    }

    guard let headerEndRange = response.range(of: Self.crlf2Data) else {
      throw DockerError.invalidResponse(
        "Connection closed or data incomplete before receiving complete HTTP headers.")
    }

    logManager.addLog(
      "Received headers. Raw response size: \(response.count)", level: "DEBUG",
      source: "socket-connection")

    let headerData = response[..<headerEndRange.lowerBound]
    var bodyData = response[headerEndRange.upperBound...]

    guard let headerString = String(data: headerData, encoding: .utf8) else {
      throw DockerError.responseParsingFailed(
        NSError(
          domain: "SocketConnection", code: -2,
          userInfo: [NSLocalizedDescriptionKey: "Failed to decode headers as UTF-8"])
      )
    }

    let lines = headerString.components(separatedBy: "\r\n")
    guard !lines.isEmpty else {
      throw DockerError.invalidResponse("Received empty headers.")
    }
    let statusLine = lines.first!

    var headers: [String: String] = [:]
    for line in lines.dropFirst() {
      let parts = line.split(separator: ":", maxSplits: 1)
      if parts.count == 2 {
        headers[String(parts[0]).trimmingCharacters(in: .whitespaces)] = String(parts[1])
          .trimmingCharacters(in: .whitespaces)
      }
    }

    if headers["Transfer-Encoding"]?.lowercased() == "chunked" {
      logManager.addLog("Dechunking body...", level: "DEBUG", source: "socket-connection")
      bodyData = try dechunk(Data(bodyData))
    } else if let contentLengthStr = headers["Content-Length"],
      let contentLength = Int(contentLengthStr),
      bodyData.count < contentLength
    {
      logManager.addLog(
        "Content-Length (\(contentLength)) > received body (\(bodyData.count)). Need to read more.",
        level: "DEBUG", source: "socket-connection")
      throw DockerError.invalidResponse(
        "Incomplete body received (Content-Length mismatch). Additional read logic not implemented."
      )
    } else if let contentLengthStr = headers["Content-Length"],
      let contentLength = Int(contentLengthStr),
      bodyData.count > contentLength
    {
      logManager.addLog(
        "Received body (\(bodyData.count)) > Content-Length (\(contentLength)). Truncating.",
        level: "WARN", source: "socket-connection")
      bodyData = bodyData.prefix(contentLength)
    }

    logManager.addLog(
      "Final body size: \(bodyData.count)", level: "DEBUG", source: "socket-connection")
    return (statusLine, headers, Data(bodyData))
  }

  private func dechunk(_ data: Data) throws -> Data {
    var result = Data()
    var index = data.startIndex

    while index < data.endIndex {
      guard let crlfRange = data[index...].range(of: Self.crlfData) else { break }
      let sizeLine = data[index..<crlfRange.lowerBound]
      guard let sizeString = String(data: sizeLine, encoding: .utf8),
        let size = Int(sizeString, radix: 16)
      else { break }
      index = crlfRange.upperBound
      if size == 0 {
        if let endCRLF = data[index...].range(of: Self.crlfData) {
          index = endCRLF.upperBound
        }
        break
      }
      let chunkEnd = data.index(index, offsetBy: size, limitedBy: data.endIndex) ?? data.endIndex
      result.append(data[index..<chunkEnd])
      index = chunkEnd
      if let nextCRLF = data[index...].range(of: Self.crlfData) {
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
  let logManager: LogManager

  init(socketPath: String, logManager: LogManager) {
    self.logManager = logManager
    self.socketPath = socketPath
  }
  private func log(_ message: String, level: String) {
    logManager.addLog(message, level: level, source: "docker-executor")
  }

  func makeRequest(path: String, method: String = "GET", body: Data? = nil) throws -> Data {
    let socket = try SocketConnection(
      path: URL(fileURLWithPath: socketPath), logManager: logManager)
    let request = DockerHTTPRequest(path: path, method: method, body: body)
    let requestData = request.rawData()
    log("Request: \(String(data: requestData, encoding: .utf8) ?? "<invalid>")", level: "DEBUG")

    try socket.write(requestData)
    let (_, _, bodyData) = try socket.readResponse()

    return bodyData
  }

  func getContainerLogs(id: String, tail: Int = 100) throws -> Data {
    log("get logs for container \(id)", level: "INFO")
    let result = try makeRequest(
      path: "/v1.41/containers/\(id)/logs?stdout=true&stderr=true&tail=\(tail)&follow=false")

    let firstBytes = [UInt8](result.prefix(100))
    debugPrintBytes(firstBytes, label: "Initial Body")

    return result
  }

  func isTTYEnabled(forContainer id: String) throws -> Bool {
    let data = try makeRequest(path: "/v1.41/containers/\(id)/json")
    let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
    let config = json?["Config"] as? [String: Any]
    let tty = config?["Tty"] as? Bool
    return tty ?? false
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

  func inspectImage(id: String) throws -> ImageInspection {
    log("inspecting image \(id)", level: "INFO")
    let data = try makeRequest(path: "/v1.41/images/\(id)/json")
    print("Raw inspection data: \(String(data: data, encoding: .utf8) ?? "invalid")")
    let inspection = try JSONDecoder().decode(ImageInspection.self, from: data)
    print("Decoded inspection: \(inspection)")
    return inspection
  }

  func startContainer(id: String) throws {
    log("start container \(id)", level: "INFO")
    _ = try makeRequest(path: "/v1.41/containers/\(id)/start", method: "POST")
  }

  func stopContainer(id: String) throws {
    log("stop container \(id)", level: "INFO")
    _ = try makeRequest(path: "/v1.41/containers/\(id)/stop", method: "POST")
  }

  func exec(containerId: String, command: [String], addCarriageReturn: Bool = true) async throws
    -> Data
  {
    // Check container state first
    let containerData = try makeRequest(path: "/v1.41/containers/\(containerId)/json")
    let json = try JSONSerialization.jsonObject(with: containerData, options: []) as? [String: Any]
    guard let state = json?["State"] as? [String: Any],
      let running = state["Running"] as? Bool,
      running == true
    else {
      throw DockerError.containerNotRunning
    }

    // 1. Create exec instance
    let execCreateBody: [String: Any] = [
      "AttachStdout": true,
      "AttachStderr": true,
      "Tty": false,
      "Cmd": command,
    ]

    let createData = try JSONSerialization.data(withJSONObject: execCreateBody, options: [])

    let createExecResponse = try makeRequest(
      path: "/v1.41/containers/\(containerId)/exec",
      method: "POST",
      body: createData
    )

    let execCreateInfo = try JSONDecoder().decode([String: String].self, from: createExecResponse)
    guard let execId = execCreateInfo["Id"] else {
      throw DockerError.invalidResponse("Failed to get exec ID from response")
    }

    // 2. Start the exec session
    let startBody: [String: Any] = [
      "Detach": false,
      "Tty": false,
    ]

    let startData = try JSONSerialization.data(withJSONObject: startBody, options: [])

    let result = try makeRequest(
      path: "/v1.41/exec/\(execId)/start",
      method: "POST",
      body: startData
    )

    // 3. Process the multiplexed stream using DockerLogStreamParser
    let parser = DockerLogStreamParser(addCarriageReturn: addCarriageReturn)
    let lines = parser.append(data: result)
    let remainingLines = parser.flush()

    // Combine all stdout lines into a single output
    var output = Data()
    for line in lines + remainingLines where line.stream == .stdout {
      output.append(contentsOf: line.message)
    }

    // 4. Check the execution result
    let inspectResult = try makeRequest(path: "/v1.41/exec/\(execId)/json")
    let execInspectInfo = try JSONDecoder().decode(ExecInspectResponse.self, from: inspectResult)

    if execInspectInfo.exitCode != 0 {
      throw DockerError.execFailed(code: execInspectInfo.exitCode)
    }

    return output
  }

  private struct ExecInspectResponse: Codable {
    let exitCode: Int

    enum CodingKeys: String, CodingKey {
      case exitCode = "ExitCode"
    }
  }
}

enum DockerError: Error, LocalizedError, Equatable {
  // Core Errors
  case noExecutor  // DockerManager couldn't create an executor (likely invalid path)
  case containerNotRunning  // Attempted action on a non-running container

  // Connection Errors
  case connectionFailed(Error)  // Failed to connect to the Docker socket
  case socketReadError(Error)  // Error reading data from the socket
  case socketWriteError(Error)  // Error writing data to the socket
  case timeoutOccurred  // Operation timed out waiting for socket response

  // API & Response Errors
  case apiError(statusCode: Int, message: String)  // Docker API returned an error status code
  case invalidResponse(String)  // General invalid/unexpected response from API
  case responseParsingFailed(Error)  // Failed to decode JSON or parse response data

  // Execution Errors
  case execFailed(code: Int)  // `docker exec` command finished with a non-zero exit code

  // Generic / Unknown
  case unknownError(Error)  // For wrapping non-DockerError types

  // Helper to identify connection-related errors
  var isConnectionError: Bool {
    switch self {
    case .connectionFailed, .socketWriteError, .socketReadError, .timeoutOccurred, .noExecutor:
      return true
    default:
      return false
    }
  }

  // MARK: - LocalizedError Conformance

  var errorDescription: String? {
    switch self {
    case .noExecutor:
      return "Could not connect to Docker. The configured socket path may be invalid."
    case .containerNotRunning:
      return "The operation could not be completed because the container is not running."
    case .connectionFailed(let underlyingError):
      return "Failed to connect to the Docker socket: \(underlyingError.localizedDescription)"
    case .socketReadError(let underlyingError):
      return
        "An error occurred while reading from the Docker socket: \(underlyingError.localizedDescription)"
    case .socketWriteError(let underlyingError):
      return
        "An error occurred while writing to the Docker socket: \(underlyingError.localizedDescription)"
    case .timeoutOccurred:
      return "The operation timed out while waiting for a response from the Docker daemon."
    case .apiError(let statusCode, let message):
      return "Docker API Error (\(statusCode)): \(message)"
    case .invalidResponse(let details):
      return "Received an invalid or unexpected response from the Docker API: \(details)"
    case .responseParsingFailed(let underlyingError):
      return
        "Failed to parse the response from the Docker API: \(underlyingError.localizedDescription)"
    case .execFailed(let code):
      return "The command executed in the container failed with exit code \(code)."
    case .unknownError(let underlyingError):
      return "An unknown error occurred: \(underlyingError.localizedDescription)"
    }
  }

  var recoverySuggestion: String? {
    switch self {
    case .noExecutor, .connectionFailed:
      return
        "Please check the Docker socket path in Settings and ensure Docker"
        + " (or your Docker provider like Colima/Rancher Desktop) is running."
    case .containerNotRunning:
      return "Please start the container before attempting this operation."
    case .socketReadError, .socketWriteError, .timeoutOccurred, .apiError:
      return
        "Please ensure the Docker daemon is running and responsive. You may need to restart Docker."
    case .invalidResponse, .responseParsingFailed:
      return
        "An unexpected issue occurred while communicating with Docker. If the problem persists, please report it."
    case .execFailed:
      return "Check the command being executed and the container's logs for more details."
    case .unknownError:
      return "An unknown error occurred. Please check the underlying error for more details."
    }
  }

  // Equatable conformance
  static func == (lhs: Self, rhs: Self) -> Bool {
    switch (lhs, rhs) {
    // 1. Cases requiring specific associated value comparisons
    case (.apiError(let lhsCode, let lhsMsg), .apiError(let rhsCode, let rhsMsg)):
      return lhsCode == rhsCode && lhsMsg == rhsMsg
    case (.invalidResponse(let lhsDetails), .invalidResponse(let rhsDetails)):
      return lhsDetails == rhsDetails
    case (.execFailed(let lhsCode), .execFailed(let rhsCode)):
      return lhsCode == rhsCode

    // 2. Cases where matching case implies equality
    // (No associated value or associated Error is ignored for comparison)
    case (.noExecutor, .noExecutor),
      (.containerNotRunning, .containerNotRunning),
      (.connectionFailed, .connectionFailed),
      (.socketReadError, .socketReadError),
      (.socketWriteError, .socketWriteError),
      (.timeoutOccurred, .timeoutOccurred),
      (.responseParsingFailed, .responseParsingFailed),
      (.unknownError, .unknownError):
      return true

    // 3. If none of the above pairs match, the errors are not equal
    default:
      return false
    }
  }
}

extension DockerContainer {
  static func enrich(from jsonData: Data, container: DockerContainer) throws -> DockerContainer {
    let json = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any]
    let config = json?["Config"] as? [String: Any]
    let state = json?["State"] as? [String: Any]

    var result = container
    enrichBasicInfo(from: json, into: &result)
    enrichConfig(from: config, into: &result)
    enrichState(from: state, into: &result)
    enrichMounts(from: json, into: &result)
    enrichPorts(from: json, into: &result)
    return result
  }

  private static func enrichBasicInfo(
    from json: [String: Any]?, into container: inout DockerContainer
  ) {
    if let createdString = json?["Created"] as? String {
      container.created = ISO8601DateFormatter().date(from: createdString)
    }
  }

  private static func enrichConfig(
    from config: [String: Any]?, into container: inout DockerContainer
  ) {
    if let cmd = config?["Cmd"] as? [String] {
      container.command = cmd.joined(separator: " ")
    }

    if let env = config?["Env"] as? [String] {
      container.env = env
    }
  }

  private static func enrichState(from state: [String: Any]?, into container: inout DockerContainer)
  {
    if let health = state?["Health"] as? [String: Any],
      let status = health["Status"] as? String
    {
      container.health = status.capitalized
    }
  }

  private static func enrichMounts(from json: [String: Any]?, into container: inout DockerContainer)
  {
    if let mountsRaw = json?["Mounts"] as? [[String: Any]] {
      container.mounts = mountsRaw.compactMap { mount in
        guard let source = mount["Source"] as? String,
          let destination = mount["Destination"] as? String,
          let type = mount["Type"] as? String
        else {
          return nil
        }
        return MountInfo(source: source, destination: destination, type: type)
      }
    }
  }

  private static func enrichPorts(from json: [String: Any]?, into container: inout DockerContainer)
  {
    guard let networkSettings = json?["NetworkSettings"] as? [String: Any],
      let portsRaw = networkSettings["Ports"] as? [String: Any]
    else {
      return
    }

    for (key, value) in portsRaw {
      guard let bindings = value as? [[String: String]] else { continue }
      let parts = key.split(separator: "/")
      guard parts.count == 2,
        let containerPort = Int(parts[0])
      else { continue }

      let type = String(parts[1])
      for binding in bindings {
        let ip = binding["HostIp"]
        let publicPort = Int(binding["HostPort"] ?? "")
        container.ports.append(
          PortBinding(ip: ip, privatePort: containerPort, publicPort: publicPort, type: type)
        )
      }
    }
  }
}
