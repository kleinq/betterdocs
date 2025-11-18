import SwiftUI

struct DocumentOutlineView: View {
    let markdownContent: String
    @Binding var isVisible: Bool
    let onHeadingClick: (String) -> Void
    
    @State private var headings: [MarkdownHeading] = []
    
    var body: some View {
        if isVisible {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    Text("Document Outline")
                        .font(.headline)
                    Spacer()
                    Button(action: { isVisible = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                
                Divider()
                
                // Outline content
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(headings) { heading in
                            Button(action: {
                                onHeadingClick(heading.id)
                            }) {
                                HStack(alignment: .top, spacing: 4) {
                                    Text(heading.text)
                                        .font(.system(size: heading.level == 1 ? 13 : 12))
                                        .foregroundColor(heading.level == 1 ? .primary : .secondary)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                    Spacer()
                                }
                                .padding(.leading, CGFloat((heading.level - 1) * 12))
                                .padding(.vertical, 4)
                                .padding(.horizontal, 12)
                            }
                            .buttonStyle(.plain)
                            .contentShape(Rectangle())
                            .onHover { hovering in
                                if hovering {
                                    NSCursor.pointingHand.push()
                                } else {
                                    NSCursor.pop()
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .background(Color(NSColor.controlBackgroundColor))
            .frame(height: 250)
            .onAppear {
                extractHeadings()
            }
            .onChange(of: markdownContent) { _, _ in
                extractHeadings()
            }
        }
    }
    
    private func extractHeadings() {
        var extracted: [MarkdownHeading] = []
        let lines = markdownContent.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Check for # heading format
            if trimmed.hasPrefix("#") {
                var level = 0
                var text = trimmed
                
                // Count the number of # symbols
                while text.hasPrefix("#") && level < 6 {
                    level += 1
                    text = String(text.dropFirst())
                }
                
                text = text.trimmingCharacters(in: .whitespaces)
                
                if !text.isEmpty && level > 0 {
                    let heading = MarkdownHeading(
                        id: "heading-\(extracted.count)",
                        text: text,
                        level: level
                    )
                    extracted.append(heading)
                }
            }
        }
        
        headings = extracted
    }
}

struct MarkdownHeading: Identifiable {
    let id: String
    let text: String
    let level: Int
}
