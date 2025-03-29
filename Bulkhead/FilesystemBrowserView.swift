import SwiftUI

struct FileEntry: Identifiable, Hashable {
  var id: String { name }
  let name: String
  let isDirectory: Bool
  let isSymlink: Bool
  let isExecutable: Bool
}

extension DockerContainer {
  var isRunning: Bool {
    status.lowercased().contains("up")
  }
}

extension String {
  func normalizedPath() -> String {
    let components = self.split(separator: "/").reduce(into: [String]()) { acc, part in
      switch part {
      case "", ".":
        break
      case "..":
        if !acc.isEmpty { acc.removeLast() }
      default:
        acc.append(String(part))
      }
    }
    return "/" + components.joined(separator: "/")
  }
}

struct FilesystemRow: View {
  let entry: FileEntry
  let isSelected: Bool
  let isHovered: Bool

  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: iconName)
        .foregroundStyle(iconColor)
        .accessibilityLabel(iconAccessibilityLabel)

      Text(entry.name)
        .font(.system(.body, design: .monospaced))
        .foregroundStyle(.primary)

      Spacer()

      if entry.isExecutable {
        Text("exec")
          .font(.caption2)
          .foregroundStyle(.green)
          .padding(.horizontal, 4)
          .padding(.vertical, 2)
          .background(.green.opacity(0.15))
          .clipShape(RoundedRectangle(cornerRadius: 4))
      }

      if entry.isSymlink {
        Text("link")
          .font(.caption2)
          .foregroundStyle(.orange)
          .padding(.horizontal, 4)
          .padding(.vertical, 2)
          .background(.orange.opacity(0.15))
          .clipShape(RoundedRectangle(cornerRadius: 4))
      }
    }
    .padding(.vertical, 6)
    .padding(.horizontal)
    .background(
      RoundedRectangle(cornerRadius: 8)
        .fill(
          isSelected
            ? Color.accentColor.opacity(0.2) : isHovered ? Color.gray.opacity(0.05) : Color.clear)
    )
    .contentShape(Rectangle())
  }

  private var iconName: String {
    if entry.isDirectory { return "folder.fill" }
    if entry.isSymlink { return "arrow.triangle.branch" }
    return "doc.text"
  }

  private var iconColor: Color {
    if entry.isDirectory { return .accentColor }
    if entry.isSymlink { return .orange }
    return .secondary
  }

  private var iconAccessibilityLabel: String {
    if entry.isDirectory { return "Folder" }
    if entry.isSymlink { return "Symbolic link" }
    return "File"
  }
}

struct FilesystemBrowserView: View {
  let container: DockerContainer
  @EnvironmentObject var manager: DockerManager
  @State private var path = "/"
  @State private var entries: [FileEntry] = []
  @State private var hoveredID: String?

  private var displayedEntries: [FileEntry] {
    if path == "/" {
      entries
    } else {
      [
        FileEntry(
          name: "..",
          isDirectory: true,
          isSymlink: false,
          isExecutable: false)
      ] + entries
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
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
        .padding()

        Divider()

        ScrollView {
          LazyVStack(alignment: .leading, spacing: 4) {
            ForEach(displayedEntries) { entry in
              FilesystemRow(
                entry: entry,
                isSelected: false,
                isHovered: hoveredID == entry.id
              )
              .accessibilityAddTraits(.isButton)
              .onTapGesture {
                if entry.name == ".." {
                  path = (path as NSString).deletingLastPathComponent.normalizedPath()
                  fetch()
                } else if entry.isDirectory {
                  path = (path + "/" + entry.name.trimmingCharacters(in: ["/"])).normalizedPath()
                  fetch()
                }
              }
              .onHover { hovering in
                hoveredID = hovering ? entry.id : nil
              }
            }
          }
          .padding(.horizontal)
        }
        .frame(minHeight: 250)
        .onAppear(perform: fetch)
      }
    }
  }

  private func fetch() {
    Task {
      do {
        let data = try manager.executor?.exec(
          containerId: container.id,
          command: ["sh", "-c", "ls -AF --color=never \"\(path)\""]
        )

        if let output = String(data: data ?? Data(), encoding: .utf8) {
          entries = output.split(separator: "\n").compactMap { line -> FileEntry? in
            let name = String(line)
            let isDir = name.hasSuffix("/")
            let isLink = name.hasSuffix("@")
            let isExec = name.hasSuffix("*")
            return FileEntry(
              name: name, isDirectory: isDir, isSymlink: isLink, isExecutable: isExec)
          }
        } else {
          entries = [
            FileEntry(
              name: "<invalid UTF-8>", isDirectory: false, isSymlink: false, isExecutable: false)
          ]
        }
      } catch {
        entries = [
          FileEntry(
            name: "Error: \(error.localizedDescription)", isDirectory: false, isSymlink: false,
            isExecutable: false)
        ]
      }
    }
  }
}
