import SwiftUI

/// Sheet for selecting file type when creating a new document
struct FileCreationSheet: View {
    @Binding var isPresented: Bool
    let folderName: String
    let onCreate: (FileType) -> Void

    @State private var hoveredType: FileType?

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "doc.badge.plus")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)

                Text("Create New File")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("in \(folderName)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 24)

            // File type options
            HStack(spacing: 16) {
                // Markdown button
                FileTypeButton(
                    fileType: .markdown,
                    icon: "doc.richtext",
                    title: "Markdown",
                    description: "Formatted text with .md extension",
                    isHovered: hoveredType == .markdown
                ) {
                    onCreate(.markdown)
                    isPresented = false
                }
                .onHover { hovering in
                    hoveredType = hovering ? .markdown : nil
                }

                // Plain text button
                FileTypeButton(
                    fileType: .plainText,
                    icon: "doc.text",
                    title: "Plain Text",
                    description: "Simple text with .txt extension",
                    isHovered: hoveredType == .plainText
                ) {
                    onCreate(.plainText)
                    isPresented = false
                }
                .onHover { hovering in
                    hoveredType = hovering ? .plainText : nil
                }
            }
            .padding(.horizontal, 24)

            // Cancel button
            HStack {
                Spacer()
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding([.horizontal, .bottom], 24)
        }
        .frame(width: 500, height: 350)
    }
}

/// Individual file type button
struct FileTypeButton: View {
    let fileType: FileType
    let icon: String
    let title: String
    let description: String
    let isHovered: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 40))
                    .foregroundColor(isHovered ? .white : .accentColor)

                Text(title)
                    .font(.headline)
                    .foregroundColor(isHovered ? .white : .primary)

                Text(description)
                    .font(.caption)
                    .foregroundColor(isHovered ? .white.opacity(0.9) : .secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(fileType.fileExtension)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(isHovered ? .white.opacity(0.8) : .secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(isHovered ? Color.white.opacity(0.2) : Color.secondary.opacity(0.1))
                    )
            }
            .frame(maxWidth: .infinity)
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isHovered ? Color.accentColor : Color.secondary.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isHovered ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
    }
}

#Preview {
    FileCreationSheet(
        isPresented: .constant(true),
        folderName: "Documents"
    ) { fileType in
        print("Creating \(fileType.displayName) file")
    }
}
