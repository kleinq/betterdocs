# BetterDocs: AI-Powered Document Management for the Modern Era

## What is BetterDocs?

**BetterDocs** is a next-generation document management system for macOS that combines the best of traditional file management with cutting-edge AI assistance. Think of it as the love child of Finder, VS Code, and Claude AI—designed for knowledge workers who demand speed, intelligence, and elegance.

---

## The Problem We Solve

Traditional document management is broken:
- **Fragmented workflows**: Jumping between Finder, Preview, editors, and AI tools wastes time
- **Manual everything**: Editing, renaming, organizing—all require tedious manual work
- **Poor discoverability**: Finding the right document means remembering exact names or locations
- **No intelligence**: Your file manager can't help you understand, edit, or improve your documents
- **Keyboard-hostile**: Mouse-driven interfaces slow down power users

**BetterDocs fixes all of this.**

---

## Key Features & Benefits

### 1. AI-First Document Workflow
**Built-in Claude Code Integration**
- Chat with Claude directly inside your document manager (just press `/`)
- AI automatically sees your selected documents for instant context
- Ask questions, get summaries, request edits—all without leaving the app
- Track which files Claude reads/writes with full tool usage auditing
- Multiple chat sessions with persistent history

**Revolutionary Annotation System**
- Mark up documents with AI instructions: Edit, Expand, Verify consistency, Suggest improvements
- Batch-process multiple annotations across different files
- Generate comprehensive Claude prompts with full file context
- Perfect for systematic document review and editorial workflows

### 2. Find Anything, Instantly
**Multiple Ways to Navigate**
- **Command Palette** (Cmd+K): VS Code/Raycast-style instant file access with fuzzy search
- **Full-text Search**: Search file content, not just names—powered by inverted index for speed
- **Smart Fuzzy Matching**: Type partial names, get relevant results ranked by relevance
- **Recent Files**: Access last 9 files with Cmd+1-9
- **Tree View**: Traditional hierarchical navigation when you need it
- **Grid View**: Pinterest-style visual browsing with thumbnails and previews

### 3. Universal Format Support
**One App, All Your Documents**
- Markdown, PDF, DOC/DOCX, PPT/PPTX
- Excel, CSV, images, code files
- Rich native previews for every format
- Edit text-based formats directly in-app
- No more "which app opens this?" moments

