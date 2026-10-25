import Foundation
import SwiftData
import SwiftUI

// MARK: - FlashcardViewModel
/// Coordinates 3D interactive flashcards, SM-2 Spaced Repetition scheduling,
/// drag gesture physics, and real-time quiz session counters.
@Observable
@MainActor
final class FlashcardViewModel {
    // Navigation & 3D Flip State
    var currentIndex: Int = 0
    var isFlipped: Bool = false
    var cardRotation: Double = 0.0

    // Deck & Session Items
    var deck: [VocabularyItem] = []
    var activeDeckFilter: VocabularyDeck? = nil

    // Live Quiz Counters
    var masteredCount: Int = 0
    var reviewNeededCount: Int = 0
    var isSessionCompleted: Bool = false

    // Drag Gesture Physics State
    var dragOffset: CGSize = .zero
    var isDragging: Bool = false
    var isAdvancing: Bool = false

    // The latest reviewed cards, used by the in-session undo control.
    private var reviewHistory: [ReviewHistory] = []

    private struct ReviewHistory {
        let item: VocabularyItem
        let index: Int
        let isMastered: Bool
        let step: Int
        let easeFactor: Double
        let intervalDays: Int
        let nextReviewDate: Date
        let lastReviewedDate: Date?
    }

    // MARK: - Session Setup & Dynamic SRS Balance
    /// Loads vocabulary cards, optionally filtered by `VocabularyDeck`,
    /// balanced by `SRSEngine` daily overdue queue (max 25 cards).
    func loadDeck(from items: [VocabularyItem], deckFilter: VocabularyDeck? = nil) {
        self.activeDeckFilter = deckFilter

        // 1. Filter by deck if a deck is selected
        let scopedItems: [VocabularyItem]
        if let filter = deckFilter {
            scopedItems = filter.items
        } else {
            scopedItems = items
        }

        // 2. Prioritize through SM-2 (keep ALL items in deck, priority to overdue and unmastered)
        let balancedQueue = SRSEngine.shared.balanceDailyQueue(from: scopedItems, limit: nil)

        self.deck = balancedQueue

        // Resume from saved checkpoint if available
        if let saved = SessionProgressManager.shared.getFlashcardSession(deckId: deckFilter?.id),
           saved.currentIndex > 0 && saved.currentIndex < balancedQueue.count {
            self.currentIndex = saved.currentIndex
            self.masteredCount = saved.masteredCount
            self.reviewNeededCount = saved.reviewNeededCount
        } else {
            self.currentIndex = 0
            self.masteredCount = 0
            self.reviewNeededCount = 0
        }

        self.isFlipped = false
        self.cardRotation = 0.0
        self.dragOffset = .zero
        self.isDragging = false
        self.isAdvancing = false
        self.isSessionCompleted = balancedQueue.isEmpty
        self.reviewHistory = []
    }

    var currentCard: VocabularyItem? {
        guard currentIndex >= 0 && currentIndex < deck.count else { return nil }
        return deck[currentIndex]
    }

    var totalItems: Int {
        deck.count
    }

    var progressText: String {
        guard !deck.isEmpty else { return "0/0" }
        return "\(min(currentIndex + 1, deck.count)) / \(deck.count)"
    }

    var progressRatio: Double {
        guard !deck.isEmpty else { return 0.0 }
        return Double(currentIndex + 1) / Double(deck.count)
    }

    var canUndoLastSwipe: Bool {
        !reviewHistory.isEmpty && !isAdvancing
    }

