import SwiftUI

public struct ListView<Item: Identifiable & Hashable, Content: View, Detail: View>: View {
  let items: Binding<[Item]>
  let selectedItem: Binding<Item?>
  let backgroundColor: Color
  let shadowColor: Color
  let content: (Item) -> Content
  let detail: (Item) -> Detail

  public init(
    items: Binding<[Item]>,
    selectedItem: Binding<Item?>,
    backgroundColor: Color,
    shadowColor: Color,
    @ViewBuilder content: @escaping (Item) -> Content,
    @ViewBuilder detail: @escaping (Item) -> Detail
  ) {
    self.items = items
    self.selectedItem = selectedItem
    self.backgroundColor = backgroundColor
    self.shadowColor = shadowColor
    self.content = content
    self.detail = detail
  }

  public var body: some View {
    NavigationSplitView {
      List(items.wrappedValue, selection: selectedItem) { item in
        content(item)
      }
      .listStyle(.plain)
      .background(backgroundColor)
    } detail: {
      if let item = selectedItem.wrappedValue {
        detail(item)
      } else {
        Text("Select an item")
          .foregroundStyle(.secondary)
      }
    }
    .background(backgroundColor)
  }
}
