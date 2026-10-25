import Foundation
import SwiftUI

// MARK: - GameCatalogService
/// Manages pre-compiled thematic vocabulary rounds for the gamified roadmap,
/// supports custom user image attachments (commercial customization), and persists progress.
@Observable
@MainActor
public final class GameCatalogService {
    public static let shared = GameCatalogService()

    // Bump this key whenever the bundled vocabulary.json changes so the app re-seeds.
    private let userDefaultsKey = "locklish_game_themed_rounds_v3"
    private let legacyUserDefaultsKey = "locklish_game_themed_rounds_v2"
    private let streakKey = "locklish_game_streak_v1"
    private let lastPlayDateKey = "locklish_game_last_play_date_v1"

    public var rounds: [GameThemeRound] = []
    public var currentStreak: Int = 1
    public var totalStars: Int = 0

    private init() {
        loadRounds()
        calculateStats()
    }

    // MARK: - Update Word Image (Commercial Customization)
    public func updateWordImage(roundId: Int, wordId: String, imageData: Data?) {
        guard let roundIndex = rounds.firstIndex(where: { $0.id == roundId }) else { return }
        guard let wordIndex = rounds[roundIndex].words.firstIndex(where: { $0.id == wordId }) else { return }

        rounds[roundIndex].words[wordIndex].imageData = imageData
        saveRounds()
    }

    // MARK: - Update Word Translation
    public func updateWordTranslation(roundId: Int, wordId: String, translation: String) {
        guard let roundIndex = rounds.firstIndex(where: { $0.id == roundId }) else { return }
        guard let wordIndex = rounds[roundIndex].words.firstIndex(where: { $0.id == wordId }) else { return }

        rounds[roundIndex].words[wordIndex].exampleTranslation = translation
        saveRounds()
    }

    // MARK: - Toggle Favorite
    public func toggleFavorite(roundId: Int, wordId: String) {
        guard let roundIndex = rounds.firstIndex(where: { $0.id == roundId }) else { return }
        guard let wordIndex = rounds[roundIndex].words.firstIndex(where: { $0.id == wordId }) else { return }

        rounds[roundIndex].words[wordIndex].isFavorite.toggle()
        saveRounds()
    }

    // MARK: - Record Word Mastery & Round Completion
    public func recordWordMastered(roundId: Int, wordId: String, isMastered: Bool) {
        guard let roundIndex = rounds.firstIndex(where: { $0.id == roundId }) else { return }
        guard let wordIndex = rounds[roundIndex].words.firstIndex(where: { $0.id == wordId }) else { return }

        rounds[roundIndex].words[wordIndex].isMastered = isMastered
        updateRoundStars(roundIndex: roundIndex)
        saveRounds()
        calculateStats()
    }

    public func completeRound(roundId: Int, scoreRatio: Double) {
        guard let roundIndex = rounds.firstIndex(where: { $0.id == roundId }) else { return }

        let stars: Int
        if scoreRatio >= 0.9 {
            stars = 3
        } else if scoreRatio >= 0.6 {
            stars = 2
        } else {
            stars = 1
        }

        if stars > rounds[roundIndex].starsEarned {
            rounds[roundIndex].starsEarned = stars
        }

        // Unlock next round
        let nextIndex = roundIndex + 1
        if nextIndex < rounds.count {
            rounds[nextIndex].isLocked = false
        }

        updateStreak()
        saveRounds()
        calculateStats()
    }

    private func updateRoundStars(roundIndex: Int) {
        let round = rounds[roundIndex]
        let masteredRatio = Double(round.masteredCount) / Double(max(round.words.count, 1))

        if masteredRatio >= 0.95 {
            rounds[roundIndex].starsEarned = max(rounds[roundIndex].starsEarned, 3)
        } else if masteredRatio >= 0.5 {
            rounds[roundIndex].starsEarned = max(rounds[roundIndex].starsEarned, 2)
        } else if masteredRatio > 0 {
            rounds[roundIndex].starsEarned = max(rounds[roundIndex].starsEarned, 1)
        }
    }

    private func calculateStats() {
        totalStars = rounds.reduce(0) { $0 + $1.starsEarned }
    }

    private func updateStreak() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let lastDate = UserDefaults.standard.object(forKey: lastPlayDateKey) as? Date ?? Date.distantPast
        let lastDay = calendar.startOfDay(for: lastDate)

        if today == lastDay { return }

        if let yesterday = calendar.date(byAdding: .day, value: -1, to: today), yesterday == lastDay {
            currentStreak += 1
        } else {
            currentStreak = 1
        }

