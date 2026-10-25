import Foundation
import SwiftUI
import SwiftData

// MARK: - SpeakMode
enum SpeakMode: String, CaseIterable, Identifiable {
    case word = "Từ"
    case sentence = "Câu ví dụ"

    var id: String { rawValue }
}

// MARK: - SpeakAttemptResult
struct SpeakAttemptResult {
    let score: Double          // 0...1 similarity
    let recognizedText: String
    let quality: ReviewQuality // SM-2 grade derived from the score
}

// MARK: - SpeakPracticeViewModel
/// Pronunciation practice: show a word or example sentence, listen to the
/// learner repeat it, score the speech against the target with Levenshtein
/// similarity, and feed the outcome back into the SM-2 schedule.
@Observable
@MainActor
final class SpeakPracticeViewModel {
    var queue: [VocabularyItem] = []
    var currentIndex: Int = 0

    var mode: SpeakMode = .word
    var isListening: Bool = false
    var liveTranscript: String = ""
    var micLevel: Float = 0.0
    var lastResult: SpeakAttemptResult? = nil
    var errorMessage: String? = nil
    var isSessionDone: Bool = false

    var currentItem: VocabularyItem? {
        guard queue.indices.contains(currentIndex) else { return nil }
        return queue[currentIndex]
    }

    /// What the learner must say in the current mode.
    var targetText: String {
        guard let item = currentItem else { return "" }
        if mode == .sentence {
            let clean = item.example
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !clean.isEmpty { return clean }
        }
        return item.word
    }

    var progressText: String {
        guard !queue.isEmpty else { return "" }
        return "Từ \(min(currentIndex + 1, queue.count)) / \(queue.count)"
    }

    // MARK: - Session Setup

    func loadQueue(from deck: VocabularyDeck) {
        let items = (deck.items ?? []).filter { !$0.isMultipleChoice }
        queue = SRSEngine.shared.balanceDailyQueue(from: items, limit: min(max(items.count, 1), 20))
        currentIndex = 0
        lastResult = nil
        isSessionDone = queue.isEmpty
    }

    // MARK: - Listening

    func toggleListening() async {
        if isListening {
            await finishAttempt()
        } else {
            await startAttempt()
        }
    }

