import Foundation

@MainActor
class ClaudeService {
    // API Key method (fallback)
    private let apiKey: String?
    private var conversationHistory: [Message] = []
    private let baseURL = "https://api.anthropic.com/v1/messages"

    // Claude Code CLI method (preferred)
    private let cli: ClaudeCodeCLI
    private var currentSessionID: String?
    private var usesCLI: Bool

    init() {
        // Load API key from UserDefaults or Keychain
        self.apiKey = UserDefaults.standard.string(forKey: "claudeAPIKey")

        // Initialize CLI
        self.cli = ClaudeCodeCLI()
        // Re-enable CLI - wrapper is working in tests
        self.usesCLI = true

        // Log which method we're using
        if usesCLI {
            logInfo("✅ Using Claude Code CLI for Agent SDK features")
        } else {
            logWarning("⚠️ Using API key method (CLI disabled due to interactive mode)")
        }
    }

    /// Check if CLI is available
    func isCLIAvailable() -> Bool {
        return cli.isCLIInstalled()
    }

    /// Get CLI version
    func getCLIVersion() async -> String? {
        guard usesCLI else { return nil }
        return try? await cli.getVersion()
    }

    /// Check if authenticated with Claude.ai
    func isAuthenticated() async -> Bool {
        guard usesCLI else {
            // For API key method, check if key exists
            return apiKey != nil && !apiKey!.isEmpty
        }

        do {
            return try await cli.checkAuthStatus()
        } catch {
            logWarning("⚠️ Failed to check authentication status: \(error)")
            return false
        }
    }

    /// Trigger authentication flow
    func authenticate() async throws {
        guard usesCLI else {
            throw ClaudeError.cliNotAvailable
        }

        try await cli.authenticate()
    }

    /// Send a message to Claude with optional document context
    func sendMessage(_ message: String, context: (any FileSystemItem)?) async throws -> String {
        if usesCLI {
            // Use streaming internally and collect the full response
            logDebug("[CLAUDE-SERVICE] Using CLI method")
            let stream = try await sendMessageStreamingViaCLI(message, context: context)
            var fullResponse = ""
            var chunkCount = 0
            for await chunk in stream {
                chunkCount += 1
                logDebug("[CLAUDE-SERVICE] Received chunk #\(chunkCount): \(chunk.prefix(50))...")
                fullResponse += chunk
            }
            logDebug("[CLAUDE-SERVICE] Stream finished. Total chunks: \(chunkCount), Response length: \(fullResponse.count)")
            return fullResponse.isEmpty ? "No response from Claude (stream ended with 0 chunks)" : fullResponse
        } else {
            logDebug("[CLAUDE-SERVICE] Using API method")
            return try await sendMessageViaAPI(message, context: context)
        }
    }

    /// Send a message and stream the response token by token
    func sendMessageStreaming(_ message: String, context: (any FileSystemItem)?) async throws -> AsyncStream<String> {
        if usesCLI {
            return try await sendMessageStreamingViaCLI(message, context: context)
        } else {
            // For API fallback, just return the full response at once
            let response = try await sendMessageViaAPI(message, context: context)
            return AsyncStream { continuation in
                continuation.yield(response)
                continuation.finish()
            }
        }
    }

    /// Send a message with streaming and audit callback for tool usage
    func sendMessageStreamingWithAudit(_ message: String, context: (any FileSystemItem)?, onToolUse: @escaping @MainActor ([String: Any]) -> Void) async throws -> AsyncStream<String> {
        if usesCLI {
            return try await sendMessageStreamingViaCLIWithAudit(message, context: context, onToolUse: onToolUse)
        } else {
            // For API fallback, just return the full response at once (no tool tracking)
            let response = try await sendMessageViaAPI(message, context: context)
            return AsyncStream { continuation in
                continuation.yield(response)
                continuation.finish()
            }
        }
    }

