import SwiftUI

struct AnnotationDialog: View {
    let selectedText: String
    let startOffset: Int
    let endOffset: Int
    let filePath: String
    let fileName: String

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var selectedAction: AnnotationType = .edit
    @State private var instruction: String = ""
    @State private var references: [String] = []
    @State private var showingFilePicker = false
    @State private var filePickerFilter: String = ""
    @State private var filteredItems: [any FileSystemItem] = []

    var body: some View {
        VStack(spacing: 0) {
            // Header with close button
            HStack {
                Text("Describe your change")
                    .font(.headline)
                    .foregroundColor(.secondary)

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .imageScale(.large)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // Action buttons (Apple Intelligence style)
            HStack(spacing: 12) {
                ActionButton(
                    title: "Edit",
                    icon: "pencil.circle",
                    isSelected: selectedAction == .edit,
                    action: { selectedAction = .edit }
                )

                ActionButton(
                    title: "Verify",
                    icon: "checkmark.circle",
                    isSelected: selectedAction == .verify,
                    action: { selectedAction = .verify }
                )

                ActionButton(
                    title: "Expand",
                    icon: "plus.circle",
                    isSelected: selectedAction == .expand,
                    action: { selectedAction = .expand }
                )

                ActionButton(
                    title: "Slides",
                    icon: "square.grid.2x2",
                    isSelected: selectedAction == .googleSlides,
                    action: { selectedAction = .googleSlides }
                )
            }
            .padding(16)

            Divider()

            // Selected text preview
            VStack(alignment: .leading, spacing: 8) {
                Text("Selected:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(truncatedSelection)
                    .font(.body)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            // Instruction text field
            VStack(alignment: .leading, spacing: 8) {
                Text(instructionPlaceholder)
                    .font(.caption)
                    .foregroundColor(.secondary)

                TextEditor(text: $instruction)
                    .font(.body)
                    .frame(height: 100)
                    .padding(8)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)

            // References section
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("References (optional)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Button(action: { showingFilePicker = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "at")
                            Text("Add file or folder")
                        }
                        .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
                }

                // Display selected references as tags
                if !references.isEmpty {
                    FlowLayout(spacing: 8) {
                        ForEach(references, id: \.self) { reference in
                            ReferenceTag(path: reference) {
                                removeReference(reference)
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)

            Divider()

            // Bottom action buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Add to Queue") {
                    addAnnotation()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(instruction.isEmpty)
            }
            .padding(16)
        }
        .frame(width: 420)
        .padding()
        .sheet(isPresented: $showingFilePicker) {
            FilePickerDialog(
                rootFolder: appState.rootFolder,
                selectedReferences: $references
            )
        }
    }
    
    private var truncatedSelection: String {
        if selectedText.count > 100 {
            return String(selectedText.prefix(97)) + "..."
        }
        return selectedText
    }

    private var instructionPlaceholder: String {
        switch selectedAction {
        case .edit:
            return "What changes would you like to make to this text?"
        case .verify:
            return "What should be verified for consistency across documents?"
        case .expand:
            return "What additional information should be included?"
        case .suggest:
            return "What suggestions do you need?"
        case .googleSlides:
            return "Describe the Google Slides presentation to create from this text"
        }
    }

    private func removeReference(_ path: String) {
        references.removeAll { $0 == path }
    }

    private func addAnnotation() {
        let annotation = Annotation(
            fileName: fileName,
            filePath: filePath,
            selection: TextSelection(
                startOffset: startOffset,
                endOffset: endOffset,
                selectedText: selectedText
            ),
            type: selectedAction,
            instruction: instruction,
            references: references
        )

        appState.addAnnotation(annotation)
        dismiss()
    }
}

// MARK: - Action Button Component

struct ActionButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : .primary)

                Text(title)
                    .font(.caption)
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor : Color(NSColor.controlBackgroundColor))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Reference Tag Component

struct ReferenceTag: View {
    let path: String
    let onRemove: () -> Void

    private var displayName: String {
        URL(fileURLWithPath: path).lastPathComponent
    }

    private var isFolder: Bool {
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
        return isDir.boolValue
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: isFolder ? "folder.fill" : "doc.fill")
                .font(.caption2)
                .foregroundColor(.secondary)

            Text(displayName)
                .font(.caption)
                .lineLimit(1)

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

// MARK: - Flow Layout for Tags

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.replacingUnspecifiedDimensions().width, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }

            self.size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}

// MARK: - File Picker Dialog

struct FilePickerDialog: View {
    let rootFolder: Folder?
    @Binding var selectedReferences: [String]

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var expandedFolders: Set<UUID> = []

    private var allItems: [any FileSystemItem] {
        guard let root = rootFolder else { return [] }
        return collectAllItems(from: root)
    }

    private var filteredItems: [any FileSystemItem] {
        if searchText.isEmpty {
            return []
        }
        return allItems.filter { item in
            item.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Select Files or Folders")
                    .font(.headline)

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .imageScale(.large)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("Type @ to search files and folders...", text: $searchText)
                    .textFieldStyle(.plain)

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Results
            ScrollView {
                if searchText.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "at")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)

                        Text("Type to search for files or folders")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(40)
                } else if filteredItems.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)

                        Text("No matches found")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(40)
                } else {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(filteredItems, id: \.id) { item in
                            FilePickerRow(
                                item: item,
                                isSelected: selectedReferences.contains(item.path.path),
                                onToggle: {
                                    toggleSelection(item)
                                }
                            )
                        }
                    }
                    .padding(.vertical, 8)
                }
            }

            Divider()

            // Footer
            HStack {
                Text("\(selectedReferences.count) selected")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 500, height: 400)
    }

    private func collectAllItems(from folder: Folder) -> [any FileSystemItem] {
        var items: [any FileSystemItem] = [folder]

        for child in folder.children {
            if let subfolder = child as? Folder {
                items.append(contentsOf: collectAllItems(from: subfolder))
            } else {
                items.append(child)
            }
        }

        return items
    }

    private func toggleSelection(_ item: any FileSystemItem) {
        let path = item.path.path

        if selectedReferences.contains(path) {
            selectedReferences.removeAll { $0 == path }
        } else {
            selectedReferences.append(path)
        }
    }
}

// MARK: - File Picker Row

struct FilePickerRow: View {
    let item: any FileSystemItem
    let isSelected: Bool
    let onToggle: () -> Void

    private var relativePath: String {
        item.path.path
    }

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .imageScale(.large)

                Image(systemName: item.isFolder ? "folder.fill" : "doc.fill")
                    .foregroundColor(item.isFolder ? .blue : .secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.body)
                        .foregroundColor(.primary)

                    Text(relativePath)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
    }
}

#Preview {
    AnnotationDialog(
        selectedText: "750,000 patients per year in the target market segment with specific focus on orthopedic procedures",
        startOffset: 100,
        endOffset: 147,
        filePath: "/path/to/pitch-deck.md",
        fileName: "pitch-deck.md"
    )
    .environment(AppState())
}
