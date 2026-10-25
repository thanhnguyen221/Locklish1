import SwiftUI
import SwiftData

// MARK: - VocabularyDetailView
/// In-depth view for a vocabulary word — full-screen, elegant, and well-spaced.
struct VocabularyDetailView: View {
    @Environment(\.modelContext) private var modelContext

    @Bindable var item: VocabularyItem
    @State private var isEditSheetPresented: Bool = false
    @Query private var decks: [VocabularyDeck]

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {

                // ── Hero Card: Word + Pronunciation ──────────────────────────
                VStack(spacing: 0) {
                    // Gradient banner at top of hero card
                    LinearGradient(
                        colors: [AppTheme.primary.opacity(0.12), AppTheme.cardBackground],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(height: 6)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusCard, style: .continuous))

                    VStack(spacing: 16) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(item.word)
                                    .font(.system(size: 30, weight: .bold, design: .rounded))
                                    .foregroundStyle(AppTheme.textPrimary)
                                    .minimumScaleFactor(0.7)
                                    .lineLimit(2)

                                // IPA
                                Text(item.ipa)
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.textSecondary)

                                // Vietnamese phonetic
                                HStack(spacing: 5) {
                                    Image(systemName: "waveform")
                                        .font(.caption)
                                    Text(item.viPhonetic)
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                }
                                .foregroundStyle(AppTheme.primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 5)
                                .background(AppTheme.primary.opacity(0.1))
                                .clipShape(Capsule())

                                // Part of speech
                                if !item.partOfSpeech.isEmpty {
                                    Text(item.partOfSpeech)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(AppTheme.textSecondary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 5)
                                        .background(Color.primary.opacity(0.06))
                                        .clipShape(Capsule())
                                }

                                if let deck = decks.first(where: { ($0.items ?? []).contains(where: { $0.id == item.id }) }) {
                                    HStack(spacing: 5) {
                                        Image(systemName: "folder.fill")
                                            .font(.caption2)
                                        Text(deck.name)
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                    }
                                    .foregroundStyle(deck.accentColor)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(deck.accentColor.opacity(0.12))
                                    .clipShape(Capsule())
                                }
                            }

                            Spacer()

                            AudioSpeakerButton(word: item.word, size: 52, iconSize: 22, tintColor: AppTheme.primary)
                        }

                        Divider()
                            .background(Color.primary.opacity(0.06))

                        // Mastery toggle
                        HStack {
                            Button(action: {
                                HapticFeedback.light()
                                item.isMastered.toggle()
                                try? modelContext.save()
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: item.isMastered ? "checkmark.circle.fill" : "circle")
                                    Text(item.isMastered ? "Đã ghi nhớ thành thạo" : "Cần ôn tập thêm")
                                }
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(item.isMastered ? AppTheme.success : AppTheme.warning)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background((item.isMastered ? AppTheme.success : AppTheme.warning).opacity(0.12))
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)

                            Spacer()

                            Text("Thêm: \(item.createdAt.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption2)
                                .foregroundStyle(AppTheme.textTertiary)
                        }
                    }
                    .padding(22)
                }
                .locklishCardStyle(cornerRadius: AppTheme.cornerRadiusCard)

                // Images are intentionally read-only here. Adding, replacing, and
                // deleting them lives in AddEditWordView to keep study screens clean.
                if let imageData = item.imageData, let image = UIImage(data: imageData) {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Ảnh gợi nhớ trực quan", systemImage: "photo")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(AppTheme.textSecondary)
                            .textCase(.uppercase)

                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 200)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
                    }
                    .padding(22)
                    .locklishCardStyle(cornerRadius: AppTheme.cornerRadiusCard)
                }

                // ── Meaning & Example ────────────────────────────────────────
                VStack(alignment: .leading, spacing: 20) {
                    // Meaning
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Định nghĩa", systemImage: "text.book.closed")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(AppTheme.textSecondary)
                            .textCase(.uppercase)

                        Text(item.meaning)
                            .font(.body)
                            .lineSpacing(4)
                            .foregroundStyle(AppTheme.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Divider()
                        .background(Color.primary.opacity(0.06))

                    let content = item.separatedContent

                    // Example Section
                    if !content.example.isEmpty || !content.translation.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Label("Ví dụ minh họa", systemImage: "quote.opening")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundStyle(AppTheme.textSecondary)
                                    .textCase(.uppercase)

                                Spacer()

                                if !content.example.isEmpty {
                                    AudioSpeakerButton(word: content.example, size: 28, iconSize: 12, tintColor: AppTheme.primary)
                                }
                            }

                            if !content.example.isEmpty {
                                Text(content.example)
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .lineSpacing(4)
                                    .foregroundStyle(AppTheme.textPrimary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            if !content.translation.isEmpty {
                                Text(content.translation)
                                    .font(.subheadline)
                                    .lineSpacing(3)
                                    .foregroundStyle(AppTheme.textSecondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }

                        if !content.note.isEmpty {
                            Divider()
                                .background(Color.primary.opacity(0.06))
                        }
                    }

                    // Notes Section
                    if !content.note.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Ghi chú & Lưu ý", systemImage: "note.text")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(AppTheme.textSecondary)
                                .textCase(.uppercase)

                            Text(content.note)
                                .font(.body)
                                .lineSpacing(4)
                                .foregroundStyle(AppTheme.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    } else if content.example.isEmpty && content.translation.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Ghi chú & Ví dụ", systemImage: "note.text")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(AppTheme.textSecondary)
                                .textCase(.uppercase)

                            Text("Chưa có ghi chú hoặc ví dụ.")
                                .font(.body)
                                .lineSpacing(4)
                                .foregroundStyle(AppTheme.textTertiary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding(22)
                .locklishCardStyle(cornerRadius: AppTheme.cornerRadiusCard)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .background(AppTheme.background.ignoresSafeArea(.all))
        .toolbar(.hidden, for: .tabBar)
        .navigationTitle(item.word)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    HapticFeedback.light()
                    isEditSheetPresented = true
                } label: {
                    Text("Sửa")
                        .fontWeight(.semibold)
                        .foregroundStyle(AppTheme.primary)
                }
            }
        }
        .fullScreenCover(isPresented: $isEditSheetPresented) {
            AddEditWordView(existingItem: item)
        }
    }
}
