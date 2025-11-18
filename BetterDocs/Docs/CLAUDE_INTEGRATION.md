# Claude Code SDK Integration Plan

## Overview

This document outlines the integration strategy for incorporating Claude Code agent capabilities into BetterDocs.

## Integration Approach

### Phase 1: Direct API Integration (Current)

The current implementation uses direct Claude API calls for basic chat functionality:

- Basic chat interface in sidebar
- Document context passing
- Simple Q&A about documents

**Implementation**: `ClaudeService.swift`

### Phase 2: Claude Code SDK Integration (Planned)

Integrate the official Claude Code SDK to enable advanced agent capabilities:

#### Key Capabilities

1. **Document Operations**
   - Summarize documents
   - Extract structured information
   - Compare multiple documents
   - Generate document outlines
   - Translate content

2. **Search & Analysis**
   - Natural language search
   - Semantic search across documents
   - Topic clustering
   - Sentiment analysis
   - Key phrase extraction

3. **File Management**
   - Bulk rename operations
   - Organize files by content
   - Tag generation
   - Duplicate detection
   - Content-based categorization

4. **Code Integration**
   - Execute Claude Code tools within document scope
   - Multi-step workflows
   - Automated document processing pipelines

## Technical Architecture

### SDK Integration Points

```swift
// Proposed SDK wrapper
class ClaudeCodeSDK {
    // Initialize with API credentials
    init(apiKey: String)

    // Execute a tool within document scope
    func executeTool(
        name: String,
        scope: [FileSystemItem],
        parameters: [String: Any]
    ) async throws -> ToolResult

    // Start an agent session
    func startSession(
        context: DocumentContext
    ) async throws -> AgentSession

    // Multi-turn conversation
    func continueSession(
        session: AgentSession,
        message: String
    ) async throws -> AgentResponse
}
```

### Document Context Scope

The SDK will have access to:

1. **Single Document Scope**
   - Currently selected file
   - Full content access
   - Metadata

2. **Folder Scope**
   - All files in selected folder
   - Recursive subfolder access (configurable)
   - Aggregated metadata

3. **Custom Scope**
   - User-selected multiple files
   - Search results
   - Tagged collections

### Security & Permissions

#### Sandboxing Strategy

```swift
class ScopedDocumentAccess {
    // Grant read access to specific paths
    func grantReadAccess(to: [URL]) -> AccessToken

    // Grant write access (requires user approval)
    func grantWriteAccess(to: [URL]) -> AccessToken

    // Revoke access
    func revokeAccess(token: AccessToken)
}
```

#### User Approval Flow

1. Claude suggests an action
2. Display approval dialog with:
   - Action description
   - Affected files
   - Preview of changes
3. User approves/denies
4. Execute with granted permissions
5. Log action for audit trail

### Proposed Features

#### 1. Smart Summarization

```swift
// Example usage
let summary = try await claude.summarize(
    document: selectedDocument,
    style: .executive,  // executive, technical, simple
    length: .medium     // short, medium, long
)
```

#### 2. Multi-Document Analysis

```swift
// Compare documents
let comparison = try await claude.compare(
    documents: [doc1, doc2, doc3],
    aspects: [.content, .structure, .tone]
)

// Find common themes
let themes = try await claude.extractThemes(
    from: folder,
    minFrequency: 3
)
```

#### 3. Intelligent Search

```swift
// Natural language search
let results = try await claude.search(
    query: "documents about machine learning from last month",
    in: rootFolder
)

// Semantic search
let similar = try await claude.findSimilar(
    to: selectedDocument,
    in: folder,
    threshold: 0.8
)
```

#### 4. Automated Workflows

```swift
// Define a workflow
let workflow = ClaudeWorkflow(name: "Process Research Papers")
    .step(.extractMetadata)
    .step(.generateSummary)
    .step(.extractKeyPhrases)
    .step(.categorize)
    .step(.generateBibliography)

// Execute workflow
let results = try await claude.executeWorkflow(
    workflow,
    on: researchPapersFolder
)
```

#### 5. Content Extraction

```swift
// Extract structured data
let tables = try await claude.extractTables(from: pdfDocument)
let citations = try await claude.extractCitations(from: document)
let entities = try await claude.extractEntities(
    from: document,
    types: [.person, .organization, .location, .date]
)
```

## UI Integration Points

### 1. Context Menu Integration

