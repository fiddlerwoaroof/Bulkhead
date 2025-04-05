import SwiftUI

struct ImageSummaryView: View {
  let image: DockerImage

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
  }
}
