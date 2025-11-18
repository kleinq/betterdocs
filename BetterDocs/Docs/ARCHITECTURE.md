# Architecture Documentation

## Overview

BetterDocs is a native macOS document management system built with SwiftUI, featuring integrated Claude Code agent capabilities.

## System Architecture

### Three-Tier Architecture

1. **Presentation Layer** (SwiftUI Views)
2. **Business Logic Layer** (Services)
3. **Data Layer** (Models & Persistence)

## Component Design

### 1. User Interface Components

#### Main Window Layout
```
┌─────────────────────────────────────────────────────────────┐
│ Ribbon Toolbar                                              │
├──────────────┬──────────────────────────┬───────────────────┤
│              │                          │                   │
│  Navigation  │    Preview Pane          │   Claude Code    │
│  Sidebar     │    (Main Content)        │   Chat Sidebar   │
│  (File Tree) │                          │                   │
│              │                          │                   │
└──────────────┴──────────────────────────┴───────────────────┘
```

#### View Responsibilities

**Toolbar View**
- File operations (New, Open, Import)
- View controls (Layout, Sort, Filter)
- Search interface
- Settings access

**Navigation View**
- Hierarchical file/folder tree
- Keyboard navigation (arrow keys)
- Context menu actions
- Drag & drop support
- Selection state management

**Preview View**
- Document rendering for supported formats
- Syntax highlighting for code files
- PDF rendering with QuickLook
- Office document preview
- CSV data grid view

**Sidebar View**
- Claude Code chat interface
- Conversation history
- Context-aware suggestions
- File scope selector

### 2. Service Layer

#### Document Parser Service
- **Purpose**: Parse and extract content from various document formats
- **Responsibilities**:
  - Format detection
  - Content extraction
  - Metadata extraction
  - Thumbnail generation

**Supported Formats**:
- Markdown: Native parsing with syntax highlighting
- PDF: PDFKit integration
- DOC/DOCX: Office document parsing
- PPT/PPTX: Presentation parsing
- CSV: Structured data parsing

#### Search Service
- **Purpose**: Provide fast, full-text search across documents
- **Responsibilities**:
  - Document indexing
  - Filename search
  - Content search
  - Search result ranking
  - Filter and sort operations

**Technology Options**:
- Core Spotlight (macOS native)
- Custom SQLite FTS (Full-Text Search)
- In-memory indexing for speed

#### Claude Integration Service
- **Purpose**: Integrate Claude Code SDK functionality
- **Responsibilities**:
  - API communication
  - Context management (active folder/documents)
  - Conversation state
  - File operation execution
  - Security sandboxing

**Key Features**:
- Execute Claude Code functions within document scope
- Pass document content as context
- Perform operations on files (read, summarize, analyze)
- Multi-file operations

### 3. Data Models

#### Document Model
```swift
struct Document {
    let id: UUID
    let name: String
    let path: URL
    let type: DocumentType
    let size: Int64
    let created: Date
    let modified: Date
    var metadata: [String: Any]
    var content: String?
    var thumbnail: Image?
}
```

#### Folder Model
```swift
struct Folder {
    let id: UUID
    let name: String
    let path: URL
    var children: [FileSystemItem]
    let created: Date
    let modified: Date
}
```

#### FileSystemItem (Protocol)
- Common interface for both Documents and Folders
- Enables unified tree navigation

#### Search Index Model
```swift
struct SearchIndex {
    let documentID: UUID
    let content: String
    let tokens: [String]
    var metadata: [String: String]
}
```

## Data Flow

### Document Loading Flow
1. User selects folder → Navigation View
2. File system scan → Document Parser Service
3. Extract metadata → Store in Models
4. Build search index → Search Service
5. Display in Navigation View

### Search Flow
1. User enters query → Toolbar Search
2. Query processed → Search Service
3. Index lookup → Results ranked
4. Display results → Navigation View
5. User selects result → Preview View shows document

### Claude Integration Flow
1. User sends message → Sidebar View
2. Gather context (active files/folders) → Claude Service
3. API call with context → Claude Code SDK
4. Receive response → Parse and display
5. Execute file operations if requested → Document Service
6. Update UI → Refresh affected views

## Technology Stack (2024-2025 Modern Stack)

### Core Technologies
- **Language**: Swift 6.0 (with strict concurrency checking)
- **UI Framework**: SwiftUI 6 (Primary) + AppKit (Hybrid as needed)
- **Minimum OS**: macOS 15.0+ (Sequoia)
- **Architecture Pattern**: MVVM (Model-View-ViewModel)
- **Data Persistence**: SwiftData (recommended for document-based apps)
- **Concurrency**: Swift Concurrency (actors, async/await)

### Apple Frameworks
- **SwiftUI 6**: Modern declarative UI with window management enhancements
- **SwiftData**: Native Swift persistence framework (replaces Core Data)
- **AppKit**: Advanced macOS features (hybrid approach where needed)
- **PDFKit**: PDF rendering and text extraction
- **QuickLook**: System-native file preview
- **UniformTypeIdentifiers**: Modern file type detection
- **OSLog**: Unified logging framework
- **Combine**: Reactive programming for async events

### SwiftUI 6 Features Utilized
- **Window Management**: `.windowStyle(.plain)`, `.windowLevel(.floating)`
- **Enhanced Animations**: SF Symbol effects (wiggle, breathe, rotate)
- **Improved Previews**: `#Preview` macro with `@Previewable`
- **Scroll Visibility**: `.onScrollVisibilityChange` for auto-play
- **Window Drag**: `WindowDragGesture()` for custom interactions

### Third-Party Dependencies
- **swift-markdown**: Apple's official Markdown parser (native Swift)
- **swift-syntax-highlight**: Code syntax highlighting (Point-Free)
- **Future**: Office document parsers (evaluate as needed)

### Data Race Safety (Swift 6)
- **Strict Concurrency**: Enabled via compiler flags
- **Actor Isolation**: All services use `actor` for thread safety
- **MainActor**: UI classes marked with `@MainActor`
- **Compile-time Checking**: Data races caught before runtime

## Security Considerations

### Sandboxing
- App Sandbox enabled
- User-selected file/folder access only
- Bookmark-based persistence for file access

### Claude Integration Security
- API key stored in Keychain
- User approval for file operations
- Audit log for Claude actions
- Scope limitation (only accessible documents)

## Performance Considerations

### Optimization Strategies
1. **Lazy Loading**: Load documents on-demand
2. **Background Indexing**: Index documents asynchronously
3. **Caching**: Cache parsed content and thumbnails
4. **Virtual Scrolling**: Efficient large folder handling
5. **Debounced Search**: Reduce search queries during typing

### Memory Management
- Weak references in view models
- Document content caching limits
- Thumbnail size optimization
- Release resources when views disappear

## Future Enhancements

### Phase 2 Features
- Cloud storage integration (iCloud, Dropbox)
- Advanced Claude workflows
- Document versioning
- Collaboration features
- Custom document types
- Plugin architecture

### Phase 3 Features
- iOS companion app
- Real-time sync
- Advanced analytics
- Team features
- Enterprise deployment
