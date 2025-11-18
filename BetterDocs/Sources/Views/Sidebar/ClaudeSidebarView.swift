import SwiftUI

struct ClaudeSidebarView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 0) {
            // Document Outline (at the top)
            if let selectedItem = appState.selectedItem as? Document,
               selectedItem.type == .markdown,
               let content = selectedItem.content {
                DocumentOutlineView(
                    markdownContent: content,
                    isVisible: Binding(
                        get: { appState.isOutlineVisible },
                        set: { _ in appState.toggleOutline() }
                    ),
                    onHeadingClick: { headingId in
                        // Scroll to heading - we'll implement this
                        scrollToHeading(headingId)
                    }
                )
                Divider()
            }

            // Annotation Tags
            AnnotationTagsView()

            Spacer()

            // Chat launcher button
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    appState.isChatOpen = true
                }
            }) {
                HStack {
                    Image(systemName: "brain")
                        .foregroundColor(.accentColor)
                    Text("Open Chat")
                        .font(.headline)
                    Spacer()
                    Text("Press /")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(4)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .padding()
        }
        .background(Color(NSColor.textBackgroundColor))
    }

    private func scrollToHeading(_ headingId: String) {
        // Post notification to scroll to heading in the preview
        NotificationCenter.default.post(
            name: NSNotification.Name("ScrollToHeading"),
            object: nil,
            userInfo: ["headingId": headingId]
        )
    }
}

#Preview {
    ClaudeSidebarView()
        .environment(AppState())
        .frame(width: 350, height: 600)
}
