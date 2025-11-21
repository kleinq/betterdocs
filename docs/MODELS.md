# Models

This document describes the data models and state management in BetterDocs.

## Model Overview

BetterDocs uses simple value types (structs) for data models, following Swift best practices.

```
Models
├── FileSystemItem (protocol)
│   ├── Document
│   └── Folder
├── GitStatus
├── DocumentTab
├── Annotation
├── Chat
└── SearchResult
```

## Core Models

### FileSystemItem Protocol

**Location**: `Sources/Models/FileSystemItem.swift`

Protocol for polymorphic file system items:

```swift
protocol FileSystemItem {
    var id: UUID { get }
    var name: String { get }
    var path: URL { get }
    var isFolder: Bool { get }
    var icon: Image { get }
}
```

**Purpose**: Allows uniform handling of both files and folders.

**Usage**:
```swift
func openItem(_ item: any FileSystemItem) {
    if item.isFolder {
        // Handle folder
    } else {
        // Handle file
    }
}
```

---

### Document

**Location**: `Sources/Models/Document.swift`

Represents a file in the system:

```swift
struct Document: FileSystemItem {
    let id: UUID
    let name: String
    let path: URL
    let type: DocumentType
    let size: Int64
    let created: Date
    let modified: Date

    var content: String?
    var metadata: [String: String]

    var isFolder: Bool { false }
    var icon: Image { type.icon }
}
```

**Properties**:
- `id`: Stable UUID based on path
- `name`: Filename with extension
- `path`: Absolute file path
- `type`: Document format (see DocumentType)
- `size`: File size in bytes
- `created`: Creation timestamp
- `modified`: Last modification timestamp
- `content`: Cached file contents (optional)
- `metadata`: Key-value metadata

**Computed Properties**:
```swift
var formattedSize: String {
    ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
}
```

**Identity**:
```swift
// Stable ID based on path
static func stableID(for url: URL) -> UUID {
    let hash = url.standardizedFileURL.path.hashValue
    return UUID(/* deterministic from hash */)
}
```

---

### DocumentType

**Location**: `Sources/Models/Document.swift:54`

Enum representing supported file types:

```swift
enum DocumentType: Hashable {
    case markdown
    case html
    case pdf
    case word
    case powerpoint
    case excel
    case csv
    case text
    case code(language: String)
    case image
    case other
}
```

**Associated Values**:
- `code`: Stores programming language name

**Methods**:

```swift
// Icon for file type
var icon: Image {
    switch self {
    case .markdown: Image(systemName: "doc.text.fill")
    case .html: Image(systemName: "globe")
    case .pdf: Image(systemName: "doc.richtext.fill")
    // ...
    }
}

// Display name
var displayName: String {
    switch self {
    case .markdown: "Markdown"
    case .html: "HTML"
    case .code(let lang): "\(lang.capitalized) Code"
    // ...
    }
}

// Detect from URL
static func from(url: URL) -> DocumentType {
    let ext = url.pathExtension.lowercased()
    switch ext {
    case "md", "markdown": return .markdown
    case "html", "htm": return .html
    case "swift": return .code(language: "Swift")
    // ...
    }
}
```

---

### Folder

**Location**: `Sources/Models/Folder.swift`

Represents a directory:

```swift
struct Folder: FileSystemItem {
    let id: UUID
    let name: String
    let path: URL
    let children: [any FileSystemItem]

    var isFolder: Bool { true }
    var icon: Image { Image(systemName: "folder.fill") }
}
```

**Computed Properties**:

```swift
// Count of direct document children
var documentCount: Int {
    children.filter { !$0.isFolder }.count
}

// Count of direct folder children
var folderCount: Int {
    children.filter { $0.isFolder }.count
}

// Total size of all documents (recursive)
var totalSize: Int64 {
    children.reduce(0) { total, item in
        if let doc = item as? Document {
            return total + doc.size
        } else if let folder = item as? Folder {
            return total + folder.totalSize
        }
        return total
    }
}
```

