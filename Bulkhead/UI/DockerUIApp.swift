import SwiftUI

@main
struct DockerUIApp: App {
  @StateObject private var manager = DockerManager()
  @Environment(\.openWindow) private var openWindow
  @State private var selectedTab = 0
  @State private var isSearchFocused = false

  var body: some Scene {
    WindowGroup {
      ContentView(selectedTab: $selectedTab, searchFocused: $isSearchFocused)
        .environmentObject(manager)
        .onAppear {
          Task {
            await manager.fetchContainers()
            await manager.fetchImages()
          }
        }
    }

    SettingsWindow(manager: manager)
    LogWindowScene()

    // swiftlint:disable:next unused_parameter
    WindowGroup(for: DockerContainer.self) { $container in
      if let container {
        ContainerLogsView(container: container)
      }
    }
    .environmentObject(manager)

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
            await manager.fetchContainers()
            await manager.fetchImages()
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
