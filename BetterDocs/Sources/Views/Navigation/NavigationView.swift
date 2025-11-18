import SwiftUI

struct NavigationView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedID: UUID?
    @State private var expandedFolders: Set<UUID> = []
    @FocusState private var isFocused: Bool

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
                .focusable()
                .focused($isFocused)
                .onKeyPress(.downArrow) {
                    navigateSearchResults(direction: .down)
                    return .handled
                }
                .onKeyPress(.upArrow) {
                    navigateSearchResults(direction: .up)
                    return .handled
                }
                .onKeyPress(.return) {
                    openSelectedSearchResult()
                    return .handled
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
                // Show file tree or grid based on view mode
                if appState.viewMode == .grid {
                    GridView(folder: rootFolder)
                } else {
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
                }
                .focusable()
                .focused($isFocused)
                .onKeyPress(.downArrow) {
                    navigateTree(direction: .down)
                    return .handled
                }
                .onKeyPress(.upArrow) {
                    navigateTree(direction: .up)
                    return .handled
                }
                .onKeyPress(.rightArrow) {
                    expandSelectedFolder()
                    return .handled
                }
                .onKeyPress(.leftArrow) {
                    collapseSelectedFolder()
                    return .handled
                }
                .onKeyPress(.return) {
                    openSelectedItem()
                    return .handled
                }
                .onKeyPress(.space) {
                    toggleSelectedFolder()
                    return .handled
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
        .onAppear {
            // Auto-focus the navigation view when it appears
            isFocused = true
        }
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

    // MARK: - Keyboard Navigation

    private enum NavigationDirection {
        case up, down
    }

    private func navigateTree(direction: NavigationDirection) {
        guard let rootFolder = appState.rootFolder else { return }

        let visibleItems = getVisibleItems(from: rootFolder)
        guard !visibleItems.isEmpty else { return }

        if let currentID = selectedID,
           let currentIndex = visibleItems.firstIndex(where: { $0.id == currentID }) {
            let newIndex: Int
            switch direction {
            case .down:
                newIndex = min(currentIndex + 1, visibleItems.count - 1)
            case .up:
                newIndex = max(currentIndex - 1, 0)
            }
            selectedID = visibleItems[newIndex].id
        } else {
            // No selection, select first item
            selectedID = visibleItems.first?.id
        }
    }

    private func navigateSearchResults(direction: NavigationDirection) {
        let results = appState.searchResults
        guard !results.isEmpty else { return }

        if let currentID = selectedID,
           let currentIndex = results.firstIndex(where: { $0.id == currentID }) {
            let newIndex: Int
            switch direction {
            case .down:
                newIndex = min(currentIndex + 1, results.count - 1)
            case .up:
                newIndex = max(currentIndex - 1, 0)
            }
            selectedID = results[newIndex].id
        } else {
            // No selection, select first result
            selectedID = results.first?.id
        }
    }

    private func getVisibleItems(from folder: Folder) -> [any FileSystemItem] {
        var items: [any FileSystemItem] = [folder]

        if expandedFolders.contains(folder.id) {
            for child in folder.children {
                if let subfolder = child as? Folder {
                    items.append(contentsOf: getVisibleItems(from: subfolder))
                } else {
                    items.append(child)
                }
            }
        }

        return items
    }

    private func expandSelectedFolder() {
        guard let selectedID = selectedID,
              let folder = appState.rootFolder,
              let item = folder.findItem(withID: selectedID),
              item.isFolder else { return }

        withAnimation(.easeInOut(duration: 0.2)) {
            expandedFolders.insert(selectedID)
        }
    }

    private func collapseSelectedFolder() {
        guard let selectedID = selectedID,
              let folder = appState.rootFolder,
              let item = folder.findItem(withID: selectedID) else { return }

        if item.isFolder && expandedFolders.contains(selectedID) {
            // Collapse the current folder if it's expanded
            withAnimation(.easeInOut(duration: 0.2)) {
                expandedFolders.remove(selectedID)
            }
        } else {
            // Navigate to parent folder
            if let parentID = findParent(of: selectedID, in: folder) {
                self.selectedID = parentID
            }
        }
    }

    private func toggleSelectedFolder() {
        guard let selectedID = selectedID,
              let folder = appState.rootFolder,
              let item = folder.findItem(withID: selectedID),
              item.isFolder else { return }

        withAnimation(.easeInOut(duration: 0.2)) {
            if expandedFolders.contains(selectedID) {
                expandedFolders.remove(selectedID)
            } else {
                expandedFolders.insert(selectedID)
            }
        }
    }

    private func openSelectedItem() {
        guard let selectedID = selectedID,
              let folder = appState.rootFolder,
              let item = folder.findItem(withID: selectedID) else { return }

        appState.openInTab(item)
    }

    private func openSelectedSearchResult() {
        guard let selectedID = selectedID,
              let result = appState.searchResults.first(where: { $0.id == selectedID }) else { return }

        appState.openInTab(result.item)
    }

    private func findParent(of itemID: UUID, in folder: Folder) -> UUID? {
        // Check direct children
        for child in folder.children {
            if child.id == itemID {
                return folder.id
            }

            // Check nested folders
            if let subfolder = child as? Folder,
               let parent = findParent(of: itemID, in: subfolder) {
                return parent
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
