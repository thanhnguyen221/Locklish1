import Foundation

// MARK: - GrammarProgressStore
/// Persists grammar learning progress with UserDefaults (same mechanism the
/// app already uses for lighter state): completed topics and the latest
/// exercise score per topic. The IPA accent preference lives here too.
@Observable
@MainActor
final class GrammarProgressStore {
    static let shared = GrammarProgressStore()

    private let completedKey = "locklish_grammar_completed_topics"
    private let scoresKey = "locklish_grammar_last_scores"
    private let accentKey = "locklish_ipa_accent"

    private(set) var completedTopics: Set<String> = []
    /// topicId -> number of correctly answered exercises in the latest attempt
    private(set) var lastScores: [String: Int] = [:]
    /// "en-US" (default) or "en-GB"
    var ipaAccent: String {
        didSet {
            guard oldValue != ipaAccent else { return }
            let defaults = UserDefaults.standard
            defaults.set(ipaAccent, forKey: accentKey)
        }
    }

    private init() {
        let defaults = UserDefaults.standard
        self.completedTopics = Set(defaults.stringArray(forKey: completedKey) ?? [])
        self.lastScores = (defaults.dictionary(forKey: scoresKey) as? [String: Int]) ?? [:]
        let stored = defaults.string(forKey: accentKey)
        self.ipaAccent = (stored == "en-GB" || stored == "en-US") ? stored! : "en-US"
    }

    func isCompleted(_ topicId: String) -> Bool {
        completedTopics.contains(topicId)
    }

    func toggleCompleted(_ topicId: String) {
        if completedTopics.contains(topicId) {
            completedTopics.remove(topicId)
        } else {
            completedTopics.insert(topicId)
        }
        UserDefaults.standard.set(Array(completedTopics), forKey: completedKey)
    }

    func recordScore(topicId: String, correct: Int) {
        lastScores[topicId] = correct
        UserDefaults.standard.set(lastScores, forKey: scoresKey)
    }

    func lastScore(for topicId: String) -> Int? {
        lastScores[topicId]
    }

    /// Completed / total across every topic in the curriculum.
    func overallProgress(totalTopics: Int) -> Double {
        guard totalTopics > 0 else { return 0 }
        return Double(completedTopics.count) / Double(totalTopics)
    }
}
