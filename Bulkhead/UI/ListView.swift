import SwiftUI

// Define focus states outside the view struct
enum ListViewFocusTarget: Hashable {
  case search
  case item(AnyHashable)
}

// ObservableObject to hold state that needs to persist
class ListViewState: ObservableObject {
  @Published var lastKnownFocus: ListViewFocusTarget?
  @Published var searchText = ""
}

struct SearchOptions {
  var caseSensitive = false
  var matchWholeWords = false
  var keyboardShortcut: KeyEquivalent = "f"
  var modifiers: EventModifiers = .command
}

struct SearchConfiguration<T> {
  let placeholder: String
  let filter: (T, String) -> Bool
  var options = SearchOptions()
}

struct ListView<T: Identifiable & Equatable, Master: View, Detail: View>: View {
  @Binding var items: [T]
  @Binding var selectedItem: T?
  var backgroundColor: Color
  var shadowColor: Color
  var searchConfig: SearchConfiguration<T>?
  @FocusState private var focusedField: ListViewFocusTarget?
  @StateObject private var viewState = ListViewState()
  @State private var selectionTask: Task<Void, Never>?  // Task for debouncing
  @ViewBuilder var content: (T) -> Master
  @ViewBuilder var detail: (T) -> Detail

  // Computed property for filtered items
  private var filteredItems: [T] {
    // Read searchText from viewState
    guard let config = searchConfig, !viewState.searchText.isEmpty else {
      return items
    }
    // Use viewState.searchText for filtering
    return items.filter { config.filter($0, viewState.searchText) }
  }

  private func selectNextItem() {
    let currentItems = filteredItems
    guard !currentItems.isEmpty else { return }

    if let currentIndex = currentItems.firstIndex(where: { $0.id == selectedItem?.id }) {
      if currentIndex < currentItems.count - 1 {
        // Move to next item if not the last one
        selectedItem = currentItems[currentIndex + 1]
        if let newlySelectedItem = selectedItem {
          let newFocus: ListViewFocusTarget = .item(AnyHashable(newlySelectedItem.id))
          focusedField = newFocus
        }
      } else {
        // Already at the last item, do nothing
      }
    } else if let firstItem = currentItems.first {
      // If no item is selected, select the first one (should focus be set here too?)
      selectedItem = firstItem
      if let newlySelectedItem = selectedItem {
        let newFocus: ListViewFocusTarget = .item(AnyHashable(newlySelectedItem.id))
        focusedField = newFocus
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
          let newFocus: ListViewFocusTarget = .item(AnyHashable(newlySelectedItem.id))
          focusedField = newFocus
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

    // Revert to HStack structure
    return HStack {
      content(item)
        .padding()  // Padding inside the background
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    // Apply background and shape styling to the HStack
    .background(isSelected ? backgroundColor.opacity(0.8) : backgroundColor)
    .cornerRadius(10)
    .overlay(
      RoundedRectangle(cornerRadius: 10)
        .stroke(isSelected ? Color.accentColor.opacity(0.7) : .clear, lineWidth: 1.5)
    )
    .shadow(color: shadowColor, radius: 2, x: 0, y: 1)
    // Modifiers applied to the HStack
    .contentShape(Rectangle())  // Explicitly define the shape for interaction
    .padding(.horizontal)  // Padding outside the background/shadow for spacing
    .id(item.id)
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits(.isButton)
    .focusable(true)  // <<< Make the HStack itself focusable
    .focused($focusedField, equals: .item(AnyHashable(item.id)))  // Bind focus state
    .onTapGesture {  // Use tap gesture for selection
      withAnimation {
        let newFocus: ListViewFocusTarget = .item(AnyHashable(item.id))
        selectedItem = item
        focusedField = newFocus
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
                  let newFocus: ListViewFocusTarget = .item(AnyHashable(item.id))
                  focusedField = newFocus
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
            text: $viewState.searchText,
            focusBinding: $focusedField,
            focusCase: ListViewFocusTarget.search
          )
          Divider()
        }
        listContent
      }
      .onChange(of: focusedField) { _, newValue in
        viewState.lastKnownFocus = newValue
      }
      .navigationSplitViewColumnWidth(min: 250, ideal: 320, max: 800)
      .onAppear {
        // Use persisted focus state from viewState if available
        if let initialFocus = viewState.lastKnownFocus {
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if focusedField == nil {
              focusedField = initialFocus
            }
          }
        } else if let firstItem = items.first {
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if focusedField == nil {
              focusedField = .item(AnyHashable(firstItem.id))
            }
          }
        } else if searchConfig != nil {
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if focusedField == nil {
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
          let newFocus: ListViewFocusTarget = .item(AnyHashable(firstItem.id))
          focusedField = newFocus
          selectedItem = firstItem
          return .handled
        }
        return .handled
      }
      selectNextItem()
      return .handled
    }
    .onKeyPress(.upArrow) {
      // If focus is on search, do nothing
      if focusedField == .search {
        return .handled  // Keep focus in search field
      }
      // Otherwise, perform normal upward navigation
      selectPreviousItem()
      return .handled
    }
    .onKeyPress(.escape) {
      if focusedField == ListViewFocusTarget.search && !viewState.searchText.isEmpty {  // Read from viewState
        viewState.searchText = ""  // Write to viewState
        return .handled
      }
      if focusedField != ListViewFocusTarget.search {
        focusedField = ListViewFocusTarget.search
        return .handled
      }
      return .ignored
    }
    .onKeyPress(.return) {
      // Revert check to use pattern matching and casting
      if case .item(let itemIdHashable) = focusedField,
        let itemId = itemIdHashable.base as? T.ID,
        let currentItem = filteredItems.first(where: { $0.id == itemId })
      {
        selectedItem = currentItem
        focusedField = .item(itemIdHashable)
        return .handled
      }
      if focusedField == .search {
        if let firstItem = filteredItems.first {
          let newFocus: ListViewFocusTarget = .item(AnyHashable(firstItem.id))
          focusedField = newFocus
          selectedItem = firstItem
          return .handled
        }
      }
      return .ignored
    }
  }
}
