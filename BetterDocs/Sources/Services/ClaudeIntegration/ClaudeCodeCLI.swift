import Foundation

/// Manages interaction with the Claude Code CLI
@MainActor
class ClaudeCodeCLI {
    private var process: Process?
    private var inputPipe: Pipe?
    private var outputPipe: Pipe?
    private var errorPipe: Pipe?
    private var sessionID: String?

    // Configuration
    private let cliPath: String
    private let workingDirectory: URL

    enum CLIError: LocalizedError {
        case cliNotFound
        case processError(String)
        case authenticationRequired
        case invalidResponse
        case sessionNotStarted

        var errorDescription: String? {
            switch self {
            case .cliNotFound:
                return "Claude Code CLI not found. Please install it first."
            case .processError(let message):
                return "CLI process error: \(message)"
            case .authenticationRequired:
                return "Authentication required. Please authenticate with Claude.ai"
            case .invalidResponse:
                return "Invalid response from Claude Code CLI"
            case .sessionNotStarted:
                return "No active session. Please start a session first."
            }
        }
    }

    init(workingDirectory: URL? = nil) {
        // Try to find Claude Code CLI in common locations
        self.cliPath = Self.findCLIPath() ?? "/usr/local/bin/claude"
        self.workingDirectory = workingDirectory ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }

    /// Find the Claude Code CLI executable
    private static func findCLIPath() -> String? {
        // First, check for bundled CLI in app resources
        if let bundledPath = getBundledCLIPath() {
            print("📦 Using bundled Claude Agent SDK: \(bundledPath)")
            return bundledPath
        } else {
            print("⚠️ Bundled Claude Agent SDK not found, checking system paths...")
        }

        // Then check common installation paths
        let possiblePaths = [
            "/usr/local/bin/claude",
            "/opt/homebrew/bin/claude",
            "\(NSHomeDirectory())/.local/bin/claude",
            "\(NSHomeDirectory())/.npm-global/bin/claude",
            "\(NSHomeDirectory())/.claude/local/claude"
        ]

        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }

        // Try to find via 'which' command
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        task.arguments = ["claude"]

        let pipe = Pipe()
        task.standardOutput = pipe

