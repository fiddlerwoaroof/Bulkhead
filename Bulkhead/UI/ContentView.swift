import Foundation
import SwiftUI

struct ContentView: View {
  @EnvironmentObject var manager: DockerManager
  @Binding var selectedTab: Int
  @Environment(\.colorScheme) private var colorScheme
  @State private var selectedContainer: DockerContainer?

  init(selectedTab: Binding<Int>) {
    _selectedTab = selectedTab
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
        containers: $manager.containers,
        selectedContainer: $selectedContainer,
        backgroundColor: backgroundColor,
        shadowColor: shadowColor
      )
      .tabItem {
        Label("Containers", systemImage: "shippingbox")
      }
      .tag(0)

      ImageListView(
        backgroundColor: backgroundColor,
        shadowColor: shadowColor,
        images: $manager.images
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
