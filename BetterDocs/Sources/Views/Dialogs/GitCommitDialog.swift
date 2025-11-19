import SwiftUI

struct GitCommitDialog: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var commitMessage: String = ""
    @FocusState private var isMessageFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Commit Changes")
                    .font(.headline)
                    .foregroundColor(.secondary)

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .imageScale(.large)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // Git Status
            VStack(alignment: .leading, spacing: 8) {
                Text("Status:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: 12) {
                    if let branch = appState.gitStatus.currentBranch {
                        Label(branch, systemImage: "arrow.branch")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if appState.gitStatus.hasUncommittedChanges {
                        let totalChanges = appState.gitStatus.modifiedFiles.count +
                                         appState.gitStatus.untrackedFiles.count +
                                         appState.gitStatus.stagedFiles.count
                        Label("\(totalChanges) changes", systemImage: "doc.text")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // Commit message field
            VStack(alignment: .leading, spacing: 8) {
                Text("Commit message:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                TextEditor(text: $commitMessage)
                    .font(.body)
                    .frame(height: 100)
                    .scrollContentBackground(.hidden)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
                    .focused($isMessageFieldFocused)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // Action buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])

                Spacer()

                Button("Commit") {
                    if !commitMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        appState.performGitCommit(message: commitMessage)
                        dismiss()
                    }
                }
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(commitMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .buttonStyle(.borderedProminent)
            }
            .padding(16)
        }
        .frame(width: 450)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            isMessageFieldFocused = true
        }
    }
}
