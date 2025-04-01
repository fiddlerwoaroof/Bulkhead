import SwiftUI

class AppState: ObservableObject {
  let manager = DockerManager()
}

@main
struct DockerUIApp: App {
  @StateObject var ass = AppState()
  @Environment(\.openWindow) private var openWindow
  @State private var selectedTab = 0
  @State private var isSearchFocused = false

  var body: some Scene {
    WindowGroup {
      ContentView(selectedTab: $selectedTab, searchFocused: $isSearchFocused, manager:ass.manager)
        .environmentObject(ass.manager.publication)
        .onAppear {
          Task {
            await ass.manager.fetchContainers()
            await ass.manager.fetchImages()
          }
        }
    }

    SettingsWindow(manager: ass.manager)
    LogWindowScene()

    // swiftlint:disable:next unused_parameter
    WindowGroup(for: DockerContainer.self) { $container in
      if let container {
        ContainerLogsView(container: container, manager: ass.manager)
      }
    }
    .environmentObject(ass.manager.publication)

    .commands {
      CommandGroup(replacing: .appInfo) {
        Button("Settings") {
          openWindow(id: "Settings")
        }
        .keyboardShortcut(",")

        Button("Show Logs") {
          openWindow(id: "Log")
        }
        .keyboardShortcut("l", modifiers: [.command, .shift])

        Divider()

        Button("Refresh Containers") {
          Task {
            await ass.manager.fetchContainers()
            await ass.manager.fetchImages()
          }
        }
        .keyboardShortcut("r")

        Divider()

        Button("Search") {
          isSearchFocused = true
        }
        .keyboardShortcut("f")

        Button("Next Item") {
          // Navigation handled by ListView
        }
        .keyboardShortcut(.downArrow)

        Button("Previous Item") {
          // Navigation handled by ListView
        }
        .keyboardShortcut(.upArrow)
      }
      CommandGroup(replacing: .help) { /* remove help */  }
      CommandGroup(replacing: .newItem) { /* remove new */  }
      CommandGroup(replacing: .saveItem) { /* remove save */  }
    }
  }
}
