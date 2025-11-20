import SwiftUI

struct ToolbarView: View {
    @Environment(AppState.self) private var appState
    @State private var showingFileCreationSheet = false
    @State private var showGitCommitDialog = false

    var body: some View {
        HStack(spacing: 16) {
            // File operations
            HStack(spacing: 8) {
                Button(action: { appState.openFolder() }) {
                    Label("Open", systemImage: "folder.badge.plus")
                }
                .help("Open folder (⌘O)")

                Divider()
                    .frame(height: 24)

                // New file button with dropdown menu
                Menu {
                    Button(action: { createNewFile(.markdown) }) {
                        Label("New Markdown File", systemImage: "doc.badge.plus")
                    }

                    Button(action: { createNewFile(.plainText) }) {
                        Label("New Text File", systemImage: "doc.text.badge.plus")
                    }
                } label: {
                    Image(systemName: "plus")
                }
                .help("Create new file")
                .disabled(appState.rootFolder == nil)

                Divider()
                    .frame(height: 24)

                Button(action: {
                    Task { await appState.refreshFolder() }
                }) {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh")
                .disabled(appState.rootFolder == nil)
            }

            Divider()
                .frame(height: 24)

            // View controls
            HStack(spacing: 8) {
                Button(action: { appState.revealInFolderTree() }) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                }
                .help("Reveal in folder tree (⌘R)")
                .disabled(appState.selectedItem == nil)

                Button(action: { appState.setViewMode(.grid) }) {
                    Image(systemName: "square.grid.2x2")
                }
                .help("Grid view (Ctrl+O)")
                .foregroundColor(appState.viewMode == .grid ? .accentColor : .primary)
                .background(appState.viewMode == .grid ? Color.accentColor.opacity(0.1) : Color.clear)
                .cornerRadius(4)

                Button(action: { appState.setViewMode(.list) }) {
                    Image(systemName: "list.bullet")
                }
                .help("List view (Ctrl+O)")
                .foregroundColor(appState.viewMode == .list ? .accentColor : .primary)
                .background(appState.viewMode == .list ? Color.accentColor.opacity(0.1) : Color.clear)
                .cornerRadius(4)
            }

            Spacer()

            // Git operations
            if appState.gitStatus.isGitRepository {
                HStack(spacing: 8) {
                    Divider()
                        .frame(height: 24)

                    // Git status indicator
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.branch")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if let branch = appState.gitStatus.currentBranch {
                            Text(branch)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        // Changes indicator
                        if appState.gitStatus.hasUncommittedChanges {
                            Text("•")
                                .foregroundColor(.orange)
                        }

                        // Ahead/behind indicators
                        if appState.gitStatus.ahead > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "arrow.up")
                                    .font(.caption2)
                                Text("\(appState.gitStatus.ahead)")
                                    .font(.caption2)
                            }
                            .foregroundColor(.blue)
                        }

                        if appState.gitStatus.behind > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "arrow.down")
                                    .font(.caption2)
                                Text("\(appState.gitStatus.behind)")
                                    .font(.caption2)
                            }
                            .foregroundColor(.blue)
                        }
                    }

                    // Git action buttons
                    Button(action: { showGitCommitDialog = true }) {
                        Image(systemName: "checkmark.circle")
                    }
                    .help("Git Commit (⌘⇧C)")
                    .disabled(!appState.gitStatus.hasUncommittedChanges || appState.isPerformingGitOperation)

                    Button(action: { appState.performGitPush() }) {
                        Image(systemName: "arrow.up.circle")
                    }
                    .help("Git Push (⌘⇧P)")
                    .disabled((appState.gitStatus.ahead == 0 && !appState.gitStatus.hasUncommittedChanges) || appState.isPerformingGitOperation)

                    Button(action: { appState.performGitPull() }) {
                        Image(systemName: "arrow.down.circle")
                    }
                    .help("Git Pull")
                    .disabled(appState.isPerformingGitOperation)
                }
            }

            // Settings
            Button(action: { openSettings() }) {
                Image(systemName: "gear")
            }
            .help("Settings")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
        .sheet(isPresented: $showGitCommitDialog) {
            GitCommitDialog()
                .environment(appState)
        }
    }

    private func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    private func createNewFile(_ fileType: FileType) {
        guard let rootFolder = appState.rootFolder else { return }

        // Priority 1: Use the folder of the currently active file
        if let activeTabID = appState.activeTabID,
           let activeTab = appState.openTabs.first(where: { $0.id == activeTabID }),
           let activeItem = findItem(byID: activeTab.itemID, in: rootFolder),
           let parentFolder = findParentFolder(of: activeItem, in: rootFolder) {
            appState.createNewFile(in: parentFolder, fileType: fileType)
            return
        }

        // Priority 2: Use selected item's folder if it's a folder
        if let selectedFolder = appState.selectedItem as? Folder {
            appState.createNewFile(in: selectedFolder, fileType: fileType)
            return
        }

        // Priority 3: Use selected item's parent folder
        if let selectedItem = appState.selectedItem,
           let parentFolder = findParentFolder(of: selectedItem, in: rootFolder) {
            appState.createNewFile(in: parentFolder, fileType: fileType)
            return
        }

        // Priority 4: Use root folder as fallback
        appState.createNewFile(in: rootFolder, fileType: fileType)
    }

    private func findItem(byID id: UUID, in folder: Folder) -> (any FileSystemItem)? {
        if folder.id == id {
            return folder
        }
        for child in folder.children {
            if child.id == id {
                return child
            }
            if let subfolder = child as? Folder,
               let found = findItem(byID: id, in: subfolder) {
                return found
            }
        }
        return nil
    }

    private func findParentFolder(of item: any FileSystemItem, in folder: Folder) -> Folder? {
        for child in folder.children {
            if child.id == item.id {
                return folder
            }
            if let subfolder = child as? Folder,
               let found = findParentFolder(of: item, in: subfolder) {
                return found
            }
        }
        return nil
    }
}

#Preview {
    ToolbarView()
        .environment(AppState())
        .frame(height: 50)
}
