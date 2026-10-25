import Foundation
import CryptoKit

// MARK: - News Models
struct NewsSource: Codable, Identifiable {
    let id: String
    let name: String
    let topic: String
    let feedUrl: String
    let levelHint: String
    let enabled: Bool
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case id, name, topic, enabled, notes
        case feedUrl = "feed_url"
        case levelHint = "level_hint"
    }
}

struct NewsSourcesFile: Codable {
    let meta: Meta
    let sources: [NewsSource]

    struct Meta: Codable {
        let version: String
        let topics: [String]
    }
}

/// One normalized article across all sources.
struct NewsItem: Codable, Identifiable, Equatable {
    /// Stable hash of the article link.
    let id: String
    let title: String
    /// Cleaned plain-text summary (≤ 300 chars — copyright: never full text).
    let summary: String
    let link: String
    let sourceId: String
    let sourceName: String
    let topic: String
    let publishedAt: Date?
    let imageURL: String?
    let levelHint: String
    /// Estimated CEFR label (A2/B1/B2/C1) — heuristic, not official.
    let estimatedLevel: String
    let fetchedAt: Date
}

// MARK: - NewsFeedParser
/// Minimal RSS 2.0 + Atom parser (Foundation XMLParser) extracting only the
/// copyright-safe fields: title, link, short description, date, thumbnail.
final class NewsFeedParser: NSObject, XMLParserDelegate {
    private var items: [ParsedItem] = []
    private var current: ParsedItem? = nil
    private var currentText: String = ""
    private var currentElement: String = ""
    private var inItem = false
    private var pendingImageURL: String? = nil
    private var isImageElement = false

    struct ParsedItem {
        var title: String = ""
        var link: String = ""
        var description: String = ""
        var pubDate: String = ""
        var imageURL: String?
    }

    static func parse(_ data: Data) -> [ParsedItem] {
        let parser = NewsFeedParser()
        let xml = XMLParser(data: data)
        xml.delegate = parser
        xml.parse()
        return parser.items
    }

    /// XMLParser reports qualified names like "media:thumbnail" when the feed
    /// uses prefixes — always compare the local part.
    private static func localName(_ name: String) -> String {
        (name.components(separatedBy: ":").last ?? name).lowercased()
    }

    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String] = [:]) {
        let element = Self.localName(name)
        currentElement = element
        currentText = ""

        if element == "item" || element == "entry" {
            inItem = true
            current = ParsedItem()
            return
        }

        guard inItem else { return }

        // Atom: <link href="..."/>
        if element == "link", let href = attributes["href"], current?.link.isEmpty != false {
            current?.link = href
        }

        // mrss: <media:thumbnail url=".."/> / <media:content type="image/..">
        if element == "thumbnail" {
            if let url = attributes["url"] { pendingImageURL = url }
        } else if element == "content", let url = attributes["url"], (attributes["type"] ?? "image").hasPrefix("image") {
            pendingImageURL = url
        }

        // RSS: <enclosure url="..." type="image/..."/>
        if element == "enclosure", let url = attributes["url"], (attributes["type"] ?? "image").hasPrefix("image") {
            pendingImageURL = url
        }

        isImageElement = (element == "thumbnail" || element == "content" || element == "enclosure")
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard inItem else { return }
        currentText += string
    }

    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
        let element = Self.localName(name)
        let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        if element == "item" || element == "entry" {
            if let item = current, !item.link.isEmpty || !item.title.isEmpty {
                items.append(item)
            }
            inItem = false
            current = nil
            return
        }

        guard inItem, var item = current else { return }

        switch currentElement {
        case "title":
            if item.title.isEmpty { item.title = text }
        case "link":
            // RSS link is element text
            if item.link.isEmpty, !text.isEmpty, !text.hasPrefix("http://www.w3.org") {
                item.link = text
            }
        case "description", "summary":
            if item.description.isEmpty { item.description = text }
        case "content":
            if !isImageElement, item.description.isEmpty, !text.isEmpty {
                item.description = text // Atom content fallback
            }
        case "pubdate", "published", "updated":
            if item.pubDate.isEmpty { item.pubDate = text }
        default:
            break
        }

        if pendingImageURL != nil, item.imageURL == nil {
            item.imageURL = pendingImageURL
            pendingImageURL = nil
        }
        current = item
    }
}

