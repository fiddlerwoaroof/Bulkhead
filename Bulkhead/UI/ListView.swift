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
  var initialFocus: FocusField? = nil

  // Define focus states (reverting to AnyHashable approach)
  enum FocusField: Hashable {
    case search
    case item(AnyHashable) // Revert to using AnyHashable
  }
  @FocusState private var focusedField: FocusField?
  @State private var searchText = ""
  @State private var selectionTask: Task<Void, Never>? = nil // Task for debouncing

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
        // Move to next item if not the last one
        selectedItem = currentItems[currentIndex + 1]
        if let newlySelectedItem = selectedItem {
            focusedField = .item(AnyHashable(newlySelectedItem.id))
        }
      } else {
          // Already at the last item, do nothing
      }
    } else if let firstItem = currentItems.first {
        // If no item is selected, select the first one (should focus be set here too?)
        selectedItem = firstItem
        if let newlySelectedItem = selectedItem {
            focusedField = .item(AnyHashable(newlySelectedItem.id))
        }
    }
  }

  private func selectPreviousItem() {
    let currentItems = filteredItems
    guard !currentItems.isEmpty else { return }

    if let currentIndex = currentItems.firstIndex(where: { $0.id == selectedItem?.id }) {
      if currentIndex > 0 {
        // Move to previous item if not the first one
        selectedItem = currentItems[currentIndex - 1]
        if let newlySelectedItem = selectedItem {
            focusedField = .item(AnyHashable(newlySelectedItem.id))
        }
      } else {
          // If already at the first item, move focus to the search field
          focusedField = .search
      }
    } else if let firstItem = currentItems.first {
        // If no item is selected, but list is not empty, select first and focus search
        // This case might be less common with the new down arrow logic, but handles edge cases
        selectedItem = firstItem
        focusedField = .search
    } else {
        // If list is empty or no selection, focus search
        focusedField = .search
    }
  }

  private func itemView(for item: T) -> some View {
    let isSelected = selectedItem?.id == item.id

    return HStack {
      content(item)
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        // Use a slightly different background for selected item
        .background(isSelected ? backgroundColor.opacity(0.8) : backgroundColor)
        .cornerRadius(10)
        .overlay(
          // Keep stroke for selection for now, but could change to focus
          // Or remove stroke and rely solely on system focus ring + background change
          RoundedRectangle(cornerRadius: 10)
            // Stroke based on selection OR focus? Let's try SELECTION for clarity
            // .stroke(isFocused ? Color.accentColor : .clear, lineWidth: 2)
            .stroke(isSelected ? Color.accentColor.opacity(0.7) : .clear, lineWidth: 1.5)
        )
        .shadow(color: shadowColor, radius: 2, x: 0, y: 1)
        .padding(.horizontal)
        .id(item.id)
        .accessibilityAddTraits(.isButton)
        // Keep the focus state binding
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
          // Cancel any previous task
          selectionTask?.cancel()

          // Create a new debounced task
          selectionTask = Task {
              do {
                  // Wait for 100ms
                  try await Task.sleep(nanoseconds: 100_000_000)
                  
                  // Check if cancelled during the sleep
                  guard !Task.isCancelled else { return }

                  // --- Actions to perform after debounce --- 
                  if let item = newItem {
                      // Scroll and update focus (UI updates on main actor)
                      await MainActor.run { 
                          withAnimation {
                              proxy.scrollTo(item.id, anchor: .center)
                              focusedField = .item(AnyHashable(item.id))
                          }
                      }
                      // TODO: Trigger any data fetching or other actions for the new item here
                      // Example: manager.fetchDetails(for: item.id)
                  } else {
                      // Handle deselection (e.g., focus search field)
                      if searchConfig != nil {
                          await MainActor.run {
                             focusedField = .search
                          }
                      }
                  }
                  // --- End Actions --- 

              } catch is CancellationError {
                  // Task was cancelled, normal operation
              } catch {
                  // Handle other potential errors from sleep
                  print("Error during selection debounce sleep: \(error)")
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
      .onAppear {
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
              if let focusTarget = initialFocus {
                  focusedField = focusTarget
              } else if focusedField == nil, let firstItem = filteredItems.first {
                  focusedField = .item(AnyHashable(firstItem.id))
              } else if focusedField == nil && filteredItems.isEmpty {
                    if searchConfig != nil {
                        focusedField = .search
                    }
              }
          }
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
      if focusedField == .search {
          if let firstItem = filteredItems.first {
              focusedField = .item(AnyHashable(firstItem.id))
              selectedItem = firstItem
              return .handled
          } else {
              return .handled
          }
      }
      selectNextItem()
      return .handled
    }
    .onKeyPress(.upArrow) {
      // If focus is on search, do nothing
      if focusedField == .search {
          return .handled // Keep focus in search field
      }
      // Otherwise, perform normal upward navigation
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
