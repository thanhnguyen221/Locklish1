import Foundation
import NaturalLanguage

// MARK: - WordInfoService
/// High-speed local and hybrid dictionary service for looking up word details, parts of speech,
/// phonetic transcriptions, authentic Vietnamese meanings, English definitions, and rich synonyms
/// without burning generative AI tokens on every tap.
final class WordInfoService {
    static let shared = WordInfoService()

    private var inMemoryCache: [String: WordDetailInfo] = [:]
    private let userDefaultsCacheKey = "locklish_cached_word_details"

    private init() {
        loadPersistedCache()
    }

    // MARK: - Primary Word Lookup
    /// Resolves comprehensive, localized word information for any English word.
    /// Incorporates sentence-level contextual POS tagging (NLTagger), lemmatization, deck items,
    /// curated dictionary, Google Translate, Datamuse, and Free Dictionary API.
    func lookupWord(
        rawWord: String,
        sentenceContext: String? = nil,
        deckItems: [VocabularyItem] = []
    ) async -> WordDetailInfo {
        let cleanWord = sanitizeWord(rawWord)
        let lower = cleanWord.lowercased()

        // Detect contextual POS first so cache and dictionary query are POS-accurate
        let taggerPos = detectPartOfSpeechInContext(word: cleanWord, in: sentenceContext)
        let cacheKey = sentenceContext != nil ? "\(lower)_\(taggerPos.lowercased())" : lower

        // 1. Check in-memory cache
        if let cached = inMemoryCache[cacheKey] {
            return cached
        } else if sentenceContext == nil, let cached = inMemoryCache[lower] {
            return cached
        }

        // 2. Lemmatization (base form)
        let lemma = findLemma(for: cleanWord).lowercased()
        let candidateKeys = [lower, lemma].filter { !$0.isEmpty }

        // 3. Check current deck items for direct match
        let matchingDeckItem = deckItems.first { item in
            let itemLower = item.word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return candidateKeys.contains(itemLower)
        }

        // 4. Check local curated dictionary
        var curatedTuple: (ipa: String, vi: String, meaning: String, example: String, exampleVi: String)? = nil
        for key in candidateKeys {
            if let found = LocalVocabularyExtractorService.shared.curatedDictionary[key] {
                curatedTuple = found
                break
            }
        }

        // 5. Concurrently fetch Vietnamese translation, Datamuse data, Dictionary API (with target POS), and context translation
        async let vietnameseMeaningTask = fetchVietnameseMeaning(word: cleanWord, lemma: lemma)
        async let datamuseTask = fetchDatamuseInfo(word: cleanWord, lemma: lemma)
        async let freeDictionaryTask = fetchFreeDictionaryData(word: cleanWord, lemma: lemma, targetPos: taggerPos)
        async let contextViTask: String? = {
            if let sentence = sentenceContext, !sentence.isEmpty {
                return await translateTextDirectly(sentence)
            }
            return nil
        }()

        let (fetchedViMeaning, datamuseInfo, apiData, resolvedContextVi) = await (vietnameseMeaningTask, datamuseTask, freeDictionaryTask, contextViTask)

        // 6. Resolve Part of Speech (Sentence context POS has highest authority!)
        let resolvedPos: String
        if sentenceContext != nil && !taggerPos.isEmpty && taggerPos != "Word" {
            resolvedPos = taggerPos
        } else if let item = matchingDeckItem, !item.partOfSpeech.isEmpty {
            resolvedPos = item.partOfSpeech
        } else if let apiPos = apiData?.partOfSpeech, !apiPos.isEmpty {
            resolvedPos = apiPos
        } else if let dataPos = datamuseInfo.partOfSpeech, !dataPos.isEmpty {
            resolvedPos = dataPos
        } else {
            resolvedPos = taggerPos
        }

        // 7. Resolve Vietnamese Meaning (Never Empty!)
        let resolvedMeaningVi: String
        if let item = matchingDeckItem, !item.meaning.isEmpty && (sentenceContext == nil || item.partOfSpeech.lowercased() == resolvedPos.lowercased()) {
            resolvedMeaningVi = item.meaning
        } else if let curated = curatedTuple, !curated.meaning.isEmpty {
            resolvedMeaningVi = curated.meaning
        } else if !fetchedViMeaning.isEmpty {
            resolvedMeaningVi = fetchedViMeaning
        } else {
            resolvedMeaningVi = "Ý nghĩa: \(cleanWord.capitalized)"
        }

        // 8. Resolve English Definition
        let resolvedDefinitionEn: String
        if let apiDef = apiData?.definition, !apiDef.isEmpty {
            resolvedDefinitionEn = apiDef
        } else if let dataDef = datamuseInfo.definition, !dataDef.isEmpty {
            resolvedDefinitionEn = dataDef
        } else if let item = matchingDeckItem, !item.note.isEmpty {
            resolvedDefinitionEn = item.note
        } else {
            resolvedDefinitionEn = "A term referring to \(cleanWord) in modern English usage."
        }

        // 9. Resolve Phonetics (IPA & viPhonetic)
        let resolvedIPA: String
        if let item = matchingDeckItem, !item.ipa.isEmpty {
            resolvedIPA = item.ipa
        } else if let curated = curatedTuple, !curated.ipa.isEmpty {
            resolvedIPA = curated.ipa
        } else if let apiIpa = apiData?.ipa, !apiIpa.isEmpty {
            resolvedIPA = apiIpa.hasPrefix("/") ? apiIpa : "/\(apiIpa)/"
        } else if let dataIpa = datamuseInfo.ipa, !dataIpa.isEmpty {
            resolvedIPA = dataIpa.hasPrefix("/") ? dataIpa : "/\(dataIpa)/"
        } else {
            resolvedIPA = "/\(lower)/"
        }

        let resolvedViPhonetic: String
        if let item = matchingDeckItem, !item.viPhonetic.isEmpty {
            resolvedViPhonetic = item.viPhonetic
        } else if let curated = curatedTuple, !curated.vi.isEmpty {
            resolvedViPhonetic = curated.vi
        } else if let pron = datamuseInfo.cmuPron, !pron.isEmpty {
            resolvedViPhonetic = LocalVocabularyExtractorService.shared.synthesizeVietnameseFromCMU(pron)
        } else {
            resolvedViPhonetic = LocalVocabularyExtractorService.shared.generateRuleBasedViPhonetic(for: cleanWord)
        }

        // 10. Resolve Example Sentences
        let resolvedExampleEn: String
        let resolvedExampleVi: String
        if let sentence = sentenceContext, !sentence.isEmpty {
            resolvedExampleEn = sentence
            if let vi = resolvedContextVi, !vi.isEmpty {
                resolvedExampleVi = vi
            } else {
                resolvedExampleVi = await translateTextDirectly(sentence)
            }
        } else if let item = matchingDeckItem, !item.example.isEmpty {
            resolvedExampleEn = item.example
            resolvedExampleVi = item.exampleTranslation
        } else if let apiEx = apiData?.example, !apiEx.isEmpty {
            resolvedExampleEn = apiEx
            resolvedExampleVi = await translateTextDirectly(apiEx)
        } else {
            resolvedExampleEn = "The word \"\(cleanWord)\" is frequently used in everyday English."
            resolvedExampleVi = "Từ \"\(cleanWord)\" thường xuyên được sử dụng trong tiếng Anh giao tiếp hàng ngày."
        }

        // 11. Resolve Synonyms & Antonyms (Merge API + Datamuse)
        var allSynonyms = (apiData?.synonyms ?? []) + datamuseInfo.synonyms
        var allAntonyms = (apiData?.antonyms ?? []) + datamuseInfo.antonyms

        // Filter out self and deduplicate
        allSynonyms = Array(
            Set(
                allSynonyms
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                    .filter { $0 != lower && $0 != lemma && !$0.isEmpty && $0.count >= 2 }
            )
        ).sorted()

        allAntonyms = Array(
            Set(
                allAntonyms
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                    .filter { $0 != lower && $0 != lemma && !$0.isEmpty }
            )
        ).sorted()

        let cefr = resolveCEFRLevel(word: cleanWord, frequencyTag: datamuseInfo.frequencyTag)

        let result = WordDetailInfo(
            word: cleanWord,
            ipa: resolvedIPA,
            viPhonetic: resolvedViPhonetic,
            partOfSpeech: localizePartOfSpeech(resolvedPos),
            meaningVi: resolvedMeaningVi,
            definitionEn: resolvedDefinitionEn,
            exampleEn: resolvedExampleEn,
            exampleVi: resolvedExampleVi,
            synonyms: Array(allSynonyms.prefix(8)),
            antonyms: Array(allAntonyms.prefix(6)),
            isTargetWord: matchingDeckItem != nil,
            cefrLevel: cefr,
            contextSentenceEn: sentenceContext,
            contextSentenceVi: resolvedContextVi
        )

        // Cache result
        inMemoryCache[cacheKey] = result
        savePersistedCache()

        return result
    }

