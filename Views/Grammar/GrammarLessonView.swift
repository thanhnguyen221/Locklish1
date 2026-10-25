import SwiftUI

// MARK: - GrammarLessonView
/// Full grammar lesson: explanation, formula chips, bilingual examples with
/// audio, common-mistake cards (wrong → right), fill-in exercises with
/// multi-answer checking, mark-as-learned, and previous/next navigation.
struct GrammarLessonView: View {
    @State var topicId: String

    @State private var progress = GrammarProgressStore.shared
    private let service = GrammarDataService.shared

    // Exercise state, indexed parallel to topic.exercises
    @State private var inputs: [String] = []
    @State private var results: [Bool] = []
    @State private var checked = false

    private var topic: GrammarTopic? {
        service.topic(withId: topicId)
    }

    var body: some View {
        Group {
            if let topic {
                content(topic)
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 36))
                        .foregroundStyle(AppTheme.textTertiary)
                    Text("Không tìm thấy chủ đề này")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle(topic?.titleVi ?? "Bài học")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { resetExerciseState() }
    }

    private func content(_ topic: GrammarTopic) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header(topic)
                    explanationCard(topic)
                    formsCard(topic)
                    examplesCard(topic)
                    mistakesCard(topic)
                    exercisesCard(topic)
                    navigationBar(topic)