    private func startAttempt() async {
        guard currentItem != nil, !targetText.isEmpty else { return }
        lastResult = nil
        errorMessage = nil

        let granted = await SpeechRecognitionService.shared.requestAuthorization()
        guard granted else {
            errorMessage = "Cần quyền Truy cập Micrô & Nhận diện giọng nói để luyện nói. Vào Cài đặt → Locklish để bật lại."
            return
        }

        do {
            try await SpeechRecognitionService.shared.startListening()
            isListening = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func finishAttempt() async {
        let recognized = await SpeechRecognitionService.shared.stopListening()
        isListening = false
        liveTranscript = ""

        let result = scoreAttempt(recognized: recognized, target: targetText)
        lastResult = result

        // Feed the pronunciation outcome into the SM-2 schedule
        if let item = currentItem {
            SRSEngine.shared.processReview(item: item, quality: result.quality)
        }
    }

    // MARK: - Scoring (speech-tuned)

    /// Filler words speakers naturally add — never count them against the score.
    private static let fillers: Set<String> = ["um", "uhm", "uh", "erm", "hmm", "like", "well", "so", "actually", "basically"]

    /// Strips common inflections so "works/working/worked" all match "work" —
    /// the learner is graded on PRONUNCIATION, not grammar.
    private static func stem(_ word: String) -> String {
        var w = word
        for suffix in ["ing", "ies", "ed", "es", "s"] where w.hasSuffix(suffix) && w.count > suffix.count + 2 {
            w = String(w.dropLast(suffix.count))
            if suffix == "ies" { w += "y" }
            break
        }
        return w
    }

    private static func tokens(_ text: String) -> [String] {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }

    /// Word-level alignment: each target word counts as matched when the
    /// learner's best corresponding token is identical, stem-equal, or within
    /// distance 1 (accent tolerance). Far fairer than raw string Levenshtein,
    /// which punished word order and fillers.
    private func wordAlignmentScore(recognized: String, target: String) -> (score: Double, matchedWords: Int) {
        let engine = LevenshteinEngine.shared
        let saidWords = Self.tokens(recognized).filter { !Self.fillers.contains($0) }
        let targetWords = Self.tokens(target)
        guard !targetWords.isEmpty else { return (0, 0) }

        var matched = 0
        var cursor = 0
        for targetWord in targetWords {
            let stemTarget = Self.stem(targetWord)
            var found = false
            // Search forward from the cursor; recognizer may add words between
            var i = cursor
            while i < saidWords.count {
                let said = saidWords[i]
                let stemSaid = Self.stem(said)
                if said == targetWord || stemSaid == stemTarget
                    || (min(said.count, targetWord.count) >= 5 && engine.distance(said, targetWord) <= 1) {
                    matched += 1
                    cursor = i + 1
                    found = true
                    break
                }
                i += 1
            }
            if !found { cursor = max(cursor, 0) }
        }

        // Penalize a bit for many extra unrecognized words (keeps "said random stuff" from passing)
        let extra = max(0, saidWords.count - targetWords.count)
        let penalty = min(0.15, Double(extra) * 0.02)
        let score = max(0, Double(matched) / Double(targetWords.count) - penalty)
        return (score, matched)
    }

    func scoreAttempt(recognized: String, target: String) -> SpeakAttemptResult {
        let cleanRecognized = recognized.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanTarget = target.lowercased().trimmingCharacters(in: .whitespaces)
        guard !cleanRecognized.isEmpty else {
            return SpeakAttemptResult(score: 0, recognizedText: recognized, quality: .again)
        }

        let alignment = wordAlignmentScore(recognized: cleanRecognized, target: cleanTarget)

        var similarity = alignment.score
        if cleanRecognized.contains(cleanTarget) {
            similarity = max(similarity, 0.97)
        }

        similarity = min(max(similarity, 0), 1)
        let quality: ReviewQuality
        switch similarity {
        case 0.85...: quality = .easy
        case 0.65..<0.85: quality = .good
        case 0.4..<0.65: quality = .hard
        default: quality = .again
        }

        return SpeakAttemptResult(score: similarity, recognizedText: recognized, quality: quality)
    }

    // MARK: - Auto-stop

    /// Called from the view whenever the live transcript changes. When the
    /// speech clearly covers the target, we stop listening shortly after the
    /// words stop improving — no need to tap the mic again.
    func transcriptDidChange() {
        guard isListening, lastResult == nil else { return }
        let current = SpeechRecognitionService.shared.transcript
        guard !current.isEmpty else { return }

        lastTranscriptAt = Date()
        shouldAutoStop = meetsAutoStopThreshold(transcript: current)
    }

    private func meetsAutoStopThreshold(transcript: String) -> Bool {
        let alignment = wordAlignmentScore(recognized: transcript, target: targetText)
        if mode == .word {
            // Word mode: one solid match is enough
            return alignment.matchedWords >= 1 && alignment.score >= 0.7
        }
        // Sentence mode: nearly everything said
        return alignment.score >= 0.85
    }

    /// Periodic tick (view timer) that performs the actual auto-stop once the
    /// transcript has been stable for a short grace period.
    func autoStopTick() async {
        guard isListening, lastResult == nil, shouldAutoStop,
              let lastChange = lastTranscriptAt,
              Date().timeIntervalSince(lastChange) >= 0.6 else { return }
        await finishAttempt()
    }

    private var lastTranscriptAt: Date? = nil
    private var shouldAutoStop: Bool = false

    /// True when the speech already covers the target and auto-stop is armed.
    var isAutoStopArmed: Bool {
        shouldAutoStop && lastResult == nil && isListening
    }

    // MARK: - Navigation

    func nextItem() {
        guard currentIndex < queue.count - 1 else {
            isSessionDone = true
            return
        }
        currentIndex += 1
        lastResult = nil
        liveTranscript = ""
    }

    func restartSession() {
        currentIndex = 0
        lastResult = nil
        isSessionDone = false
        liveTranscript = ""
    }
}
