import Foundation

// MARK: - SessionProgressManager
/// Manages checkpointing and restoring in-progress learning sessions across Gamified Rounds,
/// Dictation (Spelling), and Flashcards. Ensures users never lose their spot when leaving mid-session.
final class SessionProgressManager {
    static let shared = SessionProgressManager()

    private let userDefaults = UserDefaults.standard

    // Keys prefixes
    private let roundKeyPrefix = "locklish_session_round_"
    private let dictationKeyPrefix = "locklish_session_dictation_"
    private let flashcardKeyPrefix = "locklish_session_flashcard_"

    private init() {}

    // MARK: - 1. Gamified Themed Rounds Checkpoints
    struct RoundSessionData: Codable {
        let roundId: Int
        let wordIndex: Int
        let correctCount: Int
        let timestamp: Date
    }

    func saveRoundSession(roundId: Int, wordIndex: Int, correctCount: Int) {
        let data = RoundSessionData(
            roundId: roundId,
            wordIndex: wordIndex,
            correctCount: correctCount,
            timestamp: Date()
        )
        if let encoded = try? JSONEncoder().encode(data) {
            userDefaults.setValue(encoded, forKey: "\(roundKeyPrefix)\(roundId)")
        }
    }

    func getRoundSession(roundId: Int) -> (wordIndex: Int, correctCount: Int)? {
        guard let data = userDefaults.data(forKey: "\(roundKeyPrefix)\(roundId)"),
              let decoded = try? JSONDecoder().decode(RoundSessionData.self, from: data) else {
            return nil
        }
        return (decoded.wordIndex, decoded.correctCount)
    }

    func clearRoundSession(roundId: Int) {
        userDefaults.removeObject(forKey: "\(roundKeyPrefix)\(roundId)")
    }

    // MARK: - 2. Dictation Practice Checkpoints
    struct DictationSessionData: Codable {
        let deckIdString: String
        let currentIndex: Int
        let correctCount: Int
        let timestamp: Date
    }

    private func dictationKey(for deckId: UUID?) -> String {
        let idStr = deckId?.uuidString ?? "all_items"
        return "\(dictationKeyPrefix)\(idStr)"
    }

    func saveDictationSession(deckId: UUID?, currentIndex: Int, correctCount: Int) {
        let idStr = deckId?.uuidString ?? "all_items"
        let data = DictationSessionData(
            deckIdString: idStr,
            currentIndex: currentIndex,
            correctCount: correctCount,
            timestamp: Date()
        )
        if let encoded = try? JSONEncoder().encode(data) {
            userDefaults.setValue(encoded, forKey: dictationKey(for: deckId))
        }
    }

    func getDictationSession(deckId: UUID?) -> (currentIndex: Int, correctCount: Int)? {
        guard let data = userDefaults.data(forKey: dictationKey(for: deckId)),
              let decoded = try? JSONDecoder().decode(DictationSessionData.self, from: data) else {
            return nil
        }
        return (decoded.currentIndex, decoded.correctCount)
    }

    func clearDictationSession(deckId: UUID?) {
        userDefaults.removeObject(forKey: dictationKey(for: deckId))
    }

    // MARK: - 3. Flashcard Practice Checkpoints
    struct FlashcardSessionData: Codable {
        let deckIdString: String
        let currentIndex: Int
        let masteredCount: Int
        let reviewNeededCount: Int
        let timestamp: Date
    }

    private func flashcardKey(for deckId: UUID?) -> String {
        let idStr = deckId?.uuidString ?? "all_items"
        return "\(flashcardKeyPrefix)\(idStr)"
    }

    func saveFlashcardSession(deckId: UUID?, currentIndex: Int, masteredCount: Int, reviewNeededCount: Int) {
        let idStr = deckId?.uuidString ?? "all_items"
        let data = FlashcardSessionData(
            deckIdString: idStr,
            currentIndex: currentIndex,
            masteredCount: masteredCount,
            reviewNeededCount: reviewNeededCount,
            timestamp: Date()
        )
        if let encoded = try? JSONEncoder().encode(data) {
            userDefaults.setValue(encoded, forKey: flashcardKey(for: deckId))
        }
    }

    func getFlashcardSession(deckId: UUID?) -> (currentIndex: Int, masteredCount: Int, reviewNeededCount: Int)? {
        guard let data = userDefaults.data(forKey: flashcardKey(for: deckId)),
              let decoded = try? JSONDecoder().decode(FlashcardSessionData.self, from: data) else {
            return nil
        }
        return (decoded.currentIndex, decoded.masteredCount, decoded.reviewNeededCount)
    }

    func clearFlashcardSession(deckId: UUID?) {
        userDefaults.removeObject(forKey: flashcardKey(for: deckId))
    }
}
