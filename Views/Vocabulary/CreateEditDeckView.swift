import SwiftUI
import SwiftData
import PhotosUI

// MARK: - CreateEditDeckView
/// Quizlet-style batch vocabulary creation view for creating new study sets.
struct CreateEditDeckView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var deckName: String = ""
    @State private var deckDescription: String = ""
    @State private var deckColor: String = "#4E73DF"

    @State private var cardInputs: [CardInput] = [CardInput(id: UUID())]

    private let accentColors = [
        "#4E73DF", "#1CC88A", "#36B9CC", "#F6C23E",
        "#E74A3B", "#858796", "#5A5C69", "#6F42C1"
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Deck Info Section
                    deckInfoSection

                    // Color Picker
                    colorPickerSection

                    // Cards Section
                    cardsSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .background(AppTheme.background.ignoresSafeArea(.all))
            .navigationTitle("Tạo học phần mới")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Hủy") {
                        HapticFeedback.light()
                        dismiss()
                    }
                    .foregroundStyle(AppTheme.textSecondary)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu") {
                        saveDeck()
                        dismiss()
                    }
                    .disabled(!canSave)
                    .fontWeight(.bold)
                    .foregroundStyle(canSave ? AppTheme.primary : AppTheme.textTertiary)
                }
            }
        }
    }

    // MARK: - Deck Info Section
    private var deckInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Thông tin học phần")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(AppTheme.textSecondary)
                .textCase(.uppercase)

            VStack(spacing: 10) {
                TextField("Tiêu đề học phần (e.g. Hackers TOEIC - Day 01)", text: $deckName)
                    .font(.headline)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(AppTheme.background)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )

                TextField("Thêm mô tả...", text: $deckDescription, axis: .vertical)
                    .font(.subheadline)
                    .lineLimit(2...4)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(AppTheme.background)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )
            }
        }
    }

    // MARK: - Color Picker Section
    private var colorPickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Màu sắc")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(AppTheme.textSecondary)
                .textCase(.uppercase)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                ForEach(accentColors, id: \.self) { color in
                    Button {
                        HapticFeedback.selection()
                        deckColor = color
                    } label: {
                        Circle()
                            .fill(Color(hex: color))
                            .frame(width: 44, height: 44)
                            .overlay(
                                Circle()
                                    .stroke(deckColor == color ? Color.primary : Color.clear, lineWidth: 3)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Cards Section
    private var cardsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Thẻ từ vựng")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(AppTheme.textSecondary)
                    .textCase(.uppercase)

                Spacer()

                Text("\(cardInputs.count) thẻ")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textTertiary)
            }

            VStack(spacing: 12) {
                ForEach($cardInputs) { card in
                    cardInputView(for: card)
                }

                // Add new card button
                Button {
                    HapticFeedback.selection()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        cardInputs.append(CardInput(id: UUID()))
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                        Text("Thêm thẻ mới")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(AppTheme.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppTheme.primary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func cardInputView(for card: Binding<CardInput>) -> some View {
        VStack(spacing: 10) {
            // Card header with delete button
            HStack {
                Text("Thẻ \(cardInputs.firstIndex(where: { $0.id == card.wrappedValue.id })! + 1)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(AppTheme.textTertiary)

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        if let index = cardInputs.firstIndex(where: { $0.id == card.wrappedValue.id }) {
                            cardInputs.remove(at: index)
                        }
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.danger)
                }
                .buttonStyle(.plain)
            }

            // Term input
            VStack(alignment: .leading, spacing: 4) {
                Text("THUẬT NGỮ")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textTertiary)

                TextField("Từ vựng hoặc cụm từ", text: card.word)
                    .font(.subheadline)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(AppTheme.background)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            // Definition input
            VStack(alignment: .leading, spacing: 4) {
                Text("ĐỊNH NGHĨA")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textTertiary)

                TextField("Nghĩa tiếng Việt", text: card.meaning, axis: .vertical)
                    .font(.subheadline)
                    .lineLimit(2...4)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(AppTheme.background)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            // Optional fields
            VStack(spacing: 8) {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("LOẠI TỪ")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.textTertiary)

                        TextField("noun, verb...", text: card.partOfSpeech)
                            .font(.caption)
                            .textInputAutocapitalization(.never)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(AppTheme.background)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("IPA")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.textTertiary)

                        TextField("/.../", text: card.ipa)
                            .font(.caption)
                            .textInputAutocapitalization(.never)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(AppTheme.background)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("PHIÊN ÂM VIỆT")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textTertiary)

                    TextField("sờ-ké-chồ", text: card.viPhonetic)
                        .font(.caption)
                        .textInputAutocapitalization(.never)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(AppTheme.background)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("GHI CHÚ")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textTertiary)

                    TextField("Ghi chú (ví dụ, ngữ cảnh, lưu ý...)", text: card.note, axis: .vertical)
                        .font(.caption)
                        .lineLimit(2...3)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(AppTheme.background)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
        .padding(14)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Validation
    private var canSave: Bool {
        !deckName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        cardInputs.contains { !$0.word.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    // MARK: - Save
    private func saveDeck() {
        HapticFeedback.success()

        // Create deck
        let deck = VocabularyDeck(
            name: deckName,
            deckDescription: deckDescription,
            colorHex: deckColor
        )
        modelContext.insert(deck)

        // Create vocabulary items from cards
        for card in cardInputs {
            guard !card.word.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }

            let item = VocabularyItem(
                word: card.word,
                ipa: card.ipa,
                viPhonetic: card.viPhonetic,
                partOfSpeech: card.partOfSpeech,
                meaning: card.meaning,
                note: card.note
            )
            modelContext.insert(item)
            deck.items.append(item)
        }

        try? modelContext.save()
    }
}

// MARK: - CardInput Model
struct CardInput: Identifiable {
    let id: UUID
    var word: String = ""
    var meaning: String = ""
    var partOfSpeech: String = ""
    var ipa: String = ""
    var viPhonetic: String = ""
    var note: String = ""
}
