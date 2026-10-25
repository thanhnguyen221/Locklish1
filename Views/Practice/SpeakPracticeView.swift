import SwiftUI

// MARK: - SpeakPracticeView
/// Pronunciation practice screen: repeat the word or example sentence out loud,
/// get scored by on-device speech recognition, and advance through the SM-2 queue.
struct SpeakPracticeView: View {
    let deck: VocabularyDeck

    @State private var viewModel = SpeakPracticeViewModel()

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isSessionDone {
                sessionDoneView
            } else if let item = viewModel.currentItem {
                practiceContent(item: item)
            } else {
                emptyView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background.ignoresSafeArea())
        .onDisappear { WidgetDataStore.refreshFromModel() }
        .navigationTitle("Luyện nói")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.loadQueue(from: deck)
        }
        .onDisappear {
            Task { await SpeechRecognitionService.shared.stopListening() }
        }
    }

    // MARK: - Practice Content

    private func practiceContent(item: VocabularyItem) -> some View {
        VStack(spacing: 20) {
            // Header: progress + mode
            VStack(spacing: 12) {
                HStack {
                    Text(viewModel.progressText)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(AppTheme.textSecondary)

                    Spacer()

                    Picker("Chế độ", selection: $viewModel.mode) {
                        ForEach(SpeakMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 170)
                }

                ProgressView(value: Double(viewModel.currentIndex + 1), total: Double(max(viewModel.queue.count, 1)))
                    .tint(AppTheme.primary)
            }
            .padding(.horizontal, 22)

            Spacer()

            // Target card
            targetCard(item)

            Spacer()

            // Live transcript / result / auto-stop indicator
            if viewModel.isListening {
                TimelineView(.periodic(from: .now, by: 0.3)) { _ in
                    let speech = SpeechRecognitionService.shared

                    VStack(spacing: 6) {
                        if viewModel.isAutoStopArmed {
                            Label("Đã nghe được — đang chốt điểm…", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(AppTheme.success)
                        } else {
                            Text("Đang nghe… nói rõ vào micro (tự dừng khi xong)")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textTertiary)
                        }

                        Text(speech.transcript.isEmpty ? "…" : speech.transcript)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(viewModel.isAutoStopArmed ? AppTheme.success : AppTheme.primary)
                            .lineLimit(2)
                            .padding(.horizontal, 30)
                    }
                    .frame(height: 60)
                }
            } else if let result = viewModel.lastResult {
                resultCard(result)
            } else if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(AppTheme.danger)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                    .frame(height: 60, alignment: .top)
            } else {
                Color.clear.frame(height: 60)
            }

            // Mic button
            micButton

            Spacer(minLength: 16)
        }
        .onChange(of: SpeechRecognitionService.shared.transcript) { _, _ in
            viewModel.transcriptDidChange()
        }
        .task(id: viewModel.isListening) {
            // Auto-stop heartbeat while listening
            while viewModel.isListening && viewModel.lastResult == nil {
                await viewModel.autoStopTick()
                try? await Task.sleep(nanoseconds: 300_000_000)
            }
        }
    }

    private func targetCard(_ item: VocabularyItem) -> some View {
        VStack(spacing: 10) {
            if viewModel.mode == .sentence {
                Text(viewModel.targetText)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            } else {
                Text(item.word)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                if !item.ipa.isEmpty {
                    Text(item.ipa)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                }

                if !item.viPhonetic.isEmpty {
                    Text("Phát âm: \(item.viPhonetic)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(AppTheme.primary)
                }
            }

            Button {
                HapticFeedback.light()
                TTSService.shared.speak(text: viewModel.targetText)
            } label: {
                Label("Nghe mẫu", systemImage: "speaker.wave.2.fill")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(AppTheme.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(AppTheme.primary.opacity(0.1))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusCard, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusCard, style: .continuous)
                .stroke(
                    viewModel.isListening
                        ? AppTheme.accent.opacity(0.35)
                        : (viewModel.isAutoStopArmed ? AppTheme.success.opacity(0.4) : Color.primary.opacity(0.06)),
                    lineWidth: viewModel.isListening ? 1.5 : 0.5
                )
        )
        .padding(.horizontal, 22)
    }

    private var micButton: some View {
        let micLevel = SpeechRecognitionService.shared.audioLevel

        return Button {
            HapticFeedback.selection()
            Task { await viewModel.toggleListening() }
        } label: {
            ZStack {
                // Pulse rings follow the live mic level
                Circle()
                    .fill(AppTheme.accent.opacity(0.15))
                    .frame(width: 96 + CGFloat(micLevel) * 26,
                           height: 96 + CGFloat(micLevel) * 26)
                    .animation(.easeOut(duration: 0.12), value: micLevel)

                Circle()
                    .fill(AppTheme.accent)
                    .frame(width: 84, height: 84)
                    .shadow(color: AppTheme.accent.opacity(0.35), radius: 12, x: 0, y: 5)

                Image(systemName: viewModel.isListening ? "stop.fill" : "mic.fill")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
        .padding(.bottom, 6)
        .disabled(viewModel.lastResult != nil)
        .opacity(viewModel.lastResult != nil ? 0.35 : 1)
    }

    // MARK: - Result Card

    private func resultCard(_ result: SpeakAttemptResult) -> some View {
        let percent = Int(result.score * 100)
        let (color, title, message): (Color, String, String) = {
            switch result.quality {
            case .easy: return (AppTheme.success, "Xuất sắc! \(percent)%", "Phát âm rất chuẩn — giữ phong độ nhé!")
            case .good: return (AppTheme.primary, "Tốt! \(percent)%", "Nghe rõ và đúng, chỉ cần nói mượt hơn chút nữa.")
            case .hard: return (AppTheme.warning, "Gần đúng \(percent)%", "Nghe được từ nhưng chưa chuẩn — nghe mẫu rồi thử lại.")
            case .again: return (AppTheme.danger, "Chưa rõ \(percent)%", "Chưa nhận ra được từ. Chậm lại, nghe mẫu và nói lại nhé.")
            }
        }()

        return VStack(spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().stroke(color.opacity(0.2), lineWidth: 6).frame(width: 54, height: 54)
                    Circle()
                        .trim(from: 0, to: result.score)
                        .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 54, height: 54)
                        .rotationEffect(.degrees(-90))

                    Text("\(percent)")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(color)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(color)
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Spacer()

                Button {
                    HapticFeedback.selection()
                    viewModel.nextItem()
                } label: {
                    HStack(spacing: 5) {
                        Text("Tiếp")
                        Image(systemName: "arrow.right")
                    }
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(AppTheme.primaryGradient)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            if !result.recognizedText.isEmpty {
                Text("Mình nghe được: “\(result.recognizedText)”")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textTertiary)
                    .lineLimit(1)
            }
        }
        .padding(16)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 22)
        .frame(height: 108, alignment: .top)
    }

    // MARK: - Empty & Done States

    private var emptyView: some View {
        VStack(spacing: 14) {
            Image(systemName: "mic.slash.circle.fill")
                .font(.system(size: 52))
                .foregroundStyle(AppTheme.textTertiary)

            Text("Học phần này chưa có từ để luyện nói")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            Text("Thêm từ vựng vào học phần rồi quay lại nhé!")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
        }
    }

    private var sessionDoneView: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(AppTheme.success.opacity(0.12))
                    .frame(width: 96, height: 96)
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(AppTheme.success)
            }

            Text("Hoàn thành buổi luyện nói!")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(AppTheme.textPrimary)

            Text("Kết quả của bạn đã được cập nhật vào lịch ôn tập SM-2.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                HapticFeedback.selection()
                viewModel.restartSession()
            } label: {
                Label("Luyện lại", systemImage: "arrow.counterclockwise")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(AppTheme.primaryGradient)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 30)
    }
}
