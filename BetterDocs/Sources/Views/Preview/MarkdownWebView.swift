import SwiftUI
import WebKit

/// A markdown renderer using WKWebView for better formatting
struct MarkdownWebView: NSViewRepresentable {
    let markdown: String
    let tabID: UUID
    @Environment(\.colorScheme) var colorScheme
    @Environment(AppState.self) private var appState

    func makeNSView(context: Context) -> CustomWebView {
        let config = WKWebViewConfiguration()
        let webView = CustomWebView(frame: .zero, configuration: config, coordinator: context.coordinator)
        webView.setValue(false, forKey: "drawsBackground") // Transparent background
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator

        // Start scroll position tracking
        context.coordinator.startScrollTracking(for: webView)

        // Set initial markdown to prevent reload in updateNSView
        context.coordinator.lastMarkdown = markdown

        // Load initial HTML
        let savedPosition = appState.getTabScrollPosition(tabID)
        let html = generateHTML(from: markdown, scrollPosition: savedPosition)
        webView.loadHTMLString(html, baseURL: nil)

        return webView
    }

    func updateNSView(_ webView: CustomWebView, context: Context) {
        // Update coordinator properties
        if context.coordinator.tabID != tabID {
            context.coordinator.tabID = tabID
        }
        if context.coordinator.appState !== appState {
            context.coordinator.appState = appState
        }

        // ONLY reload HTML if the markdown content has actually changed
        // This prevents unnecessary reloads when app gains focus or SwiftUI redraws
        if context.coordinator.lastMarkdown != markdown {
            context.coordinator.lastMarkdown = markdown

            // Save current scroll position before reload
            context.coordinator.saveCurrentScrollPosition()

            // Get saved scroll position before loading
            let savedPosition = appState.getTabScrollPosition(tabID)
            let html = generateHTML(from: markdown, scrollPosition: savedPosition)
            webView.loadHTMLString(html, baseURL: nil)
        }
        // Otherwise, do nothing - keep the existing content and scroll position
    }

