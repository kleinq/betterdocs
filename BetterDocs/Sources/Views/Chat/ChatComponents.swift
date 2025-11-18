import SwiftUI

// MARK: - Empty Chat View

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

// MARK: - Chat Message View

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

// MARK: - Markdown Text View

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

// MARK: - Chat Message Model

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

// MARK: - Typing Indicator View

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
