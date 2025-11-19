import SwiftUI
import WebKit

struct NavigationView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedID: UUID?
    @State private var expandedFolders: Set<UUID> = []
    @State private var expandedFolderPaths: Set<String> = [] // Persist by path instead of UUID
    @FocusState private var isFocused: Bool
    @State private var localEventMonitor: Any?

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
                Group {
                    if appState.viewMode == .grid {
                        GridView(folder: rootFolder)
                            .id("grid-\(rootFolder.path.path)") // Stable ID based on path, not UUID
                    } else {
                        ScrollViewReader { proxy in
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
                            .onChange(of: selectedID) { _, newID in
                                // Scroll to selected item when selection changes
                                if let id = newID {
                                    withAnimation {
                                        proxy.scrollTo(id, anchor: .center)
                                    }
                                }
                            }
                        }
                        .id("tree-\(rootFolder.path.path)") // Stable ID based on path, not UUID
                    }
                }
                .focusable()
                .focused($isFocused)
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

            // Restore expanded folders from UserDefaults (if rootFolder already loaded)
            if let rootFolder = appState.rootFolder {
                logInfo("🔄 NavigationView appeared with rootFolder loaded")
                restoreExpandedFolders()
                logInfo("✅ Restored \(expandedFolders.count) expanded folders on appear")

                // If there's a selected item from app state, sync it
                if let selectedItem = appState.selectedItem {
                    logInfo("🎯 Syncing selected item: \(selectedItem.name)")
                    selectedID = selectedItem.id
                    expandPathToItem(selectedItem.id, in: rootFolder)
                }
            }

            // Set up local event monitor for arrow keys
            localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                return handleKeyEvent(event)
            }
        }
        .onDisappear {
            // Remove event monitor
            if let monitor = localEventMonitor {
                NSEvent.removeMonitor(monitor)
                localEventMonitor = nil
            }
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
        .onChange(of: appState.selectedItem?.id) { oldValue, newValue in
            // Sync selectedID when selectedItem changes (e.g., from search result or app launch)
            if let id = newValue, let selectedItem = appState.selectedItem {
                logInfo("📍 App selected item changed to: \(selectedItem.name)")
                selectedID = id
                // Also expand to show this item
                if let folder = appState.rootFolder {
                    logInfo("🌳 Expanding path to show selected item")
                    expandPathToItem(id, in: folder)
                }
            } else if newValue == nil && oldValue != nil {
                // Selection was cleared
                logInfo("❌ Selection cleared")
                selectedID = nil
            }
        }
        .onChange(of: appState.rootFolder?.id) { oldValue, newValue in
            // Folder was loaded or reloaded (e.g., on app launch or by file watcher)
            if newValue != nil {
                logInfo("📂 Folder reloaded, restoring expanded state...")
                // Small delay to ensure the view is ready
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    restoreExpandedFolders()
                    logInfo("✅ Restored \(expandedFolders.count) expanded folders")

                    // Ensure currently selected item is visible
                    if let selectedID = selectedID, let folder = appState.rootFolder {
                        expandPathToItem(selectedID, in: folder)
                    } else if oldValue == nil, let selectedItem = appState.selectedItem {
                        // On initial load, expand to selected item from app state
                        selectedID = selectedItem.id
                        if let folder = appState.rootFolder {
                            expandPathToItem(selectedItem.id, in: folder)
                        }
                    }
                }
            }
        }
        .onChange(of: expandedFolders) { _, _ in
            // Save expanded folders whenever they change
            saveExpandedFolders()
        }
    }

    private func handleKeyEvent(_ event: NSEvent) -> NSEvent? {
        // Only handle arrow keys when command palette is closed
        guard !appState.isCommandPaletteOpen else {
            return event
        }

        // Check if we're in a text field or webview (preview)
        if let firstResponder = NSApp.keyWindow?.firstResponder,
           firstResponder is NSText || firstResponder is NSTextView || firstResponder is WKWebView {
            return event
        }

        switch event.keyCode {
        case 125: // Down arrow
            if appState.isSearching && !appState.searchResults.isEmpty {
                navigateSearchResults(direction: .down)
            } else if appState.rootFolder != nil && appState.viewMode == .list {
                navigateTree(direction: .down)
            }
            return nil // Consume the event

        case 126: // Up arrow
            if appState.isSearching && !appState.searchResults.isEmpty {
                navigateSearchResults(direction: .up)
            } else if appState.rootFolder != nil && appState.viewMode == .list {
                navigateTree(direction: .up)
            }
            return nil // Consume the event

        case 124: // Right arrow
            if !appState.isSearching && appState.rootFolder != nil && appState.viewMode == .list {
                expandSelectedFolder()
                return nil
            }

        case 123: // Left arrow
            if !appState.isSearching && appState.rootFolder != nil && appState.viewMode == .list {
                collapseSelectedFolder()
                return nil
            }

        case 36: // Return/Enter
            if appState.isSearching && !appState.searchResults.isEmpty {
                openSelectedSearchResult()
            } else if appState.rootFolder != nil && appState.viewMode == .list {
                openSelectedItem()
            }
            return nil

        case 49: // Space
            if !appState.isSearching && appState.rootFolder != nil && appState.viewMode == .list {
                toggleSelectedFolder()
                return nil
            }

        default:
            break
        }

        return event
    }

    private func expandPathToItem(_ itemID: UUID, in folder: Folder) {
        // Find path to item and expand all parent folders
        if let path = findPath(to: itemID, in: folder, currentPath: []) {
            logInfo("🔍 Found path with \(path.count) parent folders to expand")
            for folderID in path {
                expandedFolders.insert(folderID)
            }
            logInfo("✅ Expanded folders, total now: \(expandedFolders.count)")
        } else {
            logWarning("⚠️ Could not find path to item")
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

    // MARK: - Expanded Folders Persistence

    private func saveExpandedFolders() {
        guard let rootFolder = appState.rootFolder else { return }

        // Convert UUIDs to paths for persistence (UUIDs change on reload)
        var paths: Set<String> = []
        for folderID in expandedFolders {
            if let folder = rootFolder.findItem(withID: folderID) {
                paths.insert(folder.path.path)
            }
        }

        expandedFolderPaths = paths
        let pathsArray = Array(paths)
        UserDefaults.standard.set(pathsArray, forKey: "expandedFolderPaths")
    }

    private func restoreExpandedFolders() {
        guard let rootFolder = appState.rootFolder else {
            logWarning("⚠️ Cannot restore: no rootFolder")
            return
        }

        // Always expand the root folder
        var restoredFolders: Set<UUID> = [rootFolder.id]
        logInfo("📂 Auto-expanding root folder: \(rootFolder.name)")

        // Load persisted paths
        if let savedPaths = UserDefaults.standard.array(forKey: "expandedFolderPaths") as? [String] {
            logInfo("📦 Found \(savedPaths.count) saved folder paths")
            expandedFolderPaths = Set(savedPaths)
        } else {
            logInfo("📦 No saved folder paths found")
        }

        // Convert paths back to UUIDs for current folder tree
        for path in expandedFolderPaths {
            if let item = findItemByPath(path, in: rootFolder), item.isFolder {
                restoredFolders.insert(item.id)
                logInfo("✅ Restored folder: \(item.name)")
            } else {
                logWarning("⚠️ Could not find folder at path: \(path)")
            }
        }

        expandedFolders = restoredFolders
        logInfo("🎯 Total restored folders: \(restoredFolders.count)")
    }

    private func findItemByPath(_ path: String, in folder: Folder) -> (any FileSystemItem)? {
        // Check if this folder matches
        if folder.path.path == path {
            return folder
        }

        // Search children recursively
        for child in folder.children {
            if child.path.path == path {
                return child
            }

            if let subfolder = child as? Folder,
               let found = findItemByPath(path, in: subfolder) {
                return found
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
    @State private var isDropTarget: Bool = false
    @State private var showingRenameSheet: Bool = false
    @State private var showingFileCreationSheet: Bool = false
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
            // Drag & Drop support
            .draggable(item.path) {
                // Preview during drag
                HStack(spacing: 6) {
                    item.icon
                    Text(item.name)
                        .lineLimit(1)
                }
                .padding(8)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
            }
            .dropDestination(for: URL.self) { droppedURLs, _ in
                handleDrop(droppedURLs: droppedURLs)
            } isTargeted: { isTargeted in
                isDropTarget = isTargeted
            }
            .contextMenu {
                itemContextMenu
            }
            .sheet(isPresented: $showingFileCreationSheet) {
                if let folder = folder {
                    FileCreationSheet(
                        isPresented: $showingFileCreationSheet,
                        folderName: folder.name
                    ) { fileType in
                        appState.createNewFile(in: folder, fileType: fileType)
                    }
                }
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
        .id(item.id) // Enable ScrollViewReader to find this item
    }

    private var backgroundColors: Color {
        if isDropTarget && item.isFolder {
            return Color.accentColor.opacity(0.2)
        } else if selectedID == item.id {
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

    // MARK: - Drag & Drop

    private func handleDrop(droppedURLs: [URL]) -> Bool {
        guard let folder = folder else { return false }

        for url in droppedURLs {
            appState.moveFile(from: url, to: folder)
        }
        return true
    }

    // MARK: - Context Menu

    @ViewBuilder
    private var itemContextMenu: some View {
        if let folder = folder {
            // Folder context menu
            Button(action: { showingFileCreationSheet = true }) {
                Label("New Markdown File", systemImage: "doc.badge.plus")
            }

            Button(action: { appState.createNewFile(in: folder, fileType: .plainText) }) {
                Label("New Text File", systemImage: "doc.text.badge.plus")
            }

            Divider()

            Button(action: { showingRenameSheet = true }) {
                Label("Rename", systemImage: "pencil")
            }

            Divider()

            Button(action: { appState.revealInFinder(item) }) {
                Label("Reveal in Finder", systemImage: "finder")
            }
        } else {
            // File context menu
            Button(action: { appState.openInTab(item) }) {
                Label("Open", systemImage: "doc")
            }

            Button(action: { showingRenameSheet = true }) {
                Label("Rename", systemImage: "pencil")
            }

            // AI rename for text files
            if let doc = document, (doc.type == .markdown || doc.type == .text) {
                Button(action: { appState.renameWithAI(item) }) {
                    Label("Rename with AI", systemImage: "sparkles")
                }
            }

            Divider()

            Button(action: { appState.revealInFinder(item) }) {
                Label("Reveal in Finder", systemImage: "finder")
            }

            Divider()

            Button(role: .destructive, action: { appState.deleteItem(item) }) {
                Label("Delete", systemImage: "trash")
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
