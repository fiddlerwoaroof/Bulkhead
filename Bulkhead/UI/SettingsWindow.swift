import SwiftUI

// This file defines the Scene for the Settings window
struct SettingsWindow: Scene {
    // Accept the instances needed by SettingsView
    let manager: DockerManager
    let publication: DockerPublication
    let logManager: LogManager
    // Removed StateObject<ApplicationEnvironment>

    // Implicit init will be used by DockerUIApp

    var body: some Scene {
        Window("Settings", id: "settings") {
            // Initialize SettingsView with the required instances
            SettingsView(manager: manager, logManager: logManager)
                // Inject publication for SettingsView to observe
                .environmentObject(publication)
        }
        .windowResizability(.contentSize)
    }
}
