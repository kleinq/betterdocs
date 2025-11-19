import Foundation

/// Represents the status of a Git repository
@MainActor
struct GitStatus: Sendable {
    let isGitRepository: Bool
    let currentBranch: String?
    let hasUncommittedChanges: Bool
    let hasUnpushedCommits: Bool
    let ahead: Int
    let behind: Int
    let modifiedFiles: [String]
    let untrackedFiles: [String]
    let stagedFiles: [String]

    static let empty = GitStatus(
        isGitRepository: false,
        currentBranch: nil,
        hasUncommittedChanges: false,
        hasUnpushedCommits: false,
        ahead: 0,
        behind: 0,
        modifiedFiles: [],
        untrackedFiles: [],
        stagedFiles: []
    )

    var statusSummary: String {
        guard isGitRepository else { return "Not a Git repository" }
        guard let branch = currentBranch else { return "No branch" }

        var parts: [String] = [branch]

        if ahead > 0 {
            parts.append("↑\(ahead)")
        }
        if behind > 0 {
            parts.append("↓\(behind)")
        }
        if hasUncommittedChanges {
            let total = modifiedFiles.count + untrackedFiles.count + stagedFiles.count
            parts.append("\(total) changes")
        }

        return parts.joined(separator: " ")
    }
}
