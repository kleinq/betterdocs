import SwiftUI

struct HelpView: View {
    @Binding var isOpen: Bool

    var body: some View {
        ZStack {
            // Overlay background
            if isOpen {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        closeHelp()
                    }

                // Help Panel
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Image(systemName: "questionmark.circle.fill")
                            .foregroundColor(.accentColor)
                            .font(.title2)

                        Text("BetterDocs Help")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Spacer()

                        Button(action: { closeHelp() }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding()
                    .background(.ultraThinMaterial)

                    Divider()

                    // Content
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            // Navigation section
                            HelpSection(title: "Navigation", items: [
                                HelpItem(shortcut: "⌘O", description: "Open folder"),
                                HelpItem(shortcut: "⌘R", description: "Reveal current file in folder tree"),
                                HelpItem(shortcut: "Ctrl+O", description: "Toggle between grid and list view"),
                                HelpItem(shortcut: "⌘1-9", description: "Switch to tab 1-9"),
                            ])

                            Divider()

                            // Search section
                            HelpSection(title: "Search & Commands", items: [
                                HelpItem(shortcut: "/", description: "Open command palette"),
                                HelpItem(shortcut: "⌘K", description: "Open command palette"),
                                HelpItem(shortcut: "⌘F", description: "Open command palette (search mode)"),
                                HelpItem(shortcut: "↑↓", description: "Navigate command palette results"),
                                HelpItem(shortcut: "Enter", description: "Select command palette item"),
                                HelpItem(shortcut: "Esc", description: "Close command palette"),
                            ])

                            Divider()

                            // Document viewing section
                            HelpSection(title: "Document Viewing", items: [
                                HelpItem(shortcut: "Space", description: "Scroll down one page"),
                                HelpItem(shortcut: "→", description: "Scroll down one page"),
                                HelpItem(shortcut: "←", description: "Scroll up one page"),
                                HelpItem(shortcut: "↑↓", description: "Scroll incrementally"),
                                HelpItem(shortcut: "⌘⇧L", description: "Toggle document outline"),
                            ])

                            Divider()

                            // Tips section
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Tips")
                                    .font(.headline)
                                    .foregroundColor(.primary)

                                VStack(alignment: .leading, spacing: 8) {
                                    HelpTip(
                                        icon: "magnifyingglass",
                                        text: "The command palette searches through all document content, not just filenames."
                                    )

                                    HelpTip(
                                        icon: "doc.text.magnifyingglass",
                                        text: "Use the document outline to quickly navigate to specific sections in markdown files."
                                    )

                                    HelpTip(
                                        icon: "square.grid.2x2",
                                        text: "Grid view provides a visual preview of your documents. List view shows more details."
                                    )

                                    HelpTip(
                                        icon: "keyboard",
                                        text: "Most keyboard shortcuts work even when typing in the search field."
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding()
                    }
                    .frame(maxHeight: 500)
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
        .onKeyPress(.escape) {
            closeHelp()
            return .handled
        }
    }

    private func closeHelp() {
        withAnimation(.spring(response: 0.2, dampingFraction: 0.9)) {
            isOpen = false
        }
    }
}

// MARK: - Help Section

struct HelpSection: View {
    let title: String
    let items: [HelpItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(items, id: \.description) { item in
                    HStack(spacing: 12) {
                        Text(item.shortcut)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(6)
                            .frame(minWidth: 80, alignment: .center)

                        Text(item.description)
                            .foregroundColor(.primary)

                        Spacer()
                    }
                }
            }
        }
        .padding(.horizontal)
    }
}

struct HelpItem {
    let shortcut: String
    let description: String
}

// MARK: - Help Tip

struct HelpTip: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 20)

            Text(text)
                .font(.callout)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Preview

#Preview {
    HelpView(isOpen: .constant(true))
}
