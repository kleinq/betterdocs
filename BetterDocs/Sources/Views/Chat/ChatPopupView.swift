import SwiftUI

struct ChatPopupView: View {
    @Binding var isOpen: Bool
    @Environment(AppState.self) private var appState
    @State private var chatInput: String = ""
    @State private var messages: [ChatMessage] = []
    @State private var isLoading: Bool = false
    @FocusState private var isInputFocused: Bool

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

                            // Annotation queue indicator
                            let pendingAnnotations = appState.annotations.filter { $0.status == .pending }
                            if !pendingAnnotations.isEmpty {
                                HStack(spacing: 6) {
                                    Image(systemName: "tag.fill")
                                        .foregroundColor(.orange)
                                        .font(.caption)
                                    Text("\(pendingAnnotations.count) pending")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(4)
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

                        // Messages area
                        ScrollView {
                            VStack(alignment: .leading, spacing: 12) {
                                if messages.isEmpty {
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
                                    ForEach(messages) { message in
                                        ChatMessageView(message: message)
                                    }
                                }
                            }
                            .padding()
                        }
                        .frame(height: 300)
                        .background(Color(NSColor.textBackgroundColor).opacity(0.5))

                        Divider()

                        // Annotation List (if there are pending annotations)
                        AnnotationListSection(
                            annotations: appState.annotations.filter { $0.status == .pending },
                            onSelectAnnotation: navigateToAnnotation
                        )

                        // Input area
                        HStack(spacing: 12) {
                            TextField("Ask a question...", text: $chatInput)
                                .textFieldStyle(.plain)
                                .focused($isInputFocused)
                                .onSubmit {
                                    sendMessage()
                                }

                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .frame(width: 24, height: 24)
                            } else {
                                Button(action: sendMessage) {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(chatInput.isEmpty ? .secondary : .accentColor)
                                }
                                .buttonStyle(.plain)
                                .disabled(chatInput.isEmpty)
                            }
                        }
                        .padding()
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

        let query = chatInput
        chatInput = ""
        isLoading = true

        // Send to Claude
        Task {
            do {
                let response = try await appState.claudeService.sendMessage(query, context: nil)
                let assistantMessage = ChatMessage(content: response, isUser: false)
                await MainActor.run {
                    messages.append(assistantMessage)
                    isLoading = false
                }
            } catch {
                let errorMessage = ChatMessage(content: "Error: \(error.localizedDescription)", isUser: false)
                await MainActor.run {
                    messages.append(errorMessage)
                    isLoading = false
                }
            }
        }
    }

    private func closeChatPopup() {
        withAnimation(.spring(response: 0.2, dampingFraction: 0.9)) {
            isOpen = false
        }
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
    }
}

// MARK: - Annotation List Section

struct AnnotationListSection: View {
    let annotations: [Annotation]
    let onSelectAnnotation: (Annotation) -> Void

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
                            Button(action: {
                                onSelectAnnotation(annotation)
                            }) {
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
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(.plain)
                            .background(Color.clear)
                            .contentShape(Rectangle())

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

// MARK: - Preview

#Preview {
    ChatPopupView(isOpen: .constant(true))
        .environment(AppState())
}
