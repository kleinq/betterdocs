import Foundation

/// Service for managing Git operations (commit, push, pull, status)
@MainActor
class GitService: ObservableObject {
    @Published var lastError: GitError?
    @Published var currentStatus: GitStatus = .empty

    // MARK: - Git Status

    /// Check if a folder is a Git repository and get its status
    func getStatus(at folderPath: URL) async throws -> GitStatus {
        // Check if .git directory exists
        let gitDir = folderPath.appendingPathComponent(".git")
        guard FileManager.default.fileExists(atPath: gitDir.path) else {
            return .empty
        }

        // Get current branch
        let branch = try await getCurrentBranch(at: folderPath)

        // Get status information
        let statusOutput = try await executeGitCommand(["status", "--porcelain", "-b"], at: folderPath)
        let (modifiedFiles, untrackedFiles, stagedFiles) = parseStatusOutput(statusOutput)

        // Get ahead/behind information
        let (ahead, behind) = try await getAheadBehind(at: folderPath)

        let status = GitStatus(
            isGitRepository: true,
            currentBranch: branch,
            hasUncommittedChanges: !modifiedFiles.isEmpty || !untrackedFiles.isEmpty || !stagedFiles.isEmpty,
            hasUnpushedCommits: ahead > 0,
            ahead: ahead,
            behind: behind,
            modifiedFiles: modifiedFiles,
            untrackedFiles: untrackedFiles,
            stagedFiles: stagedFiles
        )

        currentStatus = status
        return status
    }

    /// Refresh the current status
    func refreshStatus(at folderPath: URL) async {
        do {
            _ = try await getStatus(at: folderPath)
        } catch {
            // Silently fail for refresh - just keep old status
            print("Failed to refresh git status: \(error.localizedDescription)")
        }
    }

    // MARK: - Git Operations

    /// Stage all changes
    func stageAll(at folderPath: URL) async throws {
        _ = try await executeGitCommand(["add", "."], at: folderPath)
        await refreshStatus(at: folderPath)
    }

    /// Commit staged changes with a message
    func commit(message: String, at folderPath: URL) async throws {
        guard !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw GitError.invalidCommitMessage
        }

        // Stage all changes first
        try await stageAll(at: folderPath)

        // Check if there are changes to commit
        let status = try await getStatus(at: folderPath)
        guard status.hasUncommittedChanges else {
            throw GitError.nothingToCommit
        }

