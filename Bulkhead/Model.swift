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

  enum CodingKeys: String, CodingKey {
    case id = "Id"
    case names = "Names"
    case image = "Image"
    case status = "Status"
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
