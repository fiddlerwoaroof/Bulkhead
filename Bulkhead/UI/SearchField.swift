import SwiftUI

struct SearchOptions {
  var caseSensitive = false
  var matchWholeWords = false
  // Command-F shortcut
  var keyboardShortcut: KeyEquivalent = "f"
  var modifiers: EventModifiers = .command
}

struct SearchConfiguration<T: Identifiable & Equatable> {
  let placeholder: String
  let filter: (T, String) -> Bool
  var options = SearchOptions()
}

struct SearchField<T: Identifiable & Equatable>: View {
  let config: SearchConfiguration<T>
  @Binding var text: String
  @FocusState.Binding var focusBinding: ListViewFocusTarget?
  let focusCase: ListViewFocusTarget

  var body: some View {
    HStack {
      Image(systemName: "magnifyingglass")
        .foregroundStyle(.secondary)
      TextField(config.placeholder, text: $text)
        .textFieldStyle(.plain)
        .onKeyPress(.escape) {
          print("NOTICE ME: search received escape")

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
