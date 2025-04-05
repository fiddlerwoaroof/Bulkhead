import SwiftUI

struct SearchOptions {
  var caseSensitive = false
  var matchWholeWords = false
  // Command-F shortcut
  var keyboardShortcut: KeyEquivalent = "f"
  var modifiers: EventModifiers = .command
}

struct SearchField: View {
  let placeholder: String
  @Binding var text: String
  @FocusState.Binding var focusBinding: ListViewFocusTarget?
  let focusCase: ListViewFocusTarget
  let options: SearchOptions?

  var body: some View {
    HStack {
      Image(systemName: "magnifyingglass")
        .foregroundStyle(.secondary)
      TextField(placeholder, text: $text)
        .textFieldStyle(.plain)
        .onKeyPress(.escape) {
          DispatchQueue.main.async {
            text = ""
          }
          return .handled
        }
        .focused($focusBinding, equals: focusCase)

      if !text.isEmpty {
        Button(action: { text = "" }) {
          Image(systemName: "xmark.circle.fill")
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
      }
    }
    .padding(8)
    .background(.background)
  }
}
