import Foundation

// MARK: - Grammar Models (Codable, mirrors Resources/grammar_data.json)
struct GrammarMeta: Codable {
    let version: String
    let languageOfExplanation: String
    let framework: String
    let note: String?

    enum CodingKeys: String, CodingKey {
        case version
        case languageOfExplanation = "language_of_explanation"
        case framework
        case note
    }
}

struct GrammarPhase: Codable, Identifiable {
    let phase: Int
    let level: String
    let titleVi: String
    let durationWeeks: Int
    let goalsVi: String
    let ipaFocus: [String]
    let topicIds: [String]

    var id: Int { phase }

    enum CodingKeys: String, CodingKey {
        case phase, level
        case titleVi = "title_vi"
        case durationWeeks = "duration_weeks"
        case goalsVi = "goals_vi"
        case ipaFocus = "ipa_focus"
        case topicIds = "topic_ids"
    }
}

struct IPAMonoPhthong: Codable, Identifiable {

    enum CodingKeys: String, CodingKey {
        case symbol, type, example
        case tipVi = "tip_vi"
    }

    let symbol: String
    let type: String          // "long" / "short"
    let example: String
    let tipVi: String

    var id: String { symbol }
}

struct IPADiphthong: Codable, Identifiable {

    enum CodingKeys: String, CodingKey {
        case symbol, example
        case tipVi = "tip_vi"
    }

    let symbol: String
    let example: String
    let tipVi: String

    var id: String { symbol }
}

struct IPAConsonant: Codable, Identifiable {

    enum CodingKeys: String, CodingKey {
        case symbol, voiced, example
        case tipVi = "tip_vi"
    }

    let symbol: String
    let voiced: Bool
    let example: String
    let tipVi: String

    var id: String { symbol }
}

struct IPAData: Codable {
    let vowelsMonophthongs: [IPAMonoPhthong]
    let vowelsDiphthongs: [IPADiphthong]
    let consonants: [IPAConsonant]
    let stressMarks: [String: String]
    let specialRulesVi: [String]

    enum CodingKeys: String, CodingKey {
        case vowelsMonophthongs = "vowels_monophthongs"
        case vowelsDiphthongs = "vowels_diphthongs"
        case consonants
        case stressMarks = "stress_marks"
        case specialRulesVi = "special_rules_vi"
    }
}

struct GrammarExample: Codable {
    let en: String
    let vi: String
}

struct GrammarMistake: Codable {
    let wrong: String
    let right: String
    let noteVi: String

    enum CodingKeys: String, CodingKey {
        case wrong, right
        case noteVi = "note_vi"
    }
}

struct GrammarExercise: Codable {
    let q: String
    let answer: String
}

struct GrammarTopic: Codable, Identifiable {
    let id: String
    let level: String
    let titleEn: String
    let titleVi: String
    let explanationVi: String
    let forms: [String]
    let examples: [GrammarExample]
    let commonMistakes: [GrammarMistake]
    let exercises: [GrammarExercise]

    enum CodingKeys: String, CodingKey {
        case id, level
        case titleEn = "title_en"
        case titleVi = "title_vi"
        case explanationVi = "explanation_vi"
        case forms, examples
        case commonMistakes = "common_mistakes"
        case exercises
    }
}

struct GrammarData: Codable {
    let meta: GrammarMeta
    let roadmap: [GrammarPhase]
    let ipa: IPAData
    let topics: [GrammarTopic]
}

// MARK: - GrammarDataService
/// Loads and validates the bundled grammar curriculum. Topics referenced by a
/// phase's `topic_ids` that don't exist are dropped (and reported) so the UI
/// never renders a dead link.
final class GrammarDataService {
    static let shared = GrammarDataService()

    private(set) var data: GrammarData? = nil
    /// Phase id -> resolved topics in the phase's declared order.
    private(set) var topicsByPhase: [Int: [GrammarTopic]] = [:]

    private init() {
        load()
    }

    func load() {
        guard let url = Bundle.main.url(forResource: "grammar_data", withExtension: "json"),
              let raw = try? Data(contentsOf: url) else {
            print("GrammarDataService: grammar_data.json not found in bundle")
            return
        }

        do {
            let decoded = try JSONDecoder().decode(GrammarData.self, from: raw)
            self.data = decoded

            let byId = Dictionary(uniqueKeysWithValues: decoded.topics.map { ($0.id, $0) })
            var resolved: [Int: [GrammarTopic]] = [:]
            for phase in decoded.roadmap {
                var missing: [String] = []
                let topics = phase.topicIds.compactMap { id -> GrammarTopic? in
                    guard let topic = byId[id] else {
                        missing.append(id)
                        return nil
                    }
                    return topic
                }
                if !missing.isEmpty {
                    print("GrammarDataService: phase \(phase.phase) references missing topics: \(missing.joined(separator: ", "))")
                }
                resolved[phase.phase] = topics
            }
            self.topicsByPhase = resolved
        } catch {
            print("GrammarDataService: decode failed — \(error)")
        }
    }

    var allTopics: [GrammarTopic] { data?.topics ?? [] }
    var phases: [GrammarPhase] { data?.roadmap ?? [] }
    var ipa: IPAData? { data?.ipa }

    func topic(withId id: String) -> GrammarTopic? {
        data?.topics.first { $0.id == id }
    }

    /// Index in the full topic list, for Previous/Next navigation.
    func index(of topic: GrammarTopic) -> Int? {
        data?.topics.firstIndex { $0.id == topic.id }
    }
}

// MARK: - Exercise Answer Checking
/// Multi-answer aware comparison: case-insensitive, extra whitespace collapsed,
/// and `answer` variants split on "/" are each accepted (e.g. "can't / cannot").
enum GrammarAnswerChecker {
    static func normalize(_ raw: String) -> String {
        raw.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".'\""))
    }

    static func acceptedAnswers(for answer: String) -> [String] {
        var variants = answer
            .components(separatedBy: "/")
            .map { normalize($0) }
            .filter { !$0.isEmpty }
        let whole = normalize(answer)
        if !variants.contains(whole) { variants.append(whole) }
        return variants
    }

    static func check(userInput: String, answer: String) -> Bool {
        let input = normalize(userInput)
        guard !input.isEmpty else { return false }
        return acceptedAnswers(for: answer).contains(input)
    }
}
