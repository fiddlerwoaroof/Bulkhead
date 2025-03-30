import BulkheadCore
import BulkheadUI
import SwiftUI

struct ImageListView: View {
  var backgroundColor: Color
  var shadowColor: Color
  @Binding var images: [DockerImage]
  @Binding var isSearchFocused: Bool
  @State private var selectedImage: DockerImage?
  @State private var searchText = ""

  private var filteredImages: [DockerImage] {
    guard !searchText.isEmpty else { return images }
    let searchQuery = searchText.lowercased()
    return images.filter { image in
      // Search in repo tags
      if let tags = image.RepoTags {
        return tags.contains { tag in
          tag.lowercased().contains(searchQuery)
        }
      }
      // Search in ID
      return image.Id.lowercased().contains(searchQuery)
    }
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
    VStack(spacing: 0) {
      SearchField(
        placeholder: "Search images...",
        text: $searchText,
        isSearchFocused: $isSearchFocused
      )
      Divider()

      ListView(
        items: .constant(filteredImages),
        selectedItem: $selectedImage,
        backgroundColor: backgroundColor,
        shadowColor: shadowColor
      ) { image in
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
          Text(image.Id.prefix(12))
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      } detail: { image in
        ImageDetailView(image: image)
          .id(image.id)
      }
    }
  }
}
