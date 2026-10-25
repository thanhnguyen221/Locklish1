import Foundation

// MARK: - YouTubeSubtitleService
final class YouTubeSubtitleService {
    static let shared = YouTubeSubtitleService()

    private var cache: [String: YouTubeVideoInfo] = [:]
    private let urlSession: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 12.0
        config.timeoutIntervalForResource = 20.0
        self.urlSession = URLSession(configuration: config)
    }

    // MARK: - Pre-curated Popular English Learning Videos
    public struct SampleVideo: Identifiable {
        public let id: String
        public let title: String
        public let channel: String
        public let url: String
        public let level: String
    }

    /// Back-compat flat list (now generated from the catalog below).
    public var sampleVideos: [SampleVideo] {
        recommendedCatalog.flatMap(\.videos)
    }

    public struct RecommendationCategory: Identifiable {
        public let id: String
        public let title: String
        public let icon: String
        public let videos: [SampleVideo]
    }

    /// Verified-curated catalog (every id checked via YouTube oEmbed on 25/10).
    public let recommendedCatalog: [RecommendationCategory] = [
        RecommendationCategory(id: "inspire", title: "Truyền cảm hứng", icon: "sparkles", videos: [
            SampleVideo(id: "UF8uR6Z6KLc", title: "Steve Jobs' 2005 Stanford Commencement Address", channel: "Stanford", url: "https://www.youtube.com/watch?v=UF8uR6Z6KLc", level: "B2"),
            SampleVideo(id: "H14bBuluwB8", title: "Grit: The Power of Passion and Perseverance", channel: "TED", url: "https://www.youtube.com/watch?v=H14bBuluwB8", level: "B2"),
            SampleVideo(id: "UNP03fDSj1U", title: "Try Something New for 30 Days", channel: "TED-Ed", url: "https://www.youtube.com/watch?v=UNP03fDSj1U", level: "B1"),
            SampleVideo(id: "5MgBikgcWnY", title: "The First 20 Hours — How to Learn Anything", channel: "TEDx Talks", url: "https://www.youtube.com/watch?v=5MgBikgcWnY", level: "B2"),
        ]),
        RecommendationCategory(id: "psychology", title: "Tâm lý & Cuộc sống", icon: "brain.head.profile", videos: [
            SampleVideo(id: "arj7oStGLkU", title: "Inside the Mind of a Master Procrastinator", channel: "TED", url: "https://www.youtube.com/watch?v=arj7oStGLkU", level: "B1"),
            SampleVideo(id: "Ks-_Mh1QhMc", title: "Your Body Language May Shape Who You Are", channel: "TED", url: "https://www.youtube.com/watch?v=Ks-_Mh1QhMc", level: "B2"),
            SampleVideo(id: "iCvmsMzlF7o", title: "The Power of Vulnerability", channel: "TED", url: "https://www.youtube.com/watch?v=iCvmsMzlF7o", level: "C1"),
            SampleVideo(id: "8KkKuTCFvzI", title: "What Makes a Good Life? Lessons from the Longest Study", channel: "TED", url: "https://www.youtube.com/watch?v=8KkKuTCFvzI", level: "B2"),
            SampleVideo(id: "fLJsdqxnZb0", title: "The Happy Secret to Better Work", channel: "TED", url: "https://www.youtube.com/watch?v=fLJsdqxnZb0", level: "B2"),
        ]),
        RecommendationCategory(id: "speaking", title: "Kỹ năng giao tiếp", icon: "bubble.left.and.bubble.right", videos: [
            SampleVideo(id: "eIho2S0ZahI", title: "How to Speak So That People Want to Listen", channel: "TED", url: "https://www.youtube.com/watch?v=eIho2S0ZahI", level: "B2"),
            SampleVideo(id: "iG9CE55wbtY", title: "Do Schools Kill Creativity?", channel: "TED", url: "https://www.youtube.com/watch?v=iG9CE55wbtY", level: "B2"),
            SampleVideo(id: "8S0FDjFBj8o", title: "How to Sound Smart in Your TEDx Talk", channel: "TEDx Talks", url: "https://www.youtube.com/watch?v=8S0FDjFBj8o", level: "C1"),
            SampleVideo(id: "qp0HIF3SfI4", title: "How Great Leaders Inspire Action", channel: "TED", url: "https://www.youtube.com/watch?v=qp0HIF3SfI4", level: "B2"),
        ]),
        RecommendationCategory(id: "thinking", title: "Tư duy & Thế giới", icon: "lightbulb", videos: [
            SampleVideo(id: "6Af6b_wyiwI", title: "The Next Outbreak? We're Not Ready", channel: "TED", url: "https://www.youtube.com/watch?v=6Af6b_wyiwI", level: "B2"),
            SampleVideo(id: "ZQElzjCsl9o", title: "Math Is the Hidden Secret to Understanding the World", channel: "TED", url: "https://www.youtube.com/watch?v=ZQElzjCsl9o", level: "B2"),
            SampleVideo(id: "rrkrvAUbU9Y", title: "The Puzzle of Motivation", channel: "TED", url: "https://www.youtube.com/watch?v=rrkrvAUbU9Y", level: "B2"),
        ]),
        RecommendationCategory(id: "music", title: "Nghe nhạc thư giãn", icon: "music.note", videos: [
            SampleVideo(id: "YQHsXMglC9A", title: "Adele — Hello", channel: "Adele", url: "https://www.youtube.com/watch?v=YQHsXMglC9A", level: "B1"),
            SampleVideo(id: "JGwWNGJdvx8", title: "Ed Sheeran — Shape of You", channel: "Ed Sheeran", url: "https://www.youtube.com/watch?v=JGwWNGJdvx8", level: "B1"),
            SampleVideo(id: "2Vv-BfVoq4g", title: "Ed Sheeran — Perfect", channel: "Ed Sheeran", url: "https://www.youtube.com/watch?v=2Vv-BfVoq4g", level: "B1"),
            SampleVideo(id: "hT_nvWreIhg", title: "OneRepublic — Counting Stars", channel: "OneRepublic", url: "https://www.youtube.com/watch?v=hT_nvWreIhg", level: "B1"),
            SampleVideo(id: "CevxZvSJLk8", title: "Katy Perry — Roar", channel: "KatyPerryVEVO", url: "https://www.youtube.com/watch?v=CevxZvSJLk8", level: "B1"),
            SampleVideo(id: "nfs8NYg7yQM", title: "Charlie Puth — Attention", channel: "Charlie Puth", url: "https://www.youtube.com/watch?v=nfs8NYg7yQM", level: "B1"),
        ]),
    ]

    // MARK: - Video ID Extractor
    /// Extracts 11-character YouTube video ID from various URL formats
    public func extractVideoId(from input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count == 11 && !trimmed.contains("/") && !trimmed.contains("?") && !trimmed.contains(".") {
            return trimmed
        }

        // Regex patterns for youtube URLs
        let patterns = [
            #"(?:v=|\/v\/|youtu\.be\/|\/embed\/|\/shorts\/|\/watch\?v=|\&v=)([a-zA-Z0-9_-]{11})"#,
            #"^([a-zA-Z0-9_-]{11})$"#
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: trimmed, options: [], range: NSRange(location: 0, length: trimmed.utf16.count)) {
                if let range = Range(match.range(at: 1), in: trimmed) {
                    return String(trimmed[range])
                }
            }
        }

        // Fallback query item parsing
        if let url = URL(string: trimmed), let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            if let vItem = components.queryItems?.first(where: { $0.name == "v" })?.value, vItem.count == 11 {
                return vItem
            }
            if url.host?.contains("youtu.be") == true {
                let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                if path.count == 11 {
                    return path
                }
            }
        }

        return nil
    }

    // MARK: - Fetch Video Subtitles (English & Vietnamese)
    public func fetchSubtitles(for videoInput: String) async throws -> YouTubeVideoInfo {
        guard let videoId = extractVideoId(from: videoInput) else {
            throw SubtitleError.invalidVideoURL
        }

        if let cached = cache[videoId] {
            return cached
        }

        do {
            let videoInfo = try await fetchOnlineSubtitles(videoId: videoId)
            cache[videoId] = videoInfo
            persistToDisk(videoInfo)
            return videoInfo
        } catch {
            // Offline / throttled: a previously watched video still studies fine.
            if let disk = loadFromDisk(videoId) {
                cache[videoId] = disk
                return disk
            }
            throw error
        }
    }

    private func fetchOnlineSubtitles(videoId: String) async throws -> YouTubeVideoInfo {
        // 1. Fetch YouTube HTML page to locate caption tracks and metadata
        let (videoTitle, author, tracks) = try await fetchCaptionTracks(videoId: videoId)

        guard !tracks.isEmpty else {
            throw SubtitleError.noCaptionsAvailable
        }

        // 2. Select English track — human-made captions (better wording + timing)
        // always win over auto-generated ASR ones. A video with NO English track
        // fails honestly instead of returning subtitles in a random language.
        guard let englishTrack =
            tracks.first(where: { !$0.isAutoGenerated && ($0.languageCode == "en" || $0.languageCode.hasPrefix("en")) })
            ?? tracks.first(where: { $0.languageCode == "en" || $0.languageCode.hasPrefix("en") })
        else {
            throw SubtitleError.noEnglishTrack(availableLanguages: Array(Set(tracks.map(\.languageCode))).sorted())
        }

        // 3. Concurrently fetch English and Vietnamese cues
        async let englishCuesTask = fetchCues(from: englishTrack.baseUrl, targetLang: nil, fillsVietnameseField: false)

        // Vietnamese track: check if native Vietnamese track exists or use auto-translate timedtext
        let nativeViTrack = tracks.first(where: { !$0.isAutoGenerated && ($0.languageCode == "vi" || $0.languageCode.hasPrefix("vi")) })
            ?? tracks.first(where: { $0.languageCode == "vi" || $0.languageCode.hasPrefix("vi") })
        async let vietnameseCuesTask: [SubtitleCue] = {
            if let viTrack = nativeViTrack {
                return (try? await fetchCues(from: viTrack.baseUrl, targetLang: nil, fillsVietnameseField: true)) ?? []
            } else {
                // Request timedtext with &tlang=vi (YouTube official auto-translate)
                return (try? await fetchCues(from: englishTrack.baseUrl, targetLang: "vi", fillsVietnameseField: true)) ?? []
            }
        }()

        let (enCues, viCues) = await (try englishCuesTask, vietnameseCuesTask)

        guard !enCues.isEmpty else {
            throw SubtitleError.emptyTranscript
        }

        // 4. Pair English & Vietnamese cues by timestamp proximity
        var pairedCues: [SubtitleCue] = []
        for enCue in enCues {
            // Find closest matching Vietnamese cue within 2 seconds. Never inject the
            // Vietnamese track's English fallback text — leave it empty instead so the
            // translation pass fills it with a real Vietnamese sentence.
            var matchedVi = ""
            if !viCues.isEmpty {
                let match = viCues.min(by: { abs($0.startTime - enCue.startTime) < abs($1.startTime - enCue.startTime) })
                if let match, abs(match.startTime - enCue.startTime) <= 2.0 {
                    let vi = match.textVi.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !vi.isEmpty { matchedVi = vi }
                }
            }

            pairedCues.append(SubtitleCue(
                startTime: enCue.startTime,
                duration: enCue.duration,
                textEn: enCue.textEn,
                textVi: matchedVi,
                words: enCue.words
            ))
        }

        // 5. Fallback translate for cues that didn't get Vietnamese subtitles
        pairedCues = await fillMissingVietnameseTranslations(cues: pairedCues)

        return YouTubeVideoInfo(
            videoId: videoId,
            title: videoTitle.isEmpty ? "Video học tiếng Anh" : videoTitle,
            author: author.isEmpty ? "YouTube" : author,
            cues: pairedCues,
            availableTracks: tracks
        )
    }

    // MARK: - Disk Cache (offline re-watch)
    private var diskCacheDirectory: URL? {
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        let dir = documents.appendingPathComponent("SubtitleCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func persistToDisk(_ info: YouTubeVideoInfo) {
        guard let dir = diskCacheDirectory,
              let data = try? JSONEncoder().encode(info) else { return }
        try? data.write(to: dir.appendingPathComponent("\(info.videoId).json"), options: .atomic)
    }

    private func loadFromDisk(_ videoId: String) -> YouTubeVideoInfo? {
        guard let dir = diskCacheDirectory,
              let data = try? Data(contentsOf: dir.appendingPathComponent("\(videoId).json")) else { return nil }
        return try? JSONDecoder().decode(YouTubeVideoInfo.self, from: data)
    }

    // MARK: - URL Normalizer
    private func normalizeUrl(_ rawUrl: String) -> String {
        var url = rawUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        if url.hasPrefix("//") {
            url = "https:" + url
        } else if url.hasPrefix("/") {
            url = "https://www.youtube.com" + url
        } else if !url.hasPrefix("http://") && !url.hasPrefix("https://") {
            url = "https://www.youtube.com/" + url
        }
        return url
    }

    // MARK: - Fetch Caption Tracks from InnerTube Android API (primary) or HTML (fallback)
    // The ANDROID InnerTube client (v20.10.38) returns timedtext baseUrls WITHOUT exp=xpe,
    // which means they respond with actual content. HTML scraping returns exp=xpe URLs that
    // yield empty 200 OK bodies due to YouTube's Proof-of-Origin-Token requirement.
    private func fetchCaptionTracks(videoId: String) async throws -> (title: String, author: String, tracks: [YouTubeCaptionTrackInfo]) {

        // --- Strategy 1: Android InnerTube (primary, bypasses exp=xpe) ---
        let (itTitle, itAuthor, itTracks) = await fetchTracksViaInnertube(videoId: videoId)
        if !itTracks.isEmpty {
            return (itTitle, itAuthor, itTracks)
        }

        // --- Strategy 2: HTML scrape fallback ---
        guard let url = URL(string: "https://www.youtube.com/watch?v=\(videoId)&hl=en") else {
            throw SubtitleError.invalidVideoURL
        }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")

        var title = ""
        var author = ""
        var tracks: [YouTubeCaptionTrackInfo] = []

        if let (data, response) = try? await urlSession.data(for: request),
           (response as? HTTPURLResponse)?.statusCode == 200,
           let html = String(data: data, encoding: .utf8) {

            // Extract Title
            if let titleRange = html.range(of: "<title>"),
               let endTitleRange = html.range(of: "</title>", range: titleRange.upperBound..<html.endIndex) {
                let rawTitle = String(html[titleRange.upperBound..<endTitleRange.lowerBound])
                title = rawTitle.replacingOccurrences(of: " - YouTube", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                title = unescapeHtml(title)
            }

            // Extract Author
            if let authorMatch = html.range(of: "\"author\":\"") {
                let remainder = html[authorMatch.upperBound...]
                if let quoteEnd = remainder.firstIndex(of: "\"") {
                    author = String(remainder[..<quoteEnd])
                }
            }

            // Look for captionTracks JSON inside playerResponse
            let marker = "\"captionTracks\":"
            if let markerRange = html.range(of: marker) {
                let sub = html[markerRange.upperBound...]
                if let openBracket = sub.firstIndex(of: "[") {
                    var depth = 0
                    var endIndex: String.Index? = nil
                    for idx in sub[openBracket...].indices {
                        let char = sub[idx]
                        if char == "[" { depth += 1 }
                        else if char == "]" {
                            depth -= 1
                            if depth == 0 {
                                endIndex = sub.index(after: idx)
                                break
                            }
                        }
                    }

                    if let endIdx = endIndex {
                        let jsonString = String(sub[openBracket..<endIdx])
                        if let jsonData = jsonString.data(using: .utf8),
                           let parsedArray = try? JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] {
                            for item in parsedArray {
                                guard let rawBaseUrl = item["baseUrl"] as? String else { continue }
                                let langCode = item["languageCode"] as? String ?? "en"
                                let isTranslatable = item["isTranslatable"] as? Bool ?? true

                                var trackName = langCode
                                if let nameDict = item["name"] as? [String: Any] {
                                    if let simpleText = nameDict["simpleText"] as? String {
                                        trackName = simpleText
                                    } else if let runs = nameDict["runs"] as? [[String: Any]],
                                              let firstRun = runs.first,
                                              let text = firstRun["text"] as? String {
                                        trackName = text
                                    }
                                }

                                tracks.append(YouTubeCaptionTrackInfo(
                                    baseUrl: normalizeUrl(rawBaseUrl),
                                    name: trackName,
                                    languageCode: langCode,
                                    isTranslatable: isTranslatable,
                                    kind: item["kind"] as? String
                                ))
                            }
                        }
                    }
                }
            }
        }

        guard !tracks.isEmpty else {
            throw SubtitleError.noCaptionsAvailable
        }

        return (title, author, tracks)
    }

    // MARK: - Innertube Player API (Android primary, iOS fallback)
    // ANDROID client 20.10.38 returns timedtext baseUrls without exp=xpe.
    // When YouTube throttles that client, the IOS client is the next-best
    // source with the same caption payload.
    private let innertubeApiKey = "AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8"

    private func fetchTracksViaInnertube(videoId: String) async -> (title: String, author: String, tracks: [YouTubeCaptionTrackInfo]) {
        // Ordered by success rate: Android first, iOS as a live fallback.
        let clients: [(name: String, version: String, userAgent: String)] = [
            ("ANDROID", "20.10.38", "Mozilla/5.0 (Linux; Android 14)"),
            ("IOS", "20.10.4", "com.google.ios.youtube/20.10.4 (iPhone16,2; U; CPU iOS 18_1_0 like Mac OS X)")
        ]

        for client in clients {
            let result = await fetchTracksViaInnertube(
                videoId: videoId,
                clientName: client.name,
                clientVersion: client.version,
                userAgent: client.userAgent
            )
            if !result.tracks.isEmpty {
                return result
            }
        }
        return ("", "", [])
    }

    private func fetchTracksViaInnertube(
        videoId: String,
        clientName: String,
        clientVersion: String,
        userAgent: String
    ) async -> (title: String, author: String, tracks: [YouTubeCaptionTrackInfo]) {
        guard let url = URL(string: "https://www.youtube.com/youtubei/v1/player?key=\(innertubeApiKey)") else {
            return ("", "", [])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        let body: [String: Any] = [
            "context": [
                "client": [
                    "clientName": clientName,
                    "clientVersion": clientVersion,
                    "hl": "en"
                ]
            ],
            "videoId": videoId
        ]

        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else {
            return ("", "", [])
        }
        request.httpBody = httpBody

        guard let (data, response) = try? await urlSession.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return ("", "", [])
        }

        let videoDetails = json["videoDetails"] as? [String: Any] ?? [:]
        let title = videoDetails["title"] as? String ?? ""
        let author = videoDetails["author"] as? String ?? ""

        var tracks: [YouTubeCaptionTrackInfo] = []
        if let captions = json["captions"] as? [String: Any],
           let tracklist = captions["playerCaptionsTracklistRenderer"] as? [String: Any],
           let captionTracks = tracklist["captionTracks"] as? [[String: Any]] {
            for item in captionTracks {
                guard let rawBaseUrl = item["baseUrl"] as? String else { continue }
                let langCode = item["languageCode"] as? String ?? "en"
                let isTranslatable = item["isTranslatable"] as? Bool ?? true
                var trackName = langCode
                if let nameDict = item["name"] as? [String: Any],
                   let runs = nameDict["runs"] as? [[String: Any]],
                   let first = runs.first,
                   let text = first["text"] as? String {
                    trackName = text
                }
                tracks.append(YouTubeCaptionTrackInfo(
                    baseUrl: normalizeUrl(rawBaseUrl),
                    name: trackName,
                    languageCode: langCode,
                    isTranslatable: isTranslatable,
                    kind: item["kind"] as? String
                ))
            }
        }

        return (title, author, tracks)
    }

    // MARK: - Download and Parse TimedText Cues
    // Prefer JSON3 because its `segs` include the individual timing offsets
    // that are required for word-level tracking. XML and legacy timedtext are
    // retained as fallbacks for videos where JSON3 is unavailable.
    private func fetchCues(from baseUrl: String, targetLang: String?, fillsVietnameseField: Bool) async throws -> [SubtitleCue] {
        var urlString = normalizeUrl(baseUrl)

        // Append tlang for translation if requested
        if let tlang = targetLang, !urlString.contains("tlang=") {
            let sep = urlString.contains("?") ? "&" : "?"
            urlString += "\(sep)tlang=\(tlang)"
        }

        let json3URL = settingQueryItem(named: "fmt", to: "json3", in: urlString)
        // Avoid fetching the same endpoint twice when its base URL already
        // requests JSON3.
        let candidates = [json3URL, urlString].reduce(into: [String]()) { result, value in
            if !result.contains(value) { result.append(value) }
        }

        for candidate in candidates {
            guard let url = URL(string: candidate) else { continue }

            var request = URLRequest(url: url)
            request.setValue("Mozilla/5.0 (Linux; Android 14)", forHTTPHeaderField: "User-Agent")
            request.setValue("https://www.youtube.com", forHTTPHeaderField: "Referer")

            guard let (data, response) = try? await urlSession.data(for: request),
                  (response as? HTTPURLResponse)?.statusCode == 200,
                  !data.isEmpty
            else { continue }

            let cues = parseTimedText(data, isTargetLang: fillsVietnameseField)
            if !cues.isEmpty { return cues }
        }

        return []
    }

    /// Replaces an existing query parameter instead of adding a second `fmt`,
    /// because YouTube otherwise honours the original non-word-timed format.
    private func settingQueryItem(named name: String, to value: String, in rawURL: String) -> String {
        guard var components = URLComponents(string: rawURL) else { return rawURL }
        var items = components.queryItems ?? []
        items.removeAll { $0.name == name }
        items.append(URLQueryItem(name: name, value: value))
        components.queryItems = items
        return components.url?.absoluteString ?? rawURL
    }

    private func parseTimedText(_ data: Data, isTargetLang: Bool) -> [SubtitleCue] {

        // 1. Try XML format 3 — <p t="ms" d="ms">...</p> (Android InnerTube response)
        if let xmlString = String(data: data, encoding: .utf8), xmlString.contains("<p t=") {
            let cues = parseXmlFormat3(xmlString, isTargetLang: isTargetLang)
            if !cues.isEmpty { return cues }
        }

        // 2. Try JSON3 — {events: [{tStartMs, dDurationMs, segs: [{utf8, tOffsetMs}]}]}
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let events = json["events"] as? [[String: Any]] {
            var cues: [SubtitleCue] = []
            for ev in events {
                guard let tStartMs = (ev["tStartMs"] as? NSNumber)?.doubleValue else { continue }
                let dDurationMs = (ev["dDurationMs"] as? NSNumber)?.doubleValue ?? 2000.0
                let segs = ev["segs"] as? [[String: Any]] ?? []

                var text = ""
                var parts: [(text: String, offset: Double?)] = []
                for s in segs {
                    if let piece = s["utf8"] as? String {
                        text += piece
                        parts.append((piece, (s["tOffsetMs"] as? NSNumber)?.doubleValue))
                    }
                }

                let cleanedText = cleanSubtitleText(text)
                if !cleanedText.isEmpty {
                    let words = buildWordTimings(
                        parts: parts,
                        windowStart: tStartMs / 1000.0,
                        windowEnd: (tStartMs + dDurationMs) / 1000.0,
                        cleanedText: cleanedText
                    )
                    cues.append(SubtitleCue(
                        startTime: tStartMs / 1000.0,
                        // Do not stretch short caption windows to one second:
                        // that would highlight a sentence after it has ended.
                        duration: max(0.05, dDurationMs / 1000.0),
                        textEn: cleanedText,
                        textVi: isTargetLang ? cleanedText : "",
                        words: words
                    ))
                }
            }
            if !cues.isEmpty { return cues }
        }

        // 3. Fallback: Legacy XML timedtext — <text start="s" dur="s">...</text>
        if let xmlString = String(data: data, encoding: .utf8) {
            return parseXmlTimedText(xmlString, isTargetLang: isTargetLang)
        }

        return []
    }

    // MARK: - XML Format 3 Parser (Android InnerTube timedtext)
    // Parses <p t="startMs" d="durationMs">inner html</p> with nested <s t="offsetMs">
    // word segments carrying YouTube's own per-word timings.
    private func parseXmlFormat3(_ xml: String, isTargetLang: Bool) -> [SubtitleCue] {
        var cues: [SubtitleCue] = []
        // Matches both <p t="1000" d="2000"> and <p t="1000" d="2000" w="1" a="1">
        let pPattern = #"<p\s+t="(\d+)"(?:\s+d="(\d+)")?[^>]*>(.*?)</p>"#
        let sPattern = #"<s(?:\s[^>]*)?>([^<]*)</s>"#
        let tAttrPattern = #"\st="(\d+)""#

        guard let regex = try? NSRegularExpression(pattern: pPattern, options: .dotMatchesLineSeparators),
              let sRegex = try? NSRegularExpression(pattern: sPattern, options: .dotMatchesLineSeparators),
              let tAttrRegex = try? NSRegularExpression(pattern: tAttrPattern, options: []) else {
            return []
        }

        let ns = xml as NSString
        let matches = regex.matches(in: xml, options: [], range: NSRange(location: 0, length: ns.length))

        for match in matches {
            guard match.numberOfRanges >= 4 else { continue }
            let tStr = ns.substring(with: match.range(at: 1))
            let dStr = match.range(at: 2).location != NSNotFound ? ns.substring(with: match.range(at: 2)) : "2000"
            let rawInner = ns.substring(with: match.range(at: 3))

            let start = (Double(tStr) ?? 0.0) / 1000.0
            let dur = max(0.05, (Double(dStr) ?? 2000.0) / 1000.0)

            // Walk the <s> segments, keeping each one's text and time offset.
            var parts: [(text: String, offset: Double?)] = []
            var lastEnd = rawInner.startIndex
            let innerNS = rawInner as NSString
            let sMatches = sRegex.matches(in: rawInner, options: [], range: NSRange(location: 0, length: innerNS.length))
            for sMatch in sMatches {
                guard let segRange = Range(sMatch.range, in: rawInner) else { continue }

                // Plain text before this segment (usually a space) flows with it.
                if lastEnd < segRange.lowerBound {
                    let gap = String(rawInner[lastEnd..<segRange.lowerBound])
                    if !gap.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        parts.append((gap, nil))
                    }
                }

                var offset: Double? = nil
                if let tMatch = tAttrRegex.firstMatch(in: rawInner, options: [], range: sMatch.range),
                   let tRange = Range(tMatch.range(at: 1), in: rawInner) {
                    offset = (Double(rawInner[tRange]) ?? 0) / 1000.0
                }
                if let textRange = Range(sMatch.range(at: 1), in: rawInner) {
                    parts.append((String(rawInner[textRange]), offset))
                }
                lastEnd = segRange.upperBound
            }

            let stripped = tagRegexlessStrip(rawInner)
            let cleaned = cleanSubtitleText(stripped)
            guard !cleaned.isEmpty else { continue }

            let words = buildWordTimings(
                parts: parts,
                windowStart: start,
                windowEnd: start + dur,
                cleanedText: cleaned
            )

            cues.append(SubtitleCue(
                startTime: start,
                duration: dur,
                textEn: isTargetLang ? "" : cleaned,
                textVi: isTargetLang ? cleaned : "",
                words: words
            ))
        }

        return cues
    }

    /// Strips all tags from a timedtext fragment.
    private func tagRegexlessStrip(_ html: String) -> String {
        // A line break must become a space. Removing it outright merges the
        // final word of one caption line with the first word of the next one.
        let withSpaces = html.replacingOccurrences(
            of: #"<br\s*/?>"#,
            with: " ",
            options: [.regularExpression, .caseInsensitive]
        )
        guard let regex = try? NSRegularExpression(pattern: "<[^>]+>", options: []) else { return html }
        return regex.stringByReplacingMatches(
            in: withSpaces, options: [],
            range: NSRange(location: 0, length: withSpaces.utf16.count),
            withTemplate: ""
        )
    }

    // MARK: - Word Timing Builder
    /// Converts YouTube's per-word segments into absolute word timings.
    /// Segments without an explicit offset are interpolated between their
    /// timed neighbours; each segment's span is then split across its words
    /// proportionally to character count. Returns [] when the result doesn't
    /// line up with the cleaned cue text (callers fall back to cue-level
    /// highlighting instead of attributing an incorrect word time).
    private func buildWordTimings(
        parts: [(text: String, offset: Double?)],
        windowStart: Double,
        windowEnd: Double,
        cleanedText: String
    ) -> [SubtitleWord] {
        guard !parts.isEmpty, windowEnd > windowStart else { return [] }

        // Resolve offsets: known offsets are window-relative. For a consecutive
        // run without a timestamp, interpolate only inside its two surrounding
        // anchors. The old running-midpoint approach gave every later segment
        // the same end anchor and drifted words farther and farther off time.
        var starts: [Double?] = parts.map { $0.offset }
        let windowDuration = windowEnd - windowStart
        var lastKnown = 0.0
        for i in parts.indices {
            if let o = starts[i] {
                starts[i] = min(max(lastKnown, o), windowDuration)
                lastKnown = starts[i]!
            }
        }

        var index = 0
        while index < starts.count {
            guard starts[index] == nil else {
                index += 1
                continue
            }

            let gapStart = index
            while index < starts.count, starts[index] == nil {
                index += 1
            }
            let gapEnd = index // first timed item after the gap, if any
            let leftTime = gapStart > 0 ? (starts[gapStart - 1] ?? 0) : 0
            let rightTime = gapEnd < starts.count ? (starts[gapEnd] ?? windowDuration) : windowDuration
            let gapCount = gapEnd - gapStart

            for offset in 0..<gapCount {
                starts[gapStart + offset] = leftTime + (rightTime - leftTime)
                    * Double(offset + 1) / Double(gapCount + 1)
            }
        }

        // Tokenize each part and split its [start, end) span across words.
        var rawWords: [(text: String, start: Double, end: Double)] = []
        for (i, part) in parts.enumerated() {
            let text = cleanSubtitleText(part.text)
            let tokens = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
            guard !tokens.isEmpty else { continue }
            let segStart = windowStart + (starts[i] ?? 0)
            let segEnd = i + 1 < parts.count
                ? windowStart + (starts[i + 1] ?? starts[i] ?? 0)
                : windowEnd
            let weights = tokens.map { max(Double($0.count), 1.0) }
            let total = weights.reduce(0, +)
            var run = 0.0
            for (j, token) in tokens.enumerated() {
                let wStart = segStart + (segEnd - segStart) * run / total
                run += weights[j]
                let wEnd = segStart + (segEnd - segStart) * run / total
                rawWords.append((token, wStart, wEnd))
            }
        }

        // Only hand back timings that align 1:1 with the words shown on screen.
        let displayTokens = cleanedText.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        guard rawWords.count == displayTokens.count,
              !rawWords.isEmpty,
              zip(rawWords.map(\.text), displayTokens).allSatisfy({
                  normalizedTimingToken($0.0) == normalizedTimingToken($0.1)
              })
        else { return [] }
        return rawWords.map { SubtitleWord(text: $0.text, startTime: $0.start, endTime: max($0.end, $0.start + 0.05)) }
    }

    /// Compare timing segments to visible subtitle tokens without punctuation
    /// or Unicode normalization producing false mismatches.
    private func normalizedTimingToken(_ token: String) -> String {
        unescapeHtml(token)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .trimmingCharacters(in: .punctuationCharacters.union(.symbols))
    }

    // MARK: - XML TimedText Parser Fallback
    private func parseXmlTimedText(_ xml: String, isTargetLang: Bool) -> [SubtitleCue] {
        var cues: [SubtitleCue] = []
        // Pattern: <text start="1.23" dur="4.56">Hello world</text>
        let pattern = #"<text\s+start=\"([0-9.]+)\"(?:\s+dur=\"([0-9.]+)\")?[^>]*>(.*?)</text>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators) else {
            return []
        }

        let nsString = xml as NSString
        let matches = regex.matches(in: xml, options: [], range: NSRange(location: 0, length: nsString.length))

        for match in matches {
            guard match.numberOfRanges >= 4 else { continue }
            let startStr = nsString.substring(with: match.range(at: 1))
            let durStr = match.range(at: 2).location != NSNotFound ? nsString.substring(with: match.range(at: 2)) : "2.0"
            let textRaw = nsString.substring(with: match.range(at: 3))

            let start = Double(startStr) ?? 0.0
            let dur = Double(durStr) ?? 2.0
            let cleaned = cleanSubtitleText(textRaw)

            if !cleaned.isEmpty {
                cues.append(SubtitleCue(
                    startTime: start,
                    duration: dur,
                    textEn: cleaned,
                    textVi: isTargetLang ? cleaned : ""
                ))
            }
        }

        return cues
    }

    // MARK: - Cleaning & Unescaping Subtitle Text
    private func cleanSubtitleText(_ input: String) -> String {
        var text = tagRegexlessStrip(input)
        text = text.replacingOccurrences(of: "\n", with: " ")
        text = text.replacingOccurrences(of: "\r", with: " ")
        text = unescapeHtml(text)

        // Remove music cues like [Music], [Applause]
        let bracketRegex = try? NSRegularExpression(pattern: #"\[[A-Za-z\s]+\]"#, options: [])
        if let regex = bracketRegex {
            text = regex.stringByReplacingMatches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count), withTemplate: "")
        }

        text = text.replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func unescapeHtml(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&#10;", with: " ")
            .replacingOccurrences(of: "&#xa;", with: " ")
    }

    // MARK: - Translation Fallback for Missing Lines
    /// Translates EVERY cue that ended up without Vietnamese text, in sequential
    /// batches so the public translate endpoint isn't hammered. Partial transcripts
    /// (some lines translated, some empty) are unacceptable for study material.
    private func fillMissingVietnameseTranslations(cues: [SubtitleCue]) async -> [SubtitleCue] {
        var updated = cues
        let missingIndices = updated.indices.filter {
            updated[$0].textVi.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        guard !missingIndices.isEmpty else { return updated }

        let batchSize = 8
        for batchStart in stride(from: 0, to: missingIndices.count, by: batchSize) {
            let batch = Array(missingIndices[batchStart..<min(batchStart + batchSize, missingIndices.count)])

            await withTaskGroup(of: (Int, String).self) { group in
                for i in batch {
                    let en = updated[i].textEn
                    group.addTask {
                        let vi = await WordInfoService.shared.translateTextDirectly(en)
                        return (i, vi)
                    }
                }

                for await (idx, vi) in group {
                    if !vi.isEmpty {
                        updated[idx].textVi = vi
                    }
                }
            }
        }

        return updated
    }

    // MARK: - Subtitle Error
    public enum SubtitleError: LocalizedError {
        case invalidVideoURL
        case noCaptionsAvailable
        case noEnglishTrack(availableLanguages: [String])
        case emptyTranscript
        case networkFailed

        public var errorDescription: String? {
            switch self {
            case .invalidVideoURL:
                return "Đường dẫn video YouTube không hợp lệ. Vui lòng dán link video (ví dụ: https://www.youtube.com/watch?v=... hoặc https://youtu.be/...)."
            case .noCaptionsAvailable:
                return "Video này hiện không có phụ đề (CC) trên YouTube. Bạn vui lòng thử một video khác có phụ đề tiếng Anh nhé!"
            case .noEnglishTrack(let languages):
                return "Video này không có phụ đề tiếng Anh — chỉ có: \(languages.joined(separator: ", ")). Hãy thử video khác có phụ đề tiếng Anh (có biểu tượng CC)."
            case .emptyTranscript:
                return "Không thể trích xuất nội dung phụ đề từ video này."
            case .networkFailed:
                return "Lỗi kết nối khi tải dữ liệu từ YouTube. Vui lòng kiểm tra lại mạng internet."
            }
        }
    }
}
