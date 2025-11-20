import SwiftUI
import UniformTypeIdentifiers
import PDFKit

struct AnnotationDialogData: Identifiable {
    let id = UUID()
    let text: String
    let start: Int
    let end: Int
}

struct PreviewView: View {
    @Environment(AppState.self) private var appState
    @State private var annotationDialogData: AnnotationDialogData?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Main preview content
            VStack(spacing: 0) {
                // Tab bar (if any tabs are open - preview or pinned)
                if appState.previewTab != nil || !appState.openTabs.isEmpty {
                    TabBarView()
                    Divider()
                }

                if let item = appState.selectedItem {
                    // Header with file info
                    PreviewHeaderView(item: item)

                    Divider()

                    // Content preview
                    if let document = item as? Document {
                        DocumentPreviewView(document: document)
                    } else if let folder = item as? Folder {
                        ScrollView {
                            FolderPreviewView(folder: folder)
                                .padding()
                        }
                    }
                } else {
                    // Empty state
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 64))
                            .foregroundColor(.secondary.opacity(0.5))

                        Text("Select a file to preview")
                            .font(.title2)
                            .foregroundColor(.secondary)

                        Text("Choose a file from the navigation sidebar")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(Color(NSColor.textBackgroundColor))

            // Floating document outline overlay (top-right corner)
            FloatingDocumentOutlineView()
                .padding(.top, 16)
                .padding(.trailing, 16)
                .zIndex(100)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowAnnotationDialog"))) { notification in
            print("📢 Received ShowAnnotationDialog notification")
            if let userInfo = notification.userInfo,
               let text = userInfo["selectedText"] as? String,
               let startOffset = userInfo["startOffset"] as? Int,
               let endOffset = userInfo["endOffset"] as? Int {
                print("✅ Dialog info: text='\(text.prefix(30))...', offsets=\(startOffset)-\(endOffset)")
                // Create Identifiable data object - this will trigger the sheet
                annotationDialogData = AnnotationDialogData(text: text, start: startOffset, end: endOffset)
                print("✅ Set annotationDialogData")
            } else {
                print("❌ Failed to extract annotation info from notification")
            }
        }
        .sheet(item: $annotationDialogData) { data in
            let _ = print("🎬 Sheet builder called with data: '\(data.text.prefix(30))...'")
            if let selectedItem = appState.selectedItem {
                let _ = print("✅ Building AnnotationDialog")
                AnnotationDialog(
                    selectedText: data.text,
                    startOffset: data.start,
                    endOffset: data.end,
                    filePath: selectedItem.path.path,
                    fileName: selectedItem.name
                )
                .environment(appState)
            } else {
                let _ = print("❌ Missing selectedItem")
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text("Error: No document selected")
                    Button("Close") {
                        annotationDialogData = nil
                    }
                }
                .padding(40)
                .frame(width: 300)
            }
        }
    }
}

struct TabBarView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                // Preview tab (ephemeral, shown first)
                if let previewTab = appState.previewTab {
                    TabItemView(
                        tab: previewTab,
                        isActive: appState.activeTabID == previewTab.id,
                        isPreview: true
                    )
                }

                // Pinned tabs
                ForEach(appState.openTabs) { tab in
                    TabItemView(
                        tab: tab,
                        isActive: appState.activeTabID == tab.id,
                        isPreview: false
                    )
                }
            }
        }
        .frame(height: 32)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

