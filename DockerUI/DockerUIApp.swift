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
                LogManager.shared.addLog("Fetch error: \(error.localizedDescription)")
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
                LogManager.shared.addLog("Command error: \(error.localizedDescription)")
            }
        }
    }

    func saveDockerHostPath() {
        UserDefaults.standard.set(socketPath, forKey: "dockerHostPath")
    }
}

struct ContentView: View {
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var manager = DockerManager()

    var backgroundColor: Color {
        colorScheme == .dark ? Color(NSColor.controlBackgroundColor) : Color.white
    }

    var shadowColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.2) : Color.black.opacity(0.05)
    }

    var body: some View {
        ZStack {
            Color(NSColor.windowBackgroundColor)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
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
                            .background(backgroundColor)
                            .cornerRadius(10)
                            .shadow(color: shadowColor, radius: 2, x: 0, y: 1)
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
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
                    manager.fetchContainers()
                }
                .keyboardShortcut("r")
            }
            CommandGroup(replacing: .help) {}
            CommandGroup(replacing: .newItem) {}
            CommandGroup(replacing: .saveItem) {}
        }
    }
}
