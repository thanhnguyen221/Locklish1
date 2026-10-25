import Foundation
import NaturalLanguage

// MARK: - TextProcessingService
/// Provides high-efficiency text tokenization, lemmatization, stop-word elimination,
/// and deduplication powered by Apple's on-device `NaturalLanguage` framework.
final class TextProcessingService {
    static let shared = TextProcessingService()

    private init() {}

    /// Standard curated English stop words that should be excluded from vocabulary practice.
    let defaultStopWords: Set<String> = [
        "a", "about", "above", "after", "again", "against", "all", "am", "an", "and",
        "any", "are", "aren't", "as", "at", "be", "because", "been", "before", "being",
        "below", "between", "both", "but", "by", "can't", "cannot", "could", "couldn't",
        "did", "didn't", "do", "does", "doesn't", "doing", "don't", "down", "during",
        "each", "few", "for", "from", "further", "had", "hadn't", "has", "hasn't",
        "have", "haven't", "having", "he", "he'd", "he'll", "he's", "her", "here",
        "here's", "hers", "herself", "him", "himself", "his", "how", "how's", "i",
        "i'd", "i'll", "i'm", "i've", "if", "in", "into", "is", "isn't", "it", "it's",
        "its", "itself", "let's", "me", "more", "most", "mustn't", "my", "myself",
        "no", "nor", "not", "of", "off", "on", "once", "only", "or", "other", "ought",
        "our", "ours", "ourselves", "out", "over", "own", "same", "shan't", "she",
        "she'd", "she'll", "she's", "should", "shouldn't", "so", "some", "such",
        "than", "that", "that's", "the", "their", "theirs", "them", "themselves",
        "then", "there", "there's", "these", "they", "they'd", "they'll", "they're",
        "they've", "this", "those", "through", "to", "too", "under", "until", "up",
        "very", "was", "wasn't", "we", "we'd", "we'll", "we're", "we've", "were",
        "weren't", "what", "what's", "when", "when's", "where", "where's", "which",
        "while", "who", "who's", "whom", "why", "why's", "with", "won't", "would",
        "wouldn't", "you", "you'd", "you'll", "you're", "you've", "your", "yours",
        "yourself", "yourselves"
    ]

    // MARK: - Lemmatization & Deduplication
    /// Extracts root lemma forms of all English words in the text, discarding stop words and punctuation.
    /// Deduplicates words so that variations like "conversations", "conversing", "conversation" resolve to one base form.
    /// - Parameters:
    ///   - text: Raw document or passage text.
    ///   - customStopWords: Optional additional stop words to ignore.
    ///   - minimumLength: Minimum character length for valid target words (default 3).
    /// - Returns: Ordered array of unique lemmatized target words sorted by frequency.
    func lemmatizeAndDeduplicate(
        text: String,
        customStopWords: Set<String>? = nil,
        minimumLength: Int = 3
    ) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let stopWords = (customStopWords ?? []).union(defaultStopWords)
        let tagger = NLTagger(tagSchemes: [.lemma])
        tagger.string = trimmed

        var frequencies: [String: Int] = [:]
        var originalForms: [String: String] = [:]

        tagger.enumerateTags(in: trimmed.startIndex..<trimmed.endIndex, unit: .word, scheme: .lemma) { tag, range in
            let rawWord = String(trimmed[range])
            let lemma = tag?.rawValue.lowercased() ?? rawWord.lowercased()
            let cleaned = lemma.trimmingCharacters(in: .punctuationCharacters)

            if cleaned.count >= minimumLength,
               !stopWords.contains(cleaned),
               cleaned.rangeOfCharacter(from: .letters) != nil {
                frequencies[cleaned, default: 0] += 1
                if originalForms[cleaned] == nil {
                    originalForms[cleaned] = cleaned.capitalized
                }
            }
            return true
        }

        // Sort by occurrence frequency descending
        return frequencies.keys.sorted { (frequencies[$0] ?? 0) > (frequencies[$1] ?? 0) }
            .map { originalForms[$0] ?? $0.capitalized }
    }

    // MARK: - Context Sentence Extractor
    /// Finds the best contextual sentence containing a given vocabulary word from the document text.
    func findContextSentence(for word: String, in text: String) -> String? {
        let sentenceTokenizer = NLTokenizer(unit: .sentence)
        sentenceTokenizer.string = text

        var matchedSentence: String? = nil
        let lowerWord = word.lowercased()

        sentenceTokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let sentence = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            if sentence.range(of: "\\b\(lowerWord)\\b", options: [.regularExpression, .caseInsensitive]) != nil {
                matchedSentence = sentence
                return false // stop searching
            }
            return true
        }

        return matchedSentence
    }
}
