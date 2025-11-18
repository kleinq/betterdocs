import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @State private var navigationWidth: CGFloat = UserDefaults.standard.double(forKey: "navigationWidth") == 0 ? 250 : UserDefaults.standard.double(forKey: "navigationWidth")
    @State private var sidebarWidth: CGFloat = UserDefaults.standard.double(forKey: "sidebarWidth") == 0 ? 350 : UserDefaults.standard.double(forKey: "sidebarWidth")

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

                        // Preview Pane
                        PreviewView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                        ResizableDivider(width: $sidebarWidth, minWidth: 250, maxWidth: 600, isRightSidebar: true)

                        // Claude Sidebar (outline and annotations only now)
                        ClaudeSidebarView()
                            .frame(width: sidebarWidth)
                    }
                }
            }
            .background(Color(NSColor.windowBackgroundColor))

            // Floating Chat Drawer
            FloatingChatDrawer(isOpen: Binding(
                get: { appState.isChatOpen },
                set: { appState.isChatOpen = $0 }
            ))
        }
        .onChange(of: navigationWidth) { _, newValue in
            UserDefaults.standard.set(newValue, forKey: "navigationWidth")
        }
        .onChange(of: sidebarWidth) { _, newValue in
            UserDefaults.standard.set(newValue, forKey: "sidebarWidth")
        }
        .onAppear {
            // Set up keyboard event monitor for "/" key
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                // Check if "/" key is pressed (and not in a text field)
                if event.characters == "/" && !isTypingInTextField() {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        appState.isChatOpen.toggle()
                    }
                    return nil // Consume the event
                }
                return event
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
                DragGesture()
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                            startWidth = width
                            NSCursor.resizeLeftRight.push()
                        }

                        // For right sidebar, dragging left (negative) should increase width
                        // For left sidebar, dragging right (positive) should increase width
                        let delta = isRightSidebar ? -value.translation.width : value.translation.width
                        let newWidth = startWidth + delta
                        width = min(max(newWidth, minWidth), maxWidth)
                    }
                    .onEnded { _ in
                        isDragging = false
                        if !isHovered {
                            NSCursor.pop()
                        }
                    }
            )
    }
}

#Preview {
    ContentView()
        .environment(AppState())
        .frame(width: 1200, height: 800)
}
