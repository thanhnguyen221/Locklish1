import SwiftUI

// MARK: - StoryReadingView
/// Immersive, bilingual AI story mode for studying vocabulary in context.
/// Generates engaging stories using all words in a folder/deck, highlights target items,
/// provides bilingual paragraph translation, audio narration, and tap-to-inspect word popups.
struct StoryReadingView: View {
    let deck: VocabularyDeck

    @State private var viewModel = StoryViewModel()
    @State private var showRegenerateConfirm: Bool = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Mode & Preferences Toolbar
            preferencesToolbar

            Divider()
                .opacity(0.5)

            // Main Story Reader
            ZStack {
                AppTheme.background.ignoresSafeArea()

                if viewModel.isLoading {
                    loadingStoryView
                } else if let error = viewModel.errorMessage {
                    errorStateView(error: error)
                } else if let story = viewModel.story {
                    storyContentView(story: story)
                } else {
                    emptyStoryView
                }
            }
        }
        .navigationTitle("Truyện AI")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    // Audio Narrator Button
                    Button {
                        viewModel.toggleSpeakStory()
                    } label: {
                        Image(systemName: viewModel.isSpeakingStory ? "stop.circle.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(viewModel.isSpeakingStory ? AppTheme.accent : AppTheme.primary)
                    }
                    .disabled(viewModel.story == nil)

                    // Regenerate Story Button
                    Button {
                        HapticFeedback.light()
                        showRegenerateConfirm = true
                    } label: {
                        Image(systemName: "sparkles")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(AppTheme.primary)
                    }
                    .disabled(viewModel.isLoading)
                }
            }
        }
        .sheet(isPresented: $viewModel.isWordPopupPresented) {
            CambridgeDictionarySheet(
                wordInfo: viewModel.selectedWordInfo,
                isLoading: viewModel.isLookingUpWord,
                currentDeck: deck
            )
        }
        .confirmationDialog(
            "Tạo câu chuyện mới?",
            isPresented: $showRegenerateConfirm,
            titleVisibility: .visible
        ) {
            Button("Tạo câu chuyện mới với AI", role: .none) {
                Task {
                    await viewModel.loadStory(for: deck, forceRegenerate: true)
                }
            }
            Button("Huỷ", role: .cancel) {}
        } message: {
            Text("AI sẽ tạo một câu chuyện hoàn toàn mới sử dụng các từ vựng trong bộ \"\(deck.name)\".")
        }
        .task {
            await viewModel.loadStory(for: deck, forceRegenerate: false)
        }
        .onChange(of: TTSService.shared.isSpeaking) { _, speaking in
            // Narration finished on its own → reset the toolbar toggle state
            if !speaking && viewModel.isSpeakingStory {
                viewModel.isSpeakingStory = false
            }
        }
        .onDisappear {
            viewModel.stopSpeaking()
        }
    }

    // MARK: - 1. Preferences Toolbar
    private var preferencesToolbar: some View {
        HStack(spacing: 12) {
            // Segmented Display Mode
            Picker("Chế độ hiển thị", selection: $viewModel.displayMode) {
                ForEach(StoryDisplayMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            // Font Size Controls (A- / A+)
            HStack(spacing: 4) {
                Button {
                    HapticFeedback.selection()
                    if viewModel.fontSize > 14 { viewModel.fontSize -= 1.5 }
                } label: {
                    Text("A-")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 5)
                        .background(AppTheme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    HapticFeedback.selection()
                    if viewModel.fontSize < 24 { viewModel.fontSize += 1.5 }
                } label: {
                    Text("A+")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 5)
                        .background(AppTheme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(AppTheme.cardBackground)
    }

    // MARK: - 2. Story Content View
    private func storyContentView(story: GeneratedStory) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header Titles (karaoke index 0 — narrated first)
                VStack(alignment: .leading, spacing: 6) {
                    if viewModel.displayMode != .vietnamese {
                        let titleActive = TTSService.shared.spokenTextIndex == 0
                        Text(story.titleEn)
                            .font(.system(size: viewModel.fontSize + 8, weight: .heavy, design: .rounded))
                            .foregroundStyle(titleActive ? AppTheme.accent : AppTheme.textPrimary)
                            .underline(titleActive, color: AppTheme.accent.opacity(0.6))
                    }

                    if viewModel.displayMode != .english && !story.titleVi.isEmpty {
                        Text(story.titleVi)
                            .font(.system(size: viewModel.fontSize + 2, weight: .semibold))
                            .foregroundStyle(AppTheme.primary)
                    }
                }
                .padding(.top, 8)
                .id("karaoke-title")

                // Target Vocabulary Words Carousel Bar
                targetWordsBanner(targetWords: story.targetWords)

                Divider()
                    .opacity(0.6)

                // Paragraphs List — auto-scrolls to follow the narration
                ScrollViewReader { proxy in
                    VStack(alignment: .leading, spacing: 24) {
                        ForEach(Array(story.paragraphs.enumerated()), id: \.offset) { index, paragraph in
                            paragraphCard(paragraph: paragraph, index: index)
                                .id("karaoke-para-\(index)")
                        }
                    }
                    .onChange(of: TTSService.shared.spokenTextIndex) { _, newIndex in
                        guard let newIndex, viewModel.isSpeakingStory else { return }
                        withAnimation(.easeInOut(duration: 0.35)) {
                            if newIndex == 0 {
                                proxy.scrollTo("karaoke-title", anchor: .top)
                            } else {
                                proxy.scrollTo("karaoke-para-\(newIndex - 1)", anchor: .center)
                            }
                        }
                    }
                }

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
        }
    }

    // MARK: - 3. Target Words Banner
    private func targetWordsBanner(targetWords: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.primary)
                Text("TỪ VỰNG TRONG TRUYỆN (\(targetWords.count) từ)")
                    .font(.caption2)
                    .fontWeight(.heavy)
                    .foregroundStyle(AppTheme.textSecondary)
                    .tracking(0.8)

                Spacer()

                Text("Chạm để tra nhanh")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textTertiary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(targetWords, id: \.self) { word in
                        let level = viewModel.cefrLevel(for: word)
                        Button {
                            viewModel.selectWord(word, deckItems: deck.items)
                        } label: {
                            HStack(spacing: 5) {
                                Text(level)
                                    .font(.system(size: 9, weight: .black))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(CEFRLevelHelper.color(for: level))
                                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

                                Text(word)
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundStyle(AppTheme.primary)
                            }
                            .padding(.leading, 4)
                            .padding(.trailing, 10)
                            .padding(.vertical, 4)
                            .background(AppTheme.primary.opacity(0.10))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(12)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
        .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 2)
    }

    // MARK: - 4. Paragraph Card
    private func paragraphCard(paragraph: StoryParagraph, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // English Section (karaoke index = title at 0, so paragraphs start at 1)
            if viewModel.displayMode != .vietnamese {
                interactiveEnglishText(paragraph.en, karaokeIndex: index + 1)
            }

            // Vietnamese Translation Section
            if viewModel.displayMode != .english && !paragraph.vi.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    Rectangle()
                        .fill(AppTheme.primary.opacity(0.5))
                        .frame(width: 3)
                        .clipShape(Capsule())

                    Text(paragraph.vi)
                        .font(.system(size: max(14, viewModel.fontSize - 1.5)))
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineSpacing(4)
                }
                .padding(.top, viewModel.displayMode == .bilingual ? 4 : 0)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
        .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 2)
    }

    // MARK: - 5. Interactive English Token Flow (with TTS karaoke)
    /// While the narrator speaks this paragraph, the word being voiced is
    /// underlined (accent), already-read words turn primary, upcoming stay neutral —
    /// identical to the YouTube subtitle karaoke, driven by the synthesizer's own
    /// `willSpeakRange` callbacks rather than time estimates.
    private func interactiveEnglishText(_ text: String, karaokeIndex: Int) -> some View {
        let tokens = tokenizeParagraph(text)
        let tts = TTSService.shared
        let isParagraphActive = tts.spokenTextIndex == karaokeIndex
        let spoken = tts.spokenRange ?? NSRange(location: 0, length: 0)

        return FlowLayout(spacing: 5, lineSpacing: 8) {
            ForEach(tokens) { token in
                let isCurrent = isParagraphActive
                    && token.range.location < NSMaxRange(spoken)
                    && token.range.upperBound > spoken.location
                let isRead = isParagraphActive && token.range.upperBound <= spoken.location

                if token.isTarget {
                    // Highlighted Target Word Pill with CEFR Badge
                    let level = viewModel.cefrLevel(for: token.cleanWord)
                    Button {
                        viewModel.selectWord(token.cleanWord, sentenceContext: text, deckItems: deck.items)
                    } label: {
                        HStack(spacing: 3) {
                            Text(token.rawText)
                                .font(.system(size: viewModel.fontSize, weight: .bold))
                                .foregroundStyle(isCurrent ? AppTheme.accent : AppTheme.primary)
                                .underline(isCurrent, color: AppTheme.accent.opacity(0.6))

                            Text(level)
                                .font(.system(size: 8, weight: .black))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 3.5)
                                .padding(.vertical, 1.5)
                                .background(CEFRLevelHelper.color(for: level))
                                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(AppTheme.primary.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)
                } else if !token.cleanWord.isEmpty {
                    // Normal Clickable Word
                    Button {
                        viewModel.selectWord(token.cleanWord, sentenceContext: text, deckItems: deck.items)
                    } label: {
                        Text(token.rawText)
                            .font(.system(size: viewModel.fontSize, weight: isCurrent ? .semibold : .regular))
                            .foregroundStyle(isCurrent ? AppTheme.accent : (isRead ? AppTheme.primary : AppTheme.textPrimary))
                            .underline(isCurrent, color: AppTheme.accent.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                } else {
                    // Punctuation or spacing
                    Text(token.rawText)
                        .font(.system(size: viewModel.fontSize))
                        .foregroundStyle(AppTheme.textPrimary)
                }
            }
        }
    }

    // MARK: - Tokenizer Helper
    private struct ParagraphToken: Identifiable {
        let id = UUID()
        let rawText: String
        let cleanWord: String
        let isTarget: Bool
        /// UTF-16 range of the token inside its paragraph — matches the ranges
        /// AVSpeechSynthesizer reports for karaoke tracking.
        let range: NSRange
    }

    private func tokenizeParagraph(_ text: String) -> [ParagraphToken] {
        let nsText = text as NSString
        var cursor = 0
        var tokens: [ParagraphToken] = []

        for raw in text.components(separatedBy: .whitespacesAndNewlines).filter({ !$0.isEmpty }) {
            // Locate the word starting from the scan cursor; whitespace-splitting
            // guarantees it appears in order, so this never matches backwards.
            let searchRange = NSRange(location: cursor, length: max(0, nsText.length - cursor))
            let found = nsText.range(of: raw, range: searchRange)
            let range = found.location != NSNotFound
                ? found
                : NSRange(location: min(cursor, nsText.length), length: (raw as NSString).length)

            cursor = min(range.location + range.length, nsText.length)
            let clean = WordInfoService.shared.sanitizeWord(raw)
            tokens.append(ParagraphToken(
                rawText: raw,
                cleanWord: clean,
                isTarget: viewModel.isTargetWord(clean),
                range: range
            ))
        }
        return tokens
    }

    // MARK: - Loading & Error States
    private var loadingStoryView: some View {
        VStack(spacing: 18) {
            ProgressView()
                .scaleEffect(1.3)
                .tint(AppTheme.primary)

            VStack(spacing: 6) {
                Text("Đang dệt nên câu chuyện...")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)

                Text("AI đang kết nối các từ vựng trong bộ \"\(deck.name)\" thành một câu chuyện ngữ cảnh sinh động.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorStateView(error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(AppTheme.warning)

            Text("Không thể tạo câu chuyện")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            Text(error)
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                Task {
                    await viewModel.loadStory(for: deck, forceRegenerate: true)
                }
            } label: {
                Text("Thử lại")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(AppTheme.primaryGradient)
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStoryView: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.pages")
                .font(.system(size: 42))
                .foregroundStyle(AppTheme.textTertiary)

            Text("Chưa có câu chuyện nào")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            Button {
                Task {
                    await viewModel.loadStory(for: deck, forceRegenerate: true)
                }
            } label: {
                Text("Tạo truyện ngay")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(AppTheme.primaryGradient)
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