    static func dismantleNSView(_ webView: CustomWebView, coordinator: Coordinator) {
        Task { @MainActor in
            coordinator.cleanup()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(tabID: tabID, appState: appState)
    }

    @MainActor
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler, WKUIDelegate {
        var tabID: UUID
        var appState: AppState?
        var scrollTrackingTimer: Timer?
        weak var webView: WKWebView?
        var notificationObserver: NSObjectProtocol?
        var lastMarkdown: String = ""
        var selectedText: String?
        var selectedRange: (Int, Int)?

        init(tabID: UUID, appState: AppState) {
            self.tabID = tabID
            self.appState = appState
            super.init()

            // Listen for scroll-to-heading notifications
            notificationObserver = NotificationCenter.default.addObserver(
                forName: NSNotification.Name("ScrollToHeading"),
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard let self = self,
                      let headingId = notification.userInfo?["headingId"] as? String,
                      let webView = self.webView else {
                    print("❌ ScrollToHeading: Missing self, headingId, or webView")
                    return
                }

                print("📍 Scrolling to heading: \(headingId)")
                webView.evaluateJavaScript("window.scrollToHeading('\(headingId)');") { result, error in
                    if let error = error {
                        print("❌ Error scrolling to heading: \(error)")
                    } else {
                        print("✅ Successfully scrolled to heading: \(headingId)")
                    }
                }
            }
        }

        func cleanup() {
            scrollTrackingTimer?.invalidate()
            scrollTrackingTimer = nil

            if let observer = notificationObserver {
                NotificationCenter.default.removeObserver(observer)
            }

            // Clean up message handlers
            webView?.configuration.userContentController.removeScriptMessageHandler(forName: "scrollEnded")
            webView?.configuration.userContentController.removeScriptMessageHandler(forName: "textSelected")
        }

        nonisolated func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "scrollEnded", let yOffset = message.body as? Double {
                Task { @MainActor in
                    self.appState?.updateTabScrollPosition(self.tabID, position: CGPoint(x: 0, y: yOffset))
                    print("💾 Scroll ended, saved position: \(yOffset)")
                }
            } else if message.name == "textSelected", let body = message.body as? [String: Any] {
                Task { @MainActor in
                    if let text = body["text"] as? String,
                       let startOffset = body["startOffset"] as? Int,
                       let endOffset = body["endOffset"] as? Int {
                        print("📝 Text selected: \(text.prefix(50))...")
                        self.handleTextSelection(text: text, startOffset: startOffset, endOffset: endOffset)
                    }
                }
            }
        }

        @MainActor
        func handleTextSelection(text: String, startOffset: Int, endOffset: Int) {
            // Store selection info for context menu
            selectedText = text
            selectedRange = (startOffset, endOffset)
            print("✅ Stored selection: \(text.prefix(30))... (\(startOffset)-\(endOffset))")

            // DON'T auto-show dialog - wait for user to click menu item
        }

        func startScrollTracking(for webView: WKWebView) {
            self.webView = webView

            // REMOVED: Aggressive timer-based tracking that causes flickering
            // Instead, we'll save scroll position only on specific events:
            // 1. When tab is being switched away from
            // 2. When app loses focus
            // 3. On scroll end events from JavaScript

            // Save scroll position when app loses focus (Cmd+Tab away)
            NotificationCenter.default.addObserver(
                forName: NSApplication.didResignActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.saveCurrentScrollPosition()
            }

            // Inject JavaScript to detect scroll end and save position
            let scrollEndScript = """
            let scrollTimeout;
            window.addEventListener('scroll', function() {
                clearTimeout(scrollTimeout);
                scrollTimeout = setTimeout(function() {
                    // Scroll has ended, notify Swift
                    window.webkit.messageHandlers.scrollEnded.postMessage(window.pageYOffset);
                }, 150);
            });
            """

            // Inject JavaScript to capture text selection
            let selectionScript = """
            document.addEventListener('contextmenu', function(e) {
                const selection = window.getSelection();
                if (selection && selection.toString().trim().length > 0) {
                    const selectedText = selection.toString();
                    const range = selection.getRangeAt(0);

                    // Get approximate character offset in the document
                    const preSelectionRange = range.cloneRange();
                    preSelectionRange.selectNodeContents(document.body);
                    preSelectionRange.setEnd(range.startContainer, range.startOffset);
                    const startOffset = preSelectionRange.toString().length;
                    const endOffset = startOffset + selectedText.length;

                    // Send selection info to Swift
                    window.webkit.messageHandlers.textSelected.postMessage({
                        text: selectedText,
                        startOffset: startOffset,
                        endOffset: endOffset
                    });
                }
            });
            """

            let scrollScript = WKUserScript(source: scrollEndScript, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
            let selectionScriptObj = WKUserScript(source: selectionScript, injectionTime: .atDocumentEnd, forMainFrameOnly: true)

            webView.configuration.userContentController.addUserScript(scrollScript)
            webView.configuration.userContentController.addUserScript(selectionScriptObj)
            webView.configuration.userContentController.add(self, name: "scrollEnded")
            webView.configuration.userContentController.add(self, name: "textSelected")
        }

        func saveCurrentScrollPosition() {
            guard let webView = self.webView else { return }

            Task { @MainActor in
                do {
                    if let yOffset = try await webView.evaluateJavaScript("window.pageYOffset") as? Double {
                        self.appState?.updateTabScrollPosition(self.tabID, position: CGPoint(x: 0, y: yOffset))
                        print("💾 Saved scroll position: \(yOffset) for tab \(self.tabID)")
                    }
                } catch {
                    print("❌ Error saving scroll position: \(error)")
                }
            }
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void) {
            // Check if this is a user-initiated link click
            if let url = navigationAction.request.url,
               url.scheme != "about" && url.scheme != nil {
                // This is a link click (not initial load)
                if navigationAction.navigationType == .linkActivated {
                    // Open in default browser
                    NSWorkspace.shared.open(url)
                    decisionHandler(.cancel)
                    return
                }
            }

            // Allow the initial HTML load
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Scroll position is now restored in the HTML itself
            // No need for delayed restoration
        }

        @objc func showAnnotationDialogFromMenu() {
            print("🎯 showAnnotationDialogFromMenu called")
            print("   selectedText: \(selectedText?.prefix(30) ?? "nil")")
            print("   selectedRange: \(selectedRange?.0 ?? -1)-\(selectedRange?.1 ?? -1)")

            guard let selectedText = selectedText,
                  let selectedRange = selectedRange else {
                print("❌ Missing selectedText or selectedRange, returning")
                return
            }

            print("📤 Posting ShowAnnotationDialog notification with text: '\(selectedText.prefix(30))...'")

            NotificationCenter.default.post(
                name: NSNotification.Name("ShowAnnotationDialog"),
                object: nil,
                userInfo: [
                    "selectedText": selectedText,
                    "startOffset": selectedRange.0,
                    "endOffset": selectedRange.1
                ]
            )

            print("✅ Notification posted successfully")
        }
    }

    private func generateHTML(from markdown: String, scrollPosition: CGPoint = .zero) -> String {
        let isDark = colorScheme == .dark
        let backgroundColor = isDark ? "#1e1e1e" : "#ffffff"
        let textColor = isDark ? "#ffffff" : "#000000"
        let codeBackground = isDark ? "#2d2d2d" : "#f5f5f5"
        let linkColor = isDark ? "#60a5fa" : "#3b82f6"

        // Escape the markdown for JavaScript
        let escapedMarkdown = markdown
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "$", with: "\\$")

        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <script src="https://cdn.jsdelivr.net/npm/marked/marked.min.js"></script>
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
                    font-size: 14px;
                    line-height: 1.6;
                    color: \(textColor);
                    background-color: \(backgroundColor);
                    padding: 16px;
                    margin: 0;
                    /* Add padding to bottom so last headings can scroll to top */
                    padding-bottom: 80vh;
                }
                h1 {
                    font-size: 28px;
                    font-weight: bold;
                    margin: 24px 0 16px 0;
                    line-height: 1.3;
                }
                h2 {
                    font-size: 24px;
                    font-weight: bold;
                    margin: 20px 0 12px 0;
                    line-height: 1.3;
                }
                h3 {
                    font-size: 20px;
                    font-weight: bold;
                    margin: 16px 0 10px 0;
                    line-height: 1.3;
                }
                p {
                    margin: 0 0 12px 0;
                }
                strong {
                    font-weight: bold;
                }
                em {
                    font-style: italic;
                }
                code {
                    background-color: \(codeBackground);
                    padding: 2px 6px;
                    border-radius: 3px;
                    font-family: "SF Mono", Monaco, Consolas, monospace;
                    font-size: 13px;
                }
                pre {
                    background-color: \(codeBackground);
                    padding: 12px;
                    border-radius: 6px;
                    overflow-x: auto;
                    margin: 12px 0;
                }
                pre code {
                    background-color: transparent;
                    padding: 0;
                }
                ul, ol {
                    margin: 12px 0;
                    padding-left: 24px;
                }
                li {
                    margin: 4px 0;
                }
                blockquote {
                    border-left: 4px solid #007AFF;
                    margin: 12px 0;
                    padding-left: 16px;
                    color: \(isDark ? "#aaaaaa" : "#666666");
                }
                hr {
                    border: none;
                    border-top: 1px solid \(isDark ? "#444444" : "#dddddd");
                    margin: 20px 0;
                }
                a {
                    color: \(linkColor);
                    text-decoration: none;
                }
                a:hover {
                    text-decoration: underline;
                }
                table {
                    border-collapse: collapse;
                    margin: 12px 0;
                }
                th, td {
                    border: 1px solid \(isDark ? "#444444" : "#dddddd");
                    padding: 8px 12px;
                    text-align: left;
                }
                th {
                    background-color: \(isDark ? "#2d2d2d" : "#f5f5f5");
                    font-weight: bold;
                }
            </style>
        </head>
        <body>
            <div id="content"></div>
            <script>
                // Configure marked
                marked.setOptions({
                    breaks: true,
                    gfm: true
                });

