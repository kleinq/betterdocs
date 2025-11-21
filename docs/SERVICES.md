# Services

This document describes the business logic services in BetterDocs.

## Service Architecture

Services encapsulate business logic and external interactions. They are:

- **Stateless**: No instance state (or minimal configuration)
- **Async**: All operations use async/await
- **Throwing**: Errors propagated to caller
- **Testable**: Can be mocked or tested independently

## Core Services

### FileManagementService

**Location**: `Sources/Services/FileManagementService.swift`

Handles all file system operations.

#### Responsibilities

1. **Folder Loading**: Read directory structure
2. **File Creation**: Create new files with templates
3. **File Operations**: Rename, delete, move, copy
4. **Validation**: Filename sanitization

#### Key Methods

```swift
// Load folder structure recursively
func loadFolder(at url: URL) async throws -> Folder

// Create new text file
func createTextFile(
    at folder: URL,
    name: String,
    fileType: FileType,
    initialContent: String
) throws -> URL

// Rename file or folder
func renameItem(
    at url: URL,
    newName: String,
    preserveExtension: Bool
) throws -> URL

// Delete file or folder
func deleteItem(at url: URL) throws

// Move file to another folder
func moveFile(from source: URL, to destination: URL) throws -> URL

// Copy file
func copyFile(from source: URL, to destination: URL) throws -> URL
```

#### Implementation Details

**Recursive Folder Loading**:
```swift
func loadFolder(at url: URL) async throws -> Folder {
    let children = try FileManager.default.contentsOfDirectory(at: url)

    var documents: [Document] = []
    var subfolders: [Folder] = []

    for childURL in children {
        if isDirectory(childURL) {
            let subfolder = try await loadFolder(at: childURL)
            subfolders.append(subfolder)
        } else {
            let doc = createDocument(from: childURL)
            documents.append(doc)
        }
    }

    return Folder(/* ... */)
}
```

**Filename Sanitization**:
- Removes: `/`, `\`, `:`
- Trims whitespace
- Prevents empty names

**Error Handling**:
- Throws `CocoaError` for file operations
- Custom error messages
- Validates paths before operations

---

### GitService

**Location**: `Sources/Services/GitService.swift`

Executes git operations via shell commands.

#### Responsibilities

1. **Status Checking**: Get repository status
2. **Commit**: Stage and commit changes
3. **Push/Pull**: Sync with remote
4. **Branch Info**: Get current branch and remote status

#### Key Methods

```swift
// Get full git status
func getStatus(at repoURL: URL) async throws -> GitStatus

// Commit all changes
func commit(message: String, at repoURL: URL) async throws

// Push to remote
func push(at repoURL: URL) async throws

// Pull from remote
func pull(at repoURL: URL) async throws

// Stage all changes
func stageAll(at repoURL: URL) async throws
```

#### Implementation Details

**Process Execution**:
```swift
private func runGitCommand(
    _ args: [String],
    at repoURL: URL
) async throws -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
    process.arguments = args
    process.currentDirectoryURL = repoURL

    let pipe = Pipe()
    process.standardOutput = pipe

    try process.run()
    process.waitUntilExit()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    return String(data: data, encoding: .utf8) ?? ""
}
```

**Status Parsing**:
```swift
// Parse output of git status --porcelain
func parseStatus(_ output: String) -> GitStatus {
    var modifiedFiles: [String] = []
    var untrackedFiles: [String] = []
    var stagedFiles: [String] = []

    for line in output.split(separator: "\n") {
        let status = String(line.prefix(2))
        let file = String(line.dropFirst(3))

        switch status {
        case " M": modifiedFiles.append(file)
        case "??": untrackedFiles.append(file)
        case "A ", "M ": stagedFiles.append(file)
        // ... more cases
        }
    }

    return GitStatus(/* ... */)
}
```

**Network Retry Logic**:
- 4 retries with exponential backoff
- Handles network failures gracefully
- Timeout after 30 seconds

**Commit Workflow**:
1. Stage all changes (`git add .`)
2. Commit with message
3. Auto-append attribution
4. Refresh status

---

### DocumentService

**Location**: `Sources/Services/DocumentParser/DocumentParser.swift`

Parses and extracts content from documents.

#### Responsibilities

1. **Content Extraction**: Read file contents
2. **Metadata Extraction**: Get title, headings, etc.
3. **Format Detection**: Identify document type
4. **Parsing**: Convert to structured data

#### Key Methods

```swift
// Parse document and extract content
func parseDocument(at url: URL) async throws -> Document

// Extract headings for outline
func extractHeadings(from markdown: String) -> [Heading]

// Get document metadata
func extractMetadata(from document: Document) -> [String: String]
```

#### Supported Formats

- **Markdown**: Full parsing with heading extraction
- **Plain Text**: Raw content
- **Code**: Language detection
- **PDF**: Text extraction via PDFKit
- **Images**: EXIF metadata

---

### SearchService

**Location**: `Sources/Services/Search/SearchService.swift`

Full-text search across documents.

#### Responsibilities

1. **Indexing**: Build search index
2. **Querying**: Search with relevance ranking
3. **Filtering**: Filter by file type, folder
4. **Highlighting**: Mark matching text

#### Key Methods

```swift
// Index a folder recursively
func indexFolder(_ folder: Folder) async

// Search for query
func search(
    query: String,
    in folder: Folder
) async throws -> [SearchResult]

