import Foundation
import SwiftUI
import UniformTypeIdentifiers

// Protocol for common file system items
protocol FileSystemItem: Identifiable, Hashable {
    var id: UUID { get }
    var name: String { get }
    var path: URL { get }
    var created: Date { get }
    var modified: Date { get }
    var isFolder: Bool { get }
}

// Extension for common functionality
extension FileSystemItem {
    var displayName: String {
        name
    }

    var icon: Image {
        if isFolder {
            return Image(systemName: "folder.fill")
        } else {
            return Image(systemName: "doc.fill")
        }
    }
}
