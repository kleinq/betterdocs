import SwiftUI
import Observation
import UniformTypeIdentifiers

@MainActor
@Observable
class AppState {
    var rootFolder: Folder?
    var selectedItem: (any FileSystemItem)?
    var searchQuery: String = ""
    var searchResults: [SearchResult] = []
    var isSearching: Bool = false
    var isLoading: Bool = false

    // Tab management
    var openTabs: [DocumentTab] = []
    var activeTabID: UUID?
    var previewTab: DocumentTab? // Special ephemeral tab for single-click previews

    // UI State
    var isOutlineVisible: Bool = UserDefaults.standard.bool(forKey: "isOutlineVisible")
    var isCommandPaletteOpen: Bool = false
    var isChatPopupOpen: Bool = false
    var isHelpOpen: Bool = false
    var viewMode: ViewMode = ViewMode(rawValue: UserDefaults.standard.string(forKey: "viewMode") ?? "list") ?? .list
    var isEditMode: Bool = false // Toggle between preview and edit mode

    // Annotations
    var annotations: [Annotation] = []

    // Chats
    var chats: [Chat] = []
    var currentChat: Chat?
    var showChatList: Bool = false

    // Services
    let documentService = DocumentService()
    let searchService = SearchService()
    let claudeService = ClaudeService()
    let fileWatcher = FileSystemWatcher()
    let fileManagementService = FileManagementService()
    let gitService = GitService()

    // Git state
    var gitStatus: GitStatus = .empty
    var isPerformingGitOperation: Bool = false

    init() {
        // Restore last opened folder on launch
        restoreLastFolder()
        // Restore open tabs
        restoreOpenTabs()
        // Load annotations
        loadAnnotations()
        // Load chats
        loadChats()
    }

    private func restoreLastFolder() {
        if let lastFolderPath = UserDefaults.standard.string(forKey: "lastOpenedFolder"),
           !lastFolderPath.isEmpty {
            let url = URL(fileURLWithPath: lastFolderPath)

            // Check if folder still exists
            if FileManager.default.fileExists(atPath: lastFolderPath) {
                Task {
                    await loadFolder(at: url)

                    // Restore open tabs
                    if let tabPaths = UserDefaults.standard.array(forKey: "openTabPaths") as? [String],
                       !tabPaths.isEmpty,
                       let rootFolder = self.rootFolder {
                        logInfo("📂 Restoring \(tabPaths.count) open tabs...")
                        let activeTabPath = UserDefaults.standard.string(forKey: "activeTabPath")

                        for tabPath in tabPaths {
                            if let item = findItem(byPath: tabPath, in: rootFolder) {
                                logInfo("✅ Restored tab: \(item.name)")
                                self.openInTab(item)
                            }
                        }

                        // Restore active tab
                        if let activeTabPath = activeTabPath,
                           let activeItem = findItem(byPath: activeTabPath, in: rootFolder) {
                            logInfo("🎯 Restoring active tab: \(activeItem.name)")
                            if let tab = openTabs.first(where: { $0.itemPath == activeTabPath }) {
                                self.switchToTab(tab.id)
                            }
                        }
                    } else {
                        logInfo("📂 No tabs saved, restoring selected item...")
                        // Restore last selected item if no tabs were saved
                        if let lastSelectedPath = UserDefaults.standard.string(forKey: "lastSelectedItemPath"),
                           !lastSelectedPath.isEmpty,
                           let rootFolder = self.rootFolder {
                            // Find the item by path
                            if let item = findItem(byPath: lastSelectedPath, in: rootFolder) {
                                logInfo("🎯 Restoring selected item: \(item.name)")
                                self.selectItem(item)
                            } else {
                                logWarning("⚠️ Could not find last selected item at: \(lastSelectedPath)")
                            }
                        } else {
                            logInfo("📂 No last selected item found")
                        }
                    }
                }
            }
        }
    }

    private func saveLastFolder(_ url: URL) {
        UserDefaults.standard.set(url.path, forKey: "lastOpenedFolder")
    }

    private func saveLastSelectedItem(_ item: any FileSystemItem) {
        UserDefaults.standard.set(item.path.path, forKey: "lastSelectedItemPath")
    }

    private func saveOpenTabs() {
        // Save tab paths and active tab
        let tabPaths = openTabs.map { $0.itemPath }
        UserDefaults.standard.set(tabPaths, forKey: "openTabPaths")
        if let activeTabID = activeTabID,
           let activeTab = openTabs.first(where: { $0.id == activeTabID }) {
            UserDefaults.standard.set(activeTab.itemPath, forKey: "activeTabPath")
        }
    }

