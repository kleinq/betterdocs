import SwiftUI
import WebKit

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @State private var navigationWidth: CGFloat = UserDefaults.standard.double(forKey: "navigationWidth") == 0 ? 250 : UserDefaults.standard.double(forKey: "navigationWidth")
    @State private var eventMonitor: Any?
    @State private var saveTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            // Main Content Area
            VStack(spacing: 0) {
                // Ribbon Toolbar
                ToolbarView()
                    .frame(height: 50)

                Divider()

                // Main Content Area
                GeometryReader { geometry in
                    HStack(spacing: 0) {
                        // Navigation Sidebar
                        NavigationView()
                            .frame(width: navigationWidth)

                        ResizableDivider(width: $navigationWidth, minWidth: 150, maxWidth: 400, isRightSidebar: false)

                        // Preview Pane (with floating outline overlay)
                        PreviewView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .background(Color(NSColor.windowBackgroundColor))

            // Command Palette
            CommandPaletteView(isOpen: Binding(
                get: { appState.isCommandPaletteOpen },
                set: { appState.isCommandPaletteOpen = $0 }
            ))

            // Chat Popup
            ChatPopupView(isOpen: Binding(
                get: { appState.isChatPopupOpen },
                set: { appState.isChatPopupOpen = $0 }
            ))

            // Chat List Sidebar
            if appState.showChatList {
                ZStack {
                    // Background overlay
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.9)) {
                                appState.showChatList = false
                            }
                        }

                    // Chat list positioned on the right side
                    HStack {
                        Spacer()

                        ChatListView()
                            .transition(.move(edge: .trailing))
                            .shadow(color: .black.opacity(0.3), radius: 10)
                    }
                }
                .zIndex(50)
                .transition(.opacity)
            }

            // Git File List Panel
            if appState.showGitPanel {
                ZStack {
                    // Background overlay
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.9)) {
                                appState.showGitPanel = false
                            }
                        }

                    // Git panel positioned on the right side
                    HStack {
                        Spacer()

                        GitFileListView(isOpen: Binding(
                            get: { appState.showGitPanel },
                            set: { appState.showGitPanel = $0 }
                        ))
                        .transition(.move(edge: .trailing))
                        .shadow(color: .black.opacity(0.3), radius: 10)
                    }
                }
                .zIndex(50)
                .transition(.opacity)
            }

            // Help Screen
            HelpView(isOpen: Binding(
                get: { appState.isHelpOpen },
                set: { appState.isHelpOpen = $0 }
            ))
            .zIndex(100)
        }
        .onChange(of: navigationWidth) { _, newValue in
            // Debounce UserDefaults saves to avoid excessive writes during drag
            saveTask?.cancel()
            saveTask = Task {
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled else { return }
                UserDefaults.standard.set(newValue, forKey: "navigationWidth")
            }
        }
        .onAppear {
            // Set up keyboard event monitor for Cmd+/, Cmd+K, Cmd+F, and Ctrl+O
            eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                // If a WKWebView has focus, let it handle all non-command key events
                if let firstResponder = NSApp.keyWindow?.firstResponder,
                   firstResponder is WKWebView {
                    // Only intercept our specific command shortcuts
                    if !event.modifierFlags.contains(.command) && !event.modifierFlags.contains(.control) {
                        // Let WKWebView handle regular keys (arrows, letters, etc.)
                        return event
                    }
                }

                // Check if Cmd+/ is pressed (without Shift to avoid conflict with Cmd+? for help)
                if event.modifierFlags.contains(.command) && !event.modifierFlags.contains(.shift) && event.charactersIgnoringModifiers == "/" {
                    print("✅ Cmd+/ detected, toggling chat popup")
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.9)) {
                        // Close command palette before opening chat
                        appState.isCommandPaletteOpen = false
                        appState.isChatPopupOpen.toggle()
                    }
                    return nil // Consume the event
                }

                // Check if Cmd+K is pressed
                if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "k" {
                    print("✅ Cmd+K detected, toggling command palette")
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.9)) {
                        // Close chat popup before opening command palette
                        appState.isChatPopupOpen = false
                        appState.isCommandPaletteOpen.toggle()
                    }
                    return nil // Consume the event
                }

                // Cmd+F is reserved for in-document search (to be implemented)
                // For now, we let it pass through to the system default behavior

                // Check if Ctrl+O is pressed (toggle view mode)
                if event.modifierFlags.contains(.control) && event.charactersIgnoringModifiers == "o" {
                    print("✅ Ctrl+O detected, toggling view mode")
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        appState.toggleViewMode()
                    }
                    return nil // Consume the event
                }

                // Check if Cmd+? is pressed (help)
                if event.modifierFlags.contains(.command) && event.modifierFlags.contains(.shift) && event.charactersIgnoringModifiers == "/" {
                    print("✅ Cmd+? detected, opening help")
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.9)) {
                        appState.isHelpOpen = true
                    }
                    return nil // Consume the event
                }

                return event
            }
        }
        .onDisappear {
            // Clean up event monitor
            if let monitor = eventMonitor {
                NSEvent.removeMonitor(monitor)
                eventMonitor = nil
            }
        }
    }

    // Helper to check if user is typing in a text field
    private func isTypingInTextField() -> Bool {
        if let firstResponder = NSApp.keyWindow?.firstResponder {
            return firstResponder is NSText || firstResponder is NSTextView
        }
        return false
    }
}

// MARK: - Resizable Divider

struct ResizableDivider: View {
    @Binding var width: CGFloat
    let minWidth: CGFloat
    let maxWidth: CGFloat
    let isRightSidebar: Bool

    @State private var isDragging = false
    @State private var isHovered = false
    @State private var startWidth: CGFloat = 0
    @State private var tempWidth: CGFloat = 0

    var body: some View {
        Rectangle()
            .fill(isDragging || isHovered ? Color.accentColor : Color.clear)
            .frame(width: 8)
            .contentShape(Rectangle())
            .onHover { hovering in
                isHovered = hovering
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else if !isDragging {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                            startWidth = width
                            tempWidth = width
                            NSCursor.resizeLeftRight.push()
                        }

                        // For right sidebar, dragging left (negative) should increase width
                        // For left sidebar, dragging right (positive) should increase width
                        let delta = isRightSidebar ? -value.translation.width : value.translation.width
                        let newWidth = startWidth + delta
                        let clampedWidth = min(max(newWidth, minWidth), maxWidth)

                        // Only update if change is significant (reduces update frequency)
                        if abs(clampedWidth - tempWidth) > 2 {
                            width = clampedWidth
                            tempWidth = clampedWidth
                        }
                    }
                    .onEnded { value in
                        isDragging = false
                        if !isHovered {
                            NSCursor.pop()
                        }
                        // Final update to ensure exact position
                        let delta = isRightSidebar ? -(value.translation.width) : value.translation.width
                        let newWidth = startWidth + delta
                        width = min(max(newWidth, minWidth), maxWidth)
                    }
            )
    }
}

#Preview {
    ContentView()
        .environment(AppState())
        .frame(width: 1200, height: 800)
}
