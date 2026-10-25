import Foundation

// MARK: - StoryGeneratorService
/// Generates contextual, engaging bilingual stories incorporating all vocabulary items
/// in a selected deck using Gemini AI with intelligent local fallback.
final class StoryGeneratorService {
    static let shared = StoryGeneratorService()

    private let userDefaults = UserDefaults.standard
    private let savedStoryPrefix = "locklish_story_deck_"

    private init() {}

    // MARK: - Persistence
    func getSavedStory(deckId: UUID) -> GeneratedStory? {
        guard let data = userDefaults.data(forKey: "\(savedStoryPrefix)\(deckId.uuidString)"),
              let story = try? JSONDecoder().decode(GeneratedStory.self, from: data) else {
            return nil
        }
        return story
    }

    func saveStory(_ story: GeneratedStory) {
        if let encoded = try? JSONEncoder().encode(story) {
            userDefaults.setValue(encoded, forKey: "\(savedStoryPrefix)\(story.deckId.uuidString)")
        }
    }

    func clearSavedStory(deckId: UUID) {
        userDefaults.removeObject(forKey: "\(savedStoryPrefix)\(deckId.uuidString)")
    }

    // MARK: - Generate Story
    enum StoryError: LocalizedError {
        case emptyDeck
        case generationFailed(String)

        var errorDescription: String? {
            switch self {
            case .emptyDeck:
                return "Danh mục chưa có từ vựng nào. Hãy thêm ít nhất 2 từ để AI tạo truyện!"
            case .generationFailed(let msg):
                return msg
            }
        }
    }

    func generateStory(
        deckId: UUID,
        deckName: String,
        items: [VocabularyItem],
        forceRegenerate: Bool = false
    ) async throws -> GeneratedStory {
        guard !items.isEmpty else {
            throw StoryError.emptyDeck
        }

        // Return cached if not forcing regeneration
        if !forceRegenerate, let saved = getSavedStory(deckId: deckId) {
            return saved
        }

        // Include 100% of all vocabulary items in the folder without truncation
        let targetItems = items

        // If Gemini API key is configured, use Gemini
        if GeminiService.shared.hasValidKey {
            do {
                let story = try await generateWithGemini(
                    deckId: deckId,
                    deckName: deckName,
                    targetItems: targetItems
                )
                saveStory(story)
                return story
            } catch {
                print("[StoryGeneratorService] Gemini failed: \(error). Falling back to smart template story.")
                let fallback = generateSmartFallbackStory(
                    deckId: deckId,
                    deckName: deckName,
                    items: targetItems
                )
                saveStory(fallback)
                return fallback
            }
        } else {
            // Smart template generation without API key
            let fallback = generateSmartFallbackStory(
                deckId: deckId,
                deckName: deckName,
                items: targetItems
            )
            saveStory(fallback)
            return fallback
        }
    }

