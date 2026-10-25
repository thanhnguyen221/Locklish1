import Foundation
import SwiftData
import WidgetKit

// MARK: - WidgetDataStore
/// Computes the widget's numbers from live SwiftData items (one pass) and
/// pushes them into the shared App Group, then reloads widget timelines so the
/// home screen updates immediately after practice.
enum WidgetDataStore {
    /// Reuses the app's own container (same store, same CloudKit state) —
    /// creating a second default container caused a duplicate store file and
    /// a second CloudKit initialization that failed on simulator.
    static func refreshFromModel() {
        let context = ModelContext(LocklishApp.sharedModelContainer)
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
