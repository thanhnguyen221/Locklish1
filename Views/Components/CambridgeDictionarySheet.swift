import SwiftUI
import SwiftData

// MARK: - CambridgeDictionarySheet
/// Premium Cambridge-style dictionary sheet displaying contextual part of speech,
/// UK/US phonetic pronunciations with audio, CEFR level badge, authentic English definition,
/// Vietnamese meaning, contextual subtitle example, interactive synonyms, and 1-tap "Add to Deck".
struct CambridgeDictionarySheet: View {
    let wordInfo: WordDetailInfo?
    let isLoading: Bool
    var currentDeck: VocabularyDeck? = nil
    var onWordAdded: ((String) -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \VocabularyDeck.createdAt, order: .reverse) private var allDecks: [VocabularyDeck]

    @State private var currentInfo: WordDetailInfo? = nil
    @State private var navigationHistory: [WordDetailInfo] = []
    @State private var isNavigatingToNewWord: Bool = false
    @State private var navigatingWordName: String = ""

    // Save to deck state
    @State private var isSelectDeckSheetPresented: Bool = false
    @State private var saveSuccessMessage: String? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if isNavigatingToNewWord {
                        navigatingInlineBanner
                    }

                    if isLoading && currentInfo == nil {
                        loadingView
                    } else if let info = activeInfo {
                        // 1. Cambridge Header: Word + CEFR Badge + Bookmark
                        wordHeaderCard(info: info)

                        // 2. Pronunciation Bar: UK / US Speakers + IPA + viPhonetic
                        pronunciationCard(info: info)

                        // 3. Contextual Part of Speech & Definition Block
                        meaningCard(info: info)

                        // 4. Contextual Example Card (from Subtitle or AI Story)
                        if let contextSentence = info.contextSentenceEn, !contextSentence.isEmpty {
                            contextSentenceCard(sentenceEn: contextSentence, sentenceVi: info.contextSentenceVi)
                        } else if !info.exampleEn.isEmpty {
                            generalExampleCard(info: info)
                        }

                        // 5. Synonyms & Antonyms
                        if !info.synonyms.isEmpty {
                            synonymsSection(info: info)
                        }

                        if !info.antonyms.isEmpty {
                            antonymsSection(info: info)
                        }

                        // 6. Add to Deck Action Button
                        saveToDeckSection(info: info)
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
                // Back Button for Synonym Chain Navigation
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
            .sheet(isPresented: $isSelectDeckSheetPresented) {
                deckPickerSheet
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

    // MARK: - 1. Word Header Card
    private func wordHeaderCard(info: WordDetailInfo) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(info.word)
                            .font(.system(size: 30, weight: .heavy, design: .rounded))
                            .foregroundStyle(AppTheme.textPrimary)

                        // CEFR Level Badge (A1 - C2)
                        Text(info.cefrLevel.uppercased())
                            .font(.system(size: 11, weight: .black))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3.5)
                            .background(CEFRLevelHelper.color(for: info.cefrLevel))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }

