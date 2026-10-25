import Foundation
import SwiftData
import UserNotifications

// MARK: - ReviewReminderService
/// Daily local notification that tells the learner exactly how many words the
/// SM-2 schedule wants reviewed. The badge count and body text are refreshed
/// from real SwiftData query results each time the app updates them.
final class ReviewReminderService {
    static let shared = ReviewReminderService()

    private let notificationId = "locklish_daily_review_reminder"
    private let defaultsKey = "locklish_daily_reminder_enabled"
    private let hourKey = "locklish_daily_reminder_hour"

    private init() {}

    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: defaultsKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: defaultsKey)
            if newValue {
                Task { await enableAndSchedule() }
            } else {
                disable()
            }
        }
    }

    /// Preferred reminder hour (default 20:00 — evening review slot).
    var reminderHour: Int {
        get {
            let stored = UserDefaults.standard.integer(forKey: hourKey)
            return (0...23).contains(stored) ? stored : 20
        }
        set {
            let clamped = min(max(newValue, 0), 23)
            UserDefaults.standard.set(clamped, forKey: hourKey)
            if isEnabled {
                Task { await enableAndSchedule() }
            }
        }
    }

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let notifications: UNAuthorizationOptions = [.alert, .badge, .sound]
        return (try? await center.requestAuthorization(options: notifications)) ?? false
    }

    // MARK: - Schedule

    /// Schedules (or reschedules) the repeating daily reminder with the CURRENT
    /// due-word count baked into the message.
    func enableAndSchedule() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        var granted = settings.authorizationStatus == .authorized
        if !granted {
            granted = await requestAuthorization()
        }
        guard granted else { return }

        let content = UNMutableNotificationContent()
        let dueCount = Self.currentDueCount()
        if dueCount > 0 {
            content.title = "Đến giờ ôn từ vựng! 🔔"
            content.body = "Hôm nay có \(dueCount) từ cần ôn theo lịch nhắc thông minh. Giữ chuỗi ngày học của bạn nhé!"
        } else {
            content.title = "Một chút tiếng Anh mỗi ngày ✨"
            content.body = "Hôm nay chưa có từ nào đến hạn — vào học từ mới hoặc xem lại folder của bạn nhé!"
        }
        content.sound = .default

        var components = DateComponents()
        components.hour = reminderHour
        components.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: notificationId, content: content, trigger: trigger)

        // Replace any previous schedule so the count never goes stale
        center.removePendingNotificationRequests(withIdentifiers: [notificationId])
        try? await center.add(request)
    }

    func disable() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [notificationId])
    }

    /// Call after practice sessions so tomorrow's message carries the fresh count.
    func refreshMessage() {
        guard isEnabled else { return }
        Task { await enableAndSchedule() }
    }

    // MARK: - Due Count (SM-2 truth)

    /// Words across every deck whose SM-2 review lands today or earlier.
    /// Reuses the app's own container (same store, same CloudKit state).
    private static func currentDueCount() -> Int {
        let context = ModelContext(LocklishApp.sharedModelContainer)
        let startOfTomorrow = Calendar.current.date(
            byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date())
        ) ?? Date()

        let descriptor = FetchDescriptor<VocabularyItem>()
        guard let items = try? context.fetch(descriptor) else { return 0 }
        return items.filter { $0.lastReviewedDate != nil && $0.nextReviewDate < startOfTomorrow }.count
    }
}
