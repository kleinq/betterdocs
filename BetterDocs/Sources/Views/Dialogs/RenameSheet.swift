import SwiftUI

struct RenameSheet: View {
    @Binding var isPresented: Bool
    let item: any FileSystemItem
    let onRename: (String) -> Void

    @State private var newName: String
    @State private var errorMessage: String?
    @FocusState private var isTextFieldFocused: Bool

    init(isPresented: Binding<Bool>, item: any FileSystemItem, onRename: @escaping (String) -> Void) {
        self._isPresented = isPresented
        self.item = item
        self.onRename = onRename

        // Initialize with current name (without extension for files)
        if item.isFolder {
            self._newName = State(initialValue: item.name)
        } else {
            // Remove file extension for initial editing
            let name = item.name
            if let lastDot = name.lastIndex(of: ".") {
                self._newName = State(initialValue: String(name[..<lastDot]))
            } else {
                self._newName = State(initialValue: name)
            }
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                item.icon
                    .foregroundColor(item.isFolder ? .accentColor : .secondary)
                    .frame(width: 20, height: 20)

                Text("Rename \(item.isFolder ? "Folder" : "File")")
                    .font(.headline)
            }

            // Current name display
            VStack(alignment: .leading, spacing: 4) {
                Text("Current name:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(item.name)
                    .font(.body)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(6)
            }

            // New name input
            VStack(alignment: .leading, spacing: 4) {
                Text("New name:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                TextField("Enter new name", text: $newName)
                    .textFieldStyle(.roundedBorder)
                    .focused($isTextFieldFocused)
                    .onSubmit {
                        handleRename()
                    }

                // Show extension hint for files
                if !item.isFolder, let ext = fileExtension {
                    Text("File will be renamed with extension: \(ext)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            // Error message
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(6)
            }

            // Buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Button("Rename") {
                    handleRename()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 400)
        .onAppear {
            // Focus text field when sheet appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isTextFieldFocused = true
            }
        }
    }

    private var fileExtension: String? {
        guard !item.isFolder else { return nil }
        let name = item.name
        if let lastDot = name.lastIndex(of: ".") {
            return String(name[lastDot...])
        }
        return nil
    }

    private func handleRename() {
        // Validate name
        let trimmedName = newName.trimmingCharacters(in: .whitespaces)

        guard !trimmedName.isEmpty else {
            errorMessage = "Name cannot be empty"
            return
        }

        // Check for invalid characters
        let invalidCharacters = CharacterSet(charactersIn: "/:\\")
        if trimmedName.rangeOfCharacter(from: invalidCharacters) != nil {
            errorMessage = "Name cannot contain: / \\ :"
            return
        }

        // Add extension back for files
        let finalName: String
        if item.isFolder {
            finalName = trimmedName
        } else {
            // Preserve the original file extension
            if let ext = fileExtension {
                finalName = trimmedName + ext
            } else {
                finalName = trimmedName
            }
        }

        // Check if name is different
        if finalName == item.name {
            isPresented = false
            return
        }

        // Call the rename handler
        onRename(finalName)
        isPresented = false
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var isPresented = true

        var body: some View {
            RenameSheet(
                isPresented: $isPresented,
                item: Document(
                    name: "Example Document.md",
                    path: URL(fileURLWithPath: "/tmp/example.md"),
                    type: .markdown,
                    size: 1024,
                    created: Date(),
                    modified: Date(),
                    content: ""
                ),
                onRename: { newName in
                    print("Renamed to: \(newName)")
                }
            )
        }
    }

    return PreviewWrapper()
}