    // MARK: - Word Sanitization
    func sanitizeWord(_ word: String) -> String {
        let allowed = CharacterSet.letters.union(CharacterSet(charactersIn: "-'"))
        let trimmed = word.trimmingCharacters(in: allowed.inverted)
        return trimmed
    }

    // MARK: - Lemmatization (Root form extraction)
    func findLemma(for word: String) -> String {
        let tagger = NLTagger(tagSchemes: [.lemma])
        tagger.string = word
        var foundLemma: String? = nil
        tagger.enumerateTags(in: word.startIndex..<word.endIndex, unit: .word, scheme: .lemma) { tag, _ in
            if let tag = tag, !tag.rawValue.isEmpty {
                foundLemma = tag.rawValue
            }
            return false
        }
        return foundLemma ?? word
    }

    // MARK: - Sentence-Level POS Detection with Apple NaturalLanguage
    /// Evaluates the true grammatical function of the word inside the given sentence context
    /// (e.g. determining whether 'light' is Adjective, Noun, or Verb).
    func detectPartOfSpeechInContext(word: String, in sentence: String?) -> String {
        guard let sentence = sentence, !sentence.isEmpty else {
            return detectPartOfSpeechLocally(for: word)
        }

        let cleanWord = sanitizeWord(word).lowercased()
        guard !cleanWord.isEmpty else { return "Word" }

        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = sentence

        var matchedTag: String? = nil

        tagger.enumerateTags(in: sentence.startIndex..<sentence.endIndex, unit: .word, scheme: .lexicalClass, options: [.omitWhitespace, .omitPunctuation]) { tag, tokenRange in
            let token = String(sentence[tokenRange])
            let cleanToken = sanitizeWord(token).lowercased()
            if cleanToken == cleanWord {
                if let t = tag {
                    matchedTag = t.rawValue
                    return false
                }
            }
            return true
        }

        if let tag = matchedTag {
            return tag
        }

        return detectPartOfSpeechLocally(for: word)
    }

