import Foundation

// MARK: - StreakService
/// Daily learning streak tracker. A single hook in SRSEngine.processReview —
/// which every practice flow calls — records the day, so the streak reflects
/// ANY graded practice (flashcards, dictation, speaking, games).
final class StreakService {
    static let shared = StreakService()

    private let daysKey = "locklish_practice_days"
    private let bestKey = "locklish_best_streak"

    private init() {}

    // MARK: - Recording

    func recordPracticeDay(_ date: Date = Date()) {
        let key = dayString(date)
        var days = practicedDays
        guard !days.contains(key) else { return }
        days.insert(key)
        // Keep the set bounded — a rolling 2 years is far beyond any streak.
        if days.count > 730 {
            let cutoff = dayString(Calendar.current.date(byAdding: .day, value: -730, to: date) ?? date)
            days.subtract(days.filter { $0 < cutoff })
        }
        UserDefaults.standard.set(Array(days), forKey: daysKey)

        let streak = currentStreak
        if streak > bestStreak {
            UserDefaults.standard.set(streak, forKey: bestKey)
        }
    }

    // MARK: - Queries

    private var practicedDays: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: daysKey) ?? [])
    }

    var bestStreak: Int {
        UserDefaults.standard.integer(forKey: bestKey)
    }

    /// Consecutive practice days ending today (or yesterday, if today has no
    /// practice yet — the streak is still alive until the day ends).
    var currentStreak: Int {
        let calendar = Calendar.current
        let today = dayString(Date())
        let days = practicedDays

        var streak = 0
        var cursor = calendar.startOfDay(for: Date())

        // Streak counts from today if practiced, else it's "at risk" from yesterday
        if !days.contains(today) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) else { return 0 }
            cursor = yesterday
        }

        while days.contains(dayString(cursor)) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    /// True when today already has at least one graded practice.
    var practicedToday: Bool {
        practicedDays.contains(dayString(Date()))
    }

    private func dayString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }
}
