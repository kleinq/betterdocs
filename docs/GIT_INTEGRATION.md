# Git Integration

This document describes the git features, workflows, and implementation in BetterDocs.

## Overview

BetterDocs provides integrated git version control through a native Swift service that executes git commands via shell.

**Features**:
- Repository status tracking
- File change visualization
- Commit with message
- Push to remote
- Pull from remote
- Branch information
- Ahead/behind tracking

---

## Git Service

**Location**: `Sources/Services/GitService.swift`

### Architecture

```
AppState
    ↓
GitService
    ↓
Process (executes /usr/bin/git)
    ↓
Shell Command
    ↓
Git Repository
```

### Core Methods

```swift
class GitService {
    // Check repository status
    func getStatus(at repoURL: URL) async throws -> GitStatus

    // Commit all changes
    func commit(message: String, at repoURL: URL) async throws

    // Push to remote
    func push(at repoURL: URL) async throws

    // Pull from remote
    func pull(at repoURL: URL) async throws

    // Stage all changes
    func stageAll(at repoURL: URL) async throws
}
```

---

## Git Status

### Detection

Checks if folder is a git repository:

```swift
func isGitRepository(at url: URL) -> Bool {
    let gitDir = url.appendingPathComponent(".git")
    var isDirectory: ObjCBool = false
    return FileManager.default.fileExists(
        atPath: gitDir.path,
        isDirectory: &isDirectory
    ) && isDirectory.boolValue
}
```

### Status Retrieval

Executes `git status --porcelain -b`:

```swift
func getStatus(at repoURL: URL) async throws -> GitStatus {
    let output = try await runGitCommand(
        ["status", "--porcelln", "-b"],
        at: repoURL
    )

    return parseStatus(output)
}
```

**Output Format**:
```
## main...origin/main [ahead 1, behind 2]
 M file1.txt
?? file2.txt
A  file3.txt
```

### Status Parsing

```swift
func parseStatus(_ output: String) -> GitStatus {
    let lines = output.split(separator: "\n")

    // Parse branch line
    let branchLine = lines.first { $0.hasPrefix("##") }
    let (branch, ahead, behind) = parseBranch(branchLine)

    var modifiedFiles: [String] = []
    var untrackedFiles: [String] = []
    var stagedFiles: [String] = []

    for line in lines.dropFirst() {
        let statusCode = String(line.prefix(2))
        let filePath = String(line.dropFirst(3))

        switch statusCode {
        case " M", "M ": modifiedFiles.append(filePath)
        case "??": untrackedFiles.append(filePath)
        case "A ", "AM": stagedFiles.append(filePath)
        case "MM":
            stagedFiles.append(filePath)
            modifiedFiles.append(filePath)
        default: break
        }
    }

    return GitStatus(
        isGitRepository: true,
        currentBranch: branch,
        hasUncommittedChanges: !modifiedFiles.isEmpty || !untrackedFiles.isEmpty,
        hasUnpushedCommits: ahead > 0,
        ahead: ahead,
        behind: behind,
        modifiedFiles: modifiedFiles,
        untrackedFiles: untrackedFiles,
        stagedFiles: stagedFiles
    )
}
```

**Status Codes**:
- `??`: Untracked file
- ` M`: Modified (not staged)
- `M `: Modified (staged)
- `MM`: Modified (both staged and unstaged)
- `A `: Added (staged)
- `D `: Deleted
- `R `: Renamed

---

## Git Operations

### Commit

**UI Flow**:
1. User clicks commit button in toolbar
2. GitCommitDialog appears
3. User enters commit message
4. AppState.performGitCommit() called
5. GitService stages all → commits

**Implementation**:

```swift
func commit(message: String, at repoURL: URL) async throws {
    // 1. Stage all changes
    try await stageAll(at: repoURL)

    // 2. Create commit message with attribution
    let fullMessage = """
    \(message)

    🤖 Generated with [Claude Code](https://claude.com/claude-code)

    Co-Authored-By: Claude <noreply@anthropic.com>
    """

    // 3. Execute commit
    try await runGitCommand(
        ["commit", "-m", fullMessage],
        at: repoURL
    )
}

func stageAll(at repoURL: URL) async throws {
    try await runGitCommand(["add", "."], at: repoURL)
}
```