        UserDefaults.standard.set(today, forKey: lastPlayDateKey)
        UserDefaults.standard.set(currentStreak, forKey: streakKey)
    }

    // MARK: - Persistence
    private func saveRounds() {
        if let encoded = try? JSONEncoder().encode(rounds) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }

    private func loadRounds() {
        currentStreak = max(1, UserDefaults.standard.integer(forKey: streakKey))

        let fresh = Self.makeDefaultCatalog()

        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let saved = try? JSONDecoder().decode([GameThemeRound].self, from: data),
           !saved.isEmpty {
            // Always merge fresh JSON data with user progress:
            // Newly added JSON files/words automatically appear, and user's earned stars/mastery are preserved!
            self.rounds = Self.mergedProgress(fresh: fresh, legacy: saved)
            saveRounds()
            return
        }

        // Fresh start
        self.rounds = fresh
        if !self.rounds.isEmpty {
            saveRounds()
        }
    }

    public func reloadCatalogFromSource(forceReset: Bool = false) {
        let fresh = Self.makeDefaultCatalog()
        guard !fresh.isEmpty else { return }
        if forceReset {
            self.rounds = fresh
        } else {
            self.rounds = Self.mergedProgress(fresh: fresh, legacy: self.rounds)
        }
        saveRounds()
        calculateStats()
    }

    private static func mergedProgress(fresh: [GameThemeRound], legacy: [GameThemeRound]) -> [GameThemeRound] {
        var merged = fresh
        for i in 0..<merged.count {
            if let oldRound = legacy.first(where: { $0.id == merged[i].id || ($0.level == merged[i].level && $0.title == merged[i].title) }) {
                merged[i].starsEarned = oldRound.starsEarned
                merged[i].isLocked = oldRound.isLocked

                for wIdx in 0..<merged[i].words.count {
                    if let oldWord = oldRound.words.first(where: { $0.word.caseInsensitiveCompare(merged[i].words[wIdx].word) == .orderedSame }) {
                        merged[i].words[wIdx].isMastered = oldWord.isMastered
                        merged[i].words[wIdx].isFavorite = oldWord.isFavorite
                        merged[i].words[wIdx].imageData = oldWord.imageData
                        if !oldWord.exampleTranslation.isEmpty {
                            merged[i].words[wIdx].exampleTranslation = oldWord.exampleTranslation
                        }
                    }
                }
            }
        }
        return merged
    }

    // MARK: - Multi-File Catalog Loader with Deduplication
    public static func makeDefaultCatalog() -> [GameThemeRound] {
        var seedRoundsList: [VocabSeedRound] = []
        var processedURLs = Set<String>()
        let decoder = JSONDecoder()

        // 1. Scan App Bundle for all .json files containing vocabulary
        if let bundleURLs = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: nil) {
            for url in bundleURLs {
                let name = url.lastPathComponent.lowercased()
                if (name.contains("vocab") || name.hasPrefix("a1") || name.hasPrefix("a2") || name.hasPrefix("b1") || name.hasPrefix("b2") || name.hasPrefix("c2")),
                   !processedURLs.contains(url.path),
                   let fileData = try? Data(contentsOf: url),
                   let decoded = try? decoder.decode([VocabSeedRound].self, from: fileData) {
                    processedURLs.insert(url.path)
                    seedRoundsList.append(contentsOf: decoded)
                    print("[GameCatalogService] ✅ Loaded \(decoded.count) rounds from bundle: \(url.lastPathComponent)")
                }
            }
        }

        // 2. Scan the app's Documents folder for side-loaded vocabulary JSON
        // (developer convenience). No hardcoded machine paths — portable.
        let devDirs: [String] = {
            #if DEBUG
            if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.path {
                return [docs]
            }
            return []
            #else
            return []
            #endif
        }()
        for dir in devDirs {
            if let files = try? FileManager.default.contentsOfDirectory(atPath: dir) {
                for file in files where file.hasSuffix(".json") {
                    let fullPath = (dir as NSString).appendingPathComponent(file)
                    let lower = file.lowercased()
                    if (lower.contains("vocab") || lower.hasPrefix("a1") || lower.hasPrefix("a2") || lower.hasPrefix("b1") || lower.hasPrefix("b2") || lower.hasPrefix("c2")),
                       !processedURLs.contains(fullPath),
                       let fileData = try? Data(contentsOf: URL(fileURLWithPath: fullPath)),
                       let decoded = try? decoder.decode([VocabSeedRound].self, from: fileData) {
                        processedURLs.insert(fullPath)
                        seedRoundsList.append(contentsOf: decoded)
                        print("[GameCatalogService] 📁 Loaded \(decoded.count) rounds from disk: \(file)")
                    }
                }
            }
        }

        // 3. No hardcoded absolute fallback paths — the bundle scan (step 1)
        // covers all shipped JSON; anything else is developer-side only.

        guard !seedRoundsList.isEmpty else {
            print("[GameCatalogService] ❌ No vocabulary rounds found across any JSON files.")
            return []
        }

        // 4. Group by (level, topic) and DEDUPLICATE Words
        struct RoundGroupKey: Hashable {
            let level: String
            let topic: String
        }

        var groupedRounds: [RoundGroupKey: (topicVi: String, topicEn: String, level: String, originalRound: Int, words: [GameWordItem])] = [:]
        var groupOrder: [RoundGroupKey] = []

        for seed in seedRoundsList {
            let assignedLevel: String
            if let lvl = seed.level?.trimmingCharacters(in: .whitespacesAndNewlines), !lvl.isEmpty {
                assignedLevel = lvl.uppercased()
            } else {
                switch seed.round {
                case 1...4: assignedLevel = "A1"
                case 5...8: assignedLevel = "A2"
                case 9...12: assignedLevel = "B1"
                case 13...16: assignedLevel = "B2"
                default: assignedLevel = "C2"
                }
            }

            let topicClean = seed.topicVi.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let key = RoundGroupKey(level: assignedLevel, topic: topicClean)

            if groupedRounds[key] == nil {
                groupedRounds[key] = (
                    topicVi: seed.topicVi,
                    topicEn: seed.topicEn,
                    level: assignedLevel,
                    originalRound: seed.round,
                    words: []
                )
                groupOrder.append(key)
            }

            // Word Deduplication: ignore case & whitespaces
            var existingWordSet = Set(groupedRounds[key]!.words.map { $0.word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
            for w in seed.words {
                let cleanWord = w.word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if !cleanWord.isEmpty && !existingWordSet.contains(cleanWord) {
                    existingWordSet.insert(cleanWord)
                    groupedRounds[key]!.words.append(
                        GameWordItem(
                            word: w.word,
                            meaning: w.meaning,
                            ipa: w.ipa,
                            viPhonetic: w.viPhonetic,
                            exampleSentence: w.exampleSentence,
                            exampleTranslation: w.exampleTranslation,
                            iconEmoji: w.iconEmoji
                        )
                    )
                }
            }
        }

        let accentColors = [
            "#3B82F6", "#EF4444", "#10B981", "#F59E0B", "#8B5CF6",
            "#EC4899", "#06B6D4", "#6366F1", "#F97316", "#E11D48",
            "#0D9488", "#2563EB", "#D97706", "#9333EA", "#0284C7",
            "#DC2626", "#059669", "#4F46E5", "#EA580C", "#7C3AED"
        ]
        let roundEmojis = [
            "🚗", "🍉", "🛋️", "🍰", "🐶", "👗", "🏖️", "📦", "🧠", "👨‍👩‍👧",
            "💼", "🎒", "😊", "🎨", "⏰", "🏥", "🛍️", "💻", "⚽", "🍽️"
        ]

        // 5. Construct Final Deduplicated Rounds
        var resultRounds: [GameThemeRound] = []
        var roundIdCounter = 1

        for key in groupOrder {
            guard let roundData = groupedRounds[key] else { continue }
            let idx = resultRounds.count
            let isFirstInThisLevel = !resultRounds.contains(where: { $0.level == roundData.level })

            resultRounds.append(
                GameThemeRound(
                    id: roundIdCounter,
                    title: "Vòng \(roundIdCounter) – \(roundData.topicVi)",
                    englishCategory: roundData.topicEn,
                    iconEmoji: roundEmojis[safe: idx % roundEmojis.count] ?? "📖",
                    accentColorHex: accentColors[safe: idx % accentColors.count] ?? "#4E73DF",
                    level: roundData.level,
                    words: roundData.words,
                    starsEarned: 0,
                    isLocked: !isFirstInThisLevel
                )
            )
            roundIdCounter += 1
        }

        print("[GameCatalogService] 🎯 Total assembled rounds: \(resultRounds.count), across levels: \(Set(resultRounds.map(\.level)))")
        return resultRounds
    }

    public func rounds(for level: String) -> [GameThemeRound] {
        rounds.filter { $0.level.uppercased() == level.uppercased() }
    }
}

// MARK: - Decodable DTOs for vocabulary.json

private struct VocabSeedRound: Decodable {
    let round: Int
    let topicVi: String
    let topicEn: String
    let level: String?
    let words: [VocabSeedWord]
}

private struct VocabSeedWord: Decodable {
    let word: String
    let meaning: String
    let ipa: String
    let viPhonetic: String
    let exampleSentence: String
    let exampleTranslation: String
    let iconEmoji: String
}

// MARK: - Safe array subscript
private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
