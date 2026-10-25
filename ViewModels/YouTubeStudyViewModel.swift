import Foundation
import SwiftUI

// MARK: - SubtitleDisplayMode
enum SubtitleDisplayMode: String, CaseIterable, Identifiable {
    case bilingual = "Song ngữ"
    case english = "Tiếng Anh"
    case vietnamese = "Tiếng Việt"

    var id: String { rawValue }
}

// MARK: - CueDisplayModel
/// Precomputed, per-frame-cheap rendering model for one subtitle cue.
/// Tokenization, dictionary-word sanitation and saved-word checks run ONCE
/// per (cues, saved words) change — never inside the 30 fps TimelineView tick.
struct CueDisplayModel: Identifiable {
    let id: String
    let cue: SubtitleCue
    /// (raw display token, sanitized dictionary-lookup word) per visible word.
    let tokens: [(raw: String, clean: String)]
    /// Parallel to `tokens`: whether the word already exists in a user deck.
    var savedFlags: [Bool]
    /// Absolute start times from YouTube's real per-word timings when available
    /// (parallel to `tokens`); empty → proportional fallback.
    let wordBoundaries: [Double]
}

// MARK: - YouTubeStudyViewModel
@Observable
@MainActor
final class YouTubeStudyViewModel {
    var videoURLInput: String = ""
    var videoInfo: YouTubeVideoInfo? = nil
    var isLoading: Bool = false
    var errorMessage: String? = nil

    // Player State
    // Playback time is continuously projected between the player's frequent
    // video-frame samples so the karaoke underline tracks the audio instead
    // of stepping.
    var lastVideoTime: Double = 0.0
    var lastSyncDate: Date = .distantPast
    var isVideoPlaying: Bool = false
    /// Updated from the HTML video element after metadata loads, so the
    /// player preserves the real video dimensions on its black canvas.
    var videoAspectRatio: CGFloat = 16.0 / 9.0
    var seekRequest: Double? = nil
    var autoScrollEnabled: Bool = true
    var displayMode: SubtitleDisplayMode = .bilingual
    /// Timing offset in seconds to synchronize transcript with video player.
    /// Positive values delay the transcript, negative values advance it.
    /// Default offset accounts for YouTube caption timing latency.
    var subtitleOffset: Double = -0.3

    /// Player → view model: a fresh authoritative timestamp arrived.
    func reportTime(_ time: Double) {
        lastVideoTime = time
        lastSyncDate = Date()
    }

    /// Player → view model: play state changed.
    func setPlaying(_ playing: Bool) {
        if playing {
            lastSyncDate = Date()
        } else {
            // Freeze the projection at the moment playback stopped.
            lastVideoTime = projectedTime(at: Date())
        }
        isVideoPlaying = playing
    }

    /// Best current playback time: last reported time extrapolated forward
    /// while playing. The clamp is generous relative to the player's ~6 Hz
    /// bridge cadence so the karaoke underline keeps gliding smoothly between
    /// authoritative samples instead of freezing, while a stalled web player
    /// still can't run the highlight ahead of the spoken audio.
    func projectedTime(at date: Date = Date()) -> Double {
        guard isVideoPlaying else { return lastVideoTime }
        let delta = date.timeIntervalSince(lastSyncDate)
        return lastVideoTime + min(max(delta, 0), 0.5)
    }

    // Subtitle Search
    var searchSubtitleQuery: String = ""

    // Dictionary Sheet State
    var selectedWordInfo: WordDetailInfo? = nil
    var isDictionaryPresented: Bool = false
    var isLookingUpWord: Bool = false

    // Saved words set for fast highlighting
    var savedWordsSet: Set<String> = []

    // MARK: - Active Cue Index
    /// O(log n): cues arrive sorted by startTime from timedtext, so binary-search
    /// the last cue starting at/before the time and verify it actually bounds it.
    func activeCueIndex(at time: Double) -> Int? {
        guard let cues = videoInfo?.cues, !cues.isEmpty else { return nil }
        // Apply subtitle offset to synchronize with video player
        let adjustedTime = time + subtitleOffset

        var lo = 0
        var hi = cues.count - 1
        var candidate = -1
        while lo <= hi {
            let mid = (lo + hi) / 2
            if cues[mid].startTime <= adjustedTime {
                candidate = mid
                lo = mid + 1
            } else {
                hi = mid - 1
            }
        }

        // Overlapping caption windows are rare; a small backward scan covers them.
        var idx = candidate
        while idx >= 0 {
            let cue = cues[idx]
            if adjustedTime >= cue.startTime && adjustedTime < cue.endTime {
                return idx
            }
            if cue.endTime <= adjustedTime && idx != candidate {
                break
            }
            idx -= 1
        }
        // During a real pause between caption cues, no sentence is active.
        // Selecting the next cue early makes the highlight disagree with the
        // audio, so deliberately return nil rather than choosing a "nearby"
        // sentence.
        return nil
    }

    var activeCueIndex: Int? { activeCueIndex(at: projectedTime()) }

    /// The subtitle cue currently being spoken, matched by identity so it
    /// stays correct even when the visible list is filtered by search.
    var activeCue: SubtitleCue? {
        guard let cues = videoInfo?.cues, let idx = activeCueIndex, cues.indices.contains(idx) else {
            return nil
        }
        return cues[idx]
    }