**Validation**:
```swift
func validateCommitMessage(_ message: String) -> Bool {
    let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
    return !trimmed.isEmpty && trimmed.count >= 3
}
```

### Push

**UI Flow**:
1. User clicks push button
2. AppState.performGitPush() called
3. GitService pushes to remote
4. Status refreshed

**Implementation**:

```swift
func push(at repoURL: URL) async throws {
    try await runGitCommand(
        ["push"],
        at: repoURL,
        timeout: 30.0
    )
}
```

**Network Retry**:
```swift
func pushWithRetry(at repoURL: URL, retries: Int = 4) async throws {
    var attempt = 0
    var lastError: Error?

    while attempt < retries {
        do {
            try await push(at: repoURL)
            return  // Success
        } catch {
            lastError = error
            attempt += 1

            // Exponential backoff
            let delay = pow(2.0, Double(attempt))
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
    }

    throw lastError ?? GitError.networkFailure
}
```

### Pull

**UI Flow**:
1. User clicks pull button
2. AppState.performGitPull() called
3. GitService pulls from remote
4. Folder refreshed
5. Status updated

**Implementation**:

```swift
func pull(at repoURL: URL) async throws {
    try await runGitCommand(
        ["pull", "--rebase"],
        at: repoURL,
        timeout: 30.0
    )
}
```

**Conflict Handling**:
If pull fails due to conflicts:
```swift
do {
    try await gitService.pull(at: repoURL)
} catch GitError.hasConflicts {
    showError("Pull failed: Please resolve conflicts manually")
    // Could show conflict resolution UI here
} catch {
    showError("Pull failed: \(error)")
}
```

---

## Process Execution

### Command Runner

```swift
private func runGitCommand(
    _ args: [String],
    at repoURL: URL,
    timeout: TimeInterval = 10.0
) async throws -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
    process.arguments = args
    process.currentDirectoryURL = repoURL

    let outputPipe = Pipe()
    let errorPipe = Pipe()
    process.standardOutput = outputPipe
    process.standardError = errorPipe

    try process.run()

    // Timeout handling
    let timeoutTask = Task {
        try await Task.sleep(for: .seconds(timeout))
        if process.isRunning {
            process.terminate()
        }
    }

    process.waitUntilExit()
    timeoutTask.cancel()

    // Read output
    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: outputData, encoding: .utf8) ?? ""

    // Check exit code
    guard process.terminationStatus == 0 else {
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let error = String(data: errorData, encoding: .utf8) ?? "Unknown error"
        throw GitError.commandFailed(error)
    }

    return output
}
```

### Security

**Safe Command Construction**:
```swift
// ✅ Good: Arguments array (no shell injection)
process.arguments = ["commit", "-m", userMessage]

// ❌ Bad: Shell string (vulnerable to injection)
let command = "git commit -m '\(userMessage)'"
```

---

## UI Components

### Toolbar Status Indicator

**Location**: `Sources/Views/Toolbar/ToolbarView.swift:84`

Shows git status in toolbar:

```swift
if appState.gitStatus.isGitRepository {
    Button(action: { appState.showGitPanel.toggle() }) {
        HStack(spacing: 4) {
            Image(systemName: "arrow.branch")
            Text(appState.gitStatus.currentBranch ?? "")

            // Changes indicator
            if appState.gitStatus.hasUncommittedChanges {
                Text("•").foregroundColor(.orange)
            }

            // Ahead/behind
            if appState.gitStatus.ahead > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "arrow.up")
                    Text("\(appState.gitStatus.ahead)")
                }
            }

            if appState.gitStatus.behind > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "arrow.down")
                    Text("\(appState.gitStatus.behind)")
                }
            }
        }
    }
}
```

**Indicators**:
- Branch name
- Orange dot if uncommitted changes
- ↑ with number if commits ahead
- ↓ with number if commits behind

### Git File List Panel

**Location**: `Sources/Views/Git/GitFileListView.swift`

Side panel showing file changes:

**Sections**:
1. **Staged Changes** (green) - Files ready to commit
2. **Modified Files** (orange) - Changed files
3. **Untracked Files** (blue) - New files
4. **Remote Status** - Ahead/behind info

