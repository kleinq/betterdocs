import SwiftUI

struct ClaudeSidebarView: View {
    @Environment(AppState.self) private var appState
    @State private var messageText: String = ""
    @State private var messages: [ChatMessage] = []
    @State private var isProcessing: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Document Outline (at the top)
            if let selectedItem = appState.selectedItem as? Document,
               selectedItem.type == .markdown,
               let content = selectedItem.content {
                DocumentOutlineView(
                    markdownContent: content,
                    isVisible: Binding(
                        get: { appState.isOutlineVisible },
                        set: { _ in appState.toggleOutline() }
                    ),
                    onHeadingClick: { headingId in
                        // Scroll to heading - we'll implement this
                        scrollToHeading(headingId)
                    }
                )
                Divider()
            }

            // Annotation Tags
            AnnotationTagsView()

            // Header
            HStack {
                Image(systemName: "brain")
                    .foregroundColor(.accentColor)
                Text("Claude Assistant")
                    .font(.headline)
                Spacer()

                Menu {
                    Button("Clear conversation") {
                        messages.removeAll()
                    }
                    Button("Export chat") {
                        // TODO: Export functionality
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if messages.isEmpty {
                            EmptyChatView()
                        } else {
                            ForEach(messages) { message in
                                ChatMessageView(message: message)
                            }

                            // Typing indicator when processing
                            if isProcessing {
                                TypingIndicatorView()
                            }
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) { _, _ in
                    if let lastMessage = messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            // Input area
            VStack(spacing: 8) {
                // Context indicator
                if let selectedItem = appState.selectedItem {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.badge.gearshape")
                            .font(.caption)
                            .foregroundColor(.accentColor)

                        Text("Context: \(selectedItem.name)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)

                        Spacer()

                        Button(action: { /* Clear context */ }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(6)
                    .padding(.horizontal)
                }

                // Text input
                HStack(alignment: .bottom, spacing: 8) {
                    TextField("Ask Claude anything...", text: $messageText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                        .lineLimit(1...5)
                        .onSubmit {
                            sendMessage()
                        }

                    Button(action: sendMessage) {
                        Image(systemName: isProcessing ? "stop.circle.fill" : "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundColor(messageText.isEmpty ? .secondary : .accentColor)
                    }
                    .buttonStyle(.plain)
                    .disabled(messageText.isEmpty && !isProcessing)
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 12)
            .background(Color(NSColor.controlBackgroundColor))
        }
        .background(Color(NSColor.textBackgroundColor))
    }

    private func sendMessage() {
        guard !messageText.isEmpty else { return }

        let userMessage = ChatMessage(content: messageText, isUser: true)
        messages.append(userMessage)

        let query = messageText
        messageText = ""
        isProcessing = true

        // Call Claude Agent SDK with streaming
        Task { @MainActor in
            var assistantMessage: ChatMessage?

            do {
                let stream = try await appState.claudeService.sendMessageStreaming(query, context: appState.selectedItem)

                for await chunk in stream {
                    // Create assistant message on first chunk
                    if assistantMessage == nil {
                        assistantMessage = ChatMessage(content: "", isUser: false)
                        messages.append(assistantMessage!)
                    }
                    assistantMessage?.content += chunk
                }

                // If no response was received, show an error
                if assistantMessage == nil || assistantMessage!.content.isEmpty {
                    if assistantMessage == nil {
                        assistantMessage = ChatMessage(content: "No response from Claude", isUser: false)
                        messages.append(assistantMessage!)
                    } else {
                        assistantMessage!.content = "No response from Claude"
                    }
                }
            } catch {
                if assistantMessage == nil {
                    assistantMessage = ChatMessage(content: "Error: \(error.localizedDescription)", isUser: false)
                    messages.append(assistantMessage!)
                } else {
                    assistantMessage!.content = "Error: \(error.localizedDescription)"
                }
            }
            isProcessing = false
        }
    }

    private func scrollToHeading(_ headingId: String) {
        // Post notification to scroll to heading in the preview
        NotificationCenter.default.post(
            name: NSNotification.Name("ScrollToHeading"),
            object: nil,
            userInfo: ["headingId": headingId]
        )
    }
}

struct EmptyChatView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))

            VStack(spacing: 8) {
                Text("Claude Assistant")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text("Ask me about your documents")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                SuggestionChip(text: "Summarize this document")
                SuggestionChip(text: "Find all mentions of...")
                SuggestionChip(text: "Compare these files")
                SuggestionChip(text: "Extract key information")
            }
            .padding(.top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

struct SuggestionChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.accentColor.opacity(0.1))
            .foregroundColor(.accentColor)
            .cornerRadius(12)
    }
}

struct ChatMessageView: View {
    @ObservedObject var message: ChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if !message.isUser {
                Image(systemName: "brain.head.profile")
                    .font(.caption)
                    .foregroundColor(.accentColor)
                    .frame(width: 24, height: 24)
            } else {
                Spacer()
            }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                MarkdownText(content: message.content, isUser: message.isUser)
                    .padding(10)
                    .background(message.isUser ? Color.accentColor : Color(NSColor.controlBackgroundColor))
                    .cornerRadius(12)
                    .contextMenu {
                        Button("Copy") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(message.content, forType: .string)
                        }
                    }

                Text(formatTime(message.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if message.isUser {
                Image(systemName: "person.circle.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 24, height: 24)
            } else {
                Spacer()
            }
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// Markdown Text View using plain text with line breaks preserved
struct MarkdownText: View {
    let content: String
    let isUser: Bool

    var body: some View {
        Text(content)
            .frame(maxWidth: 280, alignment: .leading)
            .textSelection(.enabled)
            .foregroundColor(isUser ? .white : .primary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

class ChatMessage: Identifiable, ObservableObject {
    let id = UUID()
    @Published var content: String
    let isUser: Bool
    let timestamp: Date = Date()

    init(content: String, isUser: Bool) {
        self.content = content
        self.isUser = isUser
    }
}

// Typing Indicator View (like Messages app)
struct TypingIndicatorView: View {
    @State private var scale1: CGFloat = 1.0
    @State private var scale2: CGFloat = 1.0
    @State private var scale3: CGFloat = 1.0

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "brain.head.profile")
                .font(.caption)
                .foregroundColor(.accentColor)
                .frame(width: 24, height: 24)

            HStack(spacing: 4) {
                Circle()
                    .fill(Color.secondary)
                    .frame(width: 8, height: 8)
                    .scaleEffect(scale1)

                Circle()
                    .fill(Color.secondary)
                    .frame(width: 8, height: 8)
                    .scaleEffect(scale2)

                Circle()
                    .fill(Color.secondary)
                    .frame(width: 8, height: 8)
                    .scaleEffect(scale3)
            }
            .padding(10)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)

            Spacer()
        }
        .onAppear {
            // Animate each dot with a delay
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                scale1 = 1.3
            }
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true).delay(0.2)) {
                scale2 = 1.3
            }
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true).delay(0.4)) {
                scale3 = 1.3
            }
        }
    }
}

#Preview {
    ClaudeSidebarView()
        .environment(AppState())
        .frame(width: 350, height: 600)
}