    /// Send a message with streaming, audit callback, and multiple context items
    func sendMessageStreamingWithAudit(_ message: String, contextItems: [any FileSystemItem], onToolUse: @escaping @MainActor ([String: Any]) -> Void) async throws -> AsyncStream<String> {
        if usesCLI {
            return try await sendMessageStreamingViaCLIWithAudit(message, contextItems: contextItems, onToolUse: onToolUse)
        } else {
            // For API fallback, just return the full response at once (no tool tracking)
            let response = try await sendMessageViaAPI(message, contextItems: contextItems)
            return AsyncStream { continuation in
                continuation.yield(response)
                continuation.finish()
            }
        }
    }

    /// Send message using Claude Code CLI
    private func sendMessageViaCLI(_ message: String, context: (any FileSystemItem)?) async throws -> String {
        // Build context from selected items
        var contextText = ""
        if let context = context {
            contextText = buildContext(for: context)
        }

        // Create the prompt
        let prompt = buildPrompt(message: message, context: contextText)

        // Start session if needed
        if currentSessionID == nil {
            let options = ClaudeCodeOptions(
                systemPrompt: "You are a helpful assistant analyzing documents and helping with document editing tasks.",
                allowedTools: ["Read", "Write", "Edit", "Glob", "Grep"],
                permissionMode: "bypassPermissions"
            )
            currentSessionID = try await cli.startSession(options: options)
        }

        // Send query and collect response
        var responseText = ""

        for await cliMessage in try await cli.query(prompt) {
            switch cliMessage {
            case .assistant(let blocks):
                for block in blocks {
                    if case .text(let text) = block {
                        responseText += text
                    }
                }
            case .result(let isError, _, _):
                if isError {
                    throw ClaudeError.cliError("Claude returned an error")
                }
            default:
                break
            }
        }

        return responseText.isEmpty ? "No response from Claude" : responseText
    }

