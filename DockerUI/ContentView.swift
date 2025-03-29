import Foundation
import SwiftUI

struct ImageListView: View {
  @State private var backgroundColor: Color
  @State private var shadowColor: Color
  @Binding var images: [DockerImage]

  var body: some View {
    ScrollView {
      LazyVStack(spacing: 8) {
        //            ForEach(manager.images) { image in
        ForEach(images) { image in
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
          .padding()
          .background(backgroundColor)
          .cornerRadius(10)
          .shadow(color: shadowColor, radius: 2, x: 0, y: 1)
          .padding(.horizontal)
        }
      }
      .padding(.vertical)
    }
  }
}

struct ContainerListView: View {
  @Environment(\.openWindow) private var openWindow
  @EnvironmentObject var manager: DockerManager
  @State private var backgroundColor: Color
  @State private var shadowColor: Color
  @Binding var containers: [DockerContainer]

  var body: some View {
    ScrollView {
      LazyVStack(spacing: 8) {
        ForEach(containers) { container in
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
            VStack {
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
              .buttonStyle(.link)
              .controlSize(.small)
            }
          }
          .padding()
          .background(backgroundColor)
          .cornerRadius(10)
          .shadow(color: shadowColor, radius: 2, x: 0, y: 1)
          .padding(.horizontal)
        }
      }
      .padding(.vertical)
    }
  }
}

struct ContentView: View {
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.openWindow) private var openWindow
  @StateObject private var manager = DockerManager()

  var backgroundColor: Color {
    colorScheme == .dark ? Color(NSColor.controlBackgroundColor) : Color.white
  }

  var shadowColor: Color {
    colorScheme == .dark ? Color.black.opacity(0.2) : Color.black.opacity(0.05)
  }

  var body: some View {
    TabView {
      ContainerListView(
        backgroundColor: backgroundColor, shadowColor: shadowColor, containers: $manager.containers
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
