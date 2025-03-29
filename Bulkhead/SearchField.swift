import SwiftUI

struct SearchField: View {
  let placeholder: String
  @Binding var text: String
  @FocusState private var isFocused: Bool
  @Binding var isSearchFocused: Bool

  var body: some View {
    HStack {
      Image(systemName: "magnifyingglass")
        .foregroundStyle(.secondary)
      TextField(placeholder, text: $text)
        .textFieldStyle(.plain)
        .focused($isFocused)
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
    .onChange(of: isFocused) { _, newValue in
      isSearchFocused = newValue
    }
    .onChange(of: isSearchFocused) { _, newValue in
      isFocused = newValue
    }
  }
} 