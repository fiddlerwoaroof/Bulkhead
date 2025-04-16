import Combine
import Foundation

class DockerPublication: ObservableObject {
  @Published var containers: [DockerContainer] = []
  @Published var images: [DockerImage] = []
  @Published var containerListError: DockerError?  // Error fetching containers
  @Published var imageListError: DockerError?  // Error fetching images
  @Published var socketPath: String
  @Published var refreshInterval: Double =
    UserDefaults.standard.double(forKey: "refreshInterval") == 0
    ? 10 : UserDefaults.standard.double(forKey: "refreshInterval")

  private let logManager: LogManager

  var executor: DockerExecutor? {
    socketPath.isEmpty
      ? nil : DockerExecutor(socketPath: socketPath, logManager: logManager)
  }

  init(logManager: LogManager) {
    self.socketPath =
      UserDefaults.standard.string(forKey: "dockerHostPath")
      ?? DockerEnvironmentDetector.detectDockerHostPath(logManager: logManager) ?? ""
    self.logManager = logManager
  }

  @MainActor
  func updateContainerList(_ list: [DockerContainer]) {
    self.containers = list
    self.containerListError = nil  // Clear error on success
    clearContainerListError()
  }

  @MainActor
  func updateImageList(_ list: [DockerImage]) {
    self.images = list
    clearImageListError()
  }

  // @MainActor
  // func updateSocketPath(_ new: String) {
  //  socketPath = new
  // }

  @MainActor
  func clearContainerListError() {
    containerListError = nil
  }
  @MainActor
  func setImageListError(_ value: DockerError) {
    imageListError = value
  }
  @MainActor
  func clearImageListError() {
    imageListError = nil
  }

  @MainActor
  func setError(_ error: DockerError) {
    containerListError = error
  }

  func saveDockerHostPath() {
    UserDefaults.standard.set(socketPath, forKey: "dockerHostPath")
  }

  func saveRefreshInterval() {
    UserDefaults.standard.set(refreshInterval, forKey: "refreshInterval")
  }
}

class DockerManager {
  let publication: DockerPublication
  private let logManager: LogManager
  private var timer: Timer?
  private var enrichmentCache: [String: (container: DockerContainer, timestamp: Date)] = [:]
  private let enrichmentTTL: TimeInterval = 10
  private let cacheQueue = DispatchQueue(label: "com.bulkhead.cacheQueue", attributes: .concurrent)

  init(logManager: LogManager, publication: DockerPublication) {
    self.logManager = logManager
    self.publication = publication

    // Set socket path synchronously if empty
    if publication.socketPath.isEmpty {
      if let detected = DockerEnvironmentDetector.detectDockerHostPath(logManager: logManager) {
        // Directly set the socket path since we're in initialization
        publication.socketPath = detected
        publication.saveDockerHostPath()
      }
    }

    startAutoRefresh()
  }

  private func log(_ message: String, level: String = "INFO") {
    logManager.addLog(message, level: level, source: "docker-manager")
  }

  func fetchContainers() async -> [DockerContainer] {
    // Clear previous error on MainActor
    await publication.clearContainerListError()

    // Get the task handle from tryCommand
    let fetchTask: Task<[DockerContainer], Error> = tryCommand { [weak self] in
      // This block runs in background via Task.detached inside tryCommand
      guard let executor = self?.publication.executor else { throw DockerError.noExecutor }
      return try executor.listContainers()  // Assuming sync for now
    }

    // Await the task's result and handle errors on the MainActor
    do {
      let list = try await fetchTask.value  // Await result, throws if task failed
      await publication.updateContainerList(list)
      return list
    } catch let dockerError as DockerError {
      // Handle specific DockerError
      await self.publication.setError(dockerError)
      // Logging now happens inside tryCommand
    } catch {
      // Handle other errors
      await self.publication.setError(.unknownError(error))
    }
    return []
  }

  func enrichContainer(_ container: DockerContainer) async throws -> DockerContainer {
    guard let executor = publication.executor else { throw DockerError.noExecutor }

    let now = Date()
    // Read operation - can happen concurrently with other reads
    let cached = cacheQueue.sync { enrichmentCache[container.id] }
    if let cached, now.timeIntervalSince(cached.timestamp) < enrichmentTTL {
      return cached.container
    }

    let detailData = try executor.makeRequest(path: "/v1.41/containers/\(container.id)/json")
    let enriched = try DockerContainer.enrich(from: detailData, container: container)

    // Write operation - uses barrier to ensure exclusive access
    cacheQueue.async(flags: .barrier) {
      self.enrichmentCache[container.id] = (container: enriched, timestamp: now)
    }

    return enriched
  }

