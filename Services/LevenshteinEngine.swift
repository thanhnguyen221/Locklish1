import Foundation

// MARK: - DictationMatchResult
public enum DictationMatchResult: Equatable {
    case exactMatch
    case closeMatch(distance: Int, hint: String)
    case mismatch(distance: Int)
}

// MARK: - LevenshteinEngine
/// High-performance string distance calculator for Dictation ("Nghe chép chính tả") practice.
/// Provides pedagogical tolerance by detecting close typos (distance <= 2) and prompting the user
/// to self-correct instead of immediately failing.
final class LevenshteinEngine {
    static let shared = LevenshteinEngine()

    private init() {}

    // MARK: - Classic Levenshtein Distance
    /// Computes the minimum number of single-character edits (insertions, deletions, or substitutions)
    /// required to transform string `a` into string `b`.
    /// - Time Complexity: O(m * n)
    /// - Space Complexity: O(n) (optimized single-row DP)
    func distance(_ s1: String, _ s2: String) -> Int {
        let a = Array(s1.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
        let b = Array(s2.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())

        let m = a.count
        let n = b.count

        if m == 0 { return n }
        if n == 0 { return m }

        var previousRow = Array(0...n)

        for i in 1...m {
            var currentRow = [i] + Array(repeating: 0, count: n)
            for j in 1...n {
                let cost = (a[i - 1] == b[j - 1]) ? 0 : 1
                currentRow[j] = min(
                    currentRow[j - 1] + 1,      // insertion
                    previousRow[j] + 1,          // deletion
                    previousRow[j - 1] + cost    // substitution
                )
            }
            previousRow = currentRow
        }

        return previousRow[n]
    }

    // MARK: - Pedagogical Fuzzy Evaluation
    /// Evaluates user input against a target vocabulary word.
    /// Returns `.closeMatch` if distance <= 2 for words with >= 5 letters, or distance == 1 for words with 3-4 letters.
    func evaluate(userInput: String, targetWord: String) -> DictationMatchResult {
        let cleanInput = userInput.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanTarget = targetWord.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if cleanInput == cleanTarget {
            return .exactMatch
        }

        let dist = distance(cleanInput, cleanTarget)

        // Close match tolerance rules:
        // - Word length >= 5: tolerate up to 2 character edits (e.g. "scheudle" vs "schedule")
        // - Word length 3..4: tolerate exactly 1 character edit
        let length = cleanTarget.count
        let isClose: Bool = {
            if length >= 5 && dist <= 2 {
                return true
            } else if length >= 3 && dist == 1 {
                return true
            }
            return false
        }()

        if isClose {
            let typoCount = dist == 1 ? "1 ký tự" : "2 ký tự"
            return .closeMatch(
                distance: dist,
                hint: "Gần đúng rồi! (Lệch \(typoCount)) Kiểm tra lại chính tả nhé."
            )
        }

        return .mismatch(distance: dist)
    }
}
