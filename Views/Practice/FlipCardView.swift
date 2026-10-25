import SwiftUI

// MARK: - FlipCardView
/// A rich, interactive 3D flashcard displaying complete vocabulary information:
/// word, pronunciation (both US IPA and natural Vietnamese phonetics), part of speech,
/// visual memory image, full Vietnamese definition, and flexible notes / examples.
struct FlipCardView: View {
    let item: VocabularyItem
    let isFlipped: Bool
    let rotationAngle: Double
    let onFlip: () -> Void

    var body: some View {
        GeometryReader { geo in
            ZStack {
                frontCard(geo: geo)
                    .opacity(isFrontVisible ? 1 : 0)
                    .rotation3DEffect(.degrees(rotationAngle), axis: (x: 0, y: 1, z: 0))
                backCard
                    .opacity(isFrontVisible ? 0 : 1)
                    .rotation3DEffect(.degrees(rotationAngle + 180), axis: (x: 0, y: 1, z: 0))
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            // Guard: Never flip the card if the user tapped the audio speaker button
            guard Date().timeIntervalSince(AudioSpeakerButton.lastTapTime) > 0.45 else { return }
            onFlip()
        }
    }

    private var isFrontVisible: Bool {
        let normalized = Int(abs(rotationAngle)) % 360
        return normalized < 90 || normalized > 270
    }

    // MARK: - Front Card
    private func frontCard(geo: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            // Visual Image (if present)
            if let data = item.imageData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: geo.size.height * 0.35)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
            }

            VStack(spacing: 12) {
                // Word / Phrase
                Text(item.word)
                    .font(.system(size: min(34, geo.size.width * 0.085), weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.65)
                    .lineLimit(2)
                    .padding(.horizontal, 16)

                // Part of Speech Badge (noun, verb, phrasal verb, etc.)
                if !item.partOfSpeech.isEmpty {
                    Text(item.partOfSpeech.lowercased())
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(AppTheme.primary.opacity(0.12))
                        .clipShape(Capsule())
                }

                // Complete Phonetics: IPA + Vietnamese natural phonetic
                if !item.ipa.isEmpty || !item.viPhonetic.isEmpty {
                    VStack(spacing: 6) {
                        if !item.ipa.isEmpty {
                            Text(item.ipa)
                                .font(.system(.subheadline, design: .monospaced))
                                .foregroundStyle(AppTheme.textSecondary)
                        }

                        if !item.viPhonetic.isEmpty {
                            HStack(spacing: 5) {
                                Image(systemName: "waveform")
                                    .font(.caption2)
                                Text(item.viPhonetic)
                                    .font(.subheadline.weight(.bold))
                            }
                            .foregroundStyle(AppTheme.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(AppTheme.primary.opacity(0.08))
                            .clipShape(Capsule())
                        }
                    }
                }

                // Unit / Group Tag
                if let unitTag = item.unitTag, !unitTag.isEmpty {
                    Text(unitTag)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(AppTheme.textTertiary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.primary.opacity(0.04))
                        .clipShape(Capsule())
                }
            }
            .padding(.top, item.imageData == nil ? 36 : 14)
            .padding(.horizontal, 16)

            // Audio Speaker
            AudioSpeakerButton(word: item.word, size: 48, iconSize: 20, tintColor: AppTheme.primary)
                .padding(.top, 14)

            Spacer()

            flipHint("Chạm để lật xem nghĩa & ghi chú")
        }
        .cardFaceStyle(isBack: false)
    }

