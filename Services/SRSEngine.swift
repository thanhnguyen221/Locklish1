import Foundation
import SwiftData

// MARK: - ReviewQuality Enum
/// SuperMemo-2 quality rating (0 to 5 scale).
public enum ReviewQuality: Int, CaseIterable, Identifiable {
    case again = 1 // Incorrect / Complete blackout
    case hard = 2  // Correct with substantial difficulty
    case good = 3  // Correct with normal hesitation
    case easy = 5  // Perfect effortless recall

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .again: return "Cần ôn tập"
        case .hard: return "Khó nhớ"
        case .good: return "Đã thuộc"
        case .easy: return "Rất dễ"
        }
    }
}

// MARK: - SRSEngine
/// Production implementation of the SuperMemo SM-2 Spaced Repetition Algorithm.
/// Dynamically schedules vocabulary reviews based on recall strength and learning history.
final class SRSEngine {
    static let shared = SRSEngine()

    private init() {}

    // MARK: - SM-2 Core Calculation
    /// Processes a review attempt on a `VocabularyItem` according to the SM-2 algorithm.
    /// Updates `step`, `easeFactor`, `intervalDays`, `lastReviewedDate`, and `nextReviewDate`.
    /// - Parameters:
    ///   - item: The item being reviewed.
    ///   - quality: The user's recall quality (.again, .hard, .good, .easy).
    ///   - reviewDate: The date of the review (defaults to now).
    func processReview(
        item: VocabularyItem,
        quality: ReviewQuality,
        reviewDate: Date = Date()
    ) {
        let q = Double(quality.rawValue)

        // Count the attempt so statistics can show genuinely review-heavy words.
        item.reviewCount += 1
        // Any graded practice keeps the daily learning streak alive.
        StreakService.shared.recordPracticeDay()

        // 1. Update Ease Factor (EF' = EF + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02)))
        // Minimum EF is clamped to 1.3 to avoid interval stagnation.
        let delta = 0.1 - (5.0 - q) * (0.08 + (5.0 - q) * 0.02)
        item.easeFactor = max(1.3, item.easeFactor + delta)

        // 2. Repetition & Interval Calculation
        if quality.rawValue < 3 {
            // Failure (.again or .hard): reset repetition step back to 0
            item.step = 0
            item.intervalDays = 1
            item.isMastered = false
        } else {
            // Success (.good or .easy)
            switch item.step {
            case 0:
                item.intervalDays = 1
            case 1:
                item.intervalDays = 6
            default:
                let nextInterval = Double(item.intervalDays) * item.easeFactor
                // Bonus for effortless recall
                let bonus = (quality == .easy) ? 1.2 : 1.0
                item.intervalDays = max(1, Int(round(nextInterval * bonus)))
            }
            item.step += 1
            item.isMastered = true
        }

        // 3. Update Review Timestamps
        item.lastReviewedDate = reviewDate
        let calendar = Calendar.current
        item.nextReviewDate = calendar.date(byAdding: .day, value: item.intervalDays, to: reviewDate) ?? reviewDate
    }

    // MARK: - Due & Overdue Evaluation
    /// Returns true if the item is due or overdue for review on the specified date.
    func isDue(item: VocabularyItem, on date: Date = Date()) -> Bool {
        // Items never reviewed or unmastered are immediately due
        if !item.isMastered || item.lastReviewedDate == nil {
            return true
        }
        return item.nextReviewDate <= date
    }

    // MARK: - Dynamic Load Balancing & SM-2 Prioritization
    /// Prioritizes vocabulary items: unmastered first, then earliest nextReviewDate (most overdue).
    /// - If limit is specified, returns up to `limit` items (e.g. for daily unlock challenge).
    /// - If limit is nil, returns ALL items in prioritized order (e.g. for complete deck practice).
    func balanceDailyQueue(from items: [VocabularyItem], limit: Int? = nil) -> [VocabularyItem] {
        let now = Date()

        // Partition into due and not due
        let dueItems = items.filter { isDue(item: $0, on: now) }

        // Sort by priority: unmastered first, then earliest nextReviewDate (most overdue)
        let sortedDue = dueItems.sorted { item1, item2 in
            if item1.isMastered != item2.isMastered {
                return !item1.isMastered // unmastered first
            }
            return item1.nextReviewDate < item2.nextReviewDate
        }

        let otherItems = items.filter { !isDue(item: $0, on: now) }
            .sorted { $0.nextReviewDate < $1.nextReviewDate }

        let fullQueue = sortedDue + otherItems

        if let limit = limit {
            return Array(fullQueue.prefix(limit))
        }

        return fullQueue
    }
}
