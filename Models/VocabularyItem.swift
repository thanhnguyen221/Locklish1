import Foundation
import SwiftData

// MARK: - VocabularyItem Model
/// Core SwiftData entity representing an English vocabulary word with US IPA and
/// natural Vietnamese phonetic pronunciation ("sờ-ké-chồ").
@Model
final class VocabularyItem: Identifiable {
    // CloudKit-backed SwiftData: no .unique constraints, every attribute needs
    // a default, and relationships must be optional with an inverse.
    var id: UUID = UUID()
    var word: String = ""
    var ipa: String = ""
    var viPhonetic: String = ""
    var partOfSpeech: String = ""
    var meaning: String = ""
    var note: String = ""
    var example: String = ""
    var exampleTranslation: String = ""
    var collocationPhrase: String = ""
    var collocationMeaning: String = ""
    var collocationUsage: String = ""
    var imageURL: String?
    @Attribute(.externalStorage) var imageData: Data?
    var isMastered: Bool = false
    var createdAt: Date = Date()

    /// Inverse of VocabularyDeck.items — required by CloudKit sync.
    var deck: VocabularyDeck? = nil

    // MARK: - Flexible Learning Content
    /// `word`, `collocation`, or `multiple_choice`. Keeping this as a String makes
    /// the persisted model extensible without tying it to a particular textbook.
    var itemType: String = "word"
    /// A user-defined grouping label, such as "Tuần 2", "Bài 01", or "Chương 3".
    var unitTag: String?
    /// The prompt for a fill-in-the-blank / multiple-choice learning item.
    var questionSentence: String?
    /// Choices in display order (normally A through D).
    var options: [String]?
    /// Zero-based index of the correct entry in `options`.
    var correctOptionIndex: Int?

    // MARK: - SM-2 SRS (Spaced Repetition System) Fields
    var step: Int = 0
    var easeFactor: Double = 2.5
    var intervalDays: Int = 0
    var nextReviewDate: Date = Date()
    var lastReviewedDate: Date? = nil
    /// Total number of graded review attempts on this word — drives the
    /// "đã ôn N lần" statistics so frequently-reviewed words are visible.
    var reviewCount: Int = 0

    init(
        id: UUID = UUID(),
        word: String,
        ipa: String = "",
        viPhonetic: String = "",
        partOfSpeech: String = "",
        meaning: String,
        note: String = "",
        example: String = "",
        exampleTranslation: String = "",
        collocationPhrase: String = "",
        collocationMeaning: String = "",
        collocationUsage: String = "",
        imageURL: String? = nil,
        imageData: Data? = nil,
        isMastered: Bool = false,
        createdAt: Date = Date(),
        itemType: String = "word",
        unitTag: String? = nil,
        questionSentence: String? = nil,
        options: [String]? = nil,
        correctOptionIndex: Int? = nil,
        step: Int = 0,
        easeFactor: Double = 2.5,
        intervalDays: Int = 0,
        nextReviewDate: Date = Date(),
        lastReviewedDate: Date? = nil,
        reviewCount: Int = 0
    ) {
        self.id = id
        self.word = word.trimmingCharacters(in: .whitespacesAndNewlines)
        self.ipa = ipa.trimmingCharacters(in: .whitespacesAndNewlines)
        self.viPhonetic = viPhonetic.trimmingCharacters(in: .whitespacesAndNewlines)
        self.partOfSpeech = partOfSpeech.trimmingCharacters(in: .whitespacesAndNewlines)
        self.meaning = meaning.trimmingCharacters(in: .whitespacesAndNewlines)
        self.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        self.example = example.trimmingCharacters(in: .whitespacesAndNewlines)
        self.exampleTranslation = exampleTranslation.trimmingCharacters(in: .whitespacesAndNewlines)
        self.collocationPhrase = collocationPhrase.trimmingCharacters(in: .whitespacesAndNewlines)
        self.collocationMeaning = collocationMeaning.trimmingCharacters(in: .whitespacesAndNewlines)
        self.collocationUsage = collocationUsage.trimmingCharacters(in: .whitespacesAndNewlines)
        self.imageURL = imageURL
        self.imageData = imageData
        self.isMastered = isMastered
        self.createdAt = createdAt
        self.itemType = itemType
        self.unitTag = unitTag?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        self.questionSentence = questionSentence?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        self.options = options?.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        self.correctOptionIndex = correctOptionIndex
        self.step = step
        self.easeFactor = easeFactor
        self.intervalDays = intervalDays
        self.nextReviewDate = nextReviewDate
        self.lastReviewedDate = lastReviewedDate
        self.reviewCount = reviewCount
    }
}

extension VocabularyItem {
    var isMultipleChoice: Bool {
        itemType == "multiple_choice"
    }

    /// Text appropriate for a card title and automatic speech. Existing word data
    /// keeps using `word`; question records use their dedicated prompt.
    var learningPrompt: String {
        if isMultipleChoice, let questionSentence, !questionSentence.isEmpty {
            return questionSentence
        }
        return word
    }

    /// Returns `note` if non-empty, otherwise falls back to `example` (with `exampleTranslation` if available)
    var displayNote: String {
        let content = separatedContent
        if !content.note.isEmpty { return content.note }
        if !content.example.isEmpty && !content.translation.isEmpty {
            return "\(content.example)\n(\(content.translation))"
        }
        return !content.example.isEmpty ? content.example : content.translation
    }

    // MARK: - Smart Splitting for Example & Note
    struct ExampleAndNote {
        let example: String
        let translation: String
        let note: String
    }