**Features**:
- Click file to open
- File path display
- Status indicators
- Empty state for clean directory

**Opening Files**:
```swift
func openFile(path: String) {
    guard let rootFolder = appState.rootFolder else { return }

    let fullPath = rootFolder.path.appendingPathComponent(path)
    if let item = findItem(at: fullPath, in: rootFolder) {
        appState.openInTab(item)
        appState.showGitPanel = false  // Auto-close panel
    }
}
```

### Commit Dialog

**Location**: `Sources/Views/Dialogs/GitCommitDialog.swift`

Modal for entering commit message:

**UI**:
- Multi-line text editor
- File count summary
- Commit/Cancel buttons

**Validation**:
- Minimum 3 characters
- Non-empty after trimming
- Shows error if invalid

---

## Integration with AppState

### Auto-Refresh

Git status refreshed when:
- Folder opened
- File created/modified/deleted
- After commit/push/pull
- Manual refresh triggered

```swift
func refreshGitStatus() {
    guard let rootFolder = rootFolder else { return }

    Task {
        let status = try? await gitService.getStatus(at: rootFolder.path)
        await MainActor.run {
            self.gitStatus = status ?? .notRepository
        }
    }
}
```

### Operation State

Track ongoing operations:

```swift
@Observable
class AppState {
    var isPerformingGitOperation: Bool = false

    func performGitCommit(message: String) {
        guard !isPerformingGitOperation else { return }

        isPerformingGitOperation = true
        defer { isPerformingGitOperation = false }

        Task {
            do {
                try await gitService.commit(
                    message: message,
                    at: rootFolder.path
                )
                await refreshFolder()
                await refreshGitStatus()
            } catch {
                showError("Commit failed: \(error)")
            }
        }
    }
}
```

**UI Bindings**:
```swift
Button("Commit") {
    appState.performGitCommit(message)
}
.disabled(appState.isPerformingGitOperation)
```

---

## Workflows

### Typical Commit Workflow

1. User makes changes to files
2. File watcher detects changes
3. Git status auto-refreshes
4. Orange dot appears in toolbar
5. User clicks git status → sees file list
6. User clicks commit button
7. Commit dialog appears
8. User enters message
9. Click "Commit"
10. All files staged
11. Commit created
12. Status refreshed
13. Dialog closes

### Push After Commit

1. After commit, ahead count increases
2. Push button becomes enabled
3. User clicks push
4. GitService pushes to remote
5. If network error, retry with backoff
6. Status refreshed
7. Ahead count resets to 0

### Pull Before Push

1. User clicks pull button
2. GitService pulls from remote
3. If behind, updates local branch
4. If conflicts, shows error
5. Folder refreshed to show new files
6. Status updated

---

## Error Handling

### Git Errors

```swift
enum GitError: Error {
    case notARepository
    case commandFailed(String)
    case networkFailure
    case hasConflicts
    case authenticationFailed
    case timeout
}
```

### User-Friendly Messages

```swift
func handleGitError(_ error: Error) {
    let message: String

    switch error {
    case GitError.notARepository:
        message = "This folder is not a git repository"
    case GitError.networkFailure:
        message = "Network error. Check your connection and try again."
    case GitError.hasConflicts:
        message = "Pull failed due to conflicts. Please resolve manually."
    case GitError.authenticationFailed:
        message = "Authentication failed. Check your git credentials."
    default:
        message = "Git operation failed: \(error.localizedDescription)"
    }

    showError(message)
}
```

---

## Future Enhancements

### Planned Features

1. **Visual Diff**: Show file changes inline
2. **Branch Management**: Create, switch, merge branches
3. **Commit History**: View past commits
4. **Selective Staging**: Stage specific files, not all
5. **Conflict Resolution**: Built-in merge conflict resolver
6. **Git Log**: Timeline view of commits
7. **Blame**: Show who changed each line
8. **Stash**: Save work in progress

### Architecture Improvements

1. **libgit2 Integration**: Use native library instead of Process
2. **Background Sync**: Auto-pull/push in background
3. **Credential Management**: Keychain integration
4. **SSH Support**: SSH key management

---

**Last Updated**: 2025-11-20
