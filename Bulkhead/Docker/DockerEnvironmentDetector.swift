import Foundation

/// Detects the Docker environment and socket path
enum DockerEnvironmentDetector {
  /// Common Docker socket locations on macOS
  private static let socketLocations = [
    // Docker Desktop
    "/var/run/docker.sock",
    // Colima
    "\(FileManager.default.homeDirectoryForCurrentUser.path)/.colima/docker.sock",
    // Rancher Desktop
    "\(FileManager.default.homeDirectoryForCurrentUser.path)/.rd/docker.sock",
  ]

  /// Detects the Docker socket path by checking common locations
  /// Returns the first valid socket path found, or nil if none are available
  static func detectDockerHostPath() -> String? {
    for path in socketLocations where isSocketAccessible(path) {
      LogManager.shared.addLog(
        "Found accessible Docker socket at: \(path)", level: "DEBUG",
        source: "docker-environment-detector")
      return path
    }

    LogManager.shared.addLog(
      "No accessible Docker socket found in common locations", level: "ERROR",
      source: "docker-environment-detector")
    return nil
  }

  /// Returns a user-friendly description of the Docker environment
  static func getEnvironmentDescription() -> String {
    if let path = detectDockerHostPath() {
      if path.contains("colima") {
        return "Colima"
      }
      if path.contains(".rd") {
        return "Rancher Desktop"
      }
      if path == "/var/run/docker.sock" {
        return "Docker Desktop"
      }
    }
    return "Unknown"
  }

  /// Checks if a socket file exists and is accessible
  private static func isSocketAccessible(_ path: String) -> Bool {
    let fileManager = FileManager.default

    // First check if the file exists
    guard fileManager.fileExists(atPath: path) else {
      LogManager.shared.addLog(
        "Socket file does not exist at: \(path)", level: "ERROR",
        source: "docker-environment-detector")
      return false
    }

    // Check if it's a socket file
    var isDirectory: ObjCBool = false
    guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory),
      !isDirectory.boolValue
    else {
      LogManager.shared.addLog("Path exists but is not a file: \(path)")
      return false
    }

    // Try to open the socket to verify it's accessible
    do {
      let socket = try FileHandle(forReadingFrom: URL(fileURLWithPath: path))
      try socket.close()
      return true
    } catch {
      LogManager.shared.addLog(
        "Socket exists but is not accessible at \(path): \(error.localizedDescription)")
      return false
    }
  }
}
