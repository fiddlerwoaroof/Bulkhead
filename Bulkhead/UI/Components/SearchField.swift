import SwiftUI

public struct SearchField: View {
  let placeholder: String
  @Binding var text: String
  @Binding var isSearchFocused: Bool
  @FocusState private var isFocused: Bool

  public init(placeholder: String, text: Binding<String>, isSearchFocused: Binding<Bool>) {
    self.placeholder = placeholder
    self._text = text
    self._isSearchFocused = isSearchFocused
  }

  public var body: some View {
    HStack {
      Image(systemName: "magnifyingglass")
        .foregroundStyle(.secondary)
      TextField(placeholder, text: $text)
        .textFieldStyle(.plain)
        .focused($isFocused)
      if !text.isEmpty {
        Button {
          text = ""
        } label: {
          Image(systemName: "xmark.circle.fill")
            .foregroundStyle(.secondary)
        }
      }
    }
    .padding(8)
    .background(Color(.textBackgroundColor))
    .cornerRadius(8)
    .padding(.horizontal)
    .padding(.vertical, 8)
    .onChange(of: isFocused) { _, newValue in
      isSearchFocused = newValue
    }
    .onChange(of: isSearchFocused) { _, newValue in
      isFocused = newValue
    }
  }
}