                // Parse and render markdown
                const markdown = `\(escapedMarkdown)`;
                document.getElementById('content').innerHTML = marked.parse(markdown);

                // Add IDs to headings for navigation
                let headingIndex = 0;
                document.querySelectorAll('h1, h2, h3, h4, h5, h6').forEach(heading => {
                    heading.id = `heading-${headingIndex}`;
                    headingIndex++;
                });

                // Restore scroll position immediately after render
                const scrollY = \(scrollPosition.y);
                if (scrollY > 0) {
                    // Use requestAnimationFrame to ensure DOM is ready
                    requestAnimationFrame(() => {
                        window.scrollTo(0, scrollY);
                    });
                }

                // Function to scroll to heading
                window.scrollToHeading = function(headingId) {
                    const element = document.getElementById(headingId);
                    if (element) {
                        // Use instant scroll to prevent conflicts with scroll tracking
                        const rect = element.getBoundingClientRect();
                        const scrollTop = window.pageYOffset || document.documentElement.scrollTop;
                        const targetPosition = rect.top + scrollTop - 16;

                        window.scrollTo({
                            top: targetPosition,
                            behavior: 'instant'
                        });

                        console.log('Scrolled to heading:', headingId, 'at position:', targetPosition);
                    } else {
                        console.error('Heading not found:', headingId);
                    }
                };
            </script>
        </body>
        </html>
        """
    }
}

// MARK: - Custom WebView with Context Menu

@MainActor
class CustomWebView: WKWebView {
    weak var coordinator: MarkdownWebView.Coordinator?

    init(frame: CGRect, configuration: WKWebViewConfiguration, coordinator: MarkdownWebView.Coordinator) {
        self.coordinator = coordinator
        super.init(frame: frame, configuration: configuration)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {
        print("🔍 willOpenMenu called with \(menu.items.count) items")

        guard let coordinator = coordinator else {
            super.willOpenMenu(menu, with: event)
            return
        }

        // Synchronously capture text selection from JavaScript
        // This is necessary because the contextmenu event may not have fired yet
        evaluateJavaScript("window.getSelection().toString()") { result, error in
            Task { @MainActor in
                if let selectedText = result as? String, !selectedText.isEmpty {
                    print("✅ Captured selection synchronously: '\(selectedText.prefix(30))...'")

                    // Also get the offsets
                    self.evaluateJavaScript("""
                        (function() {
                            const selection = window.getSelection();
                            if (selection && selection.toString().trim().length > 0) {
                                const range = selection.getRangeAt(0);
                                const preSelectionRange = range.cloneRange();
                                preSelectionRange.selectNodeContents(document.body);
                                preSelectionRange.setEnd(range.startContainer, range.startOffset);
                                const startOffset = preSelectionRange.toString().length;
                                const endOffset = startOffset + selection.toString().length;
                                return { startOffset: startOffset, endOffset: endOffset };
                            }
                            return null;
                        })();
                    """) { offsetResult, offsetError in
                        Task { @MainActor in
                            if let offsetDict = offsetResult as? [String: Int],
                               let startOffset = offsetDict["startOffset"],
                               let endOffset = offsetDict["endOffset"] {
                                coordinator.selectedText = selectedText
                                coordinator.selectedRange = (startOffset, endOffset)
                                print("✅ Stored offsets: \(startOffset)-\(endOffset)")
                            }
                        }
                    }
                } else {
                    print("⚠️ No text selected")
                }
            }
        }

        // Check if we have selected text (from previous selection or async capture)
        if let selectedText = coordinator.selectedText, !selectedText.isEmpty {
            print("✅ Adding annotation item for: '\(selectedText.prefix(30))...'")

            // Create single annotation menu item
            let annotateItem = NSMenuItem(
                title: "Add Annotation...",
                action: #selector(coordinator.showAnnotationDialogFromMenu),
                keyEquivalent: ""
            )
            annotateItem.target = coordinator
            annotateItem.image = NSImage(systemSymbolName: "wand.and.stars", accessibilityDescription: nil)

            // Insert at the beginning of the menu
            menu.insertItem(NSMenuItem.separator(), at: 0)
            menu.insertItem(annotateItem, at: 0)

            print("📋 Added annotation menu item")
        } else {
            print("⚠️ No selected text stored yet")
        }

        super.willOpenMenu(menu, with: event)
    }
}