        do {
            try task.run()
            task.waitUntilExit()

            if task.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !path.isEmpty {
                    return path
                }
            }
        } catch {
            print("Failed to find Claude CLI: \(error)")
        }

        return nil
    }

    /// Get path to bundled CLI in app bundle
    private static func getBundledCLIPath() -> String? {
        // Get the main bundle's resource path
        guard let resourcePath = Bundle.main.resourcePath else {
            return nil
        }

        // Use our Node.js wrapper for the Claude Agent SDK
        let bundledWrapper = "\(resourcePath)/claude-agent-sdk/agent-wrapper.mjs"

        if FileManager.default.fileExists(atPath: bundledWrapper) {
            return bundledWrapper
        }

        return nil
    }

    /// Check if Claude Code CLI is installed
    func isCLIInstalled() -> Bool {
        return FileManager.default.fileExists(atPath: cliPath)
    }

    /// Get CLI version
    func getVersion() async throws -> String {
        // For bundled SDK (.js file), read version from package.json
        if cliPath.hasSuffix(".js") {
            // Path: .../claude-agent-sdk/node_modules/@anthropic-ai/claude-agent-sdk/cli.js
            // Package.json is in the same directory
            let cliURL = URL(fileURLWithPath: cliPath)
            let packageJsonPath = cliURL.deletingLastPathComponent().appendingPathComponent("package.json").path

            if let packageData = try? Data(contentsOf: URL(fileURLWithPath: packageJsonPath)),
               let json = try? JSONSerialization.jsonObject(with: packageData) as? [String: Any],
               let version = json["version"] as? String {
                return version
            }
        }

        // Fallback to running --version command for system CLI
        let task = Process()

        if cliPath.hasSuffix(".js") {
            task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            task.arguments = ["node", cliPath, "--version"]
        } else {
            task.executableURL = URL(fileURLWithPath: cliPath)
            task.arguments = ["--version"]
        }

        let pipe = Pipe()
        task.standardOutput = pipe

        try task.run()
        task.waitUntilExit()

        guard task.terminationStatus == 0 else {
            throw CLIError.processError("Failed to get version")
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown"
    }

    /// Check authentication status
    func checkAuthStatus() async throws -> Bool {
        // The SDK uses ~/.claude directory for auth, which should be automatically detected
        // Since the user is already authenticated system-wide, just check if the config exists
        let claudeConfigPath = NSHomeDirectory() + "/.claude"
        let fileManager = FileManager.default

        // Check if .claude directory exists (indicates user has authenticated before)
        if fileManager.fileExists(atPath: claudeConfigPath) {
            print("✅ Found Claude config at \(claudeConfigPath)")
            return true
        }

        print("⚠️ No Claude config found at \(claudeConfigPath)")
        return false
    }

    /// Trigger authentication flow
    func authenticate() async throws {
        let task = Process()

        if cliPath.hasSuffix(".js") {
            task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            task.arguments = ["node", cliPath, "auth", "login"]
        } else {
            task.executableURL = URL(fileURLWithPath: cliPath)
            task.arguments = ["auth", "login"]
        }

        try task.run()
        task.waitUntilExit()

        guard task.terminationStatus == 0 else {
            throw CLIError.authenticationRequired
        }
    }

    /// Start an interactive session with Claude
    func startSession(options: ClaudeCodeOptions? = nil) async throws -> String {
        guard isCLIInstalled() else {
            throw CLIError.cliNotFound
        }

        // Build arguments
        var args = ["agent", "query", "--json"]

        if let opts = options {
            if let systemPrompt = opts.systemPrompt {
                args.append(contentsOf: ["--system-prompt", systemPrompt])
            }

            if !opts.allowedTools.isEmpty {
                args.append(contentsOf: ["--allowed-tools", opts.allowedTools.joined(separator: ",")])
            }

            if let permissionMode = opts.permissionMode {
                args.append(contentsOf: ["--permission-mode", permissionMode])
            }

            if let model = opts.model {
                args.append(contentsOf: ["--model", model])
            }

            args.append(contentsOf: ["--cwd", workingDirectory.path])
        }

        // Create pipes for communication
        inputPipe = Pipe()
        outputPipe = Pipe()
        errorPipe = Pipe()

        // Configure process
        process = Process()

        if cliPath.hasSuffix(".js") {
            process?.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process?.arguments = ["node", cliPath] + args
        } else {
            process?.executableURL = URL(fileURLWithPath: cliPath)
            process?.arguments = args
        }

        process?.standardInput = inputPipe
        process?.standardOutput = outputPipe
        process?.standardError = errorPipe
        process?.currentDirectoryURL = workingDirectory

        // Start process
        try process?.run()

        // Generate session ID
        sessionID = UUID().uuidString

        print("✅ Started Claude Code session: \(sessionID!)")
        return sessionID!
    }

    /// Send a query to Claude
    func query(_ prompt: String) async throws -> AsyncStream<ClaudeMessage> {
        guard process?.isRunning == true else {
            throw CLIError.sessionNotStarted
        }

        guard let inputPipe = inputPipe,
              let outputPipe = outputPipe else {
            throw CLIError.sessionNotStarted
        }

        // Send prompt
        let promptData = "\(prompt)\n".data(using: .utf8)!
        try inputPipe.fileHandleForWriting.write(contentsOf: promptData)

        // Return stream of messages
        return AsyncStream { continuation in
            Task {
                do {
                    // Read JSON output line by line
                    let handle = outputPipe.fileHandleForReading

                    while process?.isRunning == true {
                        if let line = try handle.readLine() {
                            if let message = try? self.parseMessage(from: line) {
                                continuation.yield(message)

                                // Check if this is the final message
                                if case .result = message {
                                    continuation.finish()
                                    return
                                }
                            }
                        }
                    }

                    continuation.finish()
                } catch {
                    print("Error reading output: \(error)")
                    continuation.finish()
                }
            }
        }
    }

    /// Parse a JSON message from CLI output
    private func parseMessage(from jsonString: String) throws -> ClaudeMessage {
        let data = jsonString.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        let type = json["type"] as? String ?? "unknown"

        switch type {
        case "user":
            let content = json["content"] as? String ?? ""
            return .user(content: content)

        case "assistant":
            let content = json["content"] as? [[String: Any]] ?? []
            var blocks: [ContentBlock] = []

            for block in content {
                if let text = block["text"] as? String {
                    blocks.append(.text(text))
                } else if let toolUse = block["tool_use"] as? [String: Any],
                          let name = toolUse["name"] as? String,
                          let input = toolUse["input"] as? [String: Any] {
                    blocks.append(.toolUse(name: name, input: input))
                }
            }

            return .assistant(content: blocks)

        case "system":
            let subtype = json["subtype"] as? String ?? ""
            let data = json["data"] as? [String: Any] ?? [:]
            return .system(subtype: subtype, data: data)

        case "result":
            let isError = json["is_error"] as? Bool ?? false
            let sessionId = json["session_id"] as? String
            let numTurns = json["num_turns"] as? Int ?? 0
            return .result(isError: isError, sessionId: sessionId, numTurns: numTurns)

        default:
            return .system(subtype: "unknown", data: json)
        }
    }

    /// Stop the current session
    func stopSession() {
        process?.terminate()
        process = nil
        sessionID = nil
        inputPipe = nil
        outputPipe = nil
        errorPipe = nil

        print("🛑 Stopped Claude Code session")
    }

    /// Interrupt the current task
    func interrupt() {
        process?.interrupt()
    }
}

// MARK: - Options

struct ClaudeCodeOptions {
    var systemPrompt: String?
    var allowedTools: [String] = []
    var permissionMode: String? // "default", "acceptEdits", "plan", "bypassPermissions"
    var model: String? // "sonnet", "opus", "haiku"
    var maxTurns: Int?

    static var `default`: ClaudeCodeOptions {
        ClaudeCodeOptions(
            allowedTools: ["Read", "Write", "Edit", "Bash", "Glob", "Grep"],
            permissionMode: "acceptEdits"
        )
    }
}

// MARK: - Message Types

enum ClaudeMessage: @unchecked Sendable {
    case user(content: String)
    case assistant(content: [ContentBlock])
    case system(subtype: String, data: [String: Any])
    case result(isError: Bool, sessionId: String?, numTurns: Int)
}

enum ContentBlock: @unchecked Sendable {
    case text(String)
    case toolUse(name: String, input: [String: Any])
    case toolResult(toolUseId: String, content: String, isError: Bool)
}

// MARK: - FileHandle Extension

extension FileHandle {
    func readLine() throws -> String? {
        var data = Data()
        let newline = "\n".data(using: .utf8)![0]

        while true {
            let byte = try read(upToCount: 1)
            if byte == nil || byte!.isEmpty {
                if data.isEmpty {
                    return nil
                }
                break
            }

            if byte![0] == newline {
                break
            }

            data.append(byte!)
        }

        return String(data: data, encoding: .utf8)
    }
}
