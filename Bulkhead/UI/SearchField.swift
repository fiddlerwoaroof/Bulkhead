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

struct SearchField<T: Identifiable & Equatable, Master: View>: View {
  let config: SearchConfiguration<T>
  @Binding var text: String
  var focusBinding: FocusState<ListViewFocusTarget?>.Binding
  let focusCase: ListViewFocusTarget

  var body: some View {
    HStack {
      Image(systemName: "magnifyingglass")
        .foregroundStyle(.secondary)
      TextField(config.placeholder, text: $text)
        .textFieldStyle(.plain)
        .focused(focusBinding, equals: focusCase)
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
