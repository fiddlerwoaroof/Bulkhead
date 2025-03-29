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
        let fetcher = LogFetcher(executor: executor)
        let result = try fetcher.fetchLogs(for: container.id, stream: .stdout)
          
        DispatchQueue.main.async {
            for chunk in result {
                debugPrintBytes(chunk)
                terminal.feed(byteArray: chunk)
            }
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

func debugPrintBytes(_ bytes: [UInt8], label: String = "DEBUG") {
    let asString = String(bytes: bytes, encoding: .utf8) ?? "<invalid utf8>"
    let asHex = bytes.map { String(format: "%02x", $0) }.joined(separator: " ")
    print("[\(label)] UTF-8: \(asString)")
    print("[\(label)] HEX: \(asHex)")
}