    /// Intelligently parses and separates English example sentence, Vietnamese translation, and note
    static func splitExampleAndNote(rawExample: String, rawTranslation: String, rawNote: String) -> ExampleAndNote {
        let ex = rawExample.trimmingCharacters(in: .whitespacesAndNewlines)
        let tr = rawTranslation.trimmingCharacters(in: .whitespacesAndNewlines)
        var nt = rawNote.trimmingCharacters(in: .whitespacesAndNewlines)

        // If example already exists separately, just clean "Ghi chú:" from note if needed
        if !ex.isEmpty {
            if nt.localizedCaseInsensitiveContains("ghi chú:") {
                if let range = nt.range(of: "Ghi chú:", options: .caseInsensitive) {
                    nt = String(nt[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            return ExampleAndNote(example: ex, translation: tr, note: nt)
        }

        // If example is empty, but note contains combined text (e.g. "Ví dụ: ... Ghi chú: ...")
        if nt.localizedCaseInsensitiveContains("ví dụ:") || nt.localizedCaseInsensitiveContains("ghi chú:") {
            var extractedNote = ""
            var exampleBlock = nt

            // 1. Separate note part if "Ghi chú:" exists
            if let noteRange = nt.range(of: "Ghi chú:", options: .caseInsensitive) {
                exampleBlock = String(nt[..<noteRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                extractedNote = String(nt[noteRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            }

            // 2. Remove "Ví dụ:" prefix
            if let exRange = exampleBlock.range(of: "Ví dụ:", options: .caseInsensitive) {
                exampleBlock = String(exampleBlock[exRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            }

            // 3. Extract translation from parentheses "(...)" at end of sentence
            var extractedExample = exampleBlock
            var extractedTranslation = tr
            if let openParen = exampleBlock.range(of: "(", options: .backwards),
               let closeParen = exampleBlock.range(of: ")", options: .backwards),
               openParen.lowerBound < closeParen.lowerBound {
                let insideParen = String(exampleBlock[openParen.upperBound..<closeParen.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                let beforeParen = String(exampleBlock[..<openParen.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !beforeParen.isEmpty && !insideParen.isEmpty {
                    extractedExample = beforeParen
                    if extractedTranslation.isEmpty {
                        extractedTranslation = insideParen
                    }
                }
            }

            return ExampleAndNote(example: extractedExample, translation: extractedTranslation, note: extractedNote)
        }

        return ExampleAndNote(example: ex, translation: tr, note: nt)
    }

    var separatedContent: ExampleAndNote {
        Self.splitExampleAndNote(rawExample: example, rawTranslation: exampleTranslation, rawNote: note)
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

// MARK: - Codable DTO for Gemini AI Extraction
/// Decodable structure matching Gemini AI's JSON output schema.
struct VocabularyItemDTO: Codable, Identifiable {
    var id: String?
    let word: String
    let ipa: String
    let viPhonetic: String
    let partOfSpeech: String
    let meaning: String
    let note: String?
    let example: String?
    let exampleTranslation: String?
    let collocationPhrase: String?
    let collocationMeaning: String?
    let collocationUsage: String?
    let imageURL: String?

    func toModel() -> VocabularyItem {
        let parsed = VocabularyItem.splitExampleAndNote(
            rawExample: example ?? "",
            rawTranslation: exampleTranslation ?? "",
            rawNote: note ?? ""
        )

        return VocabularyItem(
            id: UUID(),
            word: word,
            ipa: ipa,
            viPhonetic: viPhonetic,
            partOfSpeech: partOfSpeech,
            meaning: meaning,
            note: parsed.note,
            example: parsed.example,
            exampleTranslation: parsed.translation,
            collocationPhrase: collocationPhrase ?? "",
            collocationMeaning: collocationMeaning ?? "",
            collocationUsage: collocationUsage ?? "",
            imageURL: imageURL,
            imageData: nil,
            isMastered: false,
            createdAt: Date()
        )
    }
}

// MARK: - Preview Sample Data
extension VocabularyItem {
    static var sampleItems: [VocabularyItem] {
        [
            VocabularyItem(
                word: "Schedule",
                ipa: "/ˈskedʒ.uːl/",
                viPhonetic: "sờ-ké-chồ",
                partOfSpeech: "noun",
                meaning: "Kế hoạch, lịch trình công việc hoặc sự kiện",
                example: "Let's review the production schedule before tomorrow morning.",
                isMastered: false
            ),
            VocabularyItem(
                word: "Resilient",
                ipa: "/rɪˈzɪl.jənt/",
                viPhonetic: "ri-díl-li-ừn-t",
                partOfSpeech: "adjective",
                meaning: "Kiên cường, có khả năng phục hồi nhanh chóng",
                example: "She proved to be remarkably resilient after facing major setbacks.",
                isMastered: false
            ),
            VocabularyItem(
                word: "Ubiquitous",
                ipa: "/juːˈbɪk.wɪ.təs/",
                viPhonetic: "diu-bíc-qui-tợs",
                partOfSpeech: "adjective",
                meaning: "Có mặt ở khắp nơi, phổ biến rộng rãi",
                example: "Smartphones have become ubiquitous in modern urban life.",
                isMastered: true
            ),
            VocabularyItem(
                word: "Meticulous",
                ipa: "/məˈtɪk.jə.ləs/",
                viPhonetic: "mờ-tíc-kiu-lợs",
                partOfSpeech: "adjective",
                meaning: "Tỉ mỉ, cẩn thận từng chi tiết nhỏ",
                example: "He took meticulous notes during the entire technical workshop.",
                isMastered: false
            )
        ]
    }
}
