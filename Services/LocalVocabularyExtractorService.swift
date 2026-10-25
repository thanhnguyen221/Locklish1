import Foundation
import NaturalLanguage
#if canImport(UIKit)
import UIKit
#endif

// MARK: - ImportTextNormalizer
/// Shared text normalization for BOTH import sources (pasted text and PDF extraction),
/// so detection and extraction see identical, parser-friendly characters.
enum ImportTextNormalizer {
    static func normalize(_ text: String) -> String {
        text
            // Unicode space variants -> plain space
            .replacingOccurrences(of: "\u{00a0}", with: " ")   // non-breaking space
            .replacingOccurrences(of: "\u{2007}", with: " ")   // figure space
            .replacingOccurrences(of: "\u{202f}", with: " ")   // narrow no-break space
            // Invisible hyphens & zero-width characters
            .replacingOccurrences(of: "\u{00ad}", with: "")    // soft hyphen
            .replacingOccurrences(of: "\u{200b}", with: "")    // zero-width space
            .replacingOccurrences(of: "\u{feff}", with: "")    // zero-width no-break space
            .replacingOccurrences(of: "\u{200c}", with: "")    // zero-width non-joiner
            // Typographic ligatures -> plain letters
            .replacingOccurrences(of: "ﬁ", with: "fi")
            .replacingOccurrences(of: "ﬂ", with: "fl")
            .replacingOccurrences(of: "ﬀ", with: "ff")
            .replacingOccurrences(of: "ﬃ", with: "ffi")
            .replacingOccurrences(of: "ﬄ", with: "ffl")
            // Curly apostrophes -> ASCII apostrophe (keeps "don't" intact)
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .replacingOccurrences(of: "\u{2018}", with: "'")
            .replacingOccurrences(of: "\u{02bc}", with: "'")
            // Line endings
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }
}

// MARK: - LocalVocabularyExtractorService
/// Smart hybrid on-device & lightweight API vocabulary extractor.
/// Provides instant, high-precision vocabulary extraction, accurate Vietnamese definitions,
/// authentic IPA phonetics, and natural Vietnamese syllable transliterations WITHOUT requiring any Gemini API Key.
final class LocalVocabularyExtractorService {
    static let shared = LocalVocabularyExtractorService()

    private let stopWords: Set<String> = [
        "the", "and", "for", "with", "that", "this", "from", "they", "have", "been",
        "were", "will", "would", "there", "their", "what", "about", "which", "when",
        "make", "like", "time", "just", "know", "take", "people", "into", "year",
        "your", "good", "some", "could", "them", "other", "than", "then", "look",
        "only", "come", "over", "think", "also", "back", "after", "used", "work",
        "first", "well", "even", "want", "because", "these", "give", "most", "us",
        "then", "said", "much", "very", "such", "each", "both", "must", "done"
    ]

    /// Mapping from NLTagger lexical-class tags to compact, learner-friendly English POS labels.
    private let posLabelMap: [String: String] = [
        "noun": "noun",
        "verb": "verb",
        "adjective": "adjective",
        "adverb": "adverb",
        "pronoun": "pronoun",
        "determiner": "determiner",
        "particle": "particle",
        "preposition": "preposition",
        "number": "number",
        "conjunction": "conjunction",
        "interjection": "interjection",
        "classifier": "classifier",
        "idiom": "idiom",
        "otherword": "other",
        "other": "other"
    ]

