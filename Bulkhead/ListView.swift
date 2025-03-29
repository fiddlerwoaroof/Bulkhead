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
  var searchConfig: SearchConfiguration<T>?
  @Binding var isSearchFocused: Bool
  @ViewBuilder var content: (T) -> Master
  @ViewBuilder var detail: (T) -> Detail

  @State private var searchText = ""
  @FocusState private var searchFieldFocused: Bool
  @FocusState private var focusedItemId: AnyHashable?

  private var filteredItems: [T] {
    guard let config = searchConfig, !searchText.isEmpty else { return items }
    return items.filter { config.filter($0, searchText) }
  }

  private var searchField: some View {
    HStack {
      Image(systemName: "magnifyingglass")
        .foregroundStyle(.secondary)
      TextField(searchConfig?.placeholder ?? "Search...", text: $searchText)
        .textFieldStyle(.plain)
        .focused($searchFieldFocused)
      if !searchText.isEmpty {
        Button(action: { searchText = "" }) {
          Image(systemName: "xmark.circle.fill")
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
      }
    }
    .padding(8)
    .background(.background)
    .onChange(of: searchFieldFocused) { _, newValue in
      isSearchFocused = newValue
    }
    .onChange(of: isSearchFocused) { _, newValue in
      searchFieldFocused = newValue
    }
  }

  private func selectNextItem() {
    guard !filteredItems.isEmpty else { return }

    searchFieldFocused = false

    if let currentIndex = filteredItems.firstIndex(where: { $0.id == selectedItem?.id }) {
      if currentIndex < filteredItems.count - 1 {
        selectedItem = filteredItems[currentIndex + 1]
        focusedItemId = selectedItem?.id
      }
    } else {
      selectedItem = filteredItems[0]
      focusedItemId = selectedItem?.id
    }
  }

  private func selectPreviousItem() {
    guard !filteredItems.isEmpty else { return }

    searchFieldFocused = false

    if let currentIndex = filteredItems.firstIndex(where: { $0.id == selectedItem?.id }) {
      if currentIndex > 0 {
        selectedItem = filteredItems[currentIndex - 1]
        focusedItemId = selectedItem?.id
      }
    } else {
      selectedItem = filteredItems[filteredItems.count - 1]
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
            searchFieldFocused = false
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
            focusedItemId = item.id
          }
        }
      }
    }
  }

  var body: some View {
    NavigationSplitView {
      VStack(spacing: 0) {
        if searchConfig != nil {
          searchField
          Divider()
        }

        listContent
          .navigationSplitViewColumnWidth(min: 250, ideal: 320, max: 800)
      }
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
      if searchFieldFocused, let first = filteredItems.first {
        selectedItem = first
        searchFieldFocused = false
        focusedItemId = first.id
        return .handled
      } else if let selected = selectedItem {
        focusedItemId = selected.id
        return .handled
      }
      return .ignored
    }
    .onKeyPress(.escape) {
      searchText = ""
      searchFieldFocused = false
      return .handled
      return .ignored
    }
  }
}
