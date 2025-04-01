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
  let initialPath: String
  let appEnv: ApplicationEnvironment
  @EnvironmentObject var logManager: LogManager
  @EnvironmentObject var publication: DockerPublication
  @State private var path = "/"
  @State private var entries: [FileEntry] = []
  @State private var hoveredEntry: FileEntry?
  @State private var currentTask: Task<Void, Never>?
  @State private var isExecuting = false
  @State private var fetchError: DockerError?

  private var manager: DockerManager { appEnv.manager }
  var hoveredId: String? { hoveredEntry?.id }

  init(container: DockerContainer, appEnv: ApplicationEnvironment, initialPath: String? = nil) {
    self.container = container
    self.initialPath = initialPath ?? "/"
    self.appEnv = appEnv
  }

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

  private func isSymlinkDirectory(_ path: String) async throws -> Bool {
    guard let executor = publication.executor else { throw DockerError.noExecutor }
    let data = try await executor.exec(
      containerId: container.id,
      command: ["sh", "-c", "test -d \"\(path)\" && echo yes || echo no"],
      addCarriageReturn: false
    )

    return String(data: data, encoding: .utf8)?.trimmingCharacters(
      in: .whitespacesAndNewlines) == "yes"
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      if !container.isRunning {
        ErrorView(error: DockerError.containerNotRunning, style: .prominent)
          .padding()
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
      } else {
        HStack {
          Text("Path:")
          TextField(
            "/", text: $path,
            onCommit: {
              Task { await fetch() }
            }
          )
          .textFieldStyle(RoundedBorderTextFieldStyle())
          .font(.system(.body, design: .monospaced))
          Button("Go") {
            Task { await fetch() }
          }
        }
        .padding()

        Divider()

        ZStack {
          if let error = fetchError {
            ErrorView(error: error, style: .prominent)
              .padding()
              .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
          } else if entries.isEmpty && isExecuting {
            ProgressView("Loading directory...")
              .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
          } else {
            ScrollView {
              LazyVStack(alignment: .leading, spacing: 4) {
                ForEach(displayedEntries) { entry in
                  FilesystemRow(
                    entry: entry,
                    isSelected: false,
                    isHovered: hoveredId == entry.id
                  )
                  .accessibilityAddTraits(.isButton)
                  .onTapGesture {
                    Task {
                      await handleTap(on: entry)
                    }
                  }
                  .onHover { _ in
                    hoveredEntry = entry
                  }
                }
              }
              .padding(.horizontal)
            }
            .frame(minHeight: 250)
          }
        }
        .onAppear {
          Task {
            await fetch()
          }
        }
      }
    }
    .onChange(of: container.isRunning) { _, isNowRunning in
      if isNowRunning && fetchError != nil {
        Task {
          await setupAndFetch()
        }
      }
    }
    .onChange(of: hoveredEntry) { _, newValue in
      DispatchQueue.main.async {
        if let entry = newValue {
          if entry.isDirectory {
            NSCursor.pointingHand.push()
          }
        } else {
          NSCursor.pop()

        }
      }
    }
    .task(id: container.id) {
      await setupAndFetch()
    }
    .onChange(of: initialPath) { oldPath, newPath in
      if oldPath != newPath {
        path = newPath
        Task { await setupAndFetch() }
      }
    }
  }

  private func setupAndFetch() async {
    currentTask?.cancel()
    currentTask = nil
    fetchError = nil
    entries = []
    isExecuting = false
    await fetch()
  }

  private func handleTap(on entry: FileEntry) async {
    guard !isExecuting else { return }
    do {
      if entry.name == ".." {
        path = (path as NSString).deletingLastPathComponent.normalizedPath()
        await fetch()
      } else if entry.isDirectory {
        path = (path + "/" + entry.name).normalizedPath()
        await fetch()
      } else if entry.isSymlink {
        let fullPath =
          (path + "/"
            + entry.name.trimmingCharacters(in: CharacterSet(charactersIn: "@")))
        if try await isSymlinkDirectory(fullPath) {
          path = fullPath.normalizedPath()
          await fetch()
        }
      }
    } catch let dockerError as DockerError {
      fetchError = dockerError
      logManager.addLog(
        "Error handling tap in FilesystemBrowser: \(dockerError.localizedDescription)",
        level: "ERROR")
    } catch {
      fetchError = .unknownError(error)
      logManager.addLog(
        "Unknown error handling tap in FilesystemBrowser: \(error.localizedDescription)",
        level: "ERROR")
    }
  }

  private func fetch() async {
    guard container.isRunning else {
      isExecuting = false
      entries = []
      fetchError = DockerError.containerNotRunning
      return
    }

    guard let executor = publication.executor else {
      await MainActor.run { fetchError = .noExecutor }
      isExecuting = false
      return
    }

    currentTask?.cancel()

    currentTask = Task {
      isExecuting = true
      fetchError = nil
      entries = []

      do {
        try await Task.sleep(nanoseconds: 100_000_000)

        if Task.isCancelled {
          isExecuting = false
          return
        }

        let queryPath = path.hasSuffix("/") ? path : path + "/"
        let data = try await executor.exec(
          containerId: container.id,
          command: ["sh", "-c", "ls -AF --color=never \"\(queryPath)\""],
          addCarriageReturn: false
        )

        if Task.isCancelled {
          isExecuting = false
          return
        }

        if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(
          in: .whitespacesAndNewlines)
        {
          let parsedEntries = output.split(separator: "\n", omittingEmptySubsequences: true)
            .compactMap {
              line -> FileEntry? in
              let name = String(line).trimmingCharacters(in: .whitespacesAndNewlines)
              guard !name.isEmpty else { return nil }
              let isDir = name.hasSuffix("/")
              let isLink = name.hasSuffix("@")
              let isExec = name.hasSuffix("*")
              let cleanName = name.trimmingCharacters(in: CharacterSet(charactersIn: "/@*"))
              guard cleanName != "." else { return nil }
              return FileEntry(
                name: cleanName,
                isDirectory: isDir,
                isSymlink: isLink,
                isExecutable: isExec
              )
            }
          await MainActor.run {
            entries = parsedEntries
            fetchError = nil
          }
        } else {
          throw DockerError.responseParsingFailed(
            NSError(
              domain: "FilesystemBrowser", code: 1,
              userInfo: [NSLocalizedDescriptionKey: "Invalid UTF-8 output from ls command"]))
        }
      } catch let dockerError as DockerError {
        await MainActor.run { fetchError = dockerError }
        logManager.addLog(
          "DockerError fetching filesystem: \(dockerError.localizedDescription)", level: "ERROR")
      } catch {
        await MainActor.run { fetchError = .unknownError(error) }
        logManager.addLog(
          "Unknown error fetching filesystem: \(error.localizedDescription)", level: "ERROR")
      }
      await MainActor.run { isExecuting = false }
    }
  }
}
