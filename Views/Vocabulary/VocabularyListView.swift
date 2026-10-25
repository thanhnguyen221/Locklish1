import SwiftUI
import SwiftData

// MARK: - VocabularyListView
/// Tab 1: Quizlet-style Study Sets dashboard showing vocabulary decks/collections.
struct VocabularyListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \VocabularyDeck.createdAt, order: .reverse) private var decks: [VocabularyDeck]

    @State private var viewModel = DeckListViewModel()
    @State private var isAddWordPresented = false
    @State private var isCreateDeckPresented = false
    @State private var isImportPresented = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if decks.isEmpty {
                    VStack(spacing: 20) {
                        NavigationLink(destination: YouTubeStudyView()) {
                            youtubeBannerCard
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
                        .padding(.top, 10)

                        emptyStateView
                    }
                } else {
                    let visibleDecks = viewModel.filteredDecks(decks)
                    if visibleDecks.isEmpty {
                        // Search matched nothing
                        VStack(spacing: 10) {
                            Spacer()
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 30))
                                .foregroundStyle(AppTheme.textTertiary)
                            Text("Không tìm thấy học phần nào")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.textSecondary)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        List {
                            // Streak banner
                            Section {
                                streakBanner
                                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 6, trailing: 16))
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.clear)
                            }

                            // YouTube Bilingual Subtitles Feature Card
                            Section {
                                NavigationLink(destination: YouTubeStudyView()) {
                                    youtubeBannerCard
                                }
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 6, trailing: 16))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                            }

                            // Decks List
                            Section {
                                ForEach(visibleDecks) { deck in
                                    NavigationLink(destination: DeckDetailView(deck: deck)) {
                                        deckCard(for: deck)
                                    }
                                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.clear)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            viewModel.deleteDeck(deck, in: modelContext)
                                        } label: {
                                            Label("Xóa", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .background(AppTheme.background.ignoresSafeArea(.all))
            .navigationTitle("Học phần")
            .searchable(text: $viewModel.searchText, prompt: "Tìm học phần...")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 8) {
                        Button {
                            HapticFeedback.light()
                            isImportPresented = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 12, weight: .semibold))
                                Text("Trích xuất")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                            .foregroundStyle(AppTheme.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(AppTheme.primary.opacity(0.1))
                            .clipShape(Capsule())
                        }

                        NavigationLink(destination: YouTubeStudyView()) {
                            HStack(spacing: 4) {
                                Image(systemName: "play.rectangle.fill")
                                    .font(.system(size: 12))
                                Text("YouTube Sub")
                                    .font(.caption)
                                    .fontWeight(.bold)
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.red)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            HapticFeedback.light()
                            isAddWordPresented = true
                        } label: {
                            Label("Thêm từ vựng", systemImage: "plus.circle")
                        }

                        Button {
                            HapticFeedback.light()
                            isCreateDeckPresented = true
                        } label: {
                            Label("Tạo học phần mới", systemImage: "folder.badge.plus")
                        }
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
            .sheet(isPresented: $isAddWordPresented) {
                AddEditWordView(existingItem: nil)
            }
            .fullScreenCover(isPresented: $isImportPresented) {
                ImportVocabularyView()
            }
            .sheet(isPresented: $isCreateDeckPresented) {
                CreateEditDeckView()
            }
        }
    }

    // MARK: - Deck Card (bento gradient identity)
    private func deckCard(for deck: VocabularyDeck) -> some View {
        // Single pass over the SwiftData relationship: wordCount, masteredCount,
        // progress and due count each used to walk `items` separately, and the
        // List re-renders cards on every data change.
        let startOfTomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date())) ?? Date()
        var total = 0
        var mastered = 0
        var dueCount = 0
        for item in deck.items ?? [] {
            total += 1
            if item.isMastered { mastered += 1 }
            if item.lastReviewedDate != nil && item.nextReviewDate < startOfTomorrow { dueCount += 1 }
        }
        let progress: Double = total > 0 ? Double(mastered) / Double(total) : 0
        let tint = deck.accentColor
        let deckGradient = LinearGradient(
            colors: [tint, tint.opacity(0.65)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(deckGradient)
                        .frame(width: 46, height: 46)

                    Image(systemName: "folder.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.white)
                }
                .shadow(color: tint.opacity(0.3), radius: 6, x: 0, y: 3)

                VStack(alignment: .leading, spacing: 4) {
                    Text(deck.name)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Label("\(total) từ", systemImage: "book.fill")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)

                        if dueCount > 0 {
                            Label("Ôn \(dueCount)", systemImage: "bolt.fill")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(AppTheme.warning)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(AppTheme.warning.opacity(0.14))
                                .clipShape(Capsule())
                        }
                    }
                }

                Spacer()

                ZStack {
                    Circle()
                        .stroke(tint.opacity(0.15), lineWidth: 6)
                        .frame(width: 42, height: 42)

                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(deckGradient, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 42, height: 42)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: progress)

                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 9.5, weight: .heavy))
                        .foregroundStyle(tint)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(tint.opacity(0.1))
                        .frame(height: 5)

                    Capsule()
                        .fill(deckGradient)
                        .frame(width: geo.size.width * progress, height: 5)
                        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: progress)
                }
            }
            .frame(height: 5)
        }
        .padding(14)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(tint.opacity(0.12), lineWidth: 0.5)
        )
        .shadow(color: tint.opacity(0.12), radius: 10, x: 0, y: 4)
    }

    // MARK: - Streak Banner (gradient bento)
    private var streakBanner: some View {
        let streak = StreakService.shared.currentStreak
        let practicedToday = StreakService.shared.practicedToday
        let gradient = LinearGradient(
            colors: practicedToday
                ? [AppTheme.warning, Color(red: 0.95, green: 0.42, blue: 0.25)]
                : [Color(red: 0.55, green: 0.58, blue: 0.62), Color(red: 0.38, green: 0.42, blue: 0.48)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )

        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.22))
                    .frame(width: 44, height: 44)
                Image(systemName: "flame.fill")
                    .font(.system(size: 21))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(streak > 0 ? "Chuỗi \(streak) ngày liên tục" : "Bắt đầu chuỗi học hôm nay")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)

                Text(practicedToday
                     ? "Hôm nay đã luyện tập — quá đỉnh!"
                     : "Luyện vài từ để giữ lửa chuỗi học 🔥")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
            }

            Spacer()

            if StreakService.shared.bestStreak > 0 {
                VStack(spacing: 1) {
                    Text("\(StreakService.shared.bestStreak)")
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Text("kỷ lục")
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.75))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.18))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .padding(14)
        .background(gradient)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: (practicedToday ? AppTheme.warning : Color.gray).opacity(0.28), radius: 10, x: 0, y: 4)
    }

    // MARK: - YouTube Banner (gradient bento)
    private var youtubeBannerCard: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.22))
                    .frame(width: 48, height: 48)

                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Học qua video YouTube")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)

                Text("Sub song ngữ · karaoke theo từ · tra Cambridge")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: [Color(red: 0.98, green: 0.25, blue: 0.25), Color(red: 0.85, green: 0.15, blue: 0.35)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color(red: 0.95, green: 0.2, blue: 0.3).opacity(0.28), radius: 10, x: 0, y: 4)
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack {
            Spacer()
            EmptyStatePlaceholderView(
                iconName: "folder.badge.plus",
                title: "Chưa có học phần nào",
                subtitle: "Tạo học phần mới để tổ chức từ vựng theo chủ đề hoặc sử dụng AI để trích xuất từ tài liệu.",
                actionTitle: "Tạo học phần mới"
            ) {
                isCreateDeckPresented = true
            }
            Spacer()
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - DeckListViewModel
@Observable
@MainActor
final class DeckListViewModel {
    var searchText: String = ""

    func filteredDecks(_ decks: [VocabularyDeck]) -> [VocabularyDeck] {
        if searchText.isEmpty {
            return decks
        }
        return decks.filter { deck in
            deck.name.localizedCaseInsensitiveContains(searchText) ||
            deck.deckDescription.localizedCaseInsensitiveContains(searchText)
        }
    }

    func deleteDeck(_ deck: VocabularyDeck, in context: ModelContext) {
        HapticFeedback.error()
        context.delete(deck)
        try? context.save()
    }
}
