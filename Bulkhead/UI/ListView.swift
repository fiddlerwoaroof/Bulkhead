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
  // Command-F shortcut
  var keyboardShortcut: KeyEquivalent = "f"
  var modifiers: EventModifiers = .command
}

struct SearchConfiguration<T> {
  let placeholder: String
  let filter: (T, String) -> Bool
  var options = SearchOptions()
}

struct ListView<T: Identifiable & Equatable, Master: View, Detail: View>: View {
  let items: [T]
  @Binding var selectedItem: T?
  var backgroundColor: Color
  var shadowColor: Color
  var searchConfig: SearchConfiguration<T>?
  var listError: DockerError?
  var listErrorTitle = "Error Loading List"
  @FocusState private var focusedField: ListViewFocusTarget?
  @StateObject private var viewState = ListViewState()
  @State private var selectionTask: Task<Void, Never>?
  @Binding var searchFocused: Bool
  @Environment(\.isGlobalErrorShowing) private var isGlobalErrorShowing
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
    // Add onHover to change cursor
    .onHover { isHovering in
      if isHovering {
        NSCursor.pointingHand.push()
      } else {
        NSCursor.pop()
      }
    }
  }

  private var listColumnContent: some View {
    VStack(spacing: 0) {
      // Show local list error ONLY if a global error isn't already showing
      if !isGlobalErrorShowing, let error = listError {
        ErrorView(error: error, title: listErrorTitle, style: .compact)
          .padding()
          .frame(maxHeight: .infinity)
      } else {
        if let config = searchConfig {
          SearchField<T, Master, Detail>(
            placeholder: config.placeholder,
            text: $viewState.searchText,
            focusBinding: $focusedField,
            focusCase: ListViewFocusTarget.search
          )
          Divider()
        }
        ScrollViewReader { proxy in
          ScrollView {
            LazyVStack(spacing: 8) {
              ForEach(filteredItems) { item in
                itemView(for: item)
              }
            }
            .padding(.vertical)
          }
          .onChange(of: searchFocused) { oldValue, newValue in
            if oldValue != newValue && newValue == true {
              focusedField = .search
            }
          }
          .onChange(of: selectedItem) { _, newItem in
            handleSelectionChange(newItem: newItem, proxy: proxy)
          }
        }
      }
    }
  }

  private func handleSelectionChange(newItem: T?, proxy: ScrollViewProxy) {
    selectionTask?.cancel()
    selectionTask = Task {
      do {
        try await Task.sleep(nanoseconds: 100_000_000)
        guard !Task.isCancelled else { return }

        if let item = newItem {
          await MainActor.run {
            withAnimation {
              proxy.scrollTo(item.id, anchor: .center)
              let newFocus: ListViewFocusTarget = .item(AnyHashable(item.id))
              focusedField = newFocus
            }
          }
        } else {
          if searchConfig != nil {
            await MainActor.run {
              focusedField = .search
            }
          }
        }
      } catch is CancellationError {
        // no action here
      } catch {
        print("Error during selection debounce sleep: \(error)")
      }
    }
  }

  var body: some View {
    NavigationSplitView {
      listColumnContent
        .onChange(of: focusedField) { _, newValue in
          viewState.lastKnownFocus = newValue
          if newValue != .search {
            searchFocused = false
          }
        }
        .onChange(of: items) { oldItems, newItems in
          if oldItems.isEmpty && !newItems.isEmpty && focusedField == nil {
            setupInitialFocus()
          }
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
      if focusedField == .search {
        return .handled
      }
      selectPreviousItem()
      return .handled
    }
    .onKeyPress(.escape) {
      if focusedField == ListViewFocusTarget.search && !viewState.searchText.isEmpty {
        DispatchQueue.main.async {
          viewState.searchText = ""
        }
        return .handled
      }
      if focusedField != ListViewFocusTarget.search {
        focusedField = ListViewFocusTarget.search
        return .handled
      }
      return .ignored
    }
    .onKeyPress(.return) {
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

  private func setupInitialFocus() {
    if focusedField == nil && !items.isEmpty {
      focusedField = .item(AnyHashable(items[0].id))
      selectedItem = items[0]
    } else if focusedField == nil && searchConfig != nil {
      focusedField = .search
    }
    viewState.lastKnownFocus = focusedField
  }
}
