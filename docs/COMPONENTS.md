# Components

This document details the UI components and view hierarchy in BetterDocs.

## View Hierarchy

```
BetterDocsApp
└── WindowGroup
    └── ContentView
        ├── ToolbarView
        ├── NavigationView
        │   ├── FileTreeItemView (recursive)
        │   ├── GridView
        │   └── SearchResultRow
        ├── PreviewView
        │   ├── TabBarView
        │   ├── PreviewHeaderView
        │   ├── DocumentPreviewView
        │   │   ├── MarkdownPreview → MarkdownWebView
        │   │   ├── HTMLPreview → HTMLWebView
        │   │   ├── TextPreview
        │   │   ├── PDFPreview
        │   │   ├── ImagePreview
        │   │   └── CSVPreview
        │   └── FolderPreviewView
        ├── CommandPaletteView
        ├── ChatPopupView
        ├── ChatListView
        ├── GitFileListView
        └── HelpView
```

## Core Components

### ContentView

**Location**: `Sources/App/ContentView.swift`

The root view that manages the main layout:

```swift
struct ContentView: View {
    - Toolbar (50px height)
    - Main content area
      - NavigationView (resizable sidebar)
      - ResizableDivider
      - PreviewView (main pane)
    - Overlays (command palette, chat, help)
}
```

**Features**:
- Keyboard event monitoring (Cmd+K, Cmd+/, Cmd+?)
- Resizable navigation sidebar
- Debounced UserDefaults persistence

### ResizableDivider

**Location**: `Sources/App/ContentView.swift:153`

A draggable divider for resizing panes:

```swift
struct ResizableDivider: View {
    @Binding var width: CGFloat
    let minWidth: CGFloat
    let maxWidth: CGFloat
    let isRightSidebar: Bool
}
```

**Features**:
- Hover cursor change
- Drag gesture handling
- Optimized updates (debounced to every 2px)
- Visual feedback on hover/drag

---

## Navigation Components

### NavigationView

**Location**: `Sources/Views/Navigation/NavigationView.swift`

The file browser sidebar:

**Features**:
- Tree view with expandable folders
- Grid view alternative
- Search results display
- Keyboard navigation (arrows, space, enter)
- Drag & drop support
- Persistent folder expansion state

**State Management**:
```swift
@State private var selectedID: UUID?
@State private var expandedFolders: Set<UUID>
```

### FileTreeItemView

**Location**: `Sources/Views/Navigation/NavigationView.swift:500`

Recursive component for rendering the file tree:

```swift
struct FileTreeItemView: View {
    let item: any FileSystemItem
    let level: Int  // Indentation depth
    @Binding var selectedID: UUID?
    @Binding var expandedFolders: Set<UUID>
}
```

**Features**:
- Recursive rendering of folder children
- Context menu (rename, delete, reveal)
- Disclosure triangle for folders
- Hover state
- Drag source & drop target
- Type badge for files

**Layout**:
```
[Indent] [Triangle] [Icon] [Name] [Spacer] [Badge]
```

### GridView

**Location**: `Sources/Views/Navigation/GridView.swift`

Alternative grid layout for files:

**Features**:
- LazyVGrid with adaptive columns
- Thumbnail previews
- Context menus
- Click to preview, double-click to open

---

## Preview Components

### PreviewView

**Location**: `Sources/Views/Preview/PreviewView.swift`

Main content preview area:

**Components**:
1. **TabBarView**: Horizontal scrolling tab bar
2. **PreviewHeaderView**: File info and controls
3. **DocumentPreviewView**: Format-specific preview
4. **FolderPreviewView**: Folder statistics

**State**:
- Annotation dialog handling
- Tab synchronization

### TabBarView

**Location**: `Sources/Views/Preview/PreviewView.swift:111`

Manages document tabs:

```swift
struct TabBarView: View {
    - Preview tab (ephemeral, italic)
    - Pinned tabs (closeable with X button)
}
```

**Features**:
- Horizontal scrolling
- Active tab highlighting
- Tab close buttons
- Click to activate, X to close

### DocumentPreviewView

**Location**: `Sources/Views/Preview/PreviewView.swift:277`

Routes to format-specific preview:

```swift
switch document.type {
case .markdown: MarkdownPreview
case .html: HTMLPreview
case .text, .code: TextPreview
case .pdf: PDFPreview
case .image: ImagePreview
case .csv: CSVPreview
default: GenericPreview
}
```

**Edit Mode**:
- Switches to `TextEditorView` for editable types
- Markdown, HTML, text, and code files

### MarkdownPreview

**Location**: `Sources/Views/Preview/PreviewView.swift:413`

Async markdown loader:

```swift
struct MarkdownPreview: View {
    @State private var content: String?
    @State private var isLoading = false

    // Loads from file on document.modified change
    .task(id: document.modified) {
        await loadContent()
    }
}
```

**Renders with**: `MarkdownWebView`

### MarkdownWebView

**Location**: `Sources/Views/Preview/MarkdownWebView.swift`

WKWebView wrapper with markdown rendering:

```swift
struct MarkdownWebView: NSViewRepresentable {
    let markdown: String
    let tabID: UUID
}
```

**Features**:
- marked.js for markdown → HTML
- Custom CSS (light/dark mode)
- Syntax highlighting
- Link handling (opens in browser)
- Scroll position persistence
- Text selection for annotations
- In-page search (Cmd+F)
- Heading extraction for outline

**HTML Generation**:
1. Inject marked.js from CDN
2. Apply custom CSS
3. Convert markdown to HTML
4. Add scroll tracking JavaScript
5. Set up annotation handlers

### HTMLPreview

**Location**: `Sources/Views/Preview/PreviewView.swift:460`

Displays standalone HTML files:

