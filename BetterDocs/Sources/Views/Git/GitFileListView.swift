import SwiftUI

struct GitFileListView: View {
    @Environment(AppState.self) private var appState
    @Binding var isOpen: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.branch")
                        .foregroundColor(.accentColor)

                    if let branch = appState.gitStatus.currentBranch {
                        Text(branch)
                            .font(.headline)
                    } else {
                        Text("Git Status")
                            .font(.headline)
                    }
                }

                Spacer()

                Button(action: { isOpen = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .imageScale(.medium)
                }
                .buttonStyle(.plain)
                .help("Close")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Staged files section
                    if !appState.gitStatus.stagedFiles.isEmpty {
                        GitFileSection(
                            title: "Staged Changes",
                            files: appState.gitStatus.stagedFiles,
                            icon: "checkmark.circle.fill",
                            color: .green
                        )
                    }

                    // Modified files section
                    if !appState.gitStatus.modifiedFiles.isEmpty {
                        GitFileSection(
                            title: "Modified Files",
                            files: appState.gitStatus.modifiedFiles,
                            icon: "pencil.circle.fill",
                            color: .orange
                        )
                    }

                    // Untracked files section
                    if !appState.gitStatus.untrackedFiles.isEmpty {
                        GitFileSection(
                            title: "Untracked Files",
                            files: appState.gitStatus.untrackedFiles,
                            icon: "plus.circle.fill",
                            color: .blue
                        )
                    }

                    // Empty state
                    if appState.gitStatus.stagedFiles.isEmpty &&
                       appState.gitStatus.modifiedFiles.isEmpty &&
                       appState.gitStatus.untrackedFiles.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 48))
                                .foregroundColor(.green.opacity(0.5))

                            Text("Working directory clean")
                                .font(.headline)
                                .foregroundColor(.secondary)

                            Text("No changes to commit")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }

                    // Remote status
                    if appState.gitStatus.ahead > 0 || appState.gitStatus.behind > 0 {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Remote Status")
                                .font(.headline)
                                .foregroundColor(.secondary)

                            HStack(spacing: 16) {
                                if appState.gitStatus.ahead > 0 {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.up.circle.fill")
                                            .foregroundColor(.blue)
                                        Text("\(appState.gitStatus.ahead) commit\(appState.gitStatus.ahead == 1 ? "" : "s") ahead")
                                            .font(.subheadline)
                                    }
                                }

                                if appState.gitStatus.behind > 0 {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.down.circle.fill")
                                            .foregroundColor(.blue)
                                        Text("\(appState.gitStatus.behind) commit\(appState.gitStatus.behind == 1 ? "" : "s") behind")
                                            .font(.subheadline)
                                    }
                                }
                            }
                        }
                        .padding(12)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .padding(16)
            }
        }
        .frame(width: 350)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct GitFileSection: View {
    let title: String
    let files: [String]
    let icon: String
    let color: Color
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Section header
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.subheadline)

                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)

                Text("(\(files.count))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // File list
            VStack(alignment: .leading, spacing: 4) {
                ForEach(files, id: \.self) { filePath in
                    GitFileRow(filePath: filePath, color: color)
                }
            }
        }
    }
}

struct GitFileRow: View {
    let filePath: String
    let color: Color
    @Environment(AppState.self) private var appState
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)

            Text(fileName)
                .font(.body)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            if !directoryPath.isEmpty {
                Text(directoryPath)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.head)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? Color.secondary.opacity(0.1) : Color.clear)
        )
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            openFile()
        }
        .help("Click to open")
    }

    private var fileName: String {
        (filePath as NSString).lastPathComponent
    }

    private var directoryPath: String {
        let dir = (filePath as NSString).deletingLastPathComponent
        return dir == "." ? "" : dir
    }

    private func openFile() {
        // Try to find and open the file
        guard let rootFolder = appState.rootFolder else { return }

        let fullPath = rootFolder.path.appendingPathComponent(filePath)
        if let item = findItem(at: fullPath, in: rootFolder) {
            appState.openInTab(item)
            // Close the git panel after opening file
            appState.showGitPanel = false
        }
    }

    private func findItem(at targetPath: URL, in folder: Folder) -> (any FileSystemItem)? {
        if folder.path.standardizedFileURL == targetPath.standardizedFileURL {
            return folder
        }

        for child in folder.children {
            if child.path.standardizedFileURL == targetPath.standardizedFileURL {
                return child
            }

            if let subfolder = child as? Folder,
               let found = findItem(at: targetPath, in: subfolder) {
                return found
            }
        }

        return nil
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var isOpen = true
        @State private var appState = AppState()

        var body: some View {
            // Set up mock git status
            let _ = {
                appState.gitStatus = GitStatus(
                    isGitRepository: true,
                    currentBranch: "main",
                    hasUncommittedChanges: true,
                    hasUnpushedCommits: true,
                    ahead: 2,
                    behind: 1,
                    modifiedFiles: ["src/main.swift", "docs/README.md", "config/settings.json"],
                    untrackedFiles: ["new_feature.swift"],
                    stagedFiles: ["src/utils.swift"]
                )
            }()

            return ZStack {
                Color.gray.opacity(0.3)

                HStack {
                    Spacer()
                    GitFileListView(isOpen: $isOpen)
                        .shadow(radius: 10)
                }
            }
            .environment(appState)
            .frame(width: 800, height: 600)
        }
    }

    return PreviewWrapper()
}
