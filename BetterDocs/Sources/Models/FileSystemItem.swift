import Foundation
import SwiftUI
import UniformTypeIdentifiers
import CryptoKit

// Protocol for common file system items
protocol FileSystemItem: Identifiable, Hashable {
    var id: UUID { get }
    var name: String { get }
    var path: URL { get }
    var created: Date { get }
    var modified: Date { get }
    var isFolder: Bool { get }
}

// Helper to generate stable UUIDs from file paths
extension UUID {
    /// Generate a stable UUID based on a file path
    /// This ensures that the same file always gets the same UUID across reloads
    static func stableID(for path: URL) -> UUID {
        let pathString = path.path
        let hash = SHA256.hash(data: Data(pathString.utf8))
        let hashBytes = Array(hash.prefix(16)) // Take first 16 bytes for UUID

        // Convert hash bytes to UUID string format
        let uuidString = String(format: "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x",
            hashBytes[0], hashBytes[1], hashBytes[2], hashBytes[3],
            hashBytes[4], hashBytes[5],
            hashBytes[6], hashBytes[7],
            hashBytes[8], hashBytes[9],
            hashBytes[10], hashBytes[11], hashBytes[12], hashBytes[13], hashBytes[14], hashBytes[15])

        return UUID(uuidString: uuidString)!
    }
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
