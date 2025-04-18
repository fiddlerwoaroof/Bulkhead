import SwiftUI

extension ContainerState {
  fileprivate var color: Color {
    switch self {
    case .running: return .green
    case .paused: return .orange
    case .restarting: return .blue
    case .removing: return .red
    case .dead: return .red
    case .created: return .secondary
    case .exited: return .secondary
    }
  }

  fileprivate var icon: String {
    switch self {
    case .running: return "play.circle.fill"
    case .paused: return "pause.circle.fill"
    case .restarting: return "arrow.triangle.2.circlepath.circle.fill"
    case .removing: return "xmark.circle.fill"
    case .dead: return "exclamationmark.triangle.fill"
    case .created: return "circle.fill"
    case .exited: return "stop.circle.fill"
    }
  }

  fileprivate var label: String {
    rawValue.capitalized
  }
}

struct ContainerDetailViewInner: View {
  @EnvironmentObject var publication: DockerPublication
  private let appEnv: ApplicationEnvironment
  @ObservedObject var logManager: LogManager
  @StateObject private var model: ContainerDetailModel
  let container: DockerContainer
  @State private var selectedPath: String?

  @Environment(\.isGlobalErrorShowing) private var isGlobalErrorShowing

  private var manager: DockerManager { appEnv.manager }

  // Determine if there's a *local* model loading error
  private var localError: DockerError? {
    if let error = model.error { return error }
    return nil
  }

  // Determine if there's a *relevant* connection error from the manager
  private var connectionError: DockerError? {
    // Ignore connection errors if a global one is already showing
    guard !isGlobalErrorShowing else { return nil }

    if let err = publication.containerListError, err.isConnectionError { return err }
    return nil  // No relevant connection error
  }

  init(appEnv: ApplicationEnvironment, container: DockerContainer, logManager: LogManager) {
    self.appEnv = appEnv
    self.container = container
    self.logManager = logManager
    _model = StateObject(wrappedValue: ContainerDetailModel(appEnv: appEnv, logManager: logManager))
  }