struct TabItemView: View {
    let tab: DocumentTab
    let isActive: Bool
    let isPreview: Bool
    @Environment(AppState.self) private var appState
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 6) {
            Text(tab.itemName)
                .font(.system(size: 12))
                .lineLimit(1)
                .foregroundColor(isActive ? .primary : .secondary)
                .italic(isPreview) // Preview tab in italics

            // Close button only for pinned tabs, not preview
            if !isPreview {
                Button(action: {
                    appState.closeTab(tab.id)
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 14, height: 14)
                }
                .buttonStyle(.plain)
                .opacity(isHovered || isActive ? 1.0 : 0.0)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isActive ? Color(NSColor.selectedContentBackgroundColor) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if isPreview {
                // Clicking preview tab just activates it
                appState.activeTabID = tab.id
            } else {
                appState.switchToTab(tab.id)
            }
        }
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct PreviewHeaderView: View {
    let item: any FileSystemItem
    @Environment(AppState.self) private var appState

    var document: Document? {
        item as? Document
    }

    var folder: Folder? {
        item as? Folder
    }

    var canEdit: Bool {
        if let doc = document {
            return doc.type == .markdown || doc.type == .text || doc.type == .code(language: "")
        }
        return false
    }

    var body: some View {
        HStack(spacing: 12) {
            item.icon
                .font(.title)
                .foregroundColor(.accentColor)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)

                HStack(spacing: 12) {
                    if let doc = document {
                        Label(doc.formattedSize, systemImage: "arrow.down.circle")
                        Label(doc.type.displayName, systemImage: "doc")
                    } else if let folder = folder {
                        Label("\(folder.documentCount) files", systemImage: "doc")
                        Label("\(folder.folderCount) folders", systemImage: "folder")
                    }

                    Label(formatDate(item.modified), systemImage: "clock")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer()

            // Action buttons
            HStack(spacing: 8) {
                // Edit/Preview toggle for text-based files
                if canEdit {
                    Button(action: { appState.toggleEditMode() }) {
                        Image(systemName: appState.isEditMode ? "book" : "pencil")
                    }
                    .help(appState.isEditMode ? "Preview" : "Edit")
                }

                Button(action: { openInFinder() }) {
                    Image(systemName: "folder")
                }
                .help("Show in Finder")

                Button(action: { openWithDefaultApp() }) {
                    Image(systemName: "arrow.up.forward.app")
                }
                .help("Open with default app")
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func openInFinder() {
        NSWorkspace.shared.selectFile(item.path.path, inFileViewerRootedAtPath: "")
    }

    private func openWithDefaultApp() {
        NSWorkspace.shared.open(item.path)
    }
}

struct DocumentPreviewView: View {
    let document: Document
    @Environment(AppState.self) private var appState

    var body: some View {
        let _ = print("🖼️ Previewing document: \(document.name) of type: \(document.type.displayName)")

        return Group {
            // Show editor for text-based files in edit mode
            if appState.isEditMode && canEdit {
                TextEditorView(document: document)
            } else {
                // Show preview
                switch document.type {
                case .markdown:
                    MarkdownPreview(document: document)
                case .text, .code:
                    TextPreview(document: document)
                case .pdf:
                    PDFPreview(document: document)
                case .image:
                    ImagePreview(document: document)
                case .csv:
                    CSVPreview(document: document)
                default:
                    GenericPreview(document: document)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var canEdit: Bool {
        return document.type == .markdown || document.type == .text || document.type == .code(language: "")
    }
}

struct FolderPreviewView: View {
    let folder: Folder
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Folder Contents")
                .font(.title2)
                .fontWeight(.semibold)

            // Statistics
            HStack(spacing: 40) {
                StatView(title: "Files", value: "\(folder.documentCount)", icon: "doc.fill")
                StatView(title: "Folders", value: "\(folder.folderCount)", icon: "folder.fill")
                StatView(title: "Total Size", value: ByteCountFormatter.string(fromByteCount: folder.totalSize, countStyle: .file), icon: "externaldrive.fill")
            }

            Divider()

            // Recent files in this folder
            Text("Contents")
                .font(.headline)

            LazyVStack(alignment: .leading, spacing: 4) {
                ForEach(folder.children.prefix(20), id: \.id) { item in
                    FolderContentRow(item: item, appState: appState)
                }
            }
        }
    }
}

struct FolderContentRow: View {
    let item: any FileSystemItem
    let appState: AppState
    @State private var isHovered = false

    var body: some View {
        HStack {
            item.icon
                .foregroundColor(item.isFolder ? .accentColor : .secondary)
            Text(item.name)
            Spacer()
            if let doc = item as? Document {
                Text(doc.formattedSize)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isHovered ? Color.secondary.opacity(0.1) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            // Double-click: open in tab
            appState.openInTab(item)
        }
        .onTapGesture {
            // Single-click: preview
            appState.selectItem(item)
        }
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

struct StatView: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.accentColor)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
        }
    }
}

// Placeholder preview components
struct MarkdownPreview: View {
    let document: Document
    @State private var content: String?
    @State private var isLoading = false
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if let loadedContent = content, let activeTabID = appState.activeTabID {
                MarkdownWebView(markdown: loadedContent, tabID: activeTabID)
            } else if isLoading {
                ProgressView("Loading markdown...")
            } else {
                VStack {
                    Text("Unable to load file")
                        .foregroundColor(.secondary)
                    Button("Retry") {
                        Task { await loadContent() }
                    }
                }
            }
        }
        .id(document.modified) // Force view refresh when document modified date changes
        .task(id: document.modified) {
            await loadContent()
        }
    }

    private func loadContent() async {
        isLoading = true
        defer { isLoading = false }

        print("📄 Loading markdown from: \(document.path.path)")

        // Always load from file to ensure we have the latest content
        // (cached content may be stale after edits)
        do {
            let fileContent = try String(contentsOf: document.path, encoding: .utf8)
            print("✅ Loaded \(fileContent.count) chars from file")
            content = fileContent
        } catch {
            print("❌ Error loading markdown: \(error)")
            content = "Error loading file: \(error.localizedDescription)"
        }
    }
}

struct TextPreview: View {
    let document: Document
    @State private var content: String?
    @State private var isLoading = false

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            Group {
                if let loadedContent = content {
                    Text(loadedContent)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                } else if isLoading {
                    ProgressView("Loading...")
                } else {
                    VStack {
                        Text("Unable to load file")
                            .foregroundColor(.secondary)
                        Button("Retry") {
                            Task { await loadContent() }
                        }
                    }
                }
            }
        }
        .id(document.modified) // Force view refresh when document modified date changes
        .task(id: document.modified) {
            await loadContent()
        }
    }

    private func loadContent() async {
        isLoading = true
        defer { isLoading = false }

        // Always load from file to ensure we have the latest content
        // (cached content may be stale after edits)
        do {
            let fileContent = try String(contentsOf: document.path, encoding: .utf8)
            content = fileContent
        } catch {
            print("Error loading text file: \(error)")
            content = "Error loading file: \(error.localizedDescription)"
        }
    }
}

struct PDFPreview: View {
    let document: Document

    var body: some View {
        if let pdfDocument = PDFDocument(url: document.path) {
            PDFKitView(pdfDocument: pdfDocument)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 16) {
                Image(systemName: "doc.fill.badge.exclamationmark")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                Text("Unable to load PDF")
                    .foregroundColor(.secondary)
            }
        }
    }
}

// PDFKit wrapper for SwiftUI
struct PDFKitView: NSViewRepresentable {
    let pdfDocument: PDFDocument

    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = pdfDocument
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        return pdfView
    }

    func updateNSView(_ nsView: PDFView, context: Context) {
        nsView.document = pdfDocument
    }
}

struct ImagePreview: View {
    let document: Document

    var body: some View {
        if let nsImage = NSImage(contentsOf: document.path) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            Text("Unable to load image")
                .foregroundColor(.secondary)
        }
    }
}

struct CSVPreview: View {
    let document: Document

    var body: some View {
        Text("CSV Preview - Coming Soon")
            .foregroundColor(.secondary)
    }
}

struct GenericPreview: View {
    let document: Document

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.fill")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("Preview not available for this file type")
                .foregroundColor(.secondary)

            Button("Open with default app") {
                NSWorkspace.shared.open(document.path)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    PreviewView()
        .environment(AppState())
}
