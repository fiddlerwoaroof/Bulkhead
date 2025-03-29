import SwiftUI

struct FilesystemLocation: Hashable {
  let container: DockerContainer
  let path: String
}

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

extension HealthStatus {
  fileprivate var color: Color {
    switch self {
    case .healthy: return .green
    case .unhealthy: return .red
    case .starting: return .orange
    case .none: return .secondary
    case .unknown: return .secondary
    }
  }

  fileprivate var icon: String {
    switch self {
    case .healthy: return "checkmark.circle.fill"
    case .unhealthy: return "xmark.circle.fill"
    case .starting: return "arrow.triangle.2.circlepath.circle.fill"
    case .none: return "minus.circle.fill"
    case .unknown: return "questionmark.circle.fill"
    }
  }

  fileprivate var label: String {
    switch self {
    case .healthy: return "Healthy"
    case .unhealthy: return "Unhealthy"
    case .starting: return "Starting"
    case .none: return "No Health Check"
    case .unknown: return "Unknown"
    }
  }
}

struct ContainerDetailView: View {
  let container: DockerContainer
  @EnvironmentObject var manager: DockerManager
  @StateObject private var model = ContainerDetailModel()
  @State private var selectedPath: String?

  var body: some View {
    VSplitView {
      ScrollView {
        VStack(alignment: .leading, spacing: 8) {
          if let base = model.base {
            detailContent(base, enriched: model.enriched)
          } else if model.isLoading {
            ProgressView("Loading container details...")
          } else if let error = model.error {
            Text("Error: \(error.localizedDescription)")
              .foregroundColor(.red)
          }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .topLeading)

      }

      FilesystemBrowserView(container: container, initialPath: selectedPath ?? "/")
        .frame(minHeight: 200)
    }
    .padding()
    .task(id: container.id) {
      await model.load(for: container, using: manager)
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
            ForEach(ports, id: \.privatePort) { port in
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
  private func pathDetailRow(_ label: String, _ paths: [String]) -> some View {
    HStack(alignment: .firstTextBaseline) {
      Text("\(label):")
        .fontWeight(.semibold)
        .frame(width: 200, alignment: .leading)
      VStack(alignment: .leading) {
        ForEach(paths, id: \.self) { path in
          Text(path)
            .font(.system(.body, design: .monospaced))
        }
      }
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
              ForEach(value.split(separator: ":").map(String.init), id: \.self) { path in
                Button(action: {
                  selectedPath = path
                }) {
                  Text(path)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.blue)
                }
                .buttonStyle(.link)
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

@MainActor
final class ContainerDetailModel: ObservableObject {
  @Published var enriched: DockerContainer?
  @Published var isLoading = false
  @Published var error: Error?

  var base: DockerContainer?

  func load(for container: DockerContainer, using manager: DockerManager) async {
    base = container
    enriched = nil
    error = nil
    isLoading = true

    do {
      let result = try await manager.enrichContainer(container)
      self.enriched = result
    } catch {
      self.error = error
    }

    isLoading = false
  }
}