**Children Ordering**:
- Folders first, then files
- Alphabetically within each group

---

### GitStatus

**Location**: `Sources/Models/GitStatus.swift`

Git repository status:

```swift
struct GitStatus {
    let isGitRepository: Bool
    let currentBranch: String?
    let hasUncommittedChanges: Bool
    let hasUnpushedCommits: Bool
    let ahead: Int
    let behind: Int
    let modifiedFiles: [String]
    let untrackedFiles: [String]
    let stagedFiles: [String]
}
```

**Static Constructors**:

```swift
static var notRepository: GitStatus {
    GitStatus(
        isGitRepository: false,
        currentBranch: nil,
        hasUncommittedChanges: false,
        hasUnpushedCommits: false,
        ahead: 0,
        behind: 0,
        modifiedFiles: [],
        untrackedFiles: [],
        stagedFiles: []
    )
}
```

**Usage**:
```swift
if appState.gitStatus.isGitRepository {
    // Show git UI
}
```

---

### DocumentTab

**Location**: `Sources/Models/AppState.swift` (inline)

Represents an open tab:

```swift
struct DocumentTab: Identifiable {
    let id: UUID
    let itemID: UUID       // Reference to document/folder
    var itemName: String   // Cached name for tab display
    let itemPath: String   // Full path
    var scrollPosition: CGPoint  // Saved scroll position

    init(item: any FileSystemItem) {
        self.id = UUID()
        self.itemID = item.id
        self.itemName = item.name
        self.itemPath = item.path.path
        self.scrollPosition = .zero
    }
}
```

**Tab Types**:
1. **Preview Tab**: Ephemeral, single-click
2. **Pinned Tabs**: Persistent, double-click or explicit pin

**State Management**:
```swift
@Observable
class AppState {
    var openTabs: [DocumentTab] = []  // Pinned tabs
    var previewTab: DocumentTab?      // Ephemeral preview
    var activeTabID: UUID?            // Currently active
}
```

---

### Annotation

**Location**: `Sources/Models/Annotation.swift`

User annotation on document text:

```swift
struct Annotation: Identifiable, Codable {
    let id: UUID
    let filePath: String
    let selectedText: String
    let note: String
    let tags: [String]
    let startOffset: Int
    let endOffset: Int
    let created: Date
    var modified: Date
}
```

**Properties**:
- `filePath`: Absolute path to document
- `selectedText`: Original text that was annotated
- `note`: User's annotation note
- `tags`: Categorization tags
- `startOffset`: Character offset start
- `endOffset`: Character offset end
- `created`: Creation timestamp
- `modified`: Last edit timestamp

**Persistence**:
Stored in `.annotations` sidecar files:
```
MyDocument.md
MyDocument.md.annotations  (JSON array)
```

---

### Chat

**Location**: `Sources/Models/Chat.swift`

Chat conversation with Claude:

```swift
struct Chat: Identifiable, Codable {
    let id: UUID
    var title: String
    var messages: [ChatMessage]
    let created: Date
    var modified: Date
}

struct ChatMessage: Identifiable, Codable {
    let id: UUID
    let role: Role  // .user or .assistant
    let content: String
    let timestamp: Date

    enum Role: String, Codable {
        case user
        case assistant
    }
}
```

**Auto-Title**:
First message used as title, or "New Chat" if empty.

**Persistence**:
Stored in `~/Library/Application Support/BetterDocs/chats/`:
```
{chat-id}.json
```

---

### SearchResult

**Location**: `Sources/Models/SearchResult.swift`

Search match result:

```swift
struct SearchResult: Identifiable {
    let id: UUID
    let item: any FileSystemItem
    let document: Document?
    let matches: [SearchMatch]
    let score: Double
}

struct SearchMatch {
    let text: String          // Surrounding context
    let matchRange: Range<Int>  // Range within text
}
```

