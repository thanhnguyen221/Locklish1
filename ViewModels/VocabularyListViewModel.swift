import Foundation
import SwiftData
import SwiftUI

// MARK: - VocabularyFilter
enum VocabularyFilter: String, CaseIterable, Identifiable {
    case all = "Tất cả"
    case learning = "Đang học"
    case mastered = "Đã thuộc"

    var id: String { rawValue }
}

// MARK: - VocabularySort
enum VocabularySort: String, CaseIterable, Identifiable {
    case newest = "Mới nhất"
    case alphabetical = "A - Z"

    var id: String { rawValue }
}

// MARK: - VocabularyListViewModel
@Observable
@MainActor
final class VocabularyListViewModel {
    var searchText: String = ""
    var selectedFilter: VocabularyFilter = .all
    var selectedSort: VocabularySort = .newest
    var isImportSheetPresented: Bool = false
    var isAddWordSheetPresented: Bool = false
    var selectedItemForDetail: VocabularyItem? = nil

    /// Filters and sorts vocabulary items based on current view criteria.
    func filteredItems(_ items: [VocabularyItem]) -> [VocabularyItem] {
        var result = items

        // Search text filtering
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !query.isEmpty {
            result = result.filter { item in
                item.word.lowercased().contains(query) ||
                item.meaning.lowercased().contains(query) ||
                item.viPhonetic.lowercased().contains(query) ||
                item.ipa.lowercased().contains(query)
            }
        }

        // Segment filter
        switch selectedFilter {
        case .all:
            break
        case .learning:
            result = result.filter { !$0.isMastered }
        case .mastered:
            result = result.filter { $0.isMastered }
        }

        // Sorting
        switch selectedSort {
        case .newest:
            result.sort { $0.createdAt > $1.createdAt }
        case .alphabetical:
            result.sort { $0.word.localizedCaseInsensitiveCompare($1.word) == .orderedAscending }
        }

        return result
    }

    /// Toggles mastery status of an item in SwiftData
    func toggleMastery(for item: VocabularyItem, in modelContext: ModelContext) {
        HapticFeedback.light()
        item.isMastered.toggle()
        try? modelContext.save()
    }

    /// Deletes an item from SwiftData
    func deleteItem(_ item: VocabularyItem, in modelContext: ModelContext) {
        HapticFeedback.medium()
        modelContext.delete(item)
        try? modelContext.save()
    }
}
