import SwiftUI

struct SettingsView: View {
  @ObservedObject var manager: DockerManager
  @State private var showSavedConfirmation = false

  var body: some View {
    GeometryReader { geometry in
      ScrollView {
        VStack(alignment: .leading, spacing: 12) {
          Group {
            Text("Docker Socket Path")
              .font(.headline)
            TextField("Socket Path", text: $manager.socketPath)
              .textFieldStyle(.roundedBorder)
              .onChange(of: manager.socketPath) { _, newValue in
                handleSocketPathChange(newValue: newValue)
              }
          }

          Text("Quick Configuration")
            .font(.subheadline)
            .bold()
            .padding(.top, 8)

          HStack(spacing: 10) {
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
              manager.saveRefreshInterval()
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
      maxHeight: 300)
  }

  private func handleSocketPathChange(newValue: String) {
    manager.saveDockerHostPath()
    manager.fetchContainers()
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