**Scoring**:
- TF-IDF based relevance
- Filename match bonus (+10)
- Recent file bonus (+5)

---

## State Management

### AppState

**Location**: `Sources/App/AppState.swift`

The central observable state container:

```swift
@Observable
class AppState {
    // File System
    var rootFolder: Folder?
    var selectedItem: (any FileSystemItem)?

    // Tabs
    var openTabs: [DocumentTab] = []
    var activeTabID: UUID?
    var previewTab: DocumentTab?

    // UI State
    var isOutlineVisible: Bool
    var isCommandPaletteOpen: Bool
    var isChatPopupOpen: Bool
    var isHelpOpen: Bool
    var showGitPanel: Bool
    var viewMode: ViewMode
    var isEditMode: Bool

    // Data
    var annotations: [Annotation] = []
    var chats: [Chat] = []
    var gitStatus: GitStatus = .notRepository

    // Search
    var searchQuery: String = ""
    var searchResults: [SearchResult] = []
    var isSearching: Bool

    // Services
    let fileManagementService = FileManagementService()
    let gitService = GitService()
    // ...
}
```

**Observable Pattern**:
```swift
// Automatic UI updates
@Environment(AppState.self) private var appState

var body: some View {
    Text(appState.selectedItem?.name ?? "None")
    // Updates automatically when selectedItem changes
}
```

---

## Model Patterns

### Value Semantics

All models are structs (value types):

```swift
// ✅ Good: Value type
struct Document {
    let id: UUID
    var content: String
}

// ❌ Bad: Reference type for data
class Document {
    var id: UUID
    var content: String
}
```

**Benefits**:
- Thread safety
- Predictable copying
- No unintended sharing

### Immutability

Prefer `let` over `var`:

```swift
struct Document {
    let id: UUID        // Never changes
    let path: URL       // Never changes
    var content: String // Can be updated
}
```

### Identifiable

Conform to `Identifiable` for SwiftUI:

```swift
struct Document: Identifiable {
    let id: UUID
    // ...
}

// SwiftUI can now use in ForEach
ForEach(documents) { doc in
    Text(doc.name)
}
```

### Codable

Use `Codable` for persistence:

```swift
struct Annotation: Codable {
    // Automatically generates encoding/decoding
}

// Save
let data = try JSONEncoder().encode(annotation)
try data.write(to: fileURL)

// Load
let data = try Data(contentsOf: fileURL)
let annotation = try JSONDecoder().decode(Annotation.self, from: data)
```

### Computed Properties

Use computed properties for derived data:

```swift
struct Folder {
    let children: [any FileSystemItem]

    // Computed on access
    var documentCount: Int {
        children.filter { !$0.isFolder }.count
    }

    // Not stored separately
}
```

---

## Model Evolution

### Versioning

When changing models, consider compatibility:

```swift
struct Annotation: Codable {
    // Version 1
    let id: UUID
    let note: String

    // Version 2: Added tags
    let tags: [String]

    // Custom decoding for backward compatibility
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        note = try container.decode(String.self, forKey: .note)
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
    }
}
```

### Migration

For breaking changes, implement migration:

```swift
// Old format
struct AnnotationV1: Codable {
    let id: UUID
    let note: String
}

// New format
struct Annotation: Codable {
    let id: UUID
    let note: String
    let tags: [String]

    init(from v1: AnnotationV1) {
        self.id = v1.id
        self.note = v1.note
        self.tags = []
    }
}

// Migration
func migrateAnnotations() {
    if let oldData = try? Data(contentsOf: oldFileURL) {
        let v1 = try JSONDecoder().decode([AnnotationV1].self, from: oldData)
        let v2 = v1.map { Annotation(from: $0) }
        let newData = try JSONEncoder().encode(v2)
        try newData.write(to: newFileURL)
    }
}
```

---

**Last Updated**: 2025-11-20