                    // Dictionary style subtitle
                    Text("CAMBRIDGE ENGLISH • NGỮ CẢNH TỰ ĐỘNG")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(AppTheme.textTertiary)
                        .tracking(0.8)
                }

                Spacer()

                // Bookmark status
                if isWordAlreadySaved(word: info.word) {
                    HStack(spacing: 4) {
                        Image(systemName: "bookmark.fill")
                            .font(.system(size: 11))
                        Text("Đã lưu")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(AppTheme.success)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(AppTheme.success.opacity(0.12))
                    .clipShape(Capsule())
                }
            }
        }
    }

    // MARK: - 2. Pronunciation Card (UK / US / IPA / Vietnamese Phonetics)
    private func pronunciationCard(info: WordDetailInfo) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // US Audio
                Button {
                    HapticFeedback.light()
                    TTSService.shared.speak(text: info.word)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.blue)

                        Text("US")
                            .font(.system(size: 12, weight: .heavy))
                            .foregroundStyle(.blue)

                        Text(info.ipa)
                            .font(.system(size: 13, weight: .medium, design: .serif))
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)

                // UK Audio
                Button {
                    HapticFeedback.light()
                    TTSService.shared.speak(text: info.word)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "speaker.wave.1.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.purple)

                        Text("UK")
                            .font(.system(size: 12, weight: .heavy))
                            .foregroundStyle(.purple)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.purple.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)

                Spacer()
            }

            // Intuitive Vietnamese Syllables
            if !info.viPhonetic.isEmpty {
                HStack(spacing: 6) {
                    Text("Đọc là:")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(AppTheme.textTertiary)

                    Text(info.viPhonetic)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.accent)

                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(AppTheme.accent.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .padding(14)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 2)
    }

    // MARK: - 3. Contextual Part of Speech & Definition Block
    private func meaningCard(info: WordDetailInfo) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // Part of Speech Badge
            HStack(spacing: 8) {
                Text(info.partOfSpeech.uppercased())
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(AppTheme.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(AppTheme.primary.opacity(0.12))
                    .clipShape(Capsule())

                if info.contextSentenceEn != nil {
                    Text("Xác định theo câu ngữ cảnh")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.textTertiary)
                }

                Spacer()
            }

            // English Definition (Cambridge format)
            VStack(alignment: .leading, spacing: 4) {
                Text("ĐỊNH NGHĨA TIẾNG ANH")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(AppTheme.textTertiary)
                    .tracking(0.6)

                Text(info.definitionEn)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineSpacing(3)
            }

            Divider()

            // Vietnamese Meaning
            VStack(alignment: .leading, spacing: 4) {
                Text("NGHĨA TIẾNG VIỆT")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(AppTheme.textTertiary)
                    .tracking(0.6)

                Text(info.meaningVi)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.primary)
            }
        }
        .padding(16)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 2)
    }

    // MARK: - 4. Context Sentence Card
    private func contextSentenceCard(sentenceEn: String, sentenceVi: String?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Câu ngữ cảnh thực tế", systemImage: "sparkles")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppTheme.primary)

                Spacer()

                Button {
                    HapticFeedback.light()
                    TTSService.shared.speak(text: sentenceEn)
                } label: {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(AppTheme.primary)
                }
                .buttonStyle(.plain)
            }

            Text(sentenceEn)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .lineSpacing(3)

            if let vi = sentenceVi, !vi.isEmpty {
                Text(vi)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineSpacing(2)
            }
        }
        .padding(14)
        .background(AppTheme.primary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.primary.opacity(0.15), lineWidth: 1)
        )
    }

    private func generalExampleCard(info: WordDetailInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("VÍ DỤ TỪ ĐIỂN")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(AppTheme.textTertiary)
                    .tracking(0.6)

                Spacer()

                Button {
                    HapticFeedback.light()
                    TTSService.shared.speak(text: info.exampleEn)
                } label: {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(AppTheme.primary)
                }
                .buttonStyle(.plain)
            }

            Text(info.exampleEn)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.textPrimary)

            if !info.exampleVi.isEmpty {
                Text(info.exampleVi)
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .padding(14)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - 5. Synonyms & Antonyms Navigation
    private func synonymsSection(info: WordDetailInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TỪ ĐỒNG NGHĨA (SYNONYMS)")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(AppTheme.textTertiary)
                .tracking(0.6)

            FlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach(info.synonyms, id: \.self) { syn in
                    Button {
                        navigateToWord(syn)
                    } label: {
                        HStack(spacing: 4) {
                            Text(syn)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(AppTheme.primary)
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(AppTheme.primary.opacity(0.7))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppTheme.primary.opacity(0.08))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func antonymsSection(info: WordDetailInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TỪ TRÁI NGHĨA (ANTONYMS)")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(AppTheme.textTertiary)
                .tracking(0.6)

            FlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach(info.antonyms, id: \.self) { ant in
                    Button {
                        navigateToWord(ant)
                    } label: {
                        HStack(spacing: 4) {
                            Text(ant)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.red)
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.red.opacity(0.7))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.red.opacity(0.08))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - 6. Save to Deck Action
    private func saveToDeckSection(info: WordDetailInfo) -> some View {
        VStack(spacing: 10) {
            if let msg = saveSuccessMessage {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppTheme.success)
                    Text(msg)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(AppTheme.success)
                }
                .transition(.scale.combined(with: .opacity))
            }

            if isWordAlreadySaved(word: info.word) {
                // Word is already in user's deck
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(AppTheme.success)

                    Text("Từ này đã nằm trong bộ từ vựng của bạn")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(AppTheme.textSecondary)

                    Spacer()
                }
                .padding(14)
                .background(AppTheme.success.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                Button {
                    HapticFeedback.selection()
                    if let deck = currentDeck ?? allDecks.first {
                        addWord(info: info, to: deck)
                    } else {
                        isSelectDeckSheetPresented = true
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 17, weight: .bold))

                        Text(currentDeck != nil ? "Thêm vào bộ \"\(currentDeck!.name)\"" : "Thêm vào danh sách từ vựng")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppTheme.primaryGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: AppTheme.primary.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)

                if allDecks.count > 1 {
                    Button {
                        isSelectDeckSheetPresented = true
                    } label: {
                        Text("Chọn học phần khác để lưu...")
                            .font(.caption)
                            .foregroundStyle(AppTheme.primary)
                    }
                }
            }
        }
    }

    // MARK: - Deck Picker Sheet
    private var deckPickerSheet: some View {
        NavigationStack {
            List {
                ForEach(allDecks) { deck in
                    Button {
                        if let info = activeInfo {
                            addWord(info: info, to: deck)
                        }
                        isSelectDeckSheetPresented = false
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(deck.name)
                                    .font(.headline)
                                    .foregroundStyle(AppTheme.textPrimary)
                                Text("\(deck.items.count) từ")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "plus")
                                .foregroundStyle(AppTheme.primary)
                        }
                    }
                }
            }
            .navigationTitle("Chọn học phần")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Đóng") {
                        isSelectDeckSheetPresented = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Add Word Helper
    private func addWord(info: WordDetailInfo, to deck: VocabularyDeck) {
        HapticFeedback.success()

        let newItem = VocabularyItem(
            word: info.word,
            ipa: info.ipa,
            viPhonetic: info.viPhonetic,
            partOfSpeech: info.partOfSpeech,
            meaning: info.meaningVi,
            note: info.definitionEn,
            example: info.contextSentenceEn ?? info.exampleEn,
            exampleTranslation: info.contextSentenceVi ?? info.exampleVi
        )
        deck.items.append(newItem)
        modelContext.insert(newItem)
        try? modelContext.save()

        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            saveSuccessMessage = "Đã thêm \"\(info.word)\" vào học phần \"\(deck.name)\"!"
        }

        onWordAdded?(info.word)

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation {
                saveSuccessMessage = nil
            }
        }
    }

    private func isWordAlreadySaved(word: String) -> Bool {
        let clean = WordInfoService.shared.sanitizeWord(word).lowercased()
        for d in allDecks {
            if d.items.contains(where: { $0.word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == clean }) {
                return true
            }
        }
        return false
    }

    // MARK: - Synonym & Word Navigation
    private func navigateToWord(_ targetWord: String) {
        guard let current = activeInfo else { return }

        HapticFeedback.selection()
        navigationHistory.append(current)
        navigatingWordName = targetWord
        isNavigatingToNewWord = true

        Task {
            let nextInfo = await WordInfoService.shared.lookupWord(rawWord: targetWord)
            await MainActor.run {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    self.currentInfo = nextInfo
                    self.isNavigatingToNewWord = false
                }
            }
        }
    }

    // MARK: - Inline & Loading Views
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
    }

    private var loadingView: some View {
        VStack(spacing: 14) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(AppTheme.primary)

            Text("Đang tra cứu từ điển Cambridge...")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
    }

    private var emptyStateView: some View {
        VStack(spacing: 10) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 32))
                .foregroundStyle(AppTheme.textTertiary)
            Text("Không tìm thấy thông tin từ vựng")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}
