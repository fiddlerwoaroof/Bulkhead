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

struct ListView<T: Identifiable, Master: View, Detail: View>: View {
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
    
    if let currentIndex = filteredItems.firstIndex(where: { $0.id == selectedItem?.id }) {
      // If we have a selection, try to move to next item
      if currentIndex < filteredItems.count - 1 {
        selectedItem = filteredItems[currentIndex + 1]
      }
    } else {
      // If no selection, select first item
      selectedItem = filteredItems[0]
    }
  }
  
  private func selectPreviousItem() {
    guard !filteredItems.isEmpty else { return }
    
    if let currentIndex = filteredItems.firstIndex(where: { $0.id == selectedItem?.id }) {
      // If we have a selection, try to move to previous item
      if currentIndex > 0 {
        selectedItem = filteredItems[currentIndex - 1]
      }
    } else {
      // If no selection, select last item
      selectedItem = filteredItems[filteredItems.count - 1]
    }
  }

  var body: some View {
    NavigationSplitView {
      VStack(spacing: 0) {
        if searchConfig != nil {
          searchField
          Divider()
        }
        
        ScrollView {
          LazyVStack(spacing: 8) {
            ForEach(filteredItems) { item in
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
    .keyboardShortcut(
      searchConfig?.options.keyboardShortcut ?? "f",
      modifiers: searchConfig?.options.modifiers ?? .command
    )
    .onKeyPress(.downArrow) {
      selectNextItem()
      return .handled
    }
    .onKeyPress(.upArrow) {
      selectPreviousItem()
      return .handled
    }
  }
}
