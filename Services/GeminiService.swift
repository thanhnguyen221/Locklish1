import Foundation

// MARK: - GeminiService
/// Client service for Google Gemini API with JSON Mode enabled.
/// Extracts high-value English vocabulary from provided raw text/PDF excerpts,
/// generating standard IPA and natural Vietnamese syllable transliterations ("viPhonetic").
final class GeminiService {
    static let shared = GeminiService()

    private let userDefaultsKey = "locklish_gemini_api_key"
    private let candidateModels = [
        "gemini-2.5-flash",
        "gemini-flash-latest",
        "gemini-2.0-flash",
        "gemini-1.5-flash-latest",
        "gemini-1.5-flash"
    ]

    // MARK: - API Key Management
    var apiKey: String {
        get {
            UserDefaults.standard.string(forKey: userDefaultsKey) ?? ""
        }
        set {
            UserDefaults.standard.setValue(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: userDefaultsKey)
        }
    }

    var hasValidKey: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Extraction Errors
    enum GeminiError: LocalizedError {
        case missingAPIKey
        case invalidURL
        case networkError(String)
        case invalidHTTPResponse(Int, String)
        case emptyResponseBody
        case decodingFailed(String)

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                return "Vui lòng nhập Google Gemini API Key trong Cài đặt trước khi tiếp tục."
            case .invalidURL:
                return "URL yêu cầu API không hợp lệ."
            case .networkError(let message):
                return "Lỗi kết nối mạng: \(message)"
            case .invalidHTTPResponse(let code, let msg):
                return "Lỗi máy chủ Gemini (Mã \(code)): \(msg)"
            case .emptyResponseBody:
                return "Máy chủ trả về phản hồi rỗng."
            case .decodingFailed(let detail):
                return "Không thể phân tích dữ liệu từ AI: \(detail)"
            }
        }
    }

    // MARK: - Vocabulary Extraction Prompt
    /// Strict single-word extraction contract. Every rule is absolute: the model must
    /// return exactly one English word per entry, never phrases, never Vietnamese text,
    /// never names. Validated again by LocalVocabularyExtractorService.validateAndCleanItems.
    private var systemInstructionText: String {
        """
        You are a vocabulary extraction engine for an English-learning flashcard app used by Vietnamese learners.

        OUTPUT CONTRACT — ABSOLUTE, HIGHEST PRIORITY, EVERY ENTRY WITHOUT EXCEPTION:
        1. "word" MUST be EXACTLY ONE English word — a single token with NO spaces anywhere. A hyphenated compound word like "well-known" is the ONLY multi-part form allowed.
        2. FORBIDDEN in "word": phrases, phrasal verbs, idioms, collocations, multi-word expressions (e.g. "give up", "look forward to", "a lot of", "turn out to be"). Never output them. Never split them into separate words either.
        3. FORBIDDEN in "word": ANY Vietnamese text — with or without diacritics (e.g. "trai", "khong", "nguoi", "tình yêu", "để ý", "mỉm cười"). Vietnamese belongs ONLY in "meaning" and "exampleTranslation". NEVER turn a Vietnamese word into an entry, even if it looks like an English word when written without diacritics.
        4. FORBIDDEN in "word": proper names of people, pets, places, brands, organizations, countries, languages (e.g. "Anna", "Tom", "Hanoi", "Vietnam").
        5. FORBIDDEN in "word": single letters, numbers, symbols, URLs, e-mail addresses, sentence fragments, or truncated text ending with "...".
        6. "partOfSpeech" MUST be exactly one of: "noun", "verb", "adjective", "adverb", "preposition", "conjunction", "pronoun", "interjection". Never empty. Never "phrase", "idiom", or "collocation".
        7. NO duplicates: each word appears at most once in the whole array.
        8. If a candidate fails ANY rule above, SKIP it completely and move on. Skipping is always better than violating the contract.

        TASK MODES (detect automatically):
        A. PRE-COMPILED VOCABULARY LIST / PDF GLOSSARY (lines like "word - meaning", "word: meaning", numbered lists, tables):
           - Extract 100% of all ENGLISH headwords in the list, omitting none.
           - "word" = the English headword exactly as written (still one word, still English).
           - Preserve the user's Vietnamese definitions in "meaning" exactly as written.
        B. GENERAL READING PASSAGE / STORY / ARTICLE / BILINGUAL DOCUMENT:
           - Extract the highest-value SINGLE English words (A2/B1/B2/C1/C2) worth studying.
           - Skip trivial, purely grammatical, or overly common words.
           - The document may alternate English and Vietnamese paragraphs: ONLY English words may ever appear in "word".

        FIELD REQUIREMENTS:
        - "ipa": General American IPA wrapped in slashes, e.g. "/ˈtʃer.ɪʃ/".
        - "viPhonetic": intuitive hyphenated Vietnamese syllables with tone marks, e.g. "schedule" -> "sờ-ké-chồ", "comfortable" -> "cớm-phơ-tờ-bồ".
        - "meaning": natural Vietnamese definition of the word.
        - "example": ONE realistic, natural English sentence using the exact word (no placeholders like "I like this word").
        - "exampleTranslation": natural, idiomatic Vietnamese translation of that exact example sentence.
        - "note": short Vietnamese usage note, or "" if none.

        SELF-CHECK BEFORE RESPONDING (MANDATORY): for every item verify — (a) is "word" one single token with no spaces? (b) is it 100% English, with zero Vietnamese characters or Vietnamese words? (c) is it not a name? Delete every item that fails any check.

        Return ONLY the JSON array conforming to the provided response schema. No prose, no markdown.
        """
    }

    // MARK: - Batch Vietnamese Translation
    /// Translates a batch of paragraphs into natural Vietnamese in ONE request
    /// (context flows across paragraphs — far more accurate than per-sentence).
    /// Returns an array of the same length, or throws.
    func translateBatchToVietnamese(_ texts: [String]) async throws -> [String] {
        guard hasValidKey else { throw GeminiError.missingAPIKey }
        guard !texts.isEmpty else { return [] }

        let numbered = texts.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
        let prompt = """
        Translate each numbered English paragraph below into natural, idiomatic Vietnamese.
        Rules: keep the numbering "1." "2." … at the start of each translated paragraph; preserve meaning and tone; do not merge or drop paragraphs; do not add explanations.
        Return ONLY a JSON array of strings (no markdown) with exactly \(texts.count) items, in the same order.

        \(numbered.prefix(24000))
        """

        let requestBody: [String: Any] = [
            "contents": [["role": "user", "parts": [["text": prompt]]]],
            "generationConfig": [
                "temperature": 0.15,
                "responseMimeType": "application/json",
                "responseSchema": [
                    "type": "ARRAY",
                    "items": ["type": "STRING"]
                ],
                "maxOutputTokens": 8192
            ]
        ]

        let httpData = try JSONSerialization.data(withJSONObject: requestBody)

        for model in candidateModels {
            let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)"
            guard let url = URL(string: urlString) else { continue }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = httpData

            guard let (data, response) = try? await URLSession.shared.data(for: request),
                  (response as? HTTPURLResponse)?.statusCode == 200,
                  let decoded = try? parseStringArrayResponse(data: data),
                  decoded.count == texts.count else { continue }
            return decoded
        }
        throw GeminiError.decodingFailed("Dịch hàng loạt thất bại")
    }

    private func parseStringArrayResponse(data: Data) throws -> [String] {
        guard let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = jsonObject["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let textResponse = firstPart["text"] as? String else {
            throw GeminiError.decodingFailed("Cấu trúc phản hồi từ Gemini không đúng định dạng.")
        }

        var cleaned = textResponse.trimmingCharacters(in: .whitespacesAndNewlines)
        for marker in ["```json", "```"] { cleaned = cleaned.replacingOccurrences(of: marker, with: "") }
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let jsonData = cleaned.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: jsonData) as? [String] else {
            throw GeminiError.decodingFailed("Không parse được mảng dịch.")
        }
        // Strip the "1." prefixes we asked the model to keep
        return array.map { item in
            item.replacingOccurrences(of: #"^\s*\d+\.\s*"#, with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    // MARK: - Vocabulary Extraction API Call
    /// Extracts vocabulary list using the Ultimate Prompt. Automatically handles pre-compiled lists or reading passages.
    func extractVocabulary(from text: String, customInstruction: String? = nil, targetCount: Int? = nil) async throws -> [VocabularyItemDTO] {
        guard hasValidKey else {
            throw GeminiError.missingAPIKey
        }

        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return [] }

        var promptContent = """
        Analyze the following text using the vocabulary extraction contract above.
        Detect automatically whether it is a pre-compiled word list or a reading passage/story/bilingual document.
        Pre-compiled list: return 100% of the English headwords, keeping the user's Vietnamese meanings.
        Reading passage: return ONLY high-value SINGLE English words.
        Absolute rules: every "word" is one English token with no spaces; NO phrases, idioms, or collocations; NO Vietnamese text in "word" (with or without diacritics); NO names; no duplicates. Skip anything that violates the contract.

        Input content:
        \(trimmedText.prefix(30000))
        """

        // Structured output schema: forces the array shape and constrains partOfSpeech
        // to real word categories so phrases/idioms can never be labeled as such.
        let responseSchema: [String: Any] = [
            "type": "ARRAY",
            "items": [
                "type": "OBJECT",
                "properties": [
                    "word": ["type": "STRING"],
                    "ipa": ["type": "STRING"],
                    "viPhonetic": ["type": "STRING"],
                    "partOfSpeech": [
                        "type": "STRING",
                        "enum": ["noun", "verb", "adjective", "adverb", "preposition", "conjunction", "pronoun", "interjection"]
                    ],
                    "meaning": ["type": "STRING"],
                    "example": ["type": "STRING"],
                    "exampleTranslation": ["type": "STRING"],
                    "note": ["type": "STRING"]
                ],
                "required": ["word", "ipa", "viPhonetic", "partOfSpeech", "meaning", "example", "exampleTranslation", "note"]
            ]
        ]

        // Request Payload configured with JSON response MIME type, schema, and high token limit
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "role": "user",
                    "parts": [
                        [
                            "text": promptContent
                        ]
                    ]
                ]
            ],
            "systemInstruction": [
                "parts": [
                    ["text": systemInstructionText]
                ]
            ],
            "generationConfig": [
                "temperature": 0.15,
                "topP": 0.9,
                "responseMimeType": "application/json",
                "responseSchema": responseSchema,
                "maxOutputTokens": 8192
            ]
        ]

        let httpData = try JSONSerialization.data(withJSONObject: requestBody, options: [])

        var lastError: Error?

        // Try candidate models in order of modern availability
        for model in candidateModels {
            let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)"
            guard let url = URL(string: urlString) else { continue }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = httpData

            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw GeminiError.networkError("Phản hồi máy chủ không hợp lệ")
                }

                if httpResponse.statusCode == 200 {
                    return try parseGeminiResponse(data: data)
                }

                // If 404 (model not found / deprecated for this key), try next model
                let parsedMessage = parseErrorMessage(from: data, statusCode: httpResponse.statusCode)
                if httpResponse.statusCode == 404 {
                    lastError = GeminiError.invalidHTTPResponse(httpResponse.statusCode, parsedMessage)
                    continue
                }

                // If 400, 401, 403, fail immediately with user-friendly message
                throw GeminiError.invalidHTTPResponse(httpResponse.statusCode, parsedMessage)
            } catch let error as GeminiError {
                throw error
            } catch {
                lastError = error
            }
        }

        if let lastError = lastError {
            throw lastError
        }
        throw GeminiError.networkError("Không thể kết nối tới máy chủ Gemini")
    }

    private func parseErrorMessage(from data: Data, statusCode: Int) -> String {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let errorObj = json["error"] as? [String: Any],
           let message = errorObj["message"] as? String {
            if message.contains("denied access") {
                return "Dự án Google của API Key này bị từ chối truy cập (Denied Access). Vui lòng tạo API Key mới tại https://aistudio.google.com (key hợp lệ thường bắt đầu bằng 'AIzaSy...')."
            }
            if message.contains("API key not valid") {
                return "API Key không hợp lệ. Vui lòng kiểm tra lại tại Cài đặt."
            }
            return message
        }
        return "Mã lỗi \(statusCode)"
    }

    // MARK: - Response Parsing
    private func parseGeminiResponse(data: Data) throws -> [VocabularyItemDTO] {
        guard let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = jsonObject["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let textResponse = firstPart["text"] as? String else {
            throw GeminiError.decodingFailed("Cấu trúc phản hồi từ Gemini không đúng định dạng.")
        }

        // Clean potential markdown wrap if any remains
        var cleanedText = textResponse.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanedText.hasPrefix("```json") {
            cleanedText = cleanedText.replacingOccurrences(of: "```json", with: "")
        }
        if cleanedText.hasPrefix("```") {
            cleanedText = cleanedText.replacingOccurrences(of: "```", with: "")
        }
        if cleanedText.hasSuffix("```") {
            cleanedText = String(cleanedText.dropLast(3))
        }
        cleanedText = cleanedText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let jsonData = cleanedText.data(using: .utf8) else {
            throw GeminiError.decodingFailed("Không thể chuyển đổi văn bản sang dữ liệu nhị phân.")
        }

        do {
            let items = try JSONDecoder().decode([VocabularyItemDTO].self, from: jsonData)
            return items
        } catch {
            // Attempt decoding single item wrapper or report exact error
            throw GeminiError.decodingFailed(error.localizedDescription)
        }
    }

    // MARK: - Translation Method
    /// Translates a single English sentence to Vietnamese using Gemini API.
    /// - Parameter text: The English text to translate.
    /// - Returns: Vietnamese translation string.
    func translateText(_ text: String) async throws -> String {
        guard hasValidKey else {
            throw GeminiError.missingAPIKey
        }

        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return "" }

        let promptContent = """
        Translate the following English sentence to natural, fluent Vietnamese.
        Keep the meaning accurate and use appropriate Vietnamese grammar and vocabulary.

        English sentence:
        \(trimmedText)

        Provide ONLY the Vietnamese translation, no explanations or extra text.
        """

        let requestBody: [String: Any] = [
            "contents": [
                [
                    "role": "user",
                    "parts": [
                        [
                            "text": promptContent
                        ]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.3,
                "topP": 0.8
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
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw GeminiError.networkError("Phản hồi máy chủ không hợp lệ")
                }

                if httpResponse.statusCode == 200 {
                    return try parseTranslationResponse(data: data)
                }

                let parsedMessage = parseErrorMessage(from: data, statusCode: httpResponse.statusCode)
                if httpResponse.statusCode == 404 {
                    lastError = GeminiError.invalidHTTPResponse(httpResponse.statusCode, parsedMessage)
                    continue
                }

                throw GeminiError.invalidHTTPResponse(httpResponse.statusCode, parsedMessage)
            } catch let error as GeminiError {
                throw error
            } catch {
                lastError = error
            }
        }

        if let lastError = lastError {
            throw lastError
        }
        throw GeminiError.networkError("Không thể kết nối tới máy chủ Gemini")
    }

    private func parseTranslationResponse(data: Data) throws -> String {
        guard let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = jsonObject["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let textResponse = firstPart["text"] as? String else {
            throw GeminiError.decodingFailed("Cấu trúc phản hồi từ Gemini không đúng định dạng.")
        }

        let cleanedText = textResponse.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleanedText
    }
}
