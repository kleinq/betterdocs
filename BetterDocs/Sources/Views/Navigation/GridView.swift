import SwiftUI

struct GridView: View {
    @Environment(AppState.self) private var appState
    let folder: Folder

    private let columns = [
        GridItem(.adaptive(minimum: 120, maximum: 160), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(folder.children, id: \.id) { item in
                    GridItemView(item: item)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            // Double-click opens in tab
                            appState.openInTab(item)
                        }
                        .onTapGesture {
                            // Single-click selects/previews
                            appState.selectItem(item)
                        }
                }
            }
            .padding()
        }
        .background(Color(NSColor.textBackgroundColor))
    }
}

struct GridItemView: View {
    @Environment(AppState.self) private var appState
    let item: any FileSystemItem

    private var isSelected: Bool {
        appState.selectedItem?.id == item.id
    }

    var body: some View {
        VStack(spacing: 8) {
            // Thumbnail/Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(thumbnailBackground)
                    .frame(height: 100)

                if let document = item as? Document {
                    documentThumbnail(document)
                } else {
                    folderIcon
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )

            // Name and type badge
            VStack(spacing: 4) {
                Text(item.name)
                    .font(.caption)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)

                if let document = item as? Document {
                    typeBadge(for: document.type)
                }
            }
        }
        .frame(maxWidth: 160)
        .padding(8)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(8)
    }

    // MARK: - Thumbnail Background

    private var thumbnailBackground: Color {
        if item is Folder {
            return Color.accentColor.opacity(0.1)
        } else if let document = item as? Document {
            switch document.type {
            case .markdown:
                return Color.blue.opacity(0.1)
            case .pdf:
                return Color.red.opacity(0.1)
            case .image:
                return Color.purple.opacity(0.1)
            case .code:
                return Color.green.opacity(0.1)
            default:
                return Color.gray.opacity(0.1)
            }
        }
        return Color.gray.opacity(0.1)
    }

    // MARK: - Document Thumbnail

    @ViewBuilder
    private func documentThumbnail(_ document: Document) -> some View {
        switch document.type {
        case .markdown:
            VStack(spacing: 4) {
                Image(systemName: "doc.text")
                    .font(.system(size: 36))
                    .foregroundColor(.blue)

                // Show preview of first line if available
                if let content = document.content {
                    let firstLine = content.components(separatedBy: .newlines).first ?? ""
                    Text(firstLine)
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .padding(.horizontal, 8)
                }
            }

        case .pdf:
            Image(systemName: "doc.richtext")
                .font(.system(size: 40))
                .foregroundColor(.red)

        case .image:
            // For images, try to load actual thumbnail
            if let imageURL = URL(string: document.path.path),
               let nsImage = NSImage(contentsOf: imageURL) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 100)
                    .clipped()
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 40))
                    .foregroundColor(.purple)
            }

        case .code:
            VStack(spacing: 4) {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(.system(size: 32))
                    .foregroundColor(.green)

                if let content = document.content {
                    Text(content.prefix(50))
                        .font(.system(size: 6, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(5)
                        .padding(.horizontal, 8)
                }
            }

        case .text:
            VStack(spacing: 4) {
                Image(systemName: "doc.plaintext")
                    .font(.system(size: 36))
                    .foregroundColor(.secondary)

                if let content = document.content {
                    Text(content.prefix(60))
                        .font(.system(size: 7))
                        .foregroundColor(.secondary)
                        .lineLimit(4)
                        .padding(.horizontal, 8)
                }
            }

        default:
            Image(systemName: "doc")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Folder Icon

    private var folderIcon: some View {
        VStack(spacing: 4) {
            Image(systemName: "folder.fill")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)

            if let folder = item as? Folder {
                Text("\(folder.children.count) items")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Type Badge

    @ViewBuilder
    private func typeBadge(for type: DocumentType) -> some View {
        let badgeText: String
        let badgeColor: Color

        switch type {
        case .markdown:
            badgeText = "MD"
            badgeColor = .blue
        case .pdf:
            badgeText = "PDF"
            badgeColor = .red
        case .image:
            badgeText = "IMG"
            badgeColor = .purple
        case .code(let language):
            badgeText = language.uppercased()
            badgeColor = .green
        case .text:
            badgeText = "TXT"
            badgeColor = .gray
        default:
            badgeText = "FILE"
            badgeColor = .gray
        }

        Text(badgeText)
            .font(.system(size: 8, weight: .semibold))
            .foregroundColor(badgeColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(badgeColor.opacity(0.15))
            .cornerRadius(4)
    }
}

#Preview {
    GridView(folder: Folder(
        name: "Test",
        path: URL(fileURLWithPath: "/test"),
        children: []
    ))
    .environment(AppState())
}