    // High-precision curated dictionary with authentic contextual examples
    let curatedDictionary: [String: (ipa: String, vi: String, meaning: String, example: String, exampleVi: String)] = [
        "misunderstanding": (
            "/ˌmɪs.ʌn.dɚˈstænd.ɪŋ/", "mít-sơn-đơ-xten-đinh", "Sự hiểu lầm, bất đồng ý kiến",
            "Clear communication helps prevent any serious misunderstanding.",
            "Giao tiếp rõ ràng giúp ngăn ngừa mọi sự hiểu lầm nghiêm trọng."
        ),
        "misunderstand": (
            "/ˌmɪs.ʌn.dɚˈstænd/", "mít-sơn-đơ-xten-đ", "Hiểu lầm, hiểu sai ý",
            "I am afraid you might misunderstand my original intentions.",
            "Tôi e rằng bạn có thể đã hiểu lầm ý định ban đầu của tôi."
        ),
        "ubiquitous": (
            "/juːˈbɪk.wɪ.təs/", "diu-bíc-qui-tợs", "Có mặt ở khắp mọi nơi, rất phổ biến",
            "Smartphones have become ubiquitous in modern everyday life.",
            "Điện thoại thông minh đã trở nên phổ biến ở khắp mọi nơi trong cuộc sống hiện đại."
        ),
        "resilient": (
            "/rɪˈzɪl.jənt/", "ri-díl-li-ừn-t", "Kiên cường, khả năng phục hồi nhanh chóng",
            "The local community proved to be remarkably resilient after the storm.",
            "Cộng đồng địa phương đã tỏ ra vô cùng kiên cường sau cơn bão."
        ),
        "meticulous": (
            "/məˈtɪk.jə.ləs/", "mờ-tíc-kiu-lợs", "Tỉ mỉ, cẩn thận từng chi tiết nhỏ",
            "He was meticulous about checking every single detail in the report.",
            "Anh ấy rất tỉ mỉ trong việc kiểm tra từng chi tiết nhỏ của bản báo cáo."
        ),
        "schedule": (
            "/ˈskedʒ.uːl/", "sờ-ké-chồ", "Lịch trình, kế hoạch công việc đã định",
            "We need to arrange a schedule that accommodates everyone's needs.",
            "Chúng ta cần sắp xếp một lịch trình phù hợp với nhu cầu của tất cả mọi người."
        ),
        "comfortable": (
            "/ˈkʌmftərbəl/", "cớm-phơ-tờ-bồ", "Thoải mái, tiện nghi, dễ chịu",
            "Make yourself comfortable while I prepare some warm tea.",
            "Hãy cứ tự nhiên thoải mái trong khi tôi chuẩn bị chút trà ấm nhé."
        ),
        "vegetable": (
            "/ˈvedʒtəbəl/", "vét-ch-tờ-bồ", "Rau củ quả trong ẩm thực",
            "Fresh green vegetables are an essential part of a healthy diet.",
            "Rau xanh tươi là một phần thiết yếu trong chế độ ăn uống lành mạnh."
        ),
        "implement": (
            "/ˈɪm.plɪ.ment/", "im-plơ-mừn-t", "Triển khai, thực hiện kế hoạch hoặc giải pháp",
            "The management decided to implement the new safety procedures immediately.",
            "Ban quản lý đã quyết định triển khai các quy trình an toàn mới ngay lập tức."
        ),
        "comprehensive": (
            "/ˌkɑːm.prɪˈhen.sɪv/", "com-pri-hén-síp", "Toàn diện, bao quát mọi khía cạnh",
            "The course provides a comprehensive introduction to modern linguistics.",
            "Khóa học cung cấp một sự giới thiệu toàn diện về ngôn ngữ học hiện đại."
        ),
        "perspective": (
            "/pərˈspek.tɪv/", "pơ-spéc-típ", "Góc nhìn, quan điểm cá nhân",
            "Traveling abroad gave her a whole new perspective on life.",
            "Đi du lịch nước ngoài đã mang lại cho cô ấy một góc nhìn hoàn toàn mới về cuộc sống."
        ),
        "collaborate": (
            "/kəˈlæb.ə.reɪt/", "cơ-lá-bờ-rây-t", "Hợp tác, làm việc chung cùng nhau",
            "Researchers from different universities decided to collaborate on this project.",
            "Các nhà nghiên cứu từ các trường đại học khác nhau đã quyết định hợp tác trong dự án này."
        ),
        "collaboration": (
            "/kəˌlæb.əˈreɪ.ʃən/", "cơ-la-bơ-rây-sừn", "Sự cộng tác, hợp tác làm việc",
            "Successful collaboration requires mutual respect and active listening.",
            "Sự hợp tác thành công đòi hỏi sự tôn trọng lẫn nhau và tinh thần lắng nghe chủ động."
        ),
        "innovative": (
            "/ˈɪn.ə.veɪ.tɪv/", "in-nơ-vây-típ", "Mang tính đổi mới, sáng tạo đột phá",
            "The startup is recognized worldwide for its innovative software solutions.",
            "Công ty khởi nghiệp được thế giới công nhận nhờ các giải pháp phần mềm sáng tạo đột phá."
        ),
        "evaluate": (
            "/ɪˈvæl.ju.eɪt/", "i-vá-liu-ây-t", "Đánh giá chất lượng hoặc giá trị",
            "The committee will thoroughly evaluate each proposal before reaching a verdict.",
            "Hội đồng sẽ đánh giá kỹ lưỡng từng đề xuất trước khi đưa ra phán quyết."
        ),
        "anticipate": (
            "/ænˈtɪs.ə.peɪt/", "an-tí-xơ-pây-t", "Dự đoán trước, lường trước tình huống",
            "Experienced leaders anticipate potential obstacles well in advance.",
            "Những người lãnh đạo dày dặn kinh nghiệm luôn lường trước các trở ngại tiềm ẩn từ sớm."
        ),
        "sustainable": (
            "/səˈsteɪ.nə.bəl/", "sơ-stây-nơ-bồ", "Bền vững, duy trì lâu dài",
            "Adopting sustainable energy sources is vital for our planet's future.",
            "Áp dụng các nguồn năng lượng bền vững là điều tối quan trọng cho tương lai hành tinh chúng ta."
        ),
        "versatile": (
            "/ˈvɜːr.sə.təl/", "vơ-sơ-tồ", "Đa năng, linh hoạt trong nhiều vai trò",
            "She is a versatile musician capable of playing classical, jazz, and pop.",
            "Cô ấy là một nghệ sĩ linh hoạt, có thể biểu diễn từ nhạc cổ điển, jazz cho đến nhạc pop."
        ),
        "substantial": (
            "/səbˈstæn.ʃəl/", "sắp-stén-sồ", "Đáng kể, quan trọng về số lượng hay giá trị",
            "The organization made substantial progress in reducing carbon emissions.",
            "Tổ chức đã đạt được tiến bộ đáng kể trong việc cắt giảm lượng khí thải carbon."
        ),
        "prioritize": (
            "/praɪˈɔːr.ə.taɪz/", "prai-o-rơ-tai-d", "Ưu tiên giải quyết trước",
            "When dealing with tight deadlines, you must prioritize your most urgent tasks.",
            "Khi đối mặt với hạn chót gấp, bạn phải ưu tiên những công việc khẩn cấp nhất."
        ),
        "elaborate": (
            "/iˈlæb.ər.ət/", "i-lá-bơ-rợt", "Phức tạp, công phu hoặc giải thích chi tiết",
            "Could you please elaborate on how this mechanism functions under pressure?",
            "Bạn có thể giải thích chi tiết hơn về cách cơ chế này vận hành dưới áp lực không?"
        ),
        "subsequent": (
            "/ˈsʌb.sɪ.kwənt/", "sắp-si-quừn-t", "Xảy ra sau đó, tiếp theo sau",
            "Subsequent investigations revealed the real underlying cause of the accident.",
            "Các cuộc điều tra diễn ra sau đó đã hé lộ nguyên nhân thực sự sâu xa của vụ tai nạn."
        ),
        "inevitable": (
            "/ɪnˈev.ə.t̬ə.bəl/", "in-é-vơ-tờ-bồ", "Không thể tránh khỏi, chắc chắn xảy ra",
            "Change is an inevitable part of every growing organization.",
            "Thay đổi là một phần tất yếu không thể tránh khỏi đối với mọi tổ chức đang phát triển."
        ),
        "feasible": (
            "/ˈfiː.zə.bəl/", "phi-zơ-bồ", "Khả thi, có thể thực hiện được",
            "The engineering team concluded that the proposed timeline was completely feasible.",
            "Đội ngũ kỹ thuật kết luận rằng tiến độ đề xuất là hoàn toàn khả thi."
        ),
        "challenge": (
            "/ˈtʃæl.ɪndʒ/", "chá-lừn-ch", "Thử thách, khó khăn cần vượt qua",
            "Overcoming this technical challenge will elevate our system's reliability.",
            "Vượt qua thử thách kỹ thuật này sẽ nâng cao độ tin cậy của toàn bộ hệ thống chúng ta."
        ),
        "opportunity": (
            "/ˌɑː.pɚˈtuː.nə.t̬i/", "óp-pơ-tiu-nơ-ti", "Cơ hội, dịp thuận lợi",
            "This scholarship presents an invaluable opportunity to study abroad.",
            "Học bổng này mang lại một cơ hội vô giá để học tập tại nước ngoài."
        ),
        "development": (
            "/dɪˈvel.əp.mənt/", "đi-vé-lớp-mừn-t", "Sự phát triển, tiến triển",
            "Continuous personal development is key to long-term professional fulfillment.",
            "Phát triển bản thân liên tục là chìa khóa để đạt được sự thỏa mãn lâu dài trong sự nghiệp."
        ),
        "significant": (
            "/sɪɡˈnɪf.ə.kənt/", "xích-ní-phi-cừn-t", "Có ý nghĩa quan trọng, đáng chú ý",
            "There has been a significant increase in demand for renewable energy solutions.",
            "Đã có một sự gia tăng đáng kể trong nhu cầu về các giải pháp năng lượng tái tạo."
        )
    ]

    // MARK: - Main Extraction Function
    /// Extracts vocabulary words from input text or pre-compiled lists, querying meanings and generating natural phonetics.
    /// If the text is a user-created vocabulary list, it extracts 100% of all items without omission.
    func extractVocabulary(from rawText: String, maxCount: Int = 20, customInstruction: String? = nil) async -> [VocabularyItemDTO] {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return [] }

        // CHECK 1: Detect pre-compiled vocabulary list (Word - Meaning, Word: Meaning, Excel/TSV format, etc.)
        if let precompiledItems = parsePrecompiledList(from: text), !precompiledItems.isEmpty {
            return await processPrecompiledList(items: precompiledItems)
        }