// Clear index
func clearIndex()
```

#### Implementation Details

**Indexing**:
```swift
struct SearchIndex {
    var documentTerms: [UUID: Set<String>] = [:]
    var termDocuments: [String: Set<UUID>] = [:]

    func addDocument(_ doc: Document) {
        let terms = tokenize(doc.content)
        documentTerms[doc.id] = terms

        for term in terms {
            termDocuments[term, default: []].insert(doc.id)
        }
    }
}
```

**Tokenization**:
- Lowercase conversion
- Word boundary splitting
- Stop word removal (optional)

**Ranking**:
- TF-IDF scoring
- Filename match bonus
- Recent file bonus

---

### ClaudeService

**Location**: `Sources/Services/ClaudeIntegration/ClaudeService.swift`

Integrates with Claude AI API.

#### Responsibilities

1. **Chat**: Send messages and receive responses
2. **Context**: Provide document context
3. **Streaming**: Handle streaming responses
4. **Error Handling**: API error management

#### Key Methods

```swift
// Send chat message
func sendMessage(
    _ message: String,
    context: ChatContext?
) async throws -> String

// Stream response
func streamMessage(
    _ message: String,
    context: ChatContext?
) -> AsyncThrowingStream<String, Error>

// Get document summary
func summarizeDocument(_ document: Document) async throws -> String
```

#### API Integration

**Node.js Bridge**:
- Uses bundled Node.js runtime
- Executes TypeScript SDK
- Inter-process communication via JSON

**Context Handling**:
```swift
struct ChatContext {
    let documentContent: String?
    let selectedText: String?
    let annotations: [Annotation]
}
```

**Streaming Implementation**:
```swift
func streamMessage(_ message: String) -> AsyncThrowingStream<String, Error> {
    AsyncThrowingStream { continuation in
        Task {
            let process = startClaudeProcess(message)

            for try await chunk in process.standardOutput.bytes {
                continuation.yield(String(chunk))
            }

            continuation.finish()
        }
    }
}
```

---

### FileSystemWatcher

**Location**: `Sources/Services/FileSystemWatcher.swift`

Monitors file system changes.

#### Responsibilities

1. **Watch**: Monitor folder for changes
2. **Debounce**: Batch rapid changes
3. **Notify**: Trigger folder refresh

#### Implementation

```swift
class FileSystemWatcher {
    private var source: DispatchSourceFileSystemObject?

    func watch(url: URL, onChange: @escaping () -> Void) {
        let fd = open(url.path, O_EVTONLY)
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete],
            queue: .main
        )

        source.setEventHandler {
            // Debounce: wait 500ms after last change
            self.debounceTimer?.invalidate()
            self.debounceTimer = Timer.scheduledTimer(
                withTimeInterval: 0.5,
                repeats: false
            ) { _ in
                onChange()
            }
        }

        source.resume()
        self.source = source
    }
}
```

**Watched Events**:
- File creation
- File deletion
- File modification
- File rename

---

## Service Patterns

### Async/Await

All I/O operations are async:

```swift
// ❌ Bad: Blocking
func loadFolder(at url: URL) throws -> Folder {
    // Blocks thread
}

// ✅ Good: Non-blocking
func loadFolder(at url: URL) async throws -> Folder {
    // Yields thread
}
```

### Error Propagation

Services throw errors, AppState handles:

```swift
// Service
func deleteItem(at url: URL) throws {
    try FileManager.default.removeItem(at: url)
    // Let error propagate
}

// AppState
func deleteItem(_ item: FileSystemItem) {
    Task {
        do {
            try fileManagementService.deleteItem(at: item.path)
            await refreshFolder()
        } catch {
            // Handle and show to user
            showError("Delete failed: \(error)")
        }
    }
}
```

### Dependency Injection

Services created in AppState:

```swift
@Observable
class AppState {
    let fileManagementService = FileManagementService()
    let gitService = GitService()
    let documentService = DocumentService()

    // AppState can inject different implementations
    init(
        fileService: FileManagementService? = nil,
        gitService: GitService? = nil
    ) {
        self.fileManagementService = fileService ?? FileManagementService()
        self.gitService = gitService ?? GitService()
    }
}
```

### Testing

Services are testable:

```swift
// Mock service for testing
class MockFileService: FileManagementService {
    override func loadFolder(at url: URL) async throws -> Folder {
        return Folder(/* test data */)
    }
}

// Use in test
let appState = AppState(fileService: MockFileService())
```

---

## Service Communication

### AppState as Coordinator

AppState orchestrates services:

```swift
func openFolder() {
    Task {
        // 1. Load folder structure
        let folder = try await fileManagementService.loadFolder(at: url)

        // 2. Index for search
        await searchService.indexFolder(folder)

        // 3. Check git status
        let status = try? await gitService.getStatus(at: url)

        // 4. Update state
        await MainActor.run {
            self.rootFolder = folder
            self.gitStatus = status ?? GitStatus.notRepository
        }
    }
}
```

### Service-to-Service

Services generally don't call each other directly. Instead, AppState coordinates.

**Example**: Creating and opening a file

```swift
func createAndOpenFile(in folder: Folder) {
    Task {
        // 1. Create file
        let fileURL = try fileManagementService.createTextFile(
            at: folder.path,
            name: "New Document.md",
            fileType: .markdown,
            initialContent: ""
        )

        // 2. Refresh to get Document model
        try await refreshFolder()

        // 3. Find and open new file
        if let newDoc = findDocument(at: fileURL) {
            openInTab(newDoc)
        }
    }
}
```

---

**Last Updated**: 2025-11-20
