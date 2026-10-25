import SwiftUI
import PhotosUI

// MARK: - GamifiedDrillView
/// Interactive letter-by-letter typing game screen inspired by modern learning apps.
/// Features:
/// - Prominent illustration / image with PhotoPicker customization (commercial feature)
/// - Fill-in-the-blank sentence: "We eat ________ in summer." -> "We eat watermelon in summer."
/// - Dynamic character slots: "w a t e r m e l o n" with spring pop animations
/// - Action row: 👁️ show, 🔊 hear, ⭐ favorite
/// - Smooth Continue pill button
struct GamifiedDrillView: View {
    @Bindable var viewModel: GamifiedViewModel
    let round: GameThemeRound
    let onDismiss: () -> Void

    @FocusState private var isInputFocused: Bool
    @State private var selectedPhotoItem: PhotosPickerItem? = nil

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea(.all)

            if viewModel.isSessionComplete {
                roundCompleteCelebrationView
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else if let word = viewModel.currentWord {
                VStack(spacing: 0) {
                    // Top Progress Bar
                    drillProgressHeader
                        .padding(.top, 16)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)

                    // Scrollable content area
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 24) {
                            // 1. Center Image / Illustration
                            illustrationHeroSection(word: word)

                            // 2. Sentence Display: "We eat ________ in summer."
                            sentenceDisplaySection(word: word)

                            // 3. Letter-by-letter interactive spelling slots
                            letterSlotsSection(word: word)

                            // 4. Action Icons Bar: [ 👁️ show ] [ 🔊 hear ] [ ⭐ ]
                            actionIconsBar(word: word)

                            // 5. Warning / Feedback if close match
                            if let warning = viewModel.showCloseMatchWarning {
                                feedbackWarningBanner(warning: warning)
                            }

                            Spacer(minLength: 40)
                        }
                        .id(viewModel.currentWordIndex)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.98)),
                            removal: .opacity
                        ))
                        .padding(.horizontal, 24)
                        .padding(.top, 10)
                        .padding(.bottom, 20)
                    }
                    .scrollDismissesKeyboard(.interactively)

                    // Bottom Continue Action Bar
                    bottomContinueBar
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                }
            } else {
                fallbackLoadingView
            }
        }
        .onAppear {
            if viewModel.activeRound?.id != round.id || viewModel.currentWord == nil {
                viewModel.startRound(round: round)
            }
            isInputFocused = true
        }
        .onChange(of: viewModel.currentWordIndex) { _, _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isInputFocused = true
            }
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    viewModel.updateWordImage(imageData: data)
                }
            }
        }
    }

    // MARK: - 1. Progress Header
    private var drillProgressHeader: some View {
        VStack(spacing: 10) {
            HStack {
                Button {
                    HapticFeedback.light()
                    onDismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .padding(10)
                        .background(AppTheme.cardBackground)
                        .clipShape(Circle())
                        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)

                Spacer()

                Text(viewModel.progressText)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(AppTheme.textPrimary)

                Spacer()

                Button {
                    HapticFeedback.light()
                    viewModel.restartRound()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 11, weight: .bold))
                        Text("Luyện lại")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppTheme.cardBackground)
                    .clipShape(Capsule())
                    .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)
            }

            // Smooth progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: 7)

                    Capsule()
                        .fill(AppTheme.primaryGradient)
                        .frame(width: geo.size.width * viewModel.progressRatio, height: 7)
                        .animation(.spring(response: 0.45, dampingFraction: 0.75), value: viewModel.progressRatio)
                }
            }
            .frame(height: 7)
        }
    }

    // MARK: - 2. Illustration Hero Section (Supports Custom Photo for Commercial Use)
    private func illustrationHeroSection(word: GameWordItem) -> some View {
        VStack(spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                // Image frame
                ZStack {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(AppTheme.cardBackground)
                        .frame(width: 170, height: 170)
                        .shadow(color: Color.black.opacity(0.06), radius: 14, x: 0, y: 6)

                    if let data = word.imageData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 154, height: 154)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    } else if let urlStr = word.imageURL, let url = URL(string: urlStr) {
                        AsyncImage(url: url) { phase in
                            if let img = phase.image {
                                img.resizable()
                                    .scaledToFill()
                                    .frame(width: 154, height: 154)
                                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            } else {
                                Text(word.iconEmoji)
                                    .font(.system(size: 82))
                            }
                        }
                    } else {
                        // High-res emoji symbol
                        Text(word.iconEmoji)
                            .font(.system(size: 82))
                    }
                }

                // Camera overlay button (Commercial customization feature)
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.primary)
                            .frame(width: 36, height: 36)
                            .shadow(color: AppTheme.primary.opacity(0.3), radius: 6, x: 0, y: 3)

                        Image(systemName: "camera.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .offset(x: 6, y: 6)
                }
                .buttonStyle(.plain)
            }

            // Word meaning & Vietnamese phonetic
            HStack(spacing: 8) {
                Text(word.meaning)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(AppTheme.textPrimary)

                if !word.viPhonetic.isEmpty {
                    Text("•")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textTertiary)

                    Text(word.viPhonetic)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(AppTheme.primary)
                }
            }
            .padding(.top, 4)
        }
    }

    // MARK: - 3. Dynamic Sentence Display (We eat ________ -> We eat watermelon)
    private func sentenceDisplaySection(word: GameWordItem) -> some View {
        VStack(spacing: 8) {
            if viewModel.isAnswerCorrect {
                // Completed full sentence with highlighted target word!
                highlightedCompletedSentence(word: word)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                // Sentence with fill-in-the-blank underline: "We eat ________ in summer."
                Text(word.exampleBlankSentence)
                    .font(.system(size: 21, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)

                // Vietnamese translation display (shown when toggle is on and translation exists)
                if !word.exampleTranslation.isEmpty && viewModel.showTranslation {
                    Text(word.exampleTranslation)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }

            // Translate toggle button (shown only before correct)
            if !viewModel.isAnswerCorrect {
                if word.exampleTranslation.isEmpty {
                    // Auto-translate button
                    Button {
                        Task {
                            await viewModel.autoTranslateSentence()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if viewModel.isTranslating {
                                ProgressView()
                                    .scaleEffect(0.7)
                            } else {
                                Image(systemName: "globe")
                                    .font(.system(size: 13, weight: .bold))
                            }
                            Text(viewModel.isTranslating ? "Đang dịch..." : "Dịch câu")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .foregroundStyle(AppTheme.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(AppTheme.cardBackground)
                        .clipShape(Capsule())
                        .shadow(color: Color.black.opacity(0.03), radius: 3, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isTranslating)
                } else {
                    // Toggle visibility button
                    Button {
                        viewModel.toggleTranslation()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: viewModel.showTranslation ? "eye.slash.fill" : "eye.fill")
                                .font(.system(size: 13, weight: .bold))
                            Text(viewModel.showTranslation ? "Ẩn dịch" : "Hiện dịch")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .foregroundStyle(AppTheme.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(AppTheme.cardBackground)
                        .clipShape(Capsule())
                        .shadow(color: Color.black.opacity(0.03), radius: 3, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: viewModel.isAnswerCorrect)
    }

    @ViewBuilder
    private func highlightedCompletedSentence(word: GameWordItem) -> some View {
        let full = word.exampleSentence
        let target = word.word

        VStack(spacing: 6) {
            if let range = full.range(of: target, options: .caseInsensitive) {
                let before = String(full[..<range.lowerBound])
                let match = String(full[range])
                let after = String(full[range.upperBound...])

                (
                    Text(before)
                        .foregroundStyle(AppTheme.textPrimary)
                    + Text(match)
                        .foregroundStyle(AppTheme.success)
                        .fontWeight(.heavy)
                        .underline(true, color: AppTheme.success)
                    + Text(after)
                        .foregroundStyle(AppTheme.textPrimary)
                )
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .lineSpacing(6)
            } else {
                Text(full)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.success)
                    .multilineTextAlignment(.center)
            }

            // Show translation if available
            if !word.exampleTranslation.isEmpty {
                Text(word.exampleTranslation)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
        }
    }

    // MARK: - 4. Letter-by-Letter Interactive Typing Slots ("w a t e r m e l o n")
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

    private func letterSlotsSection(word: GameWordItem) -> some View {
        VStack(spacing: 16) {
            let inputLetters = Array(viewModel.userInput.lowercased())
            let tokens = makeWordTokens(from: word.word)
            let dims = slotDimensions(for: word.word)

            FlowLayout(spacing: 14, lineSpacing: 10) {
                ForEach(tokens) { token in
                    HStack(spacing: dims.spacing) {
                        ForEach(token.letters, id: \.globalIndex) { letter in
                            let targetChar = letter.char
                            let i = letter.globalIndex
                            let inputChar: Character? = i < inputLetters.count ? inputLetters[i] : nil
                            let isFilled = inputChar != nil
                            let isMatch = inputChar == targetChar
                            let isActiveCursor = i == inputLetters.count && !viewModel.isAnswerCorrect

                            VStack(spacing: 4) {
                                // Letter character
                                Text(isFilled ? String(inputChar!) : (viewModel.isAnswerRevealed ? String(targetChar) : " "))
                                    .font(.system(size: dims.fontSize, weight: .heavy, design: .rounded))
                                    .foregroundStyle(letterColor(isFilled: isFilled, isMatch: isMatch))
                                    .frame(width: dims.width, height: dims.height)
                                    .scaleEffect(isFilled ? 1.05 : 1.0)
                                    .animation(.spring(response: 0.25, dampingFraction: 0.6), value: inputChar)

                                // Slot Underline / Base
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
                    let sanitized = sanitizePhraseInput(newValue, target: word.word)
                    if sanitized != viewModel.userInput {
                        viewModel.userInput = sanitized
                    } else {
                        viewModel.onUserInputChanged(sanitized)
                    }
                }
                .onSubmit {
                    if viewModel.isAnswerCorrect {
                        viewModel.advanceNext()
                    } else {
                        viewModel.verifyInput()
                    }
                }
        }
    }

    private func letterColor(isFilled: Bool, isMatch: Bool) -> Color {
        if viewModel.isAnswerCorrect {
            return AppTheme.success
        } else if viewModel.isAnswerRevealed {
            return AppTheme.primary
        } else if isFilled {
            if viewModel.showCloseMatchWarning != nil && !isMatch {
                return AppTheme.danger
            }
            return AppTheme.textPrimary
        } else {
            return AppTheme.primary
        }
    }

    private func slotColor(isFilled: Bool, isMatch: Bool, isActiveCursor: Bool) -> Color {
        if viewModel.isAnswerCorrect {
            return AppTheme.success
        } else if viewModel.isAnswerRevealed {
            return AppTheme.primary
        } else if isFilled {
            if viewModel.showCloseMatchWarning != nil && !isMatch {
                return AppTheme.danger
            }
            return AppTheme.primary
        } else if isActiveCursor {
            return AppTheme.primary
        } else {
            return Color.primary.opacity(0.18)
        }
    }

    // MARK: - 5. Action Icons Bar: [ 👁️ show ] [ 🔊 hear ] [ ⭐ ]
    private func actionIconsBar(word: GameWordItem) -> some View {
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
                viewModel.speakCurrentWord()
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

            // [ ⭐ favorite ]
            Button {
                viewModel.toggleFavorite()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: word.isFavorite ? "star.fill" : "star")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(word.isFavorite ? Color.yellow : AppTheme.textSecondary)
                    Text("Lưu")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(word.isFavorite ? AppTheme.textPrimary : AppTheme.textSecondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(AppTheme.cardBackground)
                .clipShape(Capsule())
                .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - 6. Feedback Warning Banner
    private func feedbackWarningBanner(warning: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(AppTheme.warning)
            Text(warning)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(AppTheme.warning)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(AppTheme.warning.opacity(0.12))
        .clipShape(Capsule())
    }

    // MARK: - 7. Bottom Continue Button
    private var bottomContinueBar: some View {
        Button {
            HapticFeedback.selection()
            if viewModel.isAnswerCorrect {
                viewModel.advanceNext()
                isInputFocused = true
            } else {
                viewModel.verifyInput()
            }
        } label: {
            HStack(spacing: 8) {
                Text(viewModel.isAnswerCorrect ? "Tiếp tục" : "Kiểm tra")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)

                Image(systemName: viewModel.isAnswerCorrect ? "arrow.right" : "checkmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                viewModel.isAnswerCorrect
                    ? AnyShapeStyle(AppTheme.success)
                    : AnyShapeStyle(AppTheme.primaryGradient)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
            .shadow(
                color: (viewModel.isAnswerCorrect ? AppTheme.success : AppTheme.primary).opacity(0.25),
                radius: 8, x: 0, y: 4
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 8. Round Complete Celebration View
    private var roundCompleteCelebrationView: some View {
        VStack(spacing: 24) {
            Spacer()

            // Stars celebration
            HStack(spacing: 12) {
                ForEach(1...3, id: \.self) { star in
                    Image(systemName: "star.fill")
                        .font(.system(size: 42))
                        .foregroundStyle(Color.yellow)
                        .shadow(color: Color.yellow.opacity(0.4), radius: 8, x: 0, y: 4)
                        .scaleEffect(1.1)
                }
            }

            VStack(spacing: 10) {
                Text("Hoàn thành Vòng \(viewModel.activeRound?.id ?? 1)! 🎉")
                    .font(.title)
                    .fontWeight(.heavy)
                    .foregroundStyle(AppTheme.textPrimary)

                Text(viewModel.activeRound?.title ?? "")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.primary)

                Text("Bạn đã học xuất sắc \(viewModel.sessionCorrectCount)/\(viewModel.totalWordsInSession) từ vựng chủ đề này!")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            Button {
                HapticFeedback.success()
                onDismiss()
            } label: {
                Text("Trở về Lộ trình")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppTheme.primaryGradient)
                    .clipShape(Capsule())
                    .shadow(color: AppTheme.primary.opacity(0.25), radius: 8, x: 0, y: 4)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 36)
        }
        .padding(24)
    }

    // MARK: - 9. Fallback Loading View (Guarantees screen is never blank)
    private var fallbackLoadingView: some View {
        VStack(spacing: 20) {
            HStack {
                Button {
                    HapticFeedback.light()
                    onDismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .padding(10)
                        .background(AppTheme.cardBackground)
                        .clipShape(Circle())
                        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.top, 16)
            .padding(.horizontal, 20)

            Spacer()

            ProgressView()
                .scaleEffect(1.2)
                .tint(AppTheme.primary)

            Text("Đang tải từ vựng...")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            Button {
                HapticFeedback.light()
                viewModel.startRound(round: round)
            } label: {
                Text("Tải lại vòng học")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(AppTheme.primaryGradient)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }
}
