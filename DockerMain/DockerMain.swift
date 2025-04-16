//
//  DockerMain.swift
//  Bulkhead
//
//  Created by Edward Langley on 4/9/25.
//
import Foundation

@main
struct DockerMain {
  static func main() async throws {
    let logManager = LogManager()
    let publication = DockerPublication(logManager: logManager)
    let manager = DockerManager(logManager: logManager, publication: publication)
    
    let containers = await manager.fetchContainers()

    for container in containers {
      let enriched = try await manager.enrichContainer(container)
      print(container)
      print(enriched)
    }
  }
}
