import SwiftUI

struct ErrorView: View {
    
    enum DisplayStyle {
        case prominent // Full box with icon, title, description, suggestion
        case compact   // Minimal, inline style (e.g., icon + description)
    }
    
    let error: LocalizedError
    var title: String? // Optional title
    var style: DisplayStyle = .prominent // Default to prominent

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

    // Original prominent style view body
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
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.red.opacity(0.3), lineWidth: 1)
        )
    }
    
    // New compact style view body
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
    // Example usage with a sample error
    enum PreviewError: Error, LocalizedError {
        case sampleConnectionError
        
        var errorDescription: String? {
            "Could not connect to the server. The network might be unavailable."
        }
        var recoverySuggestion: String? {
            "Please check your network connection and try again. Ensure the server address is correct."
        }
    }
    
    return ScrollView { VStack(alignment: .leading, spacing: 20) {
        Text("Prominent Style:")
        ErrorView(error: PreviewError.sampleConnectionError)
        ErrorView(error: PreviewError.sampleConnectionError, title: "Connection Failed")
        
        Divider()
        
        Text("Compact Style:")
        ErrorView(error: PreviewError.sampleConnectionError, style: .compact)
        ErrorView(error: PreviewError.sampleConnectionError, title: "Connection Failed", style: .compact)
    }
    .padding()
    }
}
