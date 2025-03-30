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
  var searchConfig: SearchConfiguration<T>? = nil

  // Define focus states (reverting to AnyHashable approach)
  enum FocusField: Hashable {
    case search
    case item(AnyHashable) // Revert to using AnyHashable
  }
  @FocusState private var focusedField: FocusField?
  @State private var searchText = ""

  // Computed property for filtered items
  private var filteredItems: [T] {
    guard let config = searchConfig, !searchText.isEmpty else {
        return items
    }
    return items.filter { config.filter($0, searchText) }
  }

  private func selectNextItem() {
    let currentItems = filteredItems
    guard !currentItems.isEmpty else { return }

    if let currentIndex = currentItems.firstIndex(where: { $0.id == selectedItem?.id }) {
      if currentIndex < currentItems.count - 1 {
        selectedItem = currentItems[currentIndex + 1]
        if let newlySelectedItem = selectedItem {
            focusedField = .item(AnyHashable(newlySelectedItem.id)) // Revert assignment
        }
      }
    } else {
      selectedItem = currentItems[0]
      if let newlySelectedItem = selectedItem {
          focusedField = .item(AnyHashable(newlySelectedItem.id)) // Revert assignment
      }
    }
  }

  private func selectPreviousItem() {
    let currentItems = filteredItems
    guard !currentItems.isEmpty else { return }

    if let currentIndex = currentItems.firstIndex(where: { $0.id == selectedItem?.id }) {
      if currentIndex > 0 {
        selectedItem = currentItems[currentIndex - 1]
        if let newlySelectedItem = selectedItem {
            focusedField = .item(AnyHashable(newlySelectedItem.id)) // Revert assignment
        }
      }
    } else {
      selectedItem = currentItems[currentItems.count - 1]
      if let newlySelectedItem = selectedItem {
          focusedField = .item(AnyHashable(newlySelectedItem.id)) // Revert assignment
      }
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
        // Revert to single .focused modifier using AnyHashable
        .focused($focusedField, equals: .item(AnyHashable(item.id)))
        .onTapGesture {
          withAnimation {
            selectedItem = item
            focusedField = .item(AnyHashable(item.id)) // Revert assignment
          }
        }
    }
  }

  private var listContent: some View {
    ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(spacing: 8) {
          ForEach(filteredItems) { item in
            itemView(for: item)
          }
        }
        .padding(.vertical)
      }
      .onChange(of: selectedItem) { _, newItem in
        if let item = newItem {
          withAnimation {
            proxy.scrollTo(item.id, anchor: .center)
            focusedField = .item(AnyHashable(item.id)) // Revert assignment
          }
        }
      }
    }
  }

  var body: some View {
    NavigationSplitView {
      VStack(spacing: 0) {
        if let config = searchConfig {
            SearchField<T, Master, Detail>(
                placeholder: config.placeholder,
                text: $searchText,
                focusBinding: $focusedField,
                focusCase: .search
            )
            Divider()
        }
        listContent
      }
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
    .onKeyPress(.escape) {
        if focusedField == .search && !searchText.isEmpty {
            searchText = ""
            return .handled
        } else if focusedField != .search { 
            focusedField = .search
            return .handled
        }
        return .ignored
    }
    .onKeyPress(.return) {
      // Revert check to use pattern matching and casting
      if case .item(let itemIdHashable) = focusedField,
         let itemId = itemIdHashable.base as? T.ID,
         let currentItem = filteredItems.first(where: { $0.id == itemId }) {
        selectedItem = currentItem
        focusedField = .item(itemIdHashable)
        return .handled
      } else if focusedField == .search {
        if let firstItem = filteredItems.first {
          selectedItem = firstItem
          focusedField = .item(AnyHashable(firstItem.id)) // Revert assignment
          return .handled
        }
      }
      return .ignored
    }
  }
}
