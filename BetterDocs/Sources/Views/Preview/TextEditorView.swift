import SwiftUI
import AppKit

/// Editable text editor for markdown and plain text files
struct TextEditorView: View {
    let document: Document
    @State private var content: String = ""
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var lastSavedContent: String = ""
    @State private var saveTimer: Timer?
    @Environment(AppState.self) private var appState

    var hasUnsavedChanges: Bool {
        content != lastSavedContent
    }

    var body: some View {
        VStack(spacing: 0) {
            // Editor toolbar
            HStack(spacing: 12) {
                // Save status indicator
                if isSaving {
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 16, height: 16)
                        Text("Saving...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else if hasUnsavedChanges {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 8, height: 8)
                        Text("Unsaved changes")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("Saved")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Word count
                Text("\(wordCount) words, \(content.count) characters")
                    .font(.caption)
                    .foregroundColor(.secondary)

                // Manual save button
                Button(action: { Task { await saveContent() } }) {
                    Label("Save", systemImage: "square.and.arrow.down")
                        .font(.caption)
                }
                .disabled(!hasUnsavedChanges || isSaving)
                .keyboardShortcut("s", modifiers: [.command])
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Text editor
            if isLoading {
                VStack {
                    ProgressView("Loading...")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                TextEditor(text: $content)
                    .font(.system(size: 14))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(8)
                    .onChange(of: content) { _, _ in
                        scheduleAutoSave()
                    }
            }
        }
        .id(document.id)
        .task(id: document.id) {
            await loadContent()
        }
        .onDisappear {
            // Save on close if there are unsaved changes
            if hasUnsavedChanges {
                Task { await saveContent() }
            }
            saveTimer?.invalidate()
        }
    }

    private var wordCount: Int {
        let words = content.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        return words.count
    }

    private func loadContent() async {
        isLoading = true
        defer { isLoading = false }

        // Try to load from document.content first
        if let existingContent = document.content {
            content = existingContent
            lastSavedContent = existingContent
            return
        }

        // Otherwise load from file
        do {
            let fileContent = try String(contentsOf: document.path, encoding: .utf8)
            content = fileContent
            lastSavedContent = fileContent
        } catch {
            logError("Failed to load file: \(error)")
            content = ""
            lastSavedContent = ""
        }
    }

    private func scheduleAutoSave() {
        // Invalidate existing timer
        saveTimer?.invalidate()

        // Schedule new auto-save after 2 seconds of inactivity
        saveTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
            Task { @MainActor in
                await saveContent()
            }
        }
    }

    private func saveContent() async {
        guard hasUnsavedChanges else { return }
        guard !isSaving else { return }

        isSaving = true
        defer { isSaving = false }

        do {
            try content.write(to: document.path, atomically: true, encoding: .utf8)
            lastSavedContent = content
            logInfo("✅ Saved: \(document.name)")

            // Refresh the folder tree to update file size/modified date
            await appState.refreshFolder()
        } catch {
            logError("❌ Failed to save file: \(error)")
        }
    }
}

#Preview {
    TextEditorView(
        document: Document(
            name: "test.md",
            path: URL(fileURLWithPath: "/tmp/test.md"),
            type: .markdown,
            size: 100,
            created: Date(),
            modified: Date(),
            content: "# Test Document\n\nThis is a test.",
            metadata: [:]
        )
    )
    .environment(AppState())
    .frame(width: 600, height: 400)
}