    private func restoreOpenTabs() {
        guard let tabPaths = UserDefaults.standard.array(forKey: "openTabPaths") as? [String],
              !tabPaths.isEmpty else { return }

        // We'll restore tabs after the folder is loaded
        // This is handled in restoreLastFolder()
    }

    private func findItem(byPath path: String, in folder: Folder) -> (any FileSystemItem)? {
        // Check if this folder matches
        if folder.path.path == path {
            return folder
        }

        // Search children
        for child in folder.children {
            if child.path.path == path {
                return child
            }

            // Recursively search subfolders
            if let subfolder = child as? Folder,
               let found = findItem(byPath: path, in: subfolder) {
                return found
            }
        }

        return nil
    }

    /// Get FileSystemItems from an array of file paths
    func getItems(fromPaths paths: [String]) -> [any FileSystemItem] {
        guard let rootFolder = rootFolder else { return [] }

        return paths.compactMap { path in
            findItem(byPath: path, in: rootFolder)
        }
    }

    func toggleOutline() {
        isOutlineVisible.toggle()
        UserDefaults.standard.set(isOutlineVisible, forKey: "isOutlineVisible")
    }

    func toggleViewMode() {
        viewMode = viewMode == .list ? .grid : .list
        UserDefaults.standard.set(viewMode.rawValue, forKey: "viewMode")
    }

    func setViewMode(_ mode: ViewMode) {
        viewMode = mode
        UserDefaults.standard.set(viewMode.rawValue, forKey: "viewMode")
    }

    func toggleEditMode() {
        isEditMode.toggle()
    }

    // MARK: - Annotation Management

    func addAnnotation(_ annotation: Annotation) {
        annotations.append(annotation)
        saveAnnotations()
        print("📝 Added annotation: \(annotation.displayText)")
    }

    func removeAnnotation(_ id: UUID) {
        annotations.removeAll { $0.id == id }
        saveAnnotations()
        print("🗑️ Removed annotation")
    }

    func updateAnnotationStatus(_ id: UUID, status: AnnotationStatus) {
        if let index = annotations.firstIndex(where: { $0.id == id }) {
            annotations[index].status = status
            saveAnnotations()
        }
    }

    func generateClaudePrompt() -> String {
        let pendingAnnotations = annotations.filter { $0.status == .pending }

        guard !pendingAnnotations.isEmpty else {
            return "No pending annotations to process."
        }

        var prompt = "I need you to make the following changes to my documents:\n\n"

        // Group by type
        let editAnnotations = pendingAnnotations.filter { $0.type == .edit }
        let verifyAnnotations = pendingAnnotations.filter { $0.type == .verify }
        let expandAnnotations = pendingAnnotations.filter { $0.type == .expand }
        let suggestAnnotations = pendingAnnotations.filter { $0.type == .suggest }
        let googleSlidesAnnotations = pendingAnnotations.filter { $0.type == .googleSlides }

        if !editAnnotations.isEmpty {
            prompt += "## Edit Instructions:\n\n"
            for (index, annotation) in editAnnotations.enumerated() {
                prompt += "\(index + 1). File: \(annotation.fileName)"
                if let line = annotation.lineNumber {
                    prompt += " (Line \(line))"
                }
                prompt += "\n"
                prompt += "   Selected text: \"\(annotation.selection.selectedText)\"\n"
                prompt += "   Instruction: \(annotation.instruction)\n"
                if !annotation.references.isEmpty {
                    prompt += "   References: \(annotation.references.joined(separator: ", "))\n"
                }
                prompt += "\n"
            }
        }

        if !verifyAnnotations.isEmpty {
            prompt += "## Consistency Checks:\n\n"
            for (index, annotation) in verifyAnnotations.enumerated() {
                prompt += "\(index + 1). File: \(annotation.fileName)\n"
                prompt += "   Check: \"\(annotation.selection.selectedText)\"\n"
                prompt += "   Instruction: \(annotation.instruction)\n\n"
            }
        }

        if !expandAnnotations.isEmpty {
            prompt += "## Content Expansion Requests:\n\n"
            for (index, annotation) in expandAnnotations.enumerated() {
                prompt += "\(index + 1). File: \(annotation.fileName)\n"
                prompt += "   Section: \"\(annotation.selection.selectedText)\"\n"
                prompt += "   Instruction: \(annotation.instruction)\n\n"
            }
        }

        if !suggestAnnotations.isEmpty {
            prompt += "## Suggestions:\n\n"
            for (index, annotation) in suggestAnnotations.enumerated() {
                prompt += "\(index + 1). File: \(annotation.fileName)\n"
                prompt += "   Suggestion: \(annotation.instruction)\n\n"
            }
        }

        if !googleSlidesAnnotations.isEmpty {
            prompt += "## Google Slides Creation Requests:\n\n"
            prompt += "IMPORTANT: You have access to MCP (Model Context Protocol) servers and tools that can create Google Slides presentations. Use these tools to create the presentations based on the following requests:\n\n"
            for (index, annotation) in googleSlidesAnnotations.enumerated() {
                prompt += "\(index + 1). Create Google Slides from: \(annotation.fileName)\n"
                prompt += "   Source text: \"\(annotation.selection.selectedText)\"\n"
                prompt += "   Instructions: \(annotation.instruction)\n"
                if !annotation.references.isEmpty {
                    prompt += "   Referenced files: \(annotation.references.joined(separator: ", "))\n"
                }
                prompt += "\n"
            }
        }

        return prompt
    }

