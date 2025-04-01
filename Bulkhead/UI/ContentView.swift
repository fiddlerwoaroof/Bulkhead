import Foundation
import SwiftUI

// Define Environment Key for Global Error State
struct IsGlobalErrorShowingKey: EnvironmentKey {
  static let defaultValue = false
}

extension EnvironmentValues {
  var isGlobalErrorShowing: Bool {
    get { self[IsGlobalErrorShowingKey.self] }
    set { self[IsGlobalErrorShowingKey.self] = newValue }
  }
}

struct ContentView: View {
  // Observe publication directly
  @EnvironmentObject var publication: DockerPublication
  // Receive manager via init
  let manager: DockerManager
  let appEnv: ApplicationEnvironment
  @Binding var selectedTab: Int
  @Environment(\.colorScheme) private var colorScheme
  @State private var selectedContainer: DockerContainer?
  @State private var selectedImage: DockerImage?
  @Binding private var searchFocused: Bool

  // Updated init
  init(selectedTab: Binding<Int>, searchFocused: Binding<Bool>, manager: DockerManager, appEnv: ApplicationEnvironment) {
    self.manager = manager
    self.appEnv = appEnv
    _selectedTab = selectedTab
    _searchFocused = searchFocused
  }

  private var backgroundColor: Color {
    colorScheme == .dark ? Color(NSColor.controlBackgroundColor) : Color.white
  }

  private var shadowColor: Color {
    colorScheme == .dark ? Color.black.opacity(0.2) : Color.black.opacity(0.05)
  }

  // Get errors from observed publication
  private var globalConnectionError: DockerError? {
    if let err = publication.containerListError, err.isConnectionError { return err }
    if let err = publication.imageListError, err.isConnectionError { return err }
    return nil
  }

  private var containerListView: some View {
    ContainerListView(
      // Pass data array from publication
      containers: publication.containers,
      selectedContainer: $selectedContainer,
      searchFocused: $searchFocused,
      backgroundColor: backgroundColor,
      shadowColor: shadowColor,
      // Pass manager instance
      manager: manager,
      appEnv: appEnv
    )
  }

  private var imageListView: some View {
    ImageListView(
      backgroundColor: backgroundColor,
      shadowColor: shadowColor,
      // Pass data array from publication
      images: publication.images,
      searchFocused: $searchFocused,
      selectedImage: $selectedImage,
      // Pass manager instance
      manager: manager,
      appEnv: appEnv
    )
  }

  var body: some View {
    // Main content with potential error overlay
    ZStack {
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
      // Pass down environment value based on global error state
      .environment(\.isGlobalErrorShowing, globalConnectionError != nil)

      // Overlay Error View if a global connection error exists
      if let error = globalConnectionError {
        // Background layer that fills the space
        Rectangle()
          .fill(.ultraThinMaterial.opacity(0.9))  // Apply material to the background
          .ignoresSafeArea()  // Ensure it covers the whole window area if needed
          .overlay(  // Place the ErrorView content on top, centered by default
            ErrorView(error: error, title: "Connection Error", style: .prominent)
              .padding()  // Add padding around the ErrorView content
          )
      }
    }
    .onAppear {
      Task {
        await manager.fetchContainers()
        await manager.fetchImages()
      }
    }
    // .onChange can monitor publication.containers directly
    .onChange(of: publication.containers) { _, newContainers in
      if selectedContainer == nil && !newContainers.isEmpty {
        selectedContainer = newContainers[0]
      }
    }
  }
}
