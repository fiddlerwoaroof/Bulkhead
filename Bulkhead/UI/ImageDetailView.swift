import SwiftUI

struct ImageDetailView: View {
  let image: DockerImage
  @StateObject private var model = ImageDetailModel()
  @Environment(\.colorScheme) var colorScheme
  @Environment(\.isGlobalErrorShowing) private var isGlobalErrorShowing

  @EnvironmentObject var appEnv: ApplicationEnvironment
  var manager: DockerManager { appEnv.manager }

  private var connectionError: DockerError? {
    guard !isGlobalErrorShowing else { return nil }

    if let err = manager.imageListError, err.isConnectionError { return err }
    if case .socketReadError = manager.imageListError { return manager.imageListError }
    if case .socketWriteError = manager.imageListError { return manager.imageListError }
    if case .timeoutOccurred = manager.imageListError { return manager.imageListError }
    if case .noExecutor = manager.imageListError { return manager.imageListError }
    return nil
  }

  var body: some View {
    if let connError = connectionError {
      ErrorView(error: connError, title: "Connection Error")
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          // Header
          VStack(alignment: .leading, spacing: 4) {
            Text(image.RepoTags?.first ?? "Untagged")
              .font(.title)
              .fontWeight(.bold)
            Text(String(image.id.prefix(12)))
              .font(.subheadline)
              .foregroundColor(.secondary)
          }
          .padding(.bottom, 8)

          if model.isLoading {
            ProgressView("Loading image details...")
              .frame(maxWidth: .infinity, maxHeight: .infinity)
          } else if let error = model.error {
            ErrorView(error: error, title: "Failed to Load Image Details")
              .padding()
              .frame(maxWidth: .infinity, maxHeight: .infinity)
          } else {
            // Basic Info
            DetailSection(title: "Basic Information") {
              DetailRow(title: "ID", value: String(image.id.prefix(12)))
              DetailRow(title: "Size", value: model.formatSize(Int64(image.Size)))
              if let virtualSize = model.virtualSize {
                DetailRow(title: "Virtual Size", value: model.formatSize(virtualSize))
              }
              if let createdDate = model.createdDate {
                DetailRow(title: "Created", value: model.formatDate(createdDate))
              }
              if let parentId = model.parentId {
                DetailRow(title: "Parent", value: String(parentId.prefix(12)))
              }
              if let repoDigests = model.repoDigests, !repoDigests.isEmpty {
                DetailRow(title: "Repo Digests", value: repoDigests.joined(separator: "\n"))
              }
              if let tags = image.RepoTags, !tags.isEmpty {
                DetailRow(title: "Tags", value: tags.joined(separator: "\n"))
              }
            }

            // Labels
            if let labels = model.labels, !labels.isEmpty {
              DetailSection(title: "Labels") {
                ForEach(Array(labels.keys.sorted()), id: \.self) { key in
                  if let value = labels[key] {
                    DetailRow(title: key, value: value)
                  }
                }
              }
            }

            // Layers
            if !model.layers.isEmpty {
              DetailSection(title: "Layers") {
                ForEach(Array(model.layers.enumerated()), id: \.element) { index, layer in
                  DetailRow(title: "Layer \(index + 1)", value: String(layer.prefix(12)))
                }
              }
            }

            // Configuration
            if let config = model.config {
              DetailSection(title: "Configuration") {
                if let entrypoint = config.entrypoint {
                  DetailRow(title: "Entrypoint", value: entrypoint.joined(separator: " "))
                }
                if let cmd = config.cmd {
                  DetailRow(title: "Command", value: cmd.joined(separator: " "))
                }
                if let workingDir = config.workingDir {
                  DetailRow(title: "Working Directory", value: workingDir)
                }
                if let env = config.env, !env.isEmpty {
                  DetailRow(title: "Environment Variables", value: env.joined(separator: "\n"))
                }
                if let volumes = config.volumes {
                  DetailRow(title: "Volumes", value: volumes.keys.joined(separator: "\n"))
                }
                if let exposedPorts = config.exposedPorts {
                  DetailRow(
                    title: "Exposed Ports", value: exposedPorts.keys.joined(separator: "\n"))
                }
                if let configLabels = config.labels, !configLabels.isEmpty {
                  DetailRow(
                    title: "Config Labels",
                    value: configLabels.map { "\($0.key): \($0.value)" }.joined(separator: "\n"))
                }
              }
            }

            // Raw Inspection Data
            if let rawData = model.rawInspectionData {
              DetailSection(title: "Raw Inspection Data") {
                Text(rawData)
                  .font(.system(.body, design: .monospaced))
                  .foregroundColor(.secondary)
              }
            }
          }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .frame(maxWidth: .infinity)
      .background(
        colorScheme == .dark
          ? Color(red: 0.1, green: 0.1, blue: 0.1) : Color(red: 0.95, green: 0.95, blue: 0.95)
      )
      .task(id: image.id) {
        await model.loadImageDetails(id: image.id, using: manager)
      }
    }
  }
}

