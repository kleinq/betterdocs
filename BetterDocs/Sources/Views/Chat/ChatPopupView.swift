import SwiftUI

struct ChatPopupView: View {
    @Binding var isOpen: Bool
    @Environment(AppState.self) private var appState
    @State private var chatInput: String = ""
    @State private var isLoading: Bool = false
    @FocusState private var isInputFocused: Bool
    @State private var isAnnotationsExpanded: Bool = false
    @State private var isAuditLogExpanded: Bool = false
    @State private var isRelatedFilesExpanded: Bool = true
    @State private var auditLog: [AuditLogEntry] = []
    @State private var inputHeight: CGFloat = 80
    @State private var showingFilePicker: Bool = false

    private var messages: [ChatMessage] {
        appState.currentChat?.messages ?? []
    }

    private var relatedFiles: [String] {
        appState.currentChat?.relatedFiles ?? []
    }

    private var relatedFolders: [String] {
        appState.currentChat?.relatedFolders ?? []
    }

    var body: some View {
        ZStack {
            if isOpen {
                // Overlay background
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        closeChatPopup()
                    }

                // Chat popup positioned at bottom (full width like Chrome console)
                VStack(spacing: 0) {
                    Spacer()

                    VStack(spacing: 0) {
                        // Header with chat controls
                        HStack(spacing: 16) {
                            HStack(spacing: 8) {
                                Image(systemName: "bubble.left.and.bubble.right.fill")
                                    .foregroundColor(.accentColor)

                                Text(appState.currentChat?.displayTitle ?? "Chat")
                                    .font(.headline)
                                    .lineLimit(1)
                            }

                            // New chat button
                            Button(action: {
                                appState.createNewChat()
                            }) {
                                Image(systemName: "square.and.pencil")
                                    .foregroundColor(.accentColor)
                                    .font(.caption)
                            }
                            .buttonStyle(.plain)
                            .help("New Chat")

                            // Chat list button
                            Button(action: {
                                appState.showChatList = true
                            }) {
                                Image(systemName: "list.bullet")
                                    .foregroundColor(.accentColor)
                                    .font(.caption)
                            }
                            .buttonStyle(.plain)
                            .help("All Chats")

                            // Annotation queue indicator - now a button to toggle
                            let pendingAnnotations = appState.annotations.filter { $0.status == .pending }
                            if !pendingAnnotations.isEmpty {
                                Button(action: {
                                    withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                                        isAnnotationsExpanded.toggle()
                                    }
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "tag.fill")
                                            .foregroundColor(.orange)
                                            .font(.caption)
                                        Text("\(pendingAnnotations.count) pending")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Image(systemName: isAnnotationsExpanded ? "chevron.up" : "chevron.down")
                                            .foregroundColor(.secondary)
                                            .font(.caption2)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.orange.opacity(0.1))
                                    .cornerRadius(4)
                                }
                                .buttonStyle(.plain)
                            }

                            // Audit log indicator
                            if !auditLog.isEmpty {
                                Button(action: {
                                    withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                                        isAuditLogExpanded.toggle()
                                    }
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "doc.text.magnifyingglass")
                                            .foregroundColor(.blue)
                                            .font(.caption)
                                        Text("\(auditLog.count) actions")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Image(systemName: isAuditLogExpanded ? "chevron.up" : "chevron.down")
                                            .foregroundColor(.secondary)
                                            .font(.caption2)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(4)
                                }
                                .buttonStyle(.plain)
                            }

                            Spacer()

                            Button(action: { closeChatPopup() }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding()
                        .background(.ultraThinMaterial)

                        Divider()

                        // Annotation List (if expanded)
                        if isAnnotationsExpanded {
                            AnnotationListSection(
                                annotations: appState.annotations.filter { $0.status == .pending },
                                onSelectAnnotation: navigateToAnnotation,
                                onDeleteAnnotation: { annotation in
                                    appState.removeAnnotation(annotation.id)
                                },
                                onEditAnnotation: { annotation in
                                    copyAnnotationToChat(annotation)
                                }
                            )

                            Divider()
                        }

                        // Audit Log (if expanded)
                        if isAuditLogExpanded {
                            AuditLogSection(entries: auditLog)
                            Divider()
                        }

                        // Related Files Section (always show when there are files)
                        if !relatedFiles.isEmpty || !relatedFolders.isEmpty {
                            RelatedFilesSection(
                                files: relatedFiles,
                                folders: relatedFolders,
                                isExpanded: $isRelatedFilesExpanded,
                                onNavigateToFile: navigateToFile,
                                onRemoveFile: { filePath in
                                    appState.removeFileFromCurrentChat(filePath)
                                },
                                onRemoveFolder: { folderPath in
                                    appState.removeFolderFromCurrentChat(folderPath)
                                },
                                onAddMore: {
                                    showingFilePicker = true
                                }
                            )
                            Divider()
                        }

                        // Messages area
                        ScrollViewReader { proxy in
                            ScrollView {
                                VStack(alignment: .leading, spacing: 12) {
                                    let _ = print("[CHAT-UI] Rendering messages area. Count: \(messages.count)")
                                    if messages.isEmpty {
                                        let _ = print("[CHAT-UI] Showing empty state")
                                        VStack(spacing: 8) {
                                            Image(systemName: "bubble.left.and.bubble.right")
                                                .font(.system(size: 32))
                                                .foregroundColor(.secondary)

                                            Text("Ask me anything about your documents")
                                                .font(.callout)
                                                .foregroundColor(.secondary)
                                        }
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                        .padding(.vertical, 40)
                                    } else {
                                        let _ = print("[CHAT-UI] Rendering \(messages.count) messages")
                                        ForEach(messages) { message in
                                            let _ = print("[CHAT-UI] Rendering message: \(message.id), isUser: \(message.isUser)")
                                            ChatMessageView(message: message)
                                                .id(message.id)
                                        }
                                    }
                                }
                                .padding()
                                .onChange(of: messages.count) { oldCount, newCount in
                                    print("[CHAT-UI] Messages count changed from \(oldCount) to \(newCount)")
                                    // Scroll to the last message when a new one is added
                                    if let lastMessage = messages.last {
                                        withAnimation {
                                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                        }
                                    }
                                }
                            }
                            .frame(height: 300)
                            .background(Color(NSColor.textBackgroundColor).opacity(0.5))
                        }

                        // Resizable Divider
                        ChatInputResizer(height: $inputHeight)

                        // Input area
                        VStack(spacing: 0) {
                            HStack(alignment: .bottom, spacing: 12) {
                                // Add file button
                                Button(action: {
                                    showingFilePicker = true
                                }) {
                                    Image(systemName: "paperclip")
                                        .font(.title3)
                                        .foregroundColor(.accentColor)
                                }
                                .buttonStyle(.plain)
                                .help("Add files or folders")
                                .padding(.bottom, 4)

                                ZStack(alignment: .topLeading) {
                                    // Actual TextEditor
                                    TextEditor(text: $chatInput)
                                        .font(.body)
                                        .scrollContentBackground(.hidden)
                                        .background(Color.clear)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 14)
                                        .focused($isInputFocused)

                                    // Placeholder
                                    if chatInput.isEmpty {
                                        Text("Ask a question...")
                                            .foregroundColor(.secondary)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 14)
                                            .allowsHitTesting(false)
                                    }
                                }
                                .background(Color(NSColor.textBackgroundColor).opacity(0.5))
                                .cornerRadius(8)

                                if isLoading {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                        .frame(width: 24, height: 24)
                                        .padding(.bottom, 4)
                                } else {
                                    Button(action: sendMessage) {
                                        Image(systemName: "arrow.up.circle.fill")
                                            .font(.title2)
                                            .foregroundColor(chatInput.isEmpty ? .secondary : .accentColor)
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(chatInput.isEmpty)
                                    .padding(.bottom, 4)
                                    .keyboardShortcut(.return, modifiers: [.command])
                                }
                            }
                            .padding()
                        }
                        .frame(height: inputHeight)
                        .background(.ultraThinMaterial)
                    }
                    .background(.ultraThinMaterial)
                    .background(
                        Rectangle()
                            .fill(Color(NSColor.windowBackgroundColor).opacity(0.95))
                            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: -5)
                    )
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .bottom).combined(with: .opacity)
                ))
            }
        }
        .onKeyPress(.escape) {
            closeChatPopup()
            return .handled
        }
        .onChange(of: isOpen) { _, newValue in
            if newValue {
                // Create new chat if none exists
                if appState.currentChat == nil {
                    appState.createNewChat()
                }
                // Focus input when opening
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isInputFocused = true
                }
            }
        }
        .sheet(isPresented: $showingFilePicker) {
            ChatFilePickerDialog()
        }
    }

    private func sendMessage() {
        guard !chatInput.isEmpty else { return }

        let userMessage = ChatMessage(content: chatInput, isUser: true)
        appState.addMessageToCurrentChat(userMessage)
        print("[CHAT] User message added: \(chatInput)")
        print("[CHAT] Messages array count after user message: \(messages.count)")

        let query = chatInput
        chatInput = ""
        isLoading = true

        // Clear audit log for new conversation
        auditLog.removeAll()

        // Add current file to related files if not already added
        if let selectedItem = appState.selectedItem, !selectedItem.isFolder {
            let filePath = selectedItem.path.path
            if let currentChat = appState.currentChat, !currentChat.relatedFiles.contains(filePath) {
                appState.addFileToCurrentChat(filePath)
            }
        }

        // Send to Claude with the currently selected document as context
        Task {
            do {
                print("[CHAT] Sending to Claude...")

                // Use streaming to capture tool usage
                let stream = try await appState.claudeService.sendMessageStreamingWithAudit(query, context: appState.selectedItem) { toolUse in
                    // Called on MainActor when a tool is used
                    Task { @MainActor in
                        self.addAuditEntry(toolUse: toolUse)
                    }
                }

                var fullResponse = ""
                for await chunk in stream {
                    fullResponse += chunk
                }

                print("[CHAT] Received response length: \(fullResponse.count) characters")
                print("[CHAT] Response preview: \(fullResponse.prefix(100))...")

                // Create assistant message on MainActor
                await MainActor.run {
                    let assistantMessage = ChatMessage(content: fullResponse, isUser: false)
                    print("[CHAT] [MainActor] Created assistant message with ID: \(assistantMessage.id)")
                    print("[CHAT] [MainActor] Adding assistant message. Current count: \(self.messages.count)")
                    self.appState.addMessageToCurrentChat(assistantMessage)
                    print("[CHAT] [MainActor] After append. Count: \(self.messages.count)")
                    print("[CHAT] [MainActor] Message content preview: \(assistantMessage.content.prefix(100))")
                    self.isLoading = false
                }
            } catch {
                print("[CHAT] Error: \(error.localizedDescription)")
                await MainActor.run {
                    let errorMessage = ChatMessage(content: "Error: \(error.localizedDescription)", isUser: false)
                    self.appState.addMessageToCurrentChat(errorMessage)
                    self.isLoading = false
                }
            }
        }
    }

    private func navigateToFile(_ filePath: String) {
        // Find the document in the file tree
        if let rootFolder = appState.rootFolder {
            if let document = findDocument(at: filePath, in: rootFolder) {
                // Select the document to open it
                appState.selectedItem = document
                appState.openInTab(document)

                // Close the chat popup
                closeChatPopup()
            }
        }
    }

    private func addAuditEntry(toolUse: [String: Any]) {
        guard let tool = toolUse["tool"] as? String else { return }
        let input = toolUse["input"] as? [String: Any] ?? [:]

        var action = ""
        var details: String? = nil

        // Build action description based on tool
        switch tool {
        case "Read":
            if let filePath = input["file_path"] as? String {
                action = "Reading file"
                details = filePath
            }
        case "Write":
            if let filePath = input["file_path"] as? String {
                action = "Writing file"
                details = filePath
            }
        case "Edit":
            if let filePath = input["file_path"] as? String {
                action = "Editing file"
                details = filePath
            }
        case "Glob":
            if let pattern = input["pattern"] as? String {
                action = "Finding files"
                details = "Pattern: \(pattern)"
            }
        case "Grep":
            if let pattern = input["pattern"] as? String {
                action = "Searching content"
                details = "Pattern: \(pattern)"
            }
        case "Bash":
            if let command = input["command"] as? String {
                action = "Running command"
                details = command.prefix(50).description + (command.count > 50 ? "..." : "")
            }
        case "WebFetch":
            if let url = input["url"] as? String {
                action = "Fetching URL"
                details = url
            }
        case "WebSearch":
            if let query = input["query"] as? String {
                action = "Searching web"
                details = query
            }
        default:
            action = "Using tool"
            details = nil
        }

        let entry = AuditLogEntry(
            timestamp: Date(),
            tool: tool,
            action: action,
            details: details
        )

        auditLog.append(entry)
        print("[AUDIT] Added entry: \(tool) - \(action)")
    }

    private func closeChatPopup() {
        withAnimation(.spring(response: 0.2, dampingFraction: 0.9)) {
            isOpen = false
        }
    }

    private func copyAnnotationToChat(_ annotation: Annotation) {
        // Build a formatted annotation message for the chat input
        var annotationText = "For file \(annotation.fileName)"

        if let lineNumber = annotation.lineNumber {
            annotationText += " at line \(lineNumber)"
        }

        annotationText += ":\n\n"
        annotationText += "Selected text: \"\(annotation.selection.selectedText)\"\n\n"
        annotationText += annotation.instruction

        // Copy to chat input
        chatInput = annotationText

        // Focus the input field
        isInputFocused = true
    }

    private func navigateToAnnotation(_ annotation: Annotation) {
        // Find the document in the file tree
        if let rootFolder = appState.rootFolder {
            if let document = findDocument(at: annotation.filePath, in: rootFolder) {
                // Select the document to open it
                appState.selectedItem = document
                appState.openInTab(document)

                // Close the chat popup
                closeChatPopup()

                // TODO: Scroll to the annotation's line number if available
                // This would require posting a notification to the preview view
                if let lineNumber = annotation.lineNumber {
                    print("📍 Navigating to \(annotation.fileName) at line \(lineNumber)")
                }
            }
        }
    }

    private func findDocument(at path: String, in folder: Folder) -> Document? {
        for child in folder.children {
            if let document = child as? Document, document.path.path == path {
                return document
            } else if let subfolder = child as? Folder {
                if let found = findDocument(at: path, in: subfolder) {
                    return found
                }
            }
        }
        return nil
    }
}

