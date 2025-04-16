import Foundation
import SwiftUI

// Define focus states outside the view struct
enum ListViewFocusTarget: Hashable {
  case search
  case imageList
  case containerList
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
  @FocusState<ListViewFocusTarget?> var focusState: ListViewFocusTarget?

  @State private var selectedContainer: DockerContainer?
  @State private var selectedImage: DockerImage?

  @State private var searchText = ""

  var filteredContainers: [DockerContainer] {
    publication.containers.filter { it in
      guard !searchText.isEmpty else { return true }
      guard let firstName = it.names.first else { return false }
      return firstName.localizedCaseInsensitiveContains(searchText)
    }
  }

  var filteredImages: [DockerImage] {
    publication.images.filter { it in
      guard !searchText.isEmpty else { return true }
      guard let firstTag = it.RepoTags?.first else { return false }
      return firstTag.localizedCaseInsensitiveContains(searchText)
    }
  }

  // Updated init
  init(
    selectedTab: Binding<MainTabs>,
    manager: DockerManager,
    appEnv: ApplicationEnvironment
      //    ,focusState: FocusState<ListViewFocusTarget?>.Binding
  ) {
    self.manager = manager
    self.appEnv = appEnv
    _selectedTab = selectedTab
    //    _focusState = focusState
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
            text: $searchText,
            focusBinding: $focusState,
            focusCase: .search,
            options: nil
          )
          .focused($focusState, equals: .search)

          List(filteredContainers, id: \.self, selection: $selectedContainer) { container in
            NavigationLink {
              ContainerDetailView(container: container, appEnv: appEnv)
                .navigationTitle(container.title)
            } label: {
              ContainerSummaryView(container: container, manager: appEnv.manager, appEnv: appEnv)
            }
          }
          .focused($focusState, equals: .containerList)
          .onChange(of: publication.containers) { _, _ in
            guard selectedContainer == nil else { return }
            if let firstContainer = filteredContainers.first {
              DispatchQueue.main.async {
                selectedContainer = firstContainer
              }
            }
          }
          .id(searchText)  // FIX: various hangs
        }
        .padding(4)
        .tabItem {
          Label("Containers", systemImage: "shippingbox.fill")
        }
        .tag(MainTabs.containers)

        VStack {
          SearchField(
            placeholder: "Search Images . . .",
            text: $searchText,
            focusBinding: $focusState,
            focusCase: .search,
            options: nil
          )
          .focused($focusState, equals: .search)

          List(filteredImages, id: \.self, selection: $selectedImage) { image in
            NavigationLink {
              ImageDetailView(image: image, appEnv: appEnv)
                .navigationTitle(image.title)
            } label: {
              ImageSummaryView(image: image)
            }
          }
          .focused($focusState, equals: .imageList)
          .onChange(of: publication.images) { _, _ in
            guard selectedImage == nil else { return }
            if let firstImage = filteredImages.first {
              DispatchQueue.main.async {
                selectedImage = firstImage
              }
            }
          }
          .onAppear {
            focusState = .imageList
          }
          .id(searchText)  // FIX: various hangs
        }
        .padding(4)
        .tabItem {
          Label("Images", systemImage: "photo.stack.fill")
        }
        .tag(MainTabs.images)
      }
    } detail: {
      Text("Select an object")
    }

    .navigationSplitViewColumnWidth(min: 250, ideal: 320, max: 800)
    .onKeyPress(.downArrow) {
      if let curFocus = focusState, curFocus == .search {
        switch selectedTab {
        case .containers:
          selectedContainer = filteredContainers.first
          focusState = .containerList
        case .images:
          selectedImage = filteredImages.first
          focusState = .imageList
        }
        return .handled
      }
      return .ignored
    }
    .onKeyPress(.upArrow) {
      if let curFocus = focusState, curFocus == .imageList || curFocus == .containerList {
        let firstSelected =
          switch selectedTab {
          case .containers:
            selectedContainer == filteredContainers.first
          case .images:
            selectedImage == filteredImages.first
          }
        if firstSelected {
          focusState = .search
          return .handled
        }
        return .ignored
      }
      return .ignored
    }
    .onKeyPress(.escape) {
      if let focusState, focusState == .search {
        searchText = ""
        return .handled
      }
      return .ignored
    }
    .task {
      let containers = await manager.fetchContainers()
      selectedContainer = containers[0]
      let images = await manager.fetchImages()
      selectedImage = images[0]
      await MainActor.run {
        self.focusState = .containerList
      }
    }
  }

}
