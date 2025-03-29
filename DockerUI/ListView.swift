import SwiftUI

struct ListView<T, Content>: View where T: Identifiable, Content: View {
  @Binding var items: [T]
  var backgroundColor: Color
  var shadowColor: Color

  let content: (T) -> Content

  var body: some View {
    ScrollView {
      LazyVStack(spacing: 8) {
        ForEach(items) { item in
          content(item)
            .padding()
            .background(backgroundColor)
            .cornerRadius(10)
            .shadow(color: shadowColor, radius: 2, x: 0, y: 1)
            .padding(.horizontal)
        }
      }
      .padding(.vertical)
    }
  }
}
