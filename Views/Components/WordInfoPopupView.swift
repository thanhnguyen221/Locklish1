import SwiftUI

// MARK: - WordInfoPopupView
/// Interactive, rich dictionary bottom sheet modal displaying localized word details,
/// US IPA phonetics, intuitive Vietnamese syllables ("sờ-ké-chồ"), part of speech,
/// authentic Vietnamese meanings, English definitions, and interactive multi-level synonym navigation.
struct WordInfoPopupView: View {
    let wordInfo: WordDetailInfo?
    let isLoading: Bool
    var deckItems: [VocabularyItem] = []
    var onSpeak: ((String) -> Void)? = nil
    var onSelectSynonym: ((String) -> Void)? = nil

    @State private var currentInfo: WordDetailInfo? = nil
    @State private var navigationHistory: [WordDetailInfo] = []
    @State private var isNavigatingToNewWord: Bool = false
    @State private var navigatingWordName: String = ""

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Navigating inline loading banner
                    if isNavigatingToNewWord {
                        navigatingInlineBanner
                    }

                    if isLoading && currentInfo == nil {
                        initialLoadingView
                    } else if let info = activeInfo {
                        wordHeaderSection(info: info)
                        phoneticsSection(info: info)
                        definitionSection(info: info)

                        if !info.exampleEn.isEmpty {
                            exampleSection(info: info)
                        }

                        synonymsSection(info: info)

                        if !info.antonyms.isEmpty {
                            antonymsSection(info: info)
                        }
                    } else {
                        emptyStateView
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 36)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Back button if user navigated into synonyms
                ToolbarItem(placement: .topBarLeading) {
                    if !navigationHistory.isEmpty {
                        Button {
                            HapticFeedback.light()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                currentInfo = navigationHistory.removeLast()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 14, weight: .bold))
                                Text(navigationHistory.last?.word ?? "Quay lại")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            .foregroundStyle(AppTheme.primary)
                        }
                    }
                }

                // Close Button
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        HapticFeedback.light()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear {
            if currentInfo == nil {
                currentInfo = wordInfo
            }
        }
        .onChange(of: wordInfo) { _, newInfo in
            if navigationHistory.isEmpty {
                currentInfo = newInfo
            }
        }
    }

    private var activeInfo: WordDetailInfo? {
        currentInfo ?? wordInfo
    }

    // MARK: - Synonym & Word Navigation
    private func navigateToWord(_ targetWord: String) {
        guard let current = activeInfo else { return }

        HapticFeedback.selection()
        navigationHistory.append(current)
        navigatingWordName = targetWord
        isNavigatingToNewWord = true

        Task {
            let nextInfo = await WordInfoService.shared.lookupWord(rawWord: targetWord, deckItems: deckItems)
            await MainActor.run {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    self.currentInfo = nextInfo
                    self.isNavigatingToNewWord = false
                    self.onSelectSynonym?(targetWord)
                }
            }
        }
    }

    // MARK: - Navigating Inline Banner
    private var navigatingInlineBanner: some View {
        HStack(spacing: 10) {
            ProgressView()
                .scaleEffect(0.85)
                .tint(AppTheme.primary)

            Text("Đang tra từ \"\(navigatingWordName)\"...")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(AppTheme.primary)

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(AppTheme.primary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - 1. Word Header
    private func wordHeaderSection(info: WordDetailInfo) -> some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(info.word)
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)

                    if info.isTargetWord {
                        Text("Từ trong bộ")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(AppTheme.primary)
                            .clipShape(Capsule())
                    }
                }

                // CEFR Level & Part of Speech Tags
                HStack(spacing: 8) {
                    if !info.cefrLevel.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "chart.bar.fill")
                                .font(.system(size: 9, weight: .bold))
                            Text(CEFRLevelHelper.title(for: info.cefrLevel))
                                .font(.system(size: 11, weight: .heavy))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(CEFRLevelHelper.color(for: info.cefrLevel))
                        .clipShape(Capsule())
                    }

                    if !info.partOfSpeech.isEmpty {
                        Text(info.partOfSpeech)
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(AppTheme.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(AppTheme.primary.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
            }

            Spacer()

            // Pronounce Speaker Button
            Button {
                HapticFeedback.light()
                if let customSpeak = onSpeak {
                    customSpeak(info.word)
                } else {
                    TTSService.shared.speak(text: info.word)
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(AppTheme.primaryGradient)
                        .frame(width: 48, height: 48)
                        .shadow(color: AppTheme.primary.opacity(0.25), radius: 6, x: 0, y: 3)

                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - 2. Phonetics Section (IPA & viPhonetic)
    @ViewBuilder
    private func phoneticsSection(info: WordDetailInfo) -> some View {
        if !info.ipa.isEmpty || !info.viPhonetic.isEmpty {
            HStack(spacing: 10) {
                if !info.ipa.isEmpty {
                    HStack(spacing: 5) {
                        Text("IPA:")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(AppTheme.textTertiary)
                        Text(info.ipa)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                if !info.viPhonetic.isEmpty {
                    HStack(spacing: 5) {
                        Image(systemName: "waveform")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.accent)
                        Text(info.viPhonetic)
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(AppTheme.accent)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(AppTheme.accent.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                Spacer()
            }
        }
    }

    // MARK: - 3. Definition Section (Guaranteed Rich Content)
    private func definitionSection(info: WordDetailInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "character.book.closed.fill")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.primary)
                Text("Ý NGHĨA & ĐỊNH NGHĨA")
                    .font(.caption2)
                    .fontWeight(.heavy)
                    .foregroundStyle(AppTheme.textSecondary)
                    .tracking(1.0)
            }

            VStack(alignment: .leading, spacing: 8) {
                // Vietnamese Meaning (Prominent)
                if !info.meaningVi.isEmpty {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.success)
                            .padding(.top, 2)

                        Text(info.meaningVi)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                            .lineSpacing(4)
                    }
                }

                // English Definition (Explanatory)
                if !info.definitionEn.isEmpty {
                    if !info.meaningVi.isEmpty {
                        Divider()
                            .opacity(0.5)
                            .padding(.vertical, 2)
                    }

                    Text(info.definitionEn)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineSpacing(3)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
            .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 2)
        }
    }

    // MARK: - 4. Example Section
    private func exampleSection(info: WordDetailInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "quote.opening")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
                Text("VÍ DỤ THỰC TẾ")
                    .font(.caption2)
                    .fontWeight(.heavy)
                    .foregroundStyle(AppTheme.textSecondary)
                    .tracking(1.0)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(info.exampleEn)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineSpacing(3)

                if !info.exampleVi.isEmpty {
                    Text(info.exampleVi)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineSpacing(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
            .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 2)
        }
    }

    // MARK: - 5. Synonyms Section (Interactive Navigation)
    private func synonymsSection(info: WordDetailInfo) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.swap")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.primary)
                    Text("TỪ ĐỒNG NGHĨA (\(info.synonyms.count))")
                        .font(.caption2)
                        .fontWeight(.heavy)
                        .foregroundStyle(AppTheme.textSecondary)
                        .tracking(1.0)
                }

                Spacer()

                if !info.synonyms.isEmpty {
                    Text("Chạm để tra nhanh")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textTertiary)
                }
            }

            if info.synonyms.isEmpty {
                Text("Không có từ đồng nghĩa phổ biến.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textTertiary)
                    .padding(.vertical, 4)
            } else {
                FlowLayout(spacing: 8, lineSpacing: 8) {
                    ForEach(info.synonyms, id: \.self) { syn in
                        Button {
                            navigateToWord(syn)
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "arrow.right.circle.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(AppTheme.primary)

                                Text(syn)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(AppTheme.primary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(AppTheme.primary.opacity(0.1))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - 6. Antonyms Section
    private func antonymsSection(info: WordDetailInfo) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.danger)
                Text("TỪ TRÁI NGHĨA (\(info.antonyms.count))")
                    .font(.caption2)
                    .fontWeight(.heavy)
                    .foregroundStyle(AppTheme.textSecondary)
                    .tracking(1.0)
            }

            FlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach(info.antonyms, id: \.self) { ant in
                    Button {
                        navigateToWord(ant)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "xmark.circle")
                                .font(.system(size: 11))
                                .foregroundStyle(AppTheme.danger)

                            Text(ant)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(AppTheme.danger)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(AppTheme.danger.opacity(0.1))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Initial Loading & Empty States
    private var initialLoadingView: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 40)
            ProgressView()
                .scaleEffect(1.2)
                .tint(AppTheme.primary)
            Text("Đang tra cứu từ điển & ngữ nghĩa...")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
            Spacer(minLength: 40)
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 40)
            Image(systemName: "character.book.closed")
                .font(.system(size: 40))
                .foregroundStyle(AppTheme.textTertiary)
            Text("Không tìm thấy thông tin từ này")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
            Spacer(minLength: 40)
        }
        .frame(maxWidth: .infinity)
    }
}
