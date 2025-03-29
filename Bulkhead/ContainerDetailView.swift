import SwiftUI

struct ContainerDetailView: View {
  let container: DockerContainer
  @EnvironmentObject var manager: DockerManager
  @StateObject private var model = ContainerDetailModel()

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

      FilesystemBrowserView(container: container)
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
            if let health = enriched?.health {
              healthStatusView(health)
            }
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

  private func healthStatusView(_ health: String) -> some View {
    let (status, color) = healthStatusInfo(health)
    return HStack(spacing: 4) {
      Image(systemName: status.icon)
        .foregroundStyle(color)
      Text(status.text)
        .font(.caption)
        .foregroundStyle(color)
    }
    .padding(.horizontal, 6)
    .padding(.vertical, 2)
    .background(color.opacity(0.15))
    .clipShape(RoundedRectangle(cornerRadius: 4))
  }

  private func healthStatusInfo(_ health: String) -> (status: HealthStatus, color: Color) {
    let normalizedHealth = health.lowercased()
    switch normalizedHealth {
    case "healthy":
      return (.healthy, .green)
    case "unhealthy":
      return (.unhealthy, .red)
    case "starting":
      return (.starting, .orange)
    case "none":
      return (.none, .secondary)
    default:
      return (.unknown, .secondary)
    }
  }

  private enum HealthStatus {
    case healthy
    case unhealthy
    case starting
    case none
    case unknown

    var icon: String {
      switch self {
      case .healthy: return "checkmark.circle.fill"
      case .unhealthy: return "xmark.circle.fill"
      case .starting: return "arrow.triangle.2.circlepath.circle.fill"
      case .none: return "minus.circle.fill"
      case .unknown: return "questionmark.circle.fill"
      }
    }

    var text: String {
      switch self {
      case .healthy: return "Healthy"
      case .unhealthy: return "Unhealthy"
      case .starting: return "Starting"
      case .none: return "No Health Check"
      case .unknown: return "Unknown"
      }
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
          pathDetailRow(key, value.split(separator: ":").map(String.init))
        } else {
          envDetailRow(key, value)
        }
      } else {
        envDetailRow("", envVar)
      }
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
