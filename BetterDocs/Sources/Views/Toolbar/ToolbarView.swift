import SwiftUI

struct ToolbarView: View {
    @Environment(AppState.self) private var appState
    @State private var showingFileCreationSheet = false

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
                .disabled(appState.selectedItem == nil || !appState.selectedItem!.isFolder)

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

            // Settings
            Button(action: { openSettings() }) {
                Image(systemName: "gear")
            }
            .help("Settings")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    private func createNewFile(_ fileType: FileType) {
        guard let selectedFolder = appState.selectedItem as? Folder else {
            // If selected item is not a folder, try to find its parent
            if let selectedItem = appState.selectedItem,
               let rootFolder = appState.rootFolder,
               let parentFolder = findParentFolder(of: selectedItem, in: rootFolder) {
                appState.createNewFile(in: parentFolder, fileType: fileType)
            }
            return
        }
        appState.createNewFile(in: selectedFolder, fileType: fileType)
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
