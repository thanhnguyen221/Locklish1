import Foundation
import SwiftData
import SwiftUI

// MARK: - GamifiedViewModel
/// Orchestrates the thematic game roadmap, interactive letter-by-letter typing drills,
/// sentence reveals, custom image attachments, and star ratings.
@Observable
@MainActor
final class GamifiedViewModel {

    // MARK: - Catalog & State
    var catalogService = GameCatalogService.shared

    var rounds: [GameThemeRound] {
        catalogService.rounds
    }

    var totalStars: Int {
        catalogService.totalStars
    }

    var currentStreak: Int {
        catalogService.currentStreak
    }

    var currentLevel: Int {
        max(1, (totalStars / 3) + 1)
    }

    // MARK: - CEFR Level Filtering (A1, A2, B1, B2, C2)
    var selectedLevel: String = "A1"
    let cefrLevels: [String] = ["A1", "A2", "B1", "B2", "C2"]

    var roundsForSelectedLevel: [GameThemeRound] {
        let filtered = catalogService.rounds(for: selectedLevel)
        return filtered.isEmpty && selectedLevel == "A1" ? rounds : filtered
    }

    var currentActiveRoundId: Int? {
        roundsForSelectedLevel.first(where: { !$0.isCompleted && !$0.isLocked })?.id
            ?? roundsForSelectedLevel.first?.id
    }

    // MARK: - Active Drill Session
    var activeRound: GameThemeRound? = nil
    var activeRoundIndex: Int? = nil
    var currentWordIndex: Int = 0
    var userInput: String = ""
    var isAnswerCorrect: Bool = false
    var isAnswerRevealed: Bool = false
    var showTranslation: Bool = false
    var showCloseMatchWarning: String? = nil
    var sessionCorrectCount: Int = 0
    var isSessionComplete: Bool = false
    var isTranslating: Bool = false
    private var autoAdvanceTask: Task<Void, Never>?

    // MARK: - Active Word
    var currentWord: GameWordItem? {
        guard let round = activeRound,
              currentWordIndex >= 0 && currentWordIndex < round.words.count else {
            return nil
        }
        return round.words[currentWordIndex]
    }

    var totalWordsInSession: Int {
        activeRound?.words.count ?? 0
    }

    var progressRatio: Double {
        guard totalWordsInSession > 0 else { return 0 }
        return Double(currentWordIndex) / Double(totalWordsInSession)
    }

    var progressText: String {
        guard let round = activeRound else { return "" }
        return "Vòng \(round.id) · \(currentWordIndex + 1) / \(totalWordsInSession)"
    }

    // MARK: - Start Themed Round Drill
    func startRound(index: Int) {
        guard index >= 0 && index < rounds.count else { return }
        let round = rounds[index]
        startRound(round: round)
    }

    func startRound(round: GameThemeRound) {
        if let idx = rounds.firstIndex(where: { $0.id == round.id }) {
            self.activeRoundIndex = idx
        } else {
            self.activeRoundIndex = 0
        }
        autoAdvanceTask?.cancel()
        autoAdvanceTask = nil
        self.activeRound = round

        // Resume from saved session checkpoint if available
        if let saved = SessionProgressManager.shared.getRoundSession(roundId: round.id),
           saved.wordIndex > 0 && saved.wordIndex < round.words.count {
            self.currentWordIndex = saved.wordIndex
            self.sessionCorrectCount = saved.correctCount
        } else {
            self.currentWordIndex = 0
            self.sessionCorrectCount = 0
        }

        self.userInput = ""
        self.isAnswerCorrect = false
        self.isAnswerRevealed = false
        self.showTranslation = false
        self.showCloseMatchWarning = nil
        self.isSessionComplete = false
    }

    // MARK: - Typing & Verification
    func onUserInputChanged(_ newValue: String) {
        guard !isAnswerCorrect else { return }
        // Clear close-match warning when user edits their answer
        showCloseMatchWarning = nil
    }