// MARK: - Text Cleaning & Normalization
enum NewsTextCleaner {
    /// Strips HTML, decodes entities, collapses whitespace; truncates at a word
    /// boundary to `limit` chars (default 300 — copyright-safe summary length).
    static func cleanSummary(_ raw: String, limit: Int = 300) -> String {
        var text = raw
        // Line breaks become spaces before tag stripping
        text = text.replacingOccurrences(of: "<br\\s*/?>", with: " ", options: [.regularExpression, .caseInsensitive])
        text = text.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        text = decodeEntities(text)
        text = text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard text.count > limit else { return text }
        let prefix = String(text.prefix(limit))
        if let lastSpace = prefix.lastIndex(of: " "), lastSpace > prefix.index(prefix.startIndex, offsetBy: limit - 40) {
            return String(prefix[..<lastSpace]) + "…"
        }
        return prefix + "…"
    }

    static func decodeEntities(_ s: String) -> String {
        var out = s
        let named = ["&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"", "&apos;": "'", "&#39;": "'", "&nbsp;": " ", "&hellip;": "…", "&mdash;": "—", "&ndash;": "–", "&rsquo;": "'", "&lsquo;": "'", "&rdquo;": "\"", "&ldquo;": "\""]
        for (ent, ch) in named {
            out = out.replacingOccurrences(of: ent, with: ch)
        }
        // Numeric entities &#123; and &#x1F600;
        if let regex = try? NSRegularExpression(pattern: "&#(x?[0-9A-Fa-f]+);") {
            let ns = out as NSString
            let matches = regex.matches(in: out, range: NSRange(location: 0, length: ns.length)).reversed()
            for m in matches where m.numberOfRanges >= 2 {
                let full = ns.substring(with: m.range)
                let digits = ns.substring(with: m.range(at: 1))
                let code = digits.hasPrefix("x") || digits.hasPrefix("X")
                    ? UInt32(digits.dropFirst(), radix: 16)
                    : UInt32(digits)
                if let code, let scalar = UnicodeScalar(code) {
                    out = out.replacingOccurrences(of: full, with: String(Character(scalar)))
                }
            }
        }
        return out
    }

    static func hashLink(_ link: String) -> String {
        SHA256.hash(data: Data(link.utf8)).compactMap { String(format: "%02x", $0) }.joined().prefix(16).description
    }

    static func parseDate(_ raw: String) -> Date? {
        let formats = [
            "EEE, dd MMM yyyy HH:mm:ss Z",
            "EEE, dd MMM yyyy HH:mm:ss zzz",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
        ]
        for format in formats {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = format
            if let date = formatter.date(from: raw) { return date }
        }
        return ISO8601DateFormatter().date(from: raw)
    }
}

// MARK: - Difficulty Estimator (heuristic, marked as estimate in UI)
enum NewsDifficultyEstimator {
    /// Blends source level_hint with simple text statistics (sentence length,
    /// word length, long-word ratio). Returns "A2" / "B1" / "B2" / "C1".
    static func estimate(title: String, summary: String, levelHint: String) -> String {
        let text = (title + ". " + summary)
        let words = text.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { $0.count > 0 }
        guard !words.isEmpty else { return "B1" }

        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?")).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let avgSentence = sentences.isEmpty ? 20.0 : Double(words.count) / Double(sentences.count)
        let avgWord = Double(words.reduce(0) { $0 + $1.count }) / Double(words.count)
        let longRatio = Double(words.filter { $0.count >= 8 }.count) / Double(words.count)

        var score = 0.0
        score += max(0, avgSentence - 12) * 0.35   // 12→0, 22→3.5
        score += max(0, avgWord - 4.2) * 2.2       // 4.2→0, 5.5→2.9
        score += max(0, longRatio - 0.08) * 12     // 8%→0, 25%→2

        // Level from statistics: 0-2 A2, 2-4 B1, 4-6 B2, >6 C1
        let statLevel: Int
        switch score {
        case ..<2: statLevel = 0
        case ..<4: statLevel = 1
        case ..<6: statLevel = 2
        default: statLevel = 3
        }

        // Blend with the source's own hint (range like "B2-C1" → midpoint)
        let hintLevel = levelFromHint(levelHint)
        let blended = min(max(Double(statLevel) * 0.6 + Double(hintLevel) * 0.4, 0), 3).rounded()
        return ["A2", "B1", "B2", "C1"][Int(blended)]
    }