                    Spacer(minLength: 30)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
        }
    }

    // MARK: - Header

    private func header(_ topic: GrammarTopic) -> some View {
        HStack(spacing: 10) {
            Text(topic.level)
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(CEFRLevelHelper.color(for: topic.level))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            Text(topic.titleEn)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(1)

            Spacer()

            // Mark as learned toggle
            Button {
                HapticFeedback.success()
                progress.toggleCompleted(topic.id)
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: progress.isCompleted(topic.id) ? "checkmark.seal.fill" : "checkmark.seal")
                        .font(.system(size: 12))
                    Text(progress.isCompleted(topic.id) ? "Đã học" : "Đánh dấu đã học")
                        .font(.caption)
                        .fontWeight(.bold)
                }
                .foregroundStyle(progress.isCompleted(topic.id) ? .white : AppTheme.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(progress.isCompleted(topic.id) ? AnyShapeStyle(AppTheme.successGradient) : AnyShapeStyle(AppTheme.primary.opacity(0.1)))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Explanation

    private func explanationCard(_ topic: GrammarTopic) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Giải thích", icon: "text.book.closed.fill")
            Text(topic.explanationVi)
                .font(.subheadline)
                .foregroundStyle(AppTheme.textPrimary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
    }

    // MARK: - Forms

    @ViewBuilder
    private func formsCard(_ topic: GrammarTopic) -> some View {
        if !topic.forms.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                sectionTitle("Công thức", icon: "function")
                ForEach(topic.forms, id: \.self) { form in
                    Text(form)
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundStyle(AppTheme.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppTheme.primary.opacity(0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
        }
    }

    // MARK: - Examples

    @ViewBuilder
    private func examplesCard(_ topic: GrammarTopic) -> some View {
        if !topic.examples.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle("Ví dụ", icon: "text.quote")
                ForEach(Array(topic.examples.enumerated()), id: \.offset) { _, example in
                    HStack(alignment: .top, spacing: 10) {
                        Button {
                            HapticFeedback.light()
                            TTSService.shared.speak(text: example.en)
                        } label: {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(AppTheme.primary)
                                .frame(width: 28, height: 28)
                                .background(AppTheme.primary.opacity(0.1))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Đọc câu ví dụ tiếng Anh")

                        VStack(alignment: .leading, spacing: 3) {
                            Text(example.en)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(AppTheme.textPrimary)
                            Text(example.vi)
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
        }
    }

    // MARK: - Common mistakes

    @ViewBuilder
    private func mistakesCard(_ topic: GrammarTopic) -> some View {
        if !topic.commonMistakes.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle("Lỗi thường gặp", icon: "exclamationmark.triangle.fill", tint: AppTheme.warning)
                ForEach(Array(topic.commonMistakes.enumerated()), id: \.offset) { _, mistake in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(AppTheme.danger)
                                .padding(.top, 1)
                            Text(mistake.wrong)
                                .font(.subheadline)
                                .strikethrough(color: AppTheme.danger)
                                .foregroundStyle(AppTheme.textSecondary)
                        }

                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(AppTheme.success)
                                .padding(.top, 1)
                            Text(mistake.right)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(AppTheme.textPrimary)
                        }

                        Text(mistake.noteVi)
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.primary.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
        }
    }

    // MARK: - Exercises

    @ViewBuilder
    private func exercisesCard(_ topic: GrammarTopic) -> some View {
        if !topic.exercises.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    sectionTitle("Bài tập", icon: "pencil.and.outline")
                    Spacer()
                    if checked {
                        let correct = results.filter { $0 }.count
                        Text("Đúng \(correct)/\(topic.exercises.count)")
                            .font(.caption)
                            .fontWeight(.heavy)
                            .foregroundStyle(correct == topic.exercises.count ? AppTheme.success : AppTheme.warning)
                    }
                }

                ForEach(Array(topic.exercises.enumerated()), id: \.offset) { index, exercise in
                    exerciseRow(index: index, exercise: exercise)
                }

                Button {
                    checkAnswers(topic)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                        Text(checked ? "Kiểm tra lại" : "Kiểm tra đáp án")
                            .fontWeight(.bold)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppTheme.primaryGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)

                if checked {
                    // Show accepted answers for anything the learner missed
                    ForEach(Array(topic.exercises.enumerated()), id: \.offset) { index, exercise in
                        if !results.indices.contains(index) || !results[index] {
                            Text("Đáp án: \(exercise.answer)")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
        }
    }

    private func exerciseRow(index: Int, exercise: GrammarExercise) -> some View {
        let isCorrect = checked && results.indices.contains(index) && results[index]

        return VStack(alignment: .leading, spacing: 6) {
            Text("Câu \(index + 1). \(exercise.q)")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textPrimary)

            HStack(spacing: 8) {
                TextField("Nhập đáp án...", text: bindingFor(index))
                    .font(.subheadline)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .stroke(checked ? (isCorrect ? AppTheme.success.opacity(0.6) : AppTheme.danger.opacity(0.6)) : Color.clear, lineWidth: 1)
                    )
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                if checked {
                    Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(isCorrect ? AppTheme.success : AppTheme.danger)
                }
            }
        }
    }

    // MARK: - Prev / Next

    private func navigationBar(_ topic: GrammarTopic) -> some View {
        let all = service.allTopics
        guard let currentIndex = service.index(of: topic) else { return AnyView(EmptyView()) }
        let hasPrev = currentIndex > 0
        let hasNext = currentIndex < all.count - 1

        return AnyView(
            HStack(spacing: 12) {
                if hasPrev {
                    Button {
                        HapticFeedback.selection()
                        navigateTo(all[currentIndex - 1].id)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "chevron.left")
                            Text(all[currentIndex - 1].titleVi)
                                .lineLimit(1)
                        }
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(AppTheme.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(AppTheme.primary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                if hasNext {
                    Button {
                        HapticFeedback.selection()
                        navigateTo(all[currentIndex + 1].id)
                    } label: {
                        HStack(spacing: 5) {
                            Text(all[currentIndex + 1].titleVi)
                                .lineLimit(1)
                            Image(systemName: "chevron.right")
                        }
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(AppTheme.primaryGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .buttonStyle(.plain)
                }
            }
        )
    }

    // MARK: - Helpers

    private func sectionTitle(_ title: String, icon: String, tint: Color = AppTheme.primary) -> some View {
        Label(title.uppercased(), systemImage: icon)
            .font(.caption)
            .fontWeight(.heavy)
            .foregroundStyle(tint)
    }

    private func bindingFor(_ index: Int) -> Binding<String> {
        Binding(
            get: { inputs.indices.contains(index) ? inputs[index] : "" },
            set: { newValue in
                if inputs.indices.contains(index) {
                    inputs[index] = newValue
                }
            }
        )
    }

    private func resetExerciseState() {
        guard let topic else { return }
        inputs = Array(repeating: "", count: topic.exercises.count)
        results = Array(repeating: false, count: topic.exercises.count)
        checked = false
    }

    private func checkAnswers(_ topic: GrammarTopic) {
        var newResults: [Bool] = []
        for (index, exercise) in topic.exercises.enumerated() {
            let input = inputs.indices.contains(index) ? inputs[index] : ""
            newResults.append(GrammarAnswerChecker.check(userInput: input, answer: exercise.answer))
        }
        results = newResults
        checked = true
        let correct = newResults.filter { $0 }.count
        progress.recordScore(topicId: topic.id, correct: correct)
        HapticFeedback.success()
    }

    private func navigateTo(_ newTopicId: String) {
        topicId = newTopicId
        resetExerciseState()
    }
}
