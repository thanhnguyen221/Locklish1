import SwiftUI
import SwiftData

// MARK: - DictationPracticeView
/// Listening & Dictation screen: hides word spelling, auto-plays US English speech,
/// verifies spelling accuracy, and unlocks Screen Time focus shields upon 100% completion.
struct DictationPracticeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allItems: [VocabularyItem]

    var selectedDeck: VocabularyDeck? = nil
    var isDailyMission: Bool = false
    var onDismissMission: (() -> Void)? = nil

    @State private var viewModel = DictationViewModel()
    @FocusState private var isInputFocused: Bool

    var body: some View {
        Group {
            if viewModel.sessionItems.isEmpty || viewModel.isSessionFinished {
                sessionResultView
            } else if viewModel.currentItem != nil {
                GeometryReader { geo in
                    VStack(spacing: 0) {
                        // Progress Header
                        progressHeader
                            .padding(.top, 12)
                            .padding(.bottom, 8)

                        // Scrollable practice content
                        ScrollView {
                            VStack(spacing: 20) {
                                audioHeroSection
                                hintsSection
                                inputFieldSection
                                actionIconsBar
                                evaluationFeedbackSection
                                actionButtonSection
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                            .padding(.bottom, max(geo.safeAreaInsets.bottom + 16, 32))
                        }
                        .scrollDismissesKeyboard(.interactively)
                    }
                }
            } else {
                // Loading fallback
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onDisappear { WidgetDataStore.refreshFromModel() }
        .onAppear {
            viewModel.startSession(
                with: allItems,
                deckFilter: selectedDeck,
                isDailyUnlockMission: isDailyMission,
                targetCount: 10
            )
            isInputFocused = true
        }
        .onChange(of: selectedDeck) { _, newDeck in
            viewModel.startSession(
                with: allItems,
                deckFilter: newDeck,
                isDailyUnlockMission: isDailyMission,
                targetCount: 10
            )
            isInputFocused = true
        }
    }

    // MARK: - Progress Header
    private var progressHeader: some View {
        VStack(spacing: 8) {
            HStack {
                if isDailyMission {
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(AppTheme.accent)
                        Text("Nhiệm vụ hàng ngày")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                } else {
                    Text(selectedDeck != nil ? "Chính tả • \(selectedDeck!.name)" : "Nghe chép chính tả")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Spacer()

                Text(viewModel.progressText)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(isDailyMission ? AppTheme.accent : AppTheme.primary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: 6)

                    Capsule()
                        .fill(isDailyMission ? AnyShapeStyle(AppTheme.accent) : AnyShapeStyle(AppTheme.primaryGradient))
                        .frame(width: geo.size.width * viewModel.progressRatio, height: 6)
                        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: viewModel.progressRatio)
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Audio Hero Section
    private var audioHeroSection: some View {
        VStack(spacing: 10) {
            Button(action: {
                viewModel.playCurrentAudio()
            }) {
                ZStack {
                    // Outer pulse ring
                    Circle()
                        .fill(AppTheme.primary.opacity(0.08))
                        .frame(width: 110, height: 110)

                    Circle()
                        .fill(AppTheme.primaryGradient)
                        .frame(width: 86, height: 86)
                        .shadow(color: AppTheme.primary.opacity(0.3), radius: 12, x: 0, y: 6)

                    Image(systemName: "speaker.wave.3.fill")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)

            Text("Chạm để nghe lại phát âm giọng Mỹ")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(.top, 8)
    }

    // MARK: - Hints Section
    private var hintsSection: some View {
        Group {
            if let item = viewModel.currentItem {
                VStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Text(item.meaning)
                            .font(.headline)
                            .fontWeight(.medium)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(AppTheme.textPrimary)

                        if !item.partOfSpeech.isEmpty {
                            Text(item.partOfSpeech)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(AppTheme.primary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(AppTheme.primary.opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "waveform")
                            .font(.caption)
                        Text("Gợi ý âm điệu: \(item.viPhonetic)")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(AppTheme.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(AppTheme.primary.opacity(0.1))
                    .clipShape(Capsule())

                    if !item.displayNote.isEmpty {
                        Button {
                            viewModel.toggleTranslation()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: viewModel.showTranslation ? "checkmark.circle.fill" : "note.text")
                                    .font(.system(size: 12, weight: .bold))
                                Text(viewModel.showTranslation ? item.displayNote : "Xem ghi chú")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                            }
                            .foregroundStyle(viewModel.showTranslation ? AppTheme.success : AppTheme.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(AppTheme.background)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Input Field Section
    private struct WordToken: Identifiable {
        let id: Int
        let letters: [(char: Character, globalIndex: Int)]
    }

    private func makeWordTokens(from text: String) -> [WordToken] {
        var tokens: [WordToken] = []
        let chars = Array(text.lowercased())
        var currentLetters: [(char: Character, globalIndex: Int)] = []
        var wordIndex = 0

        for (i, ch) in chars.enumerated() {
            if ch == " " {
                if !currentLetters.isEmpty {
                    tokens.append(WordToken(id: wordIndex, letters: currentLetters))
                    wordIndex += 1
                    currentLetters = []
                }
            } else {
                currentLetters.append((char: ch, globalIndex: i))
            }
        }
        if !currentLetters.isEmpty {
            tokens.append(WordToken(id: wordIndex, letters: currentLetters))
        }
        return tokens
    }

    private func slotDimensions(for targetWord: String) -> (width: CGFloat, height: CGFloat, fontSize: CGFloat, spacing: CGFloat) {
        let count = targetWord.filter { $0 != " " }.count
        if count <= 8 {
            return (width: 24, height: 32, fontSize: 22, spacing: 6)
        } else if count <= 14 {
            return (width: 20, height: 28, fontSize: 18, spacing: 5)
        } else if count <= 20 {
            return (width: 16, height: 25, fontSize: 15, spacing: 4)
        } else {
            return (width: 14, height: 22, fontSize: 13, spacing: 3)
        }
    }

    private func sanitizePhraseInput(_ input: String, target: String) -> String {
        let targetChars = Array(target)
        let inputChars = Array(input)
        var result: [Character] = []
        var targetIdx = 0
        var inputIdx = 0

        while inputIdx < inputChars.count && targetIdx < targetChars.count {
            let tChar = targetChars[targetIdx]
            let inChar = inputChars[inputIdx]

            if tChar == " " && inChar != " " {
                result.append(" ")
                targetIdx += 1
                continue
            }

            result.append(inChar)
            targetIdx += 1
            inputIdx += 1
        }

        return String(result.prefix(target.count))
    }

    private var inputFieldSection: some View {
        VStack(spacing: 16) {
            if let item = viewModel.currentItem {
                let inputLetters = Array(viewModel.userInput.lowercased())
                let tokens = makeWordTokens(from: item.word)
                let dims = slotDimensions(for: item.word)

                FlowLayout(spacing: 14, lineSpacing: 10) {
                    ForEach(tokens) { token in
                        HStack(spacing: dims.spacing) {
                            ForEach(token.letters, id: \.globalIndex) { letter in
                                let targetChar = letter.char
                                let i = letter.globalIndex
                                let inputChar: Character? = i < inputLetters.count ? inputLetters[i] : nil
                                let isFilled = inputChar != nil
                                let isMatch = inputChar == targetChar
                                let isActiveCursor = i == inputLetters.count && !viewModel.isAnswerRevealed

                                VStack(spacing: 4) {
                                    Text(isFilled ? String(inputChar!) : (viewModel.isAnswerRevealed ? String(targetChar) : " "))
                                        .font(.system(size: dims.fontSize, weight: .heavy, design: .rounded))
                                        .foregroundStyle(letterColor(isFilled: isFilled, isMatch: isMatch))
                                        .frame(width: dims.width, height: dims.height)
                                        .scaleEffect(isFilled ? 1.05 : 1.0)
                                        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: inputChar)

                                    Capsule()
                                        .fill(slotColor(isFilled: isFilled, isMatch: isMatch, isActiveCursor: isActiveCursor))
                                        .frame(height: isActiveCursor ? 3.5 : 2.5)
                                        .animation(.easeInOut(duration: 0.15), value: isActiveCursor)
                                }
                                .frame(width: dims.width)
                            }
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
                .onTapGesture {
                    isInputFocused = true
                }

                // Hidden background TextField capturing smooth keyboard input
                TextField("", text: $viewModel.userInput)
                    .focused($isInputFocused)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .opacity(0.001)
                    .frame(width: 1, height: 1)
                    .onChange(of: viewModel.userInput) { _, newValue in
                        let sanitized = sanitizePhraseInput(newValue, target: item.word)
                        if sanitized != viewModel.userInput {
                            viewModel.userInput = sanitized
                        }
                    }
                    .onSubmit {
                        if case .correct = viewModel.evaluationState {
                            viewModel.advanceNext(modelContext: modelContext)
                        } else if case .incorrect(let revealedWord) = viewModel.evaluationState, !revealedWord.isEmpty {
                            viewModel.advanceNext(modelContext: modelContext)
                        } else {
                            viewModel.verifyAnswer(in: modelContext)
                        }
                    }
            }
        }
    }

    private func letterColor(isFilled: Bool, isMatch: Bool) -> Color {
        if case .correct = viewModel.evaluationState {
            return AppTheme.success
        } else if viewModel.isAnswerRevealed {
            return AppTheme.primary
        } else if isFilled {
            if case .incorrect = viewModel.evaluationState, !isMatch {
                return AppTheme.danger
            }
            if case .closeMatch = viewModel.evaluationState, !isMatch {
                return AppTheme.accent
            }
            return AppTheme.textPrimary
        } else {
            return AppTheme.primary
        }
    }

    private func slotColor(isFilled: Bool, isMatch: Bool, isActiveCursor: Bool) -> Color {
        if case .correct = viewModel.evaluationState {
            return AppTheme.success
        } else if viewModel.isAnswerRevealed {
            return AppTheme.primary
        } else if isFilled {
            if case .incorrect = viewModel.evaluationState, !isMatch {
                return AppTheme.danger
            }
            if case .closeMatch = viewModel.evaluationState, !isMatch {
                return AppTheme.accent
            }
            return AppTheme.primary
        } else if isActiveCursor {
            return AppTheme.primary
        } else {
            return Color.primary.opacity(0.18)
        }
    }

    private var inputBorderColor: Color {
        switch viewModel.evaluationState {
        case .pending:
            return Color.primary.opacity(0.08)
        case .correct:
            return AppTheme.success
        case .closeMatch:
            return AppTheme.accent
        case .incorrect:
            return AppTheme.danger
        }
    }

    // MARK: - Evaluation Feedback Section
    @ViewBuilder
    private var evaluationFeedbackSection: some View {
        switch viewModel.evaluationState {
        case .pending:
            EmptyView()

        case .correct:
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                Text("Chính xác tuyệt đối! +1 điểm")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(AppTheme.success)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(AppTheme.success.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .transition(.scale(scale: 0.9).combined(with: .opacity))

        case .closeMatch(let hint):
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.subheadline)
                    Text(hint)
                        .font(.subheadline)
                        .fontWeight(.bold)
                }
                .foregroundStyle(AppTheme.accent)

                Text("Gợi ý: Lắng nghe kỹ lại âm đuôi hoặc nguyên âm và sửa lại nhé!")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(AppTheme.accent.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppTheme.accent.opacity(0.3), lineWidth: 1)
            )
            .transition(.scale(scale: 0.95).combined(with: .opacity))

        case .incorrect(let revealedWord):
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "xmark.circle.fill")
                    Text("Chưa đúng, hãy thử nghe lại!")
                }
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(AppTheme.danger)

                if !revealedWord.isEmpty {
                    HStack(spacing: 6) {
                        Text("Đáp án:")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                        Text(revealedWord)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundStyle(AppTheme.primary)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(AppTheme.danger.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .transition(.opacity)
        }
    }

    // MARK: - Action Button
    private var actionButtonSection: some View {
        Button(action: {
            if case .correct = viewModel.evaluationState {
                viewModel.advanceNext(modelContext: modelContext)
            } else if case .incorrect(let revealedWord) = viewModel.evaluationState, !revealedWord.isEmpty {
                viewModel.advanceNext(modelContext: modelContext)
            } else {
                viewModel.verifyAnswer(in: modelContext)
            }
        }) {
            HStack(spacing: 8) {
                Text(actionButtonTitle)
                    .font(.headline)
                    .fontWeight(.bold)

                if case .correct = viewModel.evaluationState {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 15, weight: .bold))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                actionButtonBackground
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
            .shadow(
                color: actionButtonShadowColor,
                radius: 8, x: 0, y: 4
            )
            .animation(.easeInOut(duration: 0.2), value: viewModel.userInput.isEmpty)
        }
        .disabled(actionButtonDisabled)
    }

    private var actionButtonDisabled: Bool {
        if case .correct = viewModel.evaluationState {
            return false
        }
        if case .incorrect(let revealedWord) = viewModel.evaluationState, !revealedWord.isEmpty {
            return false
        }
        return viewModel.userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var actionButtonBackground: AnyShapeStyle {
        if case .correct = viewModel.evaluationState {
            return AnyShapeStyle(AppTheme.success)
        }
        if viewModel.userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return AnyShapeStyle(Color.primary.opacity(0.15))
        }
        return AnyShapeStyle(AppTheme.primaryGradient)
    }

    private var actionButtonShadowColor: Color {
        if case .correct = viewModel.evaluationState {
            return AppTheme.success.opacity(0.3)
        }
        return AppTheme.primary.opacity(viewModel.userInput.isEmpty ? 0 : 0.25)
    }

    // MARK: - Action Icons Bar
    private var actionIconsBar: some View {
        HStack(spacing: 24) {
            // [ 👁️ show ]
            Button {
                viewModel.revealAnswer()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: viewModel.isAnswerRevealed ? "eye.fill" : "eye")
                        .font(.system(size: 15, weight: .bold))
                    Text("Gợi ý")
                        .font(.caption)
                        .fontWeight(.bold)
                }
                .foregroundStyle(viewModel.isAnswerRevealed ? AppTheme.primary : AppTheme.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(AppTheme.cardBackground)
                .clipShape(Capsule())
                .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)

            // [ 🔊 hear ]
            Button {
                viewModel.playCurrentAudio()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 15, weight: .bold))
                    Text("Nghe")
                        .font(.caption)
                        .fontWeight(.bold)
                }
                .foregroundStyle(AppTheme.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(AppTheme.cardBackground)
                .clipShape(Capsule())
                .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)
        }
    }

    private var actionButtonTitle: String {
        if case .correct = viewModel.evaluationState {
            return "Tiếp tục"
        }
        if case .incorrect(let revealedWord) = viewModel.evaluationState, !revealedWord.isEmpty {
            return "Bỏ qua & Sang từ tiếp theo →"
        }
        return "Kiểm tra chính tả"
    }

    // MARK: - Session Result View & Shield Unlock Celebration
    private var sessionResultView: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer(minLength: 40)

                if allItems.isEmpty {
                    EmptyStatePlaceholderView(
                        iconName: "headphones",
                        title: "Chưa có từ vựng để luyện nghe",
                        subtitle: "Hãy thêm từ mới vào danh mục trước khi thực hiện bài kiểm tra chính tả."
                    )
                } else {
                    VStack(spacing: 24) {
                        // Trophy / Shield icon
                        ZStack {
                            Circle()
                                .fill(viewModel.showShieldUnlockedCelebration
                                    ? AppTheme.success.opacity(0.15)
                                    : AppTheme.primary.opacity(0.1))
                                .frame(width: 100, height: 100)

                            Image(systemName: viewModel.showShieldUnlockedCelebration
                                ? "trophy.fill"
                                : "flag.checkered")
                                .font(.system(size: 46))
                                .foregroundStyle(viewModel.showShieldUnlockedCelebration ? Color.yellow : AppTheme.primary)
                        }

                        VStack(spacing: 8) {
                            Text(viewModel.showShieldUnlockedCelebration
                                ? "Xuất sắc! Đạt điểm tuyệt đối 🎉"
                                : "Hoàn thành buổi luyện tập")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(AppTheme.textPrimary)
                                .multilineTextAlignment(.center)

                            // Score Card
                            HStack(spacing: 8) {
                                Image(systemName: "star.fill")
                                    .foregroundStyle(AppTheme.warning)
                                Text("Điểm số: \(viewModel.correctAnswersCount) / \(viewModel.sessionItems.count)")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(AppTheme.textPrimary)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(AppTheme.cardBackground)
                            .clipShape(Capsule())
                            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
                        }

                        // Status message
                        if viewModel.showShieldUnlockedCelebration {
                            VStack(spacing: 10) {
                                Text("Tuyệt vời! Bạn đã trả lời đúng toàn bộ từ vựng hôm nay.")
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.textSecondary)
                                    .multilineTextAlignment(.center)

                                HStack(spacing: 6) {
                                    Image(systemName: "sparkles")
                                    Text("Ghi nhớ chính tả xuất sắc 100%!")
                                }
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundStyle(AppTheme.success)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 10)
                                .background(AppTheme.success.opacity(0.1))
                                .clipShape(Capsule())
                            }
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                        } else {
                            Text("Hãy tiếp tục luyện tập để đạt điểm tuyệt đối nhé!")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 10)
                                .background(AppTheme.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .padding(.horizontal, 24)
                        }

                        Button(action: {
                            viewModel.retrySession(with: allItems)
                            isInputFocused = true
                        }) {
                            Label(
                                isDailyMission
                                    ? (viewModel.showShieldUnlockedCelebration ? "Luyện tập lại nhiệm vụ" : "Luyện tập lại")
                                    : "Luyện lại từ đầu",
                                systemImage: "arrow.counterclockwise"
                            )
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 15)
                            .background(AppTheme.primaryGradient)
                            .clipShape(Capsule())
                            .shadow(color: AppTheme.primary.opacity(0.25), radius: 8, x: 0, y: 4)
                        }
                        .padding(.top, 4)

                        if let dismissAction = onDismissMission {
                            Button(action: {
                                HapticFeedback.light()
                                dismissAction()
                            }) {
                                Text("Đóng & Quay lại")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(AppTheme.textSecondary)
                                    .padding(.vertical, 8)
                            }
                        }
                    }
                    .padding(24)
                }

                Spacer(minLength: 40)
            }
        }
    }
}