// MARK: - Chat Message View

struct ChatMessageView: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if !message.isUser {
                Image(systemName: "sparkles")
                    .foregroundColor(.accentColor)
                    .frame(width: 20)
            }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.body)
                    .foregroundColor(.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: message.isUser ? .trailing : .leading)
                    .padding(8)
                    .background(
                        message.isUser
                            ? Color.accentColor.opacity(0.1)
                            : Color.secondary.opacity(0.1)
                    )
                    .cornerRadius(8)

                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if message.isUser {
                Image(systemName: "person.circle.fill")
                    .foregroundColor(.secondary)
                    .frame(width: 20)
            }
        }
        .padding(.horizontal, message.isUser ? 0 : 8)
        .padding(.vertical, 4)
    }
}

// MARK: - Annotation List Section

struct AnnotationListSection: View {
    let annotations: [Annotation]
    let onSelectAnnotation: (Annotation) -> Void
    let onDeleteAnnotation: (Annotation) -> Void
    let onEditAnnotation: (Annotation) -> Void

    var body: some View {
        if !annotations.isEmpty {
            VStack(spacing: 0) {
                // Section Header
                HStack {
                    Image(systemName: "tag.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text("Pending Annotations")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text("\(annotations.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.05))

                Divider()

                // Annotation List
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(annotations) { annotation in
                            AnnotationRow(
                                annotation: annotation,
                                onSelect: { onSelectAnnotation(annotation) },
                                onEdit: { onEditAnnotation(annotation) },
                                onDelete: { onDeleteAnnotation(annotation) }
                            )

                            if annotation.id != annotations.last?.id {
                                Divider()
                                    .padding(.leading)
                            }
                        }
                    }
                }
                .frame(maxHeight: 200)
                .background(Color(NSColor.textBackgroundColor).opacity(0.3))

                Divider()
            }
        }
    }
}

