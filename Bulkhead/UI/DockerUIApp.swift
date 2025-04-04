import SwiftUI

class ApplicationEnvironment {
  let publication: DockerPublication
  let logManager = LogManager()
  let manager: DockerManager

  init() {
    self.publication = DockerPublication(logManager: logManager)
    self.manager = DockerManager(logManager: logManager, publication: publication)

    // Start initial data fetch
    Task {
      await manager.fetchContainers()
      await manager.fetchImages()
    }
  }
}

@main
struct DockerUIApp: App {
  private let appEnv = ApplicationEnvironment()
  private var manager: DockerManager { appEnv.manager }
  @Environment(\.openWindow) private var openWindow
  @State private var selectedTab = MainTabs.containers
  @State private var isSearchFocused = false

  init() {
    // needed for the protocol
  }

  var body: some Scene {
    WindowGroup {
      ContentView(
        selectedTab: $selectedTab,
        searchFocused: $isSearchFocused,
        manager: manager,
        appEnv: appEnv
      )
      .environmentObject(appEnv.logManager)
      .environmentObject(appEnv.publication)
    }

    SettingsWindow(
      manager: appEnv.manager, publication: appEnv.publication, logManager: appEnv.logManager
    )
    .environmentObject(appEnv.logManager)
    .environmentObject(appEnv.publication)

    LogWindowScene()
      .environmentObject(appEnv.logManager)
      .environmentObject(appEnv.publication)

    // swiftlint:disable:next unused_parameter
    WindowGroup(for: DockerContainer.self) { $container in
      if let container {
        ContainerLogsView(container: container)
      }
    }
    .environmentObject(appEnv.logManager)
    .environmentObject(appEnv.publication)

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
            await appEnv.manager.fetchContainers()
            await appEnv.manager.fetchImages()
          }
        }
        .keyboardShortcut("r")

        Divider()

        //        Button("Search") {
        //          isSearchFocused = true
        //        }
        //        .keyboardShortcut("f")

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
