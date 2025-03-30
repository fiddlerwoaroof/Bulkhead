import Foundation
import SwiftUI

struct ContentView: View {
  @EnvironmentObject var manager: DockerManager
  @Binding var selectedTab: Int
  @Environment(\.colorScheme) private var colorScheme
  @State private var selectedContainer: DockerContainer?
  @State private var selectedImage: DockerImage?
  @Binding private var searchFocused: Bool

  init(selectedTab: Binding<Int>, searchFocused: Binding<Bool>) {
    _selectedTab = selectedTab
    _searchFocused = searchFocused
  }

  private var backgroundColor: Color {
    colorScheme == .dark ? Color(NSColor.controlBackgroundColor) : Color.white
  }

  private var shadowColor: Color {
    colorScheme == .dark ? Color.black.opacity(0.2) : Color.black.opacity(0.05)
  }
    
    private var containerListView: some View {
      ContainerListView(
          containers: $manager.containers,
          selectedContainer: $selectedContainer,
          searchFocused: $searchFocused,
          backgroundColor: backgroundColor,
          shadowColor: shadowColor
      )
    }
    
    private var imageListView: some View {
      ImageListView(
        backgroundColor: backgroundColor,
        shadowColor: shadowColor,
        images: $manager.images,
        searchFocused: $searchFocused,
        selectedImage: $selectedImage,
        manager: manager
      )
    }

  var body: some View {
      TabView(selection: $selectedTab) {
        // Container List View
          containerListView
        .tabItem {
          Label("Containers", systemImage: "shippingbox.fill")
        }
        .tag(0)
      // Image List View
          imageListView
              .tabItem {
        Label("Images", systemImage: "photo.stack.fill")
      }
      .tag(1)
    }
    .frame(minWidth: 800, minHeight: 600)
    .onAppear {
        Task {
            await manager.fetchContainers()
        }
        Task {
          await manager.fetchImages()
      }
    }
    .onChange(of: manager.containers) { _, newContainers in
      if selectedContainer == nil && !newContainers.isEmpty {
        selectedContainer = newContainers[0]
      }
    }
  }
}
