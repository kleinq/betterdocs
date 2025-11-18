import SwiftUI

struct ToolbarView: View {
    @Environment(AppState.self) private var appState
    @State private var searchText: String = ""
    @FocusState private var isSearchFocused: Bool

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

                Button(action: { /* TODO */ }) {
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

            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("Search files and content...", text: $searchText)
                    .textFieldStyle(.plain)
                    .frame(width: 300)
                    .focused($isSearchFocused)
                    .onChange(of: searchText) { _, newValue in
                        appState.search(newValue)
                    }
                    .onKeyPress(.escape) {
                        searchText = ""
                        appState.clearSearch()
                        isSearchFocused = false
                        return .handled
                    }

                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        appState.clearSearch()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("FocusSearch"))) { _ in
                isSearchFocused = true
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
}

#Preview {
    ToolbarView()
        .environment(AppState())
        .frame(height: 50)
}
