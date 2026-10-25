import Foundation
import SwiftData
import SwiftUI

// MARK: - DictationEvaluationState
enum DictationEvaluationState: Equatable {
    case pending
    case correct
    case closeMatch(hint: String)
    case incorrect(revealedWord: String)
}

// MARK: - DictationViewModel
@Observable
@MainActor
final class DictationViewModel {
    var sessionItems: [VocabularyItem] = []
    var currentIndex: Int = 0
    var userInput: String = ""
    var evaluationState: DictationEvaluationState = .pending
    var isAnswerRevealed: Bool = false
    var showTranslation: Bool = false

    var activeDeckFilter: VocabularyDeck? = nil
    var correctAnswersCount: Int = 0
    var isSessionFinished: Bool = false
    var showShieldUnlockedCelebration: Bool = false
    var attemptsOnCurrentWord: Int = 0

    var isDailyUnlockMission: Bool = false
    var missionTargetCount: Int = 10

    // MARK: - Session Setup with Deck Filtering & SM-2 Balancing
    func startSession(
        with allItems: [VocabularyItem],
        deckFilter: VocabularyDeck? = nil,
        isDailyUnlockMission: Bool = false,
        targetCount: Int = 10
    ) {
        self.activeDeckFilter = deckFilter
        self.isDailyUnlockMission = isDailyUnlockMission
        self.missionTargetCount = targetCount

        // 1. Filter by deck if selected
        let scopedItems: [VocabularyItem]
        if let filter = deckFilter {
            scopedItems = filter.items ?? []
        } else {
            scopedItems = allItems
        }

        // 2. Balance via SM-2:
        // If daily unlock mission, cap at targetCount (e.g. 10 words)
        // If deck practice, practice ALL words in the deck!
        let queue: [VocabularyItem]
        if isDailyUnlockMission {
            queue = SRSEngine.shared.balanceDailyQueue(from: scopedItems, limit: targetCount)
        } else {
            queue = SRSEngine.shared.balanceDailyQueue(from: scopedItems, limit: nil)
        }

        self.sessionItems = queue

        // Resume from saved checkpoint if available (only for deck practice or general practice, not daily unlock)
        if !isDailyUnlockMission,
           let saved = SessionProgressManager.shared.getDictationSession(deckId: deckFilter?.id),
           saved.currentIndex > 0 && saved.currentIndex < queue.count {
            self.currentIndex = saved.currentIndex
            self.correctAnswersCount = saved.correctCount
        } else {
            self.currentIndex = 0
            self.correctAnswersCount = 0
        }

        self.userInput = ""
        self.evaluationState = .pending
        self.isAnswerRevealed = false
        self.showTranslation = false
        self.isSessionFinished = self.sessionItems.isEmpty
        self.showShieldUnlockedCelebration = false
        self.attemptsOnCurrentWord = 0
    }

    var currentItem: VocabularyItem? {
        guard currentIndex >= 0 && currentIndex < sessionItems.count else { return nil }
        return sessionItems[currentIndex]
    }

    var progressRatio: Double {
        guard !sessionItems.isEmpty else { return 0.0 }
        return Double(correctAnswersCount) / Double(sessionItems.count)
    }

    var progressText: String {
        guard !sessionItems.isEmpty else { return "0/0" }
        return "\(currentIndex + 1) / \(sessionItems.count)"
    }

    // MARK: - Audio Playback
    func playCurrentAudio() {
        guard let item = currentItem else { return }
        HapticFeedback.light()
        TTSService.shared.speak(text: item.word)
    }

