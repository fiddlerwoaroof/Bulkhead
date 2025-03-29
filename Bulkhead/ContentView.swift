import Foundation
import SwiftUI

struct ImageListView: View {
  var backgroundColor: Color
  var shadowColor: Color
  @Binding var images: [DockerImage]
  @Binding var isSearchFocused: Bool
  @State private var selectedImage: DockerImage?

  var body: some View {
    ListView(
      items: $images,
      selectedItem: $selectedImage,
      backgroundColor: backgroundColor,
      shadowColor: shadowColor,
      searchConfig: SearchConfiguration(
        placeholder: "Search images...",
        filter: { image, query in
          let searchQuery = query.lowercased()
          // Search in repo tags
          if let tag = image.RepoTags?.first?.lowercased(),
            tag.contains(searchQuery)
          {
            return true
          }
          // Search in ID
          return image.Id.lowercased().contains(searchQuery)
        },
        options: SearchOptions(
          caseSensitive: false,
          matchWholeWords: false,
          keyboardShortcut: "f",
          modifiers: .command
        )
      ), isSearchFocused: $isSearchFocused
    ) { image in
      HStack {
        VStack(alignment: .leading, spacing: 2) {
          Text(image.RepoTags?.first ?? "<none>")
            .font(.headline)
          Text("Size: \(image.Size / (1024 * 1024)) MB")
            .font(.subheadline)
            .foregroundColor(.gray)
          Text("Created: \(Date(timeIntervalSince1970: TimeInterval(image.Created)))")
            .font(.caption)
            .foregroundColor(.secondary)
        }
        Spacer()
      }
    } detail: { image in
      VStack(alignment: .leading, spacing: 12) {
        Text("Details for \(image.RepoTags?.first ?? "<none>")")
          .font(.title2)
        Text("Created: \(Date(timeIntervalSince1970: TimeInterval(image.Created)))")
      }
      .padding()
    }
  }
}

struct ContainerListView: View {
  @Environment(\.openWindow) private var openWindow
  @EnvironmentObject var manager: DockerManager
  @Binding var isSearchFocused: Bool

  var backgroundColor: Color
  var shadowColor: Color
  @Binding var containers: [DockerContainer]
  @Binding var selectedContainer: DockerContainer?

  var body: some View {
    ListView(
      items: $containers,
      selectedItem: $selectedContainer,
      backgroundColor: backgroundColor,
      shadowColor: shadowColor,
      searchConfig: SearchConfiguration(
        placeholder: "Search containers...",
        filter: { container, query in
          let searchQuery = query.lowercased()
          // Search in container name
          if let name = container.names.first?.lowercased(),
            name.contains(searchQuery)
          {
            return true
          }
          // Search in image name
          if container.image.lowercased().contains(searchQuery) {
            return true
          }
          // Search in status
          return container.status.lowercased().contains(searchQuery)
        },
        options: SearchOptions(
          caseSensitive: false,
          matchWholeWords: false,
          keyboardShortcut: "f",
          modifiers: .command
        )
      ), isSearchFocused: $isSearchFocused
    ) { container in
      HStack {
        VStack(alignment: .leading, spacing: 2) {
          HStack(spacing: 8) {
            Text(container.names.first ?? "Unnamed")
              .font(.headline)
          }
          if container.status.lowercased().contains("up") {
            statusBadge(container.status, color: .green)
          } else {
            statusBadge(container.status, color: .secondary)
          }
          Text(container.image)
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        Spacer()
        containerActions(container)
      }
    } detail: { container in
      ContainerDetailView(container: container)
        .id(container.id)
    }
  }

  private func statusBadge(_ text: String, color: Color) -> some View {
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

  func containerActions(_ container: DockerContainer) -> some View {
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

struct ContentView: View {
  @EnvironmentObject var manager: DockerManager
  @Binding var selectedTab: Int
  @Binding var isSearchFocused: Bool
  @Environment(\.colorScheme) private var colorScheme
  @State private var selectedContainer: DockerContainer?

  init(selectedTab: Binding<Int>, isSearchFocused: Binding<Bool>) {
    _selectedTab = selectedTab
    _isSearchFocused = isSearchFocused
  }

  private var backgroundColor: Color {
    colorScheme == .dark ? Color(NSColor.controlBackgroundColor) : Color.white
  }

  private var shadowColor: Color {
    colorScheme == .dark ? Color.black.opacity(0.2) : Color.black.opacity(0.05)
  }

  var body: some View {
    TabView(selection: $selectedTab) {
      ContainerListView(
        isSearchFocused: $isSearchFocused,
        backgroundColor: backgroundColor,
        shadowColor: shadowColor,
        containers: $manager.containers,
        selectedContainer: $selectedContainer
      )
      .tabItem {
        Label("Containers", systemImage: "shippingbox")
      }
      .tag(0)

      ImageListView(
        backgroundColor: backgroundColor,
        shadowColor: shadowColor,
        images: $manager.images,
        isSearchFocused: $isSearchFocused
      )
      .tabItem {
        Label("Images", systemImage: "square.stack.3d.down.right")
      }
      .tag(1)
    }
    .frame(minWidth: 600, minHeight: 500)
    .onAppear {
      manager.fetchContainers()
      manager.fetchImages()
    }
    .onChange(of: manager.containers) { _, newContainers in
      if selectedContainer == nil && !newContainers.isEmpty {
        selectedContainer = newContainers[0]
      }
    }
  }
}
