import SwiftUI

struct SearchOptions {
  var caseSensitive: Bool = false
  var matchWholeWords: Bool = false
  var keyboardShortcut: KeyEquivalent = "f"
  var modifiers: EventModifiers = .command
}

struct SearchConfiguration<T> {
  let placeholder: String
  let filter: (T, String) -> Bool
  var options: SearchOptions = SearchOptions()
}

struct ListView<T: Identifiable & Equatable, Master: View, Detail: View>: View {
  @Binding var items: [T]
  @Binding var selectedItem: T?
  var backgroundColor: Color
  var shadowColor: Color
  @ViewBuilder var content: (T) -> Master
  @ViewBuilder var detail: (T) -> Detail

  @FocusState private var focusedItemId: AnyHashable?

  private func selectNextItem() {
    guard !items.isEmpty else { return }

    if let currentIndex = items.firstIndex(where: { $0.id == selectedItem?.id }) {
      if currentIndex < items.count - 1 {
        selectedItem = items[currentIndex + 1]
        focusedItemId = selectedItem?.id
      }
    } else {
      selectedItem = items[0]
      focusedItemId = selectedItem?.id
    }
  }

  private func selectPreviousItem() {
    guard !items.isEmpty else { return }

    if let currentIndex = items.firstIndex(where: { $0.id == selectedItem?.id }) {
      if currentIndex > 0 {
        selectedItem = items[currentIndex - 1]
        focusedItemId = selectedItem?.id
      }
    } else {
      selectedItem = items[items.count - 1]
      focusedItemId = selectedItem?.id
    }
  }

  private func itemView(for item: T) -> some View {
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
        .id(item.id)
        .accessibilityAddTraits(.isButton)
        .focused($focusedItemId, equals: item.id)
        .onTapGesture {
          withAnimation {
            selectedItem = item
            focusedItemId = item.id
          }
        }
    }
  }

  private var listContent: some View {
    ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(spacing: 8) {
          ForEach(items) { item in
            itemView(for: item)
          }
        }
        .padding(.vertical)
      }
      .onChange(of: selectedItem) { _, newItem in
        if let item = newItem {
          withAnimation {
            proxy.scrollTo(item.id, anchor: .center)
            focusedItemId = item.id
          }
        }
      }
    }
  }

  var body: some View {
    NavigationSplitView {
      listContent
        .navigationSplitViewColumnWidth(min: 250, ideal: 320, max: 800)
    } detail: {
      if let selected = selectedItem {
        detail(selected)
      } else {
        Text("Select an item to view details")
          .foregroundColor(.secondary)
      }
    }
    .onKeyPress(.downArrow) {
      selectNextItem()
      return .handled
    }
    .onKeyPress(.upArrow) {
      selectPreviousItem()
      return .handled
    }
    .onKeyPress(.return) {
      if let selected = selectedItem {
        focusedItemId = selected.id
        return .handled
      }
      return .ignored
    }
  }
}