    private static func levelFromHint(_ hint: String) -> Int {
        let order = ["A2": 0, "B1": 1, "B2": 2, "C1": 3]
        let found = hint.uppercased().components(separatedBy: CharacterSet(charactersIn: "-– "))
            .compactMap { order[$0] }
        guard !found.isEmpty else { return 1 }
        return found.reduce(0, +) / found.count
    }
}

// MARK: - Grammar Hint Detector (title-only heuristics → linked lessons)
enum GrammarHintDetector {
    struct Hint: Identifiable {
        let id: String      // grammar topic id
        let label: String
    }

    static func hints(forTitle title: String) -> [Hint] {
        var hints: [Hint] = []
        let t = title.lowercased()

        // Present perfect: has/have + V-ed/irregular common list
        if t.range(of: #"\b(has|have)\s+\w+(ed|en|wn|ne|d)\b"#, options: .regularExpression) != nil {
            hints.append(Hint(id: "g16", label: "Hiện tại hoàn thành"))
        }
        // Passive: be + V-ed
        if t.range(of: #"\b(is|are|was|were|been|being)\s+\w+ed\b"#, options: .regularExpression) != nil {
            hints.append(Hint(id: "g20", label: "Câu bị động"))
        }
        // Conditional: if ... (would/could/will)
        if t.range(of: #"\bif\b"#, options: .regularExpression) != nil {
            let second = t.range(of: #"\b(would|could)\b"#, options: .regularExpression) != nil
            hints.append(Hint(id: second ? "g19" : "g18", label: second ? "Điều kiện loại 2" : "Câu điều kiện"))
        }
        return hints
    }
}

// MARK: - NewsStore
/// Persists fetched items as one JSON file; purges entries older than
/// `retentionDays` (default 30) on every save/load.
final class NewsStore {
    static let shared = NewsStore()

    private var fileURL: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("news_items.json")
    }

    /// Internal setter keeps the test harness able to reset state.
    var items: [NewsItem] = []
    var retentionDays: Int = 30

    private init() {
        load()
    }

    func load() {
        guard let url = fileURL, let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([NewsItem].self, from: data) else { return }
        items = decoded
        purgeOld()
    }

    func save() {
        purgeOld()
        guard let url = fileURL, let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private func purgeOld() {
        let cutoff = Calendar.current.date(byAdding: .day, value: -retentionDays, to: Date()) ?? Date()
        items.removeAll { item in
            guard let published = item.publishedAt else { return false }
            return published < cutoff
        }
    }

    /// Merges fresh items: dedupes by id and by identical normalized title.
    /// Returns how many genuinely-new items were added.
    @discardableResult
    func merge(_ fresh: [NewsItem]) -> Int {
        let existingIDs = Set(items.map(\.id))
        let existingTitles = Set(items.map { NewsStore.normalizedTitle($0.title) })
        var added = 0
        for item in fresh {
            guard !existingIDs.contains(item.id),
                  !existingTitles.contains(NewsStore.normalizedTitle(item.title)) else { continue }
            items.append(item)
            added += 1
        }
        // Newest first
        items.sort { ($0.publishedAt ?? .distantPast) > ($1.publishedAt ?? .distantPast) }
        return added
    }

    static func normalizedTitle(_ title: String) -> String {
        title.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"[^\p{L}\p{N} ]"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }
}

// MARK: - NewsFetchService
/// Fetches every enabled source with timeout, ≤2 retries, a clear User-Agent,
/// and ETag/Last-Modified caching so unchanged feeds aren't re-downloaded.
/// One failing source never aborts the run — results are reported per source.
final class NewsFetchService {
    static let shared = NewsFetchService()

    struct SourceReport {
        let sourceId: String
        let succeeded: Bool
        let newItems: Int
        let notModified: Bool
        let error: String?
    }

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        return URLSession(configuration: config)
    }()

    private let etagKey = "locklish_news_etags"
    private let lastRunKey = "locklish_news_last_fetch"

    var lastFetchDate: Date? {
        UserDefaults.standard.object(forKey: lastRunKey) as? Date
    }

