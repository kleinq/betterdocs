import Foundation

/// Fuzzy search utility for finding matches in strings
struct FuzzySearch {
    /// Performs fuzzy search and returns a score (higher is better, nil if no match)
    static func score(_ needle: String, in haystack: String) -> Int? {
        let needleLower = needle.lowercased()
        let haystackLower = haystack.lowercased()

        guard !needleLower.isEmpty else { return nil }

        // Check for exact substring match (highest score)
        if haystackLower.contains(needleLower) {
            let index = haystackLower.range(of: needleLower)!.lowerBound
            let position = haystackLower.distance(from: haystackLower.startIndex, to: index)
            // Earlier matches get higher scores
            return 1000 - position
        }

        // Check for fuzzy match (characters in order but not necessarily consecutive)
        var haystackIndex = haystackLower.startIndex
        var matchedChars = 0
        var consecutiveMatches = 0
        var maxConsecutive = 0
        var totalScore = 0

        for needleChar in needleLower {
            // Find next occurrence of character
            while haystackIndex < haystackLower.endIndex {
                if haystackLower[haystackIndex] == needleChar {
                    matchedChars += 1
                    consecutiveMatches += 1
                    maxConsecutive = max(maxConsecutive, consecutiveMatches)
                    totalScore += 10 + consecutiveMatches // Bonus for consecutive matches
                    haystackIndex = haystackLower.index(after: haystackIndex)
                    break
                } else {
                    consecutiveMatches = 0
                    haystackIndex = haystackLower.index(after: haystackIndex)
                }
            }

            // If we couldn't find the character, no match
            if haystackIndex >= haystackLower.endIndex && matchedChars < needleLower.count {
                return nil
            }
        }

        // Only return a score if we matched all characters
        guard matchedChars == needleLower.count else { return nil }

        // Bonus for matching more characters consecutively
        totalScore += maxConsecutive * 20

        return totalScore
    }

    /// Searches an array of items and returns sorted matches with scores
    static func search<T>(_ query: String, in items: [T], keyPath: KeyPath<T, String>) -> [(item: T, score: Int)] {
        let results = items.compactMap { item -> (item: T, score: Int)? in
            guard let score = score(query, in: item[keyPath: keyPath]) else { return nil }
            return (item, score)
        }

        return results.sorted { $0.score > $1.score }
    }
}
