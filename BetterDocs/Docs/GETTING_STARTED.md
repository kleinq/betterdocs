# Getting Started with BetterDocs Development

## Prerequisites

- macOS 15.0 or later
- Xcode 16.0 or later
- Swift 6.0 or later
- Git

## Initial Setup

### 1. Clone the Repository

```bash
cd /Users/robertwinder/Projects/betterdocs
```

The repository is already initialized with the base structure.

### 2. Build the Project

You have two options for building:

#### Option A: Using Swift Package Manager (Recommended for development)

```bash
# Build the project
swift build

# Run the app
swift run BetterDocs
```

#### Option B: Generate Xcode Project

```bash
# Generate Xcode project
swift package generate-xcodeproj

# Open in Xcode
open BetterDocs.xcodeproj
```

Or use Xcode directly:
```bash
# Open Package.swift in Xcode
open Package.swift
```

### 3. Resolve Dependencies

Swift Package Manager will automatically fetch dependencies:
- swift-markdown (for Markdown parsing)

```bash
swift package resolve
```

### 4. First Run

Build and run the application:
- In Xcode: Press ⌘+R
- From terminal: `swift run BetterDocs`

## Project Structure Overview

```
BetterDocs/
├── Sources/
│   ├── App/                    # Application entry point
│   │   ├── BetterDocsApp.swift    # Main app
│   │   ├── AppState.swift         # Global app state
│   │   ├── ContentView.swift      # Main window layout
│   │   └── SettingsView.swift     # Settings UI
│   │
│   ├── Models/                 # Data models
│   │   ├── FileSystemItem.swift   # Protocol for files/folders
│   │   ├── Document.swift         # Document model
│   │   ├── Folder.swift          # Folder model
│   │   └── SearchResult.swift    # Search models
│   │
│   ├── Views/                  # UI components
│   │   ├── Toolbar/              # Ribbon toolbar
│   │   ├── Navigation/           # File browser
│   │   ├── Preview/              # Document preview
│   │   └── Sidebar/              # Claude chat
│   │
│   ├── Services/               # Business logic
│   │   ├── DocumentParser/       # Document parsing
│   │   ├── Search/               # Search & indexing
│   │   └── ClaudeIntegration/    # Claude API
│   │
│   └── Utilities/              # Helper functions
│
├── Resources/                  # Assets, localizations
├── Tests/                      # Unit & integration tests
└── Docs/                       # Documentation
```

## Key Components to Understand

### 1. AppState (App/AppState.swift)
The central state manager for the application. Holds:
- Current root folder
- Selected file/folder
- Search state
- Service instances

### 2. FileSystemItem Protocol (Models/FileSystemItem.swift)
Common interface for Documents and Folders, enabling unified handling.

### 3. Services Layer
- **DocumentService**: Scans folders, parses files, extracts content
- **SearchService**: Indexes documents, performs searches
- **ClaudeService**: Handles Claude API communication

### 4. Views
- **ToolbarView**: Top ribbon with actions and search
- **NavigationView**: Left sidebar file tree
- **PreviewView**: Center pane document preview
- **ClaudeSidebarView**: Right sidebar Claude chat

## Development Workflow

### Making Changes

1. Create a feature branch
```bash
git checkout -b feature/your-feature-name
```

2. Make your changes

3. Test your changes
```bash
swift test
```

4. Commit with descriptive message
```bash
git add .
git commit -m "Add feature: description"
```

### Testing

Run tests:
```bash
swift test
```

Run specific test:
```bash
swift test --filter BetterDocsTests.ServiceTests
```

### Debugging

- Use Xcode debugger with breakpoints
- Print statements for quick debugging
- Check Console.app for system logs

## Common Tasks

### Adding a New Document Type

1. Update `DocumentType` enum in `Models/Document.swift`
2. Add icon in `DocumentType.icon`
3. Implement parsing in `DocumentService.extractContent()`
4. Add preview in `Views/Preview/PreviewView.swift`

### Adding a New Service

1. Create new file in `Sources/Services/YourService/`
2. Use `actor` for thread-safe service
3. Register in `AppState.swift`
4. Write unit tests in `Tests/`

