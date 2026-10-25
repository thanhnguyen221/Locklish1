import SwiftUI

// MARK: - NewsListView
/// "Tin tức" tab — redesigned around the 2025-26 bento/gradient trend:
/// gradient header, colored topic pills, a big featured story card, gradient
/// "for you" carousel, and clean rows with per-topic color identity.
struct NewsListView: View {
    enum Timeframe: String, CaseIterable, Identifiable {
        case today = "Hôm nay"
        case week = "7 ngày"
        case all = "Tất cả"

        var id: String { rawValue }
    }

    @State private var settings = NewsUserSettings.shared
    @State private var isLoading: Bool = false
    @State private var lastUpdated: Date? = NewsFetchService.shared.lastFetchDate
    @State private var fetchError: String? = nil
    @State private var newCountNotice: Int? = nil

    @State private var topicFilter: String? = nil
    @State private var sourceFilter: String? = nil
    @State private var levelFilter: String? = nil
    @State private var timeframe: Timeframe = .week
    @State private var searchQuery: String = ""
    @State private var showOnlySaved: Bool = false
    @State private var isSettingsPresented: Bool = false

    @State private var visibleCount: Int = 20
    @State private var storeVersion: Int = 0

    private let levelOrder = ["A2": 0, "B1": 1, "B2": 2, "C1": 3]
    private let allTopics = ["technology", "science", "business", "health", "world", "education", "learning_english"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Bento-style header
                header

                if let error = fetchError, NewsStore.shared.items.isEmpty {
                    errorState(error)
                } else if NewsStore.shared.items.isEmpty && isLoading {
                    ProgressView("Đang tải tin lần đầu…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredItems.isEmpty {
                    emptyState
                } else {
                    feedContent
                }
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Tin tức")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            HapticFeedback.light()
                            isSettingsPresented = true
                        } label: {
                            Image(systemName: "person.text.rectangle")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(AppTheme.primary)
                        }
                        .accessibilityLabel("Tuỳ chọn tin tức")

                        Button {
                            HapticFeedback.selection()
                            Task { await refresh(force: true) }
                        } label: {
                            if isLoading {
                                ProgressView().tint(AppTheme.primary)
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(AppTheme.primary)
                            }
                        }
                        .accessibilityLabel("Cập nhật ngay")
                    }
                }
            }
            .sheet(isPresented: $isSettingsPresented) { NewsSettingsSheet() }
            .task {
                let stale = lastUpdated.map { Date().timeIntervalSince($0) > 24 * 3600 } ?? true
                if stale || NewsStore.shared.items.isEmpty {
                    await refresh(force: false)
                } else {
                    NewsStore.shared.load()
                    storeVersion += 1
                }
            }
        }
    }

    // MARK: - Header (gradient hero + topic pills + search)

    private var header: some View {
        VStack(spacing: 12) {
            // Big greeting + freshness pill
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Đọc tin mỗi ngày 📰")
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(colors: [NewsTopicStyle.color("technology"), NewsTopicStyle.color("science")], startPoint: .leading, endPoint: .trailing)
                        )
                    Text(headerSubtitle)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Spacer()

                if let newCount = newCountNotice, newCount > 0 {
                    Text("+\(newCount) mới")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(AppTheme.successGradient))
                }
            }

            // Topic pills (bento colors)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    topicPill(topic: nil, label: "Tất cả", icon: "sparkles")
                    ForEach(allTopics, id: \.self) { topic in
                        topicPill(topic: topic, label: NewsTopicStyle.label(topic), icon: NewsTopicStyle.icon(topic))
                    }
                }
                .padding(.vertical, 2)
            }

            // Search + compact filters
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textTertiary)
                    TextField("Tìm trong tin...", text: $searchQuery)
                        .font(.system(size: 13))
                    if !searchQuery.isEmpty {
                        Button { searchQuery = "" } label: {
                            Image(systemName: "xmark.circle.fill").font(.system(size: 13))
                                .foregroundStyle(AppTheme.textTertiary)
                        }.buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 8)
                .background(AppTheme.cardBackground)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.primary.opacity(0.06), lineWidth: 0.5))

                compactMenu(icon: "antenna.radiowaves.left.and.right", label: shortSourceLabel, active: sourceFilter != nil) {
                    Menu {
                        Button("Mọi nguồn") { sourceFilter = nil }
                        ForEach(NewsFetchService.shared.loadSources()) { source in
                            Button(source.name) { sourceFilter = source.id }
                        }
                    } label: { EmptyView() }
                }

                compactMenu(icon: "chart.bar.fill", label: levelFilter ?? "Mức", active: levelFilter != nil) {
                    Menu {
                        Button("Mọi mức") { levelFilter = nil }
                        ForEach(["A2", "B1", "B2", "C1"], id: \.self) { level in
                            Button(level) { levelFilter = level }
                        }
                    } label: { EmptyView() }
                }

                compactMenu(icon: "clock", label: timeframe.rawValue, active: timeframe != .week) {
                    Menu {
                        Picker("Thời gian", selection: $timeframe) {
                            ForEach(Timeframe.allCases) { t in Text(t.rawValue).tag(t) }
                        }
                    } label: { EmptyView() }
                }

                Button {
                    HapticFeedback.selection()
                    withAnimation { showOnlySaved.toggle() }
                } label: {
                    Image(systemName: showOnlySaved ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(showOnlySaved ? .white : AppTheme.textSecondary)
                        .frame(width: 34, height: 34)
                        .background(showOnlySaved ? AnyShapeStyle(AppTheme.primaryGradient) : AnyShapeStyle(AppTheme.cardBackground))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Chỉ xem bài đã lưu")
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(
            LinearGradient(colors: [AppTheme.cardBackground, AppTheme.background], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea(edges: .top)
        )
    }

    private var headerSubtitle: String {
        if let lastUpdated {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            formatter.locale = Locale(identifier: "vi_VN")
            return "Cập nhật \(formatter.localizedString(for: lastUpdated, relativeTo: Date())) trước · \(NewsStore.shared.items.count) tin"
        }
        return "Đang chuẩn bị bản tin của bạn…"
    }

    private func topicPill(topic: String?, label: String, icon: String) -> some View {
        let isActive = topicFilter == topic
        let tint: Color = topic.map { NewsTopicStyle.color($0) } ?? AppTheme.primary

        return Button {
            HapticFeedback.selection()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { topicFilter = topic }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 10, weight: .bold))
                Text(label).font(.system(size: 12.5, weight: .semibold))
            }
            .foregroundStyle(isActive ? .white : tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule().fill(isActive ? AnyShapeStyle(NewsTopicStyle.gradient(topic ?? "technology")) : AnyShapeStyle(tint.opacity(0.12)))
            )
            .overlay(Capsule().stroke(isActive ? Color.clear : tint.opacity(0.18), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    private func compactMenu<Content: View>(icon: String, label: String, active: Bool, @ViewBuilder menu: () -> Content) -> some View {
        Menu {
            menu()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 10))
                Text(label).font(.system(size: 11.5, weight: .semibold)).lineLimit(1)
            }
            .foregroundStyle(active ? .white : AppTheme.textSecondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 8)
            .background(Capsule().fill(active ? AnyShapeStyle(AppTheme.primaryGradient) : AnyShapeStyle(AppTheme.cardBackground)))
            .overlay(Capsule().stroke(Color.primary.opacity(0.06), lineWidth: 0.5))
        }
    }

    private var shortSourceLabel: String {
        guard let id = sourceFilter else { return "Nguồn" }
        return NewsFetchService.shared.loadSources().first { $0.id == id }?.name.prefix(12).description ?? "Nguồn"
    }

    // MARK: - Refresh

    private func refresh(force: Bool) async {
        isLoading = true
        fetchError = nil
        let result = await NewsFetchService.shared.fetchAll(force: force)
        isLoading = false
        lastUpdated = NewsFetchService.shared.lastFetchDate
        storeVersion += 1

        let failed = result.reports.filter { !$0.succeeded }
        if failed.isEmpty {
            newCountNotice = result.totalNew
        } else if NewsStore.shared.items.isEmpty {
            fetchError = "\(failed.count) nguồn lỗi (\(failed.first?.error ?? "")). Thử lại sau ít phút."
        }
    }

    // MARK: - Filtering

    private var filteredItems: [NewsItem] {
        _ = storeVersion
        var items = NewsStore.shared.items.filter { !settings.hiddenSources.contains($0.sourceId) }

        if showOnlySaved { items = items.filter { settings.isSaved($0.id) } }
        if let topic = topicFilter { items = items.filter { $0.topic == topic } }
        if let source = sourceFilter { items = items.filter { $0.sourceId == source } }
        if let level = levelFilter { items = items.filter { $0.estimatedLevel == level } }

        switch timeframe {
        case .today:
            items = items.filter { $0.publishedAt.map(Calendar.current.isDateInToday) ?? false }
        case .week:
            items = items.filter { $0.publishedAt.map { Date().timeIntervalSince($0) < 7 * 24 * 3600 } ?? false }
        case .all:
            break
        }

        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            items = items.filter {
                $0.title.localizedCaseInsensitiveContains(query) || $0.summary.localizedCaseInsensitiveContains(query)
            }
        }
        return items
    }

    private var recommendedItems: [NewsItem] {
        let preferred = settings.preferredTopics
        let target = levelOrder[settings.preferredLevel] ?? 1
        let candidates = NewsStore.shared.items.filter { item in
            !settings.hiddenSources.contains(item.sourceId)
                && !settings.isRead(item.id)
                && (levelOrder[item.estimatedLevel] ?? 1) <= target + 1
        }
        let matching = preferred.isEmpty ? candidates : candidates.filter { preferred.contains($0.topic) }
        return Array((matching.isEmpty ? candidates : matching).prefix(5))
    }

    // MARK: - Feed content (bento: featured + for-you + rows)

    private var isFiltering: Bool {
        topicFilter != nil || sourceFilter != nil || levelFilter != nil || !searchQuery.isEmpty || showOnlySaved || timeframe != .week
    }

    private var feedContent: some View {
        let items = filteredItems

        return ScrollView {
            LazyVStack(spacing: 14) {
                // Featured big card (newest) — only in the clean, unfiltered view
                if !isFiltering, let featured = items.first {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("NỔI BẬT HÔM NAY")
                            .font(.system(size: 11, weight: .heavy))
                            .tracking(1)
                            .foregroundStyle(AppTheme.textSecondary)
                            .padding(.horizontal, 2)

                        NavigationLink(destination: NewsArticleView(item: featured)) {
                            featuredCard(featured)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                }

                // For you — gradient carousel
                if !isFiltering && !recommendedItems.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(NewsTopicStyle.color("learning_english"))
                            Text("DÀNH CHO BẠN · \(settings.preferredLevel)")
                                .font(.system(size: 11, weight: .heavy))
                                .tracking(1)
                                .foregroundStyle(AppTheme.textSecondary)
                            Spacer()
                            Text("ước lượng độ khó")
                                .font(.system(size: 9))
                                .foregroundStyle(AppTheme.textTertiary)
                        }
                        .padding(.horizontal, 2)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(recommendedItems) { item in
                                    NavigationLink(destination: NewsArticleView(item: item)) {
                                        forYouCard(item)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }

                // Latest section
                HStack {
                    Text(isFiltering ? "KẾT QUẢ (\(items.count))" : "MỚI NHẤT")
                        .font(.system(size: 11, weight: .heavy))
                        .tracking(1)
                        .foregroundStyle(AppTheme.textSecondary)
                    Spacer()
                }
                .padding(.horizontal, 18)

                LazyVStack(spacing: 10) {
                    ForEach(items.prefix(visibleCount)) { item in
                        NavigationLink(destination: NewsArticleView(item: item)) {
                            NewsArticleRow(item: item)
                                .accessibilityIdentifier("news-article-row")
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)

                if visibleCount < items.count {
                    Button {
                        HapticFeedback.selection()
                        visibleCount += 20
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.down.circle.fill")
                            Text("Tải thêm (\(items.count - visibleCount) tin)")
                                .fontWeight(.bold)
                        }
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(AppTheme.primary.opacity(0.1)))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                }

                Spacer(minLength: 24)
            }
            .padding(.top, 4)
        }
        .refreshable { await refresh(force: true) }
    }

    // MARK: - Cards

    private func featuredCard(_ item: NewsItem) -> some View {
        let tint = NewsTopicStyle.color(item.topic)

        return ZStack(alignment: .bottomLeading) {
            // Image or gradient backdrop
            ZStack(alignment: .center) {
                Rectangle().fill(NewsTopicStyle.gradient(item.topic)).frame(height: 210)

                if let urlString = item.imageURL, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        if case .success(let image) = phase {
                            image.resizable().scaledToFill().frame(height: 210).clipped()
                        }
                    }
                }
            }
            .frame(height: 210)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

            // Bottom scrim + content
            LinearGradient(
                colors: [.black.opacity(0.75), .black.opacity(0.15), .clear],
                startPoint: .bottom, endPoint: .center
            )
            .frame(height: 210)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Label(NewsTopicStyle.label(item.topic), systemImage: NewsTopicStyle.icon(item.topic))
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(tint.opacity(0.9)))

                    Text(item.estimatedLevel)
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(.white.opacity(0.25)))
                }

                Text(item.title)
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)

                Text("\(item.sourceName) · \(item.publishedAt?.formatted(.relative(presentation: .named)) ?? "")")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(16)
        }
        .shadow(color: tint.opacity(0.25), radius: 14, x: 0, y: 6)
    }

    private func forYouCard(_ item: NewsItem) -> some View {
        let tint = NewsTopicStyle.color(item.topic)

        return VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(NewsTopicStyle.gradient(item.topic))
                    .frame(height: 52)

                if let urlString = item.imageURL, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        if case .success(let image) = phase {
                            image.resizable().scaledToFill()
                                .frame(height: 52)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }
                }

                Text(item.estimatedLevel)
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(Capsule().fill(.black.opacity(0.35)))
                    .padding(7)
            }
            .frame(height: 52)

            Text(item.title)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 4) {
                Image(systemName: NewsTopicStyle.icon(item.topic))
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(tint)
                Text(item.sourceName)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(AppTheme.textTertiary)
                    .lineLimit(1)
            }
        }
        .frame(width: 168, alignment: .leading)
        .padding(10)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(tint.opacity(0.15), lineWidth: 0.5)
        )
    }

    // MARK: - States

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 38))
                .foregroundStyle(AppTheme.warning)
            Text("Không tải được tin")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)
            Text(message)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
            Button {
                Task { await refresh(force: true) }
            } label: {
                Label("Thử lại", systemImage: "arrow.clockwise")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(AppTheme.primaryGradient)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "newspaper")
                .font(.system(size: 36))
                .foregroundStyle(AppTheme.textTertiary)
            Text(showOnlySaved ? "Chưa có bài nào được lưu" : "Không có tin nào khớp bộ lọc")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
            if showOnlySaved {
                Text("Lưu bài bằng nút dấu trang khi đọc để đọc lại sau.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Article Row (topic-color identity)
struct NewsArticleRow: View {
    let item: NewsItem
    @State private var settings = NewsUserSettings.shared

    private var tint: Color { NewsTopicStyle.color(item.topic) }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Topic color bar + source avatar
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(tint)
                    .frame(width: 3.5, height: 46)

                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Image(systemName: NewsTopicStyle.icon(item.topic))
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(tint)
                    Text(item.sourceName)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(1)
                    Text("·")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textTertiary)
                    Text(relativeTime(item.publishedAt))
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textTertiary)
                }

                Text(item.title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(settings.isRead(item.id) ? AppTheme.textSecondary : AppTheme.textPrimary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 5) {
                    Text(item.estimatedLevel)
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2.5)
                        .background(Capsule().fill(tint))

                    if GrammarHintDetector.hints(forTitle: item.title).first != nil {
                        HStack(spacing: 2) {
                            Image(systemName: "text.book.closed.fill").font(.system(size: 7))
                            Text("Ngữ pháp")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundStyle(AppTheme.accent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2.5)
                        .background(Capsule().fill(AppTheme.accent.opacity(0.12)))
                    }

                    Spacer(minLength: 0)
                }
            }

            Spacer(minLength: 0)

            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(tint.opacity(0.08))
                        .frame(width: 90, height: 62)

                    if let url = item.imageURL, let imageURL = URL(string: url) {
                        AsyncImage(url: imageURL) { phase in
                            if case .success(let image) = phase {
                                image.resizable().scaledToFill()
                                    .frame(width: 90, height: 62)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            } else {
                                Image(systemName: NewsTopicStyle.icon(item.topic))
                                    .font(.system(size: 16))
                                    .foregroundStyle(tint.opacity(0.5))
                            }
                        }
                    } else {
                        Image(systemName: NewsTopicStyle.icon(item.topic))
                            .font(.system(size: 17))
                            .foregroundStyle(tint.opacity(0.5))
                    }
                }

                Button {
                    HapticFeedback.selection()
                    settings.toggleSaved(item.id)
                } label: {
                    Image(systemName: settings.isSaved(item.id) ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 12))
                        .foregroundStyle(settings.isSaved(item.id) ? AppTheme.warning : AppTheme.textTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(settings.isSaved(item.id) ? "Bỏ lưu" : "Lưu bài")
            }
        }
        .padding(12)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(tint.opacity(settings.isRead(item.id) ? 0.04 : 0.10), lineWidth: 0.5)
        )
        .shadow(color: tint.opacity(0.06), radius: 8, x: 0, y: 3)
    }

    private func relativeTime(_ date: Date?) -> String {
        guard let date else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.locale = Locale(identifier: "vi_VN")
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
