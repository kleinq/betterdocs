import Foundation

struct SearchResult: Identifiable {
    let id: UUID
    let item: any FileSystemItem
    let matches: [SearchMatch]
    let score: Double

    var document: Document? {
        item as? Document
    }

    var folder: Folder? {
        item as? Folder
    }
}

struct SearchMatch {
    let range: Range<String.Index>
    let context: String
    let lineNumber: Int?

    var preview: String {
        // Trim context to reasonable length
        let maxLength = 200
        if context.count > maxLength {
            let start = context.index(context.startIndex, offsetBy: 0, limitedBy: context.endIndex) ?? context.startIndex
            let end = context.index(context.startIndex, offsetBy: maxLength, limitedBy: context.endIndex) ?? context.endIndex
            return String(context[start..<end]) + "..."
        }
        return context
    }
}

// Search filter options
struct SearchFilter {
    var fileTypes: Set<DocumentType> = []
    var dateRange: DateRange?
    var sizeRange: SizeRange?
    var includeContent: Bool = true
    var includeFilenames: Bool = true

    struct DateRange {
        let from: Date?
        let to: Date?
    }

    struct SizeRange {
        let min: Int64?
        let max: Int64?
    }

    static var `default`: SearchFilter {
        SearchFilter(
            fileTypes: [],
            dateRange: nil,
            sizeRange: nil,
            includeContent: true,
            includeFilenames: true
        )
    }
}

// Search result sorting options
enum SearchSortOption {
    case relevance
    case name
    case dateModified
    case size

    var displayName: String {
        switch self {
        case .relevance: return "Relevance"
        case .name: return "Name"
        case .dateModified: return "Date Modified"
        case .size: return "Size"
        }
    }
}