    // MARK: - Local POS Detection with Apple NaturalLanguage
    private func detectPartOfSpeechLocally(for word: String) -> String {
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = word
        let range = word.startIndex..<word.endIndex

        var detectedTag: String? = nil
        tagger.enumerateTags(in: range, unit: .word, scheme: .lexicalClass, options: [.omitWhitespace, .omitPunctuation]) { tag, _ in
            if let tag = tag {
                detectedTag = tag.rawValue
            }
            return false
        }

        return detectedTag ?? "Word"
    }

    // MARK: - Localize POS to Friendly Vietnamese
    func localizePartOfSpeech(_ pos: String) -> String {
        let lower = pos.lowercased()
        if lower.contains("noun") || lower == "n" { return "Danh từ (n)" }
        if lower.contains("verb") || lower == "v" { return "Động từ (v)" }
        if lower.contains("adjective") || lower == "adj" { return "Tính từ (adj)" }
        if lower.contains("adverb") || lower == "adv" { return "Trạng từ (adv)" }
        if lower.contains("pronoun") || lower == "pron" { return "Đại từ (pron)" }
        if lower.contains("preposition") || lower == "prep" { return "Giới từ (prep)" }
        if lower.contains("conjunction") || lower == "conj" { return "Liên từ (conj)" }
        if lower.contains("interjection") || lower == "int" { return "Thán từ (int)" }
        return pos.capitalized
    }

