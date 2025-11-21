# File Operations

This document describes file handling, supported types, and I/O operations in BetterDocs.

## Supported File Types

### Text-Based Files

#### Markdown (.md, .markdown)
- **Preview**: Rendered HTML with marked.js
- **Edit**: Plain text editor with syntax highlighting
- **Features**:
  - Heading extraction for outline
  - Link handling
  - Code block syntax highlighting
  - Dark/light mode support

#### HTML (.html, .htm)
- **Preview**: Rendered in WKWebView
- **Edit**: Plain text editor
- **Features**:
  - Relative resource links
  - External link handling
  - JavaScript execution
  - CSS styling

#### Plain Text (.txt)
- **Preview**: Monospaced text view
- **Edit**: Plain text editor
- **Features**: Simple, fast viewing

### Code Files

Syntax-aware viewing for:
- Swift (.swift)
- Python (.py)
- JavaScript/TypeScript (.js, .ts)
- Java (.java)
- C/C++ (.c, .cpp, .h)
- Rust (.rs)
- Go (.go)

**Preview**: Monospaced text with language badge
**Edit**: Plain text editor (future: syntax highlighting)

### Documents

#### PDF (.pdf)
- **Preview**: PDFKit native viewer
- **Features**:
  - Page navigation
  - Zoom controls
  - Text selection
  - Search (future)

#### Microsoft Office
- **Word** (.doc, .docx)
- **PowerPoint** (.ppt, .pptx)
- **Excel** (.xls, .xlsx)

**Preview**: Basic info display (future: preview via QuickLook)

#### CSV (.csv)
- **Preview**: Placeholder (future: table view)
- **Edit**: Plain text editor

### Images

Supported formats:
- JPEG (.jpg, .jpeg)
- PNG (.png)
- GIF (.gif)
- HEIC (.heic)
- WebP (.webp)

**Preview**: Native SwiftUI Image view with scaling
**Features**:
- Aspect fit/fill
- Zoom support (future)
- EXIF metadata (future)

---

## File Operations

### Creating Files

**Location**: `FileManagementService.swift:createTextFile`

```swift
func createTextFile(
    at folder: URL,
    name: String,
    fileType: FileType,
    initialContent: String = ""
) throws -> URL
```

