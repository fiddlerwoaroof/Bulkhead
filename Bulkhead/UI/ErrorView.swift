import SwiftUI

// Define a structure for actionable error elements
struct ErrorAction {
    let label: String
    let action: () -> Void
}

struct ErrorView: View {
    
    enum DisplayStyle {
        case prominent // Full box with icon, title, description, suggestion, actions
        case compact   // Minimal, inline style (e.g., icon + description)
    }
    
    let error: LocalizedError
    var title: String? // Optional title
    var style: DisplayStyle = .prominent // Default to prominent
    var actions: [ErrorAction]? // Optional array of actions

    var body: some View {
        Group {
            switch style {
            case .prominent:
                prominentBody
            case .compact:
                compactBody
            }
        }
    }

    // Prominent style view body with actions
    private var prominentBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.octagon.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .foregroundColor(.red)
                
                Text(title ?? "Error")
                    .font(.headline)
                    .foregroundColor(.red)
            }

            if let description = error.errorDescription {
                Text(description)
                    .font(.body)
            }

            if let recovery = error.recoverySuggestion {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Suggestion:")
                        .font(.caption.weight(.semibold))
                    Text(recovery)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)
            }
            
            // Display actions if provided
            if let actions = actions, !actions.isEmpty {
                HStack(spacing: 8) {
                    Spacer() // Push buttons to the right
                    ForEach(actions.indices, id: \.self) { index in
                        Button(actions[index].label) {
                            actions[index].action()
                        }
                        // Optionally add styling like .buttonStyle(.bordered)
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.red.opacity(0.3), lineWidth: 1)
        )
    }
    
    // Compact style view body (no actions shown in compact mode)
    private var compactBody: some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.circle.fill") // Smaller icon
                .foregroundColor(.red)
            
            if let description = error.errorDescription {
                Text(description)
                    .font(.callout) // Slightly smaller font
                    .foregroundColor(.red)
            } else {
                Text(title ?? "Error") // Fallback to title if no description
                    .font(.callout)
                    .foregroundColor(.red)
            }
        }
        .padding(.vertical, 2) // Minimal padding
    }
}

#Preview {
    // Example usage with a sample error and actions
    enum PreviewError: Error, LocalizedError {
        case sampleConnectionError
        case sampleAuthError

        var errorDescription: String? {
            switch self {
            case .sampleConnectionError: "Could not connect to the server. Network might be unavailable."
            case .sampleAuthError: "Authentication failed. Invalid credentials."
            }
        }
        var recoverySuggestion: String? {
            switch self {
            case .sampleConnectionError: "Check network connection and server address."
            case .sampleAuthError: "Please check your username and password."
            }
        }
    }
    
    // Example actions
    let retryAction = ErrorAction(label: "Retry") { print("Retry tapped") }
    let settingsAction = ErrorAction(label: "Settings") { print("Settings tapped") }
    
    return ScrollView {
        VStack(alignment: .leading, spacing: 20) {
            Text("Prominent Style (No Actions):").font(.title2)
            ErrorView(error: PreviewError.sampleConnectionError)
            
            Divider()
            
            Text("Prominent Style (With Actions):").font(.title2)
            ErrorView(error: PreviewError.sampleConnectionError, title: "Connection Failed", actions: [retryAction, settingsAction])
            ErrorView(error: PreviewError.sampleAuthError, title: "Auth Failed", actions: [retryAction])
            
            Divider()
            
            Text("Compact Style:").font(.title2)
            ErrorView(error: PreviewError.sampleConnectionError, style: .compact)
            // Note: Actions are not displayed in compact style
            ErrorView(error: PreviewError.sampleAuthError, title: "Auth Failed", style: .compact, actions: [retryAction])
        }
        .padding()
    }
}
