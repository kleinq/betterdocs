# BetterDocs

A modern document management system for macOS 15+ with integrated Claude Code agent capabilities.

## Features

- **Multi-format Support**: Markdown, PDF, DOC/DOCX, PPT/PPTX, CSV, and folders
- **Advanced Search**: Search by filename and file content
- **Rich Preview**: Native document preview for all supported formats
- **Claude Code Integration**: Execute Claude Code agent functions within document scope
- **Native macOS Experience**: Built with SwiftUI for macOS 15+
- **Comprehensive Keyboard Navigation**: Full keyboard support for efficient navigation

## Keyboard Shortcuts

### File Operations
- `⌘O` - Open folder
- `⌘R` - Reveal selected item in folder tree

### Navigation
- `↑ / ↓` - Navigate up/down through files and folders
- `← / →` - Collapse/expand folders (or navigate to parent)
- `Space` - Toggle folder expand/collapse
- `Enter` - Open selected file in new tab

### Search
- `⌘F` - Focus search bar
- `Esc` - Clear search and unfocus search bar
- `↑ / ↓` - Navigate through search results (when searching)
- `Enter` - Open selected search result

### Tabs
- `⌘W` - Close active tab
- `⌘⇧]` - Next tab
- `⌘⇧[` - Previous tab

### View
- `⌘⇧L` - Toggle document outline

## Architecture

### User Interface
- **Ribbon Toolbar**: Quick access to common actions
- **Navigation View**: File and folder browser with keyboard navigation
- **Preview Pane**: Central content preview area
- **Claude Sidebar**: Integrated chat interface for Claude Code agent

### Core Components
- Document parsing and indexing
- Full-text search engine
- Claude Code SDK integration
- Multi-format preview rendering

## Project Structure

```
BetterDocs/
├── Sources/
│   ├── App/              # App entry point and configuration
│   ├── Views/            # SwiftUI views
│   │   ├── Toolbar/      # Ribbon toolbar components
│   │   ├── Navigation/   # File browser and navigation
│   │   ├── Preview/      # Document preview components
│   │   └── Sidebar/      # Claude Code chat sidebar
│   ├── Models/           # Data models
│   ├── Services/         # Business logic
│   │   ├── DocumentParser/   # Document parsing engines
│   │   ├── Search/           # Search and indexing
│   │   └── ClaudeIntegration/ # Claude Code SDK integration
│   └── Utilities/        # Helper functions and extensions
├── Resources/            # Assets, localizations
├── Tests/               # Unit and integration tests
└── Docs/                # Additional documentation
```

## Technology Stack (2024-2025)

### Core Technologies
- **Swift 6.0** - Data race safety with strict concurrency
- **SwiftUI 6** - Modern declarative UI (primary)
- **AppKit** - Advanced features (hybrid approach)
- **SwiftData** - Native Swift persistence
- **Observation** - Reactive state (30-50% faster than Combine)
- **Swift Concurrency** - Actors + async/await

### Modern Apple Frameworks
- **App Intents** - Siri, Shortcuts, Spotlight integration
- **TipKit** - User onboarding and feature discovery
- **PDFKit** - PDF rendering and text extraction
- **QuickLook** - System-native file previews
- **UniformTypeIdentifiers** - Modern file type detection
- **OSLog** - Privacy-preserving logging

### Optional Enhancements
- **Swift Charts** - Data visualization (if adding analytics)
- **WidgetKit** - Desktop widgets (future phase)
- **Swift Testing** - Modern test framework

### Future Technologies
- **Apple Intelligence** - Foundation Models API (2025)
- **Enhanced App Intents** - Deeper system integration

See comprehensive framework analysis:
- 📊 [Complete Framework Analysis](BetterDocs/Docs/COMPLETE_FRAMEWORK_ANALYSIS_2025.md)
- 💻 [Tech Stack Details](BetterDocs/Docs/TECH_STACK_2025.md)
- 🔄 [Observation Migration](BetterDocs/Docs/MIGRATION_TO_OBSERVATION.md)

## Requirements

- macOS 15.0+ (Sequoia)
- Xcode 16.0+
- Swift 6.0+
- 16GB RAM (recommended for Xcode predictive completion)

## Getting Started

### Running the App

**Option 1: Use Xcode (Recommended)**

```bash
# Open the Xcode project
open BetterDocs.xcodeproj

# Then press ⌘+R in Xcode to build and run
```

**Option 2: Command Line Script**

```bash
# Build and launch the app
./run_app.sh
```

**Option 3: Manual Build**

```bash
# Build with xcodebuild
xcodebuild -project BetterDocs.xcodeproj \
           -scheme BetterDocs \
           -configuration Debug \
           -destination 'platform=macOS' \
           build

# Find and open the built app
open ~/Library/Developer/Xcode/DerivedData/BetterDocs*/Build/Products/Debug/BetterDocs.app
```

**Note:** This project uses an Xcode project (`.xcodeproj`) to build proper macOS app bundles. The `Package.swift` is kept for dependency management but cannot build GUI apps with windows.

## Documentation

- 📚 [Architecture Guide](BetterDocs/Docs/ARCHITECTURE.md)
- 🚀 [Getting Started](BetterDocs/Docs/GETTING_STARTED.md)
- 🗺️ [Development Roadmap](BetterDocs/Docs/ROADMAP.md)
- 🤖 [Claude Integration Plan](BetterDocs/Docs/CLAUDE_INTEGRATION.md)
- 💻 [Tech Stack 2025](BetterDocs/Docs/TECH_STACK_2025.md)
- 📊 [Project Summary](PROJECT_SUMMARY.md)

## Development Status

✅ **Foundation Complete** - Architecture, models, views, and services implemented
🚧 **Active Development** - Building core features and integrations

**Next Steps:**
1. Build and verify compilation
2. Implement document loading
3. Add file preview renderers
4. Integrate search functionality
5. Complete Claude API integration

## License

TBD
