import Foundation

/// Service for managing file system operations (create, move, rename, delete)
@MainActor
class FileManagementService: ObservableObject {
    @Published var lastError: FileManagementError?

    private let fileManager = FileManager.default

    // MARK: - File Creation

    /// Create a new text file with optional content
    func createTextFile(
        at folderPath: URL,
        name: String,
        fileType: FileType,
        initialContent: String = ""
    ) throws -> URL {
        let fileName = sanitizeFilename(name, fileType: fileType)
        let filePath = folderPath.appendingPathComponent(fileName)

        // Check if file already exists
        if fileManager.fileExists(atPath: filePath.path) {
            throw FileManagementError.fileAlreadyExists(path: filePath.path)
        }

        // Create the file
        let content = initialContent.data(using: .utf8) ?? Data()
        guard fileManager.createFile(atPath: filePath.path, contents: content, attributes: nil) else {
            throw FileManagementError.creationFailed(path: filePath.path)
        }

        return filePath
    }

    /// Create a new file with auto-generated AI filename
    func createFileWithAIFilename(
        at folderPath: URL,
        fileType: FileType,
        initialContent: String = "",
        suggestedName: String? = nil
    ) async throws -> URL {
        // Use suggested name or generate temporary name
        let tempName = suggestedName ?? "Untitled-\(Date().timeIntervalSince1970)"
        return try createTextFile(
            at: folderPath,
            name: tempName,
            fileType: fileType,
            initialContent: initialContent
        )
    }

    // MARK: - File Moving

    /// Move a file from source to destination folder
    func moveFile(
        from sourcePath: URL,
        to destinationFolder: URL
    ) throws -> URL {
        let fileName = sourcePath.lastPathComponent
        let destinationPath = destinationFolder.appendingPathComponent(fileName)

        // Check if source exists
        guard fileManager.fileExists(atPath: sourcePath.path) else {
            throw FileManagementError.fileNotFound(path: sourcePath.path)
        }

        // Check if destination folder exists
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: destinationFolder.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw FileManagementError.invalidDestination(path: destinationFolder.path)
        }

        // Check if file already exists at destination
        if fileManager.fileExists(atPath: destinationPath.path) {
            throw FileManagementError.fileAlreadyExists(path: destinationPath.path)
        }

        // Move the file
        try fileManager.moveItem(at: sourcePath, to: destinationPath)

        return destinationPath
    }

    /// Copy a file from source to destination folder
    func copyFile(
        from sourcePath: URL,
        to destinationFolder: URL
    ) throws -> URL {
        let fileName = sourcePath.lastPathComponent
        let destinationPath = destinationFolder.appendingPathComponent(fileName)

        // Check if source exists
        guard fileManager.fileExists(atPath: sourcePath.path) else {
            throw FileManagementError.fileNotFound(path: sourcePath.path)
        }

        // Check if destination folder exists
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: destinationFolder.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw FileManagementError.invalidDestination(path: destinationFolder.path)
        }

        // Handle duplicate names by appending number
        var finalPath = destinationPath
        var counter = 1
        while fileManager.fileExists(atPath: finalPath.path) {
            let nameWithoutExtension = fileName.deletingPathExtension
            let fileExtension = fileName.pathExtension
            let newName = "\(nameWithoutExtension) \(counter).\(fileExtension)"
            finalPath = destinationFolder.appendingPathComponent(newName)
            counter += 1
        }

        // Copy the file
        try fileManager.copyItem(at: sourcePath, to: finalPath)

        return finalPath
    }

    // MARK: - File Renaming

    /// Rename a file or folder
    func renameItem(
        at itemPath: URL,
        newName: String,
        preserveExtension: Bool = true
    ) throws -> URL {
        guard fileManager.fileExists(atPath: itemPath.path) else {
            throw FileManagementError.fileNotFound(path: itemPath.path)
        }

        // Preserve extension if requested
        var finalName = newName
        if preserveExtension {
            let currentExtension = itemPath.pathExtension
            if !currentExtension.isEmpty && !newName.hasSuffix(".\(currentExtension)") {
                finalName = "\(newName).\(currentExtension)"
            }
        }

        let sanitized = sanitizeFilename(finalName, fileType: nil)
        let parentFolder = itemPath.deletingLastPathComponent()
        let newPath = parentFolder.appendingPathComponent(sanitized)

        // Check if new name already exists
        if fileManager.fileExists(atPath: newPath.path) && newPath != itemPath {
            throw FileManagementError.fileAlreadyExists(path: newPath.path)
        }

        // Rename
        try fileManager.moveItem(at: itemPath, to: newPath)

        return newPath
    }

    // MARK: - File Deletion

    /// Delete a file or folder
    func deleteItem(at itemPath: URL) throws {
        guard fileManager.fileExists(atPath: itemPath.path) else {
            throw FileManagementError.fileNotFound(path: itemPath.path)
        }

        try fileManager.removeItem(at: itemPath)
    }

    // MARK: - Helpers

    /// Sanitize filename by removing invalid characters
    private func sanitizeFilename(_ name: String, fileType: FileType?) -> String {
        var sanitized = name
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Ensure extension matches file type
        if let fileType = fileType {
            let expectedExtension = fileType.fileExtension
            if !sanitized.hasSuffix(expectedExtension) {
                // Remove any existing extension
                if let lastDot = sanitized.lastIndex(of: ".") {
                    sanitized = String(sanitized[..<lastDot])
                }
                sanitized += expectedExtension
            }
        }

        return sanitized.isEmpty ? "Untitled" : sanitized
    }

    /// Check if a path is writable
    func isWritable(at path: URL) -> Bool {
        return fileManager.isWritableFile(atPath: path.path)
    }

    /// Get available disk space at path
    func availableDiskSpace(at path: URL) -> Int64? {
        do {
            let values = try path.resourceValues(forKeys: [.volumeAvailableCapacityKey])
            return values.volumeAvailableCapacity.map { Int64($0) }
        } catch {
            return nil
        }
    }
}

// MARK: - File Types

enum FileType {
    case markdown
    case plainText

    var fileExtension: String {
        switch self {
        case .markdown: return ".md"
        case .plainText: return ".txt"
        }
    }

    var displayName: String {
        switch self {
        case .markdown: return "Markdown"
        case .plainText: return "Plain Text"
        }
    }

    var initialContent: String {
        // Start with empty content - let user add their own
        return ""
    }
}

// MARK: - Errors

enum FileManagementError: LocalizedError {
    case fileNotFound(path: String)
    case fileAlreadyExists(path: String)
    case creationFailed(path: String)
    case invalidDestination(path: String)
    case permissionDenied(path: String)
    case diskSpaceFull
    case unknownError(message: String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .fileAlreadyExists(let path):
            return "A file already exists at: \(path)"
        case .creationFailed(let path):
            return "Failed to create file: \(path)"
        case .invalidDestination(let path):
            return "Invalid destination folder: \(path)"
        case .permissionDenied(let path):
            return "Permission denied: \(path)"
        case .diskSpaceFull:
            return "Not enough disk space"
        case .unknownError(let message):
            return "An error occurred: \(message)"
        }
    }
}

// MARK: - String Extensions

extension String {
    var pathExtension: String {
        return (self as NSString).pathExtension
    }

    var deletingPathExtension: String {
        return (self as NSString).deletingPathExtension
    }
}
