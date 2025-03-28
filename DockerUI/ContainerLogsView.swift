import SwiftTerm
import SwiftUI

struct TerminalWrapper: NSViewRepresentable {
  let container: DockerContainer
  @ObservedObject var manager: DockerManager

  class Coordinator: NSObject, TerminalDelegate {
    func send(source _: Terminal, data _: ArraySlice<UInt8>) {
      // no interaction
    }
  }

  func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  func makeNSView(context _: Context) -> TerminalView {
    let terminalView = TerminalView(frame: .zero)
    terminalView.configureNativeColors()
    _ = terminalView.becomeFirstResponder()
    fetchLogs(into: terminalView.getTerminal())
    return terminalView
  }

  func updateNSView(_: TerminalView, context _: Context) {
    // nothing goes here
  }

  private func fetchLogs(into terminal: Terminal) {
    guard let executor = manager.executor else {
      terminal.feed(text: "No executor available.\n")
      return
    }

    DispatchQueue.global().async {
      do {
        let result = try executor.makeRequest(
          path: "/v1.41/containers/\(container.id)/logs?stdout=true&stderr=true&tail=100")
        DispatchQueue.main.async {
          terminal.feed(text: "\u{001B}[38;2;255;100;0m24bit color test\u{001B}[0m\n")
          terminal.feed(byteArray: [UInt8](result))
        }
      } catch {
        DispatchQueue.main.async {
          terminal.feed(text: "Error: \(error.localizedDescription)\n")
        }
      }
    }
  }
}

struct ContainerLogsView: View {
  let container: DockerContainer
  @ObservedObject var manager: DockerManager

  var body: some View {
    TerminalWrapper(container: container, manager: manager)
      .navigationTitle(container.names.first ?? "Logs")
      .frame(minWidth: 600, minHeight: 400)
  }
}

struct ContainerLogsWindow: Scene {
  let container: DockerContainer
  @ObservedObject var manager: DockerManager

  var body: some Scene {
    Window(container.names.first ?? "Logs", id: "logs_\(container.id)") {
      ContainerLogsView(container: container, manager: manager)
    }
    .defaultSize(width: 640, height: 400)
  }
}
