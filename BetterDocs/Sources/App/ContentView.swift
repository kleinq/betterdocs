import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @State private var navigationWidth: CGFloat = UserDefaults.standard.double(forKey: "navigationWidth") == 0 ? 250 : UserDefaults.standard.double(forKey: "navigationWidth")
    @State private var sidebarWidth: CGFloat = UserDefaults.standard.double(forKey: "sidebarWidth") == 0 ? 350 : UserDefaults.standard.double(forKey: "sidebarWidth")

    var body: some View {
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

                    // Claude Sidebar
                    ClaudeSidebarView()
                        .frame(width: sidebarWidth)
                }
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
        .onChange(of: navigationWidth) { _, newValue in
            UserDefaults.standard.set(newValue, forKey: "navigationWidth")
        }
        .onChange(of: sidebarWidth) { _, newValue in
            UserDefaults.standard.set(newValue, forKey: "sidebarWidth")
        }
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
