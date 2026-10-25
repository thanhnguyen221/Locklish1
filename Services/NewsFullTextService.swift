import Foundation

// MARK: - Rich article content blocks
/// One renderable piece of the article, preserving the publisher's original
/// order: text paragraphs interleaved with their inline images.
enum NewsContentBlock: Codable, Equatable {
    case text(String)
    case image(url: String, caption: String?)
}

// MARK: - NewsFullTextService
/// Extracts the full article body from the publisher's page for in-app reading.
/// Strategy (no third-party dependency for the main path):
///   1. JSON-LD `articleBody` — highest quality, most news sites.
///   2. `<article>` block → ordered <p> + <img> blocks (scripts/styles stripped).
///   3. Whole-page ordered fallback (junk-filtered).
///   4. Reader-service fallback (r.jina.ai) for JS-rendered sites (VOA, NPR)
///      so articles still display in full instead of a stub summary.
/// Results are cached per article id for 30 days.
final class NewsFullTextService {
    static let shared = NewsFullTextService()

    struct FullArticle: Codable {
        let blocks: [NewsContentBlock]
        let heroImageURL: String?
        let fetchedAt: Date
        /// True when only partial text was available (paywall / JS page).
        let isPartial: Bool

        var wordCount: Int {
            blocks.reduce(0) { count, block in
                if case .text(let t) = block {
                    return count + t.components(separatedBy: .whitespaces).count
                }
                return count
            }
        }
    }

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 18
        config.timeoutIntervalForResource = 30
        return URLSession(configuration: config)
    }()

    private var cacheDir: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("news_fulltext", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private init() {}

    // MARK: - Cache

    func cached(articleId: String) -> FullArticle? {
        let url = cacheDir.appendingPathComponent("\(articleId).json")
        guard let data = try? Data(contentsOf: url),
              let article = try? JSONDecoder().decode(FullArticle.self, from: data) else { return nil }
        if Date().timeIntervalSince(article.fetchedAt) > 30 * 24 * 3600 {
            try? FileManager.default.removeItem(at: url)
            return nil
        }
        return article
    }

    private func save(_ article: FullArticle, articleId: String) {
        let url = cacheDir.appendingPathComponent("\(articleId).json")
        if let data = try? JSONEncoder().encode(article) {
            try? data.write(to: url, options: .atomic)
        }
    }

    // MARK: - Fetch & Extract

    func fullArticle(for item: NewsItem) async -> FullArticle? {
        if let cached = cached(articleId: item.id) { return cached }
        guard let url = URL(string: item.link) else { return nil }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html", forHTTPHeaderField: "Accept")

        if let (data, response) = try? await session.data(for: request),
           (response as? HTTPURLResponse)?.statusCode == 200,
           let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) {
            let article = Self.extract(fromHTML: html, fallbackImage: item.imageURL, articleTitle: item.title)
            if article.hasRealContent {
                save(article, articleId: item.id)
                return article
            }
        }

        // JS-rendered page (VOA, NPR…): reader service renders and returns markdown
        if let article = await fetchViaReader(original: url, item: item) {
            save(article, articleId: item.id)
            return article
        }
        return nil
    }

    /// Last-resort path for JavaScript-rendered publishers: r.jina.ai fetches
    /// the page, executes it, and returns clean markdown (text + images).
    private func fetchViaReader(original: URL, item: NewsItem) async -> FullArticle? {
        guard let readerURL = URL(string: "https://r.jina.ai/\(original.absoluteString)") else { return nil }
        var request = URLRequest(url: readerURL)
        request.timeoutInterval = 25

        guard let (data, response) = try? await session.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let markdown = String(data: data, encoding: .utf8) else { return nil }

        let blocks = Self.blocksFromMarkdown(markdown)
        guard !blocks.isEmpty else { return nil }

        return FullArticle(
            blocks: Array(blocks.prefix(90)),
            heroImageURL: item.imageURL,
            fetchedAt: Date(),
            isPartial: false
        )
    }

    // MARK: - HTML extraction

    static func extract(fromHTML html: String, fallbackImage: String?, articleTitle: String?) -> FullArticle {
        var blocks: [NewsContentBlock] = []
        var partial = false

        // 1) JSON-LD articleBody (plain text — richest single source)
        if let body = articleBodyFromJSONLD(html), body.count > 200 {
            blocks = splitParagraphs(body).map { .text($0) }
        }

        // 2/3) Ordered <p> + <img> from the article scope
        if blocks.isEmpty {
            let scope = firstMatch(html, pattern: #"<article\b[^>]*>([\s\S]*?)</article>"#) ?? html
            blocks = orderedBlocksFromHTML(scope)
            if blocks.isEmpty {
                partial = true
                blocks = orderedBlocksFromHTML(html)
            } else if blocks.textLength < 400 {
                partial = true
            }
        }

        // Drop the paragraph that just repeats the headline
        if let title = articleTitle {
            blocks.removeAll { block in
                if case .text(let t) = block {
                    return NewsStore.normalizedTitle(t) == NewsStore.normalizedTitle(title)
                }
                return false
            }
        }

        if blocks.isEmpty { partial = true }

        let hero = firstMatch(html, pattern: #"<meta[^>]+property="og:image"[^>]+content="([^"]+)""#)
            ?? firstMatch(html, pattern: #"<meta[^>]+content="([^"]+)"[^>]+property="og:image""#)
            ?? fallbackImage

        return FullArticle(
            blocks: Array(blocks.prefix(90)),
            heroImageURL: hero,
            fetchedAt: Date(),
            isPartial: partial
        )
    }

    /// Walks the HTML in document order, emitting text paragraphs and inline
    /// images exactly where the publisher placed them.
    private static func orderedBlocksFromHTML(_ html: String) -> [NewsContentBlock] {
        var cleaned = html
        cleaned = cleaned.replacingOccurrences(of: #"<script[\s\S]*?</script>"#, with: " ", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"<style[\s\S]*?</style>"#, with: " ", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"<(h[1-4])[^>]*>"#, with: "<p>", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"</(h[1-4])>"#, with: "</p>", options: .regularExpression)

        let combined = #"(?is)(<p\b[^>]*>[\s\S]*?</p>)|(<img\b[^>]*>)"#
        guard let regex = try? NSRegularExpression(pattern: combined) else { return [] }

        let ns = cleaned as NSString
        var out: [NewsContentBlock] = []

        for match in regex.matches(in: cleaned, range: NSRange(location: 0, length: ns.length)) {
            let piece = ns.substring(with: match.range)

            if piece.lowercased().hasPrefix("<img") {
                if let src = attr(of: piece, name: "src"), isContentImage(src) {
                    let alt = attr(of: piece, name: "alt")
                    let caption = (alt?.isEmpty == false) ? alt : nil
                    out.append(.image(url: src, caption: caption))
                }
            } else {
                let inner = firstMatch(piece, pattern: #"(?s)<p\b[^>]*>([\s\S]*?)</p>"#) ?? piece
                let text = NewsTextCleaner.cleanSummary(inner, limit: 3000)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard text.count >= 60 || (text.count >= 35 && text.hasSuffix(".")) else { continue }
                let lowered = text.lowercased()
                guard !junkPhrases.contains(where: { lowered.contains($0) }) else { continue }
                if case .text(let prev)? = out.last, prev == text { continue }
                out.append(.text(text))
            }
        }

        // Never start with an image (the hero covers that)
        if case .image = out.first, out.count > 1 {
            if case .image = out[0] { out.removeFirst() }
        }
        return out
    }

    /// Content-image URL filter: https only, skip logos/icons/avatars/svg/data.
    private static func isContentImage(_ url: String) -> Bool {
        guard url.hasPrefix("http"), !url.hasPrefix("data:") else { return false }
        let lowered = url.lowercased()
        let junk = ["logo", "icon", "avatar", "badge", "sprite", "favicon", ".svg", "placeholder", "1x1", "pixel", "tracking", "analytics"]
        return !junk.contains { lowered.contains($0) }
    }

    private static func attr(of tag: String, name: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: "\(name)\\s*=\\s*\"([^\"]*)\"") else { return nil }
        let ns = tag as NSString
        guard let m = regex.firstMatch(in: tag, range: NSRange(location: 0, length: ns.length)),
              m.numberOfRanges >= 2 else { return nil }
        return ns.substring(with: m.range(at: 1))
    }

    // MARK: - Markdown extraction (reader-service output)

    private static func blocksFromMarkdown(_ markdown: String) -> [NewsContentBlock] {
        var blocks: [NewsContentBlock] = []
        let lines = markdown.components(separatedBy: .newlines)

        var paragraphBuffer: [String] = []
        func flushParagraph() {
            let text = paragraphBuffer.joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            // Reader output has shorter lines than raw HTML — keep anything
            // sentence-like (≥ 45 chars ending with a period, or ≥ 60 chars).
            if text.count >= 60 || (text.count >= 45 && text.hasSuffix(".")) {
                let cleaned = stripMarkdown(text)
                let lowered = cleaned.lowercased()
                if !junkPhrases.contains(where: { lowered.contains($0) }) {
                    blocks.append(.text(cleaned))
                }
            }
            paragraphBuffer = []
        }

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Markdown image ![alt](url)
            if trimmed.hasPrefix("![") {
                flushParagraph()
                if let url = firstMatch(trimmed, pattern: #"!\[[^\]]*\]\(([^)\s]+)\)"#), isContentImage(url) {
                    let alt = firstMatch(trimmed, pattern: #"!\[([^\]]*)\]"#)
                    blocks.append(.image(url: url, caption: (alt?.isEmpty == false) ? alt : nil))
                }
                continue
            }

            // Headings become paragraph breaks
            if trimmed.hasPrefix("#") || trimmed.isEmpty {
                flushParagraph()
                continue
            }

            paragraphBuffer.append(trimmed)
        }
        flushParagraph()

        // Drop leading title duplicates (reader output starts with the page title)
        if case .text(let first)? = blocks.first, first.count < 160 {
            blocks.removeFirst()
        }
        return blocks
    }

    private static func stripMarkdown(_ s: String) -> String {
        var out = s
        out = out.replacingOccurrences(of: #"!\[[^\]]*\]\([^)]*\)"#, with: "", options: .regularExpression) // images
        out = out.replacingOccurrences(of: #"\[([^\]]+)\]\([^)]*\)"#, with: "$1", options: .regularExpression) // links keep text
        out = out.replacingOccurrences(of: #"[*_`>#]{1,3}"#, with: "", options: .regularExpression) // emphasis
        return NewsTextCleaner.decodeEntities(out)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - JSON-LD

    private static func articleBodyFromJSONLD(_ html: String) -> String? {
        let pattern = #"<script[^>]+type="application/ld\+json"[^>]*>([\s\S]*?)</script>"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = html as NSString
        for match in regex.matches(in: html, range: NSRange(location: 0, length: ns.length)) where match.numberOfRanges >= 2 {
            let block = ns.substring(with: match.range(at: 1))
            guard let data = block.data(using: .utf8),
                  let json = (try? JSONSerialization.jsonObject(with: data)) else { continue }
            if let body = deepestArticleBody(json), body.count > 200 {
                return NewsTextCleaner.decodeEntities(body)
            }
        }
        return nil
    }

    private static func deepestArticleBody(_ any: Any) -> String? {
        if let dict = any as? [String: Any] {
            if let body = dict["articleBody"] as? String { return body }
            if let graph = dict["@graph"] {
                for node in (graph as? [Any]) ?? [] {
                    if let found = deepestArticleBody(node) { return found }
                }
            }
            for value in dict.values {
                if let found = deepestArticleBody(value) { return found }
            }
        } else if let array = any as? [Any] {
            for node in array {
                if let found = deepestArticleBody(node) { return found }
            }
        }
        return nil
    }

    private static func splitParagraphs(_ body: String) -> [String] {
        body
            .replacingOccurrences(of: "\\n{2,}", with: "\u{1F}", options: .regularExpression)
            .replacingOccurrences(of: "\n", with: " ")
            .components(separatedBy: "\u{1F}")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 40 }
    }

    /// Promo/nav junk that shows up in `<p>` tags on tech blogs.
    private static let junkPhrases = [
        "subscribe", "register now", "sign up", "newsletter", "all rights reserved",
        "privacy policy", "terms of service", "click here", "follow us", "share this",
        "read more:", "advertisement", "sponsored", "get our", "download the app",
    ]

    private static func firstMatch(_ s: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: s, range: NSRange(s.startIndex..<s.endIndex, in: s)),
              match.numberOfRanges >= 2,
              let range = Range(match.range(at: 1), in: s) else { return nil }
        return String(s[range])
    }
}

extension [NewsContentBlock] {
    var textLength: Int {
        reduce(0) { total, block in
            if case .text(let t) = block { return total + t.count }
            return total
        }
    }
}

extension NewsFullTextService.FullArticle {
    var hasRealContent: Bool { blocks.textLength > 300 }
}
