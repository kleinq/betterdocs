# BetterDocs Documentation

Welcome to the BetterDocs technical documentation. This documentation provides a comprehensive guide to the architecture, components, and features of the BetterDocs application.

## What is BetterDocs?

BetterDocs is a native macOS documentation management application built with Swift and SwiftUI. It provides a powerful, modern interface for viewing, editing, and organizing documentation files with integrated AI assistance powered by Claude.

## Key Features

- **Multi-format Support**: View and edit Markdown, HTML, PDF, images, code files, and more
- **Git Integration**: Built-in git status tracking, commit, push, and pull operations
- **AI-Powered Chat**: Integrated Claude AI for document assistance and Q&A
- **Smart Search**: Fast full-text search across all documents
- **Annotations**: Add context-aware annotations to any document
- **Live Preview**: Real-time preview with support for markdown rendering
- **Tab Management**: Multiple document tabs with preview and pinned modes
- **File Operations**: Create, rename, delete, and organize files directly in the app

## Technology Stack

- **Language**: Swift 6.0 with strict concurrency
- **UI Framework**: SwiftUI 6 (declarative UI)
- **Platform**: macOS 15+ (Sequoia)
- **Markdown**: Apple's Swift Markdown parser
- **WebView**: WKWebKit for HTML and markdown rendering
- **Git**: Shell command integration via Process
- **AI**: Claude API integration

## Documentation Sections

1. [**Architecture**](ARCHITECTURE.md) - Overall app structure, frameworks, and design patterns
2. [**Components**](COMPONENTS.md) - Detailed view hierarchy and UI components
3. [**Services**](SERVICES.md) - Business logic services and their responsibilities
4. [**Models**](MODELS.md) - Data models and state management
5. [**File Operations**](FILE_OPERATIONS.md) - File handling, supported types, and I/O
6. [**Git Integration**](GIT_INTEGRATION.md) - Git features, workflows, and implementation

## Getting Started

### Building the Project

1. Open `BetterDocs.xcodeproj` in Xcode 15+
2. Select the BetterDocs scheme
3. Build and run (⌘R)

### Project Structure

```
BetterDocs/
├── Sources/
│   ├── App/              # Entry point & configuration
│   ├── Models/           # Data models
│   ├── Services/         # Business logic
│   ├── Views/            # UI components
│   └── Utils/            # Helper functions
├── Resources/            # Assets & Node.js SDK
└── docs/                 # This documentation
```

## Quick Reference

### Keyboard Shortcuts

- `⌘O` - Open folder
- `⌘F` - Search
- `⌘/` - Toggle chat
- `⌘K` - Command palette
- `⌘?` - Help
- `⌘R` - Reveal in tree
- `⌘W` - Close tab
- `⌘S` - Save file
- `Ctrl+O` - Toggle view mode
- `⌘⇧C` - Git commit
- `⌘⇧P` - Git push

### File Support

- **Text**: .md, .txt, .html
- **Code**: .swift, .py, .js, .java, .cpp, .rs, .go
- **Documents**: .pdf, .doc, .docx, .ppt, .pptx, .xls, .xlsx
- **Images**: .jpg, .png, .gif, .heic, .webp
- **Data**: .csv

## Contributing

When contributing to BetterDocs, please:

1. Follow Swift API design guidelines
2. Use SwiftUI best practices
3. Maintain strict concurrency compliance
4. Add documentation for new features
5. Test on macOS 15+

## Support

For issues or questions:
- Review this documentation
- Check the inline code comments
- Examine the SwiftUI preview implementations

---

**Last Updated**: 2025-11-20
**Version**: 1.0
**Target Platform**: macOS 15+
