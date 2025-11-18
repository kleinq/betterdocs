# BetterDocs Technology Stack - 2025 Edition

## Overview

This document outlines the modern, cutting-edge technology stack for BetterDocs based on the latest frameworks and best practices for macOS 15 Sequoia (2024-2025).

---

## Core Technologies

### Language & Compiler

#### Swift 6.0 (September 2024)
**Why Swift 6?**
- **Data Race Safety**: Compile-time detection of data races prevents crashes and corruption
- **Strict Concurrency Checking**: Enabled by default with our configuration
- **Improved Type System**: Enhanced safety and clarity
- **Better Performance**: Optimized compiler and runtime

**Key Features We Use:**
```swift
// Strict concurrency enabled in Package.swift
.enableUpcomingFeature("StrictConcurrency")
```

**Benefits:**
- Catch concurrency bugs at compile time
- Safe concurrent access with actors
- Modern async/await patterns
- Future-proof codebase

**Migration Path:**
- Start with Swift 6 language mode from day one
- All modules benefit from data race safety
- Incremental adoption possible for dependencies

### Platform

#### macOS 15 Sequoia (Released September 2024)
**Target Version:** macOS 15.0+

**Key Platform Features:**
- Apple Intelligence integration capabilities
- Enhanced window tiling
- Improved performance and security
- Latest SwiftUI and AppKit APIs

**Why macOS 15 Only?**
- Access to latest APIs and frameworks
- Best performance and security
- Simplified testing and deployment
- Modern user expectations

---

## UI Frameworks

### Primary: SwiftUI 6 (WWDC 2024)

**Recommendation:** ✅ **Use SwiftUI as primary UI framework**

#### New Features in SwiftUI 6 for macOS 15

**1. Enhanced Window Management**
```swift
// New window styling options
.windowStyle(.plain)  // Remove default chrome
.windowLevel(.floating)  // Keep on top
.defaultWindowPlacement { content, context in
    // Intelligent window positioning
}
.windowResizability(.contentSize)
```

**2. Improved Animations**
```swift
// New SF Symbol animations
Image(systemName: "doc.fill")
    .symbolEffect(.wiggle)  // Draw attention
    .symbolEffect(.breathe)  // Ongoing activity
    .symbolEffect(.rotate)  // Spinning
```

**3. Better Previews**
```swift
// New Previewable macro (Xcode 16)
#Preview {
    @Previewable @State var document: Document
    DocumentView(document: document)
}
```

**4. Enhanced Scrolling**
```swift
ScrollView {
    // Detect visibility changes for auto-play
    ContentView()
        .onScrollVisibilityChange { isVisible in
            // Trigger actions
        }
}
```

**5. Window Drag Gestures**
```swift
VStack {
    // Enable window dragging
    WindowDragGesture()
}
```

#### SwiftUI Best Practices for macOS 15

**✅ Use SwiftUI For:**
- Main app structure and layout
- Standard UI components
- Cross-platform code reuse
- Reactive UI updates
- Rapid prototyping

**⚠️ Consider AppKit For:**
- Complex file operations
- Advanced text editing
- Custom controls with fine-grained control
- Performance-critical rendering

### Secondary: AppKit (Hybrid Approach)

**When to Use AppKit:**
- NSOpenPanel, NSSavePanel (file dialogs)
- NSWorkspace (file operations)
- Complex table views with intricate behavior
- Advanced text editing (NSTextView)
- Custom drawing with precise control

**Integration Pattern:**
```swift
// SwiftUI wrapping AppKit
struct AppKitFileDialog: NSViewRepresentable {
    func makeNSView(context: Context) -> NSOpenPanel {
        // AppKit implementation
    }
}
```

---

## Data & Persistence

### SwiftData (WWDC 2023, Enhanced 2024)

**Recommendation:** ✅ **Use SwiftData for document persistence**

#### Why SwiftData?

**Modern Data Framework:**
- Native Swift syntax (no Objective-C)
- Type-safe queries with `@Query`
- Automatic relationships
- Built for SwiftUI
- Document-based app support

**Document-Based Integration:**
```swift
@main
struct BetterDocsApp: App {
    var body: some Scene {
        DocumentGroup(editing: DocumentModel.self) {
            ContentView()
        }
    }
}

@Model
class DocumentModel {
    var content: String
    var metadata: [String: String]
    // SwiftData handles persistence
}
```

#### SwiftData Features for BetterDocs