  // func clearEnrichmentCache() {
  //  // Write operation with barrier
  //  cacheQueue.async(flags: .barrier) {
  //    self.enrichmentCache.removeAll()
  //  }
  // }

  // Now async again to await the Task from tryCommand
  func fetchImages() async -> [DockerImage] {
    await publication.clearImageListError()

    let fetchTask: Task<[DockerImage], Error> = tryCommand { [weak self] in
      guard let executor = self?.publication.executor else { throw DockerError.noExecutor }
      return try executor.listImages()  // Assuming sync for now
    }

    do {
      let list = try await fetchTask.value  // Await result, throws if task failed
      await publication.updateImageList(list)
      return list
    } catch let dockerError as DockerError {
      // Handle specific DockerError
      await self.publication.setImageListError(dockerError)
    } catch {
      // Handle other errors
      await self.publication.setImageListError(.unknownError(error))
    }
    return []
  }

  // Make async to await task and handle errors
  func startContainer(id: String) async {
    let task: Task<Void, Error> = tryCommand { [weak self] in  // Task returns Void
      guard let self, let executor = publication.executor else { throw DockerError.noExecutor }
      try executor.startContainer(id: id)
    }

    // Await the task to ensure completion and catch errors
    do {
      _ = try await task.value  // Throws if the task failed
      // Optionally trigger a refresh or UI update on success
      _ = await self.fetchContainers()  // Refresh list after action
    } catch {
      // Error is already logged by tryCommand
      // Optionally update some general status property here if needed
      log("Failed to start container \(id): \(error.localizedDescription)", level: "WARN")
    }
  }

  // Make async to await task and handle errors
  func stopContainer(id: String) async {
    let task: Task<Void, Error> = tryCommand { [weak self] in  // Task returns Void
      guard let self, let executor = publication.executor else { throw DockerError.noExecutor }
      try executor.stopContainer(id: id)
    }

    // Await the task to ensure completion and catch errors
    do {
      _ = try await task.value  // Throws if the task failed
      // Optionally trigger a refresh or UI update on success
      _ = await self.fetchContainers()  // Refresh list after action
    } catch {
      // Error is already logged by tryCommand
      // Optionally update some general status property here if needed
      log("Failed to stop container \(id): \(error.localizedDescription)", level: "WARN")
    }
  }

  func inspectImage(id: String) async throws -> ImageInspection {
    guard let executor = publication.executor else { throw DockerError.noExecutor }
    return try executor.inspectImage(id: id)
  }

  // NOTE: any interaction with Docker MUST pass through this method so we can set policies generically
  // Updated to return Task handle (Alternative 1)
  private func tryCommand<T>(_ block: @escaping () async throws -> T) -> Task<T, Error> {
    // Create and return the detached task
    let logManager = logManager
    return Task.detached {
      // Log start (optional)
      logManager.addLog(
        "Executing background command...", level: "DEBUG", source: "docker-manager")
      do {
        let result = try await block()
        // Log success (optional)
        logManager.addLog(
          "Background command succeeded.", level: "DEBUG", source: "docker-manager")
        return result
      } catch {
        // Log error before task completes/throws
        logManager.addLog(
          "Background command failed: \(error.localizedDescription)", level: "ERROR",
          source: "docker-manager")
        // Log specific DockerError details if possible
        if let dockerError = error as? DockerError {
          logManager.addLog(
            "--> DockerError Details: \(String(describing: dockerError))", level: "ERROR",
            source: "docker-manager")
        }
        throw error  // Let the Task bubble up the error
      }
    }
  }

  // Auto-refresh needs to call the async methods
  private func startAutoRefresh() {
    timer?.invalidate()
    timer = Timer.scheduledTimer(withTimeInterval: publication.refreshInterval, repeats: true) {
      [weak self] _ in
      Task {  // Wrap async calls
        _ = await self?.fetchContainers()
        _ = await self?.fetchImages()
      }
    }
  }

  func saveRefreshInterval() {
    publication.saveRefreshInterval()
  }

  func saveSocketPath() {
    publication.saveDockerHostPath()
  }
}

// Note: DockerError and extension DockerContainer are kept in DockerExecutor.swift for now
// as they might be more closely related to the executor/model logic.
