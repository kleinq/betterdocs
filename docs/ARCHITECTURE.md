# Architecture

This document describes the overall architecture, design patterns, and technical decisions in BetterDocs.

## High-Level Architecture

BetterDocs follows a clean, layered architecture:

```
┌─────────────────────────────────────────┐
│            SwiftUI Views                │
│  (Navigation, Preview, Toolbar, etc.)   │
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│           AppState                      │
│     (Observable State Container)        │
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│           Services Layer                │
│  (FileManagement, Git, Document, etc.)  │
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│          Models Layer                   │
│    (Document, Folder, GitStatus)        │
└─────────────────────────────────────────┘
```

## Core Frameworks

### SwiftUI 6

BetterDocs is built entirely with SwiftUI, leveraging:

- **Declarative UI**: All views are declarative and composable
- **State Management**: Uses `@Observable` macro for reactive state
- **Navigation**: Natural SwiftUI navigation with bindings
- **Animations**: Spring animations for smooth transitions

### Swift Concurrency

The app uses modern Swift concurrency:

- **async/await**: All I/O operations are asynchronous
- **Task**: Background processing and cancellation
- **@MainActor**: UI updates are properly isolated
- **Sendable**: Strict concurrency checking enabled

### AppKit Integration

While primarily SwiftUI, the app uses AppKit for:

- **NSEvent Monitoring**: Global keyboard shortcuts
- **WKWebView**: HTML and markdown rendering
- **PDFKit**: PDF document viewing
- **NSWorkspace**: File system operations

## Design Patterns

### 1. Observable State Pattern

**AppState** is the single source of truth using Swift's Observation framework:

```swift
@Observable
class AppState {
    // Shared state
    var rootFolder: Folder?
    var selectedItem: (any FileSystemItem)?
    var openTabs: [DocumentTab] = []

    // Services
    let fileManagementService = FileManagementService()
    let gitService = GitService()
}
```

**Benefits**:
- Centralized state management
- Automatic UI updates
- Easy debugging and state inspection

### 2. Protocol-Oriented Design

The `FileSystemItem` protocol provides polymorphism:

```swift
protocol FileSystemItem {
    var id: UUID { get }
    var name: String { get }
    var path: URL { get }
    var isFolder: Bool { get }
    var icon: Image { get }
}
```

Implemented by:
- `Document` (files)
- `Folder` (directories)

### 3. Service Layer Pattern

Business logic is isolated in dedicated services:

- **FileManagementService**: File I/O operations
- **GitService**: Git command execution
- **DocumentParser**: Content parsing and extraction
- **SearchService**: Full-text search indexing
- **ClaudeService**: AI integration

**Benefits**:
- Separation of concerns
- Testability
- Reusability

### 4. View Composition

Complex views are built from smaller, focused components:

```swift
ContentView
├── ToolbarView
├── NavigationView
│   ├── FileTreeItemView (recursive)
│   └── GridView
├── PreviewView
│   ├── DocumentPreviewView
│   │   ├── MarkdownPreview
│   │   ├── PDFPreview
│   │   └── ImagePreview
│   └── FolderPreviewView
└── Overlays (Chat, Help, Git Panel)
```

## State Management

### AppState Responsibilities

1. **Navigation State**: Current folder, selected item, expanded folders
2. **Tab Management**: Open tabs, active tab, preview tab
3. **UI State**: View mode, edit mode, panel visibility
4. **Git State**: Repository status, operations in progress
5. **Service Coordination**: Orchestrates service calls

### State Flow

```
User Action → View → AppState → Service → Model → AppState → View Update
```

Example: Opening a folder

1. User clicks "Open Folder"
2. `ToolbarView` calls `appState.openFolder()`
3. `AppState` uses `FileManagementService.loadFolder()`
4. Service creates `Folder` model with children
5. `AppState.rootFolder` is updated
6. SwiftUI automatically re-renders `NavigationView`

## Persistence

### UserDefaults

Simple preferences stored in UserDefaults:

- Navigation sidebar width
- Expanded folder paths
- Last opened folder path
- View mode (list/grid)
- Open tabs state

### File System

- Documents stored on disk (no database)
- Watched for external changes via `DispatchSource`
- Chat history in JSON files
- Annotations in sidecar `.annotations` files

## Concurrency Model

### Main Actor Isolation

UI operations run on the main actor:

```swift
@MainActor
func openFolder() {
    // Safe to update UI here
}
```

### Background Processing

Heavy operations use background tasks:

```swift
Task {
    let folder = try await fileManagementService.loadFolder(at: url)
    await MainActor.run {
        self.rootFolder = folder
    }
}
```

## Error Handling

### Strategy

- Services throw errors for exceptional cases
- AppState catches and handles errors
- User-facing errors shown in alerts or inline messages
- Logging for debugging

### Example

```swift
func renameItem(_ item: FileSystemItem, newName: String) {
    Task {
        do {
            let newURL = try fileManagementService.renameItem(
                at: item.path,
                newName: newName
            )
            await refreshFolder()
        } catch {
            showError("Failed to rename: \(error.localizedDescription)")
        }
    }
}
```

## Performance Considerations

### 1. Lazy Loading

- Folder contents loaded on-demand
- Document content loaded when selected
- Search results paginated

### 2. Caching

- Folder expansion state cached
- Document scroll positions cached
- Search index maintained in memory

### 3. Debouncing

- File system watcher debounced (500ms)
- Search queries debounced (300ms)
- UserDefaults saves debounced (100ms)

### 4. View Optimization

- `LazyVStack`/`LazyHStack` for long lists
- Recursive tree rendering with identity
- Minimal state in child views

## Module Organization

### App Module

- `BetterDocsApp.swift`: Entry point
- `AppState.swift`: Global state
- `ContentView.swift`: Root view
- `SettingsView.swift`: Preferences

### Models Module

Pure data structures:

- `Document.swift`
- `Folder.swift`
- `GitStatus.swift`
- `Annotation.swift`
- `Chat.swift`

### Services Module

Business logic:

- `FileManagementService.swift`
- `GitService.swift`
- `DocumentParser/`
- `Search/`
- `ClaudeIntegration/`

### Views Module

UI components organized by feature:

- `Navigation/`: File browser
- `Preview/`: Document viewers
- `Toolbar/`: Top toolbar
- `Dialogs/`: Modals and sheets
- `Git/`: Git UI components
- `Help/`: Help overlay

## Security

### Sandboxing

The app uses macOS sandbox entitlements:

- User-selected file access
- Network access for git and Claude API
- No arbitrary file system access

### Input Validation

- File names sanitized
- Git commands use `Process` with arguments (not shell)
- URLs validated before opening

## Future Architecture Considerations

### Potential Improvements

1. **Document Database**: SQLite for faster search
2. **Plugin System**: Extension points for file types
3. **Sync**: iCloud or custom sync backend
4. **Multi-window**: Multiple document windows
5. **Collaborative**: Real-time collaboration features

### Scalability

Current architecture handles:

- Folders with thousands of files
- Multiple concurrent operations
- Large documents (tested to 10MB+)

For larger scale:

- Consider pagination for file lists
- Background indexing service
- Incremental search updates

---

**Last Updated**: 2025-11-20
