import SwiftUI
import AppKit
import Foundation

/// A native markdown renderer using NSAttributedString
struct MarkdownRenderer: NSViewRepresentable {
    let markdown: String

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()

        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }

        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = true
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.textContainerInset = NSSize(width: 16, height: 16)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else {
            return
        }

        // Update background color for theme changes
        textView.backgroundColor = NSColor.textBackgroundColor

        // Convert markdown to attributed string with proper styling
        do {
            let attributedString = try AttributedString(
                markdown: markdown,
                options: AttributedString.MarkdownParsingOptions(
                    interpretedSyntax: .full,
                    failurePolicy: .returnPartiallyParsedIfPossible
                )
            )

            // Convert to NSMutableAttributedString for better control
            let nsAttributedString = NSMutableAttributedString(attributedString)
            let fullRange = NSRange(location: 0, length: nsAttributedString.length)

            // Set default paragraph style with proper line spacing
            let defaultParagraphStyle = NSMutableParagraphStyle()
            defaultParagraphStyle.lineSpacing = 4
            defaultParagraphStyle.paragraphSpacing = 12
            nsAttributedString.addAttribute(.paragraphStyle, value: defaultParagraphStyle, range: fullRange)

            // First pass: set default font size and color where not already set
            nsAttributedString.enumerateAttributes(in: fullRange, options: []) { attributes, range, _ in
                // Set default font size if no font exists
                if attributes[.font] == nil {
                    nsAttributedString.addAttribute(.font, value: NSFont.systemFont(ofSize: 14), range: range)
                }

                // Always ensure text color for visibility
                nsAttributedString.addAttribute(.foregroundColor, value: NSColor.labelColor, range: range)
            }

            // Second pass: enhance formatting with proper fonts and spacing based on presentation intent
            var headerCount = 0
            nsAttributedString.enumerateAttributes(in: fullRange, options: []) { attributes, range, _ in
                var needsUpdate = false
                var newFont: NSFont?

                // Check for presentation intent - it's an opaque object, use string description
                if let intent = attributes[.presentationIntentAttributeName] {
                    let intentString = String(describing: intent)

                    // Debug first header
                    if headerCount == 0 && intentString.lowercased().contains("header") {
                        let text = (nsAttributedString.string as NSString).substring(with: range)
                        print("✅ Header found - level extraction working, text: '\(text.prefix(30))'")
                        headerCount += 1
                    }

                    // Parse header level from string description like "Header (id 1) (1)"
                    // The format is: <NSPresentationIntent 0x...>: Header (id X) (LEVEL) indent Y
                    if intentString.contains("Header") {
                        // Extract level - it's the number in the second set of parentheses
                        let components = intentString.components(separatedBy: " ")
                        var level = 1

                        // Look for pattern like "(1)" or "(2)" after "Header"
                        if let headerIndex = components.firstIndex(of: "Header"),
                           headerIndex + 3 < components.count {
                            // Format: "Header (id X) (LEVEL)"
                            let levelPart = components[headerIndex + 3]
                            if let extracted = Int(levelPart.trimmingCharacters(in: CharacterSet(charactersIn: "()"))) {
                                level = extracted
                            }
                        }

                        // Add spacing before headers
                        let paragraphStyle = NSMutableParagraphStyle()
                        paragraphStyle.paragraphSpacingBefore = 12
                        paragraphStyle.paragraphSpacing = 8
                        nsAttributedString.addAttribute(.paragraphStyle, value: paragraphStyle, range: range)

                        switch level {
                        case 1:
                            newFont = NSFont.boldSystemFont(ofSize: 28)
                            needsUpdate = true
                        case 2:
                            newFont = NSFont.boldSystemFont(ofSize: 24)
                            needsUpdate = true
                        case 3:
                            newFont = NSFont.boldSystemFont(ofSize: 20)
                            needsUpdate = true
                        default:
                            newFont = NSFont.boldSystemFont(ofSize: 18)
                            needsUpdate = true
                        }
                    }
                    // Paragraph - add spacing
                    else if intentString.contains("paragraph") {
                        let paragraphStyle = NSMutableParagraphStyle()
                        paragraphStyle.paragraphSpacing = 12
                        nsAttributedString.addAttribute(.paragraphStyle, value: paragraphStyle, range: range)
                    }
                    // Strong emphasis (bold) - look for "strongly" in description
                    else if intentString.lowercased().contains("strongly") {
                        if let currentFont = attributes[.font] as? NSFont {
                            newFont = NSFont.boldSystemFont(ofSize: currentFont.pointSize)
                            needsUpdate = true
                        }
                    }
                    // Emphasis (italic)
                    else if intentString.lowercased().contains("emphasis") && !intentString.lowercased().contains("strongly") {
                        if let currentFont = attributes[.font] as? NSFont {
                            // Try to get italic font, or use obliqueness
                            let italicFont = NSFontManager.shared.convert(currentFont, toHaveTrait: .italicFontMask)
                            if italicFont != currentFont {
                                newFont = italicFont
                            } else {
                                // Italic font not available, use obliqueness
                                newFont = currentFont
                                nsAttributedString.addAttribute(.obliqueness, value: 0.15, range: range)
                            }
                            needsUpdate = true
                        }
                    }
                }

                if needsUpdate, let font = newFont {
                    nsAttributedString.addAttribute(.font, value: font, range: range)
                }
            }

            textView.textStorage?.setAttributedString(nsAttributedString)
        } catch {
            print("❌ Error parsing markdown: \(error)")
            // Fallback to plain text with proper color
            let plainText = NSMutableAttributedString(string: markdown)
            plainText.addAttribute(.foregroundColor, value: NSColor.labelColor, range: NSRange(location: 0, length: plainText.length))
            plainText.addAttribute(.font, value: NSFont.systemFont(ofSize: 14), range: NSRange(location: 0, length: plainText.length))
            textView.textStorage?.setAttributedString(plainText)
        }
    }
}
