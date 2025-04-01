import SwiftUI

struct SettingsView: View {
  @EnvironmentObject var publication: DockerPublication
  let manager: DockerManager
  let logManager: LogManager
  @State private var showSavedConfirmation = false

  private var detectedEnvironment: String {
    DockerEnvironmentDetector.getEnvironmentDescription(logManager: logManager)
  }

  private var socketPathBinding: Binding<String> {
    Binding(
      get: { publication.socketPath },
      set: { publication.socketPath = $0; manager.saveSocketPath(); showSaved() }
    )
  }
  
  private var refreshIntervalBinding: Binding<Double> {
    Binding(
      get: { publication.refreshInterval },
      set: { publication.refreshInterval = $0; manager.saveRefreshInterval(); showSaved() }
    )
  }

  var body: some View {
    GeometryReader { geometry in
      ScrollView {
        VStack(alignment: .leading, spacing: 15) {
          Text("Docker Settings")
            .font(.title)
            .padding(.bottom, 10)

          VStack(alignment: .leading) {
            TextField("Docker Socket Path", text: socketPathBinding)

            Text("Detected Environment: \(detectedEnvironment)")
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }

          Text("Quick Configuration")
            .font(.headline)
            .padding(.top, 8)

          HStack(spacing: 10) {
            Button("Use Docker Desktop") {
              publication.socketPath = "/var/run/docker.sock"
              manager.saveSocketPath()
              showSaved()
            }
            .buttonStyle(.bordered)
            Button("Use Rancher Desktop") {
              publication.socketPath = "\(NSHomeDirectory())/.rd/docker.sock"
              manager.saveSocketPath()
              showSaved()
            }
            .buttonStyle(.bordered)
            Button("Use Colima") {
              publication.socketPath = "\(NSHomeDirectory())/.colima/docker.sock"
              manager.saveSocketPath()
              showSaved()
            }
            .buttonStyle(.bordered)
          }
          .padding(.bottom, 10)

          Divider()

          VStack(alignment: .leading) {
            Text("Auto-Refresh Interval (seconds)")
              .font(.headline)
            Slider(
              value: refreshIntervalBinding,
              in: 1...60,
              step: 1
            )
            Text("\(publication.refreshInterval, specifier: "%.0f") seconds")
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }
          .padding(.top, 10)
          
          if showSavedConfirmation {
            Text("Settings Saved")
              .foregroundStyle(.green)
              .transition(.opacity.combined(with: .slide))
          }
        }
        .padding()
        .frame(width: geometry.size.width * 0.8, alignment: .center)
        .frame(maxWidth: .infinity)
      }
    }
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
