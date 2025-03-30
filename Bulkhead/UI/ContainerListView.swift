import Foundation
import SwiftUI

struct ContainerListView: View {
  @Environment(\.openWindow) private var openWindow
  @EnvironmentObject var manager: DockerManager
  @Binding var containers: [DockerContainer]
  @Binding var selectedContainer: DockerContainer?
  @State private var lastKnownFocus: ListView<DockerContainer, AnyView, AnyView>.FocusField? = nil // Persisted focus state

  var backgroundColor: Color
  var shadowColor: Color

  private var containerSearchConfig: SearchConfiguration<DockerContainer> {
    SearchConfiguration(
      placeholder: "Search containers...",
      filter: { container, query in
        let searchQuery = query.lowercased()
        // Search in container name
        if let name = container.names.first?.lowercased(), name.contains(searchQuery) {
          return true
        }
        // Search in image name
        if container.image.lowercased().contains(searchQuery) {
          return true
        }
        // Search in status
        return container.status.lowercased().contains(searchQuery)
      }
    )
  }

  var body: some View {
    ListView(
      items: $containers,
      selectedItem: $selectedContainer,
      backgroundColor: backgroundColor,
      shadowColor: shadowColor,
      content: { container in
        // Type erase the content view
        AnyView(
          HStack {
            VStack(alignment: .leading, spacing: 2) {
              HStack(spacing: 8) {
                Text(container.names.first ?? "Unnamed")
                  .font(.headline)
              }
              if container.status.lowercased().contains("up") {
                StatusBadgeView(text: container.status, color: .green)
              } else {
                StatusBadgeView(text: container.status, color: .secondary)
              }
              Text(container.image)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            Spacer()
            ContainerActionsView(container: container, manager: manager)
          }
        )
      },
      detail: { container in
        // Type erase the detail view
        AnyView(ContainerDetailView(container: container))
      },
      searchConfig: containerSearchConfig,
      persistedFocus: lastKnownFocus, // Pass the persisted focus state
      onFocusChange: { newFocus in // Provide callback
          lastKnownFocus = newFocus
      }
    )
  }
}

// New View for Status Badge
struct StatusBadgeView: View {
  let text: String
  let color: Color

  var body: some View {
    HStack(spacing: 4) {
      Image(systemName: color == .green ? "checkmark.circle.fill" : "stop.circle.fill")
        .foregroundStyle(color)
      Text(text)
        .font(.caption)
        .foregroundStyle(color)
    }
    .padding(.horizontal, 6)
    .padding(.vertical, 2)
    .background(color.opacity(0.15))
    .clipShape(RoundedRectangle(cornerRadius: 4))
  }
}

// New View for Container Actions
struct ContainerActionsView: View {
  @Environment(\.openWindow) private var openWindow
  let container: DockerContainer
  @ObservedObject var manager: DockerManager // Use ObservedObject if manager might change

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      if container.status.lowercased().contains("up") {
        Button("Stop") {
          manager.stopContainer(id: container.id)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
      } else {
        Button("Start") {
          manager.startContainer(id: container.id)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
      }

      Button("Logs") {
        openWindow(value: container)
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
    }
  }
} 