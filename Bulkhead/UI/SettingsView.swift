import SwiftUI

struct SettingsView: View {
  @ObservedObject var manager: DockerManager
  @State private var showSavedConfirmation = false
  @EnvironmentObject var appEnv: ApplicationEnvironment

  private var detectedEnvironment: String {
    DockerEnvironmentDetector.getEnvironmentDescription(logManager: appEnv.logManager)
  }

  var body: some View {
    GeometryReader { geometry in
      ScrollView {
        VStack(alignment: .leading, spacing: 12) {
          Group {
            Text("Docker Socket Path")
              .font(.headline)
            TextField("Socket Path", text: $manager.socketPath)
              .textFieldStyle(.roundedBorder)
              .onChange(of: manager.socketPath) { _, newPath in
                handleSocketPathChange(newValue: newPath)
              }

            Text("Detected Environment: \(detectedEnvironment)")
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }

          Text("Quick Configuration")
            .font(.subheadline)
            .bold()
            .padding(.top, 8)

          HStack(spacing: 10) {
            Button("Use Docker Desktop") {
              manager.socketPath = "/var/run/docker.sock"
            }
            .buttonStyle(.bordered)
            Button("Use Rancher Desktop") {
              manager.socketPath = "\(NSHomeDirectory())/.rd/docker.sock"
            }
            .buttonStyle(.bordered)
            Button("Use Colima") {
              manager.socketPath = "\(NSHomeDirectory())/.colima/docker.sock"
            }
            .buttonStyle(.bordered)
          }

          Group {
            Text("Refresh Interval: \(Int(manager.refreshInterval)) seconds")
              .font(.headline)
              .padding(.top, 12)
            Slider(value: $manager.refreshInterval, in: 5...60, step: 1) {
              Text("Refresh Interval")
            } onEditingChanged: { _ in
              handleRefreshIntervalChange(newValue: manager.refreshInterval)
            }
            .frame(maxWidth: 300)
          }

          if showSavedConfirmation {
            Text("✔ Saved")
              .foregroundStyle(.green)
              .transition(.opacity)
          }
        }
        .padding()
        .frame(maxWidth: min(geometry.size.width * 0.9, 500), alignment: .center)
        .frame(maxWidth: .infinity)
      }
    }
    .frame(
      minWidth: 400, idealWidth: 480, maxWidth: 500, minHeight: 250, idealHeight: 250,
      maxHeight: 300
    )
    .onChange(of: manager.socketPath) { _, newPath in
      handleSocketPathChange(newValue: newPath)
    }
    .onChange(of: manager.refreshInterval) { _, newInterval in
      handleRefreshIntervalChange(newValue: newInterval)
    }
  }

  private func handleSocketPathChange(newValue _: String) {
    Task {
      await manager.fetchContainers()
      await manager.fetchImages()
    }
    showSaved()
  }

  private func handleRefreshIntervalChange(newValue _: Double) {
    showSaved()
  }

  private func showSaved() {
    withAnimation {
      showSavedConfirmation = true
    }
    Task { @MainActor in
      try? await Task.sleep(for: .seconds(2))
      withAnimation {
        showSavedConfirmation = false
      }
    }
  }
}
