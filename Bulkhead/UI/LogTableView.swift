import AppKit
import SwiftUI

class LogTableViewCoordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate {
  var entries: [LogEntry] = [] {
    didSet {
      DispatchQueue.main.async {
        self.tableView?.reloadData()
      }
    }
  }
  weak var tableView: NSTableView?

  func numberOfRows(in _: NSTableView) -> Int { entries.count }

  func tableView(_: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
    let entry = entries[row]
    guard let identifier = tableColumn?.identifier else { return nil }
    let text: String
    let color: NSColor

    switch identifier.rawValue {
    case "Timestamp":
      text = entry.timestamp
      color = .secondaryLabelColor
    case "Level":
      text = entry.level
      color = .textColor
    case "Source":
      text = entry.source
      color = .textColor
    case "Message":
      text = entry.message
      color = .textColor
    default:
      return nil
    }

    let textField = NSTextField(labelWithString: text)
    textField.textColor = color
    textField.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
    textField.lineBreakMode = .byWordWrapping
    textField.setContentHuggingPriority(.defaultLow, for: .horizontal)
    textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    return textField
  }

  func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
    let entry = entries[row]
    let maxWidth = tableView.frame.size.width
    let estimatedCharWidth: CGFloat = 7.0
    let charsPerLine = maxWidth / estimatedCharWidth
    let maxLines = CGFloat(entry.message.count) / charsPerLine + 1
    return max(20, maxLines * 20)
  }
}

struct LogTableView: NSViewRepresentable {
  @EnvironmentObject private var logManager: LogManager

  func makeCoordinator() -> LogTableViewCoordinator {
    let coordinator = LogTableViewCoordinator()
    coordinator.entries = logManager.logs
    return coordinator
  }

  func makeNSView(context: Context) -> NSScrollView {
    let scrollView = NSScrollView()
    scrollView.hasVerticalScroller = true

    let tableView = NSTableView()
    context.coordinator.tableView = tableView

    tableView.usesAlternatingRowBackgroundColors = true
    tableView.allowsColumnReordering = false
    tableView.allowsColumnResizing = true
    tableView.allowsMultipleSelection = false
    tableView.headerView = NSTableHeaderView()

    let timestampColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Timestamp"))
    timestampColumn.title = "Timestamp"
    timestampColumn.width = 200
    timestampColumn.resizingMask = .userResizingMask

    let levelColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Level"))
    levelColumn.title = "Level"
    levelColumn.width = 80
    levelColumn.resizingMask = .userResizingMask

    let sourceColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Source"))
    sourceColumn.title = "Source"
    sourceColumn.width = 150
    sourceColumn.resizingMask = .userResizingMask

    let messageColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Message"))
    messageColumn.title = "Message"
    messageColumn.minWidth = 400
    messageColumn.resizingMask = .autoresizingMask

    tableView.addTableColumn(timestampColumn)
    tableView.addTableColumn(levelColumn)
    tableView.addTableColumn(sourceColumn)
    tableView.addTableColumn(messageColumn)

    tableView.delegate = context.coordinator
    tableView.dataSource = context.coordinator

    scrollView.documentView = tableView

    // Observe log changes
    _ = logManager.$logs.sink { logs in
      context.coordinator.entries = logs
    }

    return scrollView
  }

  func updateNSView(_ nsView: NSScrollView, context: Context) {
    guard let tableView = nsView.documentView as? NSTableView else { return }
    context.coordinator.entries = logManager.logs
    tableView.reloadData()
  }
}

struct LogWindowScene: Scene {
  var body: some Scene {
    Window("Docker Log", id: "Log") {
      LogTableView()
        .frame(minWidth: 600, minHeight: 400)
    }
  }
}
