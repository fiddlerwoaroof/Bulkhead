import Foundation
import SwiftUI

// Define focus states outside the view struct
enum ListViewFocusTarget: Hashable {
  case search
  case item(AnyHashable)
}

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
  @FocusState<ListViewFocusTarget?>.Binding var focusState: ListViewFocusTarget?

  @State private var selectedContainer: DockerContainer?
  @State private var lastContainer: DockerContainer?
  @State private var containerSearchText = ""

  @State private var selectedImage: DockerImage?
  @State private var lastImage: DockerImage?
  @State private var imageSearchText = ""

  var filteredContainers: [DockerContainer] {
    publication.containers.filter { it in
      guard !containerSearchText.isEmpty else { return true }
      guard let firstName = it.names.first else { return false }
      return firstName.contains(containerSearchText)
    }
  }

  var filteredImages: [DockerImage] {
    publication.images.filter { it in
      guard !imageSearchText.isEmpty else { return true }
      guard let firstTag = it.RepoTags?.first else { return false }
      return firstTag.contains(imageSearchText)
    }
  }

  // Updated init
  init(
    selectedTab: Binding<MainTabs>,
    manager: DockerManager,
    appEnv: ApplicationEnvironment,
    focusState: FocusState<ListViewFocusTarget?>.Binding
  ) {
    self.manager = manager
    self.appEnv = appEnv
    _selectedTab = selectedTab
    _focusState = focusState
  }

  // Get errors from observed publication
  // private var globalConnectionError: DockerError? {
  //   if let err = publication.containerListError, err.isConnectionError { return err }
  //   if let err = publication.imageListError, err.isConnectionError { return err }
  //   return nil
  // }

  var body: some View {
    // Main content with potential error overlay
    NavigationSplitView {
      TabView(selection: $selectedTab) {
        VStack {
          SearchField(
            placeholder: "Search Containers . . .",
            text: $containerSearchText,
            focusBinding: $focusState,
            focusCase: .search,
            options: nil
          )
          .focused($focusState, equals: .search)

          List(filteredContainers, id: \.self, selection: $selectedContainer) { container in
            NavigationLink {
              ContainerDetailView(container: container, appEnv: appEnv)
            } label: {
              ContainerSummaryView(container: container, manager: appEnv.manager, appEnv: appEnv)
            }
            .focused($focusState, equals: .item(container))
          }
          .onChange(of: publication.containers) { _, _ in
            guard selectedContainer == nil && lastContainer == nil else { return }
            if let firstContainer = filteredContainers.first {
              DispatchQueue.main.async {
                selectedContainer = firstContainer
                focusState = .item(firstContainer)
              }
            }
          }

        }
        .padding(4)
        .tabItem {
          Label("Containers", systemImage: "shippingbox.fill")
        }
        .tag(MainTabs.containers)

        VStack {
          SearchField(
            placeholder: "Search Images . . .",
            text: $imageSearchText,
            focusBinding: $focusState,
            focusCase: .search,
            options: nil
          )
          .focused($focusState, equals: .search)

          List(filteredImages, id: \.self, selection: $selectedImage) { image in
            NavigationLink {
              ImageDetailView(image: image, appEnv: appEnv)
            } label: {
              ImageSummaryView(image: image)
            }
            .focused($focusState, equals: .item(image))
            .focusable(true)
          }
          .onChange(of: publication.images) { _, _ in
            guard selectedImage == nil && lastImage == nil else { return }
            if let firstImage = filteredImages.first {
              DispatchQueue.main.async {
                selectedImage = firstImage
              }
            }
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
    .onChange(of: selectedTab) { _, newTab in
      DispatchQueue.main.async {
        if newTab == .containers {
          lastImage = selectedImage
          let toFocus = lastContainer ?? publication.containers.first
          selectedContainer = toFocus
          if let toFocus {
            focusState = .item(toFocus)
          }
          selectedImage = nil
        } else if newTab == .images {
          lastContainer = selectedContainer
          let toFocus = lastImage ?? publication.images.first
          selectedImage = toFocus
          if let toFocus {
            focusState = .item(toFocus)
          }
          selectedContainer = nil
        }
      }
    }

    .navigationSplitViewColumnWidth(min: 250, ideal: 320, max: 800)
    .onKeyPress(.downArrow) {
      if focusState == .search {
        if selectedTab == .containers, let firstContainer = publication.containers.first {
          focusState = .item(firstContainer)
        } else if let firstImage = publication.images.first {
          focusState = .item(firstImage)
        }

        return .handled
      }
      return .ignored
    }
    .onKeyPress(.upArrow) {
      if focusState != .search {
        if selectedTab == .containers, let firstContainer = publication.containers.first,
          selectedContainer == firstContainer
        {
          focusState = .search
        } else if let firstImage = publication.images.first, selectedImage == firstImage {
          focusState = .search
        }

        return .handled
      }
      return .ignored
    }
    .onKeyPress(.escape) {
      if let focusState, focusState == .search {
        if selectedTab == .containers {
          containerSearchText = ""
        } else {
          imageSearchText = ""
        }
        return .handled
      }
      return .ignored
    }
  }

}
