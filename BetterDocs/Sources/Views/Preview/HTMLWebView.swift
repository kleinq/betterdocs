import SwiftUI
import WebKit

// Custom WKWebView that accepts first responder for keyboard events
class FocusableWKWebView: WKWebView {
    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        // Become first responder when clicked
        self.window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        let key = event.charactersIgnoringModifiers ?? ""
        let keyCode = event.keyCode

        // For remark.js presentations, directly call the slideshow API
        let script: String
        switch keyCode {
        case 124, 125, 49, 38: // Right arrow, Down arrow, Space, j
            script = "if (window.slideshow) { slideshow.gotoNextSlide(); }"
        case 123, 126, 40: // Left arrow, Up arrow, k
            script = "if (window.slideshow) { slideshow.gotoPreviousSlide(); }"
        case 35: // p - presenter mode
            script = "if (window.slideshow) { slideshow.togglePresenterMode(); }"
        case 4: // h - help
            script = "if (window.slideshow) { slideshow.toggleHelp(); }"
        case 3: // f - fullscreen (not f key, but close)
            script = "if (window.slideshow) { slideshow.toggleFullscreen(); }"
        default:
            // For other keys, try to create a keyboard event
            script = """
            var event = new KeyboardEvent('keydown', {
                key: '\(key)',
                keyCode: \(keyCode),
                which: \(keyCode),
                bubbles: true,
                cancelable: true
            });
            document.dispatchEvent(event);
            """
        }

        evaluateJavaScript(script, completionHandler: nil)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // Let all key events pass through to web content
        // Don't intercept them at the AppKit level
        return false
    }
}

struct HTMLWebView: View {
    let document: Document
    @Binding var scrollPosition: CGPoint

    var body: some View {
        HTMLWebViewRepresentable(
            document: document,
            scrollPosition: $scrollPosition
        )
    }
}

struct HTMLWebViewRepresentable: NSViewRepresentable {
    let document: Document
    @Binding var scrollPosition: CGPoint

    func makeNSView(context: Context) -> FocusableWKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")

        // Enable JavaScript for interactive HTML content
        let preferences = WKPreferences()
        preferences.javaScriptEnabled = true
        config.preferences = preferences

        // Set up user script to help with keyboard event handling
        let keyboardScript = WKUserScript(
            source: """
            // Install a global keyboard event forwarder
            window.__nativeKeyHandler = function(key, keyCode, type) {
                const event = new KeyboardEvent(type, {
                    key: key,
                    keyCode: keyCode,
                    which: keyCode,
                    bubbles: true,
                    cancelable: true,
                    view: window
                });
                document.dispatchEvent(event);
            };
            """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(keyboardScript)

        let webView = FocusableWKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true

        // Store reference in coordinator
        context.coordinator.webView = webView

        return webView
    }

    func updateNSView(_ webView: FocusableWKWebView, context: Context) {
        // Check if we need to load new content
        if context.coordinator.currentURL != document.path {
            context.coordinator.currentURL = document.path
            loadHTML(in: webView)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    static func dismantleNSView(_ nsView: FocusableWKWebView, coordinator: Coordinator) {
        coordinator.cleanup()
    }

    private func loadHTML(in webView: WKWebView) {
        // Load the HTML file from disk
        webView.loadFileURL(document.path, allowingReadAccessTo: document.path.deletingLastPathComponent())
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: HTMLWebViewRepresentable
        var currentURL: URL?
        var scrollPageObserver: NSObjectProtocol?
        weak var webView: WKWebView?

        init(_ parent: HTMLWebViewRepresentable) {
            self.parent = parent
            super.init()

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
            if let observer = scrollPageObserver {
                NotificationCenter.default.removeObserver(observer)
                scrollPageObserver = nil
            }
        }

        // Handle navigation - open external links in default browser
        @MainActor
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url {
                // Allow loading the initial file
                if url.isFileURL && url.path == parent.document.path.path {
                    decisionHandler(.allow)
                    return
                }

                // Allow navigation to relative links within the same directory
                if url.isFileURL && url.path.hasPrefix(parent.document.path.deletingLastPathComponent().path) {
                    decisionHandler(.allow)
                    return
                }

                // For http/https links, open in default browser
                if url.scheme == "http" || url.scheme == "https" {
                    NSWorkspace.shared.open(url)
                    decisionHandler(.cancel)
                    return
                }

                // Allow other file URLs (for local resources)
                if url.isFileURL {
                    decisionHandler(.allow)
                    return
                }
            }

            decisionHandler(.allow)
        }

        @MainActor
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Restore scroll position if we have one
            if parent.scrollPosition.y > 0 {
                let script = "window.scrollTo(\(parent.scrollPosition.x), \(parent.scrollPosition.y));"
                webView.evaluateJavaScript(script)
            }

            // Set up scroll tracking
            let trackingScript = """
            window.addEventListener('scroll', function() {
                window.webkit.messageHandlers.scrollHandler.postMessage({
                    x: window.scrollX,
                    y: window.scrollY
                });
            }, { passive: true });
            """
            webView.evaluateJavaScript(trackingScript)
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var scrollPosition = CGPoint.zero

        var body: some View {
            HTMLWebView(
                document: Document(
                    name: "example.html",
                    path: URL(fileURLWithPath: "/tmp/example.html"),
                    type: .html,
                    size: 1024,
                    created: Date(),
                    modified: Date(),
                    content: "<html><body><h1>Test HTML</h1></body></html>"
                ),
                scrollPosition: $scrollPosition
            )
        }
    }

    return PreviewWrapper()
        .frame(width: 600, height: 400)
}