### 4. Keyboard-First Design
**Built for Power Users**
- Every feature accessible via keyboard shortcuts
- Command palette for zero-context-switching file access
- Vim-inspired efficiency meets modern macOS design
- Tab management: Cmd+W to close, Cmd+Shift+]/[ to navigate
- Toggle views, create files, run git operations—all without touching the mouse

### 5. Git Integration Built-In
**Version Control for Everyone**
- Real-time git status display (branch, changes, sync state)
- Commit and push directly from the document manager
- Visual indicators for modified/untracked files
- Network retry logic ensures reliable operations
- Perfect for documentation repos and content teams

### 6. Modern, Beautiful macOS Design
**Feels Like It Came From Apple**
- Full macOS Sequoia styling with glassmorphism effects
- Smooth spring animations throughout (0.2-0.3s response times)
- Native SwiftUI 6 implementation
- Floating chat drawer that appears/disappears elegantly
- Collapsible sidebar, responsive layouts, dark mode support

---

## Who Should Use BetterDocs?

### Knowledge Workers
- Manage all your documents in one intelligent workspace
- Let AI summarize, analyze, and edit for you
- Annotate systematically, batch-process improvements
- Navigate vast document collections effortlessly

### Developers & Tech Writers
- Built-in git integration for documentation repos
- Code file support with syntax awareness
- Markdown-first design
- Keyboard-driven workflow matches your coding environment

### Writers & Editors
- Annotation system perfect for editorial workflows
- AI-powered content expansion and consistency checks
- Multi-document batch editing
- Track changes and generate improvement prompts

### Researchers & Analysts
- Multi-format support (PDFs, docs, spreadsheets, images)
- Full-text search across your entire knowledge base
- Document outline navigation for structured reading
- AI assistance for analysis and synthesis

---

## What Makes BetterDocs Different?

### 1. Deep AI Integration (Not a Bolt-On)
Most document managers add AI as an afterthought. BetterDocs was designed from the ground up with AI at its core:
- Claude Code Agent SDK integration for full tool access
- Annotation system purpose-built for AI batch processing
- Context management that actually works
- Tool usage transparency—see exactly what Claude does

### 2. Annotation-to-AI Workflow (Unique!)
No other document manager lets you:
- Mark up multiple documents with typed instructions
- Generate comprehensive AI prompts with full context
- Batch-process editorial tasks across files
- Support specialized workflows (consistency checks, content expansion, Slides generation)

### 3. Keyboard-First, Modern UI
The rare combination of:
- Complete keyboard accessibility (power users rejoice!)
- Contemporary macOS design (not a dated enterprise UI)
- Smooth, delightful animations
- Multiple navigation paradigms for different workflows

### 4. Technical Excellence
Built with the latest technology:
- **Swift 6.0** with strict concurrency (compile-time data race safety)
- **Actor-based architecture** for thread-safe operations
- **Observation framework** (30-50% faster than Combine)
- **Modern Apple frameworks**: SwiftUI 6, PDFKit, UniformTypeIdentifiers, OSLog

---

## Real-World Use Cases

### Use Case 1: Content Team Documentation Review
1. Open your docs folder in BetterDocs
2. Use full-text search to find all mentions of outdated terminology
3. Add "Edit" annotations to mark sections needing updates
4. Add "Verify" annotations for consistency checks across files
5. Generate batch prompt, send to Claude, process all updates at once
6. Commit and push changes with built-in git integration

**Time saved**: Hours of manual editing reduced to minutes

### Use Case 2: Research Paper Management
1. Import PDFs, docs, and notes into a project folder
2. Use document outline to navigate dense papers
3. Chat with Claude to summarize key findings (context automatically included)
4. Add "Expand" annotations where you need more detail
5. Full-text search across all papers to find specific methodologies
6. Export annotated summaries for your own writing

**Time saved**: Weeks of manual reading and note-taking

### Use Case 3: Developer Documentation
1. Manage Markdown docs alongside code in git repo
2. Use command palette (Cmd+K) for instant file access
3. Edit docs with live preview
4. Ask Claude to improve clarity, check for technical accuracy
5. Stage, commit, push—all without leaving the app
6. Recent files (Cmd+1-9) for quick navigation between docs you're updating

**Time saved**: Constant context-switching eliminated

---

## Technical Highlights

### Performance
- **Inverted index** for instant full-text search across thousands of documents
- **Lazy loading** in grid view for smooth scrolling
- **File system watching** with smart debouncing (auto-refresh on changes)
- **0.2-0.3s animations** for responsive feel

### Safety & Reliability
- **Swift 6 data race safety**: Compile-time guarantees prevent concurrency bugs
- **Actor-based services**: Thread-safe operations by design
- **Git retry logic**: Exponential backoff (2s, 4s, 8s, 16s) ensures reliable network operations
- **Privacy-preserving logging**: OSLog with appropriate privacy levels

### Architecture
- **MVVM pattern**: Clean separation of concerns
- **Protocol-oriented design**: Polymorphic file/folder handling
- **Observable state**: Reactive UI updates with @Observable macro
- **Comprehensive documentation**: 9+ detailed architecture docs

---

## Development Status

**Current State**: Foundation complete, actively developed

**What Works Now**:
- All core document management features
- Claude Code Agent SDK integration
- Full UI with floating chat, command palette, grid/list views
- Git operations with retry logic
- Annotation system
- Multi-format preview and editing

**Next Steps**:
- Enhanced Office format parsing
- Advanced search filters (date, size, type)
- Performance optimization for 10,000+ file collections
- Comprehensive automated testing

---

## Why You Should Care

### For Your Team
- **Productivity boost**: Spend less time managing files, more time creating value
- **AI leverage**: Every team member gets AI-assisted document workflows
- **Consistency**: Standardized tool for documentation review and editing
- **Modern stack**: Built with 2024-2025 best practices, not legacy tech

### For Your Organization
- **Faster documentation cycles**: Annotation + AI batch processing = speed
- **Better knowledge management**: Full-text search makes institutional knowledge discoverable
- **Developer-friendly**: Git integration means documentation lives with code
- **macOS-native**: Leverages platform strengths, feels familiar

### For You Personally
- **Less context-switching**: One app instead of five
- **Keyboard efficiency**: Work at the speed of thought
- **Beautiful design**: Actually enjoy using your document manager
- **AI superpowers**: Claude becomes your editing and research assistant

---

## Getting Started

BetterDocs requires:
- macOS 15 Sequoia or later
- Node.js (for Claude Agent SDK integration)
- Claude API key or Claude Code CLI configured

**Ready to revolutionize your document workflow?**

BetterDocs is where modern document management meets AI assistance—designed for people who demand more from their tools.

---

## Technical Details

**Built With**:
- Swift 6.0, SwiftUI 6, macOS 15 SDK
- Claude Agent SDK (Node.js)
- Apple frameworks: Observation, PDFKit, UniformTypeIdentifiers, QuickLook

**Architecture**:
- MVVM with actor-based services
- Observable state management
- Protocol-oriented polymorphism
- Thread-safe by design

**Repository**: Active development with comprehensive documentation

---

*BetterDocs: Document management that finally makes sense.*
