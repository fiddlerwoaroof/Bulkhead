import SwiftUI

struct ListView<T: Identifiable, Master: View, Detail: View>: View {
  @Binding var items: [T]
  @Binding var selectedItem: T?
  var backgroundColor: Color
  var shadowColor: Color
  @ViewBuilder var content: (T) -> Master
  @ViewBuilder var detail: (T) -> Detail

  var body: some View {
    NavigationSplitView {
      ScrollView {
        LazyVStack(spacing: 8) {
          ForEach(items) { item in
            HStack {
              content(item)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(backgroundColor)
                .cornerRadius(10)
                .overlay(
                  RoundedRectangle(cornerRadius: 10)
                    .stroke(selectedItem?.id == item.id ? Color.accentColor : .clear, lineWidth: 2)
                )
                .shadow(color: shadowColor, radius: 2, x: 0, y: 1)
                .padding(.horizontal)
                .accessibilityAddTraits(.isButton)
                .onTapGesture {
                  withAnimation {
                    selectedItem = item
                  }
                }
            }
          }
        }
        .padding(.vertical)
      }
      //      .background(Color(NSColor.windowBackgroundColor))
      .navigationSplitViewColumnWidth(min: 250, ideal: 320, max: 800)  // <- ADDED

    } detail: {
      if let selected = selectedItem {
        detail(selected)
      } else {
        Text("Select an item to view details")
          .foregroundColor(.secondary)
      }
    }

  }
}
