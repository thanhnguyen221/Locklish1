import Foundation
import AVFoundation

// MARK: - TTSService
/// Audio synthesis engine for standard US English pronunciation.
/// Built with AVSpeechSynthesizer, configuring audio session ducking and natural pacing.
/// Supports karaoke narration: speaking a queue of texts while reporting the exact
/// character range being voiced (`willSpeakRangeOfSpeechString`) so views can
/// underline the word the voice is currently reading.
@Observable
@MainActor
final class TTSService: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = TTSService()

    private let synthesizer = AVSpeechSynthesizer()
    var isSpeaking: Bool = false
    var currentWord: String?

    // MARK: - Karaoke Narration State
    /// Index into the queued karaoke texts currently being spoken (nil = inactive).
    var spokenTextIndex: Int? = nil
    /// Character range (within that text) being voiced right now.
    var spokenRange: NSRange? = nil
    private var karaokeTexts: [String] = []

    override private init() {
        super.init()
        synthesizer.delegate = self
    }

    /// Speaks the given English word or phrase.
    /// - Parameters:
    ///   - text: Word or sentence to pronounce
    ///   - rate: Speech rate multiplier (default 0.46 for clear educational articulation)
    ///   - voiceLanguage: BCP-47 tag — "en-US" (default) or "en-GB" for the IPA accent toggle
    func speak(text: String, rate: Float = 0.46, voiceLanguage: String = "en-US") {
        clearKaraokeState()

        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        configureAudioSession()

        // Stop any active utterance to prevent overlap
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = utterance(for: text, rate: rate, voiceLanguage: voiceLanguage)
        currentWord = text
        isSpeaking = true
        synthesizer.speak(utterance)
    }

    /// Narrates a queue of texts (e.g. story paragraphs) in order, publishing
    /// which text index and character range is being spoken for karaoke tracking.
    func speakKaraoke(texts: [String], rate: Float = 0.46) {
        clearKaraokeState()
        let clean = texts.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !clean.isEmpty else { return }

        configureAudioSession()

        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        karaokeTexts = clean
        spokenTextIndex = 0
        currentWord = clean.first
        isSpeaking = true
        for text in clean {
            synthesizer.speak(utterance(for: text, rate: rate))
        }
    }

    private func utterance(for text: String, rate: Float, voiceLanguage: String = "en-US") -> AVSpeechUtterance {
        let utterance = AVSpeechUtterance(string: text)
        // Strictly select the requested English voice (US default / GB for IPA)
        utterance.voice = AVSpeechSynthesisVoice(language: voiceLanguage)
            ?? AVSpeechSynthesisVoice(identifier: AVSpeechSynthesisVoiceIdentifierAlex)
        utterance.rate = rate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        return utterance
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true)
        } catch {
            print("Failed to configure audio session: \(error.localizedDescription)")
        }
    }

    /// Defers setup to the next main run-loop turn. AVSpeechSynthesizer performs
    /// its audio work asynchronously, while this small deferral lets a gesture's
    /// haptic and SwiftUI animation begin without competing for that frame.
    func speakAfterCurrentRunLoop(text: String, rate: Float = 0.46) {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty else { return }

        DispatchQueue.main.async { [weak self] in
            self?.speak(text: cleanText, rate: rate)
        }
    }

    func stop() {
        clearKaraokeState()
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
            isSpeaking = false
            currentWord = nil
        }
    }

    private func clearKaraokeState() {
        karaokeTexts = []
        spokenTextIndex = nil
        spokenRange = nil
    }

    // MARK: - AVSpeechSynthesizerDelegate
    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        willSpeakRangeOfSpeechString characterRange: NSRange,
        utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in
            // Only track ranges while a karaoke queue is active
            guard self.spokenTextIndex != nil else { return }
            self.spokenRange = characterRange
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            if let index = self.spokenTextIndex {
                // Advance to the next queued text, or finish the session
                if index + 1 < self.karaokeTexts.count {
                    self.spokenTextIndex = index + 1
                    self.spokenRange = nil
                } else {
                    self.clearKaraokeState()
                }
            }
            self.isSpeaking = false
            self.currentWord = nil
            // Deactivate audio session to restore background audio
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.clearKaraokeState()
            self.isSpeaking = false
            self.currentWord = nil
        }
    }
}