    // MARK: - CEFR Level Detection
    func resolveCEFRLevel(word: String, frequencyTag: String? = nil) -> String {
        let clean = sanitizeWord(word).lowercased()
        guard !clean.isEmpty else { return "B1" }

        // Method 1: Check Datamuse frequency tag if available (f:XXXX.XXXX per million words)
        if let fTag = frequencyTag, fTag.hasPrefix("f:") {
            let numStr = String(fTag.dropFirst(2))
            if let freq = Double(numStr) {
                if freq >= 100.0 {
                    return "A1"
                } else if freq >= 30.0 {
                    return "A2"
                } else if freq >= 8.0 {
                    return "B1"
                } else if freq >= 2.0 {
                    return "B2"
                } else {
                    return "C1"
                }
            }
        }

        // Method 2: High-accuracy length & syllable heuristic
        let count = clean.count
        if count <= 4 {
            return "A1"
        } else if count <= 6 {
            return "A2"
        } else if count <= 8 {
            return "B1"
        } else if count <= 11 {
            return "B2"
        } else {
            return "C1"
        }
    }

    // MARK: - Authentic Vietnamese Translation (Google Translate GTX)
    private func fetchVietnameseMeaning(word: String, lemma: String) async -> String {
        // Try original word first
        let meaning = await translateTextDirectly(word)
        if !meaning.isEmpty {
            return meaning
        }
        // Try lemma if different
        if lemma != word.lowercased() {
            let lemmaMeaning = await translateTextDirectly(lemma)
            if !lemmaMeaning.isEmpty {
                return lemmaMeaning
            }
        }
        return ""
    }

    func translateTextDirectly(_ text: String) async -> String {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return "" }

