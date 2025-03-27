import SwiftUI
import Foundation

struct DockerContainer: Identifiable, Codable {
    let id: String
    let name: String
    let image: String
    let status: String
}

class LogManager: ObservableObject {
    static let shared = LogManager()
    @Published var log: String = ""

    func append(_ entry: String) {
        DispatchQueue.main.async {
            self.log += "\n\(Date()): \(entry)"
        }
    }
}

class DockerEnvironmentDetector {
    static func detectDockerHostPath() -> String? {
        let potentialPaths = [
            "\(NSHomeDirectory())/.rd/docker.sock",
            "\(NSHomeDirectory())/.colima/docker.sock"
        ]
        for path in potentialPaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        return nil
    }
}





class DockerManager: ObservableObject {
    @Published var containers: [DockerContainer] = []
    @Published var socketPath: String = UserDefaults.standard.string(forKey: "dockerHostPath") ?? DockerEnvironmentDetector.detectDockerHostPath() ?? ""

    var executor: DockerExecutor? {
        socketPath.isEmpty ? nil : DockerExecutor(socketPath: socketPath)
    }

    init() {
        if socketPath.isEmpty, let detected = DockerEnvironmentDetector.detectDockerHostPath() {
            socketPath = detected
            saveDockerHostPath()
        }
    }

    func fetchContainers() {
        guard let executor = executor else { return }
        DispatchQueue.global().async {
            do {
                let list = try executor.listContainers()
                DispatchQueue.main.async {
                    self.containers = list
                }
            } catch {
                LogManager.shared.append("Fetch error: \(error.localizedDescription)")
            }
        }
    }

    func startContainer(id: String) {
        tryCommand { [weak self] in try self?.executor?.startContainer(id: id) }
    }

    func stopContainer(id: String) {
        tryCommand { [weak self] in try self?.executor?.stopContainer(id: id) }
    }

    private func tryCommand(_ block: @escaping () throws -> Void) {
        DispatchQueue.global().async {
            do {
                try block()
                DispatchQueue.main.async {
                    self.fetchContainers()
                }
            } catch {
                LogManager.shared.append("Command error: \(error.localizedDescription)")
            }
        }
    }

    func saveDockerHostPath() {
        UserDefaults.standard.set(socketPath, forKey: "dockerHostPath")
    }
}

struct SettingsView: View {
    @ObservedObject var manager: DockerManager

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Docker Socket Path")
                .font(.headline)
            TextField("Socket Path", text: $manager.socketPath)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            HStack {
                Button("Use Rancher Desktop") {
                    manager.socketPath = "\(NSHomeDirectory())/.rd/docker.sock"
                }
                Button("Use Colima") {
                    manager.socketPath = "\(NSHomeDirectory())/.colima/docker.sock"
                }
            }

            Button("Save") {
                manager.saveDockerHostPath()
                manager.fetchContainers()
            }
            Spacer()
        }
        .padding()
        .frame(width: 400, height: 200)
    }
}

struct LogWindow: View {
    @ObservedObject var logManager = LogManager.shared

    var body: some View {
        VStack(alignment: .leading) {
            Text("Docker Log")
                .font(.title2)
                .padding(.bottom, 5)
            ScrollView {
                TextEditor(text: $logManager.log)
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(6)
            }
            .frame(maxHeight: .infinity)
        }
        .padding()
        .frame(width: 600, height: 400)
    }
}

struct ContentView: View {
    @StateObject private var manager = DockerManager()
    @State private var showingSettings = false
    @State private var showingLog = false

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("DockerUI")
                    .font(.largeTitle)
                    .padding(.bottom, 10)
                Spacer()
                Button("Log") {
                    showingLog.toggle()
                }
                Button("Settings") {
                    showingSettings.toggle()
                }
            }

            List(manager.containers) { container in
                HStack {
                    VStack(alignment: .leading) {
                        Text(container.name)
                            .font(.headline)
                        Text(container.image)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        Text(container.status.capitalized)
                            .font(.caption)
                    }
                    Spacer()
                    if container.status.lowercased().contains("up") {
                        Button("Stop") {
                            manager.stopContainer(id: container.id)
                        }.buttonStyle(BorderlessButtonStyle())
                    } else {
                        Button("Start") {
                            manager.startContainer(id: container.id)
                        }.buttonStyle(BorderlessButtonStyle())
                    }
                }
                .padding(.vertical, 4)
            }

            HStack {
                Button("Refresh") {
                    manager.fetchContainers()
                }.padding(.top)
                Spacer()
            }
        }
        .padding()
        .frame(minWidth: 600, minHeight: 400)
        .onAppear {
            manager.fetchContainers()
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(manager: manager)
        }
        .sheet(isPresented: $showingLog) {
            LogWindow()
        }
    }
}

@main
struct DockerUIApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
