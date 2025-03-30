import Foundation
import SwiftUI
import Combine

class DockerManager: ObservableObject {
  @Published var containers: [DockerContainer] = []
  @Published var images: [DockerImage] = []
  @Published var socketPath: String =
    UserDefaults.standard.string(forKey: "dockerHostPath")
    ?? DockerEnvironmentDetector.detectDockerHostPath() ?? ""
  @Published var refreshInterval: Double =
    UserDefaults.standard.double(forKey: "refreshInterval") == 0
    ? 10 : UserDefaults.standard.double(forKey: "refreshInterval")

  var executor: DockerExecutor? {
    socketPath.isEmpty ? nil : DockerExecutor(socketPath: socketPath)
  }

  private var timer: Timer?
  private var enrichmentCache: [String: (container: DockerContainer, timestamp: Date)] = [:]
  private let enrichmentTTL: TimeInterval = 10

  init() {
    if socketPath.isEmpty, let detected = DockerEnvironmentDetector.detectDockerHostPath() {
      socketPath = detected
      saveDockerHostPath()
    }
    startAutoRefresh()
  }

  private func log(_ message: String, level: String = "INFO") {
    LogManager.shared.addLog(message, level: level, source: "docker-manager")
  }

  func fetchContainers() {
    tryCommand { [weak self] in
      guard let executor = self?.executor else { return }
      let list = try executor.listContainers()
      DispatchQueue.main.async { [weak self] in
        self?.containers = list
      }
    }
  }

  func enrichContainer(_ container: DockerContainer) async throws -> DockerContainer {
    guard let executor else { throw DockerError.noExecutor }

    let now = Date()
    if let cached = enrichmentCache[container.id],
      now.timeIntervalSince(cached.timestamp) < enrichmentTTL
    {
      return cached.container
    }

    let detailData = try executor.makeRequest(path: "/v1.41/containers/\(container.id)/json")
    var enriched = container
    try DockerContainer.enrich(from: detailData, into: &enriched)

    enrichmentCache[container.id] = (container: enriched, timestamp: now)
    return enriched
  }

  func clearEnrichmentCache() {
    enrichmentCache.removeAll()
  }

  func fetchImages() {
    tryCommand { [weak self] in
      guard let executor = self?.executor else { return }
      let list = try executor.listImages()
      DispatchQueue.main.async {
        self?.images = list
      }
    }
  }

  func startContainer(id: String) {
    tryCommand { [weak self] in
      try self?.executor?.startContainer(id: id)
    }
  }

  func stopContainer(id: String) {
    tryCommand {
      [weak self]
      in try self?.executor?.stopContainer(id: id)
    }
  }

  func inspectImage(id: String) async throws -> ImageInspection {
    guard let executor else { throw DockerError.noExecutor }
    return try executor.inspectImage(id: id)
  }

  private func tryCommand(_ block: @escaping () throws -> Void) {
    DispatchQueue.global().async { [weak self] in
      do {
        try block()
      } catch let dockerError as DockerError {
        // Log specific DockerError
        self?.log("DockerError in command: \(dockerError.localizedDescription)", level: "ERROR")
        // Note: We don't set a published error here, as this is for background commands.
        // Errors relevant to UI state should be handled where the command is initiated (e.g., in ViewModels).
      } catch {
        // Log other wrapped errors
        self?.log("Unknown error in command: \(error.localizedDescription)", level: "ERROR")
      }
    }
  }

  func saveDockerHostPath() {
    UserDefaults.standard.set(socketPath, forKey: "dockerHostPath")
  }

  func saveRefreshInterval() {
    UserDefaults.standard.set(refreshInterval, forKey: "refreshInterval")
    startAutoRefresh()
  }

  private func startAutoRefresh() {
    timer?.invalidate()
    timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) {
      [weak self] _ in
      self?.fetchContainers()
      self?.fetchImages()
    }
  }
}

// Note: DockerError and extension DockerContainer are kept in DockerExecutor.swift for now
// as they might be more closely related to the executor/model logic. 