    // MARK: - Gemini API Call
    private func generateWithGemini(
        deckId: UUID,
        deckName: String,
        targetItems: [VocabularyItem]
    ) async throws -> GeneratedStory {
        let wordsListString = targetItems.map { item in
            "- \(item.word) (\(item.partOfSpeech)): \(item.meaning)"
        }.joined(separator: "\n")

        let prompt = """
        You are a master bilingual English-Vietnamese storyteller and language teacher.
        Create an engaging, coherent, natural, and realistic short story under the topic "\(deckName)".
        The story MUST naturally incorporate and highlight ALL of these target vocabulary words (do not omit any):
        \(wordsListString)

        Requirements:
        1. Every single target word MUST be used naturally in context.
        2. Break the story into clean, well-paced paragraphs (2 to 6 paragraphs depending on the number of words).
        3. Provide an accurate, natural, fluent Vietnamese translation for each paragraph and the whole story.
        4. For each target word, evaluate its CEFR proficiency level (A1, A2, B1, B2, C1, or C2).
        5. Output MUST be ONLY valid JSON with this exact schema:
        {
          "titleEn": "Title in English",
          "titleVi": "Tiêu đề tiếng Việt",
          "fullStoryEn": "Full English story...",
          "fullStoryVi": "Toàn bộ bản dịch tiếng Việt...",
          "paragraphs": [
            {
              "en": "English paragraph text...",
              "vi": "Bản dịch tiếng Việt..."
            }
          ],
          "targetWords": ["word1", "word2"],
          "wordLevels": {
            "word1": "A2",
            "word2": "B1"
          }
        }
        """

        let apiKey = GeminiService.shared.apiKey
        let candidateModels = [
            "gemini-2.5-flash",
            "gemini-flash-latest",
            "gemini-2.0-flash",
            "gemini-1.5-flash-latest",
            "gemini-1.5-flash"
        ]

        let requestBody: [String: Any] = [
            "contents": [
                [
                    "role": "user",
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.5,
                "topP": 0.9,
                "responseMimeType": "application/json"
            ]
        ]

        let httpData = try JSONSerialization.data(withJSONObject: requestBody, options: [])
        var lastError: Error?

        for model in candidateModels {
            let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)"
            guard let url = URL(string: urlString) else { continue }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = httpData

            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    continue
                }

                if let story = try parseStoryResponse(data: data, deckId: deckId, deckName: deckName) {
                    return story
                }
            } catch {
                lastError = error
            }
        }

        if let err = lastError {
            throw err
        }
        throw StoryError.generationFailed("Không thể tạo truyện từ AI lúc này.")
    }

    private func parseStoryResponse(data: Data, deckId: UUID, deckName: String) throws -> GeneratedStory? {
        guard let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = jsonObject["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let textResponse = firstPart["text"] as? String else {
            return nil
        }

        // Clean possible markdown code fences
        var cleaned = textResponse.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```json") {
            cleaned = String(cleaned.dropFirst(7))
        } else if cleaned.hasPrefix("```") {
            cleaned = String(cleaned.dropFirst(3))
        }
        if cleaned.hasSuffix("```") {
            cleaned = String(cleaned.dropLast(3))
        }
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let jsonData = cleaned.data(using: .utf8),
              let dict = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return nil
        }

        let titleEn = dict["titleEn"] as? String ?? "Story for \(deckName)"
        let titleVi = dict["titleVi"] as? String ?? "Câu chuyện chủ đề \(deckName)"
        let fullStoryEn = dict["fullStoryEn"] as? String ?? ""
        let fullStoryVi = dict["fullStoryVi"] as? String ?? ""
        let targetWords = dict["targetWords"] as? [String] ?? []

        var paragraphs: [StoryParagraph] = []
        if let rawParas = dict["paragraphs"] as? [[String: Any]] {
            for p in rawParas {
                let en = p["en"] as? String ?? ""
                let vi = p["vi"] as? String ?? ""
                if !en.isEmpty {
                    paragraphs.append(StoryParagraph(en: en, vi: vi))
                }
            }
        }

        if paragraphs.isEmpty && !fullStoryEn.isEmpty {
            paragraphs.append(StoryParagraph(en: fullStoryEn, vi: fullStoryVi))
        }

        var wordLevels: [String: String] = [:]
        if let rawLevels = dict["wordLevels"] as? [String: String] {
            wordLevels = rawLevels
        }
        // Fallback for any target words missing in wordLevels
        for word in targetWords {
            let key = word.lowercased()
            if wordLevels[key] == nil && wordLevels[word] == nil {
                wordLevels[key] = WordInfoService.shared.resolveCEFRLevel(word: key)
            }
        }

        return GeneratedStory(
            deckId: deckId,
            deckName: deckName,
            titleEn: titleEn,
            titleVi: titleVi,
            fullStoryEn: fullStoryEn,
            fullStoryVi: fullStoryVi,
            paragraphs: paragraphs,
            targetWords: targetWords,
            wordLevels: wordLevels,
            createdAt: Date()
        )
    }

    // MARK: - Smart On-Device Fallback Story
    /// Generates a structured narrative without API calls using the words,
    /// definitions, and example sentences already stored in the deck.
    private func generateSmartFallbackStory(
        deckId: UUID,
        deckName: String,
        items: [VocabularyItem]
    ) -> GeneratedStory {
        let titleEn = "Daily Exploration: \(deckName)"
        let titleVi = "Khám phá mỗi ngày: \(deckName)"

        var enParagraphs: [String] = []
        var viParagraphs: [String] = []

        // Group into chunks of 3 items per paragraph
        let chunks = stride(from: 0, to: items.count, by: 3).map {
            Array(items[$0..<min($0 + 3, items.count)])
        }

        for (idx, chunk) in chunks.enumerated() {
            var enSentences: [String] = []
            var viSentences: [String] = []

            if idx == 0 {
                enSentences.append("In our recent study on \(deckName), several key ideas emerged.")
                viSentences.append("Trong quá trình nghiên cứu về chủ đề \(deckName), nhiều ý niệm quan trọng đã xuất hiện.")
            }

            for item in chunk {
                let word = item.word.trimmingCharacters(in: .whitespacesAndNewlines)
                if !item.example.isEmpty {
                    enSentences.append(item.example)
                    if !item.exampleTranslation.isEmpty {
                        viSentences.append(item.exampleTranslation)
                    } else {
                        viSentences.append("Từ \"\(word)\" thể hiện ý nghĩa: \(item.meaning).")
                    }
                } else {
                    enSentences.append("Understanding \(word) is essential for mastering this topic.")
                    viSentences.append("Việc hiểu rõ từ \"\(word)\" (\(item.meaning)) là điều thiết yếu để làm chủ chủ đề này.")
                }
            }

            enParagraphs.append(enSentences.joined(separator: " "))
            viParagraphs.append(viSentences.joined(separator: " "))
        }

        var paragraphs: [StoryParagraph] = []
        for i in 0..<enParagraphs.count {
            paragraphs.append(
                StoryParagraph(
                    en: enParagraphs[i],
                    vi: i < viParagraphs.count ? viParagraphs[i] : ""
                )
            )
        }

        let fullEn = enParagraphs.joined(separator: "\n\n")
        let fullVi = viParagraphs.joined(separator: "\n\n")

        var wordLevels: [String: String] = [:]
        for item in items {
            let clean = item.word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            wordLevels[clean] = WordInfoService.shared.resolveCEFRLevel(word: clean)
        }

        return GeneratedStory(
            deckId: deckId,
            deckName: deckName,
            titleEn: titleEn,
            titleVi: titleVi,
            fullStoryEn: fullEn,
            fullStoryVi: fullVi,
            paragraphs: paragraphs,
            targetWords: items.map { $0.word },
            wordLevels: wordLevels,
            createdAt: Date()
        )
    }
}
