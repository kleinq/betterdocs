import SwiftUI

struct CommandPaletteView: View {
    @Environment(AppState.self) private var appState
    @Binding var isOpen: Bool
    @State private var searchQuery: String = ""
    @State private var selectedIndex: Int = 0
    @State private var showGitCommitDialog: Bool = false
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        ZStack {
            // Overlay background
            if isOpen {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        closePanel()
                    }

                // Command Palette Panel
                VStack(spacing: 0) {
                    // Search field
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                            .font(.title3)

                        TextField("Type to search files or commands...", text: $searchQuery)
                            .textFieldStyle(.plain)
                            .font(.title3)
                            .focused($isSearchFocused)
                            .onSubmit {
                                selectCurrentItem()
                            }

                        if !searchQuery.isEmpty {
                            Button(action: { searchQuery = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)

                    Divider()

                    // Results
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                if searchQuery.isEmpty {
                                    // Show recent files and actions
                                    recentFilesSection
                                    Divider()
                                    actionsSection
                                    Divider()
                                    gitOperationsSection
                                } else {
                                    // Show search results
                                    searchResultsSection
                                }
                            }
                        }
                        .frame(maxHeight: 400)
                        .onChange(of: selectedIndex) { _, newIndex in
                            withAnimation {
                                proxy.scrollTo(newIndex, anchor: .center)
                            }
                        }
                    }
                }
                .frame(width: 600)
                .background(.ultraThinMaterial)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(NSColor.windowBackgroundColor).opacity(0.95))
                        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.top, 100)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.95).combined(with: .opacity),
                    removal: .scale(scale: 0.95).combined(with: .opacity)
                ))
            }
        }
        .onChange(of: isOpen) { _, newValue in
            if newValue {
                isSearchFocused = true
                searchQuery = ""
                selectedIndex = 0
            }
        }
        .onKeyPress(.downArrow) {
            moveSelection(down: true)
            return .handled
        }
        .onKeyPress(.upArrow) {
            moveSelection(down: false)
            return .handled
        }
        .onKeyPress(.escape) {
            closePanel()
            return .handled
        }
        .sheet(isPresented: $showGitCommitDialog) {
            GitCommitDialog()
                .environment(appState)
        }
    }

    // MARK: - Recent Files Section

    private var recentFilesSection: some View {
        Group {
            if !appState.openTabs.isEmpty {
                Section {
                    ForEach(Array(appState.openTabs.enumerated()), id: \.element.id) { index, tab in
                        CommandPaletteRow(
                            icon: "doc.text",
                            title: tab.itemName,
                            subtitle: tab.itemPath,
                            shortcut: index < 9 ? "⌘\(index + 1)" : nil,
                            isSelected: selectedIndex == index
                        )
                        .id(index)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectTab(tab)
                        }
                    }
                } header: {
                    Text("RECENT FILES")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.top, 12)
                        .padding(.bottom, 6)
                }
            }
        }
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        Section {
            let baseIndex = appState.openTabs.count

            CommandPaletteRow(
                icon: "gear",
                title: "Open Settings",
                subtitle: "Configure BetterDocs",
                shortcut: "⌘,",
                isSelected: selectedIndex == baseIndex
            )
            .id(baseIndex)
            .contentShape(Rectangle())
            .onTapGesture {
                openSettings()
            }

            CommandPaletteRow(
                icon: "arrow.clockwise",
                title: "Refresh Folder",
                subtitle: "Reload current folder",
                shortcut: "⌘R",
                isSelected: selectedIndex == baseIndex + 1
            )
            .id(baseIndex + 1)
            .contentShape(Rectangle())
            .onTapGesture {
                refreshFolder()
            }

            CommandPaletteRow(
                icon: "sidebar.right",
                title: "Toggle Document Outline",
                subtitle: "Show or hide outline",
                shortcut: "⌘⇧L",
                isSelected: selectedIndex == baseIndex + 2
            )
            .id(baseIndex + 2)
            .contentShape(Rectangle())
            .onTapGesture {
                toggleOutline()
            }

            CommandPaletteRow(
                icon: "folder",
                title: "Open Folder",
                subtitle: "Select a new folder to browse",
                shortcut: "⌘O",
                isSelected: selectedIndex == baseIndex + 3
            )
            .id(baseIndex + 3)
            .contentShape(Rectangle())
            .onTapGesture {
                openFolder()
            }
        } header: {
            Text("ACTIONS")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 6)
        }
    }

    // MARK: - Git Operations Section

    private var gitOperationsSection: some View {
        Group {
            if appState.gitStatus.isGitRepository {
                Section {
                    let baseIndex = appState.openTabs.count + 4 // After recent files + 4 actions

                    CommandPaletteRow(
                        icon: "checkmark.circle",
                        title: "Git Commit",
                        subtitle: appState.gitStatus.hasUncommittedChanges ?
                            "\(appState.gitStatus.modifiedFiles.count + appState.gitStatus.untrackedFiles.count + appState.gitStatus.stagedFiles.count) changes" :
                            "No changes to commit",
                        shortcut: "⌘⇧C",
                        isSelected: selectedIndex == baseIndex
                    )
                    .id(baseIndex)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        gitCommit()
                    }
                    .opacity(appState.gitStatus.hasUncommittedChanges ? 1.0 : 0.5)

                    CommandPaletteRow(
                        icon: "arrow.up.circle",
                        title: "Git Push",
                        subtitle: appState.gitStatus.hasUnpushedCommits ?
                            "↑\(appState.gitStatus.ahead) commits to push" :
                            "Nothing to push",
                        shortcut: "⌘⇧P",
                        isSelected: selectedIndex == baseIndex + 1
                    )
                    .id(baseIndex + 1)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        gitPush()
                    }
                    .opacity(appState.gitStatus.ahead > 0 || appState.gitStatus.hasUncommittedChanges ? 1.0 : 0.5)

                    CommandPaletteRow(
                        icon: "arrow.down.circle",
                        title: "Git Pull",
                        subtitle: appState.gitStatus.behind > 0 ?
                            "↓\(appState.gitStatus.behind) commits to pull" :
                            "Up to date",
                        shortcut: nil,
                        isSelected: selectedIndex == baseIndex + 2
                    )
                    .id(baseIndex + 2)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        gitPull()
                    }
                } header: {
                    HStack {
                        Text("GIT OPERATIONS")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if let branch = appState.gitStatus.currentBranch {
                            Text("[\(branch)]")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .padding(.bottom, 6)
                }
            }
        }
    }

    // MARK: - Search Results Section

    private var searchResultsSection: some View {
        Group {
            // Use SearchService for full-text search instead of just fuzzy filename matching
            let searchResults = appState.searchService.search(searchQuery, in: appState.rootFolder, filter: .default)

            if searchResults.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.5))

                    Text("No results found")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Text("Try a different search term")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ForEach(Array(searchResults.prefix(20).enumerated()), id: \.element.id) { index, result in
                    let matchContext = result.matches.first?.preview ?? result.item.path.path
                    CommandPaletteRow(
                        icon: iconForItem(result.item),
                        title: result.item.name,
                        subtitle: matchContext,
                        shortcut: nil,
                        isSelected: selectedIndex == index
                    )
                    .id(index)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectItem(result.item)
                    }
                }
            }
        }
    }

    // MARK: - Helper Methods

    private func collectAllItems() -> [any FileSystemItem] {
        guard let rootFolder = appState.rootFolder else { return [] }
        var items: [any FileSystemItem] = []

        func traverse(_ folder: Folder) {
            // Add the folder itself to the searchable items
            items.append(folder)

            // Add all children
            for child in folder.children {
                if let subfolder = child as? Folder {
                    // Recursively traverse subfolders
                    traverse(subfolder)
                } else {
                    // Add files directly
                    items.append(child)
                }
            }
        }

        traverse(rootFolder)
        return items
    }

    private func iconForItem(_ item: any FileSystemItem) -> String {
        if item is Folder {
            return "folder"
        } else if let doc = item as? Document {
            switch doc.type {
            case .markdown:
                return "doc.text"
            case .pdf:
                return "doc.richtext"
            case .image:
                return "photo"
            case .code:
                return "chevron.left.forwardslash.chevron.right"
            default:
                return "doc"
            }
        }
        return "doc"
    }

    private func moveSelection(down: Bool) {
        let maxIndex: Int
        if searchQuery.isEmpty {
            // Recent files + 4 actions + 3 git operations (if git repo)
            let gitOperationsCount = appState.gitStatus.isGitRepository ? 3 : 0
            maxIndex = appState.openTabs.count + 3 + gitOperationsCount
        } else {
            // Calculate based on actual search results
            let fuzzyResults = FuzzySearch.search(searchQuery, in: collectAllItems(), keyPath: \.name)
            maxIndex = min(fuzzyResults.count - 1, 19) // Max 20 search results
        }

        if down {
            selectedIndex = min(selectedIndex + 1, maxIndex)
        } else {
            selectedIndex = max(selectedIndex - 1, 0)
        }
    }

    private func selectCurrentItem() {
        if searchQuery.isEmpty {
            // Recent files or actions
            if selectedIndex < appState.openTabs.count {
                selectTab(appState.openTabs[selectedIndex])
            } else {
                let actionIndex = selectedIndex - appState.openTabs.count
                switch actionIndex {
                case 0: openSettings()
                case 1: refreshFolder()
                case 2: toggleOutline()
                case 3: openFolder()
                case 4: gitCommit()
                case 5: gitPush()
                case 6: gitPull()
                default: break
                }
            }
        } else {
            // Search results
            let fuzzyResults = FuzzySearch.search(searchQuery, in: collectAllItems(), keyPath: \.name)
            if selectedIndex < fuzzyResults.count {
                selectItem(fuzzyResults[selectedIndex].item)
            }
        }
    }

    private func selectTab(_ tab: DocumentTab) {
        appState.switchToTab(tab.id)
        closePanel()
    }

    private func selectItem(_ item: any FileSystemItem) {
        if item is Folder {
            appState.selectItem(item)
        } else {
            appState.openInTab(item)
        }
        closePanel()
    }

    private func openSettings() {
        // Open settings window
        closePanel()
        // TODO: Open settings window
        if let url = URL(string: "betterdocs://settings") {
            NSWorkspace.shared.open(url)
        }
    }

    private func refreshFolder() {
        if let rootFolder = appState.rootFolder {
            Task {
                await appState.loadFolder(at: rootFolder.path)
            }
        }
        closePanel()
    }

    private func toggleOutline() {
        appState.toggleOutline()
        closePanel()
    }

    private func openFolder() {
        appState.openFolder()
        closePanel()
    }

    private func gitCommit() {
        if appState.gitStatus.hasUncommittedChanges {
            showGitCommitDialog = true
            closePanel()
        }
    }

    private func gitPush() {
        if appState.gitStatus.ahead > 0 || appState.gitStatus.hasUncommittedChanges {
            appState.performGitPush()
            closePanel()
        }
    }

    private func gitPull() {
        appState.performGitPull()
        closePanel()
    }

    private func closePanel() {
        withAnimation(.spring(response: 0.2, dampingFraction: 0.9)) {
            isOpen = false
        }
    }
}

// MARK: - Command Palette Row

struct CommandPaletteRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let shortcut: String?
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .foregroundColor(.primary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if let shortcut = shortcut {
                Text(shortcut)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        .contentShape(Rectangle())
    }
}

#Preview {
    CommandPaletteView(isOpen: .constant(true))
        .environment(AppState())
}
