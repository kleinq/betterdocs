import Foundation
import SwiftUI

// TODO: Make this @Observable when actor isolation is properly handled
class Folder: FileSystemItem {
    let id: UUID
    let name: String
    let path: URL
    let created: Date
    let modified: Date

    var children: [any FileSystemItem]
    var isExpanded: Bool = false

    var isFolder: Bool { true }

    var documentCount: Int {
        children.filter { !$0.isFolder }.count
    }

    var folderCount: Int {
        children.filter { $0.isFolder }.count
    }

    var totalSize: Int64 {
        children.reduce(0) { total, item in
            if let doc = item as? Document {
                return total + doc.size
            } else if let folder = item as? Folder {
                return total + folder.totalSize
            }
            return total
        }
    }

    var icon: Image {
        Image(systemName: isExpanded ? "folder.fill" : "folder")
    }

    init(
        id: UUID? = nil,
        name: String,
        path: URL,
        created: Date,
        modified: Date,
        children: [any FileSystemItem] = []
    ) {
        // Use stable ID based on path, or provided ID, or generate new one
        self.id = id ?? UUID.stableID(for: path)
        self.name = name
        self.path = path
        self.created = created
        self.modified = modified
        self.children = children
    }

    func addChild(_ item: any FileSystemItem) {
        children.append(item)
    }

    func removeChild(withID id: UUID) {
        children.removeAll { $0.id == id }
    }

    func sortChildren(by comparator: (any FileSystemItem, any FileSystemItem) -> Bool) {
        children.sort(by: comparator)
    }

    // Sort alphabetically with folders first
    func sortAlphabetically() {
        children.sort { item1, item2 in
            if item1.isFolder != item2.isFolder {
                return item1.isFolder
            }
            return item1.name.localizedCaseInsensitiveCompare(item2.name) == .orderedAscending
        }
    }

    // Recursive search for an item
    func findItem(withID id: UUID) -> (any FileSystemItem)? {
        if self.id == id {
            return self
        }

        for child in children {
            if child.id == id {
                return child
            }

            if let folder = child as? Folder,
               let found = folder.findItem(withID: id) {
                return found
            }
        }

        return nil
    }

    // Get all documents recursively
    func allDocuments() -> [Document] {
        var documents: [Document] = []

        for child in children {
            if let doc = child as? Document {
                documents.append(doc)
            } else if let folder = child as? Folder {
                documents.append(contentsOf: folder.allDocuments())
            }
        }

        return documents
    }

    // MARK: - File Management Helpers

    /// Check if a file with the given name exists in this folder
    func containsFile(named fileName: String) -> Bool {
        return children.contains { $0.name == fileName }
    }

    /// Get a unique filename by appending a number if needed
    func uniqueFilename(for baseName: String, withExtension ext: String) -> String {
        var filename = "\(baseName)\(ext)"
        var counter = 1

        while containsFile(named: filename) {
            filename = "\(baseName) \(counter)\(ext)"
            counter += 1
        }

        return filename
    }

    /// Find the parent folder of an item
    func findParentFolder(of item: any FileSystemItem) -> Folder? {
        for child in children {
            if child.id == item.id {
                return self
            }

            if let subfolder = child as? Folder,
               let parent = subfolder.findParentFolder(of: item) {
                return parent
            }
        }

        return nil
    }

    /// Move an item from this folder to another folder
    func moveChild(_ childID: UUID, to targetFolder: Folder) {
        guard let child = children.first(where: { $0.id == childID }) else { return }

        // Remove from this folder
        removeChild(withID: childID)

        // Add to target folder
        targetFolder.addChild(child)

        // Re-sort both folders
        sortAlphabetically()
        targetFolder.sortAlphabetically()
    }
}

// Hashable conformance for Folder
extension Folder {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Folder, rhs: Folder) -> Bool {
        lhs.id == rhs.id
    }
}