**1. Automatic Persistence**
- No manual save/load code
- Automatic iCloud sync (optional)
- Version management
- Undo/redo support

**2. Powerful Querying**
```swift
@Query(sort: \.modified, order: .reverse)
var recentDocuments: [DocumentModel]

@Query(filter: #Predicate<DocumentModel> { doc in
    doc.type == .markdown
})
var markdownFiles: [DocumentModel]
```

**3. Document-Based Apps**
- Automatic file management
- Multiple document support
- Document browser
- Version browsing

#### Implementation Strategy

**Phase 1: Basic Persistence**
- Store document metadata
- Cache parsed content
- Search index persistence

**Phase 2: Advanced Features**
- Full document storage
- Version history
- iCloud sync
- Conflict resolution

### Alternative: Core Data

**When to Consider:**
- Need to support macOS 14 and earlier
- Complex migration requirements
- Existing Core Data expertise
- Advanced CoreData-specific features

**Our Choice:** SwiftData (modern, Swift-native, better SwiftUI integration)

---

## Apple Frameworks

### Essential Frameworks

#### 1. UniformTypeIdentifiers
**Purpose:** Modern file type detection

```swift
import UniformTypeIdentifiers

let type = UTType(filenameExtension: "md")
if type?.conforms(to: .plainText) {
    // Handle text file
}
```

**Benefits:**
- Modern replacement for NSWorkspace type checking
- Better type safety
- Extensible

#### 2. PDFKit
**Purpose:** PDF rendering and manipulation

```swift
import PDFKit

let pdfView = PDFView()
pdfView.document = PDFDocument(url: fileURL)
```

**Features:**
- Native PDF rendering
- Search within PDFs
- Annotations
- Text extraction

#### 3. QuickLook
**Purpose:** File preview generation

```swift
import QuickLook

let preview = QLPreviewController()
preview.dataSource = self
```

**Features:**
- System-native previews
- Supports all macOS file types
- Thumbnails
- No custom rendering needed

#### 4. OSLog (Unified Logging)
**Purpose:** Modern logging framework

```swift
import OSLog

let logger = Logger(subsystem: "com.betterdocs", category: "document")
logger.info("Document loaded: \(filename)")
logger.error("Failed to parse: \(error)")
```

**Benefits:**
- Privacy-preserving
- Performance optimized
- Console.app integration
- Structured logging

#### 5. Combine (Reactive Programming)
**Purpose:** Asynchronous event processing

```swift
import Combine

class SearchService {
    @Published var searchResults: [SearchResult] = []

    var cancellables = Set<AnyCancellable>()
}
```

**Use Cases:**
- Search debouncing
- Reactive UI updates
- Async operation chaining
- State management

---

## Concurrency & Performance

### Swift Concurrency (Swift 5.5+, Enhanced in Swift 6)

**Modern Async/Await:**
```swift
actor DocumentService {
    func scanFolder(at url: URL) async throws -> Folder {
        // Safe concurrent access
        await withTaskGroup { group in
            // Parallel processing
        }
    }
}
```

**Key Patterns:**

**1. Actors for Thread Safety**
```swift
actor SearchIndex {
    private var index: [UUID: Entry] = [:]

    func add(_ entry: Entry) {
        // Automatically serialized
        index[entry.id] = entry
    }
}
```

**2. Structured Concurrency**
```swift
await withTaskGroup(of: Document.self) { group in
    for url in urls {
        group.addTask {
            try await parseDocument(url)
        }
    }
}
```

**3. MainActor for UI**
```swift
@MainActor
class AppState: ObservableObject {
    @Published var documents: [Document] = []

    // Always runs on main thread
    func updateUI() {
        // Safe UI updates
    }
}
```

### Performance Optimizations

**1. Lazy Loading**
```swift
LazyVStack {
    ForEach(documents) { doc in
        DocumentRow(doc: doc)
    }
}
```

**2. Task Cancellation**
```swift
let task = Task {
    try await heavyOperation()
}

// Cancel when needed
task.cancel()
```

**3. Debouncing**
```swift
@Published var searchText = ""

searchText
    .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
    .sink { text in
        performSearch(text)
    }
```

---

## Third-Party Dependencies

### Current Dependencies

#### 1. swift-markdown (Apple Official)
**Purpose:** Markdown parsing and rendering

**GitHub:** https://github.com/apple/swift-markdown

**Why?**
- Official Apple framework
- Native Swift implementation
- AST-based parsing
- Extensible
- Well-maintained