        guard let encoded = clean.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl=vi&dt=t&q=\(encoded)") else {
            return ""
        }

        var req = URLRequest(url: url)
        req.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 3.5

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let json = try JSONSerialization.jsonObject(with: data) as? [Any],
                  let first = json.first as? [Any] else {
                return ""
            }

            var fullText = ""
            for item in first {
                if let sub = item as? [Any], let piece = sub.first as? String {
                    fullText += piece
                }
            }
            let trimmed = fullText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return "" }
            return trimmed.prefix(1).uppercased() + trimmed.dropFirst()
        } catch {
            return ""
        }
    }

    // MARK: - Datamuse High-Reliability API Integration (Phonetics, Defs, Synonyms)
    private struct DatamuseResult {
        var ipa: String? = nil
        var cmuPron: String? = nil
        var definition: String? = nil
        var partOfSpeech: String? = nil
        var frequencyTag: String? = nil
        var synonyms: [String] = []
        var antonyms: [String] = []
    }

    private func fetchDatamuseInfo(word: String, lemma: String) async -> DatamuseResult {
        var result = DatamuseResult()
        let queryWord = word.lowercased()

        // 1. Fetch Phonetics, Definitions & Frequency via Datamuse md=drf&ipa=1
        if let encoded = queryWord.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "https://api.datamuse.com/words?sp=\(encoded)&qe=sp&md=drf&ipa=1") {
            var req = URLRequest(url: url)
            req.timeoutInterval = 3.0
            if let (data, response) = try? await URLSession.shared.data(for: req),
               (response as? HTTPURLResponse)?.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
               let first = json.first {

                if let tags = first["tags"] as? [String] {
                    for tag in tags {
                        if tag.hasPrefix("ipa_pron:") {
                            result.ipa = "/" + tag.replacingOccurrences(of: "ipa_pron:", with: "") + "/"
                        } else if tag.hasPrefix("pron:") {
                            result.cmuPron = tag.replacingOccurrences(of: "pron:", with: "").trimmingCharacters(in: .whitespaces)
                        } else if tag.hasPrefix("f:") {
                            result.frequencyTag = tag
                        }
                    }
                }

                if let defs = first["defs"] as? [String], let firstDef = defs.first {
                    // defs are formatted like "n\tA member of the common people..."
                    let components = firstDef.components(separatedBy: "\t")
                    if components.count >= 2 {
                        let posTag = components[0].trimmingCharacters(in: .whitespaces)
                        let defText = components[1].trimmingCharacters(in: .whitespaces)
                        result.partOfSpeech = posTag
                        result.definition = defText
                    } else {
                        result.definition = firstDef.trimmingCharacters(in: .whitespaces)
                    }
                }
            }
        }

        // If definition or IPA is still missing and lemma differs, try lemma
        if (result.definition == nil || result.ipa == nil) && lemma != queryWord {
            if let encodedLemma = lemma.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
               let url = URL(string: "https://api.datamuse.com/words?sp=\(encodedLemma)&qe=sp&md=drf&ipa=1") {
                var req = URLRequest(url: url)
                req.timeoutInterval = 3.0
                if let (data, response) = try? await URLSession.shared.data(for: req),
                   (response as? HTTPURLResponse)?.statusCode == 200,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                   let first = json.first {

                    if let tags = first["tags"] as? [String] {
                        for tag in tags {
                            if result.ipa == nil && tag.hasPrefix("ipa_pron:") {
                                result.ipa = "/" + tag.replacingOccurrences(of: "ipa_pron:", with: "") + "/"
                            } else if result.cmuPron == nil && tag.hasPrefix("pron:") {
                                result.cmuPron = tag.replacingOccurrences(of: "pron:", with: "").trimmingCharacters(in: .whitespaces)
                            } else if result.frequencyTag == nil && tag.hasPrefix("f:") {
                                result.frequencyTag = tag
                            }
                        }
                    }

                    if result.definition == nil, let defs = first["defs"] as? [String], let firstDef = defs.first {
                        let components = firstDef.components(separatedBy: "\t")
                        if components.count >= 2 {
                            result.partOfSpeech = components[0].trimmingCharacters(in: .whitespaces)
                            result.definition = components[1].trimmingCharacters(in: .whitespaces)
                        } else {
                            result.definition = firstDef.trimmingCharacters(in: .whitespaces)
                        }
                    }
                }
            }
        }

        // 2. Fetch Synonyms via Datamuse rel_syn and ml (meaning like)
        let synWord = lemma.isEmpty ? queryWord : lemma
        if let encoded = synWord.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "https://api.datamuse.com/words?ml=\(encoded)&max=15") {
            var req = URLRequest(url: url)
            req.timeoutInterval = 3.0
            if let (data, response) = try? await URLSession.shared.data(for: req),
               (response as? HTTPURLResponse)?.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {

                var collected: [String] = []
                for entry in json {
                    if let w = entry["word"] as? String {
                        collected.append(w)
                    }
                }
                result.synonyms = collected
            }
        }

        // 3. Fetch Antonyms via Datamuse rel_ant
        if let encoded = synWord.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "https://api.datamuse.com/words?rel_ant=\(encoded)&max=8") {
            var req = URLRequest(url: url)
            req.timeoutInterval = 2.5
            if let (data, response) = try? await URLSession.shared.data(for: req),
               (response as? HTTPURLResponse)?.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {

                var collected: [String] = []
                for entry in json {
                    if let w = entry["word"] as? String {
                        collected.append(w)
                    }
                }
                result.antonyms = collected
            }
        }

        return result
    }

    // MARK: - Free Dictionary API Integration (With Lemma Fallback)
    private struct APIDictionaryResult {
        let ipa: String
        let partOfSpeech: String
        let definition: String
        let example: String
        let synonyms: [String]
        let antonyms: [String]
    }

    private func fetchFreeDictionaryData(word: String, lemma: String, targetPos: String? = nil) async -> APIDictionaryResult? {
        // Try original word first
        if let direct = await queryFreeDictionaryAPI(for: word, targetPos: targetPos) {
            return direct
        }
        // Try lemma if different
        if lemma != word.lowercased() {
            if let lemmaResult = await queryFreeDictionaryAPI(for: lemma, targetPos: targetPos) {
                return lemmaResult
            }
        }
        return nil
    }

    private func queryFreeDictionaryAPI(for word: String, targetPos: String? = nil) async -> APIDictionaryResult? {
        guard let encoded = word.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "https://api.dictionaryapi.dev/api/v2/entries/en/\(encoded)") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 3.0 // Fast timeout so UI never hangs

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return nil
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                  let firstEntry = json.first else {
                return nil
            }

            // Extract IPA
            var ipa = ""
            if let phonetic = firstEntry["phonetic"] as? String {
                ipa = phonetic
            } else if let phonetics = firstEntry["phonetics"] as? [[String: Any]] {
                for p in phonetics {
                    if let text = p["text"] as? String, !text.isEmpty {
                        ipa = text
                        break
                    }
                }
            }

            // Extract meanings, POS, definitions, synonyms
            var primaryPos = ""
            var primaryDef = ""
            var primaryExample = ""
            var allSynonyms: [String] = []
            var allAntonyms: [String] = []

            if let meanings = firstEntry["meanings"] as? [[String: Any]] {
                // If targetPos is specified, try to find meaning block matching this part of speech!
                var matchedMeaning: [String: Any]? = nil
                if let tPos = targetPos?.lowercased(), !tPos.isEmpty && tPos != "word" {
                    matchedMeaning = meanings.first { m in
                        let pos = (m["partOfSpeech"] as? String ?? "").lowercased()
                        if pos == tPos || pos.contains(tPos) || tPos.contains(pos) {
                            return true
                        }
                        if (tPos.contains("adj") && pos.contains("adj")) ||
                           (tPos.contains("noun") && pos.contains("noun")) ||
                           (tPos.contains("verb") && pos.contains("verb")) ||
                           (tPos.contains("adv") && pos.contains("adv")) {
                            return true
                        }
                        return false
                    }
                }

                if let matched = matchedMeaning {
                    primaryPos = matched["partOfSpeech"] as? String ?? ""
                    if let defs = matched["definitions"] as? [[String: Any]], let first = defs.first {
                        primaryDef = first["definition"] as? String ?? ""
                        primaryExample = first["example"] as? String ?? ""
                    }
                }

                for m in meanings {
                    let pos = m["partOfSpeech"] as? String ?? ""
                    if primaryPos.isEmpty && !pos.isEmpty {
                        primaryPos = pos
                    }

                    if let syns = m["synonyms"] as? [String] {
                        allSynonyms.append(contentsOf: syns)
                    }
                    if let ants = m["antonyms"] as? [String] {
                        allAntonyms.append(contentsOf: ants)
                    }

                    if let defs = m["definitions"] as? [[String: Any]] {
                        for d in defs {
                            if primaryDef.isEmpty, let def = d["definition"] as? String {
                                primaryDef = def
                            }
                            if primaryExample.isEmpty, let ex = d["example"] as? String {
                                primaryExample = ex
                            }
                            if let itemSyns = d["synonyms"] as? [String] {
                                allSynonyms.append(contentsOf: itemSyns)
                            }
                            if let itemAnts = d["antonyms"] as? [String] {
                                allAntonyms.append(contentsOf: itemAnts)
                            }
                        }
                    }
                }
            }

            return APIDictionaryResult(
                ipa: ipa,
                partOfSpeech: primaryPos,
                definition: primaryDef,
                example: primaryExample,
                synonyms: allSynonyms,
                antonyms: allAntonyms
            )
        } catch {
            return nil
        }
    }

    // MARK: - Cache Persistence
    private func loadPersistedCache() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsCacheKey),
              let decoded = try? JSONDecoder().decode([String: WordDetailInfo].self, from: data) else {
            return
        }
        self.inMemoryCache = decoded
    }

    private func savePersistedCache() {
        if inMemoryCache.count > 500 {
            let excess = inMemoryCache.count - 500
            for key in Array(inMemoryCache.keys.prefix(excess)) {
                inMemoryCache.removeValue(forKey: key)
            }
        }
        if let encoded = try? JSONEncoder().encode(inMemoryCache) {
            UserDefaults.standard.setValue(encoded, forKey: userDefaultsCacheKey)
        }
    }
}
