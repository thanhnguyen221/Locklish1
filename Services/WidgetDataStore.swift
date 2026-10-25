import Foundation
import SwiftData
import WidgetKit

// MARK: - WidgetDataStore
/// Computes the widget's numbers from live SwiftData items (one pass) and
/// pushes them into the shared App Group, then reloads widget timelines so the
/// home screen updates immediately after practice.
enum WidgetDataStore {
    /// One shared container for out-of-view refreshes (practice screens call
    /// this when they disappear, so the widget updates right after a session).
    private static let queryContainer: ModelContainer? = try? ModelContainer(
        for: VocabularyItem.self, VocabularyDeck.self, DailyPracticeRecord.self
    )

    /// Fetches every item through a lightweight context and pushes the widget.
    static func refreshFromModel() {
        guard let container = queryContainer else { return }
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<VocabularyItem>()
        guard let items = try? context.fetch(descriptor) else { return }
        refresh(items: items)
    }

    static func refresh(items: [VocabularyItem]) {
        let startOfTomorrow = Calendar.current.date(
            byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date())
        ) ?? Date()

        var due = 0
        var mastered = 0
        for item in items {
            if item.isMastered { mastered += 1 }
            if item.lastReviewedDate != nil && item.nextReviewDate < startOfTomorrow {
                due += 1
            }
        }

        var snapshot = WidgetSnapshot.load()
        snapshot.dueCount = due
        snapshot.masteredCount = mastered
        snapshot.totalWords = items.count
        snapshot.updatedAt = Date()
        snapshot.save()

        WidgetCenter.shared.reloadAllTimelines()
    }
}