```swift
struct HTMLPreview: View {
    let document: Document
    // Uses HTMLWebView for rendering
}
```

**Renders with**: `HTMLWebView`

### HTMLWebView

**Location**: `Sources/Views/Preview/HTMLWebView.swift`

WKWebView for HTML files:

**Features**:
- Loads HTML from file URL
- Allows relative resource links
- Opens external links in browser
- Scroll position tracking
- Back/forward navigation

### TextPreview

**Location**: `Sources/Views/Preview/PreviewView.swift:485`

Plain text and code viewer:

**Features**:
- Monospaced font
- Scrollable text view
- Syntax-aware (code type in badge)
- Read-only in preview mode

### PDFPreview

**Location**: `Sources/Views/Preview/PreviewView.swift:509`

PDF document viewer using PDFKit:

```swift
struct PDFPreview: NSViewRepresentable {
    // Wraps PDFView from PDFKit
}
```

**Features**:
- Native PDF rendering
- Zoom controls
- Page navigation
- Thumbnail sidebar

### ImagePreview

**Location**: `Sources/Views/Preview/PreviewView.swift:533`

Image viewer:

**Features**:
- SwiftUI `Image` with scaling
- Async loading
- Supports: jpg, png, gif, heic, webp

---

## Toolbar Components

### ToolbarView

**Location**: `Sources/Views/Toolbar/ToolbarView.swift`

Top toolbar with controls:

**Sections**:
1. **File Operations**: Open, New File, Refresh
2. **View Controls**: Reveal, Grid/List toggle
3. **Git Operations**: Status, Commit, Push, Pull
4. **Settings**: Gear icon

**Git Status Indicator**:
```
[Branch Icon] [Branch Name] [Changes Dot] [↑ Ahead] [↓ Behind]
```

- Clickable to show `GitFileListView`

---

## Overlay Components

### CommandPaletteView

**Location**: `Sources/Views/CommandPalette/CommandPaletteView.swift`

Quick command launcher (Cmd+K):

**Features**:
- Fuzzy search
- Keyboard navigation
- Recent commands
- Action execution

### ChatPopupView

**Location**: `Sources/Views/Chat/ChatPopupView.swift`

Floating chat interface (Cmd+/):

**Features**:
- Claude AI integration
- Message history
- Context-aware responses
- Markdown rendering in responses

### ChatListView

**Location**: `Sources/Views/Chat/ChatListView.swift`

Chat history sidebar:

**Features**:
- List of past chats
- Create new chat
- Switch between chats
- Delete chats

### GitFileListView

**Location**: `Sources/Views/Git/GitFileListView.swift`

Git status panel:

**Sections**:
1. **Staged Changes** (green)
2. **Modified Files** (orange)
3. **Untracked Files** (blue)
4. **Remote Status** (ahead/behind)

**Features**:
- Click files to open
- File path display
- Status indicators
- Empty state for clean working directory

### HelpView

**Location**: `Sources/Views/Help/HelpView.swift`

Keyboard shortcut reference (Cmd+?):

**Sections**:
- Navigation shortcuts
- Search & commands
- Document viewing
- Tips & tricks

**Design**:
- Semi-transparent backdrop
- Centered panel
- Scrollable content
- ESC to close

---

## Dialog Components

### GitCommitDialog

**Location**: `Sources/Views/Dialogs/GitCommitDialog.swift`

Commit message entry:

**Features**:
- Multi-line text editor
- Commit button
- Cancel button
- File count display

### RenameSheet

**Location**: `Sources/Views/Dialogs/RenameSheet.swift`

File/folder rename dialog:

**Features**:
- Current name display
- New name input
- Extension preservation
- Validation (invalid characters)
- Error messages

### AnnotationDialog

**Location**: `Sources/Views/Dialogs/AnnotationDialog.swift`

Add annotation to selected text:

**Features**:
- Selected text preview
- Note input field
- Tag selection
- Save/cancel buttons

### FileCreationSheet

**Location**: `Sources/Views/Dialogs/FileCreationSheet.swift`

Create new file:

**Features**:
- File type selection (Markdown/Text)
- File name input
- Template selection (optional)
- Folder context

---

## Specialized Components

### FloatingDocumentOutlineView

**Location**: `Sources/Views/Preview/FloatingDocumentOutlineView.swift`

Floating table of contents:

**Features**:
- Extracted headings from markdown
- Click to scroll to section
- Collapsible
- Draggable positioning

### TextEditorView

**Location**: `Sources/Views/Preview/TextEditorView.swift`

Text editing interface:

**Features**:
- SwiftUI TextEditor
- Auto-save (2 second debounce)
- Manual save (Cmd+S)
- Word/character count
- Unsaved indicator

### SearchResultRow

**Location**: `Sources/Views/Navigation/NavigationView.swift:724`

Search result item:

**Features**:
- File icon and name
- Match context preview
- File type badge
- Click to preview

---

## Component Design Principles

### 1. Single Responsibility

Each component has one clear purpose:
- `ToolbarView` → toolbar controls
- `NavigationView` → file browsing
- `PreviewView` → content display

### 2. Composition Over Inheritance

Complex views built from smaller components:
```swift
PreviewView
  ├─ TabBarView
  └─ DocumentPreviewView
       └─ MarkdownPreview
            └─ MarkdownWebView
```

### 3. State Ownership

- Local state for UI-only concerns (`@State`)
- Shared state via `@Environment(AppState.self)`
- Bindings for parent-child communication

### 4. Reusability

Components designed for reuse:
- `ResizableDivider` (can resize any pane)
- `GitFileSection` (reused for staged/modified/untracked)
- `FileTreeItemView` (recursive for any depth)

---

**Last Updated**: 2025-11-20
