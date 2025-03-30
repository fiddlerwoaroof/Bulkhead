import SwiftUI

struct SearchField<T: Identifiable & Equatable, Master: View, Detail: View>: View {
  let placeholder: String
  @Binding var text: String
  var focusBinding: FocusState<ListViewFocusTarget?>.Binding
  let focusCase: ListViewFocusTarget

  var body: some View {
    HStack {
      Image(systemName: "magnifyingglass")
        .foregroundStyle(.secondary)
      TextField(placeholder, text: $text)
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
