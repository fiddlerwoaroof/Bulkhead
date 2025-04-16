import Foundation

struct DockerContainer: Identifiable, Codable, Hashable, Sendable {
  let id: String
  let names: [String]
  let image: String
  let status: String

  var title: String {
    names.first ?? id
  }

  // Optional detail fields
  var created: Date?
  var command: String?
  var ports: [PortBinding] = []
  var mounts: [MountInfo] = []
  var env: [String] = []
  var health: String?
  var state: ContainerState?

  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.id == rhs.id
  }
  func hash(into hasher: inout Hasher) {
    hasher.combine(id)  // Only hash the ID
  }

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
    }
    if lowercasedStatus.contains("paused") {
      return .paused
    }
    if lowercasedStatus.contains("restarting") {
      return .restarting
    }
    if lowercasedStatus.contains("removing") {
      return .removing
    }
    if lowercasedStatus.contains("dead") {
      return .dead
    }
    if lowercasedStatus.contains("created") {
      return .created
    }
    return .exited
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

  var title: String {
    RepoTags?.first ?? id
  }
}

struct ImageInspection: Codable {
  let Id: String
  let Parent: String?
  let RepoTags: [String]?
  let RepoDigests: [String]?
  let Created: String  // Docker returns ISO8601 format
  let Size: Int64
  let VirtualSize: Int64
  let Labels: [String: String]?
  let Config: ImageConfig

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

  var createdDate: Date? {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.date(from: Created)
  }
}

struct ImageConfig: Codable {
  let entrypoint: [String]?
  let cmd: [String]?
  let workingDir: String?
  let env: [String]?
  let labels: [String: String]?
  let volumes: [String: [String: String]]?
  let exposedPorts: [String: [String: String]]?
  let layers: [String]?

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

enum ContainerState: String, Codable {
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