class ImageDetailModel: ObservableObject {
  @Published var parentId: String?
  @Published var layers: [String] = []
  @Published var config: ImageConfig?
  @Published var labels: [String: String]?
  @Published var repoDigests: [String]?
  @Published var rawInspectionData: String?
  @Published var isLoading = false
  @Published var error: DockerError?
  @Published var createdDate: Date?
  @Published var virtualSize: Int64?

  @EnvironmentObject var manager: DockerManager
  @EnvironmentObject var appEnv: ApplicationEnvironment

  func formatSize(_ size: Int64) -> String {
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
    formatter.countStyle = .file
    return formatter.string(fromByteCount: size)
  }

  func formatDate(_ date: Date) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .full
    return formatter.localizedString(for: date, relativeTo: Date())
  }

  @MainActor
  func loadImageDetails(id: String, using manager: DockerManager) async {
    // Reset state before loading new data
    resetState()

    isLoading = true
    error = nil

    do {
      let inspection = try await manager.inspectImage(id: id)
      print("Image inspection received: \(inspection)")
      parentId = inspection.Parent
      layers = inspection.Config.layers ?? []
      config = inspection.Config
      labels = inspection.Labels
      repoDigests = inspection.RepoDigests
      createdDate = inspection.createdDate
      virtualSize = inspection.VirtualSize

      // Format raw inspection data
      let inspectionDict: [String: Any] = [
        "Id": inspection.Id,
        "Parent": inspection.Parent as Any,
        "RepoTags": inspection.RepoTags as Any,
        "RepoDigests": inspection.RepoDigests as Any,
        "Created": inspection.Created,
        "Size": inspection.Size,
        "VirtualSize": inspection.VirtualSize,
        "Labels": inspection.Labels as Any,
        "Config": [
          "Entrypoint": inspection.Config.entrypoint as Any,
          "Cmd": inspection.Config.cmd as Any,
          "WorkingDir": inspection.Config.workingDir as Any,
          "Env": inspection.Config.env as Any,
          "Labels": inspection.Config.labels as Any,
          "Volumes": inspection.Config.volumes as Any,
          "ExposedPorts": inspection.Config.exposedPorts as Any,
          "Layers": inspection.Config.layers as Any,
        ],
      ]

      if let data = try? JSONSerialization.data(
        withJSONObject: inspectionDict, options: .prettyPrinted),
        let string = String(data: data, encoding: .utf8)
      {
        rawInspectionData = string
      }

      // Ensure error is cleared on success (redundant due to resetState/initial clear, but safe)
      self.error = nil

    } catch let dockerError as DockerError {
      // Store the specific DockerError
      self.error = dockerError
      appEnv.logManager.addLog(
        "DockerError loading image details: \(dockerError.localizedDescription)", level: "ERROR")
    } catch {
      // Wrap other errors
      self.error = .unknownError(error)
      appEnv.logManager.addLog(
        "Unknown error loading image details: \(error.localizedDescription)", level: "ERROR")
    }

    isLoading = false
  }

  private func resetState() {
    parentId = nil
    layers = []
    config = nil
    labels = nil
    repoDigests = nil
    rawInspectionData = nil
    createdDate = nil
    virtualSize = nil
    error = nil
  }
}

struct DetailSection<Content: View>: View {
  let title: String
  let content: Content

  init(title: String, @ViewBuilder content: () -> Content) {
    self.title = title
    self.content = content()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(title)
        .font(.headline)
        .foregroundColor(.secondary)
      content
    }
  }
}

struct DetailRow: View {
  let title: String
  let value: String

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title)
        .font(.subheadline)
        .foregroundColor(.secondary)
      Text(value)
        .font(.body)
    }
  }
}

extension ImageInspection {
  func asDictionary() -> [String: Any] {
    // Simplified example - needs actual implementation based on ImageInspection properties
    [
      "Id": Id,
      "Parent": Parent as Any,
      "RepoTags": RepoTags as Any,
      // ... include all other relevant properties ...
      "Config": Config.asDictionary(),
    ]
  }
}

extension ImageConfig {
  func asDictionary() -> [String: Any] {
    // Simplified example - needs actual implementation
    [
      "Entrypoint": entrypoint as Any,
      "Cmd": cmd as Any,
        // ... include all other relevant properties ...
    ]
  }
}