  var body: some View {
    // Check for global connection error first (or if we should ignore local one)
    if let connError = connectionError {
      ErrorView(error: connError, title: "Connection Error")
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else {
      // Original content if no connection error
      VSplitView {
        ScrollView {
          VStack(alignment: .leading, spacing: 8) {
            if model.isLoading {
              ProgressView("Loading container details...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else if let error = localError {  // Local model error (e.g., enrich failed)
              ErrorView(error: error, title: "Failed to Load Details")
                .padding()
            } else if let base = model.base {  // Use base container as fallback
              detailContent(base, enriched: model.enriched)
            } else {
              // Should not happen if base is always set, but provides fallback
              Text("Select a container.").foregroundColor(.secondary)
            }
          }
          .padding()
          .frame(maxWidth: .infinity, alignment: .topLeading)
        }

        FilesystemBrowserView(
          container: container, appEnv: appEnv, initialPath: selectedPath ?? "/"
        )
        .frame(minHeight: 200)
      }
      .padding()
      .task(id: container.id) {
        await model.load(for: container, using: manager)
      }
    }
  }

  @ViewBuilder
  private func detailContent(_ container: DockerContainer, enriched: DockerContainer?) -> some View
  {
    ScrollView {
      VStack(alignment: .leading, spacing: 8) {
        Group {
          HStack(spacing: 8) {
            Text(container.names.first ?? "<unnamed>")
              .font(.headline)
            Spacer()
            statusBadge(container, enriched: enriched)
          }
          detailRow("Image", container.image)
          detailRow("Status", container.status)

          if let created = enriched?.created {
            detailRow("Created", created.formatted(date: .abbreviated, time: .shortened))
          }

          if let command = enriched?.command {
            detailRow("Command", command)
          }

          if let env = enriched?.env {
            environmentSection(env)
          }

          if let ports = enriched?.ports, !ports.isEmpty {
            sectionHeader("Ports")
            ForEach(ports, id: \.self) { port in
              detailRow(
                "\(port.privatePort)/\(port.type)",
                "\(port.ip ?? "0.0.0.0"):\(port.publicPort ?? 0)"
              )
            }
          }

          if let mounts = enriched?.mounts, !mounts.isEmpty {
            sectionHeader("Mounts")
            ForEach(mounts, id: \.source) { mount in
              detailRow(mount.source, mount.destination)
            }
          }
        }
      }
      .padding()
    }
  }

  private func statusBadge(_ container: DockerContainer, enriched: DockerContainer?) -> some View {
    let state = container.containerState
    let health = enriched?.healthStatus ?? .none

    let (icon, label, color) = statusInfo(state: state, health: health)

    return HStack(spacing: 4) {
      Image(systemName: icon)
        .foregroundStyle(color)
      Text(label)
        .font(.caption)
        .foregroundStyle(color)
    }
    .padding(.horizontal, 6)
    .padding(.vertical, 2)
    .background(color.opacity(0.15))
    .clipShape(RoundedRectangle(cornerRadius: 4))
  }

  private func statusInfo(state: ContainerState, health: HealthStatus) -> (
    icon: String, label: String, color: Color
  ) {
    // If container is not running, show container state
    guard state == .running else {
      return (state.icon, state.label, state.color)
    }

    // If container is running, prefer health status if available
    switch health {
    case .healthy:
      return ("checkmark.circle.fill", "Healthy", .green)
    case .unhealthy:
      return ("xmark.circle.fill", "Unhealthy", .red)
    case .starting:
      return ("arrow.triangle.2.circlepath.circle.fill", "Starting", .orange)
    case .none:
      return ("play.circle.fill", "Running", .green)
    case .unknown:
      return ("questionmark.circle.fill", "Unknown", .secondary)
    }
  }

  @ViewBuilder
  private func detailRow(_ label: String, _ value: String) -> some View {
    HStack(alignment: .firstTextBaseline) {
      Text("\(label):")
        .fontWeight(.semibold)
        .frame(width: 80, alignment: .leading)
      Text(value)
        .font(.system(.body, design: .monospaced))
    }
  }

  @ViewBuilder
  private func envDetailRow(_ label: String, _ value: String) -> some View {
    HStack(alignment: .firstTextBaseline) {
      Text("\(label):")
        .fontWeight(.semibold)
        .frame(width: 200, alignment: .leading)
      Text(value)
        .font(.system(.body, design: .monospaced))
    }
  }

  @ViewBuilder
  private func environmentSection(_ env: [String]) -> some View {
    sectionHeader("Environment")
    ForEach(env.sorted(), id: \.self) { envVar in
      if let separatorIndex = envVar.firstIndex(of: "=") {
        let key = String(envVar[..<separatorIndex])
        let value = String(envVar[envVar.index(after: separatorIndex)...])
        if key.hasSuffix("PATH") {
          envRow(key) {
            VStack(alignment: .leading) {
              let pathComponents = value.split(separator: ":").map(String.init)
              ForEach(pathComponents.indices, id: \.self) { index in
                let path = pathComponents[index]
                Button(action: {
                  selectedPath = path
                }) {
                  Text(path)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.blue)
                }
                .buttonStyle(.link)
                .onHover { isHovering in
                  if isHovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }
              }
            }
          }
        } else {
          envDetailRow(key, value)

        }
      } else {
        envDetailRow("", envVar)
      }
    }
  }

  @ViewBuilder
  private func envRow(_ label: String, @ViewBuilder value: () -> some View) -> some View {
    HStack(alignment: .firstTextBaseline) {
      Text("\(label):")
        .fontWeight(.semibold)
        .frame(width: 200, alignment: .leading)
      value()
    }
  }

  @ViewBuilder
  private func sectionHeader(_ title: String) -> some View {
    Text(title)
      .font(.headline)
      .padding(.top, 12)
  }
}

struct ContainerDetailView: View {
  let container: DockerContainer
  let appEnv: ApplicationEnvironment
  @EnvironmentObject var logManager: LogManager

  var body: some View {
    ContainerDetailViewInner(appEnv: appEnv, container: container, logManager: logManager)
  }
}

@MainActor
final class ContainerDetailModel: ObservableObject {
  @Published var enriched: DockerContainer?
  @Published var isLoading = false
  @Published var error: DockerError?
  @Published var sortedEnvironmentVariables: [(key: String, value: String)] = []

  let appEnv: ApplicationEnvironment
  var logManager: LogManager

  init(appEnv: ApplicationEnvironment, logManager: LogManager) {
    self.appEnv = appEnv
    self.logManager = logManager
  }

  var base: DockerContainer?

  func load(for container: DockerContainer, using manager: DockerManager) async {
    base = container
    enriched = nil
    error = nil
    isLoading = true

    do {
      let result = try await manager.enrichContainer(container)
      self.enriched = result
      self.error = nil
      self.processEnvironmentVariables(result.env)
    } catch let dockerError as DockerError {
      self.error = dockerError
      logManager.addLog(
        "DockerError loading container details: \(dockerError.localizedDescription)", level: "ERROR"
      )
    } catch {
      self.error = .unknownError(error)
      logManager.addLog(
        "Unknown error loading container details: \(error.localizedDescription)", level: "ERROR")
    }

    isLoading = false
  }

  private func processEnvironmentVariables(_ env: [String]) {
    sortedEnvironmentVariables = env.compactMap { envVar in
      guard let separatorIndex = envVar.firstIndex(of: "=") else { return nil }
      let key = String(envVar[..<separatorIndex])
      let value = String(envVar[envVar.index(after: separatorIndex)...])
      return (key, value)
    }.sorted(by: { $0.key < $1.key })
  }
}
