import Foundation

// Temporarily simplified to class until we implement proper async search
@MainActor
class SearchService {
    private var searchIndex: [UUID: SearchIndexEntry] = [:]
    private var fileNameIndex: [String: Set<UUID>] = [:]
    private var contentTokenIndex: [String: Set<UUID>] = [:] // Inverted index for content tokens
    private var itemCache: [UUID: any FileSystemItem] = [:] // Cache item references

    struct SearchIndexEntry: Sendable {
        let itemID: UUID
        let itemName: String
        let itemPath: String
        let isFolder: Bool
        let content: String
        let tokens: Set<String>
    }

    /// Index a folder and all its contents
    func indexFolder(_ folder: Folder) async {
        // Index the folder itself
        indexItem(folder)

        // Index all children recursively
        for child in folder.children {
            if let subfolder = child as? Folder {
                await indexFolder(subfolder)
            } else {
                indexItem(child)
            }
        }
    }

    /// Index a single item
    func indexItem(_ item: any FileSystemItem) {
        let content: String
        let itemName = item.name
        let itemPath = item.path.path
        let itemID = item.id
        let itemIsFolder = item.isFolder

        if let document = item as? Document {
            content = document.content ?? ""
        } else {
            content = ""
        }

        // Tokenize content
        let tokens = tokenize(content + " " + itemName)

        let entry = SearchIndexEntry(
            itemID: itemID,
            itemName: itemName,
            itemPath: itemPath,
            isFolder: itemIsFolder,
            content: content,
            tokens: tokens
        )

        searchIndex[itemID] = entry
        itemCache[itemID] = item // Cache the item reference

        // Index filename tokens
        let nameTokens = tokenize(itemName)
        for token in nameTokens {
            fileNameIndex[token, default: []].insert(itemID)
        }

        // Index content tokens (for fast lookup)
        for token in tokens {
            contentTokenIndex[token, default: []].insert(itemID)
        }
    }

    /// Search for items matching a query
    func search(_ query: String, in rootFolder: Folder?, filter: SearchFilter = .default) -> [SearchResult] {
        guard !query.isEmpty else { return [] }
        guard let rootFolder = rootFolder else { return [] }

        let queryTokens = tokenize(query)
        var candidateIDs = Set<UUID>()

        // Fast path: Use inverted index to find candidate items
        // Only search items that contain at least one query token
        if !queryTokens.isEmpty {
            for token in queryTokens {
                // Check filename index
                if let ids = fileNameIndex[token] {
                    candidateIDs.formUnion(ids)
                }
                // Check content token index
                if let ids = contentTokenIndex[token] {
                    candidateIDs.formUnion(ids)
                }
            }
        }

        // If no candidates found via token matching, fall back to phrase search
        // This handles exact phrase queries that may span multiple tokens
        if candidateIDs.isEmpty {
            candidateIDs = Set(searchIndex.keys)
        }

        var results: [SearchResult] = []
        let lowercasedQuery = query.lowercased()

        // Only search through candidate items (much smaller set)
        for itemID in candidateIDs {
            guard let entry = searchIndex[itemID] else { continue }

            var score = 0.0
            var matches: [SearchMatch] = []

            // Search in filename
            if filter.includeFilenames {
                if entry.itemName.lowercased().contains(lowercasedQuery) {
                    score += 10.0 // High score for filename match
                    let context = "Filename: \(entry.itemName)"
                    matches.append(SearchMatch(
                        range: entry.itemName.startIndex..<entry.itemName.endIndex,
                        context: context,
                        lineNumber: nil
                    ))
                }
            }

            // Search in content (only if item has content)
            if filter.includeContent && !entry.content.isEmpty {
                let contentMatches = findMatches(
                    in: entry.content,
                    for: query,
                    tokens: entry.tokens
                )
                if !contentMatches.isEmpty {
                    matches.append(contentsOf: contentMatches)
                    score += Double(contentMatches.count) * 5.0
                }
            }

            // Token matching for relevance boost
            for token in queryTokens {
                if entry.tokens.contains(token) {
                    score += 1.0
                }
            }

            // If we have matches or score, create a result
            if score > 0 || !matches.isEmpty {
                // Use cached item reference instead of expensive tree traversal
                if let item = itemCache[itemID] {
                    // Apply filters
                    if passesFilter(item, filter: filter) {
                        let result = SearchResult(
                            id: itemID,
                            item: item,
                            matches: matches,
                            score: score
                        )
                        results.append(result)
                    }
                }
            }
        }

        // Sort by relevance (score)
        results.sort { $0.score > $1.score }

        return results
    }

