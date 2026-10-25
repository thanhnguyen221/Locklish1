import Foundation
import SwiftUI

// MARK: - GameWordItem
/// A structured vocabulary item inside a themed game round.
/// Supports custom user images/illustrations for commercial customization.
public struct GameWordItem: Codable, Identifiable, Equatable {
    public var id: String
    public var word: String
    public var meaning: String
    public var ipa: String
    public var viPhonetic: String
    public var exampleSentence: String
    public var exampleBlankSentence: String
    public var exampleTranslation: String
    public var iconEmoji: String
    public var imageURL: String?
    public var imageData: Data?
    public var isMastered: Bool
    public var isFavorite: Bool

    public init(
        id: String = UUID().uuidString,
        word: String,
        meaning: String,
        ipa: String = "",
        viPhonetic: String = "",
        exampleSentence: String,
        exampleBlankSentence: String = "",
        exampleTranslation: String = "",
        iconEmoji: String = "📖",
        imageURL: String? = nil,
        imageData: Data? = nil,
        isMastered: Bool = false,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.word = word
        self.meaning = meaning
        self.ipa = ipa
        self.viPhonetic = viPhonetic
        self.exampleSentence = exampleSentence
        let trimmedWord = word.trimmingCharacters(in: .whitespacesAndNewlines)
        if !exampleBlankSentence.isEmpty {
            self.exampleBlankSentence = exampleBlankSentence
        } else if let range = exampleSentence.range(of: trimmedWord, options: .caseInsensitive) {
            self.exampleBlankSentence = exampleSentence.replacingCharacters(in: range, with: "________")
        } else {
            self.exampleBlankSentence = exampleSentence.replacingOccurrences(of: trimmedWord, with: "________", options: .caseInsensitive)
        }
        self.exampleTranslation = exampleTranslation
        self.iconEmoji = iconEmoji
        self.imageURL = imageURL
        self.imageData = imageData
        self.isMastered = isMastered
        self.isFavorite = isFavorite
    }
}

// MARK: - GameThemeRound
/// A themed level on the roadmap (e.g. Giao thông, Trái cây, Nội thất, Đồ ăn, Động vật...).
public struct GameThemeRound: Codable, Identifiable, Equatable {
    public var id: Int
    public var title: String
    public var englishCategory: String
    public var iconEmoji: String
    public var accentColorHex: String
    public var level: String // "A1", "A2", "B1", "B2", "C2"
    public var words: [GameWordItem]
    public var starsEarned: Int // 0 to 3 stars
    public var isLocked: Bool

    public var isCompleted: Bool {
        starsEarned > 0
    }

    public var masteredCount: Int {
        words.filter(\.isMastered).count
    }

    public var progressText: String {
        "\(masteredCount)/\(words.count)"
    }

    public var accentColor: Color {
        Color(hex: accentColorHex)
    }

    enum CodingKeys: String, CodingKey {
        case id, title, englishCategory, iconEmoji, accentColorHex, level, words, starsEarned, isLocked
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        englishCategory = try container.decode(String.self, forKey: .englishCategory)
        iconEmoji = try container.decode(String.self, forKey: .iconEmoji)
        accentColorHex = try container.decode(String.self, forKey: .accentColorHex)
        level = try container.decodeIfPresent(String.self, forKey: .level) ?? "A1"
        words = try container.decode([GameWordItem].self, forKey: .words)
        starsEarned = try container.decode(Int.self, forKey: .starsEarned)
        isLocked = try container.decode(Bool.self, forKey: .isLocked)
    }

    public init(
        id: Int,
        title: String,
        englishCategory: String,
        iconEmoji: String,
        accentColorHex: String = "#527870",
        level: String = "A1",
        words: [GameWordItem],
        starsEarned: Int = 0,
        isLocked: Bool = false
    ) {
        self.id = id
        self.title = title
        self.englishCategory = englishCategory
        self.iconEmoji = iconEmoji
        self.accentColorHex = accentColorHex
        self.level = level
        self.words = words
        self.starsEarned = starsEarned
        self.isLocked = isLocked
    }
}