    // MARK: - 3D Card Flip Action
    func flipCard() {
        HapticFeedback.light()
        withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
            isFlipped.toggle()
            cardRotation += 180.0
        }
    }

    // MARK: - Swipe Left: Cần ôn tập (.again)
    func swipeLeftNeedsReview(in modelContext: ModelContext) {
        guard let item = currentCard, !isAdvancing else { return }
        isAdvancing = true
        saveReviewState(for: item)

        // Animate fly off to the left
        withAnimation(.easeOut(duration: 0.22)) {
            dragOffset = CGSize(width: -500, height: 0)
        }

        HapticFeedback.light()
        reviewNeededCount += 1

        // SM-2: Process quality as .again
        SRSEngine.shared.processReview(item: item, quality: .again)
        try? modelContext.save()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            self.advanceToNextCard()
        }
    }

    // MARK: - Swipe Right: Đã thuộc (.good)
    func swipeRightMastered(in modelContext: ModelContext) {
        guard let item = currentCard, !isAdvancing else { return }
        isAdvancing = true
        saveReviewState(for: item)

        // Animate fly off to the right
        withAnimation(.easeOut(duration: 0.22)) {
            dragOffset = CGSize(width: 500, height: 0)
        }

        HapticFeedback.success()
        masteredCount += 1

        // SM-2: Process quality as .good
        SRSEngine.shared.processReview(item: item, quality: .good)
        try? modelContext.save()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            self.advanceToNextCard()
        }
    }

    // MARK: - Drag Gesture Event Handling
    func handleDragChanged(translation: CGSize) {
        guard !isAdvancing else { return }
        isDragging = true
        dragOffset = translation
    }

    func handleDragEnded(translation: CGSize, in modelContext: ModelContext) {
        guard !isAdvancing else { return }
        isDragging = false
        let threshold: CGFloat = 85.0

        if translation.width > threshold {
            swipeRightMastered(in: modelContext)
        } else if translation.width < -threshold {
            swipeLeftNeedsReview(in: modelContext)
        } else {
            // Snap back
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                dragOffset = .zero
            }
        }
    }

    // MARK: - Advance Card
    private func advanceToNextCard() {
        isFlipped = false
        cardRotation = 0.0
        dragOffset = .zero

        if currentIndex + 1 < deck.count {
            currentIndex += 1
            SessionProgressManager.shared.saveFlashcardSession(
                deckId: activeDeckFilter?.id,
                currentIndex: currentIndex,
                masteredCount: masteredCount,
                reviewNeededCount: reviewNeededCount
            )
        } else {
            SessionProgressManager.shared.clearFlashcardSession(deckId: activeDeckFilter?.id)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                isSessionCompleted = true
            }
            HapticFeedback.success()
        }
        isAdvancing = false
    }

    // MARK: - Undo
    /// Restores the most recently swiped card and its SRS data. This only affects
    /// the current practice session, so it is safe to use for an accidental swipe.
    func undoLastSwipe(in modelContext: ModelContext) {
        guard !isAdvancing, let previousReview = reviewHistory.popLast() else { return }

        let item = previousReview.item
        item.isMastered = previousReview.isMastered
        item.step = previousReview.step
        item.easeFactor = previousReview.easeFactor
        item.intervalDays = previousReview.intervalDays
        item.nextReviewDate = previousReview.nextReviewDate
        item.lastReviewedDate = previousReview.lastReviewedDate
        try? modelContext.save()

        currentIndex = previousReview.index
        isSessionCompleted = false
        isFlipped = false
        cardRotation = 0.0
        dragOffset = .zero
        HapticFeedback.light()

        SessionProgressManager.shared.saveFlashcardSession(
            deckId: activeDeckFilter?.id,
            currentIndex: currentIndex,
            masteredCount: masteredCount,
            reviewNeededCount: reviewNeededCount
        )
    }

    private func saveReviewState(for item: VocabularyItem) {
        reviewHistory.append(
            ReviewHistory(
                item: item,
                index: currentIndex,
                isMastered: item.isMastered,
                step: item.step,
                easeFactor: item.easeFactor,
                intervalDays: item.intervalDays,
                nextReviewDate: item.nextReviewDate,
                lastReviewedDate: item.lastReviewedDate
            )
        )
    }

    func restartSession(with items: [VocabularyItem]) {
        SessionProgressManager.shared.clearFlashcardSession(deckId: activeDeckFilter?.id)
        loadDeck(from: items, deckFilter: activeDeckFilter)
    }
}
