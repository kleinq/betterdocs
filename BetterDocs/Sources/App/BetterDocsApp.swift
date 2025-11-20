import SwiftUI
import AppKit

@main
struct BetterDocsApp: App {
    @State private var appState = AppState()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        logInfo("✅ BetterDocs app initializing...")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .frame(minWidth: 600, minHeight: 400)
                .onAppear {
                    logInfo("✅ Window appeared!")
                    // Wire appState to the delegate
                    appDelegate.appState = appState
                }
        }
        .windowStyle(.automatic)
        .windowResizability(.contentSize)
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Folder...") {
                    appState.openFolder()
                }
                .keyboardShortcut("o", modifiers: .command)
            }

            CommandGroup(after: .windowArrangement) {
                Button("Close Tab") {
                    if let activeTabID = appState.activeTabID,
                       appState.openTabs.contains(where: { $0.id == activeTabID }) {
                        appState.closeTab(activeTabID)
                    }
                }
                // Don't add keyboard shortcut here - handled by NSEvent monitor
                .disabled(appState.activeTabID == nil ||
                         !appState.openTabs.contains(where: { $0.id == appState.activeTabID }))

                Divider()

                Button("Next Tab") {
                    appState.selectNextTab()
                }
                .keyboardShortcut("]", modifiers: [.command, .shift])
                .disabled(appState.openTabs.count <= 1)

                Button("Previous Tab") {
                    appState.selectPreviousTab()
                }
                .keyboardShortcut("[", modifiers: [.command, .shift])
                .disabled(appState.openTabs.count <= 1)
            }

            CommandGroup(before: .sidebar) {
                Button("Find...") {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("FocusSearch"),
                        object: nil
                    )
                }
                .keyboardShortcut("f", modifiers: .command)

                Divider()

                Button(appState.isOutlineVisible ? "Hide Document Outline" : "Show Document Outline") {
                    appState.toggleOutline()
                }
                .keyboardShortcut("l", modifiers: [.command, .shift])

                Button("Reveal in Files") {
                    if let selectedItem = appState.selectedItem {
                        // The reveal functionality will be handled by posting a notification
                        NotificationCenter.default.post(
                            name: NSNotification.Name("RevealInTree"),
                            object: selectedItem.id
                        )
                    }
                }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(appState.selectedItem == nil)
            }

            CommandGroup(replacing: .help) {
                Button("BetterDocs Help") {
                    // TODO: Show help
                }
            }
        }

        Settings {
            SettingsView()
                .environment(appState)
        }
    }
}

// MARK: - AppDelegate

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    @MainActor var appState: AppState?
    weak var mainWindow: NSWindow?

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    // Handle Cmd+W to close tabs instead of windows
    func applicationDidFinishLaunching(_ notification: Notification) {
        // App icon is automatically loaded from Assets.xcassets/AppIcon.appiconset

        // Set ourselves as the window delegate
        if let window = NSApplication.shared.windows.first {
            mainWindow = window
            window.delegate = self
        }

        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // Check for Cmd+W
            if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "w" {
                Task { @MainActor in
                    // Check if we have an active tab
                    if let appState = self?.appState,
                       let activeTabID = appState.activeTabID,
                       appState.openTabs.contains(where: { $0.id == activeTabID }) {
                        // Close the tab instead of the window
                        appState.closeTab(activeTabID)
                    } else {
                        // No tabs, close the window
                        self?.mainWindow?.close()
                    }
                }
                return nil // Always consume Cmd+W
            }
            return event // Let other events through
        }
    }
}
