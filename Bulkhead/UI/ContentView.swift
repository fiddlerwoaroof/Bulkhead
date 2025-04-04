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

enum MainTabs {
  case containers
  case images
}

struct ContentView: View {
  // Observe publication directly
  @EnvironmentObject var publication: DockerPublication
  // Receive manager via init
  let manager: DockerManager
  let appEnv: ApplicationEnvironment
  @Binding var selectedTab: MainTabs
  @Environment(\.colorScheme) private var colorScheme
  @State private var selectedContainer: DockerContainer?
  @State private var selectedImage: DockerImage?

  @Binding private var searchFocused: Bool

  // Updated init
  init(
    selectedTab: Binding<MainTabs>,
    searchFocused: Binding<Bool>,
    manager: DockerManager,
    appEnv: ApplicationEnvironment
  ) {
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

  var body: some View {
    // Main content with potential error overlay
    NavigationSplitView {
      TabView(selection: $selectedTab) {
        // Container List View
        ContainerListView(
          backgroundColor: backgroundColor,
          shadowColor: shadowColor,

          selectedContainer: $selectedContainer,

          searchFocused: $searchFocused,

          manager: manager,
          appEnv: appEnv
        )
        .tabItem {
          Label("Containers", systemImage: "shippingbox.fill")
        }
        .tag(MainTabs.containers)

        // Image List View
        ImageListView(
          backgroundColor: backgroundColor,
          shadowColor: shadowColor,

          selectedImage: $selectedImage,

          searchFocused: $searchFocused,

          manager: manager,
          appEnv: appEnv
        )
        .tabItem {
          Label("Images", systemImage: "photo.stack.fill")
        }
        .tag(MainTabs.images)
      }
    } detail: {
      if let error = globalConnectionError {
        Rectangle()
          .fill(.ultraThinMaterial.opacity(0.9))  // Apply material to the background
          .ignoresSafeArea()  // Ensure it covers the whole window area if needed
          .overlay(  // Place the ErrorView content on top, centered by default
            ErrorView(
              error: error, title: "Connection Error", style: .prominent,
              actions: [
                ErrorAction(label: "Refresh") {}
              ]
            )
            .padding()  // Add padding around the ErrorView content
          )
      } else if selectedTab == .containers, let selectedContainer {
        ContainerDetailView(container: selectedContainer, appEnv: appEnv)
      } else if let selectedImage {
        ImageDetailView(image: selectedImage, appEnv: appEnv)
      } else {
        Text("Nothing Selected!")
      }
    }
  }
}
