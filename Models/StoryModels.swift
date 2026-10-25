import Foundation
import SwiftUI

// MARK: - StoryParagraph
struct StoryParagraph: Identifiable, Codable {
    var id: UUID = UUID()
    let en: String
    let vi: String

    enum CodingKeys: String, CodingKey {
        case en
        case vi
    }

    init(id: UUID = UUID(), en: String, vi: String) {
        self.id = id
        self.en = en
        self.vi = vi
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.en = try container.decode(String.self, forKey: .en)
        self.vi = try container.decode(String.self, forKey: .vi)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(en, forKey: .en)
        try container.encode(vi, forKey: .vi)
    }
}

// MARK: - GeneratedStory
struct GeneratedStory: Identifiable, Codable {
    var id: UUID { deckId }
    let deckId: UUID
    let deckName: String
    let titleEn: String
    let titleVi: String
    let fullStoryEn: String
    let fullStoryVi: String
    let paragraphs: [StoryParagraph]
    let targetWords: [String]
    var wordLevels: [String: String]? = nil
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case deckId
        case deckName
        case titleEn
        case titleVi
        case fullStoryEn
        case fullStoryVi
        case paragraphs
        case targetWords
        case wordLevels
        case createdAt
    }

    init(
        deckId: UUID,
        deckName: String,
        titleEn: String,
        titleVi: String,
        fullStoryEn: String,
        fullStoryVi: String,
        paragraphs: [StoryParagraph],
        targetWords: [String],
        wordLevels: [String: String]? = nil,
        createdAt: Date = Date()
    ) {
        self.deckId = deckId
        self.deckName = deckName
        self.titleEn = titleEn
        self.titleVi = titleVi
        self.fullStoryEn = fullStoryEn
        self.fullStoryVi = fullStoryVi
        self.paragraphs = paragraphs
        self.targetWords = targetWords
        self.wordLevels = wordLevels
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.deckId = try container.decode(UUID.self, forKey: .deckId)
        self.deckName = try container.decode(String.self, forKey: .deckName)
        self.titleEn = try container.decode(String.self, forKey: .titleEn)
        self.titleVi = try container.decode(String.self, forKey: .titleVi)
        self.fullStoryEn = try container.decode(String.self, forKey: .fullStoryEn)
        self.fullStoryVi = try container.decode(String.self, forKey: .fullStoryVi)
        self.paragraphs = try container.decode([StoryParagraph].self, forKey: .paragraphs)
        self.targetWords = try container.decode([String].self, forKey: .targetWords)
        self.wordLevels = try container.decodeIfPresent([String: String].self, forKey: .wordLevels)
        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }
}

// MARK: - WordDetailInfo
struct WordDetailInfo: Identifiable, Codable, Equatable {
    var id: String { word.lowercased() }
    let word: String
    let ipa: String
    let viPhonetic: String
    let partOfSpeech: String
    let meaningVi: String
    let definitionEn: String
    let exampleEn: String
    let exampleVi: String
    let synonyms: [String]
    let antonyms: [String]
    let isTargetWord: Bool
    var cefrLevel: String = "B1"
    var contextSentenceEn: String? = nil
    var contextSentenceVi: String? = nil

    enum CodingKeys: String, CodingKey {
        case word
        case ipa
        case viPhonetic
        case partOfSpeech
        case meaningVi
        case definitionEn
        case exampleEn
        case exampleVi
        case synonyms
        case antonyms
        case isTargetWord
        case cefrLevel
        case contextSentenceEn
        case contextSentenceVi
    }

    init(
        word: String,
        ipa: String,
        viPhonetic: String,
        partOfSpeech: String,
        meaningVi: String,
        definitionEn: String,
        exampleEn: String,
        exampleVi: String,
        synonyms: [String],
        antonyms: [String],
        isTargetWord: Bool,
        cefrLevel: String = "B1",
        contextSentenceEn: String? = nil,
        contextSentenceVi: String? = nil
    ) {
        self.word = word
        self.ipa = ipa
        self.viPhonetic = viPhonetic
        self.partOfSpeech = partOfSpeech
        self.meaningVi = meaningVi
        self.definitionEn = definitionEn
        self.exampleEn = exampleEn
        self.exampleVi = exampleVi
        self.synonyms = synonyms
        self.antonyms = antonyms
        self.isTargetWord = isTargetWord
        self.cefrLevel = cefrLevel
        self.contextSentenceEn = contextSentenceEn
        self.contextSentenceVi = contextSentenceVi
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.word = try container.decode(String.self, forKey: .word)
        self.ipa = try container.decode(String.self, forKey: .ipa)
        self.viPhonetic = try container.decode(String.self, forKey: .viPhonetic)
        self.partOfSpeech = try container.decode(String.self, forKey: .partOfSpeech)
        self.meaningVi = try container.decode(String.self, forKey: .meaningVi)
        self.definitionEn = try container.decode(String.self, forKey: .definitionEn)
        self.exampleEn = try container.decode(String.self, forKey: .exampleEn)
        self.exampleVi = try container.decode(String.self, forKey: .exampleVi)
        self.synonyms = try container.decode([String].self, forKey: .synonyms)
        self.antonyms = try container.decode([String].self, forKey: .antonyms)
        self.isTargetWord = try container.decode(Bool.self, forKey: .isTargetWord)
        self.cefrLevel = try container.decodeIfPresent(String.self, forKey: .cefrLevel) ?? "B1"
        self.contextSentenceEn = try container.decodeIfPresent(String.self, forKey: .contextSentenceEn)
        self.contextSentenceVi = try container.decodeIfPresent(String.self, forKey: .contextSentenceVi)
    }

    static func == (lhs: WordDetailInfo, rhs: WordDetailInfo) -> Bool {
        lhs.word.lowercased() == rhs.word.lowercased()
    }
}

// MARK: - CEFRLevelHelper
enum CEFRLevelHelper {
    static func color(for level: String) -> Color {
        switch level.uppercased() {
        case "A1":
            return Color(red: 0.16, green: 0.65, blue: 0.38)
        case "A2":
            return Color(red: 0.18, green: 0.72, blue: 0.85)
        case "B1":
            return Color(red: 0.20, green: 0.50, blue: 0.95)
        case "B2":
            return Color(red: 0.95, green: 0.60, blue: 0.15)
        case "C1":
            return Color(red: 0.90, green: 0.35, blue: 0.20)
        case "C2":
            return Color(red: 0.68, green: 0.25, blue: 0.85)
        default:
            return Color(red: 0.20, green: 0.50, blue: 0.95)
        }
    }

    static func title(for level: String) -> String {
        switch level.uppercased() {
        case "A1": return "A1 - Căn bản"
        case "A2": return "A2 - Sơ cấp"
        case "B1": return "B1 - Trung cấp"
        case "B2": return "B2 - Trung cao"
        case "C1": return "C1 - Cao cấp"
        case "C2": return "C2 - Tinh thông"
        default: return level.uppercased()
        }
    }
}