    func verifyInput(cleanInput: String? = nil, targetWord: String? = nil) {
        guard let word = currentWord else { return }
        let target = (targetWord ?? word.word).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let input = (cleanInput ?? userInput).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if input == target {
            // Exact match!
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                isAnswerCorrect = true
                showTranslation = true
                showCloseMatchWarning = nil
            }
            sessionCorrectCount += 1
            HapticFeedback.success()

            // Update mastery in catalog
            if let round = activeRound {
                catalogService.recordWordMastered(roundId: round.id, wordId: word.id, isMastered: true)
            }

            // Note: Auto-advance has been removed as requested.
            // User now reviews their answer and presses "Tiếp tục" to advance.
            autoAdvanceTask?.cancel()
            autoAdvanceTask = nil
        } else {
            // Check Levenshtein distance for close match warning
            let distance = LevenshteinEngine.shared.distance(input, target)
            if distance <= 2 {
                showCloseMatchWarning = "Gần đúng rồi! Kiểm tra lại chính tả nhé."
                HapticFeedback.light()
            } else {
                showCloseMatchWarning = "Chưa chính xác. Hãy nghe lại phát âm!"
                HapticFeedback.error()
            }
        }
    }

    // MARK: - Reveal Hint / Eye Action
    func revealAnswer() {
        guard let word = currentWord else { return }
        HapticFeedback.light()
        withAnimation(.easeInOut(duration: 0.2)) {
            isAnswerRevealed = true
            userInput = word.word
        }
        verifyInput()
    }

    // MARK: - Speak Audio
    func speakCurrentWord() {
        guard let word = currentWord else { return }
        HapticFeedback.light()
        TTSService.shared.speak(text: isAnswerCorrect ? word.exampleSentence : word.word)
    }

    // MARK: - Toggle Favorite
    func toggleFavorite() {
        guard let round = activeRound, let word = currentWord else { return }
        HapticFeedback.selection()
        catalogService.toggleFavorite(roundId: round.id, wordId: word.id)
    }

    // MARK: - Toggle Translation
    func toggleTranslation() {
        withAnimation(.easeInOut(duration: 0.2)) {
            showTranslation.toggle()
        }
        HapticFeedback.light()
    }

    // MARK: - Auto Translate Sentence
    func autoTranslateSentence() async {
        guard let word = currentWord else { return }
        guard let round = activeRound else { return }
        guard let roundIndex = activeRoundIndex else { return }

        // If translation already exists, just toggle visibility
        if word.exampleTranslation.isEmpty == false {
            toggleTranslation()
            return
        }

        HapticFeedback.light()
        isTranslating = true

        do {
            let translation = try await GeminiService.shared.translateText(word.exampleSentence)

            // Update the word's translation in the catalog
            catalogService.updateWordTranslation(roundId: round.id, wordId: word.id, translation: translation)

            // Force update active round reference to trigger UI refresh
            self.activeRound = catalogService.rounds[roundIndex]

            // Show the translation
            withAnimation(.easeInOut(duration: 0.2)) {
                showTranslation = true
            }
        } catch {
            print("[GamifiedViewModel] Translation error: \(error)")
            // Fallback: toggle visibility even if translation fails
            toggleTranslation()
        }

        isTranslating = false
    }

    // MARK: - Update Word Image (Commercial Customization)
    func updateWordImage(imageData: Data?) {
        guard let round = activeRound, let word = currentWord else { return }
        HapticFeedback.success()
        catalogService.updateWordImage(roundId: round.id, wordId: word.id, imageData: imageData)
        // Refresh active round reference
        if let idx = activeRoundIndex {
            self.activeRound = rounds[idx]
        }
    }

    // MARK: - Advance to Next Word
    func advanceNext() {
        autoAdvanceTask?.cancel()
        autoAdvanceTask = nil
        guard let round = activeRound else { return }

        if currentWordIndex + 1 < round.words.count {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                currentWordIndex += 1
                userInput = ""
                isAnswerCorrect = false
                isAnswerRevealed = false
                showTranslation = false
                showCloseMatchWarning = nil
            }
            // Save progress checkpoint
            SessionProgressManager.shared.saveRoundSession(
                roundId: round.id,
                wordIndex: currentWordIndex,
                correctCount: sessionCorrectCount
            )
        } else {
            // Completed Round! Clear saved session
            SessionProgressManager.shared.clearRoundSession(roundId: round.id)
            let ratio = Double(sessionCorrectCount) / Double(max(1, round.words.count))
            catalogService.completeRound(roundId: round.id, scoreRatio: ratio)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                isSessionComplete = true
            }
            HapticFeedback.success()
        }
    }

    // MARK: - Restart Current Round
    func restartRound() {
        if let round = activeRound {
            SessionProgressManager.shared.clearRoundSession(roundId: round.id)
            startRound(round: round)
        } else if let idx = activeRoundIndex {
            let round = rounds[idx]
            SessionProgressManager.shared.clearRoundSession(roundId: round.id)
            startRound(index: idx)
        }
    }
}
