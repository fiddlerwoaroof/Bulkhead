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
          detailRow("Name", container.names.first ?? "<unnamed>")
          detailRow("Image", container.image)
          detailRow("Status", container.status)

          if let created = enriched?.created {
            detailRow("Created", created.formatted(date: .abbreviated, time: .shortened))
          }

          if let command = enriched?.command {
            detailRow("Command", command)
          }
        }

        if let ports = enriched?.ports, !ports.isEmpty {
          sectionHeader("Ports")
          ForEach(ports, id: \.self) { port in
            Text(
              "\(port.ip ?? "0.0.0.0"):\(port.publicPort ?? 0) → \(port.privatePort)/\(port.type)"
            )
            .font(.system(.body, design: .monospaced))
            .foregroundColor(.primary)
          }
        }

        if let mounts = enriched?.mounts, !mounts.isEmpty {
          sectionHeader("Mounts")
          ForEach(mounts, id: \.self) { mount in
            Text("\(mount.source) → \(mount.destination)")
              .font(.system(.body, design: .monospaced))
              .foregroundColor(.primary)
          }
        }

        if let health = enriched?.health {
          sectionHeader("Health")
          Label(
            health,
            systemImage: health == "Healthy"
              ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
          )
          .foregroundColor(health == "Healthy" ? .green : .orange)
        }
      }
      .padding()
      .frame(maxWidth: .infinity, alignment: .topLeading)
    }
  }

  @ViewBuilder
  private func detailRow(_ label: String, _ value: String) -> some View {
    HStack(alignment: .top) {
      Text("\(label):")
        .fontWeight(.semibold)
        .frame(width: 80, alignment: .leading)
      Text(value)
        .font(.system(.body, design: .monospaced))
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