    // MARK: - Answer Verification with Levenshtein Distance
    func verifyAnswer(in modelContext: ModelContext) {
        guard let item = currentItem else { return }

        // Use Levenshtein fuzzy engine
        let matchResult = LevenshteinEngine.shared.evaluate(userInput: userInput, targetWord: item.word)

        switch matchResult {
        case .exactMatch:
            // 1. Correct Answer
            evaluationState = .correct
            correctAnswersCount += 1

            // SM-2: Perfect recall -> .easy
            SRSEngine.shared.processReview(item: item, quality: .easy)
            try? modelContext.save()
            HapticFeedback.success()

            // Note: Auto-advance removed. User now presses "Tiếp tục" or Return to advance.

        case .closeMatch(_, let hint):
            // 2. Close Typo (Pedagogical Warning Banner)
            evaluationState = .closeMatch(hint: hint)
            HapticFeedback.light()
            // Do not immediately penalize — let user self-correct!

        case .mismatch:
            // 3. Complete Incorrect Answer
            attemptsOnCurrentWord += 1
            HapticFeedback.error()

            if attemptsOnCurrentWord >= 2 {
                // SM-2: Failed after multiple attempts -> .again
                SRSEngine.shared.processReview(item: item, quality: .again)
                try? modelContext.save()
                evaluationState = .incorrect(revealedWord: item.word)
            } else {
                evaluationState = .incorrect(revealedWord: "")
            }
        }
    }

    func revealAnswer() {
        guard let item = currentItem else { return }
        isAnswerRevealed = true
        // Pre-fill userInput so the "Kiểm tra chính tả" button stays enabled
        if userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            userInput = item.word
        }
        HapticFeedback.light()
    }

    func toggleTranslation() {
        showTranslation.toggle()
        HapticFeedback.light()
    }

    // MARK: - Advance to Next Word
    func advanceNext(modelContext: ModelContext) {
        userInput = ""
        evaluationState = .pending
        isAnswerRevealed = false
        showTranslation = false
        attemptsOnCurrentWord = 0

        if currentIndex + 1 < sessionItems.count {
            currentIndex += 1
            if !isDailyUnlockMission {
                SessionProgressManager.shared.saveDictationSession(
                    deckId: activeDeckFilter?.id,
                    currentIndex: currentIndex,
                    correctCount: correctAnswersCount
                )
            }
        } else {
            completeSession(modelContext: modelContext)
        }
    }

    // MARK: - Complete Session & Screen Time Unlock
    private func completeSession(modelContext: ModelContext) {
        isSessionFinished = true
        if !isDailyUnlockMission {
            SessionProgressManager.shared.clearDictationSession(deckId: activeDeckFilter?.id)
        }

        let isPerfectScore = (correctAnswersCount == sessionItems.count) && !sessionItems.isEmpty

        // Update DailyPracticeRecord in SwiftData
        let todayString = DailyPracticeRecord.currentDateString()
        let fetchDescriptor = FetchDescriptor<DailyPracticeRecord>(
            predicate: #Predicate { $0.dateString == todayString }
        )

        let existingRecords = (try? modelContext.fetch(fetchDescriptor)) ?? []
        let todayRecord: DailyPracticeRecord

        if let found = existingRecords.first {
            todayRecord = found
            todayRecord.totalAssigned = sessionItems.count
            todayRecord.totalCompleted = correctAnswersCount
            todayRecord.isFullyCompleted = isPerfectScore
            if isPerfectScore { todayRecord.completedAt = Date() }
        } else {
            todayRecord = DailyPracticeRecord(
                dateString: todayString,
                totalAssigned: sessionItems.count,
                totalCompleted: correctAnswersCount,
                isFullyCompleted: isPerfectScore,
                completedAt: isPerfectScore ? Date() : nil
            )
            modelContext.insert(todayRecord)
        }

        try? modelContext.save()

        // Celebrate 100% completion
        if isPerfectScore {
            showShieldUnlockedCelebration = true
            HapticFeedback.success()
        }
    }

    func retrySession(with allItems: [VocabularyItem]) {
        SessionProgressManager.shared.clearDictationSession(deckId: activeDeckFilter?.id)
        startSession(
            with: allItems,
            deckFilter: activeDeckFilter,
            isDailyUnlockMission: isDailyUnlockMission,
            targetCount: isDailyUnlockMission ? missionTargetCount : sessionItems.count
        )
    }
}