**Process**:
1. Sanitize filename (remove `/`, `\`, `:`)
2. Add appropriate extension
3. Check for duplicates → append number
4. Write initial content
5. Return file URL

**Filename Sanitization**:
```swift
func sanitizeFilename(_ name: String) -> String {
    var sanitized = name
    let invalidChars = CharacterSet(charactersIn: "/:\\")
    sanitized = sanitized.components(separatedBy: invalidChars).joined()
    sanitized = sanitized.trimmingCharacters(in: .whitespaces)
    return sanitized.isEmpty ? "Untitled" : sanitized
}
```

**Duplicate Handling**:
```
MyDocument.md       (original)
MyDocument 2.md     (first duplicate)
MyDocument 3.md     (second duplicate)
```

**Templates**:
```swift
enum FileType {
    case markdown
    case plainText

    var defaultExtension: String {
        switch self {
        case .markdown: ".md"
        case .plainText: ".txt"
        }
    }

    var template: String {
        switch self {
        case .markdown: "# New Document\n\n"
        case .plainText: ""
        }
    }
}
```

---

### Reading Files

**Lazy Loading**:
Files are read on-demand when previewed:

```swift
struct MarkdownPreview: View {
    @State private var content: String?

    var body: some View {
        // ...
    }

    .task(id: document.modified) {
        await loadContent()
    }

    private func loadContent() async {
        do {
            content = try String(contentsOf: document.path, encoding: .utf8)
        } catch {
            content = "Error loading file"
        }
    }
}
```

**Caching**:
- Content cached in `Document.content` (optional)
- Cache invalidated on file modification
- Re-read from disk when `modified` timestamp changes

**Encoding**:
- UTF-8 for text files
- Binary for images, PDFs

---

### Updating Files

**Auto-Save**:
Text editor auto-saves after 2 seconds of inactivity:

```swift
struct TextEditorView: View {
    @State private var text: String
    @State private var saveTask: Task<Void, Never>?

    var body: some View {
        TextEditor(text: $text)
            .onChange(of: text) { _, newText in
                // Cancel previous save task
                saveTask?.cancel()

                // Schedule new save after 2 seconds
                saveTask = Task {
                    try? await Task.sleep(for: .seconds(2))
                    guard !Task.isCancelled else { return }
                    await saveFile(newText)
                }
            }
    }

    private func saveFile(_ content: String) async {
        try? content.write(to: document.path, atomically: true, encoding: .utf8)
        // Update modified timestamp
        document.modified = Date()
    }
}
```

**Manual Save**:
Cmd+S triggers immediate save:

```swift
.onKeyPress(.init("s"), modifiers: .command) {
    saveTask?.cancel()
    Task { await saveFile(text) }
    return .handled
}
```

---

### Renaming Files

**Location**: `FileManagementService.swift:renameItem`

```swift
func renameItem(
    at url: URL,
    newName: String,
    preserveExtension: Bool = true
) throws -> URL
```

**Process**:
1. Validate new name (no invalid characters)
2. Preserve extension if requested
3. Check for conflicts
4. Use FileManager.moveItem
5. Return new URL

**Extension Handling**:
```swift
let finalName: String
if preserveExtension, let ext = url.pathExtension {
    // Remove extension from new name if present
    let nameWithoutExt = newName.hasSuffix(".\(ext)")
        ? String(newName.dropLast(ext.count + 1))
        : newName

    finalName = "\(nameWithoutExt).\(ext)"
} else {
    finalName = newName
}
```

**AI-Powered Rename**:
For text files, can use Claude to suggest names:

```swift
func renameWithAI(_ item: FileSystemItem) {
    Task {
        let content = try String(contentsOf: item.path, encoding: .utf8)
        let suggestion = try await claudeService.suggestFilename(content)
        renameItem(item, newName: suggestion)
    }
}
```

---

### Deleting Files

**Location**: `FileManagementService.swift:deleteItem`

```swift
func deleteItem(at url: URL) throws {
    try FileManager.default.removeItem(at: url)
}
```

**Safety**:
- No confirmation in service layer
- AppState or UI should confirm before calling
- Moves to Trash (not permanent deletion)

**Related Files**:
When deleting a document, also delete:
- `.annotations` sidecar file
- Any cached data

```swift
func deleteItem(_ item: FileSystemItem) {
    // Show confirmation dialog
    let confirmed = await showConfirmation("Delete \(item.name)?")
    guard confirmed else { return }

    do {
        try fileManagementService.deleteItem(at: item.path)

        // Delete annotations
        let annotationPath = item.path.appendingPathExtension("annotations")
        try? FileManager.default.removeItem(at: annotationPath)

        await refreshFolder()
    } catch {
        showError("Delete failed")
    }
}
```

---

### Moving Files

**Location**: `FileManagementService.swift:moveFile`

```swift
func moveFile(
    from source: URL,
    to destination: URL
) throws -> URL
```

**Drag & Drop**:
```swift
.dropDestination(for: URL.self) { droppedURLs, _ in
    for url in droppedURLs {
        appState.moveFile(from: url, to: targetFolder)
    }
    return true
}
```

**Conflict Resolution**:
If destination exists, append number:
```
source: Documents/file.txt
target: Downloads/

Move to: Downloads/file.txt
If exists: Downloads/file 2.txt
```

---

### Copying Files

**Location**: `FileManagementService.swift:copyFile`

```swift
func copyFile(
    from source: URL,
    to destination: URL
) throws -> URL
```

**Use Cases**:
- Duplicate file
- Copy between folders
- Backup before edit

---

## File System Watching

**Location**: `FileSystemWatcher.swift`

Monitors folder for external changes:

```swift
class FileSystemWatcher {
    func watch(url: URL, onChange: @escaping () -> Void) {
        let fd = open(url.path, O_EVTONLY)
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete],
            queue: .main
        )

        source.setEventHandler {
            // Debounce: batch rapid changes
            self.scheduleRefresh(onChange)
        }

        source.resume()
    }
}
```

**Events Watched**:
- File added to folder
- File removed from folder
- File renamed
- File modified (content changed)

**Debouncing**:
Changes batched with 500ms delay:
```swift
private var debounceTimer: Timer?

