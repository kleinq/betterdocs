import Foundation
import SwiftUI

// MARK: - Chat Model

struct Chat: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var messages: [ChatMessage]
    var relatedFiles: [String] // File paths
    var relatedFolders: [String] // Folder paths
    let created: Date
    var modified: Date
    var isArchived: Bool

    init(
        id: UUID = UUID(),
        title: String = "New Chat",
        messages: [ChatMessage] = [],
        relatedFiles: [String] = [],
        relatedFolders: [String] = [],
        created: Date = Date(),
        modified: Date = Date(),
        isArchived: Bool = false
    ) {
        self.id = id
        self.title = title
        self.messages = messages
        self.relatedFiles = relatedFiles
        self.relatedFolders = relatedFolders
        self.created = created
        self.modified = modified
        self.isArchived = isArchived
    }

    var displayTitle: String {
        if title.isEmpty || title == "New Chat" {
            // Use first user message as title
            if let firstUserMessage = messages.first(where: { $0.isUser }) {
                let truncated = firstUserMessage.content.count > 50
                    ? String(firstUserMessage.content.prefix(47)) + "..."
                    : firstUserMessage.content
                return truncated
            }
            return "New Chat"
        }
        return title
    }

    var lastMessageDate: Date {
        messages.last?.timestamp ?? modified
    }

    mutating func addMessage(_ message: ChatMessage) {
        messages.append(message)
        modified = Date()
    }

    mutating func addRelatedFile(_ filePath: String) {
        if !relatedFiles.contains(filePath) {
            relatedFiles.append(filePath)
            modified = Date()
        }
    }

    mutating func removeRelatedFile(_ filePath: String) {
        relatedFiles.removeAll { $0 == filePath }
        modified = Date()
    }

    mutating func addRelatedFolder(_ folderPath: String) {
        if !relatedFolders.contains(folderPath) {
            relatedFolders.append(folderPath)
            modified = Date()
        }
    }

    mutating func removeRelatedFolder(_ folderPath: String) {
        relatedFolders.removeAll { $0 == folderPath }
        modified = Date()
    }
}

// MARK: - Chat Message Model

struct ChatMessage: Identifiable, Codable, Equatable {
    let id: UUID
    let content: String
    let isUser: Bool
    let timestamp: Date

    init(id: UUID = UUID(), content: String, isUser: Bool, timestamp: Date = Date()) {
        self.id = id
        self.content = content
        self.isUser = isUser
        self.timestamp = timestamp
    }
}

// MARK: - Audit Log Entry

struct AuditLogEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let timestamp: Date
    let tool: String
    let action: String
    let details: String?

    init(id: UUID = UUID(), timestamp: Date, tool: String, action: String, details: String?) {
        self.id = id
        self.timestamp = timestamp
        self.tool = tool
        self.action = action
        self.details = details
    }

    var icon: String {
        switch tool.lowercased() {
        case "read": return "doc.text"
        case "write", "edit": return "pencil"
        case "glob", "grep": return "magnifyingglass"
        case "bash": return "terminal"
        case "webfetch", "websearch": return "globe"
        default: return "wrench.and.screwdriver"
        }
    }

    var color: Color {
        switch tool.lowercased() {
        case "read": return .blue
        case "write", "edit": return .green
        case "glob", "grep": return .purple
        case "bash": return .orange
        case "webfetch", "websearch": return .cyan
        default: return .gray
        }
    }
}