    private var etags: [String: String] {
        get { UserDefaults.standard.dictionary(forKey: etagKey) as? [String: String] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: etagKey) }
    }

    /// Test hook: when set, sources are read from this plain file URL instead
    /// of the app bundle (used by the macOS harness).
    static var sourcesFileOverride: URL? = nil

    func loadSources() -> [NewsSource] {
        let candidates: [Data?] = [
            Self.sourcesFileOverride.flatMap { try? Data(contentsOf: $0) },
            Bundle.main.url(forResource: "news_sources", withExtension: "json").flatMap { try? Data(contentsOf: $0) },
        ]
        for case let data? in candidates {
            if let file = try? JSONDecoder().decode(NewsSourcesFile.self, from: data) {
                return file.sources.filter(\.enabled)
            }
        }
        return []
    }

    /// Fetches all enabled sources concurrently. Call on a background task.
    func fetchAll(force: Bool = false) async -> (reports: [SourceReport], totalNew: Int) {
        let sources = loadSources()
        let currentEtags = etags

        var reports: [SourceReport] = []
        var totalNew = 0
        await withTaskGroup(of: (SourceReport, [NewsItem]).self) { group in
            for source in sources {
                group.addTask { [weak self] in
                    guard let self else {
                        return (SourceReport(sourceId: source.id, succeeded: false, newItems: 0, notModified: false, error: nil), [])
                    }
                    let (report, items) = await self.fetchReturningItems(source: source, cachedETag: force ? nil : currentEtags[source.id])
                    return (report, items)
                }
            }
            for await (report, items) in group {
                reports.append(report)
                if !items.isEmpty {
                    totalNew += NewsStore.shared.merge(items)
                }
            }
        }

        NewsStore.shared.save()
        UserDefaults.standard.set(Date(), forKey: lastRunKey)
        return (reports, totalNew)
    }

    private func fetchReturningItems(source: NewsSource, cachedETag: String?) async -> (SourceReport, [NewsItem]) {
        var request = URLRequest(url: URL(string: source.feedUrl)!)
        request.setValue("Locklish/1.0 (iOS English-learning app; contact: dev@locklish.app)", forHTTPHeaderField: "User-Agent")
        if let etag = cachedETag {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }

        var lastError: String? = nil
        for _ in 0..<3 { // 1 try + 2 retries
            do {
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    lastError = "Phản hồi không phải HTTP"; continue
                }
                if http.statusCode == 304 {
                    return (SourceReport(sourceId: source.id, succeeded: true, newItems: 0, notModified: true, error: nil), [])
                }
                guard http.statusCode == 200 else {
                    lastError = "HTTP \(http.statusCode)"; continue
                }

                let parsed = NewsFeedParser.parse(data)
                guard !parsed.isEmpty else {
                    lastError = "Feed không có item"; continue
                }

                // Store ETag for next time
                if let etag = http.value(forHTTPHeaderField: "ETag") {
                    var updated = etags
                    updated[source.id] = etag
                    etags = updated
                }

                let now = Date()
                let items = parsed.compactMap { raw -> NewsItem? in
                    let cleanTitle = NewsTextCleaner.decodeEntities(raw.title)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !cleanTitle.isEmpty else { return nil }
                    let link = raw.link.trimmingCharacters(in: .whitespaces)
                    guard !link.isEmpty, URL(string: link) != nil else { return nil }
                    let summary = NewsTextCleaner.cleanSummary(raw.description)
                    return NewsItem(
                        id: NewsTextCleaner.hashLink(link),
                        title: cleanTitle,
                        summary: summary,
                        link: link,
                        sourceId: source.id,
                        sourceName: source.name,
                        topic: source.topic,
                        publishedAt: NewsTextCleaner.parseDate(raw.pubDate),
                        imageURL: raw.imageURL,
                        levelHint: source.levelHint,
                        estimatedLevel: NewsDifficultyEstimator.estimate(title: cleanTitle, summary: summary, levelHint: source.levelHint),
                        fetchedAt: now
                    )
                }
                return (SourceReport(sourceId: source.id, succeeded: true, newItems: items.count, notModified: false, error: nil), items)
            } catch {
                lastError = error.localizedDescription
            }
        }
        return (SourceReport(sourceId: source.id, succeeded: false, newItems: 0, notModified: false, error: lastError), [])
    }
}
