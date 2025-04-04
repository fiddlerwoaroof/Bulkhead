import Foundation
import SwiftUI

struct ContainerSummaryView: View {
  var container: DockerContainer

  let manager: DockerManager
  let appEnv: ApplicationEnvironment

  var body: some View {
    HStack {
      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: 8) {
          Text(container.names.first ?? "Unnamed")
            .font(.headline)
        }
        if container.status.lowercased().contains("up") {
          StatusBadgeView(text: container.status, color: .green)
        } else {
          StatusBadgeView(text: container.status, color: .secondary)
        }
        Text(container.image)
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
      Spacer()
      ContainerActionsView(container: container, manager: manager)
    }
  }
}

// New View for Status Badge
struct StatusBadgeView: View {
  let text: String
  let color: Color

  var body: some View {
    HStack(spacing: 4) {
      Image(systemName: color == .green ? "checkmark.circle.fill" : "stop.circle.fill")
        .foregroundStyle(color)
      Text(text)
        .font(.caption)
        .foregroundStyle(color)
    }
    .padding(.horizontal, 6)
    .padding(.vertical, 2)
    .background(color.opacity(0.15))
    .clipShape(RoundedRectangle(cornerRadius: 4))
  }
}

// New View for Container Actions
struct ContainerActionsView: View {
  @Environment(\.openWindow) private var openWindow
  let container: DockerContainer
  let manager: DockerManager
  @EnvironmentObject var publication: DockerPublication  // Use ObservedObject if manager might change
  @State private var isActionPending = false  // State for loading indicator

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      // Start/Stop Button or Progress Indicator
      Group {
        if isActionPending {
          ProgressView()
            .controlSize(.small)
            .frame(width: 50, height: 15)  // Approximate button size
        } else if container.status.lowercased().contains("up") {
          Button("Stop") {
            isActionPending = true
            Task {
              await manager.stopContainer(id: container.id)
              // Let list refresh handle final state, just reset pending
              isActionPending = false
            }
          }
          .buttonStyle(.bordered)
          .controlSize(.small)
          .disabled(isActionPending)  // Disable button while pending
          .onHover { isHovering in
            if isHovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
          }
        } else {
          Button("Start") {
            isActionPending = true
            Task {
              await manager.startContainer(id: container.id)
              // Let list refresh handle final state, just reset pending
              isActionPending = false
            }
          }
          .buttonStyle(.borderedProminent)
          .controlSize(.small)
          .disabled(isActionPending)  // Disable button while pending
          .onHover { isHovering in
            if isHovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
          }
        }
      }
      .frame(height: 20)  // Ensure consistent height for button/progress

      // Logs Button
      Button("Logs") {
        openWindow(value: container)
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
      .disabled(isActionPending)  // Optionally disable Logs button during action
      .onHover { isHovering in
        if isHovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
      }
    }
  }
}