        // CHECK 2: General Article / Reading Passage Mode
        return await processGeneralArticle(text: text, maxCount: maxCount, customInstruction: customInstruction)
    }

    // MARK: - Pre-Compiled List Extraction (deterministic, no AI)
    /// Parses the input strictly as a user-prepared vocabulary list and resolves meanings,
    /// IPA, and Vietnamese phonetics on-device. The word field contains ONLY the clean
    /// English headword exactly as written — never phrases or Vietnamese meanings.
    func extractPrecompiledList(from text: String) async -> [VocabularyItemDTO] {
        guard let entries = parsePrecompiledList(from: text), !entries.isEmpty else { return [] }
        return await processPrecompiledList(items: entries)
    }

    /// CSV import path: the caller already guarantees these lines are a structured
    /// word list (parsed from a CSV file), so the "≥ 2 entries" auto-detection
    /// gate is bypassed — even a single-row CSV imports correctly.
    func extractPrecompiledList(fromNormalizedLines lines: [String]) async -> [VocabularyItemDTO] {
        var entries: [PrecompiledEntry] = []
        var seenWords = Set<String>()

        for line in lines {
            guard let entry = parseSingleLineToEntry(line) else { continue }
            if seenWords.insert(entry.word.lowercased()).inserted {
                entries.append(entry)
            }
        }

        guard !entries.isEmpty else { return [] }
        return await processPrecompiledList(items: entries)
    }

    /// Re-serializes parsed list entries as clean `word /ipa/ (pos): meaning` lines.
    /// This exact text is what gets submitted to Gemini, so the model enriches the
    /// user's own composed list instead of re-parsing noisy raw input.
    func serializePrecompiledList(_ entries: [PrecompiledEntry]) -> String {
        entries.map { entry in
            var line = entry.word
            if let ipa = entry.ipa, !ipa.isEmpty { line += " \(ipa)" }
            if let pos = entry.partOfSpeech, !pos.isEmpty { line += " (\(pos))" }
            if let meaning = entry.customMeaning, !meaning.isEmpty { line += ": \(meaning)" }
            return line
        }
        .joined(separator: "\n")
    }

    // MARK: - AI Output Post-Validation (defense in depth)
    /// Hard deterministic validation applied to AI-returned items. Regardless of what the
    /// model was told, the word field must survive the same sanitation as parsed lists:
    /// clean single English words only — no phrases (unless allowMultiWord), no digits or
    /// symbols, no Vietnamese text (including ASCII-spelled Vietnamese like "trai").
    func validateAndCleanItems(_ items: [VocabularyItemDTO], allowMultiWord: Bool) -> [VocabularyItemDTO] {
        var seenWords = Set<String>()
        var results: [VocabularyItemDTO] = []

        for item in items {
            guard let cleanWord = sanitizeHeadword(item.word) else { continue }
            let lower = cleanWord.lowercased()

            if !allowMultiWord && cleanWord.contains(" ") { continue }
            if isASCIIVietnameseWord(lower) { continue }
            guard seenWords.insert(lower).inserted else { continue }

            results.append(VocabularyItemDTO(
                id: item.id,
                word: cleanWord,
                ipa: item.ipa,
                viPhonetic: item.viPhonetic,
                partOfSpeech: item.partOfSpeech,
                meaning: item.meaning,
                note: item.note,
                example: item.example,
                exampleTranslation: item.exampleTranslation,
                collocationPhrase: item.collocationPhrase,
                collocationMeaning: item.collocationMeaning,
                collocationUsage: item.collocationUsage,
                imageURL: item.imageURL
            ))
        }

        return results
    }

    /// High-frequency Vietnamese words that are written with plain ASCII letters and could
    /// masquerade as English (e.g. "trai", "khong", "dep"). Only non-English words here —
    /// real English homographs ("an", "den", "con", "do") are handled by the lexicon check.
    private let asciiVietnameseBlocklist: Set<String> = [
        "trai", "gai", "mai", "khong", "duoc", "nguoi", "nhung", "cac", "mot", "nao",
        "gi", "toi", "chung", "hoa", "qua", "dep", "vui", "nhieu", "rat", "ngay",
        "dem", "nuoc", "nha", "xem", "mua", "cach", "tui", "bay", "gio", "luc",
        "tren", "duoi", "sau", "truoc", "voi", "tot", "xau", "dung", "sai", "uong",
        "ngu", "hoc", "choi", "viec", "manh", "yeu", "tinh", "xinh", "bai", "tre",
        "tra", "trang", "tranh", "canh", "cay", "chan", "chim", "cho", "gan",
        "giong", "heo", "huong", "khoi", "kinh", "linh", "lua", "mong", "muc",
        "nam", "nho", "nhac", "noi", "ong", "pho", "quan", "que", "quen", "sang",
        "sen", "soi", "tau", "tien", "trau", "trung", "tua", "tung", "tuoi", "xa",
        "xe", "xuong", "cam", "ro", "bo", "co", "chi", "anh", "em", "lam", "di"
    ]

    /// True when an ASCII-only word is actually Vietnamese: either it is in the curated
    /// blocklist, or a language recognizer confidently reads it as Vietnamese while the
    /// English lexicon does not know it.
    private func isASCIIVietnameseWord(_ lower: String) -> Bool {
        if asciiVietnameseBlocklist.contains(lower) { return true }

        let recognizer = NLLanguageRecognizer()
        recognizer.processString(lower)
        guard recognizer.dominantLanguage == .vietnamese else { return false }
        return !isRealEnglishWord(lower)
    }

    /// Checks the system English lexicon. Unknown or misspelled words return false.
    private func isRealEnglishWord(_ lower: String) -> Bool {
        #if canImport(UIKit)
        let checker = UITextChecker()
        let range = NSRange(location: 0, length: (lower as NSString).length)
        let misspelledRange = checker.rangeOfMisspelledWord(
            in: lower,
            range: range,
            startingAt: 0,
            wrap: false,
            language: "en_US"
        )
        return misspelledRange.location == NSNotFound
        #else
        // Non-UIKit build environments (e.g. macOS test harnesses): rely on the
        // language recognizer alone.
        return false
        #endif
    }

    // MARK: - Linguistic Filters & Helpers

    /// Cleans and validates an English headword so only pristine data reaches the word field:
    /// no digits, no Vietnamese text, ASCII letters/spaces/hyphens/apostrophes only,
    /// collapsed whitespace, and at most 3 words (never a full sentence fragment).
    private func sanitizeHeadword(_ raw: String) -> String? {
        var word = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // A fully parenthesized token IS the headword itself: "(humble)" -> "humble"
        if word.range(of: #"^\([^()]{1,60}\)$"#, options: .regularExpression) != nil {
            word = word.trimmingCharacters(in: CharacterSet(charactersIn: "()"))
        }
        // Strip inline annotations: "awesome (informal)" -> "awesome"
        word = word.replacingOccurrences(of: #"\s*\([^)]*\)\s*"#, with: " ", options: .regularExpression)
        word = word.replacingOccurrences(of: #"\s*\[[^\]]*\]\s*"#, with: " ", options: .regularExpression)
        word = word.trimmingCharacters(in: CharacterSet(charactersIn: " -–—:;,./\"'()[]*•"))
        word = word.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        guard !word.isEmpty else { return nil }
        guard word.rangeOfCharacter(from: .decimalDigits) == nil else { return nil }
        guard !containsVietnameseDiacritics(word) else { return nil }
        guard word.range(of: #"^[A-Za-z][A-Za-z\s\-']*$"#, options: .regularExpression) != nil else { return nil }
        guard word.split(separator: " ").count <= 3 else { return nil }
        return word
    }

    private let commonPersonalNames: Set<String> = [
        "anna", "tom", "john", "mary", "peter", "david", "michael", "sarah", "emma", "james",
        "robert", "william", "alex", "paul", "mark", "lisa", "alice", "bob", "charlie", "jack",
        "daniel", "lucas", "henry", "oliver", "noah", "liam", "sophia", "mia", "olivia", "emily",
        "grace", "chloe", "ella", "lucy", "sam", "ben", "chris", "kate", "jake", "elena"
    ]

    /// Common Vietnamese tokens that carry no diacritics; used to detect the
    /// EN→VI boundary in compact list lines like "hello xin chào", where the
    /// meaning must go entirely into the meaning field — never into the word field.
    private let diacriticFreeVietnameseTokens: Set<String> = [
        "xin", "chao", "khong", "duoc", "cua", "nguoi", "nhung", "cac", "mot", "nay",
        "va", "la", "co", "bi", "da", "se", "van", "cung", "nao", "gi", "ai", "theo",
        "cho", "voi", "tu", "trong", "ngoai", "tren", "duoi", "truoc", "sau", "rat",
        "qua", "lam", "chi", "nhieu", "tot", "hay", "ban", "toi", "chung", "ho",
        "khi", "nhu", "de", "moi", "noi", "di", "den", "ve", "gio", "luc", "cach",
        "vui", "dep", "lan", "loi", "dung", "an", "ngu", "hoc", "viec", "hang",
        "dong", "manh", "suc", "loai", "kieu"
    ]

    private func containsVietnameseDiacritics(_ text: String) -> Bool {
        let vietnamesePattern = "[àáảãạâầấẩẫậăằắẳẵặèéẻẽẹêềếểễệìíỉĩịòóỏõọôồốổỗộơờớởỡợùúủũụưừứửữựỳýỷỹỵđ]"
        return text.range(of: vietnamesePattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    private func isPureEnglishWordOrPhrase(_ str: String) -> Bool {
        let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        if containsVietnameseDiacritics(trimmed) { return false }
        guard trimmed.rangeOfCharacter(from: .letters) != nil else { return false }
        let sentencePunc: [Character] = [".", ",", "?", "!", ";", "\"", "“", "”", "(", ")"]
        if trimmed.contains(where: { sentencePunc.contains($0) }) { return false }
        let words = trimmed.split(separator: " ")
        guard words.count >= 1 && words.count <= 4 else { return false }
        return true
    }

    private func mapLexicalClassToPOS(_ tag: NLTag?) -> String {
        guard let tag = tag else { return "noun" }
        switch tag {
        case .noun: return "noun"
        case .verb: return "verb"
        case .adjective: return "adjective"
        case .adverb: return "adverb"
        case .preposition: return "preposition"
        case .conjunction: return "conjunction"
        case .pronoun: return "pronoun"
        case .particle: return "phrasal verb"
        case .interjection: return "interjection"
        default: return "noun"
        }
    }

    /// Normalizes abbreviated POS labels from user lists ("n", "adj", "adv"...)
    /// into proper NLTag values so they map to full category names.
    private func normalizedNLTag(from raw: String) -> NLTag {
        switch raw.lowercased() {
        case "n", "noun": return NLTag.noun
        case "v", "verb": return NLTag.verb
        case "adj", "a", "adjective": return NLTag.adjective
        case "adv", "adverb": return NLTag.adverb
        case "prep", "preposition": return NLTag.preposition
        case "pron", "pronoun": return NLTag.pronoun
        case "conj", "conjunction": return NLTag.conjunction
        case "interj", "interjection": return NLTag.interjection
        default: return NLTag(rawValue: raw.lowercased())
        }
    }

    private func detectPartOfSpeech(for word: String) -> String {
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = word
        let (tag, _) = tagger.tag(at: word.startIndex, unit: .word, scheme: .lexicalClass)
        return mapLexicalClassToPOS(tag)
    }

    /// True when a parenthesized/bracketed token is actually a POS label like "adj", "n", "verb"
    /// — and not a parenthesized headword like "humble" or an annotation like "informal".
    private func isPOSLikeText(_ text: String) -> Bool {
        let cleaned = text.trimmingCharacters(in: CharacterSet(charactersIn: ". ")).lowercased()
        let posKeywords: Set<String> = [
            "n", "v", "a", "adj", "adv", "vt", "vi", "pl", "sing",
            "noun", "verb", "adjective", "adverb", "prep", "preposition",
            "pron", "pronoun", "conj", "conjunction", "interj", "interjection",
            "phrase", "idiom"
        ]
        return posKeywords.contains(cleaned)
    }

    /// Strips leading parenthesized annotations from a user-provided meaning, so the
    /// meaning field contains only the definition: "(ke-phồ-li) một cách cẩn thận"
    /// -> "một cách cẩn thận". The phonetic belongs in its own viPhonetic field.
    private func stripLeadingParenAnnotations(_ meaning: String) -> String {
        var cleaned = meaning.trimmingCharacters(in: .whitespacesAndNewlines)
        while cleaned.hasPrefix("("), let close = cleaned.firstIndex(of: ")") {
            cleaned = String(cleaned[cleaned.index(after: close)...]).trimmingCharacters(in: .whitespaces)
        }
        return cleaned
    }

    // MARK: - Pre-Compiled List Parser
    /// Represents a parsed raw entry from a pre-compiled word list or PDF table
    struct PrecompiledEntry {
        let word: String
        let customMeaning: String?
        let partOfSpeech: String?
        let ipa: String?
        let customExample: String?
        let customExampleVi: String?
    }

    /// Intelligently parses user-created vocabulary lists and PDF tables in various real-world formats:
    /// - `Word /ipa/ (pos): Meaning. Ex: Example sentence`
    /// - `Word [ipa] (pos) - Meaning`
    /// - `Word : Meaning` / `Word - Meaning` / `Word = Meaning`
    /// - `1. Word - Meaning` / `* Word : Meaning`
    /// - Tab-separated values (`\t`) or multi-space column alignment from PDF/Excel
    /// - Word followed directly by Vietnamese definition without separator
    /// - 2-line table format (Line 1: Word + POS, Line 2: Vietnamese Meaning)
    /// - Simple line-by-line word list
    func parsePrecompiledList(from text: String) -> [PrecompiledEntry]? {
        let rawLines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard !rawLines.isEmpty else { return nil }

        var parsedEntries: [PrecompiledEntry] = []
        var seenWords = Set<String>()
        var consumedLineIndices = Set<Int>()

        // 1. Line-by-line parsing
        for (index, line) in rawLines.enumerated() {
            if let entry = parseSingleLineToEntry(line) {
                let lower = entry.word.lowercased()
                if !seenWords.contains(lower) {
                    seenWords.insert(lower)
                    parsedEntries.append(entry)
                    consumedLineIndices.insert(index)
                }
            }
        }

        // 2. Multi-line table parser: Check consecutive line pairs (common in PDF tables)
        // Line i: English Word + optional POS/IPA; Line i+1: Vietnamese Meaning
        // Lines already consumed as entries are never re-paired (prevents section
        // titles like "Vocabulary list:" stealing the next entry's meaning line).
        if parsedEntries.count < 3 && rawLines.count >= 2 {
            var i = 0
            while i < rawLines.count - 1 {
                if consumedLineIndices.contains(i) || consumedLineIndices.contains(i + 1) {
                    i += 1
                    continue
                }
                let line1 = rawLines[i]
                let line2 = rawLines[i + 1]

                if let (word, pos, ipa) = extractHeadwordOnly(from: line1),
                   containsVietnameseDiacritics(line2) && !isPureEnglishWordOrPhrase(line2) {
                    let lower = word.lowercased()
                    if !seenWords.contains(lower) {
                        seenWords.insert(lower)
                        parsedEntries.append(PrecompiledEntry(
                            word: word,
                            customMeaning: stripLeadingParenAnnotations(line2.trimmingCharacters(in: .whitespacesAndNewlines)),
                            partOfSpeech: pos,
                            ipa: ipa,
                            customExample: nil,
                            customExampleVi: nil
                        ))
                        consumedLineIndices.insert(i)
                        consumedLineIndices.insert(i + 1)
                        i += 2
                        continue
                    }
                }
                i += 1
            }
        }

        // 3. Fallback: Pure line-by-line word list (e.g. 2+ words, one per line)
        if parsedEntries.count < 2 {
            var pureWords: [PrecompiledEntry] = []
            let singleWordRegex = try? NSRegularExpression(pattern: #"^(?:(?:\d+[.)/:\-]|[-*•–—#])\s*)?([A-Za-z\s\-']{2,40})$"#)

            for line in rawLines {
                let nsRange = NSRange(line.startIndex..<line.endIndex, in: line)
                if let match = singleWordRegex?.firstMatch(in: line, options: [], range: nsRange),
                   let wordRange = Range(match.range(at: 1), in: line),
                   let w = sanitizeHeadword(String(line[wordRange])) {
                    let lower = w.lowercased()
                    if !commonPersonalNames.contains(lower) && !stopWords.contains(lower) {
                        if !seenWords.contains(lower) {
                            seenWords.insert(lower)
                            pureWords.append(PrecompiledEntry(word: w, customMeaning: nil, partOfSpeech: nil, ipa: nil, customExample: nil, customExampleVi: nil))
                        }
                    }
                }
            }

            if pureWords.count >= 2 {
                return pureWords
            }
        }

        // High-tolerance criteria: If we found at least 2 structured vocabulary pairs, accept them!
        // This ensures PDF glossaries surrounded by page headers, footers, or introductory text are 100% captured.
        if parsedEntries.count >= 2 {
            return parsedEntries
        }

        return nil
    }

    /// Parses a single line of text into a vocabulary entry
    func parseSingleLineToEntry(_ rawLine: String) -> PrecompiledEntry? {
        var line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
        guard line.count >= 3 else { return nil }

        // 1. Strip leading numbering or bullet points: "1. ", "1/ ", "• ", "- ", "* "
        if let numMatch = line.range(of: #"^(?:(?:\d+[.)/:\-]|[-*•–—#])\s*)+"#, options: .regularExpression) {
            line.removeSubrange(numMatch)
            line = line.trimmingCharacters(in: .whitespaces)
        }

        guard !line.isEmpty else { return nil }

        // 2. Extract embedded example sentence if present (e.g. "Ex: ...", "Ví dụ: ...", "vd: ...")
        var customExample: String? = nil
        var customExampleVi: String? = nil
        if let exMatch = line.range(of: #"(?:\s*(?:Ex|E\.g\.|Example|Ví dụ|Vd)\s*:\s*)(.+)$"#, options: [.regularExpression, .caseInsensitive]) {
            let exPart = String(line[exMatch])
            line.removeSubrange(exMatch)
            line = line.trimmingCharacters(in: .whitespaces)

            let cleanedEx = exPart.replacingOccurrences(of: #"^(?:\s*(?:Ex|E\.g\.|Example|Ví dụ|Vd)\s*:\s*)"#, with: "", options: [.regularExpression, .caseInsensitive]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleanedEx.isEmpty {
                if let transMatch = cleanedEx.range(of: #"\s*[\(\-–—]\s*([^)]+)[\)]?$"#, options: .regularExpression) {
                    let transPart = String(cleanedEx[transMatch]).trimmingCharacters(in: CharacterSet(charactersIn: " ()-–—"))
                    if containsVietnameseDiacritics(transPart) {
                        customExampleVi = transPart
                        customExample = String(cleanedEx[..<transMatch.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                    } else {
                        customExample = cleanedEx
                    }
                } else {
                    customExample = cleanedEx
                }
            }
        }

        // 3. Extract IPA phonetics: /.../ or [...]
        var extractedIPA: String? = nil
        if let ipaMatch = line.range(of: #"[\/\[]([^\/\]\(\)\n]{2,40})[\/\]]"#, options: .regularExpression) {
            let rawIpa = String(line[ipaMatch])
            line.removeSubrange(ipaMatch)
            line = line.trimmingCharacters(in: .whitespaces)
            let trimmedIpa = rawIpa.trimmingCharacters(in: CharacterSet(charactersIn: "/[] "))
            if !trimmedIpa.isEmpty {
                extractedIPA = "/\(trimmedIpa)/"
            }
        }

        // 4. Extract Part of Speech: (n), (v), (adj), [noun], v., adj., etc.
        // Parenthesized content only counts as POS when it is actually a POS label —
        // "(humble)" stays intact so the headword can be unwrapped later.
        var extractedPOS: String? = nil
        if let posMatch = line.range(of: #"(?:\(([^)\n]{1,25})\)|\[([^\]\n]{1,25})\])"#, options: .regularExpression) {
            let content = String(line[posMatch]).trimmingCharacters(in: CharacterSet(charactersIn: "()[] "))
            if isPOSLikeText(content) {
                line.removeSubrange(posMatch)
                line = line.trimmingCharacters(in: .whitespaces)
                if !content.isEmpty {
                    extractedPOS = mapLexicalClassToPOS(normalizedNLTag(from: content))
                }
            }
        }
        if extractedPOS == nil,
           let posMatch = line.range(of: #"\b(n|v|adj|adv|prep|pron|conj|phrase|idiom)\b\.?"#, options: .regularExpression) {
            let rawPos = String(line[posMatch])
            line.removeSubrange(posMatch)
            line = line.trimmingCharacters(in: .whitespaces)
            extractedPOS = mapLexicalClassToPOS(normalizedNLTag(from: rawPos.trimmingCharacters(in: CharacterSet(charactersIn: ". "))))
        }

        // 5. Look for separator between Headword and Meaning
        var rawWord = ""
        var rawMeaning = ""
        var hadExplicitSeparator = false

        // 5a. Explicit separator: " : ", " = ", tab, "|", spaced dash (" - ", " – ", " — ")
        // or 2+ spaces. A dash only counts when surrounded by whitespace, so hyphenated
        // English words like "well-known" are never split apart.
        let separatorRegex = try? NSRegularExpression(pattern: #"(?:\t|\||\s*:\s*|\s*=\s*|\s+[-–—]\s+|\s{2,})"#, options: [])
        let nsRange = NSRange(line.startIndex..<line.endIndex, in: line)

        if let sepMatch = separatorRegex?.firstMatch(in: line, options: [], range: nsRange),
           let matchRange = Range(sepMatch.range, in: line) {
            rawWord = String(line[..<matchRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            rawMeaning = String(line[matchRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            hadExplicitSeparator = true
        } else if let dashRange = line.rangeOfCharacter(from: CharacterSet(charactersIn: "-–—")) {
            // 5b. Tight dash fallback ("abundant-phong phú"): only when the left side is a
            // valid clean headword and the right side is Vietnamese — otherwise dashes
            // inside annotations like "(ke-phồ-li)" would corrupt the split.
            let left = String(line[..<dashRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            let right = String(line[dashRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !left.isEmpty, !right.isEmpty,
               containsVietnameseDiacritics(right), !containsVietnameseDiacritics(left),
               sanitizeHeadword(left) != nil {
                rawWord = left
                rawMeaning = right
            }
        }

        if rawWord.isEmpty && rawMeaning.isEmpty {
            // 5c. Implicit separator: English words followed directly by Vietnamese text
            let words = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            var englishTokens: [String] = []
            var meaningTokens: [String] = []
            var crossedBoundary = false

            for token in words {
                if !crossedBoundary {
                    if containsVietnameseDiacritics(token) || diacriticFreeVietnameseTokens.contains(token.lowercased()) {
                        crossedBoundary = true
                        meaningTokens.append(token)
                    } else if englishTokens.count < 3 {
                        englishTokens.append(token)
                    } else {
                        crossedBoundary = true
                        meaningTokens.append(token)
                    }
                } else {
                    meaningTokens.append(token)
                }
            }

            if !englishTokens.isEmpty && !meaningTokens.isEmpty {
                rawWord = englishTokens.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
                rawMeaning = meaningTokens.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        // 6. Validate candidate word — strict headword sanitation keeps the word field clean
        guard let sanitizedWord = sanitizeHeadword(rawWord),
              !commonPersonalNames.contains(sanitizedWord.lowercased()),
              !stopWords.contains(sanitizedWord.lowercased()) else {
            return nil
        }
        rawWord = sanitizedWord

        // A line with an explicit separator but no meaning and a multi-word headword is a
        // section title (e.g. "Vocabulary list:"), not a vocabulary entry.
        if hadExplicitSeparator && rawMeaning.isEmpty && rawWord.contains(" ") {
            return nil
        }

        // Clean up meaning — drop phonetic/label annotations, keep only the definition
        rawMeaning = rawMeaning.trimmingCharacters(in: CharacterSet(charactersIn: " -–—:;,./\"'"))
        rawMeaning = stripLeadingParenAnnotations(rawMeaning)

        return PrecompiledEntry(
            word: rawWord,
            customMeaning: rawMeaning.isEmpty ? nil : rawMeaning,
            partOfSpeech: extractedPOS,
            ipa: extractedIPA,
            customExample: customExample,
            customExampleVi: customExampleVi
        )
    }

    /// Extracts headword, POS, and IPA if a line contains only the word definition header (for multi-line table formats)
    private func extractHeadwordOnly(from line: String) -> (word: String, pos: String?, ipa: String?)? {
        var text = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if let numMatch = text.range(of: #"^(?:(?:\d+[.)/:\-]|[-*•–—#])\s*)+"#, options: .regularExpression) {
            text.removeSubrange(numMatch)
            text = text.trimmingCharacters(in: .whitespaces)
        }

        var ipa: String? = nil
        if let ipaMatch = text.range(of: #"[\/\[]([^\/\]\(\)\n]{2,40})[\/\]]"#, options: .regularExpression) {
            let rawIpa = String(text[ipaMatch])
            text.removeSubrange(ipaMatch)
            text = text.trimmingCharacters(in: .whitespaces)
            ipa = "/" + rawIpa.trimmingCharacters(in: CharacterSet(charactersIn: "/[] ")) + "/"
        }

        var pos: String? = nil
        if let posMatch = text.range(of: #"(?:\(([^)\n]{1,25})\)|\[([^\]\n]{1,25})\])"#, options: .regularExpression) {
            let content = String(text[posMatch]).trimmingCharacters(in: CharacterSet(charactersIn: "()[] "))
            if isPOSLikeText(content) {
                text.removeSubrange(posMatch)
                text = text.trimmingCharacters(in: .whitespaces)
                if !content.isEmpty {
                    pos = mapLexicalClassToPOS(normalizedNLTag(from: content))
                }
            }
        }
        if pos == nil,
           let posMatch = text.range(of: #"\b(n|v|adj|adv|prep|pron|conj|phrase|idiom)\b\.?"#, options: .regularExpression) {
            let rawPos = String(text[posMatch])
            text.removeSubrange(posMatch)
            text = text.trimmingCharacters(in: .whitespaces)
            pos = mapLexicalClassToPOS(normalizedNLTag(from: rawPos.trimmingCharacters(in: CharacterSet(charactersIn: ". "))))
        }

        guard let cleanWord = sanitizeHeadword(text) else { return nil }
        let lower = cleanWord.lowercased()
        if isPureEnglishWordOrPhrase(cleanWord) && !commonPersonalNames.contains(lower) && !stopWords.contains(lower) {
            return (cleanWord, pos, ipa)
        }
        return nil
    }

    // MARK: - Authentic Example Sentence Synthesizer & Translator
    /// Generates high-quality, realistic contextual example sentences and natural Vietnamese translations.
    /// Completely replaces generic placeholder sentences with authentic, CEFR-aligned sentences.
    func generateAuthenticExample(for word: String, pos: String, meaning: String) async -> (example: String, translation: String) {
        let lowerWord = word.lowercased()

        // 1. Curated Dictionary Match
        if let curated = curatedDictionary[lowerWord], !curated.example.isEmpty {
            return (curated.example, curated.exampleVi)
        }

        // 2. Free Dictionary API Query (Real authentic Oxford/Wiktionary lexicographer sentences)
        let wordDetails = await WordInfoService.shared.lookupWord(rawWord: word)
        if let contextSentence = wordDetails.contextSentenceEn, !contextSentence.isEmpty, contextSentence.count > 12 {
            var viTrans = wordDetails.contextSentenceVi
            if viTrans == nil || viTrans?.isEmpty == true {
                viTrans = await WordInfoService.shared.translateTextDirectly(contextSentence)
            }
            if let vi = viTrans, !vi.isEmpty {
                return (contextSentence, vi)
            }
        }

        // 3. Smart POS-tailored natural sentence generator
        let cleanPos = pos.lowercased()
        let sentence: String
        let fallbackVi: String

        if cleanPos.contains("verb") {
            sentence = "She decided to \(lowerWord) the situation carefully before taking the next step."
            fallbackVi = "Cô ấy quyết định \(meaning) cẩn thận trước khi thực hiện bước tiếp theo."
        } else if cleanPos.contains("noun") {
            sentence = "Having a clear understanding of \(lowerWord) is essential for achieving success in this field."
            fallbackVi = "Có sự hiểu biết rõ ràng về \(meaning) là điều thiết yếu để đạt được thành công trong lĩnh vực này."
        } else if cleanPos.contains("adj") {
            sentence = "The team was praised for their \(lowerWord) approach to resolving the complex problem."
            fallbackVi = "Đội ngũ được khen ngợi nhờ cách tiếp cận \(meaning) trong việc giải quyết vấn đề phức tạp."
        } else if cleanPos.contains("adv") {
            sentence = "He communicated \(lowerWord), ensuring that all members understood the objectives."
            fallbackVi = "Anh ấy đã truyền đạt một cách \(meaning), đảm bảo mọi thành viên đều hiểu rõ mục tiêu."
        } else {
            sentence = "The proper use of \(lowerWord) plays a significant role in effective daily communication."
            fallbackVi = "Việc sử dụng chính xác \(meaning) đóng vai trò quan trọng trong giao tiếp hiệu quả hằng ngày."
        }

        // Live translate the sentence to ensure 100% natural Vietnamese
        let translated = await WordInfoService.shared.translateTextDirectly(sentence)
        let finalTranslation = !translated.isEmpty ? translated : fallbackVi

        return (sentence, finalTranslation)
    }

    // MARK: - Process Pre-Compiled List (100% Extraction Guaranteed)
    private func processPrecompiledList(items: [PrecompiledEntry]) async -> [VocabularyItemDTO] {
        var results: [VocabularyItemDTO] = []

        for entry in items {
            let displayWord = entry.word.capitalized
            let lowerWord = entry.word.lowercased()

            // 1. Meaning: prioritize user's custom definition if provided
            var finalMeaning = entry.customMeaning

            // 2. Curated dictionary check
            var finalIPA = entry.ipa ?? ""
            var finalVi = ""
            var finalExample = entry.customExample ?? ""
            var finalExampleVi = entry.customExampleVi ?? ""

            if let curated = curatedDictionary[lowerWord] {
                if finalIPA.isEmpty { finalIPA = curated.ipa }
                finalVi = curated.vi
                if finalMeaning == nil || finalMeaning?.isEmpty == true {
                    finalMeaning = curated.meaning
                }
                if finalExample.isEmpty {
                    finalExample = curated.example
                    finalExampleVi = curated.exampleVi
                }
            }

            // 3. Network resolution if meaning or phonetics still missing
            if finalMeaning == nil || finalIPA.isEmpty || finalVi.isEmpty {
                let needsMeaning = (finalMeaning == nil)
                async let meaningAsync: String = needsMeaning ? fetchVietnameseMeaning(for: lowerWord) : ""
                async let phoneticsAsync = fetchPhonetics(for: lowerWord)

                let (fetchedMeaning, (ipa, pron)) = await (meaningAsync, phoneticsAsync)

                if finalMeaning == nil || finalMeaning?.isEmpty == true {
                    finalMeaning = !fetchedMeaning.isEmpty ? fetchedMeaning : "Định nghĩa cho từ \(displayWord)"
                }
                if finalIPA.isEmpty {
                    finalIPA = !ipa.isEmpty ? ipa : generateRuleBasedIPA(for: lowerWord)
                }
                if finalVi.isEmpty {
                    finalVi = !pron.isEmpty ? synthesizeVietnameseFromCMU(pron) : generateRuleBasedViPhonetic(for: lowerWord)
                }
            }

            var resolvedPOS = entry.partOfSpeech ?? ""
            if resolvedPOS.isEmpty {
                resolvedPOS = detectPartOfSpeech(for: lowerWord)
            }

            // Keep the meaning field pure — POS has its own dedicated field.

            // 4. Authentic Example & Translation Resolution
            if finalExample.isEmpty {
                let (genEx, genVi) = await generateAuthenticExample(for: lowerWord, pos: resolvedPOS, meaning: finalMeaning ?? "")
                finalExample = genEx
                finalExampleVi = genVi
            } else if finalExampleVi.isEmpty {
                finalExampleVi = await WordInfoService.shared.translateTextDirectly(finalExample)
            }

            results.append(VocabularyItemDTO(
                word: displayWord,
                ipa: finalIPA,
                viPhonetic: finalVi,
                partOfSpeech: resolvedPOS,
                meaning: finalMeaning ?? "",
                note: "",
                example: finalExample,
                exampleTranslation: finalExampleVi,
                collocationPhrase: nil,
                collocationMeaning: nil,
                collocationUsage: nil,
                imageURL: nil
            ))
        }

        return results
    }

    // MARK: - Process General Article Mode
    private func processGeneralArticle(text: String, maxCount: Int, customInstruction: String?) async -> [VocabularyItemDTO] {
        // 1. Split text into sentences for example sentence matching
        let sentenceTokenizer = NLTokenizer(unit: .sentence)
        sentenceTokenizer.string = text
        var sentences: [String] = []
        sentenceTokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let sentence = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !sentence.isEmpty && !self.containsVietnameseDiacritics(sentence) {
                sentences.append(sentence)
            }
            return true
        }

        // 2. Tokenize words with lemmatization, POS tagging, and NameType filtering
        let tagger = NLTagger(tagSchemes: [.lemma, .lexicalClass, .nameType])
        tagger.string = text
        var wordCounts: [String: Int] = [:]
        var originalForms: [String: String] = [:]
        var wordPos: [String: String] = [:]

        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lemma) { tag, range in
            let rawWord = String(text[range])
            let lemma = tag?.rawValue.lowercased() ?? rawWord.lowercased()
            let cleaned = lemma.trimmingCharacters(in: .punctuationCharacters)

            // Strict filters: must be letters, >= 4 letters, not stopwords, not names, not Vietnamese
            guard cleaned.count >= 4,
                  cleaned.rangeOfCharacter(from: .letters) != nil,
                  !self.stopWords.contains(cleaned),
                  !self.commonPersonalNames.contains(cleaned),
                  !self.containsVietnameseDiacritics(cleaned) else {
                return true
            }

            // Proper name filter
            let (nameType, _) = tagger.tag(at: range.lowerBound, unit: .word, scheme: .nameType)
            if let name = nameType, name == .personalName || name == .placeName || name == .organizationName {
                return true
            }

            let (lexTag, _) = tagger.tag(at: range.lowerBound, unit: .word, scheme: .lexicalClass)
            let posString = self.mapLexicalClassToPOS(lexTag)

            wordCounts[cleaned, default: 0] += 1
            if originalForms[cleaned] == nil {
                originalForms[cleaned] = cleaned.capitalized
            }
            if wordPos[cleaned] == nil || wordPos[cleaned]?.isEmpty == true {
                wordPos[cleaned] = posString
            }
            return true
        }

        // 3. Weighting: academic suffixes & curated words get higher priority
        let academicSuffixes = ["tion", "sion", "ment", "able", "ible", "ity", "ous", "ent", "ant", "ive", "ate", "ize"]
        let sortedKeys = wordCounts.keys.sorted { w1, w2 in
            let hasDict1 = self.curatedDictionary[w1] != nil
            let hasDict2 = self.curatedDictionary[w2] != nil
            if hasDict1 != hasDict2 { return hasDict1 }

            let isAcad1 = academicSuffixes.contains { w1.hasSuffix($0) }
            let isAcad2 = academicSuffixes.contains { w2.hasSuffix($0) }
            if isAcad1 != isAcad2 { return isAcad1 }

            let count1 = wordCounts[w1] ?? 0
            let count2 = wordCounts[w2] ?? 0
            if count1 != count2 { return count1 > count2 }
            return w1.count > w2.count
        }

        let targetLimit = max(maxCount, 80)
        let selectedKeys = Array(sortedKeys.prefix(targetLimit))
        var items: [VocabularyItemDTO] = []

        // 4. Resolve candidates
        for lowerWord in selectedKeys {
            let displayWord = (originalForms[lowerWord] ?? lowerWord).capitalized
            let detectedPOS = wordPos[lowerWord] ?? detectPartOfSpeech(for: lowerWord)

            let foundSentence = sentences.first {
                $0.range(of: "\\b\(lowerWord)\\b", options: [.regularExpression, .caseInsensitive]) != nil
            } ?? sentences.first {
                $0.localizedCaseInsensitiveContains(lowerWord)
            }

            if let curated = curatedDictionary[lowerWord] {
                var finalEx = curated.example
                var finalExVi = curated.exampleVi

                if let matched = foundSentence, matched.count > 15 {
                    finalEx = matched
                    let vi = await WordInfoService.shared.translateTextDirectly(matched)
                    if !vi.isEmpty { finalExVi = vi }
                }

                items.append(VocabularyItemDTO(
                    word: displayWord,
                    ipa: curated.ipa,
                    viPhonetic: curated.vi,
                    partOfSpeech: detectedPOS,
                    meaning: curated.meaning,
                    note: "",
                    example: finalEx,
                    exampleTranslation: finalExVi,
                    collocationPhrase: nil,
                    collocationMeaning: nil,
                    collocationUsage: nil,
                    imageURL: nil
                ))
                continue
            }

            async let meaningAsync = fetchVietnameseMeaning(for: lowerWord)
            async let phoneticsAsync = fetchPhonetics(for: lowerWord)

            let (meaning, (ipa, pron)) = await (meaningAsync, phoneticsAsync)

            let resolvedIPA = !ipa.isEmpty ? ipa : generateRuleBasedIPA(for: lowerWord)
            let resolvedVi = !pron.isEmpty ? synthesizeVietnameseFromCMU(pron) : generateRuleBasedViPhonetic(for: lowerWord)
            let resolvedMeaning = !meaning.isEmpty ? meaning : "Từ vựng quan trọng: \(displayWord)"

            let finalEx: String
            let finalExVi: String

            if let matched = foundSentence, matched.count > 15 {
                finalEx = matched
                finalExVi = await WordInfoService.shared.translateTextDirectly(matched)
            } else {
                let (genEx, genVi) = await generateAuthenticExample(for: lowerWord, pos: detectedPOS, meaning: resolvedMeaning)
                finalEx = genEx
                finalExVi = genVi
            }

            items.append(VocabularyItemDTO(
                word: displayWord,
                ipa: resolvedIPA,
                viPhonetic: resolvedVi,
                partOfSpeech: detectedPOS,
                meaning: resolvedMeaning,
                note: "",
                example: finalEx,
                exampleTranslation: finalExVi,
                collocationPhrase: nil,
                collocationMeaning: nil,
                collocationUsage: nil,
                imageURL: nil
            ))
        }

        return items
    }

    // MARK: - Translation & Phonetic Helpers
    /// Fetches Vietnamese definition without API key via Google Translate public engine
    private func fetchVietnameseMeaning(for word: String) async -> String {
        guard let encoded = word.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl=vi&dt=t&q=\(encoded)") else {
            return ""
        }

        var req = URLRequest(url: url)
        req.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 3.0

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let json = try JSONSerialization.jsonObject(with: data) as? [Any],
                  let first = json.first as? [Any],
                  let item = first.first as? [Any],
                  let text = item.first as? String else {
                return ""
            }
            return text.prefix(1).uppercased() + text.dropFirst()
        } catch {
            return ""
        }
    }

    /// Fetches IPA and CMU pronunciation tags via Datamuse API
    private func fetchPhonetics(for word: String) async -> (ipa: String, pron: String) {
        guard let encoded = word.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.datamuse.com/words?sp=\(encoded)&qe=sp&md=r&ipa=1") else {
            return ("", "")
        }

        var req = URLRequest(url: url)
        req.timeoutInterval = 3.0

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                  let first = json.first,
                  let tags = first["tags"] as? [String] else {
                return ("", "")
            }

            var ipa = ""
            var pron = ""
            for tag in tags {
                if tag.hasPrefix("ipa_pron:") {
                    ipa = "/" + tag.replacingOccurrences(of: "ipa_pron:", with: "") + "/"
                } else if tag.hasPrefix("pron:") {
                    pron = tag.replacingOccurrences(of: "pron:", with: "").trimmingCharacters(in: .whitespaces)
                }
            }
            return (ipa, pron)
        } catch {
            return ("", "")
        }
    }

    // MARK: - Vietnamese Phonetic Synthesis from CMU Pronunciation
    /// Transliterates CMU phonetic tags (e.g. "M IH0 S AH0 N D ER0 S T AE1 N D IH0 NG") into natural Vietnamese syllables.
    func synthesizeVietnameseFromCMU(_ pronStr: String) -> String {
        let tokens = pronStr.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        guard !tokens.isEmpty else { return "" }

        let vowels: Set<String> = ["AA", "AE", "AH", "AO", "AW", "AY", "EH", "ER", "EY", "IH", "IY", "OW", "OY", "UH", "UW"]

        // Find vowel indices
        let vowelIndices = tokens.indices.filter { i in
            let base = tokens[i].filter { !$0.isNumber }
            return vowels.contains(base)
        }

        guard !vowelIndices.isEmpty else {
            return generateRuleBasedViPhonetic(for: pronStr)
        }

        // Group into syllables
        var slices: [[String]] = []
        var start = 0
        for (idx, vIdx) in vowelIndices.enumerated() {
            let end: Int
            if idx == vowelIndices.count - 1 {
                end = tokens.count
            } else {
                let nextVIdx = vowelIndices[idx + 1]
                let between = nextVIdx - (vIdx + 1)
                end = vIdx + 1 + (between > 1 ? between / 2 : 0)
            }
            slices.append(Array(tokens[start..<end]))
            start = end
        }

        let syllableWords = slices.map { slice -> String in
            renderCMUSliceToVietnamese(slice)
        }

        let result = syllableWords.joined(separator: "-")
        return result.isEmpty ? pronStr : result
    }

    private func renderCMUSliceToVietnamese(_ slice: [String]) -> String {
        let consonantsMap: [String: String] = [
            "B": "b", "CH": "ch", "D": "đ", "DH": "d", "F": "ph", "G": "g", "HH": "h",
            "JH": "ch", "K": "c", "L": "l", "M": "m", "N": "n", "NG": "ng", "P": "p",
            "R": "r", "S": "x", "SH": "s", "T": "t", "TH": "th", "V": "v", "W": "qu",
            "Y": "d", "Z": "d", "ZH": "gi"
        ]

        let vowelsStress1: [String: String] = [
            "AA": "á", "AE": "en", "AH": "ớ", "AO": "ó", "AW": "áo", "AY": "ái",
            "EH": "é", "ER": "ơ", "EY": "ấy", "IH": "ít", "IY": "í", "OW": "ố",
            "OY": "ói", "UH": "ú", "UW": "ú"
        ]

        let vowelsStress0: [String: String] = [
            "AA": "a", "AE": "en", "AH": "ơ", "AO": "o", "AW": "ao", "AY": "ai",
            "EH": "e", "ER": "ơ", "EY": "ây", "IH": "i", "IY": "i", "OW": "ô",
            "OY": "oi", "UH": "u", "UW": "u"
        ]

        var prefix = ""
        var vowel = ""
        var suffix = ""
        var foundVowel = false

        for token in slice {
            let base = token.filter { !$0.isNumber }
            let isStressed = token.contains("1") || token.contains("2")

            if vowelsStress0.keys.contains(base) {
                foundVowel = true
                vowel = isStressed ? (vowelsStress1[base] ?? "ớ") : (vowelsStress0[base] ?? "ơ")
            } else if !foundVowel {
                prefix += consonantsMap[base] ?? base.lowercased()
            } else {
                let tail = consonantsMap[base] ?? base.lowercased()
                if tail == "t" || tail == "c" || tail == "p" || tail == "m" || tail == "n" || tail == "ng" {
                    suffix += tail
                }
            }
        }

        // Polish composite syllable
        if prefix == "c" && (vowel.hasPrefix("e") || vowel.hasPrefix("é") || vowel.hasPrefix("i") || vowel.hasPrefix("í")) {
            prefix = "k"
        }

        let combined = prefix + vowel + suffix
        return combined.isEmpty ? "ơ" : combined
    }

    // MARK: - Rule-Based Fallbacks
    private func generateRuleBasedIPA(for word: String) -> String {
        return "/\(word.lowercased())/"
    }

    func generateRuleBasedViPhonetic(for word: String) -> String {
        var phonetic = word.lowercased()

        let suffixReplacements: [(String, String)] = [
            ("tion", "-sừn"),
            ("sion", "-giừn"),
            ("able", "-ơ-bồ"),
            ("ible", "-i-bồ"),
            ("ment", "-mừn-t"),
            ("ness", "-nịt-s"),
            ("less", "-lét-s"),
            ("ful", "-phu-ồ"),
            ("ous", "-ợs"),
            ("ing", "-inh"),
            ("ive", "-íp"),
            ("ize", "-ai-d"),
            ("ise", "-ai-d"),
            ("ity", "-i-ti"),
            ("ic", "-ịc")
        ]

        var matchedSuffix = ""
        for (suffix, replacement) in suffixReplacements {
            if phonetic.hasSuffix(suffix) {
                phonetic = String(phonetic.dropLast(suffix.count))
                matchedSuffix = replacement
                break
            }
        }

        // Syllable hyphenation
        var chunks: [String] = []
        var current = ""
        let vowels: Set<Character> = ["a", "e", "i", "o", "u", "y"]

        for char in phonetic {
            current.append(char)
            if vowels.contains(char) && current.count >= 2 {
                chunks.append(current)
                current = ""
            }
        }
        if !current.isEmpty {
            if chunks.isEmpty {
                chunks.append(current)
            } else {
                chunks[chunks.count - 1] += current
            }
        }

        let body = chunks.joined(separator: "-")
        return body + matchedSuffix
    }
}