private func scheduleRefresh(_ onChange: @escaping () -> Void) {
    debounceTimer?.invalidate()
    debounceTimer = Timer.scheduledTimer(
        withTimeInterval: 0.5,
        repeats: false
    ) { _ in
        onChange()
    }
}
```

**Integration**:
```swift
func openFolder(_ url: URL) {
    rootFolder = try await fileManagementService.loadFolder(at: url)

    // Watch for changes
    fileSystemWatcher.watch(url: url) {
        Task { await refreshFolder() }
    }
}
```

---

## File Type Detection

**Location**: `Document.swift:DocumentType.from`

Uses file extension and UTType:

```swift
static func from(url: URL) -> DocumentType {
    let ext = url.pathExtension.lowercased()

    // Primary: Extension matching
    switch ext {
    case "md", "markdown": return .markdown
    case "html", "htm": return .html
    case "pdf": return .pdf
    // ...
    }

    // Fallback: UTType conformance
    guard let uti = UTType(filenameExtension: ext) else {
        return .other
    }

    if uti.conforms(to: .image) {
        return .image
    } else if uti.conforms(to: .plainText) {
        return .text
    }

    return .other
}
```

---

## Performance Optimization

### Lazy Loading

Only load visible content:
```swift
// ❌ Bad: Load all file contents upfront
func loadFolder() -> Folder {
    let docs = files.map { file in
        let content = try String(contentsOf: file)
        return Document(/* with content */)
    }
}

// ✅ Good: Load structure only
func loadFolder() -> Folder {
    let docs = files.map { file in
        return Document(/* without content */)
    }
    // Content loaded when document is previewed
}
```

### Pagination

For large folders, consider pagination:
```swift
struct LargeFolder: View {
    let items: [FileSystemItem]
    let pageSize = 100

    var body: some View {
        LazyVStack {
            ForEach(items.prefix(currentPage * pageSize)) { item in
                FileRow(item: item)
            }

            if hasMore {
                Button("Load More") {
                    currentPage += 1
                }
            }
        }
    }
}
```

### Background Processing

Heavy operations on background queue:
```swift
func indexFolder(_ folder: Folder) async {
    await Task.detached {
        for child in folder.children {
            if let doc = child as? Document {
                let content = try? String(contentsOf: doc.path)
                await searchService.indexDocument(doc, content: content)
            }
        }
    }.value
}
```

---

## Error Handling

### Common Errors

```swift
enum FileError: Error {
    case notFound
    case permissionDenied
    case invalidName
    case diskFull
    case alreadyExists
}
```

### Error Recovery

```swift
do {
    try fileManagementService.createTextFile(/* ... */)
} catch CocoaError.fileWriteNoPermission {
    showError("Permission denied. Try choosing a different location.")
} catch CocoaError.fileWriteFileExists {
    // Auto-rename with number suffix
    let uniqueName = generateUniqueName(original)
    try fileManagementService.createTextFile(name: uniqueName)
} catch {
    showError("Unexpected error: \(error.localizedDescription)")
}
```

---

## Security Considerations

### Sandbox

App is sandboxed with entitlements:
- `com.apple.security.files.user-selected.read-write`
  - User must explicitly choose folder
  - No arbitrary file system access

### Path Validation

```swift
func validatePath(_ url: URL, within allowed: URL) -> Bool {
    let allowedPath = allowed.standardizedFileURL.path
    let targetPath = url.standardizedFileURL.path

    // Prevent directory traversal
    return targetPath.hasPrefix(allowedPath)
}
```

### Content Sanitization

When creating files from user input:
```swift
let sanitized = input
    .replacingOccurrences(of: "/", with: "-")
    .replacingOccurrences(of: "\\", with: "-")
    .replacingOccurrences(of: ":", with: "-")
```

---

**Last Updated**: 2025-11-20
