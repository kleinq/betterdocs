# Technology Stack Comparison: Old vs New (2025)

## Quick Reference: What Changed and Why

This document provides a quick comparison between traditional macOS development approaches and our modern 2025 stack.

---

## Language & Concurrency

### Old Approach
```swift
// Objective-C or Swift 5.x
class DocumentService {
    private let queue = DispatchQueue(label: "docs")
    private var documents: [Document] = []

    func loadDocument(completion: @escaping (Result<Document, Error>) -> Void) {
        queue.async {
            // Load document
            DispatchQueue.main.async {
                completion(.success(document))
            }
        }
    }
}
```

**Issues:**
- Manual thread management
- Easy to create race conditions
- Callback hell
- No compile-time safety

### New Approach (Swift 6)
```swift
// Swift 6 with strict concurrency
actor DocumentService {
    private var documents: [Document] = []

    func loadDocument() async throws -> Document {
        // Automatically thread-safe
        // Load document
        return document
    }
}
```

**Benefits:**
- Automatic thread safety
- Data races caught at compile time
- Clean async/await syntax
- Structured concurrency

**Why Change:** Safety, clarity, and prevention of subtle concurrency bugs

---

## UI Framework

### Old Approach: AppKit/NSView
```swift
class DocumentViewController: NSViewController {
    @IBOutlet weak var tableView: NSTableView!

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.delegate = self
        tableView.dataSource = self
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        return documents.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        // Configure view
    }
}
```

**Characteristics:**
- Imperative UI updates
- Lots of boilerplate
- Delegate/datasource patterns
- Manual state synchronization

### New Approach: SwiftUI 6
```swift
struct DocumentListView: View {
    @Query var documents: [Document]

    var body: some View {
        List(documents) { document in
            DocumentRow(document: document)
        }
    }
}
```

**Benefits:**
- Declarative UI
- Automatic updates
- Much less code
- State-driven design
- Better preview support

**Why Change:** Developer productivity, less bugs, modern patterns

---

## Data Persistence

### Old Approach: Core Data
```objectivec
// Objective-C style Core Data
NSManagedObjectContext *context = [[NSManagedObjectContext alloc] init];
NSEntityDescription *entity = [NSEntityDescription entityForName:@"Document"
                                           inManagedObjectContext:context];
NSManagedObject *document = [[NSManagedObject alloc] initWithEntity:entity
                                     insertIntoManagedObjectContext:context];
[document setValue:@"Test" forKey:@"title"];
NSError *error;
[context save:&error];
```

Even modern Swift Core Data:
```swift
let fetchRequest: NSFetchRequest<Document> = Document.fetchRequest()
fetchRequest.predicate = NSPredicate(format: "type == %@", "markdown")
let documents = try context.fetch(fetchRequest)
```

**Issues:**
- Objective-C based
- Verbose syntax
- Manual relationship management
- Complex migration
- String-based predicates (not type-safe)

### New Approach: SwiftData
```swift
@Model
class Document {
    var title: String
    var content: String
    var type: DocumentType
}

// Querying
@Query(filter: #Predicate<Document> { $0.type == .markdown })
var markdownDocs: [Document]
```

**Benefits:**
- Native Swift
- Type-safe queries
- Automatic relationships
- Clean syntax
- Built for SwiftUI

**Why Change:** Modern Swift-first API, better integration, less code

---

## Window Management

### Old Approach: NSWindowController
```swift
class DocumentWindowController: NSWindowController {
    override func windowDidLoad() {
        super.windowDidLoad()
        window?.setFrame(NSRect(x: 100, y: 100, width: 800, height: 600), display: true)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }
}
```

### New Approach: SwiftUI 6
```swift
WindowGroup {
    ContentView()
}
.defaultWindowPlacement { content, context in
    WindowPlacement(.prominent)
}
.windowResizability(.contentSize)
.windowStyle(.plain)
```

**Benefits:**
- Declarative window configuration
- Better multi-window support
- Automatic state restoration
- Modern modifiers

