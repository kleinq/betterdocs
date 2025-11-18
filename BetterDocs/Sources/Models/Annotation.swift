import Foundation

struct Annotation: Identifiable, Codable, Equatable {
    let id: UUID
    let fileName: String
    let filePath: String
    let lineNumber: Int?
    let selection: TextSelection
    let type: AnnotationType
    let instruction: String
    let references: [String] // File paths referenced in instruction
    let created: Date
    var status: AnnotationStatus
    
    init(
        id: UUID = UUID(),
        fileName: String,
        filePath: String,
        lineNumber: Int? = nil,
        selection: TextSelection,
        type: AnnotationType,
        instruction: String,
        references: [String] = [],
        created: Date = Date(),
        status: AnnotationStatus = .pending
    ) {
        self.id = id
        self.fileName = fileName
        self.filePath = filePath
        self.lineNumber = lineNumber
        self.selection = selection
        self.type = type
        self.instruction = instruction
        self.references = references
        self.created = created
        self.status = status
    }
    
    var displayText: String {
        let fileInfo = "\(fileName)" + (lineNumber.map { ":\($0)" } ?? "")
        let truncated = instruction.count > 40 
            ? String(instruction.prefix(37)) + "..." 
            : instruction
        return "\(fileInfo) · \(truncated)"
    }
    
    var icon: String {
        switch type {
        case .edit: return "pencil.circle.fill"
        case .verify: return "checkmark.circle.fill"
        case .expand: return "plus.circle.fill"
        case .suggest: return "lightbulb.fill"
        }
    }
}

struct TextSelection: Codable, Equatable {
    let startOffset: Int
    let endOffset: Int
    let selectedText: String
}

enum AnnotationType: String, Codable, CaseIterable {
    case edit = "Edit"
    case verify = "Verify Consistency"
    case expand = "Expand Content"
    case suggest = "Suggestion"
}

enum AnnotationStatus: String, Codable {
    case pending
    case sent
    case completed
}
