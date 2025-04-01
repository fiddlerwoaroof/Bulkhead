import SwiftUI

class ApplicationEnvironment: ObservableObject {
  let logManager = LogManager()
  let manager: DockerManager

  init() {
    self.manager = DockerManager(logManager: logManager)

    // Start initial data fetch
    Task {
      await manager.fetchContainers()
      await manager.fetchImages()
    }
  }
}

@main
struct DockerUIApp: App {
  @StateObject private var appEnv = ApplicationEnvironment()
  private var manager: DockerManager { appEnv.manager }
  @Environment(\.openWindow) private var openWindow
  @State private var selectedTab = 0
  @State private var isSearchFocused = false

  init() {
    // needed for the protocol
  }

  var body: some Scene {
    WindowGroup {
      ContentView(selectedTab: $selectedTab, searchFocused: $isSearchFocused, manager: manager)
        .environmentObject(appEnv.manager.publication)
        .environmentObject(appEnv)
        .onAppear {
          Task {
            await appEnv.manager.fetchContainers()
            await appEnv.manager.fetchImages()
          }
        }
    }

    SettingsWindow(manager: appEnv.manager)
    LogWindowScene()

    // swiftlint:disable:next unused_parameter
    WindowGroup(for: DockerContainer.self) { $container in
      if let container {
        ContainerLogsView(container: container, manager: appEnv.manager)
      }
    }
    .environmentObject(appEnv.manager.publication)

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
          let manager = manager
          Task {
            await appEnv.manager.fetchContainers()
            await appEnv.manager.fetchImages()
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
