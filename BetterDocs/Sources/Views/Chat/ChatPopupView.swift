import SwiftUI

struct ChatPopupView: View {
    @Binding var isOpen: Bool
    @Environment(AppState.self) private var appState
    @State private var chatInput: String = ""
    @State private var messages: [ChatMessage] = []
    @State private var isLoading: Bool = false
    @FocusState private var isInputFocused: Bool
    @State private var isAnnotationsExpanded: Bool = false
    @State private var isAuditLogExpanded: Bool = false
    @State private var auditLog: [AuditLogEntry] = []
    @State private var inputHeight: CGFloat = 80

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
                        // Header with annotation queue
                        HStack(spacing: 16) {
                            HStack(spacing: 8) {
                                Image(systemName: "bubble.left.and.bubble.right.fill")
                                    .foregroundColor(.accentColor)

                                Text("Chat")
                                    .font(.headline)
                            }

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
                // Focus input when opening
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isInputFocused = true
                }
            }
        }
    }

    private func sendMessage() {
        guard !chatInput.isEmpty else { return }

        let userMessage = ChatMessage(content: chatInput, isUser: true)
        messages.append(userMessage)
        print("[CHAT] User message added: \(chatInput)")
        print("[CHAT] Messages array count after user message: \(messages.count)")

        let query = chatInput
        chatInput = ""
        isLoading = true

        // Clear audit log for new conversation
        auditLog.removeAll()

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
                    self.messages.append(assistantMessage)
                    print("[CHAT] [MainActor] After append. Count: \(self.messages.count)")
                    print("[CHAT] [MainActor] Message content preview: \(assistantMessage.content.prefix(100))")
                    self.isLoading = false
                }
            } catch {
                print("[CHAT] Error: \(error.localizedDescription)")
                await MainActor.run {
                    let errorMessage = ChatMessage(content: "Error: \(error.localizedDescription)", isUser: false)
                    self.messages.append(errorMessage)
                    self.isLoading = false
                }
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

// MARK: - Chat Message Model

struct ChatMessage: Identifiable {
    let id = UUID()
    let content: String
    let isUser: Bool
    let timestamp = Date()
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

// MARK: - Audit Log Models

struct AuditLogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let tool: String
    let action: String
    let details: String?

    var icon: String {
        switch tool.lowercased() {
        case "read": return "doc.text"
        case "write", "edit": return "pencil"
        case "glob", "grep": return "magnifyingglass"
        case "bash": return "terminal"
        case "webfetch", "websearch": return "globe"
        default: return "wrench.and.screwdriver"
        }
    }

    var color: Color {
        switch tool.lowercased() {
        case "read": return .blue
        case "write", "edit": return .green
        case "glob", "grep": return .purple
        case "bash": return .orange
        case "webfetch", "websearch": return .cyan
        default: return .gray
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

// MARK: - Preview

#Preview {
    ChatPopupView(isOpen: .constant(true))
        .environment(AppState())
}
