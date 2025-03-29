import SwiftUI

struct FilesystemBrowserView: View {
  let container: DockerContainer
  @EnvironmentObject var manager: DockerManager
  @State private var path: String = "/"
  @State private var entries: [FileEntry] = []
  @State private var hoveredEntry: FileEntry?

  var body: some View {
    VStack(alignment: .leading) {
      if !container.isRunning {
        Text(
          "This container is not running. Filesystem access requires the container to be started."
        )
        .foregroundColor(.secondary)
        .italic()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
      } else {

        HStack {
          Text("Path:")
          TextField("/", text: $path, onCommit: fetch)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .font(.system(.body, design: .monospaced))
          Button("Go", action: fetch)
        }
        .padding(.bottom, 4)

        List(entries) { entry in
          HStack {
            Image(systemName: entry.isDirectory ? "folder.fill" : "doc.text")
            Text(entry.name)
              .font(.system(.body, design: .monospaced))
          }
          .padding(.vertical, 2)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(
            hoveredEntry?.id == entry.id
              ? Color.accentColor.opacity(0.15)
              : Color.clear
          )
          .cornerRadius(4)
          .contentShape(Rectangle())
          .onHover { hovering in
            hoveredEntry = hovering ? entry : nil
          }
          .onTapGesture {
            if entry.name == ".." {
              path = (path as NSString).deletingLastPathComponent.normalizedPath()
              fetch()
            } else if entry.isDirectory {
              path = (path + "/" + entry.name.trimmingCharacters(in: ["/"])).normalizedPath()
              fetch()
            }
          }
        }
        .padding()
        .onAppear(perform: fetch)
      }
    }
  }

  private func fetch() {
    Task {
      do {
        let data = try manager.executor?.exec(
          containerId: container.id,
          command: ["sh", "-c", "ls -aF \"\(path)\""]
        )

        if let output = String(data: data ?? Data(), encoding: .utf8) {
          entries =
            output
            .split(separator: "\n")
            .map(String.init)
            .map { line in
              FileEntry(name: line, isDirectory: line.hasSuffix("/"))
            }
        } else {
          entries = [FileEntry(name: "<invalid UTF-8>", isDirectory: false)]
        }
      } catch {
        entries = [FileEntry(name: "Error: \(error.localizedDescription)", isDirectory: false)]
      }
    }
  }
}

extension DockerExecutor {
  func exec(containerId: String, command: [String]) throws -> Data {
    // 1. Create exec instance
    let execCreateBody: [String: Any] = [
      "AttachStdout": true,
      "AttachStderr": true,
      "Tty": false,
      "Cmd": command,
    ]

    let createData = try JSONSerialization.data(withJSONObject: execCreateBody, options: [])

    let createExecResponse = try makeRequest(
      path: "/v1.41/containers/\(containerId)/exec",
      method: "POST",
      body: createData
    )

    let execId = try JSONDecoder().decode([String: String].self, from: createExecResponse)["Id"]!

    // 2. Start the exec session
    let startBody: [String: Any] = [
      "Detach": false,
      "Tty": false,
    ]

    let startData = try JSONSerialization.data(withJSONObject: startBody, options: [])

    let output = try makeRequest(
      path: "/v1.41/exec/\(execId)/start",
      method: "POST",
      body: startData
    )

    return output
  }
}

struct FileEntry: Identifiable, Hashable {
  var id: String { name }
  let name: String
  let isDirectory: Bool
}
extension String {
  func normalizedPath() -> String {
    NSString(string: self).standardizingPath
  }
}

extension DockerContainer {
  var isRunning: Bool {
    status.lowercased().contains("up")
  }
}
