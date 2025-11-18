import SwiftUI

struct FloatingChatDrawer: View {
    @Environment(AppState.self) private var appState
    @Binding var isOpen: Bool
    @State private var messageText: String = ""
    @State private var messages: [ChatMessage] = []
    @State private var isProcessing: Bool = false
    @State private var drawerHeight: CGFloat = 500
    @State private var isDragging: Bool = false

    private let minHeight: CGFloat = 300
    private let maxHeight: CGFloat = 800

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Resize handle
                ResizeHandle(isDragging: $isDragging)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                isDragging = true
                                let newHeight = drawerHeight - value.translation.height
                                drawerHeight = min(max(newHeight, minHeight), min(maxHeight, geometry.size.height - 100))
                            }
                            .onEnded { _ in
                                isDragging = false
                            }
                    )

                // Header
                HStack {
                    Image(systemName: "brain")
                        .foregroundColor(.accentColor)
                    Text("Chat with Claude")
                        .font(.headline)

                    Spacer()

                    // Minimize button
                    Button(action: { withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { isOpen = false } }) {
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)

                    // Close button
                    Button(action: { withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { isOpen = false } }) {
                        Image(systemName: "xmark")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding()
                .background(.ultraThinMaterial)

                Divider()

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
                    .padding(.top, 8)
                }

                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            if messages.isEmpty {
                                EmptyChatView()
                                    .frame(height: drawerHeight - 200)
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
                .padding()
                .background(.ultraThinMaterial)
            }
            .frame(height: drawerHeight)
            .background(.ultraThinMaterial)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(NSColor.textBackgroundColor).opacity(0.95))
                    .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: -5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .offset(y: isOpen ? geometry.size.height - drawerHeight : geometry.size.height)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isOpen)
        }
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
}

// Resize handle for the top of the drawer
struct ResizeHandle: View {
    @Binding var isDragging: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Drag indicator
            RoundedRectangle(cornerRadius: 2.5)
                .fill(isDragging ? Color.accentColor : Color.secondary.opacity(0.3))
                .frame(width: 40, height: 5)
                .padding(.vertical, 8)
        }
        .frame(height: 20)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .contentShape(Rectangle())
        .cursor(.resizeUpDown)
    }
}

// Extension to change cursor on hover
extension View {
    func cursor(_ cursor: NSCursor) -> some View {
        self.onContinuousHover { phase in
            switch phase {
            case .active:
                cursor.push()
            case .ended:
                NSCursor.pop()
            }
        }
    }
}

#Preview {
    FloatingChatDrawer(isOpen: .constant(true))
        .environment(AppState())
        .frame(width: 800, height: 600)
}