**Usage:**
```swift
import Markdown

let document = Document(parsing: markdownText)
let html = document.format()
```

#### 2. swift-syntax-highlight (Recommended)
**Purpose:** Code syntax highlighting

**GitHub:** https://github.com/pointfreeco/swift-syntax-highlight

**Why?**
- Swift-native
- Multiple language support
- Fast performance
- SwiftUI integration

**Usage:**
```swift
import SyntaxHighlight

CodeView(code: swiftCode, language: .swift)
```

### Potential Future Dependencies

#### Office Document Parsing

**Option 1: Custom Implementation**
- Use Zip archives (DOCX/XLSX are ZIP files)
- Parse XML content
- Extract text

**Option 2: Third-Party**
- Evaluate as needed
- Security concerns with parsing
- May not be necessary for V1

**Recommendation:** Start with basic text extraction, add libraries if needed

#### PDF Text Extraction

**Option: PDFKit (Built-in)**
```swift
let page = pdfDocument.page(at: 0)
let text = page?.string
```

**No third-party needed** - PDFKit handles this

---

## Development Tools

### Xcode 16 (Released 2024)

**Key Features:**
- Swift 6 compiler
- Predictive code completion (requires 16GB RAM)
- Enhanced SwiftUI previews
- Improved debugging
- Cloud integration

**New Preview Features:**
```swift
#Preview("Light Mode") {
    ContentView()
}

#Preview("Dark Mode") {
    ContentView()
        .preferredColorScheme(.dark)
}
```

### Testing Frameworks

#### Swift Testing (New in Swift 6)
**Modern testing framework**

```swift
import Testing

@Test func documentParsing() {
    let doc = Document(name: "test.md", ...)
    #expect(doc.type == .markdown)
}

@Test(.tags(.performance))
func searchPerformance() {
    // Performance test
}
```

**Benefits:**
- Native Swift syntax
- Better error messages
- Parameterized tests
- Tags and organization

#### XCTest (Traditional)
**Still supported, mature**

```swift
import XCTest

class DocumentTests: XCTestCase {
    func testDocumentCreation() {
        XCTAssertNotNil(document)
    }
}
```

**Our Strategy:** Use Swift Testing for new code, XCTest as fallback

---

## Architecture Patterns

### MVVM (Model-View-ViewModel)

**Modern SwiftUI Pattern:**
```swift
// Model
struct Document: Identifiable {
    let id: UUID
    var content: String
}

// ViewModel
@Observable
class DocumentViewModel {
    var document: Document
    var isLoading = false

    func load() async {
        isLoading = true
        // Load document
        isLoading = false
    }
}

// View
struct DocumentView: View {
    @State var viewModel: DocumentViewModel

    var body: some View {
        // UI
    }
}
```

### Clean Architecture

**Layers:**
1. **Presentation** - SwiftUI Views
2. **Business Logic** - Services (Actors)
3. **Data** - SwiftData Models
4. **Infrastructure** - File system, network

### Dependency Injection

**SwiftUI Environment:**
```swift
@Environment(\.documentService) var documentService

extension EnvironmentValues {
    var documentService: DocumentService {
        get { self[DocumentServiceKey.self] }
        set { self[DocumentServiceKey.self] = newValue }
    }
}
```

---

## Security & Privacy

### App Sandbox
**Required for Mac App Store**

```xml
<key>com.apple.security.files.user-selected.read-write</key>
<true/>
```

**Implementation:**
- User must select folders
- Bookmark URLs for persistence
- Security-scoped resources

### Keychain Integration

**For Claude API Key:**
```swift
import Security

class KeychainService {
    func save(apiKey: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "claudeAPIKey",
            kSecValueData as String: apiKey.data(using: .utf8)!
        ]
        SecItemAdd(query as CFDictionary, nil)
    }
}
```

---

## Updated Tech Stack Summary

### ✅ Recommended Stack for 2025

| Component | Technology | Version | Status |
|-----------|-----------|---------|--------|
| **Language** | Swift | 6.0 | Latest |
| **Platform** | macOS | 15 (Sequoia) | Latest |
| **UI Framework** | SwiftUI | 6 | Primary |
| **UI (Hybrid)** | AppKit | Latest | Secondary |
| **Data** | SwiftData | 2024 | Recommended |
| **Concurrency** | Swift Concurrency | 6.0 | Native |
| **Markdown** | swift-markdown | Latest | Official |
| **Syntax Highlight** | swift-syntax-highlight | Latest | Third-party |
| **Testing** | Swift Testing | 6.0 | Modern |
| **PDF** | PDFKit | Native | Built-in |
| **Files** | UniformTypeIdentifiers | Native | Built-in |
| **Logging** | OSLog | Native | Built-in |