    /// Send message via CLI with streaming
    private func sendMessageStreamingViaCLI(_ message: String, context: (any FileSystemItem)?) async throws -> AsyncStream<String> {
        // Build context from selected items
        var contextText = ""
        if let context = context {
            contextText = buildContext(for: context)
        }

        // Create the prompt
        let prompt = buildPrompt(message: message, context: contextText)
        logDebug("[SWIFT] Sending message via CLI: \(message)")

        // Use the agent wrapper to call Claude Agent SDK
        return AsyncStream { continuation in
            Task.detached {
                // Get the wrapper path - try bundle first, then development location
                var wrapperPath: String?

                if let resourcePath = Bundle.main.resourcePath {
                    let bundledPath = "\(resourcePath)/claude-agent-sdk/agent-wrapper.mjs"
                    if FileManager.default.fileExists(atPath: bundledPath) {
                        wrapperPath = bundledPath
                        logDebug("[SWIFT] Using bundled wrapper at: \(bundledPath)")
                    }
                }

                // Fallback to development location
                if wrapperPath == nil {
                    let devPath = "/Users/robertwinder/Projects/betterdocs/BetterDocs/Resources/claude-agent-sdk/agent-wrapper.mjs"
                    if FileManager.default.fileExists(atPath: devPath) {
                        wrapperPath = devPath
                        logDebug("[SWIFT] Using development wrapper at: \(devPath)")
                    }
                }

                guard let finalWrapperPath = wrapperPath else {
                    logError("[SWIFT] Error: Could not find agent-wrapper.mjs")
                    continuation.yield("Error: Claude Agent SDK wrapper not found")
                    continuation.finish()
                    return
                }

                logDebug("[SWIFT] Wrapper path: \(finalWrapperPath)")
                logDebug("[SWIFT] Prompt: \(prompt)")

                // Find node path
                let nodePath = Self.findNodePath()
                logDebug("[SWIFT] Node path: \(nodePath ?? "not found")")

                guard let finalNodePath = nodePath else {
                    logError("[SWIFT] Error: Could not find node executable")
                    continuation.yield("Error: Node.js not found. Please install Node.js from https://nodejs.org/")
                    continuation.finish()
                    return
                }

                // Run the wrapper with node
                let task = Process()
                task.executableURL = URL(fileURLWithPath: finalNodePath)
                task.arguments = [finalWrapperPath, prompt]

                // Set up PATH environment to include common node locations
                var environment = ProcessInfo.processInfo.environment
                let nodeBinDir = (finalNodePath as NSString).deletingLastPathComponent
                if let existingPath = environment["PATH"] {
                    environment["PATH"] = "\(nodeBinDir):\(existingPath)"
                } else {
                    environment["PATH"] = nodeBinDir
                }
                task.environment = environment

                let outputPipe = Pipe()
                let errorPipe = Pipe()
                task.standardOutput = outputPipe
                task.standardError = errorPipe

                do {
                    logDebug("[SWIFT] Starting node process...")
                    try task.run()
                    logDebug("[SWIFT] Process started with PID: \(task.processIdentifier)")

                    // Read stderr in background to monitor wrapper debug output
                    Task {
                        let errorHandle = errorPipe.fileHandleForReading
                        for try await line in errorHandle.bytes.lines {
                            logDebug("[WRAPPER-STDERR] \(line)")
                        }
                    }

                    // Read output asynchronously using async bytes API
                    let handle = outputPipe.fileHandleForReading
                    logDebug("[SWIFT] Reading output from stdout...")

                    var lineCount = 0
                    // Use async iteration over file handle bytes
                    for try await line in handle.bytes.lines {
                        lineCount += 1
                        logDebug("[SWIFT] Line #\(lineCount): \(line.isEmpty ? "(empty)" : line.prefix(100))")

                        guard !line.isEmpty else { continue }

                        // Try to parse JSON response
                        if let data = line.data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            logDebug("[SWIFT] Parsed JSON: \(json)")

                            // Check message type from wrapper
                            if let messageType = json["type"] as? String {
                                if messageType == "text", let content = json["content"] as? String {
                                    logDebug("[SWIFT] Yielding text content: \(content.prefix(50))...")
                                    continuation.yield(content)
                                } else if messageType == "result" {
                                    logDebug("[SWIFT] Received result message")
                                    // Don't yield anything for result messages
                                } else if messageType == "tool_use" {
                                    logDebug("[SWIFT] Tool use detected: \(json["tool"] ?? "unknown")")
                                    // Don't yield tool use messages
                                } else if messageType == "error" {
                                    logError("[SWIFT] Error message: \(json["error"] ?? "unknown")")
                                    continuation.yield("Error: \(json["error"] as? String ?? "Unknown error")")
                                } else {
                                    logDebug("[SWIFT] Unknown message type: \(messageType)")
                                }
                            } else {
                                logDebug("[SWIFT] No type field found in JSON")
                            }
                        } else {
                            logDebug("[SWIFT] Failed to parse JSON from line: \(line.prefix(100))")
                        }
                    }

                    logDebug("[SWIFT] Finished reading stdout. Total lines: \(lineCount)")

                    // Wait for process to complete
                    task.waitUntilExit()

                    // Check exit code
                    if task.terminationStatus != 0 {
                        logError("[SWIFT] Process exited with code: \(task.terminationStatus)")
                    } else {
                        logDebug("[SWIFT] Process finished successfully")
                    }

                    continuation.finish()

                } catch {
                    logError("[SWIFT] Error: \(error.localizedDescription)")
                    continuation.yield("Error: \(error.localizedDescription)")
                    continuation.finish()
                }
            }
        }
    }

    /// Send message via CLI with streaming and audit callback for tool usage
    private func sendMessageStreamingViaCLIWithAudit(_ message: String, context: (any FileSystemItem)?, onToolUse: @escaping @MainActor ([String: Any]) -> Void) async throws -> AsyncStream<String> {
        // Build context from selected items
        var contextText = ""
        if let context = context {
            contextText = buildContext(for: context)
        }

        // Create the prompt
        let prompt = buildPrompt(message: message, context: contextText)
        logDebug("[SWIFT] Sending message via CLI with audit: \(message)")

        // Use the agent wrapper to call Claude Agent SDK
        return AsyncStream { continuation in
            Task.detached {
                // Get the wrapper path - try bundle first, then development location
                var wrapperPath: String?

                if let resourcePath = Bundle.main.resourcePath {
                    let bundledPath = "\(resourcePath)/claude-agent-sdk/agent-wrapper.mjs"
                    if FileManager.default.fileExists(atPath: bundledPath) {
                        wrapperPath = bundledPath
                        logDebug("[SWIFT] Using bundled wrapper at: \(bundledPath)")
                    }
                }

                // Fallback to development location
                if wrapperPath == nil {
                    let devPath = "/Users/robertwinder/Projects/betterdocs/BetterDocs/Resources/claude-agent-sdk/agent-wrapper.mjs"
                    if FileManager.default.fileExists(atPath: devPath) {
                        wrapperPath = devPath
                        logDebug("[SWIFT] Using development wrapper at: \(devPath)")
                    }
                }

                guard let finalWrapperPath = wrapperPath else {
                    logError("[SWIFT] Error: Could not find agent-wrapper.mjs")
                    continuation.yield("Error: Claude Agent SDK wrapper not found")
                    continuation.finish()
                    return
                }

                logDebug("[SWIFT] Wrapper path: \(finalWrapperPath)")
                logDebug("[SWIFT] Prompt: \(prompt)")

                // Find node path
                let nodePath = Self.findNodePath()
                logDebug("[SWIFT] Node path: \(nodePath ?? "not found")")

                guard let finalNodePath = nodePath else {
                    logError("[SWIFT] Error: Could not find node executable")
                    continuation.yield("Error: Node.js not found. Please install Node.js from https://nodejs.org/")
                    continuation.finish()
                    return
                }

                // Run the wrapper with node
                let task = Process()
                task.executableURL = URL(fileURLWithPath: finalNodePath)
                task.arguments = [finalWrapperPath, prompt]

                // Set up PATH environment to include common node locations
                var environment = ProcessInfo.processInfo.environment
                let nodeBinDir = (finalNodePath as NSString).deletingLastPathComponent
                if let existingPath = environment["PATH"] {
                    environment["PATH"] = "\(nodeBinDir):\(existingPath)"
                } else {
                    environment["PATH"] = nodeBinDir
                }
                task.environment = environment

                let outputPipe = Pipe()
                let errorPipe = Pipe()
                task.standardOutput = outputPipe
                task.standardError = errorPipe

                do {
                    logDebug("[SWIFT] Starting node process...")
                    try task.run()
                    logDebug("[SWIFT] Process started with PID: \(task.processIdentifier)")

                    // Read stderr in background to monitor wrapper debug output
                    Task {
                        let errorHandle = errorPipe.fileHandleForReading
                        for try await line in errorHandle.bytes.lines {
                            logDebug("[WRAPPER-STDERR] \(line)")
                        }
                    }

                    // Read output asynchronously using async bytes API
                    let handle = outputPipe.fileHandleForReading
                    logDebug("[SWIFT] Reading output from stdout...")

                    var lineCount = 0
                    // Use async iteration over file handle bytes
                    for try await line in handle.bytes.lines {
                        lineCount += 1
                        logDebug("[SWIFT] Line #\(lineCount): \(line.isEmpty ? "(empty)" : line.prefix(100))")

                        guard !line.isEmpty else { continue }

                        // Try to parse JSON response
                        if let data = line.data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            logDebug("[SWIFT] Parsed JSON: \(json)")

                            // Check message type from wrapper
                            if let messageType = json["type"] as? String {
                                if messageType == "text", let content = json["content"] as? String {
                                    logDebug("[SWIFT] Yielding text content: \(content.prefix(50))...")
                                    continuation.yield(content)
                                } else if messageType == "result" {
                                    logDebug("[SWIFT] Received result message")
                                    // Don't yield anything for result messages
                                } else if messageType == "tool_use" {
                                    logDebug("[SWIFT] Tool use detected: \(json["tool"] ?? "unknown")")
                                    // Call the audit callback on MainActor
                                    // Extract necessary fields - use nonisolated(unsafe) to bypass concurrency checking
                                    // This is safe because the dictionary is created locally and immediately consumed
                                    if let tool = json["tool"] as? String,
                                       let input = json["input"] as? [String: Any] {
                                        nonisolated(unsafe) let toolData: [String: Any] = ["tool": tool, "input": input]
                                        await MainActor.run {
                                            onToolUse(toolData)
                                        }
                                    }
                                    // Don't yield tool use messages
                                } else if messageType == "error" {
                                    logError("[SWIFT] Error message: \(json["error"] ?? "unknown")")
                                    continuation.yield("Error: \(json["error"] as? String ?? "Unknown error")")
                                } else {
                                    logDebug("[SWIFT] Unknown message type: \(messageType)")
                                }
                            } else {
                                logDebug("[SWIFT] No type field found in JSON")
                            }
                        } else {
                            logDebug("[SWIFT] Failed to parse JSON from line: \(line.prefix(100))")
                        }
                    }

                    logDebug("[SWIFT] Finished reading stdout. Total lines: \(lineCount)")

                    // Wait for process to complete
                    task.waitUntilExit()

                    // Check exit code
                    if task.terminationStatus != 0 {
                        logError("[SWIFT] Process exited with code: \(task.terminationStatus)")
                    } else {
                        logDebug("[SWIFT] Process finished successfully")
                    }

                    continuation.finish()

                } catch {
                    logError("[SWIFT] Error: \(error.localizedDescription)")
                    continuation.yield("Error: \(error.localizedDescription)")
                    continuation.finish()
                }
            }
        }
    }

    /// Send message via CLI with streaming, audit callback, and multiple context items
    private func sendMessageStreamingViaCLIWithAudit(_ message: String, contextItems: [any FileSystemItem], onToolUse: @escaping @MainActor ([String: Any]) -> Void) async throws -> AsyncStream<String> {
        // Build context from multiple items
        let contextText = buildContext(for: contextItems)

        // Create the prompt
        let prompt = buildPrompt(message: message, context: contextText)
        logDebug("[SWIFT] Sending message via CLI with audit and \(contextItems.count) context items: \(message)")

        // Use the agent wrapper to call Claude Agent SDK
        return AsyncStream { continuation in
            Task.detached {
                // Get the wrapper path - try bundle first, then development location
                var wrapperPath: String?

                if let resourcePath = Bundle.main.resourcePath {
                    let bundledPath = "\(resourcePath)/claude-agent-sdk/agent-wrapper.mjs"
                    if FileManager.default.fileExists(atPath: bundledPath) {
                        wrapperPath = bundledPath
                        logDebug("[SWIFT] Using bundled wrapper at: \(bundledPath)")
                    }
                }

                // Fallback to development location
                if wrapperPath == nil {
                    let devPath = "/Users/robertwinder/Projects/betterdocs/BetterDocs/Resources/claude-agent-sdk/agent-wrapper.mjs"
                    if FileManager.default.fileExists(atPath: devPath) {
                        wrapperPath = devPath
                        logDebug("[SWIFT] Using development wrapper at: \(devPath)")
                    }
                }

                guard let finalWrapperPath = wrapperPath else {
                    logError("[SWIFT] Error: Could not find agent-wrapper.mjs")
                    continuation.yield("Error: Claude Agent SDK wrapper not found")
                    continuation.finish()
                    return
                }

                logDebug("[SWIFT] Wrapper path: \(finalWrapperPath)")
                logDebug("[SWIFT] Prompt: \(prompt)")

                // Find node path
                let nodePath = Self.findNodePath()
                logDebug("[SWIFT] Node path: \(nodePath ?? "not found")")

                guard let finalNodePath = nodePath else {
                    logError("[SWIFT] Error: Could not find node executable")
                    continuation.yield("Error: Node.js not found. Please install Node.js from https://nodejs.org/")
                    continuation.finish()
                    return
                }

                // Run the wrapper with node
                let task = Process()
                task.executableURL = URL(fileURLWithPath: finalNodePath)
                task.arguments = [finalWrapperPath, prompt]

                // Set up PATH environment to include common node locations
                var environment = ProcessInfo.processInfo.environment
                let nodeBinDir = (finalNodePath as NSString).deletingLastPathComponent
                if let existingPath = environment["PATH"] {
                    environment["PATH"] = "\(nodeBinDir):\(existingPath)"
                } else {
                    environment["PATH"] = nodeBinDir
                }
                task.environment = environment

                let outputPipe = Pipe()
                let errorPipe = Pipe()
                task.standardOutput = outputPipe
                task.standardError = errorPipe

                do {
                    logDebug("[SWIFT] Starting node process...")
                    try task.run()
                    logDebug("[SWIFT] Process started with PID: \(task.processIdentifier)")

                    // Read stderr in background to monitor wrapper debug output
                    Task {
                        let errorHandle = errorPipe.fileHandleForReading
                        for try await line in errorHandle.bytes.lines {
                            logDebug("[WRAPPER-STDERR] \(line)")
                        }
                    }

                    // Read output asynchronously using async bytes API
                    let handle = outputPipe.fileHandleForReading
                    logDebug("[SWIFT] Reading output from stdout...")

                    var lineCount = 0
                    // Use async iteration over file handle bytes
                    for try await line in handle.bytes.lines {
                        lineCount += 1
                        logDebug("[SWIFT] Line #\(lineCount): \(line.isEmpty ? "(empty)" : line.prefix(100))")

                        guard !line.isEmpty else { continue }

                        // Try to parse JSON response
                        if let data = line.data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            logDebug("[SWIFT] Parsed JSON: \(json)")

                            // Check message type from wrapper
                            if let messageType = json["type"] as? String {
                                if messageType == "text", let content = json["content"] as? String {
                                    logDebug("[SWIFT] Yielding text content: \(content.prefix(50))...")
                                    continuation.yield(content)
                                } else if messageType == "result" {
                                    logDebug("[SWIFT] Received result message")
                                    // Don't yield anything for result messages
                                } else if messageType == "tool_use" {
                                    logDebug("[SWIFT] Tool use detected: \(json["tool"] ?? "unknown")")
                                    // Call the audit callback on MainActor
                                    // Extract necessary fields - use nonisolated(unsafe) to bypass concurrency checking
                                    // This is safe because the dictionary is created locally and immediately consumed
                                    if let tool = json["tool"] as? String,
                                       let input = json["input"] as? [String: Any] {
                                        nonisolated(unsafe) let toolData: [String: Any] = ["tool": tool, "input": input]
                                        await MainActor.run {
                                            onToolUse(toolData)
                                        }
                                    }
                                    // Don't yield tool use messages
                                } else if messageType == "error" {
                                    logError("[SWIFT] Error message: \(json["error"] ?? "unknown")")
                                    continuation.yield("Error: \(json["error"] as? String ?? "Unknown error")")
                                } else {
                                    logDebug("[SWIFT] Unknown message type: \(messageType)")
                                }
                            } else {
                                logDebug("[SWIFT] No type field found in JSON")
                            }
                        } else {
                            logDebug("[SWIFT] Failed to parse JSON from line: \(line.prefix(100))")
                        }
                    }

                    logDebug("[SWIFT] Finished reading stdout. Total lines: \(lineCount)")

                    // Wait for process to complete
                    task.waitUntilExit()

                    // Check exit code
                    if task.terminationStatus != 0 {
                        logError("[SWIFT] Process exited with code: \(task.terminationStatus)")
                    } else {
                        logDebug("[SWIFT] Process finished successfully")
                    }

                    continuation.finish()

                } catch {
                    logError("[SWIFT] Error: \(error.localizedDescription)")
                    continuation.yield("Error: \(error.localizedDescription)")
                    continuation.finish()
                }
            }
        }
    }

    /// Send message using API key (fallback)
    private func sendMessageViaAPI(_ message: String, context: (any FileSystemItem)?) async throws -> String {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            return "Please configure your Claude API key in Settings or install Claude Code CLI to use this feature."
        }

        // Build context from selected items
        var contextText = ""
        if let context = context {
            contextText = buildContext(for: context)
        }

        // Create the prompt
        let prompt = buildPrompt(message: message, context: contextText)

        // Add to conversation history
        conversationHistory.append(Message(role: "user", content: prompt))

        // Make API call
        let response = try await callClaudeAPI(messages: conversationHistory)

        // Add response to history
        conversationHistory.append(Message(role: "assistant", content: response))

        return response
    }

    /// Send message using API key with multiple context items (fallback)
    private func sendMessageViaAPI(_ message: String, contextItems: [any FileSystemItem]) async throws -> String {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            return "Please configure your Claude API key in Settings or install Claude Code CLI to use this feature."
        }

        // Build context from multiple items
        let contextText = buildContext(for: contextItems)

        // Create the prompt
        let prompt = buildPrompt(message: message, context: contextText)

        // Add to conversation history
        conversationHistory.append(Message(role: "user", content: prompt))

        // Make API call
        let response = try await callClaudeAPI(messages: conversationHistory)

        // Add response to history
        conversationHistory.append(Message(role: "assistant", content: response))

        return response
    }

    /// Execute a Claude Code function within document scope
    func executeFunction(
        _ function: String,
        on items: [any FileSystemItem],
        parameters: [String: Any] = [:]
    ) async throws -> ClaudeFunctionResult {
        // TODO: Implement Claude Code SDK integration
        // This will interface with the Claude Code agent SDK
        // to execute functions like summarize, extract, analyze, etc.

        return ClaudeFunctionResult(
            success: false,
            output: "Function execution not yet implemented",
            affectedItems: []
        )
    }

    /// Clear conversation history
    func clearHistory() {
        conversationHistory.removeAll()
    }

    // MARK: - Private Helpers

    private func buildContext(for item: any FileSystemItem) -> String {
        var context = "Current context:\n"
        context += "File: \(item.name)\n"
        context += "Path: \(item.path.path)\n"

        if let document = item as? Document {
            context += "Type: \(document.type.displayName)\n"
            context += "Size: \(document.formattedSize)\n\n"

            if let content = document.content, !content.isEmpty {
                // Limit content length
                let maxLength = 50000
                if content.count > maxLength {
                    let truncated = String(content.prefix(maxLength))
                    context += "Content (truncated):\n\(truncated)\n...[truncated]"
                } else {
                    context += "Content:\n\(content)"
                }
            }
        } else if let folder = item as? Folder {
            context += "Type: Folder\n"
            context += "Contains: \(folder.documentCount) files, \(folder.folderCount) folders\n\n"

            context += "Contents:\n"
            for child in folder.children.prefix(50) {
                context += "- \(child.name)\n"
            }
        }

        return context
    }

    private func buildContext(for items: [any FileSystemItem]) -> String {
        guard !items.isEmpty else { return "" }

        var context = "Context includes \(items.count) file(s) and folder(s):\n\n"

        for (index, item) in items.enumerated() {
            context += "--- File \(index + 1) of \(items.count) ---\n"
            context += "Name: \(item.name)\n"
            context += "Path: \(item.path.path)\n"

            if let document = item as? Document {
                context += "Type: \(document.type.displayName)\n"
                context += "Size: \(document.formattedSize)\n\n"

                if let content = document.content, !content.isEmpty {
                    // Limit content length per file to keep total context manageable
                    let maxLength = 30000 // Smaller limit per file when multiple files
                    if content.count > maxLength {
                        let truncated = String(content.prefix(maxLength))
                        context += "Content (truncated):\n\(truncated)\n...[truncated]\n\n"
                    } else {
                        context += "Content:\n\(content)\n\n"
                    }
                }
            } else if let folder = item as? Folder {
                context += "Type: Folder\n"
                context += "Contains: \(folder.documentCount) files, \(folder.folderCount) folders\n\n"

                context += "Contents:\n"
                for child in folder.children.prefix(50) {
                    context += "- \(child.name)\n"
                }
                context += "\n"
            }

            if index < items.count - 1 {
                context += "\n"
            }
        }

        return context
    }

    private func buildPrompt(message: String, context: String) -> String {
        if context.isEmpty {
            return message
        } else {
            return """
            \(context)

            User question: \(message)
            """
        }
    }

    private func callClaudeAPI(messages: [Message]) async throws -> String {
        // Prepare request
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let requestBody: [String: Any] = [
            "model": "claude-3-5-sonnet-20241022",
            "max_tokens": 4096,
            "messages": messages.map { ["role": $0.role, "content": $0.content] }
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        // Make request
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw ClaudeError.apiError(statusCode: httpResponse.statusCode)
        }

        // Parse response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstContent = content.first,
              let text = firstContent["text"] as? String else {
            throw ClaudeError.invalidResponse
        }

        return text
    }

    /// Generate a descriptive filename based on content
    func generateFilename(content: String, fileType: String) async throws -> String {
        let prompt = """
        Generate a concise, descriptive filename (without extension) for a document with the following content. \
        The filename should be 2-5 words, use hyphens instead of spaces, and be lowercase. \
        Only respond with the filename, nothing else.

        Content preview:
        \(content.prefix(500))
        """

        do {
            let response = try await sendMessage(prompt, context: nil)
            // Clean up the response
            let cleaned = response
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: " ", with: "-")
                .lowercased()
                .replacingOccurrences(of: "[^a-z0-9-]", with: "", options: .regularExpression)

            // Ensure it's not empty and not too long
            let truncated = String(cleaned.prefix(50))
            return truncated.isEmpty ? "untitled" : truncated
        } catch {
            logWarning("Failed to generate filename with Claude: \(error)")
            // Fallback to timestamp-based name
            let timestamp = Date().timeIntervalSince1970
            return "document-\(Int(timestamp))"
        }
    }

    /// Stop current CLI session
    func stopSession() {
        guard usesCLI else { return }
        cli.stopSession()
        currentSessionID = nil
    }

    /// Find the node executable path
    private nonisolated static func findNodePath() -> String? {
        // Common node installation locations
        let possiblePaths = [
            "/usr/local/bin/node",
            "/opt/homebrew/bin/node",
            "/usr/bin/node",
            "\(NSHomeDirectory())/.nvm/versions/node/*/bin/node"
        ]

        // Check each path
        for path in possiblePaths {
            if path.contains("*") {
                // Handle glob patterns (e.g., nvm installations)
                if let expanded = expandGlobPath(path) {
                    return expanded
                }
            } else if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }

        // Try using 'which node' as fallback
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", "which node"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

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
            logDebug("[SWIFT] Failed to run 'which node': \(error)")
        }

        return nil
    }

    /// Expand glob pattern to find first matching path
    private nonisolated static func expandGlobPath(_ pattern: String) -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", "ls -1 \(pattern) 2>/dev/null | head -n 1"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

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
            logDebug("[SWIFT] Failed to expand glob: \(error)")
        }

        return nil
    }
}

// MARK: - Models

struct Message {
    let role: String
    let content: String
}

struct ClaudeFunctionResult {
    let success: Bool
    let output: String
    let affectedItems: [UUID]
}

enum ClaudeError: LocalizedError {
    case invalidResponse
    case apiError(statusCode: Int)
    case missingAPIKey
    case cliNotAvailable
    case cliError(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from Claude API"
        case .apiError(let statusCode):
            return "Claude API error: \(statusCode)"
        case .missingAPIKey:
            return "Claude API key not configured"
        case .cliNotAvailable:
            return "Claude Code CLI is not available"
        case .cliError(let message):
            return "Claude Code CLI error: \(message)"
        }
    }
}