    /// Clear the search index
    func clearIndex() {
        searchIndex.removeAll()
        fileNameIndex.removeAll()
        contentTokenIndex.removeAll()
        itemCache.removeAll()
    }

    // MARK: - Private Helpers

    private func tokenize(_ text: String) -> Set<String> {
        let lowercased = text.lowercased()
        let components = lowercased.components(separatedBy: .whitespacesAndNewlines)

        var tokens = Set<String>()

        for component in components {
            // Remove punctuation and add token
            let cleaned = component.components(separatedBy: .punctuationCharacters).joined()
            if !cleaned.isEmpty {
                tokens.insert(cleaned)
            }
        }

        return tokens
    }

    private func findMatches(
        in text: String,
        for query: String,
        tokens: Set<String>
    ) -> [SearchMatch] {
        var matches: [SearchMatch] = []
        let lowercasedText = text.lowercased()
        let lowercasedQuery = query.lowercased()

        // Find exact phrase matches
        var searchRange = lowercasedText.startIndex..<lowercasedText.endIndex

        while let range = lowercasedText.range(of: lowercasedQuery, range: searchRange) {
            // Convert the range indices to UTF-16 offsets that are safe to use on both strings
            let lowerOffset = lowercasedText.distance(from: lowercasedText.startIndex, to: range.lowerBound)
            let upperOffset = lowercasedText.distance(from: lowercasedText.startIndex, to: range.upperBound)

            // Create a corresponding range in the original text using the same offsets
            let originalStart = text.index(text.startIndex, offsetBy: lowerOffset)
            let originalEnd = text.index(text.startIndex, offsetBy: upperOffset)
            let originalRange = originalStart..<originalEnd

            let context = extractContext(from: text, around: originalRange)
            let match = SearchMatch(
                range: originalRange,
                context: context,
                lineNumber: nil
            )
            matches.append(match)

            // Move search range past this match
            searchRange = range.upperBound..<lowercasedText.endIndex
        }

        return matches
    }

    private func extractContext(from text: String, around range: Range<String.Index>) -> String {
        let contextLength = 100
        let start = text.index(
            range.lowerBound,
            offsetBy: -contextLength,
            limitedBy: text.startIndex
        ) ?? text.startIndex

        let end = text.index(
            range.upperBound,
            offsetBy: contextLength,
            limitedBy: text.endIndex
        ) ?? text.endIndex

        return String(text[start..<end])
    }

    private func passesFilter(_ item: any FileSystemItem, filter: SearchFilter) -> Bool {
        // File type filter
        if !filter.fileTypes.isEmpty {
            if let document = item as? Document {
                guard filter.fileTypes.contains(document.type) else {
                    return false
                }
            } else {
                // If filtering by file types, exclude folders
                return false
            }
        }

        // Date range filter
        if let dateRange = filter.dateRange {
            if let from = dateRange.from, item.modified < from {
                return false
            }
            if let to = dateRange.to, item.modified > to {
                return false
            }
        }

        // Size range filter (only for documents)
        if let sizeRange = filter.sizeRange, let document = item as? Document {
            if let min = sizeRange.min, document.size < min {
                return false
            }
            if let max = sizeRange.max, document.size > max {
                return false
            }
        }

        return true
    }
}
