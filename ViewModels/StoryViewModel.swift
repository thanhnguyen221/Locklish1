import Foundation
import SwiftUI

// MARK: - StoryDisplayMode
enum StoryDisplayMode: String, CaseIterable, Identifiable {
    case bilingual = "Song ngữ"
    case english = "Tiếng Anh"
    case vietnamese = "Tiếng Việt"

    var id: String { rawValue }
}

// MARK: - StoryViewModel
@Observable
@MainActor
final class StoryViewModel {
    var story: GeneratedStory? = nil
    var isLoading: Bool = false
    var errorMessage: String? = nil

    // Word Popup State
    var selectedWordInfo: WordDetailInfo? = nil
    var isWordPopupPresented: Bool = false
    var isLookingUpWord: Bool = false

    // Reading preferences
    var displayMode: StoryDisplayMode = .bilingual
    var isSpeakingStory: Bool = false
    var fontSize: CGFloat = 17.0

    // MARK: - Load or Generate Story
    func loadStory(for deck: VocabularyDeck, forceRegenerate: Bool = false) async {
        guard !(deck.items ?? []).isEmpty else {
            self.errorMessage = "Thư mục này chưa có từ vựng nào. Hãy thêm từ vựng trước khi tạo truyện!"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let result = try await StoryGeneratorService.shared.generateStory(
                deckId: deck.id,
                deckName: deck.name,
                items: deck.items ?? [],
                forceRegenerate: forceRegenerate
            )
            self.story = result
        } catch {
            self.errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Word Lookup (Context-Aware & Fast)
    func selectWord(_ rawWord: String, sentenceContext: String? = nil, deckItems: [VocabularyItem]) {
        let clean = WordInfoService.shared.sanitizeWord(rawWord)
        guard !clean.isEmpty else { return }

        HapticFeedback.light()
        isLookingUpWord = true
        isWordPopupPresented = true

        Task {
            let info = await WordInfoService.shared.lookupWord(
                rawWord: clean,
                sentenceContext: sentenceContext,
                deckItems: deckItems
            )
            self.selectedWordInfo = info
            self.isLookingUpWord = false
        }
    }

    // MARK: - Pronunciation
    func speakWord(_ word: String) {
        HapticFeedback.light()
        TTSService.shared.speak(text: word)
    }

    func toggleSpeakStory() {
        guard let story = story else { return }

        if isSpeakingStory {
            TTSService.shared.stop()
            isSpeakingStory = false
        } else {
            HapticFeedback.selection()
            isSpeakingStory = true
            // Narrate paragraph-by-paragraph: each utterance's spoken range maps
            // 1:1 onto its paragraph, so karaoke tracking never drifts even when
            // the AI's fullStoryEn and paragraphs differ slightly.
            var texts: [String] = []
            if !story.titleEn.isEmpty { texts.append(story.titleEn) }
            texts.append(contentsOf: story.paragraphs.map(\.en))
            TTSService.shared.speakKaraoke(texts: texts)
        }
    }

    func stopSpeaking() {
        if isSpeakingStory {
            TTSService.shared.stop()
            isSpeakingStory = false
        }
    }

    // MARK: - Helpers
    func isTargetWord(_ word: String) -> Bool {
        guard let story = story else { return false }
        let clean = WordInfoService.shared.sanitizeWord(word).lowercased()
        return story.targetWords.contains { $0.lowercased() == clean }
    }

    // MARK: - CEFR Level Detection
    func cefrLevel(for word: String) -> String {
        let clean = WordInfoService.shared.sanitizeWord(word).lowercased()
        guard !clean.isEmpty else { return "B1" }

        if let levels = story?.wordLevels {
            if let direct = levels[clean] {
                return direct.uppercased()
            }
            if let matched = levels.first(where: { $0.key.lowercased() == clean }) {
                return matched.value.uppercased()
            }
        }
        return WordInfoService.shared.resolveCEFRLevel(word: clean)
    }
}