    func activeCueId(at time: Double) -> String? {
        guard let idx = activeCueIndex(at: time),
              let cues = videoInfo?.cues, cues.indices.contains(idx) else { return nil }
        return cues[idx].id
    }

    // MARK: - Cached Display Models & Filtering
    /// Rendering models for the loaded cues; rebuilt only when the video or the
    /// user's saved-word set changes — NOT on every animation tick.
    private(set) var cueDisplays: [CueDisplayModel] = []
    private var filterCacheQuery: String? = nil
    private var filterCacheResult: [CueDisplayModel] = []

    /// Search-filtered display models, cached per query until cues/saved words change.
    func displayModels(matching query: String) -> [CueDisplayModel] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed == filterCacheQuery {
            return filterCacheResult
        }
        let filtered: [CueDisplayModel]
        if trimmed.isEmpty {
            filtered = cueDisplays
        } else {
            let q = trimmed.lowercased()
            filtered = cueDisplays.filter {
                $0.cue.textEn.lowercased().contains(q) || $0.cue.textVi.lowercased().contains(q)
            }
        }
        filterCacheQuery = trimmed
        filterCacheResult = filtered
        return filtered
    }

    /// Index of the last word the audio has reached inside the active cue.
    /// Uses YouTube's real word timings when present; proportional split otherwise.
    func spokenWordIndex(in model: CueDisplayModel, at time: Double) -> Int {
        let count = model.tokens.count
        guard count > 0 else { return 0 }

        if model.wordBoundaries.count == count {
            var idx = 0
            while idx < count && time >= model.wordBoundaries[idx] { idx += 1 }
            return idx
        }

        let cue = model.cue
        let duration = max(cue.duration, 0.05)
        let progress = min(max((time - cue.startTime) / duration, 0), 1)
        return Int((progress * Double(count)).rounded(.down))
    }

    /// (Re)builds all per-cue rendering work: token split, sanitize, saved flags,
    /// word boundaries. Called after load, after deck refresh, and when a word
    /// gets saved — a handful of times per video instead of 30×/second.
    private func rebuildCueDisplays() {
        guard let cues = videoInfo?.cues else {
            cueDisplays = []
            filterCacheQuery = nil
            return
        }

        cueDisplays = cues.map { cue in
            let rawTokens = cue.textEn.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
            let tokens: [(raw: String, clean: String)] = rawTokens.map {
                (raw: $0, clean: WordInfoService.shared.sanitizeWord($0))
            }
            let boundaries: [Double] = cue.words.count == rawTokens.count
                ? cue.words.map(\.startTime)
                : []
            return CueDisplayModel(
                id: cue.id,
                cue: cue,
                tokens: tokens,
                savedFlags: tokens.map { savedWordsSet.contains($0.clean.lowercased()) },
                wordBoundaries: boundaries
            )
        }
        filterCacheQuery = nil
    }

    // MARK: - Load Video from Input or Sample
    func loadVideo(from urlOrId: String? = nil) async {
        let input = (urlOrId ?? videoURLInput).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else {
            errorMessage = "Vui lòng dán link video YouTube!"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let info = try await YouTubeSubtitleService.shared.fetchSubtitles(for: input)
            self.videoInfo = info
            self.videoAspectRatio = 16.0 / 9.0
            self.videoURLInput = "https://www.youtube.com/watch?v=\(info.videoId)"
            rebuildCueDisplays()
        } catch {
            self.errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Seek to Subtitle Cue
    func seekTo(cue: SubtitleCue) {
        HapticFeedback.selection()
        seekRequest = cue.startTime
    }

    // MARK: - Word Lookup with Sentence Context
    func selectWord(_ rawWord: String, in sentence: String, deckItems: [VocabularyItem] = []) {
        let clean = WordInfoService.shared.sanitizeWord(rawWord)
        guard !clean.isEmpty else { return }

        HapticFeedback.light()
        isLookingUpWord = true
        isDictionaryPresented = true

        Task {
            let info = await WordInfoService.shared.lookupWord(
                rawWord: clean,
                sentenceContext: sentence,
                deckItems: deckItems
            )
            self.selectedWordInfo = info
            self.isLookingUpWord = false
        }
    }

    // MARK: - Word Highlight Tracking
    func refreshSavedWords(from decks: [VocabularyDeck]) {
        var set = Set<String>()
        for d in decks {
            for it in d.items {
                let clean = WordInfoService.shared.sanitizeWord(it.word).lowercased()
                if !clean.isEmpty {
                    set.insert(clean)
                }
            }
        }
        self.savedWordsSet = set
        rebuildCueDisplays()
    }

    func isWordSaved(_ word: String) -> Bool {
        let clean = WordInfoService.shared.sanitizeWord(word).lowercased()
        return savedWordsSet.contains(clean)
    }

    func markWordSaved(_ word: String) {
        let clean = WordInfoService.shared.sanitizeWord(word).lowercased()
        if !clean.isEmpty {
            savedWordsSet.insert(clean)
            // Update the parallel flag array in place — far cheaper than a
            // full rebuild, and it keeps search filtering untouched.
            let lower = clean
            for i in cueDisplays.indices {
                if cueDisplays[i].tokens.contains(where: { $0.clean.lowercased() == lower }) {
                    cueDisplays[i].savedFlags = cueDisplays[i].tokens.map { savedWordsSet.contains($0.clean.lowercased()) }
                }
            }
        }
    }
}