    // MARK: - Back Card
    private var backCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: Word + Part of Speech + Speaker
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.word)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(AppTheme.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    if !item.partOfSpeech.isEmpty {
                        Text(item.partOfSpeech.lowercased())
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(AppTheme.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(AppTheme.primary.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }

                Spacer()

                AudioSpeakerButton(word: item.word, size: 38, iconSize: 16, tintColor: AppTheme.primary)
            }
            .padding(.horizontal, 22)
            .padding(.top, 22)

            // Complete Pronunciation Info on Back (Both IPA & Vietnamese Phonetics)
            if !item.ipa.isEmpty || !item.viPhonetic.isEmpty {
                HStack(spacing: 8) {
                    if !item.ipa.isEmpty {
                        Text(item.ipa)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(AppTheme.textSecondary)
                    }

                    if !item.ipa.isEmpty && !item.viPhonetic.isEmpty {
                        Text("•")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textTertiary)
                    }

                    if !item.viPhonetic.isEmpty {
                        HStack(spacing: 3) {
                            Image(systemName: "waveform")
                                .font(.system(size: 10))
                            Text(item.viPhonetic)
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(AppTheme.primary)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 6)
            }

            Divider()
                .background(Color.primary.opacity(0.06))
                .padding(.horizontal, 22)
                .padding(.top, 12)

            // Scrollable Content: Meaning & Notes
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Definition / Meaning
                    VStack(alignment: .leading, spacing: 6) {
                        sectionTitle("Ý NGHĨA")
                        Text(item.meaning)
                            .font(.title3.weight(.semibold))
                            .lineSpacing(4)
                            .foregroundStyle(AppTheme.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(14)
                    .background(AppTheme.primary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    // Separated Example & Notes
                    let content = item.separatedContent

                    // 1. Example Section
                    if !content.example.isEmpty || !content.translation.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                sectionTitle("VÍ DỤ")
                                Spacer()
                                if !content.example.isEmpty {
                                    AudioSpeakerButton(word: content.example, size: 24, iconSize: 11, tintColor: AppTheme.primary)
                                }
                            }

                            if !content.example.isEmpty {
                                Text(content.example)
                                    .font(.system(size: 15, weight: .medium))
                                    .lineSpacing(4)
                                    .foregroundStyle(AppTheme.textPrimary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            if !content.translation.isEmpty {
                                Text(content.translation)
                                    .font(.system(size: 14))
                                    .foregroundStyle(AppTheme.textSecondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(14)
                        .background(AppTheme.background)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    // 2. Note Section
                    if !content.note.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            sectionTitle("GHI CHÚ")

                            Text(content.note)
                                .font(.system(size: 14))
                                .lineSpacing(4)
                                .foregroundStyle(AppTheme.textPrimary.opacity(0.9))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(14)
                        .background(AppTheme.primary.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    // 3. Fallback if both empty
                    if content.example.isEmpty && content.translation.isEmpty && content.note.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            sectionTitle("GHI CHÚ & VÍ DỤ")
                            Text("Chưa có ghi chú hoặc câu ví dụ cho mục này.")
                                .font(.callout)
                                .italic()
                                .foregroundStyle(AppTheme.textTertiary)
                        }
                        .padding(14)
                        .background(AppTheme.background)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    // Mastery Status Badge
                    HStack(spacing: 6) {
                        Image(systemName: item.isMastered ? "checkmark.circle.fill" : "clock.arrow.circlepath")
                            .font(.caption)
                        Text(item.isMastered ? "Đã ghi nhớ thành thạo" : "Đang trong lộ trình ôn tập")
                            .font(.caption2.weight(.medium))
                    }
                    .foregroundStyle(item.isMastered ? AppTheme.success : AppTheme.warning)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background((item.isMastered ? AppTheme.success : AppTheme.warning).opacity(0.1))
                    .clipShape(Capsule())
                    .padding(.top, 2)
                }
                .padding(.horizontal, 22)
                .padding(.top, 14)
                .padding(.bottom, 12)
            }

            Spacer(minLength: 0)

            flipHint("Chạm để lật lại mặt trước")
        }
        .cardFaceStyle(isBack: true)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.caption2.weight(.bold))
            .foregroundStyle(AppTheme.textTertiary)
            .tracking(1)
    }

    private func flipHint(_ text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "arrow.triangle.2.circlepath")
            Text(text)
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(AppTheme.textTertiary)
        .frame(maxWidth: .infinity)
        .padding(.bottom, 16)
    }
}

private extension View {
    func cardFaceStyle(isBack: Bool) -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                if isBack {
                    AppTheme.cardBackground
                } else {
                    LinearGradient(
                        colors: [AppTheme.primary.opacity(0.06), AppTheme.cardBackground],
                        startPoint: .top, endPoint: .init(x: 0.5, y: 0.45)
                    )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusCard, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusCard, style: .continuous)
                .stroke((isBack ? AppTheme.primary.opacity(0.12) : Color.primary.opacity(0.07)), lineWidth: isBack ? 0.8 : 0.5))
            .shadow(color: isBack ? AppTheme.primary.opacity(0.08) : Color.black.opacity(0.05), radius: 16, x: 0, y: 6)
    }
}
