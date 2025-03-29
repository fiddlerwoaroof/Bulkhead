import Foundation
import SwiftUI

struct ImageListView: View {
  var backgroundColor: Color
  var shadowColor: Color
  @Binding var images: [DockerImage]
  @State private var selectedImage: DockerImage?

  var body: some View {
    ListView(
      items: $images, selectedItem: $selectedImage, backgroundColor: backgroundColor,
      shadowColor: shadowColor
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

  var backgroundColor: Color
  var shadowColor: Color
  @Binding var containers: [DockerContainer]
  @Binding var selectedContainer: DockerContainer?

  var body: some View {
    ListView(
      items: $containers,
      selectedItem: $selectedContainer,
      backgroundColor: backgroundColor,
      shadowColor: shadowColor
    ) { container in
      HStack {
        VStack(alignment: .leading, spacing: 2) {
          Text(container.names.first ?? "Unnamed")
            .font(.headline)
          Text(container.image)
            .font(.subheadline)
            .foregroundColor(.gray)
          Text(container.status.capitalized)
            .font(.caption)
            .foregroundColor(.secondary)
        }

        Spacer()

        containerActions(container)
      }
    } detail: { container in
      ContainerDetailView(container: container)
        .id(container.id)
    }
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
  @Environment(\.colorScheme) private var colorScheme
  @StateObject private var manager = DockerManager()
  @State private var selectedContainer: DockerContainer?

  var backgroundColor: Color {
    colorScheme == .dark ? Color(NSColor.controlBackgroundColor) : Color.white
  }

  var shadowColor: Color {
    colorScheme == .dark ? Color.black.opacity(0.2) : Color.black.opacity(0.05)
  }

  var body: some View {
    TabView {
      ContainerListView(
        backgroundColor: backgroundColor,
        shadowColor: shadowColor,
        containers: $manager.containers,
        selectedContainer: $selectedContainer
      )
      .tabItem {
        Text("Containers")
      }

      ImageListView(
        backgroundColor: backgroundColor, shadowColor: shadowColor, images: $manager.images
      )
      .tabItem {
        Text("Images")
      }
    }
    .frame(minWidth: 600, minHeight: 500)
    .onAppear {
      manager.fetchContainers()
      manager.fetchImages()
    }
    .environmentObject(manager)
  }
}
