import SwiftUI

class ApplicationEnvironment {
  let publication: DockerPublication
  let logManager = LogManager()
  let manager: DockerManager

  init() {
    self.publication = DockerPublication(logManager: logManager)
    self.manager = DockerManager(logManager: logManager, publication: publication)
  }
}

@main
struct DockerUIApp: App {
  private let appEnv = ApplicationEnvironment()
  private var manager: DockerManager { appEnv.manager }
  @Environment(\.openWindow) private var openWindow
  @State private var selectedTab = MainTabs.containers

  //  @FocusState private var focusState: ListViewFocusTarget?

  init() {
    // needed for the protocol
  }

  var body: some Scene {
    WindowGroup {
      ContentView(
        selectedTab: $selectedTab,
        manager: manager,
        appEnv: appEnv  //,
          //        focusState: $focusState
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
        //        Button("Search") {
        //          focusState = .search
        //        }
        //        .keyboardShortcut("f")

        Divider()

        Button("Refresh Containers") {
          Task {
            _ = await appEnv.manager.fetchContainers()
            _ = await appEnv.manager.fetchImages()
          }
        }
        .keyboardShortcut("r")
      }
      CommandGroup(replacing: .help) { /* remove help */  }
      CommandGroup(replacing: .newItem) { /* remove new */  }
      CommandGroup(replacing: .saveItem) { /* remove save */  }
    }
  }
}