---

## Migration from Old Stack

### If You Were Using...

**Objective-C → Swift 6**
- Complete rewrite recommended
- Swift offers better safety and performance

**Core Data → SwiftData**
- Modern Swift-native API
- Better SwiftUI integration
- Simpler code

**UIKit/NSView → SwiftUI**
- Declarative, modern UI
- Reactive updates
- Less boilerplate

**GCD → Swift Concurrency**
- Safer concurrency
- Better error handling
- Structured concurrency

---

## Performance Targets (2025)

### App Performance Goals

| Metric | Target | Notes |
|--------|--------|-------|
| App Launch | < 1s | Cold start |
| Folder Scan (1000 files) | < 3s | With indexing |
| Search Results | < 300ms | Full-text search |
| Preview Load | < 500ms | Most formats |
| Memory Usage | < 300MB | Normal operation |
| CPU Usage | < 20% | Idle state |

### Optimization Techniques

**1. Async/Await Throughout**
```swift
actor IndexService {
    func index(_ docs: [Document]) async {
        await withTaskGroup { group in
            // Parallel processing
        }
    }
}
```

**2. Lazy Loading**
```swift
@Query var documents: [Document]

LazyVStack {
    ForEach(documents) { doc in
        DocumentRow(doc: doc)
            .task {
                await loadContent(for: doc)
            }
    }
}
```

**3. Caching Strategy**
```swift
actor CacheService {
    private var cache = NSCache<NSURL, DocumentContent>()

    func get(_ url: URL) async -> DocumentContent? {
        cache.object(forKey: url as NSURL)
    }
}
```

---

## Future-Proofing

### Upcoming Technologies to Watch

**1. Swift 7+ Features**
- Enhanced concurrency
- Better type inference
- Performance improvements

**2. visionOS Support**
- Spatial computing
- Shared SwiftUI code
- Document viewing in 3D space

**3. Apple Intelligence APIs**
- On-device ML models
- Enhanced text analysis
- Smart features

**4. SwiftData Enhancements**
- Better sync
- Performance improvements
- New query features

---

## Recommendations Summary

### ✅ Do This Now

1. **Use Swift 6** with strict concurrency
2. **Target macOS 15+** only
3. **SwiftUI as primary** UI framework
4. **SwiftData for persistence**
5. **Actors for services**
6. **Async/await everywhere**
7. **Swift Testing** for new tests

### ⚠️ Consider Carefully

1. **Third-party dependencies** - minimize them
2. **AppKit integration** - only when necessary
3. **Backward compatibility** - not needed for new app

### ❌ Avoid

1. **Objective-C** - no longer necessary
2. **GCD directly** - use Swift concurrency
3. **Core Data** - SwiftData is better
4. **UIKit patterns** - use SwiftUI patterns

---

## Getting Started with Modern Stack

### 1. Verify Your Setup

```bash
# Check Swift version
swift --version
# Should be 6.0 or later

# Check Xcode version
xcodebuild -version
# Should be 16.0 or later
```

### 2. Enable Modern Features

Already configured in `Package.swift`:
- Swift 6 language mode
- Strict concurrency checking
- Latest SDK

### 3. Follow Best Practices

- Use `actor` for services
- Use `@MainActor` for UI classes
- Use `async/await` for async operations
- Use `@Observable` for view models (iOS 17+/macOS 14+)

### 4. Learn New APIs

**Essential WWDC 2024 Sessions:**
- "What's new in SwiftUI"
- "Tailor macOS windows with SwiftUI"
- "Migrate to Swift 6"
- "Build a document-based app with SwiftData"

---

## Conclusion

The 2025 tech stack for BetterDocs leverages cutting-edge Apple technologies:

- **Swift 6** for safety and performance
- **SwiftUI 6** for modern, reactive UI
- **SwiftData** for effortless persistence
- **Native frameworks** over third-party when possible
- **Future-proof architecture** ready for visionOS and beyond

This stack positions BetterDocs as a modern, performant, and maintainable macOS application ready for the App Store and beyond.

**Last Updated:** November 2024
**Next Review:** WWDC 2025
