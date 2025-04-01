import SwiftUI

struct ImageListView: View {
  var backgroundColor: Color
  var shadowColor: Color
  @Binding var images: [DockerImage]
  @Binding var searchFocused: Bool
  @Binding var selectedImage: DockerImage?
  let manager: DockerManager

  private var imageSearchConfig: SearchConfiguration<DockerImage> {
    SearchConfiguration(
      placeholder: "Search images...",
      filter: { image, query in
        let searchQuery = query.lowercased()
        // Search in repo tags
        if let tags = image.RepoTags {
          if tags.contains(where: { $0.lowercased().contains(searchQuery) }) {
            return true
          }
        }
        // Search in ID (shortened, prefix match)
        let idToSearch =
          (image.Id.starts(with: "sha256:") ? String(image.Id.dropFirst(7)) : image.Id).lowercased()
        return idToSearch.prefix(searchQuery.count) == searchQuery
      }
    )
  }

  private func formatSize(_ size: Int) -> String {
    let formatter = ByteCountFormatter()
    formatter.countStyle = .file
    return formatter.string(fromByteCount: Int64(size))
  }

  private func formatDate(_ timestamp: Int) -> String {
    let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .full
    return formatter.localizedString(for: date, relativeTo: Date())
  }

  var body: some View {
    ListView(
      items: $images,
      selectedItem: $selectedImage,
      backgroundColor: backgroundColor,
      shadowColor: shadowColor,
      searchConfig: imageSearchConfig,
      listError: manager.imageListError,
      listErrorTitle: "Failed to Load Images",
      searchFocused: $searchFocused
    ) { image in
      // Type erase the content view
      AnyView(
        HStack {
          VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
              Image(systemName: "photo")
                .foregroundStyle(.secondary)
              Text(image.RepoTags?.first ?? "<none>")
                .font(.headline)
            }

            if let tags = image.RepoTags, tags.count > 1 {
              Text("\(tags.count - 1) more tags")
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
              Text(formatSize(image.Size))
                .font(.caption)
                .foregroundStyle(.secondary)
              Text("•")
                .font(.caption)
                .foregroundStyle(.secondary)
              Text("Created \(formatDate(image.Created))")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
          Spacer()
          Text(
            (image.Id.starts(with: "sha256:") ? String(image.Id.dropFirst(7)) : image.Id).prefix(12)
          )
          .font(.caption.monospaced())
          .foregroundStyle(.secondary)
        }
      )
    } detail: { image in
      // Type erase the detail view
      ImageDetailView(image: image)
    }

    .onChange(of: images) { _, newImages in
      if selectedImage == nil && !newImages.isEmpty {
        selectedImage = newImages.first
      }
    }
  }
}
