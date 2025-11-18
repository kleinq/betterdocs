import Foundation
import UniformTypeIdentifiers

actor DocumentService {
    private var documentCache: [UUID: Document] = [:]

    /// Scan a folder and build a hierarchical structure
    @MainActor
    func scanFolder(at url: URL) async throws -> Folder {
        let fileManager = FileManager.default

        // Get folder attributes
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        let created = attributes[.creationDate] as? Date ?? Date()
        let modified = attributes[.modificationDate] as? Date ?? Date()

        let folder = Folder(
            name: url.lastPathComponent,
            path: url,
            created: created,
            modified: modified
        )

        // Get directory contents
        let contents = try fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .creationDateKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )

        // Process each item
        for itemURL in contents {
            let resourceValues = try itemURL.resourceValues(forKeys: [.isDirectoryKey])

            if resourceValues.isDirectory == true {
                // Recursively scan subdirectory
                let subfolder = try await scanFolder(at: itemURL)
                folder.addChild(subfolder)
            } else {
                // Create document
                let document = try await createDocument(from: itemURL)
                folder.addChild(document)
            }
        }

        // Sort children
        folder.sortAlphabetically()

        return folder
    }

    /// Create a document from a file URL
    func createDocument(from url: URL) async throws -> Document {
        let fileManager = FileManager.default
        let attributes = try fileManager.attributesOfItem(atPath: url.path)

        let size = attributes[.size] as? Int64 ?? 0
        let created = attributes[.creationDate] as? Date ?? Date()
        let modified = attributes[.modificationDate] as? Date ?? Date()

        let documentType = DocumentType.from(url: url)

        var document = Document(
            name: url.lastPathComponent,
            path: url,
            type: documentType,
            size: size,
            created: created,
            modified: modified
        )

        // Extract content for text-based files
        if shouldExtractContent(for: documentType) {
            document.content = try? await extractContent(from: url, type: documentType)
        }

        // Extract metadata
        document.metadata = extractMetadata(from: url, attributes: attributes)

        // Cache the document
        documentCache[document.id] = document

        return document
    }

    /// Extract text content from a document
    func extractContent(from url: URL, type: DocumentType) async throws -> String {
        switch type {
        case .markdown, .text:
            return try String(contentsOf: url, encoding: .utf8)

        case .code:
            return try String(contentsOf: url, encoding: .utf8)

        case .csv:
            return try String(contentsOf: url, encoding: .utf8)

        case .pdf:
            return try await extractPDFContent(from: url)

        case .word:
            return try await extractWordContent(from: url)

        case .powerpoint:
            return try await extractPowerPointContent(from: url)

        default:
            return ""
        }
    }

    /// Refresh a document's content
    func refreshDocument(_ document: Document) async throws -> Document {
        try await createDocument(from: document.path)
    }

    // MARK: - Private Helpers

    private func shouldExtractContent(for type: DocumentType) -> Bool {
        switch type {
        case .markdown, .text, .code, .csv:
            return true
        case .pdf, .word, .powerpoint:
            return true // Will be extracted on demand
        default:
            return false
        }
    }

    private func extractMetadata(from url: URL, attributes: [FileAttributeKey: Any]) -> [String: String] {
        var metadata: [String: String] = [:]

        metadata["path"] = url.path
        metadata["extension"] = url.pathExtension

        if let size = attributes[.size] as? Int64 {
            metadata["size"] = "\(size)"
        }

        return metadata
    }

    private func extractPDFContent(from url: URL) async throws -> String {
        // TODO: Implement PDF text extraction using PDFKit
        // For now, return placeholder
        return "[PDF content extraction not yet implemented]"
    }

    private func extractWordContent(from url: URL) async throws -> String {
        // TODO: Implement Word document parsing
        // This will require a third-party library or custom parser
        return "[Word document parsing not yet implemented]"
    }

    private func extractPowerPointContent(from url: URL) async throws -> String {
        // TODO: Implement PowerPoint parsing
        return "[PowerPoint parsing not yet implemented]"
    }
}
