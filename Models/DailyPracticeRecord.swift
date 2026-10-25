import Foundation
import SwiftData

// MARK: - DailyPracticeRecord Model
/// Tracks daily practice progress, dictation accuracy, and completion state.
/// When completion reaches 100%, the focus shield is unlocked for the day.
@Model
final class DailyPracticeRecord: Identifiable {
    var id: UUID = UUID()
    var dateString: String = DailyPracticeRecord.currentDateString()
    var totalAssigned: Int = 0
    var totalCompleted: Int = 0
    var isFullyCompleted: Bool = false
    var completedAt: Date? = nil

    init(
        id: UUID = UUID(),
        dateString: String = DailyPracticeRecord.currentDateString(),
        totalAssigned: Int = 0,
        totalCompleted: Int = 0,
        isFullyCompleted: Bool = false,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.dateString = dateString
        self.totalAssigned = totalAssigned
        self.totalCompleted = totalCompleted
        self.isFullyCompleted = isFullyCompleted
        self.completedAt = completedAt
    }

    var progressRatio: Double {
        guard totalAssigned > 0 else { return 0.0 }
        return min(1.0, Double(totalCompleted) / Double(totalAssigned))
    }

    var percentageFormatted: String {
        let percent = Int(progressRatio * 100)
        return "\(percent)%"
    }

    static func currentDateString(from date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter.string(from: date)
    }
}