Right-click menu options:
- "Summarize with Claude"
- "Extract information..."
- "Find similar documents"
- "Ask Claude about this file"

### 2. Toolbar Actions

Quick access buttons:
- Smart search
- Bulk operations
- Document insights

### 3. Sidebar Features

Enhanced sidebar with:
- Suggested actions based on selection
- Quick commands
- Workflow templates
- Recent queries

### 4. Inline Assistance

- Hover tooltips with AI insights
- Smart suggestions in search
- Auto-complete for natural language queries

## Implementation Roadmap

### Milestone 1: Foundation (Week 1-2)
- [x] Basic Claude API integration
- [x] Simple chat interface
- [x] Document context passing
- [ ] API key management in Keychain

### Milestone 2: Core Features (Week 3-4)
- [ ] Document summarization
- [ ] Multi-document chat
- [ ] Search integration
- [ ] Content extraction (text-based formats)

### Milestone 3: Advanced Features (Week 5-6)
- [ ] PDF content extraction
- [ ] Office document parsing
- [ ] Workflow engine
- [ ] Batch operations

### Milestone 4: SDK Integration (Week 7-8)
- [ ] Integrate official Claude Code SDK
- [ ] Implement tool execution
- [ ] Advanced agent capabilities
- [ ] Multi-step workflows

### Milestone 5: Polish & Optimization (Week 9-10)
- [ ] Performance optimization
- [ ] Caching strategies
- [ ] Error handling improvements
- [ ] User experience refinements

## Configuration & Settings

### User Settings

```swift
struct ClaudeSettings {
    var apiKey: String
    var defaultModel: String = "claude-3-5-sonnet-20241022"
    var maxTokens: Int = 4096
    var temperature: Double = 1.0

    // Privacy settings
    var enableTelemetry: Bool = false
    var allowCloudSync: Bool = false

    // Feature flags
    var enableWorkflows: Bool = true
    var enableBatchOps: Bool = true
    var requireApproval: Bool = true
}
```

### Scope Limitations

```swift
struct ScopeSettings {
    var maxFilesPerRequest: Int = 100
    var maxContentSize: Int = 1_000_000  // 1MB
    var allowRecursive: Bool = true
    var maxDepth: Int = 10
    var excludedTypes: Set<DocumentType> = []
}
```

## Privacy & Security

### Data Handling

1. **Local Processing**
   - File indexing happens locally
   - Metadata stays on device
   - User controls what's sent to API

2. **API Communication**
   - HTTPS only
   - API key stored in Keychain
   - No logging of sensitive content

3. **Audit Trail**
   - Log all Claude operations
   - Track files accessed
   - User can review history

### Compliance

- GDPR compliant
- No PII sent without user consent
- Clear data retention policies
- User can delete all Claude data

## Error Handling

### Common Scenarios

1. **API Errors**
   - Rate limiting
   - Authentication failures
   - Service unavailable

2. **Content Errors**
   - File too large
   - Unsupported format
   - Corrupted file

3. **Permission Errors**
   - File access denied
   - Sandbox restrictions
   - Network unavailable

### User-Friendly Messages

```swift
enum ClaudeUserError {
    case rateLimited(retryAfter: TimeInterval)
    case fileTooLarge(maxSize: Int)
    case unsupportedFormat(format: String)
    case networkError

    var localizedDescription: String {
        switch self {
        case .rateLimited(let seconds):
            return "Too many requests. Please try again in \(Int(seconds)) seconds."
        case .fileTooLarge(let max):
            return "File is too large. Maximum size is \(ByteCountFormatter.string(fromByteCount: Int64(max), countStyle: .file))."
        case .unsupportedFormat(let format):
            return "The format '\(format)' is not yet supported."
        case .networkError:
            return "Network error. Please check your connection."
        }
    }
}
```

## Testing Strategy

### Unit Tests
- Service layer functionality
- Context building
- Error handling
- Response parsing

### Integration Tests
- API communication
- File operations
- Workflow execution

### UI Tests
- Chat interface
- Context menu actions
- Settings management

## Future Enhancements

1. **Multi-modal Support**
   - Image analysis
   - Chart/graph extraction
   - Handwriting recognition

2. **Collaboration**
   - Shared Claude sessions
   - Team workspaces
   - Shared workflows

3. **Advanced Analytics**
   - Usage statistics
   - Document insights dashboard
   - Trend analysis

4. **Custom Integrations**
   - Plugin system
   - Custom tools
   - Third-party extensions
