import Foundation
import SwiftUI
import Combine

class DockerManager: ObservableObject {
  @Published var containers: [DockerContainer] = []
  @Published var images: [DockerImage] = []
  @Published var containerListError: DockerError? // Error fetching containers
  @Published var imageListError: DockerError? // Error fetching images
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

  // Now async again to await the Task from tryCommand
  @MainActor 
  func fetchContainers() async {
    // Clear previous error on MainActor
    if containerListError != nil {
        containerListError = nil
    }

    // Get the task handle from tryCommand
    let fetchTask: Task<[DockerContainer], Error> = tryCommand {
        // This block runs in background via Task.detached inside tryCommand
        guard let executor = self.executor else { throw DockerError.noExecutor }
        let list = try executor.listContainers() // Assuming sync for now
        return list
    }

    // Await the task's result and handle errors on the MainActor
    do {
        let list = try await fetchTask.value // Await result, throws if task failed
        // Update state on MainActor (already here due to @MainActor func)
        self.containers = list
        self.containerListError = nil // Clear error on success
    } catch let dockerError as DockerError {
        // Handle specific DockerError
        self.containerListError = dockerError
        // Logging now happens inside tryCommand
    } catch {
        // Handle other errors
        self.containerListError = .unknownError(error)
        // Logging now happens inside tryCommand
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

  // Now async again to await the Task from tryCommand
  @MainActor
  func fetchImages() async {
    // Clear previous error on MainActor
    if imageListError != nil {
        imageListError = nil
    }

    // Get the task handle from tryCommand
    let fetchTask: Task<[DockerImage], Error> = tryCommand {
        // This block runs in background via Task.detached inside tryCommand
        guard let executor = self.executor else { throw DockerError.noExecutor }
        let list = try executor.listImages() // Assuming sync for now
        return list
    }

    // Await the task's result and handle errors on the MainActor
    do {
        let list = try await fetchTask.value // Await result, throws if task failed
        // Update state on MainActor
        self.images = list
        self.imageListError = nil // Clear error on success
    } catch let dockerError as DockerError {
        // Handle specific DockerError
        self.imageListError = dockerError
        // Logging now happens inside tryCommand
    } catch {
        // Handle other errors
        self.imageListError = .unknownError(error)
        // Logging now happens inside tryCommand
    }
  }

  // Make async to await task and handle errors
  @MainActor 
  func startContainer(id: String) async {
    let task: Task<Void, Error> = tryCommand { [weak self] in // Task returns Void
      guard let self = self, let executor = self.executor else { throw DockerError.noExecutor }
      try executor.startContainer(id: id)
    }
    
    // Await the task to ensure completion and catch errors
    do {
      _ = try await task.value // Throws if the task failed
      // Optionally trigger a refresh or UI update on success
      await self.fetchContainers() // Refresh list after action
    } catch {
      // Error is already logged by tryCommand
      // Optionally update some general status property here if needed
      log("Failed to start container \(id): \(error.localizedDescription)", level: "WARN")
    }
  }

  // Make async to await task and handle errors
  @MainActor 
  func stopContainer(id: String) async {
    let task: Task<Void, Error> = tryCommand { [weak self] in // Task returns Void
      guard let self = self, let executor = self.executor else { throw DockerError.noExecutor }
      try executor.stopContainer(id: id)
    }
    
    // Await the task to ensure completion and catch errors
    do {
      _ = try await task.value // Throws if the task failed
      // Optionally trigger a refresh or UI update on success
      await self.fetchContainers() // Refresh list after action
    } catch {
      // Error is already logged by tryCommand
      // Optionally update some general status property here if needed
      log("Failed to stop container \(id): \(error.localizedDescription)", level: "WARN")
    }
  }

  func inspectImage(id: String) async throws -> ImageInspection {
    guard let executor else { throw DockerError.noExecutor }
    return try executor.inspectImage(id: id)
  }

  // NOTE: any interaction with Docker MUST pass through this method so we can set policies generically
  // Updated to return Task handle (Alternative 1)
  private func tryCommand<T>(_ block: @escaping () async throws -> T) -> Task<T, Error> { 
    // Create and return the detached task
    return Task.detached { 
        // Log start (optional)
        LogManager.shared.addLog("Executing background command...", level: "DEBUG", source: "docker-manager")
        do {
            let result = try await block()
            // Log success (optional)
            LogManager.shared.addLog("Background command succeeded.", level: "DEBUG", source: "docker-manager")
            return result
        } catch {
            // Log error before task completes/throws
            LogManager.shared.addLog("Background command failed: \(error.localizedDescription)", level: "ERROR", source: "docker-manager")
            // Log specific DockerError details if possible
            if let dockerError = error as? DockerError {
                 LogManager.shared.addLog("--> DockerError Details: \(String(describing: dockerError))", level: "ERROR", source: "docker-manager")
            }
            throw error // Let the Task bubble up the error
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

  // Auto-refresh needs to call the async methods
  private func startAutoRefresh() {
    timer?.invalidate()
    timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
        Task { // Wrap async calls
            await self?.fetchContainers()
            await self?.fetchImages()
        }
    }
  }
}

// Note: DockerError and extension DockerContainer are kept in DockerExecutor.swift for now
// as they might be more closely related to the executor/model logic. 