### Adding UI Components

1. Create SwiftUI view in appropriate `Views/` subdirectory
2. Use `@EnvironmentObject` for AppState access
3. Follow existing component structure
4. Add to relevant parent view

## Configuration

### API Keys

Store Claude API key in Settings:
1. Run the app
2. Open Settings (⌘+,)
3. Navigate to "Claude" tab
4. Enter your API key

For development, you can also set it programmatically in `AppState`.

### User Defaults Keys

```swift
// Used in the app
@AppStorage("claudeAPIKey") private var claudeAPIKey: String
@AppStorage("maxSearchResults") private var maxSearchResults: Int
@AppStorage("enableFilePreview") private var enableFilePreview: Bool
```

## Troubleshooting

### Build Errors

**Issue**: Swift package dependency resolution fails
```bash
# Clear package cache
rm -rf .build
swift package clean
swift package resolve
```

**Issue**: Xcode not finding modules
- Clean build folder: ⌘+Shift+K
- Close and reopen Xcode
- Delete derived data

### Runtime Issues

**Issue**: App crashes on launch
- Check Console.app for crash logs
- Verify macOS version is 15.0+
- Check file permissions

**Issue**: Folder selection not working
- App needs file system permissions
- Check System Settings > Privacy & Security > Files and Folders

**Issue**: Claude integration not working
- Verify API key is set in Settings
- Check internet connection
- Review API quota/limits

## Next Steps

### For New Developers

1. **Explore the codebase**
   - Read through ARCHITECTURE.md
   - Review model definitions
   - Understand service layer

2. **Run the app**
   - Build and launch
   - Try opening a folder
   - Test file preview
   - Try Claude chat (with API key)

3. **Pick a starter task**
   - Fix a TODO comment
   - Add a file type icon
   - Improve error handling
   - Write a unit test

### Recommended First Contributions

- [ ] Add more file type icons in `DocumentType`
- [ ] Implement syntax highlighting for code preview
- [ ] Add keyboard shortcuts
- [ ] Improve error messages
- [ ] Write tests for SearchService
- [ ] Add loading indicators
- [ ] Implement drag & drop

## Resources

### Documentation
- [ARCHITECTURE.md](ARCHITECTURE.md) - System architecture
- [ROADMAP.md](ROADMAP.md) - Development roadmap
- [CLAUDE_INTEGRATION.md](CLAUDE_INTEGRATION.md) - Claude features

### Apple Documentation
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui/)
- [Swift Concurrency](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)
- [PDFKit](https://developer.apple.com/documentation/pdfkit)

### External Resources
- [Swift Markdown](https://github.com/apple/swift-markdown)
- [Claude API Docs](https://docs.anthropic.com/)

## Getting Help

- Check existing documentation first
- Search GitHub issues
- Ask in discussions
- Review code comments and TODO items

## Code Style

- Use Swift 6.0 features
- Prefer `actor` for services (thread safety)
- Use `async/await` for asynchronous operations
- Follow SwiftUI best practices
- Add comments for complex logic
- Keep functions focused and small
- Use meaningful variable names

## Example: Adding a New Feature

Here's how to add a "Recently Opened" list:

1. **Update Model**
```swift
// In AppState.swift
@Published var recentFolders: [URL] = []

func addRecentFolder(_ url: URL) {
    recentFolders.insert(url, at: 0)
    if recentFolders.count > 10 {
        recentFolders.removeLast()
    }
}
```

2. **Update UI**
```swift
// In ToolbarView.swift
Menu("Recent") {
    ForEach(appState.recentFolders, id: \.self) { url in
        Button(url.lastPathComponent) {
            Task {
                await appState.loadFolder(at: url)
            }
        }
    }
}
```

3. **Persist Data**
```swift
// Save to UserDefaults
UserDefaults.standard.set(
    recentFolders.map { $0.path },
    forKey: "recentFolders"
)
```

4. **Test**
- Open multiple folders
- Verify recent list updates
- Test persistence across launches

Happy coding! 🚀