    func generateClaudePromptWithFileContent() -> String {
        let pendingAnnotations = annotations.filter { $0.status == .pending }

        guard !pendingAnnotations.isEmpty else {
            return "No pending annotations to process."
        }

        var prompt = "I need you to make the following changes to my documents. I'm providing the full file content for each document so you have the complete context.\n\n"

        // Group annotations by file path to avoid duplicating file content
        var annotationsByFile: [String: [Annotation]] = [:]
        for annotation in pendingAnnotations {
            annotationsByFile[annotation.filePath, default: []].append(annotation)
        }

        // Process each file
        for (filePath, fileAnnotations) in annotationsByFile.sorted(by: { $0.key < $1.key }) {
            let fileName = fileAnnotations.first?.fileName ?? "Unknown"
            prompt += "## File: \(fileName)\n"
            prompt += "Path: \(filePath)\n\n"

            // Load the file content
            if let fileContent = loadFileContent(at: filePath) {
                prompt += "### Current File Content:\n```\n\(fileContent)\n```\n\n"
            } else {
                prompt += "### Current File Content:\n(Unable to load file content)\n\n"
            }

            // List all annotations for this file
            prompt += "### Requested Changes:\n\n"
            for (index, annotation) in fileAnnotations.enumerated() {
                prompt += "\(index + 1). "

                switch annotation.type {
                case .edit:
                    prompt += "**EDIT**"
                case .verify:
                    prompt += "**VERIFY**"
                case .expand:
                    prompt += "**EXPAND**"
                case .suggest:
                    prompt += "**SUGGEST**"
                case .googleSlides:
                    prompt += "**GOOGLE SLIDES**"
                }

                if let line = annotation.lineNumber {
                    prompt += " (Line \(line))"
                }
                prompt += "\n"

                prompt += "   Selected text: \"\(annotation.selection.selectedText)\"\n"
                prompt += "   Instruction: \(annotation.instruction)\n"

                if !annotation.references.isEmpty {
                    prompt += "   References: \(annotation.references.joined(separator: ", "))\n"
                }
                prompt += "\n"
            }

            prompt += "---\n\n"
        }

        prompt += "## Instructions:\n\n"
        prompt += "Please apply the requested changes to each file using the Edit tool. For each change:\n"
        prompt += "1. Use the Edit tool to modify the file directly\n"
        prompt += "2. Make precise edits based on the selected text and instructions\n"
        prompt += "3. Preserve all other content in the file\n"
        prompt += "4. After making all changes, provide a summary of what was changed\n\n"
        prompt += "IMPORTANT: Use the Edit tool to apply changes directly to the files on disk. Do not just describe the changes - actually make them.\n"

        return prompt
    }

    private func loadFileContent(at path: String) -> String? {
        do {
            let url = URL(fileURLWithPath: path)
            let content = try String(contentsOf: url, encoding: .utf8)
            return content
        } catch {
            print("❌ Error loading file content from \(path): \(error)")
            return nil
        }
    }

    private func saveAnnotations() {
        if let encoded = try? JSONEncoder().encode(annotations) {
            UserDefaults.standard.set(encoded, forKey: "annotations")
        }
    }

