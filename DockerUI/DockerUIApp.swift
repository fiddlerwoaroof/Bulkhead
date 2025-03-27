import SwiftUI
import Foundation

struct DockerContainer: Identifiable, Codable {
    let id: String
    let names: [String]
    let image: String
    let status: String

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case names = "Names"
        case image = "Image"
        case status = "Status"
    }
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

struct SettingsWindow: Scene {
    @ObservedObject var manager: DockerManager

    var body: some Scene {
        Window("Settings", id: "Settings") {
            SettingsView(manager: manager)
        }
        .windowStyle(HiddenTitleBarWindowStyle())
    }
}

struct LogWindowScene: Scene {
    var body: some Scene {
        Window("Docker Log", id: "Log") {
            LogWindow()
        }
        .windowStyle(HiddenTitleBarWindowStyle())
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

            VStack(alignment: .leading, spacing: 10) {
                Text("Quick Configurations")
                    .font(.subheadline)
                    .bold()

                HStack {
                    Button("Use Rancher Desktop") {
                        manager.socketPath = "\(NSHomeDirectory())/.rd/docker.sock"
                    }
                    Button("Use Colima") {
                        manager.socketPath = "\(NSHomeDirectory())/.colima/docker.sock"
                    }
                }
            }

            HStack {
                Spacer()
                Button("Save") {
                    manager.saveDockerHostPath()
                    manager.fetchContainers()
                }
                .buttonStyle(.borderedProminent)
            }
            Spacer()
        }
        .padding()
        .frame(width: 450, height: 250)
        .background(Color(NSColor.windowBackgroundColor))
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
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct ContentView: View {
    @StateObject private var manager = DockerManager()

    var body: some View {
        ZStack {
            Color(NSColor.windowBackgroundColor)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("DockerUI")
                        .font(.largeTitle)
                        .bold()
                    Spacer()
                }
                .padding()

                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(manager.containers) { container in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(container.names.first ?? "Unnamed")
                                        .font(.headline)
                                    Text(container.image)
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                    Text(container.status.capitalized)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if container.status.lowercased().contains("up") {
                                    Button("Stop") {
                                        manager.stopContainer(id: container.id)
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                } else {
                                    Button("Start") {
                                        manager.startContainer(id: container.id)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.small)
                                }
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(10)
                            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }

                HStack {
                    Button("Refresh") {
                        manager.fetchContainers()
                    }
                    .controlSize(.regular)
                    .padding()
                    Spacer()
                }
            }
        }
        .frame(minWidth: 600, minHeight: 500)
        .onAppear {
            manager.fetchContainers()
        }
        .environmentObject(manager)
    }
}

@main
struct DockerUIApp: App {
    @StateObject private var manager = DockerManager()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(manager)
        }

        SettingsWindow(manager: manager)
        LogWindowScene()

        .commands {
            CommandMenu("DockerUI") {
                Button("Settings") {
                    openWindow(id: "Settings")
                }
                .keyboardShortcut(",")

                Button("Show Logs") {
                    openWindow(id: "Log")
                }
                .keyboardShortcut("l", modifiers: [.command, .shift])
            }
        }
    }
}