**Why Change:** Simpler API, less boilerplate, better defaults

---

## File Type Detection

### Old Approach: NSWorkspace
```swift
let workspace = NSWorkspace.shared
if let uti = workspace.type(ofFile: path) {
    if workspace.type(uti, conformsToType: "public.text") {
        // Handle text file
    }
}
```

### New Approach: UniformTypeIdentifiers
```swift
import UniformTypeIdentifiers

let type = UTType(filenameExtension: url.pathExtension)
if type?.conforms(to: .plainText) == true {
    // Handle text file
}
```

**Benefits:**
- Modern Swift API
- Better type safety
- Clearer conformance checking
- Future-proof

**Why Change:** Modern replacement for legacy APIs

---

## Async Operations

### Old Approach: Grand Central Dispatch
```swift
DispatchQueue.global(qos: .userInitiated).async {
    let result = self.heavyOperation()
    DispatchQueue.main.async {
        self.updateUI(with: result)
    }
}
```

### New Approach: Swift Concurrency
```swift
Task {
    let result = await heavyOperation()
    await MainActor.run {
        updateUI(with: result)
    }
}
```

**Benefits:**
- Structured concurrency
- Automatic cancellation propagation
- Better error handling
- Clearer intent

**Why Change:** Safety, clarity, automatic thread-safety

---

## Testing

### Old Approach: XCTest
```swift
class DocumentTests: XCTestCase {
    func testDocumentCreation() {
        let doc = Document()
        XCTAssertNotNil(doc)
        XCTAssertEqual(doc.type, .markdown)
    }
}
```

### New Approach: Swift Testing
```swift
import Testing

@Test func documentCreation() {
    let doc = Document()
    #expect(doc != nil)
    #expect(doc.type == .markdown)
}

@Test(.tags(.performance))
func searchPerformance() async {
    await #expect(searchTime < 0.3)
}
```

**Benefits:**
- Modern Swift syntax
- Better error messages
- Parameterized tests
- Tags and organization
- Async testing support

**Why Change:** Better developer experience, modern patterns

---

## Comparison Table

| Feature | Old (Pre-2024) | New (2025) | Why Change |
|---------|---------------|------------|------------|
| **Language** | Swift 5.x / Obj-C | Swift 6.0 | Data race safety |
| **Concurrency** | GCD/OperationQueue | Actors/async-await | Compile-time safety |
| **UI** | AppKit/NSView | SwiftUI 6 | Declarative, less code |
| **Data** | Core Data | SwiftData | Swift-native, simpler |
| **Windows** | NSWindowController | SwiftUI scenes | Modern API |
| **Types** | NSWorkspace | UniformTypeIdentifiers | Better types |
| **Testing** | XCTest | Swift Testing | Modern syntax |
| **Logging** | print/NSLog | OSLog | Privacy, performance |
| **Preview** | Manual IB | SwiftUI Previews | Instant feedback |

---

## Migration Effort

### Low Effort (Quick Wins)
- ✅ Use `async/await` instead of completion handlers
- ✅ Replace `print()` with `Logger`
- ✅ Use `UniformTypeIdentifiers` instead of NSWorkspace
- ✅ Add Swift Testing for new tests

### Medium Effort
- ⚙️ Refactor services to use `actor`
- ⚙️ Convert views to SwiftUI incrementally
- ⚙️ Add `@MainActor` to UI classes
- ⚙️ Enable strict concurrency checking

### High Effort (Long-term)
- 🔨 Full SwiftUI adoption
- 🔨 Core Data → SwiftData migration
- 🔨 Refactor all async code to Swift concurrency
- 🔨 Complete Swift 6 compliance

---

## Performance Comparison

### App Launch Time
- **Old (AppKit)**: ~2-3 seconds
- **New (SwiftUI)**: ~1-2 seconds
- **Improvement**: 30-50% faster

### Memory Usage
- **Old (Manual management)**: Higher, variable
- **New (ARC + Swift)**: Lower, consistent
- **Improvement**: 20-30% reduction

