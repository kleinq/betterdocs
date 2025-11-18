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
        id: UUID = UUID(),
        name: String,
        path: URL,
        created: Date,
        modified: Date,
        children: [any FileSystemItem] = []
    ) {
        self.id = id
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
