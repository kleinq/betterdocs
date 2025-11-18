import SwiftUI

struct NavigationView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedID: UUID?
    @State private var expandedFolders: Set<UUID> = []

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Files")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Search results or file tree
            if appState.isSearching && !appState.searchResults.isEmpty {
                // Show search results
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(appState.searchResults) { result in
                            SearchResultRow(result: result, selectedID: $selectedID)
                        }
                    }
                    .padding(8)
                }
            } else if appState.isSearching {
                // No search results
                VStack(spacing: 16) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)

                    Text("No results found")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Text("Try a different search term")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let rootFolder = appState.rootFolder {
                // Show file tree
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        FileTreeItemView(
                            item: rootFolder,
                            level: 0,
                            selectedID: $selectedID,
                            expandedFolders: $expandedFolders
                        )
                    }
                    .padding(4)
                }
            } else {
                // Empty state
                VStack(spacing: 16) {
                    Image(systemName: "folder.badge.questionmark")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)

                    Text("No folder opened")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Button("Open Folder") {
                        appState.openFolder()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(NSColor.textBackgroundColor))
        .onChange(of: selectedID) { _, newValue in
            if let id = newValue,
               let folder = appState.rootFolder,
               let item = folder.findItem(withID: id) {
                appState.selectItem(item)
                // Expand parent folders to reveal this item
                expandPathToItem(id, in: folder)
            }
        }
        .onChange(of: appState.selectedItem?.id) { _, newValue in
            // Sync selectedID when selectedItem changes (e.g., from search result or app launch)
            if let id = newValue {
                selectedID = id
                // Also expand to show this item
                if let folder = appState.rootFolder {
                    expandPathToItem(id, in: folder)
                }
            }
        }
    }

    private func expandPathToItem(_ itemID: UUID, in folder: Folder) {
        // Find path to item and expand all parent folders
        if let path = findPath(to: itemID, in: folder, currentPath: []) {
            for folderID in path {
                expandedFolders.insert(folderID)
            }
        }
    }

    private func findPath(to itemID: UUID, in folder: Folder, currentPath: [UUID]) -> [UUID]? {
        // Check if item is in this folder
        for child in folder.children {
            if child.id == itemID {
                return currentPath
            }

            if let subfolder = child as? Folder {
                let newPath = currentPath + [subfolder.id]
                if let found = findPath(to: itemID, in: subfolder, currentPath: newPath) {
                    return found
                }
            }
        }
        return nil
    }
}

struct FileTreeItemView: View {
    let item: any FileSystemItem
    let level: Int
    @Binding var selectedID: UUID?
    @Binding var expandedFolders: Set<UUID>

    @State private var isHovered: Bool = false
    @Environment(AppState.self) private var appState

    var folder: Folder? {
        item as? Folder
    }

    var document: Document? {
        item as? Document
    }

    var isExpanded: Bool {
        expandedFolders.contains(item.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Item row
            HStack(spacing: 6) {
                // Indentation
                Color.clear
                    .frame(width: CGFloat(level * 16))

                // Disclosure triangle for folders
                if item.isFolder {
                    Button(action: { toggleExpanded() }) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)
                            .frame(width: 12, height: 12)
                    }
                    .buttonStyle(.plain)
                } else {
                    Color.clear.frame(width: 12)
                }

                // Icon
                item.icon
                    .foregroundColor(item.isFolder ? .accentColor : .secondary)
                    .frame(width: 16, height: 16)

                // Name
                Text(item.name)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                // Document type badge
                if let doc = document {
                    Text(doc.type.displayName)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(backgroundColors)
            )
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                // Double-click: open in tab
                appState.openInTab(item)
            }
            .onTapGesture {
                // Single-click: preview
                selectedID = item.id
                if item.isFolder {
                    toggleExpanded()
                }
            }
            .onHover { hovering in
                isHovered = hovering
            }

            // Children (if folder is expanded)
            if isExpanded, let folder = folder {
                ForEach(folder.children, id: \.id) { child in
                    FileTreeItemView(
                        item: child,
                        level: level + 1,
                        selectedID: $selectedID,
                        expandedFolders: $expandedFolders
                    )
                }
            }
        }
    }

    private var backgroundColors: Color {
        if selectedID == item.id {
            return Color.accentColor.opacity(0.3)
        } else if isHovered {
            return Color.secondary.opacity(0.1)
        }
        return Color.clear
    }

    private func toggleExpanded() {
        withAnimation(.easeInOut(duration: 0.2)) {
            if isExpanded {
                expandedFolders.remove(item.id)
            } else {
                expandedFolders.insert(item.id)
            }
        }
    }
}

struct SearchResultRow: View {
    let result: SearchResult
    @Binding var selectedID: UUID?
    @State private var isHovered = false
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                result.item.icon
                    .foregroundColor(result.item.isFolder ? .accentColor : .secondary)
                    .frame(width: 16, height: 16)

                VStack(alignment: .leading, spacing: 2) {
                    Text(result.item.name)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .font(.subheadline)

                    if let document = result.document {
                        Text(document.type.displayName)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    // Show first match context
                    if let firstMatch = result.matches.first {
                        Text(firstMatch.preview)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer()

                // Score badge (for debugging)
                Text(String(format: "%.0f", result.score))
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.2))
                    .cornerRadius(4)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(backgroundColors)
        )
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            // Double-click: open in tab
            appState.openInTab(result.item)
        }
        .onTapGesture {
            // Single-click: preview
            selectedID = result.id
        }
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var backgroundColors: Color {
        if selectedID == result.id {
            return Color.accentColor.opacity(0.3)
        } else if isHovered {
            return Color.secondary.opacity(0.1)
        }
        return Color.clear
    }
}

#Preview {
    NavigationView()
        .environment(AppState())
        .frame(width: 250, height: 600)
}
