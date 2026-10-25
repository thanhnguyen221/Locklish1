import SwiftUI
import SwiftData

// MARK: - AddEditWordView
/// Creates and updates vocabulary words and phrases while preserving existing
/// vocabulary, notes, and SRS fields on `VocabularyItem`.
struct AddEditWordView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var existingItem: VocabularyItem?
    var deck: VocabularyDeck? = nil  // Pre-selected deck for new items

    @Query(sort: \VocabularyDeck.createdAt, order: .reverse) private var existingDecks: [VocabularyDeck]
    @State private var selectedDeck: VocabularyDeck?
    @State private var isCreatingNewDeck = false
    @State private var newDeckName = ""

    @State private var word = ""
    @State private var ipa = ""
    @State private var viPhonetic = ""
    @State private var partOfSpeech = ""
    @State private var meaning = ""
    @State private var example = ""
    @State private var exampleTranslation = ""
    @State private var note = ""
    @State private var unitTag = ""
    @State private var imageData: Data?
    @State private var isMastered = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case word, ipa, viPhonetic, partOfSpeech, meaning, example, exampleTranslation, note, unitTag
    }

    private var isEditing: Bool { existingItem != nil }
    private var canSave: Bool {
        !word.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    wordAndPronunciationForm
                    meaningAndNotesForm
                    collectionForm
                    imageForm
                    masteryForm
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .background(AppTheme.background.ignoresSafeArea(.all))
            .navigationTitle(isEditing ? "Chỉnh sửa từ vựng" : "Thêm từ vựng")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Hủy") { HapticFeedback.light(); dismiss() }
                        .foregroundStyle(AppTheme.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu") { saveItem(); dismiss() }
                        .disabled(!canSave)
                        .fontWeight(.bold)
                        .foregroundStyle(canSave ? AppTheme.primary : AppTheme.textTertiary)
                }
            }
            .onAppear(perform: loadExistingItem)
        }
    }

    // MARK: - Word & Pronunciation
    private var wordAndPronunciationForm: some View {
        sectionCard(title: "Từ vựng / Cụm từ & phát âm", icon: "character.cursor.ibeam") {
            formField(
                placeholder: "Từ vựng hoặc cụm từ (vd: Schedule, take note of)",
                text: $word, field: .word, autocapitalization: .never, autocorrect: false,
                trailingView: word.isEmpty ? nil : AnyView(AudioSpeakerButton(word: word, size: 32, iconSize: 14, tintColor: AppTheme.primary))
            )
            formField(placeholder: "Phiên âm IPA (vd: /ˈskedʒ.uːl/)", text: $ipa, field: .ipa,
                      font: .system(.body, design: .monospaced), autocapitalization: .never)
            VStack(alignment: .leading, spacing: 4) {
                formField(placeholder: "Phiên âm tiếng Việt (vd: sờ-ké-chồ)", text: $viPhonetic, field: .viPhonetic, autocapitalization: .never)
                Text("Ghi cách đọc dễ nhớ theo tiếng Việt nếu cần.")
                    .font(.caption2).foregroundStyle(AppTheme.textTertiary).padding(.horizontal, 4)
            }
            formField(placeholder: "Loại từ (vd: noun, verb, phrasal verb, idiom...)", text: $partOfSpeech, field: .partOfSpeech, autocapitalization: .never)
        }
    }

    // MARK: - Meaning, Example & Notes
    private var meaningAndNotesForm: some View {
        sectionCard(title: "Nghĩa, Ví dụ & Ghi chú", icon: "text.book.closed") {
            formField(placeholder: "Nghĩa tiếng Việt", text: $meaning, field: .meaning, axis: .vertical)

            VStack(alignment: .leading, spacing: 6) {
                formField(placeholder: "Câu ví dụ tiếng Anh (vd: The superhero had to reveal...)", text: $example, field: .example, axis: .vertical, autocapitalization: .sentences)
                formField(placeholder: "Dịch câu ví dụ (vd: Siêu anh hùng phải tiết lộ...)", text: $exampleTranslation, field: .exampleTranslation, axis: .vertical, autocapitalization: .sentences)
            }

            VStack(alignment: .leading, spacing: 4) {
                formField(placeholder: "Ghi chú thêm (lưu ý ngữ pháp, ngữ cảnh, cấu trúc...)", text: $note, field: .note, axis: .vertical, autocapitalization: .sentences)
                Text("Tách riêng ví dụ và ghi chú giúp hiển thị flashcard rõ ràng và khoa học hơn.")
                    .font(.caption2).foregroundStyle(AppTheme.textTertiary).padding(.horizontal, 4)
            }
        }
    }

    // MARK: - Collection / Deck
    private var collectionForm: some View {
        sectionCard(title: "Bộ từ & phân nhóm", icon: "folder") {
            deckPicker
            formField(placeholder: "Nhãn đơn vị / nhóm học (vd: Tuần 2, Bài 01, Chương 3)", text: $unitTag, field: .unitTag)
        }
    }

    private var deckPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Thuộc bộ từ").font(.subheadline).foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Menu {
                    Button { selectedDeck = nil; isCreatingNewDeck = false } label: {
                        Label("Chưa gán bộ từ", systemImage: selectedDeck == nil && !isCreatingNewDeck ? "checkmark" : "")
                    }
                    if !existingDecks.isEmpty {
                        Divider()
                        ForEach(existingDecks) { deck in
                            Button { selectedDeck = deck; isCreatingNewDeck = false } label: {
                                Label(deck.name, systemImage: selectedDeck?.id == deck.id && !isCreatingNewDeck ? "checkmark" : "")
                            }
                        }
                    }
                    Divider()
                    Button { isCreatingNewDeck = true; selectedDeck = nil } label: {
                        Label("Tạo bộ từ mới…", systemImage: "plus.circle")
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(isCreatingNewDeck ? "Bộ từ mới…" : (selectedDeck?.name ?? "Chưa gán"))
                        Image(systemName: "chevron.up.chevron.down").font(.caption2)
                    }
                    .font(.subheadline.weight(.semibold)).foregroundStyle(AppTheme.primary)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(AppTheme.primary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
            if isCreatingNewDeck {
                TextField("Nhập tên bộ từ mới…", text: $newDeckName)
                    .font(.subheadline).padding(.horizontal, 14).padding(.vertical, 12)
                    .background(AppTheme.background)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(AppTheme.accent.opacity(0.4), lineWidth: 1))
            }
        }
    }

    // MARK: - Image
    private var imageForm: some View {
        sectionCard(title: "Ảnh gợi nhớ trực quan", icon: "photo") {
            WordImagePickerView(imageData: $imageData, height: 170, allowsEditing: true)
            if imageData != nil {
                Button(role: .destructive) { HapticFeedback.light(); imageData = nil } label: {
                    Label("Xóa ảnh hiện tại", systemImage: "trash").font(.caption).foregroundStyle(AppTheme.danger)
                }
            }
        }
    }

    // MARK: - Mastery
    private var masteryForm: some View {
        HStack(spacing: 14) {
            Image(systemName: isMastered ? "checkmark.seal.fill" : "seal")
                .font(.system(size: 20)).foregroundStyle(isMastered ? AppTheme.success : AppTheme.primary)
                .frame(width: 40, height: 40).background((isMastered ? AppTheme.success : AppTheme.primary).opacity(0.10)).clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text("Đã thuộc mục này").font(.body.weight(.medium)).foregroundStyle(AppTheme.textPrimary)
                Text("Xếp vào nhóm đã ghi nhớ").font(.caption).foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
            Toggle("", isOn: $isMastered).labelsHidden().tint(AppTheme.success)
        }
        .padding(18).locklishCardStyle(cornerRadius: AppTheme.cornerRadiusMedium)
    }

    @ViewBuilder
    private func sectionCard<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: icon).font(.caption.weight(.bold)).foregroundStyle(AppTheme.textSecondary).textCase(.uppercase).tracking(0.5)
            VStack(spacing: 10, content: content)
        }
        .padding(18).locklishCardStyle(cornerRadius: AppTheme.cornerRadiusMedium)
    }

    @ViewBuilder
    private func formField(
        placeholder: String, text: Binding<String>, field: Field, font: Font = .body,
        axis: Axis = .horizontal, autocapitalization: TextInputAutocapitalization = .words,
        autocorrect: Bool = true, trailingView: AnyView? = nil
    ) -> some View {
        HStack {
            TextField(placeholder, text: text, axis: axis)
                .focused($focusedField, equals: field).font(font)
                .lineLimit(axis == .vertical ? 2...5 : 1...1)
                .textInputAutocapitalization(autocapitalization).autocorrectionDisabled(!autocorrect)
            if let trailingView { trailingView }
        }
        .padding(.horizontal, 14).padding(.vertical, 12).background(AppTheme.background)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(focusedField == field ? AppTheme.primary.opacity(0.4) : Color.primary.opacity(0.06), lineWidth: 1.5))
    }

    private func loadExistingItem() {
        guard let item = existingItem else {
            // New item: use pre-selected deck if provided
            if let preselectedDeck = deck {
                selectedDeck = preselectedDeck
            }
            focusedField = .word
            return
        }
        word = item.word
        ipa = item.ipa
        viPhonetic = item.viPhonetic
        partOfSpeech = item.partOfSpeech
        meaning = item.meaning

        let content = item.separatedContent
        example = content.example
        exampleTranslation = content.translation
        note = content.note

        unitTag = item.unitTag ?? ""
        imageData = item.imageData
        isMastered = item.isMastered
        // Find which deck this item belongs to
        selectedDeck = existingDecks.first { ($0.items ?? []).contains(where: { $0.id == item.id }) }
        focusedField = .word
    }

    private func saveItem() {
        HapticFeedback.success()
        var targetDeck = selectedDeck
        let cleanNewDeckName = newDeckName.trimmingCharacters(in: .whitespacesAndNewlines)
        if isCreatingNewDeck && !cleanNewDeckName.isEmpty {
            let createdDeck = VocabularyDeck(name: cleanNewDeckName)
            modelContext.insert(createdDeck)
            targetDeck = createdDeck
        }
        if let item = existingItem {
            update(item, deck: targetDeck)
        } else {
            let item = VocabularyItem(
                word: word,
                ipa: ipa,
                viPhonetic: viPhonetic,
                partOfSpeech: partOfSpeech,
                meaning: meaning,
                note: note,
                example: example,
                exampleTranslation: exampleTranslation,
                imageData: imageData,
                isMastered: isMastered,
                itemType: "word",
                unitTag: unitTag
            )
            modelContext.insert(item)
            if let targetDeck = targetDeck {
                targetDeck.items = (targetDeck.items ?? []) + [item]
            }
        }
        try? modelContext.save()
    }

    private func update(_ item: VocabularyItem, deck: VocabularyDeck?) {
        item.word = word.trimmingCharacters(in: .whitespacesAndNewlines)
        item.meaning = meaning.trimmingCharacters(in: .whitespacesAndNewlines)
        item.example = example.trimmingCharacters(in: .whitespacesAndNewlines)
        item.exampleTranslation = exampleTranslation.trimmingCharacters(in: .whitespacesAndNewlines)
        item.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        item.unitTag = unitTag.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        item.itemType = "word"
        item.isMastered = isMastered
        item.ipa = ipa.trimmingCharacters(in: .whitespacesAndNewlines)
        item.viPhonetic = viPhonetic.trimmingCharacters(in: .whitespacesAndNewlines)
        item.partOfSpeech = partOfSpeech.trimmingCharacters(in: .whitespacesAndNewlines)
        item.imageData = imageData
        item.questionSentence = nil
        item.options = nil
        item.correctOptionIndex = nil

        // Manage deck relation if needed
        if let targetDeck = deck {
            if !(targetDeck.items ?? []).contains(where: { $0.id == item.id }) {
                // Remove from other decks
                for d in existingDecks where d.id != targetDeck.id {
                    d.items?.removeAll(where: { $0.id == item.id })
                }
                targetDeck.items = (targetDeck.items ?? []) + [item]
            }
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
