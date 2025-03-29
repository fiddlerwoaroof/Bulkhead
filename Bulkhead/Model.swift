import Foundation

struct DockerContainer: Identifiable, Codable, Hashable {
  let id: String
  let names: [String]
  let image: String
  let status: String

  // Optional detail fields
  var created: Date?
  var command: String?
  var ports: [PortBinding] = []
  var mounts: [MountInfo] = []
  var env: [String] = []
  var health: String?
  var state: ContainerState?

  enum CodingKeys: String, CodingKey {
    case id = "Id"
    case names = "Names"
    case image = "Image"
    case status = "Status"
  }

  var healthStatus: HealthStatus {
    if let health = health?.lowercased() {
      switch health {
      case "healthy": return .healthy
      case "unhealthy": return .unhealthy
      case "starting": return .starting
      case "none": return .none
      default: return .unknown
      }
    }
    return .none
  }

  var containerState: ContainerState {
    let lowercasedStatus = status.lowercased()
    if lowercasedStatus.contains("up") {
      return .running
    } else if lowercasedStatus.contains("paused") {
      return .paused
    } else if lowercasedStatus.contains("restarting") {
      return .restarting
    } else if lowercasedStatus.contains("removing") {
      return .removing
    } else if lowercasedStatus.contains("dead") {
      return .dead
    } else if lowercasedStatus.contains("created") {
      return .created
    } else {
      return .exited
    }
  }
}

struct PortBinding: Codable, Hashable {
  let ip: String?
  let privatePort: Int
  let publicPort: Int?
  let type: String

  enum CodingKeys: String, CodingKey {
    case ip = "IP"
    case privatePort = "PrivatePort"
    case publicPort = "PublicPort"
    case type = "Type"
  }
}

struct MountInfo: Codable, Hashable {
  let source: String
  let destination: String
  let type: String

  enum CodingKeys: String, CodingKey {
    case source = "Source"
    case destination = "Destination"
    case type = "Type"
  }
}

struct DockerImage: Identifiable, Codable, Hashable {
  var id: String { Id }
  let Id: String
  let RepoTags: [String]?
  let Created: Int
  let Size: Int
}

class DockerEnvironmentDetector {
  static func detectDockerHostPath() -> String? {
    let potentialPaths = [
      "\(NSHomeDirectory())/.rd/docker.sock",
      "\(NSHomeDirectory())/.colima/docker.sock",
    ]
    for path in potentialPaths where FileManager.default.fileExists(atPath: path) {
      return path
    }
    return nil
  }
}

enum ContainerState: String {
  case created
  case running
  case paused
  case restarting
  case removing
  case exited
  case dead
}

enum HealthStatus: String {
  case healthy
  case unhealthy
  case starting
  case none
  case unknown
}
