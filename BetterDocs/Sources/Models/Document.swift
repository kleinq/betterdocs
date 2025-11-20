import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct Document: FileSystemItem {
    let id: UUID
    let name: String
    let path: URL
    let type: DocumentType
    let size: Int64
    let created: Date
    let modified: Date

    // Optional parsed content
    var content: String?
    var metadata: [String: String]

    // Computed properties
    var isFolder: Bool { false }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var icon: Image {
        type.icon
    }

    init(
        id: UUID? = nil,
        name: String,
        path: URL,
        type: DocumentType,
        size: Int64,
        created: Date,
        modified: Date,
        content: String? = nil,
        metadata: [String: String] = [:]
    ) {
        // Use stable ID based on path, or provided ID, or generate new one
        self.id = id ?? UUID.stableID(for: path)
        self.name = name
        self.path = path
        self.type = type
        self.size = size
        self.created = created
        self.modified = modified
        self.content = content
        self.metadata = metadata
    }
}

// Document type enumeration
enum DocumentType: Hashable {
    case markdown
    case pdf
    case word
    case powerpoint
    case excel
    case csv
    case text
    case code(language: String)
    case image
    case other

    var icon: Image {
        switch self {
        case .markdown:
            return Image(systemName: "doc.text.fill")
        case .pdf:
            return Image(systemName: "doc.richtext.fill")
        case .word:
            return Image(systemName: "doc.fill")
        case .powerpoint:
            return Image(systemName: "rectangle.stack.fill")
        case .excel, .csv:
            return Image(systemName: "tablecells.fill")
        case .text:
            return Image(systemName: "doc.plaintext.fill")
        case .code:
            return Image(systemName: "chevron.left.forwardslash.chevron.right")
        case .image:
            return Image(systemName: "photo.fill")
        case .other:
            return Image(systemName: "doc.fill")
        }
    }

    var displayName: String {
        switch self {
        case .markdown:
            return "Markdown"
        case .pdf:
            return "PDF"
        case .word:
            return "Word Document"
        case .powerpoint:
            return "PowerPoint"
        case .excel:
            return "Excel"
        case .csv:
            return "CSV"
        case .text:
            return "Text"
        case .code(let language):
            return "\(language.capitalized) Code"
        case .image:
            return "Image"
        case .other:
            return "Document"
        }
    }

    static func from(url: URL) -> DocumentType {
        guard let uti = UTType(filenameExtension: url.pathExtension) else {
            return .other
        }

        // Check file extension
        let ext = url.pathExtension.lowercased()

        switch ext {
        case "md", "markdown":
            return .markdown
        case "pdf":
            return .pdf
        case "doc", "docx":
            return .word
        case "ppt", "pptx":
            return .powerpoint
        case "xls", "xlsx":
            return .excel
        case "csv":
            return .csv
        case "txt":
            return .text
        case "swift":
            return .code(language: "Swift")
        case "py":
            return .code(language: "Python")
        case "js", "ts":
            return .code(language: "JavaScript")
        case "java":
            return .code(language: "Java")
        case "cpp", "c", "h":
            return .code(language: "C++")
        case "rs":
            return .code(language: "Rust")
        case "go":
            return .code(language: "Go")
        case "jpg", "jpeg", "png", "gif", "heic", "webp":
            return .image
        default:
            // Fallback to UTI checking
            if uti.conforms(to: .image) {
                return .image
            } else if uti.conforms(to: .plainText) || uti.conforms(to: .sourceCode) {
                return .text
            } else {
                return .other
            }
        }
    }
}

// Hashable conformance for Document
extension Document {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Document, rhs: Document) -> Bool {
        lhs.id == rhs.id
    }
}