// MARK: - Annotation Row

struct AnnotationRow: View {
    let annotation: Annotation
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            // Main content - clickable to navigate
            Button(action: onSelect) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(annotation.fileName)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)

                        Spacer()

                        Text(annotation.created, style: .relative)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    Text(annotation.instruction)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let lineNumber = annotation.lineNumber {
                        Text("Line \(lineNumber)")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
            }
            .buttonStyle(.plain)

            // Action buttons (visible on hover)
            if isHovered {
                HStack(spacing: 6) {
                    Button(action: onEdit) {
                        Image(systemName: "arrow.up.message")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                    .help("Copy to chat input")

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                    .help("Delete annotation")
                }
                .padding(.trailing, 4)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(isHovered ? Color.secondary.opacity(0.05) : Color.clear)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Chat Input Resizer

struct ChatInputResizer: View {
    @Binding var height: CGFloat
    @State private var isDragging = false
    @State private var isHovering = false

    var body: some View {
        ZStack {
            // Large invisible hit area for easier grabbing
            Rectangle()
                .fill(Color.clear)
                .frame(height: 20)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            isDragging = true
                            // Drag upward decreases height (negative translation)
                            // Drag downward increases height (positive translation)
                            let newHeight = height - value.translation.height
                            height = min(max(newHeight, 60), 400)
                        }
                        .onEnded { _ in
                            isDragging = false
                        }
                )
                .onHover { hovering in
                    isHovering = hovering
                    if hovering {
                        NSCursor.resizeUpDown.push()
                    } else {
                        NSCursor.pop()
                    }
                }

            // Visual indicator
            RoundedRectangle(cornerRadius: 2)
                .fill(isDragging ? Color.accentColor : (isHovering ? Color.accentColor.opacity(0.5) : Color.secondary.opacity(0.3)))
                .frame(width: 40, height: 4)
        }
    }
}

