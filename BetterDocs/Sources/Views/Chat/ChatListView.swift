import SwiftUI

struct ChatListView: View {
    @Environment(AppState.self) private var appState
    @State private var searchQuery: String = ""
    @State private var showArchived: Bool = false
    @State private var editingChatID: UUID?
    @State private var editingTitle: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Chats")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                Button(action: {
                    appState.createNewChat()
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                .help("New Chat")

                Button(action: {
                    appState.showChatList = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Close")
            }
            .padding()

            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search chats...", text: $searchQuery)
                    .textFieldStyle(.plain)

                if !searchQuery.isEmpty {
                    Button(action: { searchQuery = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .padding(.horizontal)

            // Toggle between active and archived
            Picker("", selection: $showArchived) {
                Text("Active").tag(false)
                Text("Archived").tag(true)
            }
            .pickerStyle(.segmented)
            .padding()

            Divider()

            // Chat list
            ScrollView {
                LazyVStack(spacing: 0) {
                    let chats = filteredChats
                    if chats.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: showArchived ? "archivebox" : "bubble.left.and.bubble.right")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)

                            Text(showArchived ? "No archived chats" : "No chats yet")
                                .font(.headline)
                                .foregroundColor(.secondary)

                            if !showArchived {
                                Text("Click + to create a new chat")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                    } else {
                        ForEach(chats) { chat in
                            ChatListRow(
                                chat: chat,
                                isEditing: editingChatID == chat.id,
                                editingTitle: $editingTitle,
                                onSelect: {
                                    appState.selectChat(chat)
                                    appState.showChatList = false
                                },
                                onEdit: {
                                    editingChatID = chat.id
                                    editingTitle = chat.title
                                },
                                onSaveEdit: {
                                    if !editingTitle.isEmpty {
                                        appState.updateChatTitle(chat.id, title: editingTitle)
                                    }
                                    editingChatID = nil
                                },
                                onArchive: {
                                    if showArchived {
                                        appState.unarchiveChat(chat.id)
                                    } else {
                                        appState.archiveChat(chat.id)
                                    }
                                },
                                onDelete: {
                                    appState.deleteChat(chat.id)
                                }
                            )

                            if chat.id != chats.last?.id {
                                Divider()
                                    .padding(.leading)
                            }
                        }
                    }
                }
            }
        }
        .frame(width: 400)
        .background(.ultraThinMaterial)
    }

    private var filteredChats: [Chat] {
        let baseChats = showArchived ? appState.archivedChats : appState.activeChats

        if searchQuery.isEmpty {
            return baseChats
        }

        return baseChats.filter { chat in
            chat.displayTitle.localizedCaseInsensitiveContains(searchQuery) ||
            chat.messages.contains { $0.content.localizedCaseInsensitiveContains(searchQuery) }
        }
    }
}

// MARK: - Chat List Row

struct ChatListRow: View {
    let chat: Chat
    let isEditing: Bool
    @Binding var editingTitle: String
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onSaveEdit: () -> Void
    let onArchive: () -> Void
    let onDelete: () -> Void

    @State private var isHovered: Bool = false
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                // Chat icon
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .foregroundColor(.accentColor)
                    .font(.title3)
                    .frame(width: 24)

                // Chat content
                VStack(alignment: .leading, spacing: 4) {
                    if isEditing {
                        TextField("Chat title", text: $editingTitle, onCommit: onSaveEdit)
                            .textFieldStyle(.plain)
                            .font(.body)
                            .fontWeight(.medium)
                    } else {
                        Text(chat.displayTitle)
                            .font(.body)
                            .fontWeight(.medium)
                            .lineLimit(1)
                    }

                    HStack(spacing: 8) {
                        // Message count
                        Label("\(chat.messages.count)", systemImage: "message")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        // File count
                        if !chat.relatedFiles.isEmpty {
                            Label("\(chat.relatedFiles.count)", systemImage: "doc")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        // Folder count
                        if !chat.relatedFolders.isEmpty {
                            Label("\(chat.relatedFolders.count)", systemImage: "folder")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        // Last modified
                        Text(chat.lastMessageDate, style: .relative)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                // Action buttons (visible on hover)
                if isHovered && !isEditing {
                    HStack(spacing: 8) {
                        Button(action: onEdit) {
                            Image(systemName: "pencil")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                        .help("Rename")

                        Button(action: onArchive) {
                            Image(systemName: chat.isArchived ? "tray.and.arrow.up" : "archivebox")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        .buttonStyle(.plain)
                        .help(chat.isArchived ? "Unarchive" : "Archive")

                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                        .help("Delete")
                    }
                }
            }
            .padding()
            .background(
                Group {
                    if appState.currentChat?.id == chat.id {
                        Color.accentColor.opacity(0.15)
                    } else if isHovered {
                        Color.secondary.opacity(0.08)
                    } else {
                        Color.clear
                    }
                }
            )
            .onHover { hovering in
                isHovered = hovering
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if !isEditing {
                    onSelect()
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ChatListView()
        .environment(AppState())
}