    private func loadAnnotations() {
        if let data = UserDefaults.standard.data(forKey: "annotations"),
           let decoded = try? JSONDecoder().decode([Annotation].self, from: data) {
            annotations = decoded
        }
    }

    // MARK: - Chat Management

    func createNewChat(title: String = "New Chat") {
        let chat = Chat(title: title)
        chats.insert(chat, at: 0) // Add to beginning
        currentChat = chat
        saveChats()
        print("💬 Created new chat: \(chat.displayTitle)")
    }

    func deleteChat(_ id: UUID) {
        chats.removeAll { $0.id == id }
        if currentChat?.id == id {
            currentChat = chats.first
        }
        saveChats()
        print("🗑️ Deleted chat")
    }

    func archiveChat(_ id: UUID) {
        if let index = chats.firstIndex(where: { $0.id == id }) {
            chats[index].isArchived = true
            chats[index].modified = Date()

            // If archiving the current chat, create a new one
            if currentChat?.id == id {
                createNewChat()
                print("📦 Archived current chat, created new chat")
            } else {
                print("📦 Archived chat")
            }

            saveChats()
        }
    }

    func unarchiveChat(_ id: UUID) {
        if let index = chats.firstIndex(where: { $0.id == id }) {
            chats[index].isArchived = false
            chats[index].modified = Date()
            saveChats()
            print("📤 Unarchived chat")
        }
    }

    func updateChatTitle(_ id: UUID, title: String) {
        if let index = chats.firstIndex(where: { $0.id == id }) {
            chats[index].title = title
            chats[index].modified = Date()
            saveChats()
        }
    }

    func addMessageToCurrentChat(_ message: ChatMessage) {
        guard var chat = currentChat else {
            // Create new chat if none exists
            createNewChat()
            guard var chat = currentChat else { return }
            chat.addMessage(message)
            updateChat(chat)
            return
        }

        var updatedChat = chat
        updatedChat.addMessage(message)
        updateChat(updatedChat)
    }

    func updateChat(_ chat: Chat) {
        if let index = chats.firstIndex(where: { $0.id == chat.id }) {
            chats[index] = chat
        }
        if currentChat?.id == chat.id {
            currentChat = chat
        }
        saveChats()
    }

    func selectChat(_ chat: Chat) {
        currentChat = chat
        isChatPopupOpen = true
    }

    func addFileToCurrentChat(_ filePath: String) {
        guard var chat = currentChat else { return }
        chat.addRelatedFile(filePath)
        updateChat(chat)
    }

    func removeFileFromCurrentChat(_ filePath: String) {
        guard var chat = currentChat else { return }
        chat.removeRelatedFile(filePath)
        updateChat(chat)
    }

    func addFolderToCurrentChat(_ folderPath: String) {
        guard var chat = currentChat else { return }
        chat.addRelatedFolder(folderPath)
        updateChat(chat)
    }

    func removeFolderFromCurrentChat(_ folderPath: String) {
        guard var chat = currentChat else { return }
        chat.removeRelatedFolder(folderPath)
        updateChat(chat)
    }

    var activeChats: [Chat] {
        chats.filter { !$0.isArchived }.sorted { $0.modified > $1.modified }
    }

    var archivedChats: [Chat] {
        chats.filter { $0.isArchived }.sorted { $0.modified > $1.modified }
    }

    private func saveChats() {
        if let encoded = try? JSONEncoder().encode(chats) {
            UserDefaults.standard.set(encoded, forKey: "chats")
        }
    }

    private func loadChats() {
        if let data = UserDefaults.standard.data(forKey: "chats"),
           let decoded = try? JSONDecoder().decode([Chat].self, from: data) {
            chats = decoded
            // Set current chat to the most recent active chat
            currentChat = chats.filter { !$0.isArchived }.sorted { $0.modified > $1.modified }.first
        }
    }

    func openFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select a folder to open in BetterDocs"

