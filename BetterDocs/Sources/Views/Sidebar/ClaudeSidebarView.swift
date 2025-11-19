import SwiftUI

// Floating version of the document outline for overlay on preview
struct FloatingDocumentOutlineView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        if let selectedItem = appState.selectedItem as? Document,
           selectedItem.type == .markdown,
           let content = selectedItem.content,
           appState.isOutlineVisible {

            DocumentOutlineView(
                markdownContent: content,
                isVisible: Binding(
                    get: { appState.isOutlineVisible },
                    set: { _ in appState.toggleOutline() }
                ),
                onHeadingClick: { headingId in
                    scrollToHeading(headingId)
                }
            )
            .frame(width: 200)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.95))
                    .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
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

// Legacy sidebar view - kept for compatibility if needed elsewhere
struct ClaudeSidebarView: View {
    @Environment(AppState.self) private var appState
    @State private var claudeResponse: String = ""
    @State private var isLoadingResponse: Bool = false
    @State private var isResponseExpanded: Bool = true
    @State private var showResponse: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Pending Edits at the top
            AnnotationTagsView(
                onSendToClaude: { handleSendToClaude() }
            )

            // Claude Response Section
            if showResponse {
                ClaudeResponseView(
                    response: claudeResponse,
                    isLoading: isLoadingResponse,
                    isExpanded: $isResponseExpanded,
                    onDismiss: { dismissResponse() }
                )
            }

            Spacer()
        }
        .background(Color(NSColor.textBackgroundColor))
    }

    private func handleSendToClaude() {
        let prompt = appState.generateClaudePromptWithFileContent()
        print("📤 Sending to Claude:\n\(prompt)")

        // Reset and show response area
        claudeResponse = ""
        isLoadingResponse = true
        showResponse = true
        isResponseExpanded = true

        // Collect the file paths that will be modified
        let affectedFiles = Set(appState.annotations
            .filter { $0.status == .pending }
            .map { $0.filePath })

        // Send to Claude service
        Task { @MainActor in
            do {
                // Mark annotations as processing
                for annotation in appState.annotations where annotation.status == .pending {
                    appState.updateAnnotationStatus(annotation.id, status: .sent)
                }

                // Send message to Claude via the service
                let stream = try await appState.claudeService.sendMessageStreaming(prompt, context: nil)

                var fullResponse = ""
                for await chunk in stream {
                    fullResponse += chunk
                    claudeResponse = fullResponse
                }

                isLoadingResponse = false
                print("✅ Claude response received:\n\(fullResponse)")

                // Mark annotations as complete
                for annotation in appState.annotations where annotation.status == .sent {
                    appState.updateAnnotationStatus(annotation.id, status: .completed)
                }

                print("✅ Files modified by Claude. Annotations marked as complete.")
                print("📝 Modified files: \(affectedFiles.joined(separator: ", "))")
            } catch {
                print("❌ Error sending to Claude: \(error)")
                isLoadingResponse = false
                claudeResponse = "Error: \(error.localizedDescription)"

                // Revert annotations back to pending on error
                for annotation in appState.annotations where annotation.status == .sent {
                    appState.updateAnnotationStatus(annotation.id, status: .pending)
                }
            }
        }
    }

    private func dismissResponse() {
        showResponse = false
        claudeResponse = ""
        isLoadingResponse = false
    }
}

// MARK: - Claude Response View
struct ClaudeResponseView: View {
    let response: String
    let isLoading: Bool
    @Binding var isExpanded: Bool
    let onDismiss: () -> Void

    private func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(response, forType: .string)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "bubble.left.fill")
                    .foregroundColor(.blue)
                Text("Claude Response")
                    .font(.headline)
                Spacer()

                // Copy button
                Button(action: { copyToClipboard() }) {
                    Image(systemName: "doc.on.doc")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Copy response")
                .disabled(response.isEmpty || isLoading)

                // Expand/Collapse button
                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)

                // Dismiss button
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Response content (collapsible)
            if isExpanded {
                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Processing request...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                    .frame(height: 150)
                } else {
                    ScrollView {
                        Text(response.isEmpty ? "Waiting for response..." : response)
                            .font(.system(size: 12))
                            .foregroundColor(.primary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                    }
                    .frame(maxHeight: 300)
                }

                Divider()
            }
        }
    }
}

#Preview("Floating Outline") {
    FloatingDocumentOutlineView()
        .environment(AppState())
        .frame(width: 300, height: 400)
}

#Preview("Sidebar") {
    ClaudeSidebarView()
        .environment(AppState())
        .frame(width: 350, height: 600)
}