### Development Speed
- **Old (AppKit + Core Data)**: Baseline
- **New (SwiftUI + SwiftData)**: 2-3x faster
- **Improvement**: Significantly faster iteration

---

## Code Size Comparison

### Document List Example

**Old AppKit:**
```swift
// ~80 lines of code
class DocumentListViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource {
    @IBOutlet weak var tableView: NSTableView!
    private var documents: [Document] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTableView()
        loadDocuments()
    }

    func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        // ... more setup
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        documents.count
    }

    // ... 60 more lines
}
```

**New SwiftUI:**
```swift
// ~15 lines of code
struct DocumentListView: View {
    @Query var documents: [Document]

    var body: some View {
        List(documents) { doc in
            DocumentRow(doc: doc)
        }
    }
}
```

**Code Reduction:** ~80% less code

---

## When to Use What

### Use SwiftUI 6 When:
✅ Building new UI
✅ Standard controls sufficient
✅ Targeting macOS 15+
✅ Want rapid iteration
✅ Cross-platform needs

### Use AppKit When:
⚠️ Complex custom controls
⚠️ Need precise control
⚠️ Legacy compatibility
⚠️ SwiftUI limitations exist
⚠️ Specific AppKit features needed

### Use SwiftData When:
✅ New projects
✅ Document-based apps
✅ Simple data models
✅ Want modern Swift API

### Use Core Data When:
⚠️ Must support macOS 14 or earlier
⚠️ Complex data models with specific features
⚠️ Existing Core Data expertise
⚠️ Migration too costly

---

## Real-World Examples

### Example 1: Document Loading

**Before:**
```swift
func loadDocument(_ url: URL, completion: @escaping (Result<Document, Error>) -> Void) {
    DispatchQueue.global().async {
        do {
            let data = try Data(contentsOf: url)
            let doc = try JSONDecoder().decode(Document.self, from: data)
            DispatchQueue.main.async {
                completion(.success(doc))
            }
        } catch {
            DispatchQueue.main.async {
                completion(.failure(error))
            }
        }
    }
}
```

**After:**
```swift
func loadDocument(_ url: URL) async throws -> Document {
    let data = try Data(contentsOf: url)
    return try JSONDecoder().decode(Document.self, from: data)
}
```

**Lines of code:** 15 → 4 (73% reduction)

### Example 2: Search with Debouncing

**Before:**
```swift
private var searchWorkItem: DispatchWorkItem?

func searchTextChanged(_ text: String) {
    searchWorkItem?.cancel()

    let workItem = DispatchWorkItem { [weak self] in
        self?.performSearch(text)
    }
    searchWorkItem = workItem

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
}
```

**After:**
```swift
@Published var searchText = ""

searchText
    .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
    .sink { text in
        performSearch(text)
    }
```

**Lines of code:** 12 → 6 (50% reduction)

---

## Recommendations

### For New Projects
**Use the 2025 stack:**
- Swift 6 with strict concurrency
- SwiftUI 6 for all UI
- SwiftData for persistence
- Native Apple frameworks

### For Existing Projects
**Gradual migration:**
1. Start with Swift 6 language mode
2. Convert services to actors
3. Use SwiftUI for new views
4. Migrate data layer when ready

### For Learning
**Focus on:**
1. Swift concurrency fundamentals
2. SwiftUI declarative patterns
3. SwiftData basics
4. Modern Swift features

---

## Conclusion

The 2025 stack represents a significant improvement:

- **Safety:** Compile-time concurrency checking
- **Productivity:** Less boilerplate, faster iteration
- **Performance:** Better memory and CPU usage
- **Future-proof:** Built on latest Apple technologies

**Bottom Line:** The investment in modern technologies pays off in:
- Fewer bugs
- Faster development
- Better maintainability
- Happier developers

---

**Last Updated:** November 2024
**Based on:** WWDC 2024, Swift 6.0, macOS 15 Sequoia
