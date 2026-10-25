import Foundation
import SwiftData
import SwiftUI

// MARK: - VocabularyDeck Model
/// SwiftData entity representing a custom collection / folder of vocabulary items.
/// Allows learners to organize words by source, topic, or objective (e.g. "IELTS Writing", "IT Terms", "PDF Scan 11/10").
@Model
final class VocabularyDeck: Identifiable {
    // CloudKit-backed SwiftData: no .unique constraints, every attribute needs
    // a default, and relationships declare an explicit inverse.
    var id: UUID = UUID()
    var name: String = ""
    var deckDescription: String = ""
    var createdAt: Date = Date()
    var colorHex: String = "#4E73DF"

    // CloudKit requires relationships to be optional — the array stays nil
    // for empty decks instead of holding an empty non-optional relationship.
    @Relationship(deleteRule: .cascade, inverse: \VocabularyItem.deck)
    var items: [VocabularyItem]? = nil

    init(
        id: UUID = UUID(),
        name: String,
        deckDescription: String = "",
        createdAt: Date = Date(),
        colorHex: String = "#4E73DF",
        items: [VocabularyItem] = []
    ) {
        self.id = id
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.deckDescription = deckDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        self.createdAt = createdAt
        self.colorHex = colorHex
        self.items = items
    }

    // MARK: - Convenience Computed Properties
    var wordCount: Int {
        (items ?? []).count
    }

    var masteredCount: Int {
        (items ?? []).filter { $0.isMastered }.count
    }

    var unmasteredCount: Int {
        (items ?? []).filter { !$0.isMastered }.count
    }

    var progressRatio: Double {
        let all = items ?? []
        guard !all.isEmpty else { return 0.0 }
        return Double(masteredCount) / Double(all.count)
    }

    var accentColor: Color {
        Color(hex: colorHex)
    }
}
