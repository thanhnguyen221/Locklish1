import SwiftUI
import SwiftData

// MARK: - PracticeMode
enum PracticeMode: String, CaseIterable, Identifiable {
    case flashcards = "Thẻ ghi nhớ 3D"
    case dictation = "Nghe chép chính tả"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .flashcards: return "rectangle.on.rectangle.angled"
        case .dictation: return "waveform.and.mic"
        }
    }
}

// MARK: - PracticeHubView
/// Tab 2: Practice by vocabulary deck - folder-style navigation.
struct PracticeHubView: View {
    @Query private var allVocabularyItems: [VocabularyItem]
    @Query(sort: \VocabularyDeck.createdAt, order: .reverse) private var decks: [VocabularyDeck]

    var initialSelectedDeck: VocabularyDeck? = nil  // Optional initial deck selection

    @State private var selectedMode: PracticeMode = .flashcards
    @State private var selectedDeck: VocabularyDeck? = nil
    @State private var isShowingPracticeContent = false  // Show practice content or folder list

    var body: some View {
        NavigationStack {
            if isShowingPracticeContent && selectedDeck != nil {
                // Show practice content for selected deck
                practiceContentView
            } else {
                // Show folder list of decks
                folderListView
            }
        }
    }

    // MARK: - Folder List View
    private var folderListView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(AppTheme.primary)
                        Text("Chọn học phần để luyện tập")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(AppTheme.textSecondary)
                            .textCase(.uppercase)
                    }

                    Spacer()

                    Text("\(decks.count) học phần")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(AppTheme.primary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                // Deck folders
                if decks.isEmpty {
                    emptyFoldersView
                } else {
                    LazyVGrid(columns: [GridItem(.flexible())], spacing: 12) {
                        ForEach(decks) { deck in
                            deckFolderCard(deck: deck)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            .padding(.bottom, 32)
        }
        .background(AppTheme.background.ignoresSafeArea(.all))
        .navigationTitle("Luyện tập")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Practice Content View
    private var practiceContentView: some View {
        VStack(spacing: 0) {
            // Mode selector
            modeSelectorBar
                .padding(.horizontal, 20)
                .padding(.bottom, 8)

            // Practice content
            Group {
                switch selectedMode {
                case .flashcards:
                    FlashcardPracticeView(selectedDeck: selectedDeck)
                case .dictation:
                    DictationPracticeView(selectedDeck: selectedDeck, isDailyMission: false)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .id("\(selectedMode.rawValue)_\(selectedDeck?.id.uuidString ?? "all")")
        }
        .background(AppTheme.background.ignoresSafeArea(.all))
        .navigationTitle(selectedDeck?.name ?? "Luyện tập")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    HapticFeedback.selection()
                    withAnimation {
                        isShowingPracticeContent = false
                        selectedDeck = nil
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Quay lại")
                    }
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.primary)
                }
            }
        }
        .onAppear {
            if let initialDeck = initialSelectedDeck {
                selectedDeck = initialDeck
                isShowingPracticeContent = true
            }
        }
    }

    // MARK: - Deck Folder Card
    private func deckFolderCard(deck: VocabularyDeck) -> some View {
        Button {
            HapticFeedback.selection()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedDeck = deck
                isShowingPracticeContent = true
            }
        } label: {
            HStack(spacing: 16) {
                // Folder icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(deck.accentColor.opacity(0.15))
                        .frame(width: 56, height: 56)

                    Image(systemName: "folder.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(deck.accentColor)
                }

                // Deck info
                VStack(alignment: .leading, spacing: 6) {
                    Text(deck.name)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Label("\(deck.wordCount) từ", systemImage: "book.fill")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)

                        if deck.masteredCount > 0 {
                            Label("\(deck.masteredCount) đã thuộc", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(AppTheme.success)
                        }
                    }

                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.primary.opacity(0.08))
                                .frame(height: 4)

                            Capsule()
                                .fill(deck.accentColor)
                                .frame(width: geo.size.width * deck.progressRatio, height: 4)
                        }
                    }
                    .frame(height: 4)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.textTertiary)
            }
            .padding(16)
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty Folders View
    private var emptyFoldersView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.textTertiary)

            Text("Chưa có học phần nào")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            Text("Tạo học phần mới trong tab Từ vựng để bắt đầu luyện tập")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Mode Selector Bar
    private var modeSelectorBar: some View {
        HStack(spacing: 8) {
            ForEach(PracticeMode.allCases) { mode in
                let isSelected = selectedMode == mode
                Button {
                    HapticFeedback.selection()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedMode = mode
                    }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: mode.icon)
                            .font(.system(size: 14, weight: .semibold))
                        Text(mode.rawValue)
                            .font(.subheadline)
                            .fontWeight(isSelected ? .bold : .medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .foregroundStyle(isSelected ? .white : AppTheme.textSecondary)
                    .background(
                        isSelected
                            ? AnyShapeStyle(AppTheme.primaryGradient)
                            : AnyShapeStyle(AppTheme.cardBackground)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(isSelected ? Color.clear : Color.primary.opacity(0.06), lineWidth: 0.5)
                    )
                    .shadow(color: isSelected ? AppTheme.primary.opacity(0.2) : Color.clear, radius: 6, x: 0, y: 3)
                }
                .buttonStyle(.plain)
            }
        }
    }

}
