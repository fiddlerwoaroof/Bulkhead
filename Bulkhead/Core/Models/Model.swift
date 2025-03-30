import Foundation

public struct DockerContainer: Identifiable, Codable, Hashable {
  public let id: String
  public let names: [String]
  public let image: String
  public let status: String

  // Optional detail fields
  public var created: Date?
  public var command: String?
  public var ports: [PortBinding] = []
  public var mounts: [MountInfo] = []
  public var env: [String] = []
  public var health: String?
  public var state: ContainerState?

  enum CodingKeys: String, CodingKey {
    case id = "Id"
    case names = "Names"
    case image = "Image"
    case status = "Status"
  }

  public var healthStatus: HealthStatus {
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

  public var containerState: ContainerState {
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

public struct PortBinding: Codable, Hashable {
  public let ip: String?
  public let privatePort: Int
  public let publicPort: Int?
  public let type: String

  enum CodingKeys: String, CodingKey {
    case ip = "IP"
    case privatePort = "PrivatePort"
    case publicPort = "PublicPort"
    case type = "Type"
  }
}

public struct MountInfo: Codable, Hashable {
  public let source: String
  public let destination: String
  public let type: String

  enum CodingKeys: String, CodingKey {
    case source = "Source"
    case destination = "Destination"
    case type = "Type"
  }
}

public struct DockerImage: Identifiable, Codable, Hashable {
  public var id: String { Id }
  public let Id: String
  public let RepoTags: [String]?
  public let Created: Int
  public let Size: Int
}

public struct ImageInspection: Codable {
  public let Id: String
  public let Parent: String?
  public let RepoTags: [String]?
  public let RepoDigests: [String]?
  public let Created: String  // Docker returns ISO8601 format
  public let Size: Int64
  public let VirtualSize: Int64
  public let Labels: [String: String]?
  public let Config: ImageConfig

  enum CodingKeys: String, CodingKey {
    case Id
    case Parent
    case RepoTags
    case RepoDigests
    case Created
    case Size
    case VirtualSize
    case Labels
    case Config
  }

  public var createdDate: Date? {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.date(from: Created)
  }
}

public struct ImageConfig: Codable {
  public let entrypoint: [String]?
  public let cmd: [String]?
  public let workingDir: String?
  public let env: [String]?
  public let labels: [String: String]?
  public let volumes: [String: [String: String]]?
  public let exposedPorts: [String: [String: String]]?
  public let layers: [String]?

  enum CodingKeys: String, CodingKey {
    case entrypoint = "Entrypoint"
    case cmd = "Cmd"
    case workingDir = "WorkingDir"
    case env = "Env"
    case labels = "Labels"
    case volumes = "Volumes"
    case exposedPorts = "ExposedPorts"
    case layers = "Layers"
  }
}

public class DockerEnvironmentDetector {
  public static func detectDockerHostPath() -> String? {
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

public enum ContainerState: String {
  case created
  case running
  case paused
  case restarting
  case removing
  case exited
  case dead
}

public enum HealthStatus: String {
  case healthy
  case unhealthy
  case starting
  case none
  case unknown
}
