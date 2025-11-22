# **Prompt: Build BetterDocs - An AI-Powered macOS Document Management System**

## **Project Overview**

Create a production-ready, native macOS desktop application called "BetterDocs" - a next-generation document management system with AI integration, built specifically for macOS 15 Sequoia and later. This is a professional-grade application designed for knowledge workers, developers, writers, and researchers who demand speed, intelligence, and elegance from their document management tools.

---

## **Technology Stack Requirements**

### **Core Technologies**
- **Language**: Swift 6.0 with strict concurrency checking enabled
- **UI Framework**: SwiftUI 6 (primary) with AppKit hybrid for advanced features
- **Platform**: macOS 15.0+ (Sequoia) native application
- **Build System**: Xcode 16.0+ with Swift Package Manager
- **State Management**: Observation framework (@Observable macro)
- **Concurrency**: Swift Concurrency (async/await, actors, structured concurrency)

### **Apple Frameworks**
- UniformTypeIdentifiers (modern file type detection)
- PDFKit (PDF rendering and text extraction)
- QuickLook (system-native file previews)
- OSLog (privacy-preserving structured logging)
- Swift Markdown (Apple's official markdown parsing library)
- WebKit (WKWebView for HTML/Markdown rendering)
- AppKit (NSOpenPanel, NSEvent monitoring, advanced features)

### **Dependencies**
- `@anthropic-ai/claude-agent-sdk` (v0.1.37) for Claude Code integration
- Minimal dependencies philosophy - prefer native Apple frameworks

### **Architecture Patterns**
1. **MVVM** (Model-View-ViewModel)
2. **Clean Architecture** (layered approach)
3. **Service Layer Pattern** (business logic isolation)
4. **Protocol-Oriented Design** (polymorphic file system)
5. **Observable State Pattern** (centralized AppState)
6. **Actor-Based Concurrency** (thread safety with Swift 6)

---

## **Complete Feature Set**

### **1. Document Management**

**Multi-Format Support:**
- Markdown (.md, .markdown) - rendered HTML with syntax highlighting
- HTML (.html, .htm) - full rendering with JavaScript
- PDF (.pdf) - native PDFKit viewer with controls
- Microsoft Office - Word (.doc, .docx), PowerPoint (.ppt, .pptx), Excel (.xls, .xlsx)
- CSV (.csv) - table view
- Images - JPEG, PNG, GIF, HEIC, WebP with scaling
- Code Files - Swift, Python, JavaScript, TypeScript, Java, C/C++, Rust, Go with syntax highlighting
- Plain Text (.txt)

**File Operations:**
- Create new files (Markdown, text) with templates
- Rename files/folders with validation (no invalid characters, duplicate names)
- Delete files (move to Trash, not permanent deletion)
- Move files via drag & drop (planned)
- Copy files (planned)
- Reveal in Finder
- AI-powered rename suggestions using Claude

### **2. Advanced Search System**

Implement three search modes:
1. **Full-Text Search** - Search within file contents using inverted index (TF-IDF)
2. **Fuzzy Search** - Intelligent matching with relevance scoring
3. **Filename Search** - Quick file name matching

**Search Features:**
- Real-time indexing with debouncing (300ms)
- TF-IDF based relevance ranking
- Context preview in search results (show surrounding text)
- Recent files accessible with Cmd+1-9 shortcuts
- Search result highlighting
- Async indexing without blocking UI

### **3. Rich Preview System**

**View Modes:**
- **List View** - Traditional hierarchical tree with expand/collapse
- **Grid View** - Pinterest-style visual browsing with thumbnails (lazy loading)
- **Preview Pane** - Central content display area with tabs
- **Tab System** - Multiple documents open simultaneously

**Preview Features:**
- Markdown rendering with marked.js library
- Code syntax highlighting with highlight.js
- PDF viewing with native PDFKit controls
- Image viewing with scaling and pan
- HTML rendering with WebKit (JavaScript enabled)
- Document outline navigation (automatically extract headings)
- Scroll position persistence per tab
- Edit mode for text-based files with auto-save (debounced 500ms)

**Tab Management:**
- Ephemeral preview tab (single-click opens in preview)
- Pinned tabs (double-click or Enter to pin)
- Tab bar with horizontal scrolling
- Active tab highlighting with accent color
- Close tabs with Cmd+W
- Navigate tabs with Cmd+Shift+]/[
- Show file path in tab tooltip

### **4. Claude AI Integration**

**Chat Interface:**
- **Floating Chat Drawer** - slides up from bottom (toggle with `/` key)
- Resizable height (300-800px with drag handle)
- Glassmorphism design (macOS Sequoia .ultraThinMaterial)
- Context-aware conversations (automatically pass current document)
- Message history persistence (JSON storage)
- Multiple chat sessions support

**AI Capabilities:**
- Document context passing (send currently selected file content)
- Chat with Claude about documents
- Document summarization
- Multi-document analysis
- Annotation-based batch processing
- Tool usage tracking and display

**Chat Features:**
- Markdown rendering in AI responses
- Typing indicators during response generation
- Auto-dismiss on Escape or clicking outside
- Context indicator showing current document name
- Persistent chat history across sessions
- Copy messages to clipboard

### **5. Annotation System**

**Core Features:**
- Mark up documents with instructions for AI processing
- Tagged annotations with types: Edit, Expand, Verify, Slides
- Selected text preservation (highlight in document)
- Batch processing across multiple files
- Generate comprehensive Claude prompts from annotations
- Persistent storage in `.annotations` sidecar files (JSON)

**Annotation Types:**
- **Edit** - Request specific changes
- **Expand** - Add more detail to sections
- **Verify** - Check consistency and accuracy
- **Slides** - Generate presentation content

**Workflow:**
1. Select text in document
2. Add annotation with type and instruction
3. View all annotations in right sidebar
4. Generate batch prompt with "Send to Claude" button
5. Review AI responses and apply changes

### **6. Git Integration**

**Git Operations:**
- Repository status detection (is folder a git repo?)
- Real-time branch tracking
- File change visualization (modified, staged, untracked)
- Commit with message (auto-attribution to Claude if AI-generated)
- Push to remote with `-u` flag for new branches
- Pull from remote
- Stage all changes (`git add .`)
- Git status display in toolbar

**Git UI Components:**
- **Status Indicator** in toolbar showing: branch name, # changes, ahead/behind
- **Git Panel** - floating overlay showing all changed files organized by status
- **Commit Dialog** - multi-line message entry with recent commit style analysis
- Visual file status indicators (green=new, orange=modified, blue=staged)
- Exponential backoff retry for network operations (2s, 4s, 8s, 16s delays)

**Git Requirements:**
- Execute git via Process (not shell) to prevent injection
- Parse git output correctly
- Handle authentication errors gracefully
- Validate commit messages (non-empty)

### **7. File System Watching**

- Real-time folder monitoring using FileManager DirectoryMonitor
- Detect external changes: file creation, modification, deletion, rename
- Debounced refresh (500ms) to batch rapid changes
- Auto-refresh file tree on external changes
- Update search index automatically when files change
- Handle race conditions properly

### **8. Keyboard-First Design**

Implement **comprehensive keyboard shortcuts**:

**File Operations:**
- Cmd+O - Open folder (NSOpenPanel)
- Cmd+R - Reveal selected file in folder tree
- Cmd+N - New file dialog

**Navigation:**
- ↑/↓ - Navigate files/folders in list
- ←/→ - Collapse/expand folders
- Space - Toggle folder expansion
- Enter - Open file in new pinned tab
- Backspace - Navigate to parent folder

**Search:**
- Cmd+F - Focus search field
- Cmd+K - Open command palette
- Esc - Clear search / close overlays
- Cmd+1-9 - Open recent files 1-9

**Tabs:**
- Cmd+W - Close active tab
- Cmd+Shift+] - Next tab
- Cmd+Shift+[ - Previous tab
- Cmd+T - New tab (planned)

**View:**
- Cmd+Shift+L - Toggle document outline sidebar
- Ctrl+O - Toggle grid/list view
- / - Toggle chat drawer
- Cmd+? - Show help overlay with all shortcuts

### **9. Command Palette**

Build a VS Code/Raycast-style quick launcher:

**Features:**
- Fuzzy search across all files in folder
- Recent files section (last 5 accessed)
- Quick actions: Settings, Refresh Folder, Toggle Outline, Open Chat
- Keyboard navigation (↑/↓, Enter to select, Escape to dismiss)
- Smart relevance scoring (prefer filename matches over content)
- Glassmorphism design with backdrop blur
- Instant responsiveness (< 50ms)

**Implementation:**
- Show with Cmd+K
- Filter as user types
- Display file icons based on type
- Show file path in results
- Highlight matching characters

### **10. Modern macOS UI Design**

**Design Language:**
- Glassmorphism effects (.ultraThinMaterial, .ultraThickMaterial)
- Smooth spring animations (0.2-0.3s duration, response: 0.35, dampingFraction: 0.9)
- Full dark mode support (dynamic colors)
- System accent color integration
- SF Symbols for all icons
- Hover states and visual feedback
- Context menus throughout

**Layout Architecture:**
```
┌────────────────────────────────────────────────┐
│  Toolbar (50px) - controls, git status, search │
├──────────┬─────────────────────────┬───────────┤
│  Nav     │   Preview Pane (Tabs)   │ Outline   │
│  Sidebar │   [Tab] [Tab] [Tab]     │ (Right)   │
│  (Left)  │                          │           │
│  - List  │   Document Content       │ - Headings│
│  - Grid  │   (Markdown/PDF/etc)     │ - Annot.  │
│          │                          │           │
│  200-400 │                          │  200-300  │
│  px      │                          │  px       │
│  resizable                          │  toggle   │
└──────────┴─────────────────────────┴───────────┘
│  Floating Chat Drawer (300-800px)              │
│  (slides up from bottom, toggle with /)        │
└────────────────────────────────────────────────┘
```

**UI Components:**
- Resizable sidebars with drag handles
- Collapsible panels
- Floating overlays (chat, command palette, help, git panel)
- Tab bar with horizontal scrolling
- Context menus with system styling
- Toast notifications for operations

---

## **Project Structure**

Organize code following this structure:

```
BetterDocs/
├── BetterDocs/
│   ├── Sources/
│   │   ├── App/
│   │   │   ├── BetterDocsApp.swift          # Entry point
│   │   │   ├── AppState.swift               # Observable state
│   │   │   └── ContentView.swift            # Root view
│   │   ├── Models/
│   │   │   ├── FileSystemItem.swift         # Protocol
│   │   │   ├── Document.swift               # File model
│   │   │   ├── Folder.swift                 # Directory model
│   │   │   ├── GitStatus.swift              # Git state
│   │   │   ├── Annotation.swift             # Annotation model
│   │   │   ├── Chat.swift                   # Chat/message models
│   │   │   └── SearchResult.swift           # Search result
│   │   ├── Views/
│   │   │   ├── Chat/                        # Chat UI
│   │   │   ├── CommandPalette/              # Cmd+K palette
│   │   │   ├── Dialogs/                     # Modal dialogs
│   │   │   ├── Git/                         # Git UI
│   │   │   ├── Help/                        # Help overlay
│   │   │   ├── Navigation/                  # File browser
│   │   │   ├── Preview/                     # Document viewers
│   │   │   ├── Sheets/                      # Sheet modals
│   │   │   ├── Sidebar/                     # Right sidebar
│   │   │   └── Toolbar/                     # Top toolbar
│   │   ├── Services/
│   │   │   ├── ClaudeService.swift          # AI integration
│   │   │   ├── DocumentService.swift        # Content parsing
│   │   │   ├── FileManagementService.swift  # File I/O
│   │   │   ├── FileSystemWatcher.swift      # FS monitoring
│   │   │   ├── GitService.swift             # Git operations
│   │   │   └── SearchService.swift          # Full-text search
│   │   └── Utils/
│   │       ├── FileIconProvider.swift       # SF Symbol icons
│   │       ├── FuzzySearch.swift            # Fuzzy matching
│   │       └── Extensions.swift             # Swift extensions
│   ├── Resources/
│   │   ├── AppIcon.icns
│   │   └── claude-agent-sdk/                # Node.js SDK
│   ├── Assets.xcassets/
│   ├── Docs/                                # Technical docs
│   └── BetterDocs.entitlements
├── docs/                                    # User docs
├── Package.swift                            # SPM config
├── BetterDocs.xcodeproj/                    # Xcode project
├── build_app.sh                             # Build script
├── run_app.sh                               # Run script
└── package_app.sh                           # DMG packaging
```

---

## **Implementation Details**

### **Models (Data Layer)**

**FileSystemItem Protocol:**
```swift
protocol FileSystemItem: Identifiable {
    var id: UUID { get }
    var name: String { get }
    var path: URL { get }
    var createdDate: Date { get }
    var modifiedDate: Date { get }
    var fileSize: Int64 { get }
}
```

**Document Model:**
- Properties: id, name, path, fileSize, createdDate, modifiedDate, fileType, icon
- Cached content (String?)
- Computed: fileExtension, isTextBased, isImage, isPDF, isMarkdown
- Methods: loadContent() async throws, saveContent() async throws

**Folder Model:**
- Properties: id, name, path, children (recursive [FileSystemItem])
- Methods: loadChildren() async, addChild(), removeChild()
- Computed: childCount, hasChildren

**GitStatus Model:**
- Properties: branch, modifiedFiles, stagedFiles, untrackedFiles, aheadCount, behindCount
- Computed: hasChanges, totalChanges

### **Services (Business Logic)**

**SearchService (Actor):**
- Inverted index using [String: Set<UUID>] (word → document IDs)
- TF-IDF scoring for relevance ranking
- Methods: indexDocument(), search(query: String) -> [SearchResult]
- Debounced indexing (300ms) to batch rapid updates
- Tokenization: lowercase, split on whitespace/punctuation, remove stopwords

**ClaudeService (Actor):**
- Integration with claude-agent-sdk via Process
- Methods: sendMessage(prompt: String, context: String?) async throws -> String
- Stream responses with async sequences
- Tool usage tracking
- Error handling for API failures, rate limits

**GitService (Actor):**
- Execute git commands via Process (never shell)
- Methods: status(), commit(message:), push(), pull(), stageAll()
- Parse git output correctly (branch from status, file lists from diff)
- Retry logic: exponential backoff for push/pull (2s, 4s, 8s, 16s)
- Validate repo existence before operations

**FileManagementService:**
- CRUD operations with FileManager
- Methods: createFile(), renameFile(), deleteFile(), moveFile()
- Validation: check filename validity, prevent overwrites, handle permissions
- Error handling: wrap FileManager errors in custom domain errors

**DocumentService:**
- Parse content based on UTType
- Extract metadata (word count, headings for markdown)
- Generate thumbnails for images
- Extract text from PDFs using PDFKit

**FileSystemWatcher:**
- Monitor folder changes with FileManager
- Debounced notifications (500ms)
- Methods: startWatching(url:), stopWatching()
- Delegate pattern for change callbacks

### **AppState (Central State)**

```swift
@Observable
final class AppState {
    // File System
    var rootFolder: Folder?
    var selectedDocument: Document?
    var openTabs: [Document] = []
    var activeTabId: UUID?

    // UI State
    var searchQuery: String = ""
    var showCommandPalette: Bool = false
    var showChatDrawer: Bool = false
    var showOutline: Bool = false
    var viewMode: ViewMode = .list  // .list or .grid

    // Git
    var gitStatus: GitStatus?

    // Services (injected)
    let fileService: FileManagementService
    let gitService: GitService
    let claudeService: ClaudeService
    let searchService: SearchService

    // Methods
    func openFolder(_ url: URL) async
    func selectDocument(_ doc: Document)
    func openInNewTab(_ doc: Document)
    func closeTab(_ id: UUID)
    func refreshFolder()
}
```

### **Concurrency Requirements**

- All file I/O must be async (don't block main thread)
- Use `@MainActor` for all UI updates
- Services should be actors for thread safety
- Use Task groups for parallel processing (e.g., indexing multiple files)
- Structured concurrency - no detached tasks unless necessary
- Enable Swift 6 strict concurrency checking

### **Performance Targets**

| Metric | Target |
|--------|--------|
| App Launch | < 1s (cold start) |
| Folder Scan (1000 files) | < 3s |
| Search Results | < 300ms |
| Preview Load | < 500ms |
| Grid View Scroll | 60 FPS |
| Memory Usage | < 300MB |
| CPU Usage (idle) | < 5% |

**Optimizations:**
- Lazy loading in grid view (only render visible cells)
- Content caching for documents
- Async image loading with AsyncImage
- Debounced search and file watching
- Efficient SwiftUI view updates (avoid unnecessary re-renders)

### **Security & Entitlements**

**Entitlements (BetterDocs.entitlements):**
```xml
com.apple.security.app-sandbox = true
com.apple.security.files.user-selected.read-write = true
com.apple.security.files.bookmarks.app-scope = true
com.apple.security.network.client = true
```

**Security Practices:**
- Sandboxed app - user must explicitly select folders (NSOpenPanel)
- Secure API key storage in Keychain
- Input validation for all filenames and paths
- Safe git command execution (use Process with arguments, not shell)
- Privacy-preserving logging with OSLog
- No hardcoded credentials

### **Build & Deployment**

**Build Scripts:**

`build_app.sh`:
```bash
xcodebuild -project BetterDocs.xcodeproj \
           -scheme BetterDocs \
           -configuration Release \
           -derivedDataPath ./build \
           build
```

`run_app.sh`:
```bash
./build_app.sh && \
open ./build/Build/Products/Release/BetterDocs.app
```

`package_app.sh`:
```bash
# Create DMG with signed app bundle
# Include app icon, background image, symlink to /Applications
```

**Distribution:**
- Code sign with Apple Developer certificate
- Notarize with Apple for Gatekeeper
- Create DMG installer
- Target: Mac App Store and direct distribution

---

## **Code Quality Expectations**

### **Swift Style**
- Follow Swift API Design Guidelines
- Use meaningful names (no abbreviations except common ones like `id`, `url`)
- Prefer value types (struct) over reference types (class) unless needed
- Use `guard` for early returns
- Avoid force unwrapping (`!`) - use `if let` or `guard let`
- Document public APIs with `///` comments

### **SwiftUI Best Practices**
- Extract reusable components into separate views
- Use view modifiers for styling (create custom modifiers for repeated styles)
- Avoid massive views - break into smaller components
- Use `@Environment` for dependency injection
- Prefer `@Observable` over `@StateObject` (modern approach)

### **Error Handling**
- Define custom error enums conforming to Error
- Propagate errors with `throws` - don't silently catch
- Show user-friendly error messages in alerts
- Log errors with OSLog for debugging

### **Testing (Future)**
- Unit tests for services and business logic
- UI tests for critical workflows
- Test coverage goal: > 70%

### **Documentation**
Create comprehensive documentation:
1. **README.md** - Quick start, features overview
2. **ARCHITECTURE.md** - Technical design, patterns
3. **FEATURES.md** - Complete feature documentation
4. **BUILD.md** - Build instructions, requirements
5. **CONTRIBUTING.md** - Development guidelines
6. **API.md** - Service layer documentation
7. **USER_GUIDE.md** - End-user manual

---

## **Additional Requirements**

### **Accessibility**
- Full keyboard navigation support
- VoiceOver support for all UI elements
- High contrast mode support
- Respect system accessibility settings

### **Localization (Future)**
- Use NSLocalizedString for all user-facing text
- Support for multiple languages (start with English)

### **Analytics (Privacy-First)**
- Crash reporting (opt-in)
- Anonymous usage statistics (opt-in)
- No user data collection without consent

### **Updates**
- Check for updates at launch (optional)
- Sparkle framework for auto-updates (future)

---

## **Success Criteria**

This project is complete when:

1. ✅ App launches successfully on macOS 15+
2. ✅ User can select folder and browse files in list/grid views
3. ✅ All file formats preview correctly (Markdown, PDF, images, code, HTML)
4. ✅ Full-text search returns relevant results in < 300ms
5. ✅ Command palette (Cmd+K) works with fuzzy matching
6. ✅ Git integration shows status and allows commit/push
7. ✅ Chat drawer opens with `/` and integrates with Claude
8. ✅ All keyboard shortcuts work as specified
9. ✅ Annotations can be added and sent to Claude
10. ✅ Tab management works (open, close, switch between tabs)
11. ✅ File operations work (create, rename, delete, reveal)
12. ✅ App performs well with 1000+ files in folder
13. ✅ UI follows macOS design language (glassmorphism, animations)
14. ✅ Comprehensive documentation exists
15. ✅ App can be built and packaged as DMG

---

## **Final Notes**

This is a **professional, production-ready application** built with cutting-edge 2024-2025 Apple technologies. The app should feel native, fast, and polished - something users would pay for on the Mac App Store.

Focus on:
- **Performance** - Use Swift 6 concurrency properly, optimize rendering
- **Polish** - Smooth animations, thoughtful UX, attention to detail
- **Reliability** - Proper error handling, data persistence, crash prevention
- **Maintainability** - Clean architecture, documented code, testable design

Build this as if shipping to 10,000+ users. Quality over speed.

---

**Total Scope:** 40+ Swift files, 8+ services, 12 view directories, comprehensive documentation, build scripts, and deployment pipeline. This is a complete, feature-rich application requiring approximately 8,000-10,000 lines of Swift code.
