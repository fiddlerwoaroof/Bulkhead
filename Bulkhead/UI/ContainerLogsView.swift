import SwiftTerm
import SwiftUI

final class TerminalSessionManager {
  let terminal: Terminal
  let executor: DockerExecutor
  let containerID: String

  init(terminal: Terminal, executor: DockerExecutor, containerID: String) {
    self.terminal = terminal
    self.executor = executor
    self.containerID = containerID
  }

  func start() {
    DispatchQueue.global(qos: .userInitiated).async {
      do {
        let fetcher = LogFetcher(executor: self.executor)
        let logs = try fetcher.fetchLogs(for: self.containerID, stream: .stdout)

        DispatchQueue.main.async {
          for chunk in logs {
            self.terminal.feed(byteArray: chunk)
          }
        }
      } catch {
        DispatchQueue.main.async {
          self.terminal.feed(text: "Error: \(error.localizedDescription)\n")
        }
      }
    }
  }
}

struct TerminalWrapper: NSViewRepresentable {
  let configure: (Terminal) -> Void

  func makeNSView(context _: Context) -> TerminalView {
    let terminalView = TerminalView(frame: .zero)
    terminalView.configureNativeColors()
    _ = terminalView.becomeFirstResponder()
    configure(terminalView.getTerminal())
    return terminalView
  }

  func updateNSView(_: TerminalView, context _: Context) {
    // No updates needed as the terminal view is configured once during creation
  }
}

struct ContainerLogsView: View {
  let container: DockerContainer
  //  let manager: DockerManager
  @EnvironmentObject var publication: DockerPublication
  @Environment(\.isGlobalErrorShowing) private var isGlobalErrorShowing

  private var connectionError: DockerError? {
    if isGlobalErrorShowing {
      return publication.containerListError
        ?? DockerError.connectionFailed(
          NSError(
            domain: "Bulkhead", code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Docker connection unavailable."]))
    }
    if publication.executor == nil {
      return DockerError.noExecutor
    }
    return nil
  }

  var body: some View {
    Group {
      if let error = connectionError {
        ErrorView(error: error, title: "Cannot Fetch Logs")
          .padding()
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else if let executor = publication.executor {
        TerminalWrapper { terminal in
          TerminalSessionManager(
            terminal: terminal,
            executor: executor,
            containerID: container.id
          ).start()
        }
      } else {
        Text("Unexpected state: Executor unavailable but no connection error detected.")
          .padding()
      }
    }
    .navigationTitle(container.names.first ?? "Logs")
    .frame(minWidth: 600, minHeight: 400)
  }
}
