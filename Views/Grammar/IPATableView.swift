import SwiftUI

// MARK: - IPATableView
/// Pronunciation reference: 3 tabs (đơn/đôi/phụ âm), accent toggle (US/UK),
/// tap any card to hear the example word, plus the Vietnamese-learner
/// special rules (-s/-es, -ed, final consonants).
struct IPATableView: View {
    enum IPATab: String, CaseIterable, Identifiable {
        case monophthongs = "Nguyên âm đơn"
        case diphthongs = "Nguyên âm đôi"
        case consonants = "Phụ âm"

        var id: String { rawValue }
    }

    @State private var tab: IPATab = .monophthongs
    @State private var progress = GrammarProgressStore.shared
    private let service = GrammarDataService.shared

    var body: some View {
        let ipa = service.ipa

        return Group {
            if let ipa {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Accent toggle
                        HStack(spacing: 8) {
                            Text("Giọng đọc")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)

                            Picker("Giọng đọc", selection: Binding(
                                get: { progress.ipaAccent },
                                set: { newValue in
                                    HapticFeedback.selection()
                                    progress.ipaAccent = newValue
                                }
                            )) {
                                Text("Anh - Mỹ").tag("en-US")
                                Text("Anh - Anh").tag("en-GB")
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 180)

                            Spacer()
                        }
                        .padding(.horizontal, 4)

                        // Sub-tabs
                        Picker("Nhóm âm", selection: $tab) {
                            ForEach(IPATab.allCases) { t in
                                Text(t.rawValue).tag(t)
                            }
                        }
                        .pickerStyle(.segmented)

                        switch tab {
                        case .monophthongs:
                            sectionLabel("12 nguyên âm đơn", note: "Nhấn thẻ để nghe từ ví dụ")
                            grid {
                                ForEach(ipa.vowelsMonophthongs) { item in
                                    soundCard(
                                        symbol: item.symbol,
                                        badge: item.type == "long" ? "Dài" : "Ngắn",
                                        badgeColor: nil,
                                        tint: item.type == "long" ? Color(red: 0.30, green: 0.45, blue: 0.96) : Color(red: 0.98, green: 0.55, blue: 0.15),
                                        example: item.example,
                                        tip: item.tipVi
                                    )
                                }
                            }
                        case .diphthongs:
                            sectionLabel("8 nguyên âm đôi", note: "Âm trượt từ một nguyên âm sang nguyên âm khác")
                            grid {
                                ForEach(ipa.vowelsDiphthongs) { item in
                                    soundCard(symbol: item.symbol, badge: nil, badgeColor: nil, tint: Color(red: 0.62, green: 0.36, blue: 0.96), example: item.example, tip: item.tipVi)
                                }
                            }
                        case .consonants:
                            sectionLabel("24 phụ âm", note: "Hữu thanh = dây thanh rung khi phát âm")
                            grid {
                                ForEach(ipa.consonants) { item in
                                    soundCard(
                                        symbol: item.symbol,
                                        badge: item.voiced ? "Hữu thanh" : "Vô thanh",
                                        badgeColor: nil,
                                        tint: item.voiced ? Color(red: 0.06, green: 0.66, blue: 0.52) : Color(red: 0.45, green: 0.50, blue: 0.58),
                                        example: item.example,
                                        tip: item.tipVi
                                    )
                                }
                            }
                        }

                        // Special rules for Vietnamese learners
                        if !ipa.specialRulesVi.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Label("LUẬT ĐỌC ĐẶC BIỆT — NGƯỜI VIỆT HAY MẮC", systemImage: "exclamationmark.bubble.fill")
                                    .font(.caption)
                                    .fontWeight(.heavy)
                                    .foregroundStyle(AppTheme.warning)

                                ForEach(Array(ipa.specialRulesVi.enumerated()), id: \.offset) { _, rule in
                                    HStack(alignment: .top, spacing: 8) {
                                        Circle()
                                            .fill(AppTheme.warning.opacity(0.5))
                                            .frame(width: 6, height: 6)
                                            .padding(.top, 5)
                                        Text(rule)
                                            .font(.caption)
                                            .foregroundStyle(AppTheme.textSecondary)
                                            .lineSpacing(3)
                                    }
                                }
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppTheme.warning.opacity(0.07))
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
                        }

                        // Stress marks legend
                        if !ipa.stressMarks.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("KÝ HIỆU NHẤN ÂM")
                                    .font(.caption)
                                    .fontWeight(.heavy)
                                    .foregroundStyle(AppTheme.textSecondary)
                                ForEach(Array(ipa.stressMarks.sorted(by: { $0.key < $1.key }).enumerated()), id: \.offset) { _, pair in
                                    HStack(spacing: 10) {
                                        Text(pair.key)
                                            .font(.system(size: 18, weight: .bold, design: .rounded))
                                            .foregroundStyle(AppTheme.primary)
                                            .frame(width: 30)
                                        Text(pair.value)
                                            .font(.caption)
                                            .foregroundStyle(AppTheme.textSecondary)
                                    }
                                }
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppTheme.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
                        }

                        Spacer(minLength: 30)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "waveform.slash")
                        .font(.system(size: 40))
                        .foregroundStyle(AppTheme.textTertiary)
                    Text("Không tải được dữ liệu IPA")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: - Building blocks

    private func sectionLabel(_ title: String, note: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(AppTheme.textSecondary)
            Text(note)
                .font(.caption2)
                .foregroundStyle(AppTheme.textTertiary)
        }
        .padding(.horizontal, 4)
    }

    private func grid<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10, content: content)
    }

    /// One IPA sound: big symbol + (badge) + example with speak + Vietnamese tip.
    /// Whole card is tappable to hear the example word; tinted by sound group.
    private func soundCard(symbol: String, badge: String?, badgeColor: Color?, tint: Color, example: String, tip: String) -> some View {
        Button {
            HapticFeedback.selection()
            let word = example.components(separatedBy: " /").first?.trimmingCharacters(in: .whitespaces) ?? example
            TTSService.shared.speak(text: word, voiceLanguage: progress.ipaAccent)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(symbol)
                        .font(.system(size: 27, weight: .heavy, design: .rounded))
                        .foregroundStyle(tint)

                    Spacer()

                    if let badge {
                        Text(badge)
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2.5)
                            .background(Capsule().fill(LinearGradient(colors: [tint, tint.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)))
                    }
                }

                Text(example)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(tip)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineSpacing(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 4) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 9))
                    Text("Nghe")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(tint)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(AppTheme.cardBackground)
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(LinearGradient(colors: [tint.opacity(0.10), tint.opacity(0.03)], startPoint: .topLeading, endPoint: .bottomTrailing))
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(tint.opacity(0.18), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Âm \(symbol), ví dụ \(example)")
        .accessibilityHint("Chạm để nghe phát âm")
    }
}