// MARK: - Audit Log Section

struct AuditLogSection: View {
    let entries: [AuditLogEntry]

    var body: some View {
        if !entries.isEmpty {
            VStack(spacing: 0) {
                // Section Header
                HStack {
                    Image(systemName: "doc.text.magnifyingglass")
                        .foregroundColor(.blue)
                        .font(.caption)
                    Text("Audit Log")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text("\(entries.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.05))

                Divider()

                // Audit Log List
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(entries) { entry in
                            AuditLogRow(entry: entry)

                            if entry.id != entries.last?.id {
                                Divider()
                                    .padding(.leading)
                            }
                        }
                    }
                }
                .frame(maxHeight: 200)
                .background(Color(NSColor.textBackgroundColor).opacity(0.3))

                Divider()
            }
        }
    }
}

// MARK: - Audit Log Row

struct AuditLogRow: View {
    let entry: AuditLogEntry

    var body: some View {
        HStack(spacing: 12) {
            // Tool icon
            Image(systemName: entry.icon)
                .foregroundColor(entry.color)
                .font(.caption)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(entry.tool)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    Spacer()

                    Text(entry.timestamp, style: .relative)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Text(entry.action)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                if let details = entry.details {
                    Text(details)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

// MARK: - Related Files Section

struct RelatedFilesSection: View {
    let files: [String]
    let folders: [String]
    @Binding var isExpanded: Bool
    let onNavigateToFile: (String) -> Void
    let onRemoveFile: (String) -> Void
    let onRemoveFolder: (String) -> Void
    let onAddMore: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Section Header
            HStack {
                Image(systemName: "doc.on.doc.fill")
                    .foregroundColor(.green)
                    .font(.caption)
                Button(action: {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                    }
                }) {
                    HStack(spacing: 4) {
                        Text("Related Files")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .foregroundColor(.secondary)
                            .font(.caption2)
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                Text("\(files.count + folders.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button(action: onAddMore) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help("Add files or folders")
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.green.opacity(0.05))

            if isExpanded {
                Divider()

                // Files and Folders List
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(folders, id: \.self) { folderPath in
                            RelatedItemRow(
                                path: folderPath,
                                isFolder: true,
                                onNavigate: { onNavigateToFile(folderPath) },
                                onRemove: { onRemoveFolder(folderPath) }
                            )

                            Divider()
                                .padding(.leading)
                        }

                        ForEach(files, id: \.self) { filePath in
                            RelatedItemRow(
                                path: filePath,
                                isFolder: false,
                                onNavigate: { onNavigateToFile(filePath) },
                                onRemove: { onRemoveFile(filePath) }
                            )

                            if filePath != files.last {
                                Divider()
                                    .padding(.leading)
                            }
                        }
                    }
                }
                .frame(maxHeight: 150)
                .background(Color(NSColor.textBackgroundColor).opacity(0.3))
            }
        }
    }
}

// MARK: - Related Item Row

struct RelatedItemRow: View {
    let path: String
    let isFolder: Bool
    let onNavigate: () -> Void
    let onRemove: () -> Void
    @State private var isHovered = false

    private var displayName: String {
        URL(fileURLWithPath: path).lastPathComponent
    }

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: isFolder ? "folder.fill" : "doc.fill")
                .foregroundColor(isFolder ? .blue : .secondary)
                .font(.caption)
                .frame(width: 20)

            // Content
            Button(action: onNavigate) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Text(path)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            // Remove button (visible on hover)
            if isHovered {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Remove")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(isHovered ? Color.secondary.opacity(0.05) : Color.clear)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Chat File Picker Dialog

struct ChatFilePickerDialog: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var allItems: [any FileSystemItem] {
        guard let root = appState.rootFolder else { return [] }
        return collectAllItems(from: root)
    }

    private var filteredItems: [any FileSystemItem] {
        if searchText.isEmpty {
            return []
        }
        return allItems.filter { item in
            item.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var selectedFiles: [String] {
        appState.currentChat?.relatedFiles ?? []
    }

    private var selectedFolders: [String] {
        appState.currentChat?.relatedFolders ?? []
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Select Files or Folders")
                    .font(.headline)

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .imageScale(.large)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("Search files and folders...", text: $searchText)
                    .textFieldStyle(.plain)

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Results
            ScrollView {
                if searchText.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)

                        Text("Type to search for files or folders")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(40)
                } else if filteredItems.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)

                        Text("No matches found")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(40)
                } else {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(filteredItems, id: \.id) { item in
                            ChatFilePickerRow(
                                item: item,
                                isSelected: isSelected(item),
                                onToggle: {
                                    toggleSelection(item)
                                }
                            )
                        }
                    }
                    .padding(.vertical, 8)
                }
            }

