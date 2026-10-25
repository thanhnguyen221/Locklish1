import SwiftUI
import SwiftData

// MARK: - DeckDetailView
/// Detail view for a specific vocabulary deck with quick actions and item list.
struct DeckDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var deck: VocabularyDeck

    @State private var isAddWordPresented = false
    @State private var editingItem: VocabularyItem? = nil
    @State private var itemToDelete: VocabularyItem? = nil
    @State private var showDeleteConfirmation = false

    /// Words whose SM-2 review lands today or earlier (single pass).
    private var dueWordCount: Int {
        let startOfTomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date())) ?? Date()
        var count = 0
        for item in deck.items where item.lastReviewedDate != nil && item.nextReviewDate < startOfTomorrow {
            count += 1
        }
        return count
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header Section
                headerSection

                // Quick Actions
                quickActionsSection

                // Vocabulary Items List
                vocabularyItemsSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .confirmationDialog("Xoá từ vựng?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Xoá \"\(itemToDelete?.word ?? "từ này")\"", role: .destructive) {
                if let it = itemToDelete {
                    deleteItem(it)
                }
            }
            Button("Huỷ", role: .cancel) {
                itemToDelete = nil
            }
        } message: {
            Text("Từ này sẽ bị xoá khỏi học phần \"\(deck.name)\".")
        }
        .background(AppTheme.background.ignoresSafeArea(.all))
        .navigationTitle(deck.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 10) {
                    NavigationLink(destination: DeckStatsView(deck: deck)) {
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(AppTheme.primary)
                            .frame(width: 30, height: 30)
                            .background(AppTheme.primary.opacity(0.12))
                            .clipShape(Circle())
                    }

                    // Export deck as CSV (importable into Anki / Excel / Quizlet)
                    ShareLink(item: deckCSVFile) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(AppTheme.accent)
                            .frame(width: 30, height: 30)
                            .background(AppTheme.accent.opacity(0.12))
                            .clipShape(Circle())
                    }

                    Button {
                        HapticFeedback.light()
                        isAddWordPresented = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .background(AppTheme.primary)
                            .clipShape(Circle())
                    }
                }
            }
        }
        .sheet(isPresented: $isAddWordPresented) {
            AddEditWordView(existingItem: nil, deck: deck)
        }
        .sheet(item: $editingItem) { item in
            AddEditWordView(existingItem: item, deck: deck)
        }
    }

    // MARK: - CSV Export (Anki / Excel / Quizlet compatible)
    private var deckCSVFile: URL {
        let csv = deckCSVString
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(deck.name.replacingOccurrences(of: "/", with: "-"))-locklish.csv")
        // UTF-8 BOM so Excel opens Vietnamese text correctly
        try? ("\u{FEFF}" + csv).data(using: .utf8)?.write(to: url, options: .atomic)
        return url
    }

    private var deckCSVString: String {
        func escape(_ field: String) -> String {
            let value = field.replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "\r", with: " ")
            if value.contains(";") || value.contains("\"") {
                return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
            }
            return value
        }

        var lines = ["Word;IPA;Part of Speech;Meaning;Vietnamese Phonetic;Example;Example Translation"]
        for item in deck.items {
            lines.append([
                item.word,
                item.ipa,
                item.partOfSpeech,
                item.meaning,
                item.viPhonetic,
                item.example,
                item.exampleTranslation
            ].map(escape).joined(separator: ";"))
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Progress
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(deck.masteredCount) / \(deck.wordCount) từ đã thuộc")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(AppTheme.textPrimary)

                    if !deck.deckDescription.isEmpty {
                        Text(deck.deckDescription)
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }

                Spacer()

                // Progress circle
                ZStack {
                    Circle()
                        .stroke(Color.primary.opacity(0.1), lineWidth: 8)
                        .frame(width: 60, height: 60)

                    Circle()
                        .trim(from: 0, to: deck.progressRatio)
                        .stroke(deck.accentColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: deck.progressRatio)

                    Text("\(Int(deck.progressRatio * 100))%")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(deck.accentColor)
                }
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: 8)

                    Capsule()
                        .fill(deck.accentColor)
                        .frame(width: geo.size.width * deck.progressRatio, height: 8)
                        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: deck.progressRatio)
                }
            }
            .frame(height: 8)
        }
        .padding(16)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Quick Actions Section
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Luyện tập nhanh")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(AppTheme.textSecondary)
                .textCase(.uppercase)

            // Due-review accelerator: appears only when the SM-2 schedule has work today
            if dueWordCount > 0 {
                NavigationLink(destination: FlashcardPracticeView(selectedDeck: deck)) {
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(AppTheme.warning.opacity(0.15))
                                .frame(width: 38, height: 38)
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(AppTheme.warning)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Ôn ngay \(dueWordCount) từ đến hạn")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundStyle(AppTheme.textPrimary)
                            Text("Lịch SM-2 đang chờ — ôn trước khi quên")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(AppTheme.warning)
                    }
                    .padding(12)
                    .background(AppTheme.warning.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(AppTheme.warning.opacity(0.25), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .simultaneousGesture(TapGesture().onEnded { HapticFeedback.selection() })
            }

            HStack(spacing: 10) {
                // Flashcard
                NavigationLink(destination: FlashcardPracticeView(selectedDeck: deck)) {
                    quickActionButton(
                        icon: "rectangle.stack.fill",
                        title: "Flashcard",
                        subtitle: "Ôn từ thẻ",
                        color: .blue
                    )
                }
                .buttonStyle(.plain)

                // Dictation
                NavigationLink(destination: DictationPracticeView(selectedDeck: deck)) {
                    quickActionButton(
                        icon: "pencil.and.outline",
                        title: "Chép chính tả",
                        subtitle: "Nghe viết",
                        color: .orange
                    )
                }
                .buttonStyle(.plain)

                // AI Story Mode
                NavigationLink(destination: StoryReadingView(deck: deck)) {
                    quickActionButton(
                        icon: "sparkles.rectangle.stack.fill",
                        title: "Truyện AI",
                        subtitle: "Ngữ cảnh",
                        color: AppTheme.primary
                    )
                }
                .buttonStyle(.plain)

                // YouTube Subtitles
                NavigationLink(destination: YouTubeStudyView(preselectedDeck: deck)) {
                    quickActionButton(
                        icon: "play.rectangle.fill",
                        title: "YouTube Sub",
                        subtitle: "Song ngữ",
                        color: .red
                    )
                }
                .buttonStyle(.plain)
            }

            // Second row: pronunciation practice
            NavigationLink(destination: SpeakPracticeView(deck: deck)) {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(AppTheme.accent.opacity(0.12))
                            .frame(width: 40, height: 40)

                        Image(systemName: "mic.fill")
                            .font(.system(size: 17))
                            .foregroundStyle(AppTheme.accent)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Luyện nói")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Đọc to từng từ & câu — AI chấm điểm phát âm")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.textTertiary)
                }
                .padding(12)
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func quickActionButton(icon: String, title: String, subtitle: String, color: Color) -> some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(color.opacity(0.1))
                    .frame(width: 60, height: 60)

                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(color)
            }

            VStack(spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.textPrimary)

                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Vocabulary Items Section
    private var vocabularyItemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Danh sách từ vựng")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(AppTheme.textSecondary)
                    .textCase(.uppercase)

                Spacer()

                Text("\(deck.items.count) từ")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textTertiary)
            }

            if deck.items.isEmpty {
                emptyItemsView
            } else {
                VStack(spacing: 10) {
                    ForEach(deck.items) { item in
                        vocabularyItemRow(for: item)
                    }
                }
            }
        }
    }

    private func vocabularyItemRow(for item: VocabularyItem) -> some View {
        Button {
            editingItem = item
        } label: {
            HStack(spacing: 12) {
                // Thumbnail or initial
                if let data = item.imageData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(AppTheme.primary.opacity(0.08))
                            .frame(width: 44, height: 44)
                        Text(String(item.word.prefix(1)).uppercased())
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.primary)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(item.word)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppTheme.textPrimary)
                            .lineLimit(1)

                        if item.isMastered {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(AppTheme.success)
                        }
                    }

                    HStack(spacing: 6) {
                        if !item.partOfSpeech.isEmpty {
                            Text(item.partOfSpeech)
                                .font(.caption2)
                                .foregroundStyle(AppTheme.primary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppTheme.primary.opacity(0.1))
                                .clipShape(Capsule())
                        }

                        Text(item.meaning)
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Pronunciation Button
                AudioSpeakerButton(word: item.word, size: 32, iconSize: 13, tintColor: AppTheme.primary)

                // Item Action Menu (Edit, Toggle, Delete)
                Menu {
                    Button {
                        toggleMastery(for: item)
                    } label: {
                        Label(item.isMastered ? "Đánh dấu ôn lại" : "Đánh dấu đã thuộc",
                              systemImage: item.isMastered ? "arrow.counterclockwise" : "checkmark.seal.fill")
                    }

                    Button {
                        editingItem = item
                    } label: {
                        Label("Chỉnh sửa từ", systemImage: "pencil")
                    }

                    Divider()

                    Button(role: .destructive) {
                        itemToDelete = item
                        showDeleteConfirmation = true
                    } label: {
                        Label("Xoá khỏi học phần", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(Color.primary.opacity(0.04))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                toggleMastery(for: item)
            } label: {
                Label(item.isMastered ? "Đánh dấu ôn lại" : "Đánh dấu đã thuộc",
                      systemImage: item.isMastered ? "arrow.counterclockwise" : "checkmark.seal.fill")
            }

            Button {
                editingItem = item
            } label: {
                Label("Chỉnh sửa từ", systemImage: "pencil")
            }

            Divider()

            Button(role: .destructive) {
                itemToDelete = item
                showDeleteConfirmation = true
            } label: {
                Label("Xoá khỏi học phần", systemImage: "trash")
            }
        }
    }

    private var emptyItemsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "book.closed")
                .font(.system(size: 40))
                .foregroundStyle(AppTheme.textTertiary)

            Text("Chưa có từ vựng")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)

            Button {
                isAddWordPresented = true
            } label: {
                Text("Thêm từ vựng")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(AppTheme.primary)
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Actions
    private func toggleMastery(for item: VocabularyItem) {
        HapticFeedback.selection()
        item.isMastered.toggle()
        try? modelContext.save()
    }

    private func deleteItem(_ item: VocabularyItem) {
        HapticFeedback.error()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            if let index = deck.items.firstIndex(where: { $0.id == item.id }) {
                deck.items.remove(at: index)
            }
            modelContext.delete(item)
            try? modelContext.save()
        }
    }
}
