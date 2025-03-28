import SwiftUI

struct DockerContainer: Identifiable, Codable, Hashable {
  let id: String
  let names: [String]
  let image: String
  let status: String

  enum CodingKeys: String, CodingKey {
    case id = "Id"
    case names = "Names"
    case image = "Image"
    case status = "Status"
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