        panel.begin { [weak self] response in
            guard let self = self, response == .OK, let url = panel.url else { return }

            Task {
                await self.loadFolder(at: url)
            }
        }
    }

    func loadFolder(at url: URL) async {
        isLoading = true
        defer { isLoading = false }

        do {
            _ = url.startAccessingSecurityScopedResource()
            defer { url.stopAccessingSecurityScopedResource() }

            print("📂 Loading folder: \(url.path)")
            let folder = try await documentService.scanFolder(at: url)
            self.rootFolder = folder
            print("✅ Loaded \(folder.children.count) items from \(folder.name)")

            // Save as last opened folder
            saveLastFolder(url)

            // Index for search (simplified for now)
            await searchService.indexFolder(folder)

            // Refresh git status
            refreshGitStatus()

            // Start watching the folder for changes
            fileWatcher.watch(path: url) { [weak self] in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    print("🔄 File system changed, reloading folder...")
                    await self.loadFolder(at: url)
                }
            }
        } catch {
            print("❌ Error loading folder: \(error.localizedDescription)")
        }
    }

    func selectItem(_ item: any FileSystemItem) {
        selectedItem = item
        saveLastSelectedItem(item)

        // Update preview tab (ephemeral tab for single-clicks)
        let tabName = extractTabName(from: item)
        let newPreviewTab = DocumentTab(itemID: item.id, itemName: tabName, itemPath: item.path.path)
        previewTab = newPreviewTab

        // If no pinned tabs are open, or if the active tab is the preview tab, use the preview tab
        if openTabs.isEmpty || activeTabID == previewTab?.id {
            activeTabID = newPreviewTab.id
        }
    }

    func search(_ query: String) {
        searchQuery = query

        // Clear results if query is empty
        guard !query.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }

        isSearching = true

        // Perform search
        let results = searchService.search(query, in: rootFolder)
        searchResults = results

        print("🔍 Search for '\(query)' found \(results.count) results")
    }

    func clearSearch() {
        searchQuery = ""
        searchResults = []
        isSearching = false
    }

    func revealInFolderTree() {
        // Clear search to show folder tree
        clearSearch()
        // The NavigationView will handle expanding to show the selected item
    }

    // MARK: - Tab Management

    func openInTab(_ item: any FileSystemItem) {
        // Check if tab already exists in pinned tabs
        if let existingTab = openTabs.first(where: { $0.itemID == item.id }) {
            // Switch to existing pinned tab
            activeTabID = existingTab.id
            selectedItem = item
            saveOpenTabs()
            return
        }

        // Create new pinned tab with extracted title
        let tabName = extractTabName(from: item)
        let newTab = DocumentTab(itemID: item.id, itemName: tabName, itemPath: item.path.path)
        openTabs.append(newTab)
        activeTabID = newTab.id
        selectedItem = item
        saveOpenTabs()
        print("📑 Opened new tab: \(tabName)")
    }

    func closeTab(_ tabID: UUID) {
        guard let index = openTabs.firstIndex(where: { $0.id == tabID }) else { return }

        let wasActive = activeTabID == tabID
        openTabs.remove(at: index)

        // If we closed the active tab, switch to another tab
        if wasActive {
            if !openTabs.isEmpty {
                // Switch to the previous tab, or the first one if we closed the first tab
                let newIndex = max(0, index - 1)
                if newIndex < openTabs.count {
                    switchToTab(openTabs[newIndex].id)
                }
            } else {
                // No more pinned tabs, switch to preview tab if available
                if let preview = previewTab {
                    activeTabID = preview.id
                } else {
                    activeTabID = nil
                    selectedItem = nil
                }
            }
        }

        saveOpenTabs()
        print("📑 Closed tab, \(openTabs.count) remaining")
    }

    func switchToTab(_ tabID: UUID) {
        guard let tab = openTabs.first(where: { $0.id == tabID }) else { return }

        activeTabID = tabID

        // Find and select the item
        if let rootFolder = rootFolder,
           let item = rootFolder.findItem(withID: tab.itemID) {
            selectedItem = item
        }

        saveOpenTabs()
    }

    func selectNextTab() {
        guard !openTabs.isEmpty else { return }

        if let activeTabID = activeTabID,
           let currentIndex = openTabs.firstIndex(where: { $0.id == activeTabID }) {
            let nextIndex = (currentIndex + 1) % openTabs.count
            switchToTab(openTabs[nextIndex].id)
        } else if let firstTab = openTabs.first {
            switchToTab(firstTab.id)
        }
    }

    func selectPreviousTab() {
        guard !openTabs.isEmpty else { return }

        if let activeTabID = activeTabID,
           let currentIndex = openTabs.firstIndex(where: { $0.id == activeTabID }) {
            let previousIndex = currentIndex == 0 ? openTabs.count - 1 : currentIndex - 1
            switchToTab(openTabs[previousIndex].id)
        } else if let lastTab = openTabs.last {
            switchToTab(lastTab.id)
        }
    }

    func updateTabScrollPosition(_ tabID: UUID, position: CGPoint) {
        // Update scroll position for pinned tabs
        if let index = openTabs.firstIndex(where: { $0.id == tabID }) {
            openTabs[index].scrollPosition = position
        }
        // Update scroll position for preview tab
        if previewTab?.id == tabID {
            previewTab?.scrollPosition = position
        }
    }

    func getTabScrollPosition(_ tabID: UUID) -> CGPoint {
        // Check pinned tabs
        if let tab = openTabs.first(where: { $0.id == tabID }) {
            return tab.scrollPosition
        }
        // Check preview tab
        if let preview = previewTab, preview.id == tabID {
            return preview.scrollPosition
        }
        return .zero
    }

    // MARK: - Helper Functions

    private func extractTabName(from item: any FileSystemItem) -> String {
        // For folders, just use the name
        guard let document = item as? Document else {
            return item.name
        }

        // For markdown files, try to extract the first H1 title
        if document.type == .markdown, let content = document.content {
            // Look for # Title or other H1 patterns
            let lines = content.components(separatedBy: .newlines)
            for line in lines.prefix(20) { // Check first 20 lines
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                // Check for # Title format
                if trimmed.hasPrefix("#") && !trimmed.hasPrefix("##") {
                    let title = trimmed.dropFirst().trimmingCharacters(in: .whitespaces)
                    if !title.isEmpty {
                        return truncateTabName(title)
                    }
                }
            }
        }

        // Fallback to filename without extension
        let nameWithoutExt = (item.name as NSString).deletingPathExtension
        return truncateTabName(nameWithoutExt)
    }

    private func truncateTabName(_ name: String) -> String {
        // Truncate to max 30 characters with ellipsis
        if name.count > 30 {
            let index = name.index(name.startIndex, offsetBy: 27)
            return String(name[..<index]) + "..."
        }
        return name
    }

    // MARK: - File Management Operations

    /// Create a new file in the specified folder
    func createNewFile(in folder: Folder, fileType: FileType) {
        Task {
            do {
                // Create temporary file with minimal placeholder content
                let initialContent = "" // Start with empty content
                let timestamp = Date().timeIntervalSince1970
                let tempName = "untitled-\(Int(timestamp))" // Simple timestamp-based name

                let fileURL = try fileManagementService.createTextFile(
                    at: folder.path,
                    name: tempName,
                    fileType: fileType,
                    initialContent: initialContent
                )

                logInfo("✅ Created file: \(fileURL.lastPathComponent)")

                // Refresh the folder to show the new file
                await refreshFolder()

                // Auto-select and open the new file in EDIT mode
                if let rootFolder = self.rootFolder,
                   let newFile = findItem(byPath: fileURL.path, in: rootFolder) {
                    selectItem(newFile)
                    openInTab(newFile)
                    // Switch to edit mode so user can start typing
                    isEditMode = true
                }
            } catch {
                logError("❌ Failed to create file: \(error)")
            }
        }
    }

    /// Move a file from source URL to destination folder
    func moveFile(from sourceURL: URL, to destinationFolder: Folder) {
        Task {
            do {
                let destinationURL = try fileManagementService.moveFile(
                    from: sourceURL,
                    to: destinationFolder.path
                )

                logInfo("✅ Moved file to: \(destinationURL.path)")

                // Delay refresh slightly to allow file system to settle
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

                // Refresh the folder tree
                await refreshFolder()

                // Small delay before trying to select, to allow view to update
                try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds

                // Auto-select the moved file
                if let rootFolder = self.rootFolder,
                   let movedFile = findItem(byPath: destinationURL.path, in: rootFolder) {
                    selectItem(movedFile)
                }
            } catch {
                logError("❌ Failed to move file: \(error)")
            }
        }
    }

    /// Rename a file or folder
    func renameItem(_ item: any FileSystemItem, newName: String) {
        Task {
            do {
                let renamedURL = try fileManagementService.renameItem(
                    at: item.path,
                    newName: newName,
                    preserveExtension: true
                )

                logInfo("✅ Renamed to: \(renamedURL.lastPathComponent)")

                // Refresh the folder tree
                await refreshFolder()

                // Re-select the renamed item
                if let rootFolder = self.rootFolder,
                   let renamedItem = findItem(byPath: renamedURL.path, in: rootFolder) {
                    selectItem(renamedItem)
                }
            } catch {
                logError("❌ Failed to rename: \(error)")
            }
        }
    }

    /// Rename a file using AI based on its content
    func renameWithAI(_ item: any FileSystemItem) {
        Task {
            do {
                // Load file content
                guard let content = try? String(contentsOf: item.path, encoding: .utf8),
                      !content.isEmpty else {
                    logWarning("⚠️ Cannot rename: file is empty")
                    return
                }

                logInfo("🤖 Generating AI filename...")

                // Generate AI filename
                let fileExtension = item.path.pathExtension
                let aiFilename = try await claudeService.generateFilename(
                    content: content,
                    fileType: ".\(fileExtension)"
                )

                // Rename the file
                let renamedURL = try fileManagementService.renameItem(
                    at: item.path,
                    newName: aiFilename,
                    preserveExtension: true
                )

                logInfo("✅ AI renamed to: \(renamedURL.lastPathComponent)")

                // Refresh the folder tree
                await refreshFolder()

                // Re-select the renamed item
                if let rootFolder = self.rootFolder,
                   let renamedItem = findItem(byPath: renamedURL.path, in: rootFolder) {
                    selectItem(renamedItem)
                }
            } catch {
                logError("❌ Failed to AI rename: \(error)")
            }
        }
    }

    /// Delete a file or folder
    func deleteItem(_ item: any FileSystemItem) {
        Task {
            do {
                try fileManagementService.deleteItem(at: item.path)

                logInfo("✅ Deleted: \(item.name)")

                // Clear selection if deleted item was selected
                if selectedItem?.id == item.id {
                    selectedItem = nil
                }

                // Refresh the folder tree
                await refreshFolder()
            } catch {
                logError("❌ Failed to delete: \(error)")
            }
        }
    }

    /// Reveal item in Finder
    func revealInFinder(_ item: any FileSystemItem) {
        NSWorkspace.shared.activateFileViewerSelecting([item.path])
    }

    /// Refresh the current folder
    func refreshFolder() async {
        guard let rootFolder = rootFolder else { return }

        // Reload the folder
        await loadFolder(at: rootFolder.path)
    }

    // MARK: - Git Operations

    /// Refresh git status for the current folder
    func refreshGitStatus() {
        guard let rootFolder = rootFolder else { return }

        Task {
            do {
                gitStatus = try await gitService.getStatus(at: rootFolder.path)
            } catch {
                // Silently fail - just keep old status
                gitStatus = .empty
            }
        }
    }

    /// Commit changes with a message
    func performGitCommit(message: String) {
        guard let rootFolder = rootFolder else { return }

        Task {
            isPerformingGitOperation = true
            defer { isPerformingGitOperation = false }

            do {
                try await gitService.commit(message: message, at: rootFolder.path)
                logInfo("✅ Git commit successful")
                await refreshGitStatus()
            } catch {
                logError("❌ Git commit failed: \(error.localizedDescription)")
            }
        }
    }

    /// Push changes to remote
    func performGitPush() {
        guard let rootFolder = rootFolder else { return }

        Task {
            isPerformingGitOperation = true
            defer { isPerformingGitOperation = false }

            do {
                logInfo("🔄 Pushing to remote...")
                try await gitService.push(at: rootFolder.path)
                logInfo("✅ Git push successful")
                await refreshGitStatus()
            } catch {
                logError("❌ Git push failed: \(error.localizedDescription)")
            }
        }
    }

    /// Pull changes from remote
    func performGitPull() {
        guard let rootFolder = rootFolder else { return }

        Task {
            isPerformingGitOperation = true
            defer { isPerformingGitOperation = false }

            do {
                logInfo("🔄 Pulling from remote...")
                try await gitService.pull(at: rootFolder.path)
                logInfo("✅ Git pull successful")
                await refreshFolder() // Refresh folder to show updated files
                await refreshGitStatus()
            } catch {
                logError("❌ Git pull failed: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - DocumentTab Model

struct DocumentTab: Identifiable, Equatable {
    let id = UUID()
    let itemID: UUID
    var itemName: String // Changed to var to allow updating
    let itemPath: String
    var scrollPosition: CGPoint = .zero // Store scroll position

    static func == (lhs: DocumentTab, rhs: DocumentTab) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - View Mode

enum ViewMode: String {
    case list
    case grid
}
