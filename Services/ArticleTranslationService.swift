import Foundation

// MARK: - ArticleTranslationService
/// Paragraph-level Vietnamese translations for news articles. Prefers one
/// Gemini batch request per article (context flows across paragraphs → most
/// accurate), falls back to the public Google endpoint per paragraph.
/// Translations are cached per article id so re-reading is instant & offline.
final class ArticleTranslationService {
    static let shared = ArticleTranslationService()

    /// blockIndex -> Vietnamese translation
    typealias Translations = [Int: String]

    private var cacheDir: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("news_translations", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private init() {}

    func cached(articleId: String) -> Translations {
        let url = cacheDir.appendingPathComponent("\(articleId).json")
        guard let data = try? Data(contentsOf: url),
              let map = try? JSONDecoder().decode(Translations.self, from: data) else { return [:] }
        return map
    }

    private func save(_ map: Translations, articleId: String) {
        let url = cacheDir.appendingPathComponent("\(articleId).json")
        if let data = try? JSONEncoder().encode(map) {
            try? data.write(to: url, options: .atomic)
        }
    }

    /// Returns the full translation map, filling in any missing paragraphs.
    /// Batches run **3 at a time** and `onUpdate` fires after every batch —
    /// the UI shows translations streaming in instead of waiting for the end.
    func translations(
        for articleId: String,
        blocks: [NewsContentBlock],
        onUpdate: (@MainActor (Translations) -> Void)? = nil
    ) async -> Translations {
        var map = cached(articleId: articleId)
        let pending: [Int] = blocks.indices.filter { index in
            if case .text(let t) = blocks[index] { return t.count >= 40 && map[index] == nil }
            return false
        }
        guard !pending.isEmpty else {
            if let onUpdate { await MainActor.run { onUpdate(map) } }
            return map
        }

        // Smaller batches (8) + 3 concurrent workers → first text lands fast
        let batchSize = 8
        var batches: [[Int]] = []
        for start in stride(from: 0, to: pending.count, by: batchSize) {
            batches.append(Array(pending[start..<min(start + batchSize, pending.count)]))
        }

        var iterator = batches.makeIterator()
        var inflight = 0
        let maxConcurrent = 3

        await withTaskGroup(of: Translations?.self) { group in
            func addNext() {
                if let batch = iterator.next() {
                    inflight += 1
                    group.addTask { [self] in
                        await translateBatch(batch, blocks: blocks)
                    }
                }
            }
            for _ in 0..<maxConcurrent { addNext() }

            while inflight > 0 {
                if let result = await group.next() {
                    inflight -= 1
                    for (key, value) in result ?? [:] { map[key] = value }
                    save(map, articleId: articleId)

                    if let onUpdate {
                        let snapshot = map
                        await MainActor.run { onUpdate(snapshot) }
                    }
                    addNext()
                }
            }
        }
        return map
    }

    /// One batch: prefer a single Gemini request (best quality), else the
    /// public Google endpoint with 6 parallel requests.
    private func translateBatch(_ indices: [Int], blocks: [NewsContentBlock]) async -> Translations? {
        let texts = indices.map { index -> String in
            if case .text(let t) = blocks[index] { return t }
            return ""
        }

        if let gemini = try? await GeminiService.shared.translateBatchToVietnamese(texts),
           gemini.count == indices.count {
            var result: Translations = [:]
            for (position, index) in indices.enumerated() where !gemini[position].isEmpty {
                result[index] = gemini[position]
            }
            if !result.isEmpty { return result }
        }

        // Fallback: Google endpoint, 6 concurrent
        var results = Array(repeating: "", count: indices.count)
        await withTaskGroup(of: (Int, String).self) { group in
            var iterator = indices.indices.makeIterator()
            var inflight = 0
            func addNext() {
                if let i = iterator.next() {
                    inflight += 1
                    group.addTask {
                        let vi = await WordInfoService.shared.translateTextDirectly(texts[i])
                        return (i, vi)
                    }
                }
            }
            for _ in 0..<6 { addNext() }
            while inflight > 0 {
                if let (i, vi) = await group.next() {
                    inflight -= 1
                    results[i] = vi
                    addNext()
                }
            }
        }

        var result: Translations = [:]
        for (position, index) in indices.enumerated() where !results[position].isEmpty {
            result[index] = results[position]
        }
        return result.isEmpty ? nil : result
    }
}
