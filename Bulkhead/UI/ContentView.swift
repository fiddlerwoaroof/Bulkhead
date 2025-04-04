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

  @State private var searchText = ""
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
        List(publication.containers, selection: $selectedContainer) { container in
          NavigationLink {
            ContainerDetailView(container: container, appEnv: appEnv)
          } label: {
            ContainerSummaryView(container: container, manager: appEnv.manager, appEnv: appEnv)
          }
          .padding(4)
        }
        .tabItem {
          Label("Containers", systemImage: "shippingbox.fill")
        }
        .tag(MainTabs.containers)

        List(publication.images, selection: $selectedImage) { image in
          NavigationLink {
            ImageDetailView(image: image, appEnv: appEnv)
          } label: {
            ImageSummaryView(image: image)
          }
        }
        .tabItem {
          Label("Images", systemImage: "photo.stack.fill")
        }
        .tag(MainTabs.images)

      }
    } detail: {
      Text("Select an object")
    }
    .navigationSplitViewColumnWidth(min: 250, ideal: 320, max: 800)
    .onKeyPress(
      .escape,
      action: {
        print("NOTICE ME: content view received escape \(searchFocused)")
        searchText = ""
        return searchFocused ? .handled : .ignored
      })
  }
}