            Divider()

            // Footer
            HStack {
                Text("\(selectedFiles.count + selectedFolders.count) selected")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 500, height: 400)
    }

    private func collectAllItems(from folder: Folder) -> [any FileSystemItem] {
        var items: [any FileSystemItem] = [folder]

        for child in folder.children {
            if let subfolder = child as? Folder {
                items.append(contentsOf: collectAllItems(from: subfolder))
            } else {
                items.append(child)
            }
        }

        return items
    }

    private func isSelected(_ item: any FileSystemItem) -> Bool {
        let path = item.path.path
        if item.isFolder {
            return selectedFolders.contains(path)
        } else {
            return selectedFiles.contains(path)
        }
    }

    private func toggleSelection(_ item: any FileSystemItem) {
        let path = item.path.path

        if item.isFolder {
            if selectedFolders.contains(path) {
                appState.removeFolderFromCurrentChat(path)
            } else {
                appState.addFolderToCurrentChat(path)
            }
        } else {
            if selectedFiles.contains(path) {
                appState.removeFileFromCurrentChat(path)
            } else {
                appState.addFileToCurrentChat(path)
            }
        }
    }
}

// MARK: - Chat File Picker Row

struct ChatFilePickerRow: View {
    let item: any FileSystemItem
    let isSelected: Bool
    let onToggle: () -> Void

    private var relativePath: String {
        item.path.path
    }

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .imageScale(.large)

                Image(systemName: item.isFolder ? "folder.fill" : "doc.fill")
                    .foregroundColor(item.isFolder ? .blue : .secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.body)
                        .foregroundColor(.primary)

                    Text(relativePath)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
    }
}

// MARK: - Preview

#Preview {
    ChatPopupView(isOpen: .constant(true))
        .environment(AppState())
}
