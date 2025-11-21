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

        // Make the webView accept first responder status for keyboard events
        DispatchQueue.main.async {
            webView.window?.makeFirstResponder(webView)
        }

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
        var scrollPageObserver: NSObjectProtocol?
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

            // Listen for space bar page-down scroll
            scrollPageObserver = NotificationCenter.default.addObserver(
                forName: NSNotification.Name("ScrollPreviewPageDown"),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                guard let self = self, let webView = self.webView else { return }

                // Scroll down one page (viewport height)
                webView.evaluateJavaScript("""
                    window.scrollBy({
                        top: window.innerHeight * 0.9,
                        behavior: 'smooth'
                    });
                """)
            }
        }

        func cleanup() {
            scrollTrackingTimer?.invalidate()
            scrollTrackingTimer = nil

            if let observer = notificationObserver {
                NotificationCenter.default.removeObserver(observer)
            }

            if let observer = scrollPageObserver {
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
                    width: 100%;
                }
                th, td {
                    border: 1px solid \(isDark ? "#555555" : "#dddddd");
                    padding: 10px 14px;
                    text-align: left;
                    vertical-align: top;
                }
                th {
                    background-color: \(isDark ? "#333333" : "#f5f5f5");
                    font-weight: bold;
                    color: \(isDark ? "#e0e0e0" : "#000000");
                }
                tr:hover {
                    background-color: \(isDark ? "#2a2a2a" : "#f9f9f9");
                }
            </style>
        </head>
        <body>
            <div id="content"></div>
            <script>
                // Configure marked with proper options
                marked.setOptions({
                    breaks: true,
                    gfm: true,
                    headerIds: true,
                    mangle: false
                });

                // Parse and render markdown
                const markdown = `\(escapedMarkdown)`;
                const parsed = marked.parse(markdown);
                document.getElementById('content').innerHTML = parsed;

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

    // Accept first responder to receive keyboard events
    override var acceptsFirstResponder: Bool {
        return true
    }

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        // Become first responder when clicked
        self.window?.makeFirstResponder(self)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // Handle Cmd+F for find
        if event.modifierFlags.contains(.command) {
            let key = event.charactersIgnoringModifiers ?? ""
            if key == "f" {
                print("🔍 Cmd+F pressed - showing find interface")
                showFindInterface()
                return true
            } else if key == "g" {
                // Cmd+G for find next
                print("🔍 Cmd+G pressed - find next")
                findNext()
                return true
            } else if key == "G" && event.modifierFlags.contains(.shift) {
                // Cmd+Shift+G for find previous
                print("🔍 Cmd+Shift+G pressed - find previous")
                findPrevious()
                return true
            }
        }
        // Let other key events pass through to web content
        return false
    }

    private func showFindInterface() {
        evaluateJavaScript("""
            if (!window.findOverlay) {
                // Create find overlay
                const overlay = document.createElement('div');
                overlay.id = 'findOverlay';
                overlay.style.cssText = `
                    position: fixed;
                    top: 10px;
                    right: 10px;
                    background: rgba(30, 30, 30, 0.95);
                    border: 1px solid #555;
                    border-radius: 6px;
                    padding: 8px 12px;
                    display: flex;
                    align-items: center;
                    gap: 8px;
                    z-index: 10000;
                    box-shadow: 0 4px 12px rgba(0,0,0,0.3);
                `;

                const input = document.createElement('input');
                input.type = 'text';
                input.placeholder = 'Find in page...';
                input.style.cssText = `
                    background: #1e1e1e;
                    border: 1px solid #555;
                    color: white;
                    padding: 4px 8px;
                    border-radius: 4px;
                    outline: none;
                    width: 200px;
                `;

                const countSpan = document.createElement('span');
                countSpan.style.cssText = 'color: #aaa; font-size: 12px; min-width: 50px;';

                const prevBtn = document.createElement('button');
                prevBtn.textContent = '▲';
                prevBtn.style.cssText = `
                    background: #333;
                    border: 1px solid #555;
                    color: white;
                    padding: 4px 8px;
                    border-radius: 4px;
                    cursor: pointer;
                `;

                const nextBtn = document.createElement('button');
                nextBtn.textContent = '▼';
                nextBtn.style.cssText = prevBtn.style.cssText;

                const closeBtn = document.createElement('button');
                closeBtn.textContent = '✕';
                closeBtn.style.cssText = prevBtn.style.cssText;

                overlay.appendChild(input);
                overlay.appendChild(countSpan);
                overlay.appendChild(prevBtn);
                overlay.appendChild(nextBtn);
                overlay.appendChild(closeBtn);
                document.body.appendChild(overlay);

                window.findOverlay = overlay;
                window.findInput = input;
                window.findCount = countSpan;
                window.currentMatches = [];
                window.currentMatchIndex = -1;

                function highlightMatches(text) {
                    // Remove previous highlights
                    document.querySelectorAll('.find-highlight').forEach(el => {
                        const parent = el.parentNode;
                        parent.replaceChild(document.createTextNode(el.textContent), el);
                        parent.normalize();
                    });

                    window.currentMatches = [];
                    window.currentMatchIndex = -1;

                    if (!text) {
                        countSpan.textContent = '';
                        return;
                    }

                    const walker = document.createTreeWalker(
                        document.getElementById('content'),
                        NodeFilter.SHOW_TEXT,
                        null
                    );

                    const textNodes = [];
                    let node;
                    while (node = walker.nextNode()) {
                        textNodes.push(node);
                    }

                    const searchText = text.toLowerCase();
                    textNodes.forEach(node => {
                        const nodeText = node.textContent;
                        const nodeLower = nodeText.toLowerCase();
                        let lastIndex = 0;
                        let index = nodeLower.indexOf(searchText, lastIndex);

                        if (index === -1) return;

                        const fragment = document.createDocumentFragment();
                        while (index !== -1) {
                            if (index > lastIndex) {
                                fragment.appendChild(document.createTextNode(nodeText.substring(lastIndex, index)));
                            }

                            const highlight = document.createElement('span');
                            highlight.className = 'find-highlight';
                            highlight.style.cssText = 'background-color: yellow; color: black;';
                            highlight.textContent = nodeText.substring(index, index + text.length);
                            fragment.appendChild(highlight);
                            window.currentMatches.push(highlight);

                            lastIndex = index + text.length;
                            index = nodeLower.indexOf(searchText, lastIndex);
                        }

                        if (lastIndex < nodeText.length) {
                            fragment.appendChild(document.createTextNode(nodeText.substring(lastIndex)));
                        }

                        node.parentNode.replaceChild(fragment, node);
                    });

                    if (window.currentMatches.length > 0) {
                        window.currentMatchIndex = 0;
                        selectMatch(0);
                    }

                    countSpan.textContent = window.currentMatches.length > 0
                        ? `1 of ${window.currentMatches.length}`
                        : 'No matches';
                }

                function selectMatch(index) {
                    if (window.currentMatches.length === 0) return;

                    // Remove current selection highlight
                    window.currentMatches.forEach(el => {
                        el.style.backgroundColor = 'yellow';
                    });

                    // Highlight current match
                    const match = window.currentMatches[index];
                    match.style.backgroundColor = 'orange';
                    match.scrollIntoView({ behavior: 'smooth', block: 'center' });

                    countSpan.textContent = `${index + 1} of ${window.currentMatches.length}`;
                }

                input.addEventListener('input', (e) => {
                    highlightMatches(e.target.value);
                });

                input.addEventListener('keydown', (e) => {
                    if (e.key === 'Enter') {
                        e.preventDefault();
                        if (e.shiftKey) {
                            prevBtn.click();
                        } else {
                            nextBtn.click();
                        }
                    } else if (e.key === 'Escape') {
                        closeBtn.click();
                    }
                });

                prevBtn.addEventListener('click', () => {
                    if (window.currentMatches.length === 0) return;
                    window.currentMatchIndex = (window.currentMatchIndex - 1 + window.currentMatches.length) % window.currentMatches.length;
                    selectMatch(window.currentMatchIndex);
                });

                nextBtn.addEventListener('click', () => {
                    if (window.currentMatches.length === 0) return;
                    window.currentMatchIndex = (window.currentMatchIndex + 1) % window.currentMatches.length;
                    selectMatch(window.currentMatchIndex);
                });

                closeBtn.addEventListener('click', () => {
                    document.querySelectorAll('.find-highlight').forEach(el => {
                        const parent = el.parentNode;
                        parent.replaceChild(document.createTextNode(el.textContent), el);
                        parent.normalize();
                    });
                    overlay.remove();
                    window.findOverlay = null;
                    window.currentMatches = [];
                });

                window.findNext = function() {
                    if (window.currentMatches.length === 0) return;
                    window.currentMatchIndex = (window.currentMatchIndex + 1) % window.currentMatches.length;
                    selectMatch(window.currentMatchIndex);
                };

                window.findPrevious = function() {
                    if (window.currentMatches.length === 0) return;
                    window.currentMatchIndex = (window.currentMatchIndex - 1 + window.currentMatches.length) % window.currentMatches.length;
                    selectMatch(window.currentMatchIndex);
                };
            }

            window.findOverlay.style.display = 'flex';
            window.findInput.focus();
            window.findInput.select();
        """)
    }

    private func findNext() {
        evaluateJavaScript("if (window.findNext) window.findNext();")
    }

    private func findPrevious() {
        evaluateJavaScript("if (window.findPrevious) window.findPrevious();")
    }

    override func keyDown(with event: NSEvent) {
        // Handle keyboard navigation for page-by-page reading
        let key = event.charactersIgnoringModifiers ?? ""
        let keyCode = event.keyCode

        print("🔑 WebView keyDown - keyCode: \(keyCode), char: '\(key)'")

        // Key codes reference:
        // Space: 49, Left: 123, Right: 124, Down: 125, Up: 126

        // Space key or Right Arrow: Scroll down one page
        if key == " " || keyCode == 49 || keyCode == 124 {
            print("📄 Space/Right Arrow - scrolling down")
            scrollByPage(direction: .down)
            return
        }

        // Left Arrow: Scroll up one page (for symmetry with Right Arrow)
        if keyCode == 123 {
            print("📄 Left Arrow - scrolling up")
            scrollByPage(direction: .up)
            return
        }

        // Down Arrow (125) and Up Arrow (126) fall through to default behavior
        // for incremental scrolling - this is intentional
        super.keyDown(with: event)
    }

    private func scrollByPage(direction: ScrollDirection) {
        // Get the viewport height and scroll by approximately one page
        evaluateJavaScript("""
            (function() {
                const viewportHeight = window.innerHeight;
                const currentScroll = window.pageYOffset;
                const documentHeight = document.documentElement.scrollHeight;

                // Calculate target scroll position
                // Leave a small overlap (10% of viewport) for reading continuity
                const scrollAmount = viewportHeight * 0.9;
                let targetScroll;

                if ('\(direction.rawValue)' === 'down') {
                    targetScroll = Math.min(currentScroll + scrollAmount, documentHeight - viewportHeight);
                } else {
                    targetScroll = Math.max(currentScroll - scrollAmount, 0);
                }

                // Smooth scroll to target
                window.scrollTo({
                    top: targetScroll,
                    behavior: 'smooth'
                });

                return targetScroll;
            })();
        """) { result, error in
            if let error = error {
                print("❌ Error scrolling by page: \(error)")
            } else if let targetScroll = result as? Double {
                print("📄 Scrolled \(direction.rawValue) to position: \(targetScroll)")
            }
        }
    }

    enum ScrollDirection: String {
        case up = "up"
        case down = "down"
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

