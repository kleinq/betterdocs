import SwiftUI

struct AnnotationTagsView: View {
    @Environment(AppState.self) private var appState
    var onSendToClaude: (() -> Void)? = nil

    var body: some View {
        let pendingAnnotations = appState.annotations.filter { $0.status == .pending }

        if !pendingAnnotations.isEmpty {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Image(systemName: "tag.fill")
                        .foregroundColor(.orange)
                    Text("Pending Edits (\(pendingAnnotations.count))")
                        .font(.headline)
                    Spacer()
                    Button(action: {
                        if let onSendToClaude = onSendToClaude {
                            onSendToClaude()
                        } else {
                            sendToClaudeLegacy()
                        }
                    }) {
                        Text("Send to Claude")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor))

                Divider()

                // Annotation tags
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(pendingAnnotations) { annotation in
                            AnnotationTag(annotation: annotation)
                        }
                    }
                    .padding(12)
                }
                .frame(maxHeight: 200)

                Divider()
            }
        }
    }

    // Legacy method for backward compatibility (used when no callback is provided)
    private func sendToClaudeLegacy() {
        let prompt = appState.generateClaudePromptWithFileContent()
        print("📤 Sending to Claude:\n\(prompt)")

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
                }

                print("✅ Claude response received:\n\(fullResponse)")

                // Claude has used the Edit tool to modify files directly to disk
                // The files have been updated. To see changes, users can:
                // 1. Close and reopen the file
                // 2. Switch to another file and back
                // TODO: Implement file watching to auto-reload changed files

                // Mark annotations as complete
                for annotation in appState.annotations where annotation.status == .sent {
                    appState.updateAnnotationStatus(annotation.id, status: .completed)
                }

                print("✅ Files modified by Claude. Annotations marked as complete.")
                print("📝 Modified files: \(affectedFiles.joined(separator: ", "))")
            } catch {
                print("❌ Error sending to Claude: \(error)")
                // Revert annotations back to pending on error
                for annotation in appState.annotations where annotation.status == .sent {
                    appState.updateAnnotationStatus(annotation.id, status: .pending)
                }
            }
        }
    }
}

struct AnnotationTag: View {
    let annotation: Annotation
    @Environment(AppState.self) private var appState
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 8) {
            // Icon
            Image(systemName: annotation.icon)
                .font(.caption)
                .foregroundColor(iconColor)
            
            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(annotation.fileName + (annotation.lineNumber.map { ":\($0)" } ?? ""))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(truncatedInstruction)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Delete button
            Button(action: {
                appState.removeAnnotation(annotation.id)
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(isHovered ? .red : .secondary)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                isHovered = hovering
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(tagBackground)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(borderColor, lineWidth: 1)
        )
    }
    
    private var iconColor: Color {
        switch annotation.type {
        case .edit: return .blue
        case .verify: return .green
        case .expand: return .purple
        case .suggest: return .orange
        case .googleSlides: return .red
        }
    }
    
    private var tagBackground: Color {
        Color(NSColor.controlBackgroundColor).opacity(0.8)
    }
    
    private var borderColor: Color {
        iconColor.opacity(0.3)
    }
    
    private var truncatedInstruction: String {
        if annotation.instruction.count > 50 {
            return String(annotation.instruction.prefix(47)) + "..."
        }
        return annotation.instruction
    }
}

#Preview {
    let appState = AppState()
    appState.annotations = [
        Annotation(
            fileName: "pitch-deck.md",
            filePath: "/path/to/pitch-deck.md",
            lineNumber: 23,
            selection: TextSelection(startOffset: 100, endOffset: 107, selectedText: "750,000"),
            type: .edit,
            instruction: "Change to match @market-analysis.md"
        ),
        Annotation(
            fileName: "financials.md",
            filePath: "/path/to/financials.md",
            lineNumber: 45,
            selection: TextSelection(startOffset: 200, endOffset: 208, selectedText: "$2.5M ARR"),
            type: .verify,
            instruction: "Verify consistency across all financial documents"
        ),
        Annotation(
            fileName: "roadmap.md",
            filePath: "/path/to/roadmap.md",
            lineNumber: 12,
            selection: TextSelection(startOffset: 50, endOffset: 70, selectedText: "product roadmap"),
            type: .expand,
            instruction: "Add 2-3 paragraphs about Q2 plans"
        )
    ]
    
    return AnnotationTagsView()
        .environment(appState)
        .frame(width: 350)
}
