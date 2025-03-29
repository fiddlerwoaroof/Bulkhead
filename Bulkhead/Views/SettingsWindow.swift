import SwiftUI

struct SettingsWindow: Scene {
  @ObservedObject var manager: DockerManager

  var body: some Scene {
    Window("Settings", id: "Settings") {
      SettingsView(manager: manager)
    }
    .windowResizability(.contentSize)
    .defaultSize(width: 480, height: 250)
  }
}