        // Commit
        _ = try await executeGitCommand(["commit", "-m", message], at: folderPath)
        await refreshStatus(at: folderPath)
    }

    /// Push changes to remote repository
    func push(at folderPath: URL) async throws {
        let status = try await getStatus(at: folderPath)

        // Check if there are changes to push
        guard status.ahead > 0 || status.hasUncommittedChanges else {
            throw GitError.nothingToPush
        }

        // Get current branch
        guard let branch = status.currentBranch else {
            throw GitError.noBranch
        }

        // Try to push with retry logic for network errors
        var lastError: Error?
        let maxRetries = 4
        let delays: [UInt64] = [2_000_000_000, 4_000_000_000, 8_000_000_000, 16_000_000_000] // 2s, 4s, 8s, 16s in nanoseconds

        for attempt in 0..<maxRetries {
            do {
                // Push with upstream set
                _ = try await executeGitCommand(["push", "-u", "origin", branch], at: folderPath)
                await refreshStatus(at: folderPath)
                return // Success!
            } catch let error as GitError {
                lastError = error
                // Check if this is a network error that we should retry
                if case .commandFailed(let message) = error,
                   message.contains("Could not resolve host") ||
                   message.contains("Failed to connect") ||
                   message.contains("Connection timed out") {
                    // Network error - retry if we have attempts left
                    if attempt < maxRetries - 1 {
                        let delay = delays[attempt]
                        print("Push failed with network error, retrying in \(delay / 1_000_000_000)s...")
                        try await Task.sleep(nanoseconds: delay)
                        continue
                    }
                }
                // Non-network error or max retries reached - throw immediately
                throw error
            } catch {
                lastError = error
                throw error
            }
        }

        // If we get here, we exhausted retries
        if let error = lastError {
            throw error
        } else {
            throw GitError.commandFailed("Push failed after \(maxRetries) attempts")
        }
    }

    /// Pull changes from remote repository
    func pull(at folderPath: URL) async throws {
        // Get current branch
        let status = try await getStatus(at: folderPath)
        guard let branch = status.currentBranch else {
            throw GitError.noBranch
        }

        // Try to pull with retry logic for network errors
        var lastError: Error?
        let maxRetries = 4
        let delays: [UInt64] = [2_000_000_000, 4_000_000_000, 8_000_000_000, 16_000_000_000] // 2s, 4s, 8s, 16s

        for attempt in 0..<maxRetries {
            do {
                // Pull from origin
                _ = try await executeGitCommand(["pull", "origin", branch], at: folderPath)
                await refreshStatus(at: folderPath)
                return // Success!
            } catch let error as GitError {
                lastError = error
                // Check if this is a network error that we should retry
                if case .commandFailed(let message) = error,
                   message.contains("Could not resolve host") ||
                   message.contains("Failed to connect") ||
                   message.contains("Connection timed out") {
                    // Network error - retry if we have attempts left
                    if attempt < maxRetries - 1 {
                        let delay = delays[attempt]
                        print("Pull failed with network error, retrying in \(delay / 1_000_000_000)s...")
                        try await Task.sleep(nanoseconds: delay)
                        continue
                    }
                }
                // Non-network error or max retries reached - throw immediately
                throw error
            } catch {
                lastError = error
                throw error
            }
        }

        // If we get here, we exhausted retries
        if let error = lastError {
            throw error
        } else {
            throw GitError.commandFailed("Pull failed after \(maxRetries) attempts")
        }
    }

    // MARK: - Helper Methods

    private func getCurrentBranch(at folderPath: URL) async throws -> String? {
        let output = try await executeGitCommand(["branch", "--show-current"], at: folderPath)
        let branch = output.trimmingCharacters(in: .whitespacesAndNewlines)
        return branch.isEmpty ? nil : branch
    }

    private func getAheadBehind(at folderPath: URL) async throws -> (ahead: Int, behind: Int) {
        do {
            let output = try await executeGitCommand(["rev-list", "--left-right", "--count", "HEAD...@{upstream}"], at: folderPath)
            let components = output.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "\t")
            if components.count == 2,
               let ahead = Int(components[0]),
               let behind = Int(components[1]) {
                return (ahead, behind)
            }
        } catch {
            // No upstream configured or other error - return 0, 0
        }
        return (0, 0)
    }

    private func parseStatusOutput(_ output: String) -> (modified: [String], untracked: [String], staged: [String]) {
        var modified: [String] = []
        var untracked: [String] = []
        var staged: [String] = []

        let lines = output.split(separator: "\n")
        for line in lines {
            if line.hasPrefix("##") {
                // Branch information line - skip
                continue
            }

            guard line.count >= 3 else { continue }

            let statusCode = String(line.prefix(2))
            let filename = String(line.dropFirst(3))

            // Parse git status codes
            let x = statusCode.first ?? " "
            let y = statusCode.last ?? " "

            if x != " " && x != "?" {
                staged.append(filename)
            }
            if y == "M" || y == "D" {
                modified.append(filename)
            }
            if statusCode == "??" {
                untracked.append(filename)
            }
        }

        return (modified, untracked, staged)
    }

    /// Execute a git command and return its output
    private func executeGitCommand(_ arguments: [String], at folderPath: URL) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = arguments
        process.currentDirectoryURL = folderPath

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

            let output = String(data: outputData, encoding: .utf8) ?? ""
            let errorOutput = String(data: errorData, encoding: .utf8) ?? ""

            guard process.terminationStatus == 0 else {
                let errorMessage = errorOutput.isEmpty ? output : errorOutput
                throw GitError.commandFailed(errorMessage.trimmingCharacters(in: .whitespacesAndNewlines))
            }

            return output
        } catch let error as GitError {
            throw error
        } catch {
            throw GitError.executionFailed(error.localizedDescription)
        }
    }
}

// MARK: - Git Errors

enum GitError: LocalizedError {
    case notGitRepository
    case noBranch
    case invalidCommitMessage
    case nothingToCommit
    case nothingToPush
    case commandFailed(String)
    case executionFailed(String)

    var errorDescription: String? {
        switch self {
        case .notGitRepository:
            return "This folder is not a Git repository"
        case .noBranch:
            return "No current branch detected"
        case .invalidCommitMessage:
            return "Commit message cannot be empty"
        case .nothingToCommit:
            return "No changes to commit"
        case .nothingToPush:
            return "No changes to push"
        case .commandFailed(let message):
            return "Git command failed: \(message)"
        case .executionFailed(let message):
            return "Failed to execute git command: \(message)"
        }
    }
}
