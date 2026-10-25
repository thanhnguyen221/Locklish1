import SwiftUI
import SwiftData

// MARK: - YouTubeStudyView
/// Comprehensive bilingual YouTube study view with interactive subtitles,
/// auto-scrolling synchronization, Cambridge dictionary instant lookup,
/// automatic vocabulary highlighting, and 1-tap saving to decks.
struct YouTubeStudyView: View {
    var preselectedDeck: VocabularyDeck? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Query private var allDecks: [VocabularyDeck]

    @State private var viewModel = YouTubeStudyViewModel()
    @State private var isPasteActive: Bool = false
    @State private var embedErrorText: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Top URL Input Bar
            urlInputBar
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(AppTheme.cardBackground)
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundStyle(Color.primary.opacity(0.06)),
                    alignment: .bottom
                )

            if viewModel.isLoading {
                loadingVideoView
            } else if let error = viewModel.errorMessage {
                errorStateView(message: error)
            } else if let video = viewModel.videoInfo {
                // Active Video Study View
                activeStudyView(video: video)
            } else {
                // Welcome / Sample Videos View
                emptyWelcomeView
            }
        }
        .background(AppTheme.background.ignoresSafeArea(.all))
        .navigationTitle("Video YouTube")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.refreshSavedWords(from: allDecks)
        }
        .sheet(isPresented: $viewModel.isDictionaryPresented) {
            CambridgeDictionarySheet(
                wordInfo: viewModel.selectedWordInfo,
                isLoading: viewModel.isLookingUpWord,
                currentDeck: preselectedDeck,
                onWordAdded: { savedWord in
                    viewModel.markWordSaved(savedWord)
                }
            )
        }
    }

    // MARK: - URL Input Bar
    private var urlInputBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                // YouTube Icon Badge
                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.red)

                TextField("Dán link YouTube (watch?v=... hoặc youtu.be/)", text: $viewModel.videoURLInput)
                    .font(.system(size: 13.5))
                    .foregroundStyle(AppTheme.textPrimary)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .submitLabel(.go)
                    .onSubmit {
                        Task { await viewModel.loadVideo() }
                    }

                if !viewModel.videoURLInput.isEmpty {
                    Button {
                        viewModel.videoURLInput = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )

            // Paste from clipboard button
            Button {
                HapticFeedback.light()
                if let string = UIPasteboard.general.string {
                    viewModel.videoURLInput = string
                    Task { await viewModel.loadVideo() }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 12))
                    Text("Dán")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(AppTheme.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(AppTheme.primary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)

            // Submit Button
            Button {
                HapticFeedback.light()
                Task { await viewModel.loadVideo() }
            } label: {
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(
                        LinearGradient(
                            colors: [AppTheme.primary, AppTheme.primaryDark],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Circle())
                    .shadow(color: AppTheme.primary.opacity(0.3), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Active Video Study View
    /// Wide, regular-width screens (iPad, Max iPhones landscape) put the player
    /// and the transcript side by side; compact screens keep the classic stack.
    @ViewBuilder
    private func activeStudyView(video: YouTubeVideoInfo) -> some View {
        if horizontalSizeClass == .regular {
            HStack(spacing: 0) {
                playerContainer(video: video)
                    .frame(maxWidth: 560)
                    .frame(maxHeight: .infinity)
                    .background(Color.black)

                VStack(spacing: 0) {
                    subtitleControlsBar(video: video)
                    subtitleListView
                }
            }
            .edgesIgnoringSafeArea(.top)
        } else {
            VStack(spacing: 0) {
                playerContainer(video: video)

                subtitleControlsBar(video: video)
                subtitleListView
            }
        }
    }

    private func playerContainer(video: YouTubeVideoInfo) -> some View {
        ZStack {
            YouTubePlayerView(
                videoId: video.videoId,
                currentTime: Binding(
                    get: { viewModel.lastVideoTime },
                    set: { viewModel.reportTime($0) }
                ),
                isPlaying: Binding(
                    get: { viewModel.isVideoPlaying },
                    set: { viewModel.setPlaying($0) }
                ),
                seekRequest: $viewModel.seekRequest,
                onEmbedError: { code in
                    embedErrorText = Self.embedErrorMessage(for: code)
                },
                onPlayerReady: {
                    embedErrorText = nil
                },
                onVideoAspectRatio: { ratio in
                    guard ratio.isFinite, ratio > 0 else { return }
                    viewModel.videoAspectRatio = ratio
                }
            )

            if let message = embedErrorText {
                embedErrorOverlay(message)
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(viewModel.videoAspectRatio, contentMode: .fit)
        .background(Color.black)
    }

    private static func embedErrorMessage(for code: Int) -> String {
        switch code {
        case 2: return "Link video không hợp lệ."
        case 5: return "Lỗi trình phát. Hãy thử lại hoặc dùng video khác."
        case 100: return "Video không tồn tại hoặc đã bị xoá."
        case 101, 150: return "Chủ sở hữu video không cho phép phát nhúng. Hãy thử video khác."
        default: return "Không phát được video này."
        }
    }

    private func embedErrorOverlay(_ message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 30))
                .foregroundStyle(AppTheme.warning)

            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.88))
    }

    // MARK: - Subtitle Controls Bar
    private func subtitleControlsBar(video: YouTubeVideoInfo) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(video.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: 5) {
                        Text(video.author)
                            .font(.caption2)
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineLimit(1)

                        Text("·")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.textTertiary)

                        Text("\(video.cues.count) câu phụ đề")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(AppTheme.primary)
                    }
                }

                Spacer(minLength: 8)

                // Display Mode Picker
                Picker("Chế độ", selection: $viewModel.displayMode) {
                    ForEach(SubtitleDisplayMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 168)
            }

            HStack(spacing: 8) {
                // Search in Subtitle Field
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textTertiary)

                    TextField("Tìm câu trong video...", text: $viewModel.searchSubtitleQuery)
                        .font(.system(size: 12))

                    if !viewModel.searchSubtitleQuery.isEmpty {
                        Button {
                            viewModel.searchSubtitleQuery = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(AppTheme.textTertiary)
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.primary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

                // Auto-scroll toggle
                Button {
                    HapticFeedback.light()
                    viewModel.autoScrollEnabled.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: viewModel.autoScrollEnabled ? "arrow.down.circle.fill" : "arrow.down.circle")
                            .font(.system(size: 11))
                        Text("Tự cuộn")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(viewModel.autoScrollEnabled ? AppTheme.primary : AppTheme.textSecondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 7)
                    .background(viewModel.autoScrollEnabled ? AppTheme.primary.opacity(0.12) : Color.primary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
                .buttonStyle(.plain)

                // Sync offset adjust button
                Menu {
                    Picker("Độ trễ phụ đề", selection: $viewModel.subtitleOffset) {
                        Text("Tự động").tag(-0.3)
                        Text("0.0s").tag(0.0)
                        Text("-0.5s").tag(-0.5)
                        Text("-1.0s").tag(-1.0)
                        Text("-1.5s").tag(-1.5)
                        Text("-2.0s").tag(-2.0)
                        Text("+0.5s").tag(0.5)
                        Text("+1.0s").tag(1.0)
                        Text("+1.5s").tag(1.5)
                        Text("+2.0s").tag(2.0)
                    }
                    .pickerStyle(.menu)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 11))
                        Text("Đồng bộ")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(viewModel.subtitleOffset != -0.3 ? AppTheme.primary : AppTheme.textSecondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 7)
                    .background(viewModel.subtitleOffset != -0.3 ? AppTheme.primary.opacity(0.12) : Color.primary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(AppTheme.cardBackground)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(Color.primary.opacity(0.06)),
            alignment: .bottom
        )
    }

    // MARK: - Synchronized Subtitle List
    /// 30 fps tick, but every per-frame computation is O(active cue): display
    /// tokens, sanitized words and saved flags were prebuilt in the view model,
    /// so ticks that don't cross a word boundary produce identical output and
    /// SwiftUI diffs them away almost for free.
    private var subtitleListView: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let playbackTime = viewModel.projectedTime(at: timeline.date)
            // Apply subtitle offset for synchronization
            let adjustedTime = playbackTime + viewModel.subtitleOffset
            let activeId = viewModel.activeCueId(at: adjustedTime)
            let cues = viewModel.displayModels(matching: viewModel.searchSubtitleQuery)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(cues) { model in
                            let isActive = model.id == activeId
                            subtitleRow(
                                model: model,
                                isActive: isActive,
                                spokenTime: isActive ? adjustedTime : -1
                            )
                            .id(model.id)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }
                .onChange(of: activeId) { _, newId in
                    guard viewModel.autoScrollEnabled, let newId else { return }
                    guard cues.contains(where: { $0.id == newId }) else { return }
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(newId, anchor: .center)
                    }
                }
            }
        }
    }

    // MARK: - Single Subtitle Row
    private func subtitleRow(model: CueDisplayModel, isActive: Bool, spokenTime: Double) -> some View {
        let cue = model.cue

        return HStack(alignment: .top, spacing: 10) {
            // Timestamp chip: tap to seek the video here
            Button {
                viewModel.seekTo(cue: cue)
            } label: {
                Text(cue.formattedTimestamp)
                    .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(isActive ? .white : AppTheme.textTertiary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(isActive ? AppTheme.primary : Color.primary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.top, 3)

            VStack(alignment: .leading, spacing: 6) {
                if viewModel.displayMode != .vietnamese {
                    interactiveEnglishCue(model: model, isActive: isActive, spokenTime: spokenTime)
                }

                if viewModel.displayMode != .english && !cue.textVi.isEmpty {
                    Text(cue.textVi)
                        .font(.system(size: 13.5))
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineSpacing(3)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isActive ? AppTheme.primary.opacity(0.07) : AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    isActive ? AppTheme.primary.opacity(0.45) : Color.primary.opacity(0.05),
                    lineWidth: 1
                )
        )
    }

    // MARK: - Interactive English Tokens
    /// Karaoke tracking: within the active cue, words the audio has already reached are
    /// underlined and bolded. Real per-word YouTube timings are used when present;
    /// all token/clean/saved data comes from the prebuilt display model, so this
    /// closure does no string work per frame.
    private func interactiveEnglishCue(model: CueDisplayModel, isActive: Bool, spokenTime: Double) -> some View {
        let spokenCount = isActive ? viewModel.spokenWordIndex(in: model, at: spokenTime) : 0

        return FlowLayout(spacing: 4, lineSpacing: 7) {
            ForEach(Array(model.tokens.indices), id: \.self) { index in
                let isSpoken = isActive && index < spokenCount
                let isUpcoming = isActive && !isSpoken

                Button {
                    viewModel.selectWord(model.tokens[index].clean, in: model.tokens[index].raw, deckItems: preselectedDeck?.items ?? [])
                } label: {
                    HStack(spacing: 2) {
                        Text(model.tokens[index].raw)
                            .font(.system(size: 15, weight: isSpoken ? .semibold : .regular))
                            .foregroundStyle(
                                isSpoken ? AppTheme.primary : (isUpcoming ? AppTheme.primary.opacity(0.4) : AppTheme.textPrimary)
                            )
                            .underline(isSpoken, color: AppTheme.primary.opacity(0.6))

                        if model.savedFlags[index] {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(AppTheme.success)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Welcome & Curated Catalog (bento redesign)
    @State private var selectedCategoryId: String? = nil
    @State private var catalogQuery: String = ""

    /// Deterministic daily rotation: one pick per category, seeded by today.
    private var dailyPicks: [YouTubeSubtitleService.SampleVideo] {
        let catalog = YouTubeSubtitleService.shared.recommendedCatalog
        let day = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
        return catalog.enumerated().compactMap { categoryIndex, category in
            guard !category.videos.isEmpty else { return nil }
            let pick = (day + categoryIndex) % category.videos.count
            return category.videos[pick]
        }
    }

    private var filteredCatalog: [YouTubeSubtitleService.RecommendationCategory] {
        let catalog = YouTubeSubtitleService.shared.recommendedCatalog
        let visible = catalog.filter { selectedCategoryId == nil || $0.id == selectedCategoryId }
        let query = catalogQuery.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return visible }
        return visible.map { category in
            YouTubeSubtitleService.RecommendationCategory(
                id: category.id, title: category.title, icon: category.icon,
                videos: category.videos.filter {
                    $0.title.localizedCaseInsensitiveContains(query)
                        || $0.channel.localizedCaseInsensitiveContains(query)
                        || $0.level.caseInsensitiveCompare(query) == .orderedSame
                }
            )
        }.filter { !$0.videos.isEmpty }
    }

    private var emptyWelcomeView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Gradient hero header
                VStack(alignment: .leading, spacing: 10) {
                    Text("Học tiếng Anh qua video 🎬")
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(colors: [Color(red: 0.98, green: 0.25, blue: 0.25), Color(red: 0.62, green: 0.36, blue: 0.96)], startPoint: .leading, endPoint: .trailing)
                        )

                    Text("Dán link bất kỳ — hoặc chọn video đề xuất. Phụ đề song ngữ, karaoke theo từng từ, chạm từ để tra Cambridge.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineSpacing(3)
                }
                .padding(.top, 14)

                // Search the catalog
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textTertiary)
                    TextField("Tìm video, kênh, hoặc mức (B1, B2...)", text: $catalogQuery)
                        .font(.system(size: 13))
                    if !catalogQuery.isEmpty {
                        Button { catalogQuery = "" } label: {
                            Image(systemName: "xmark.circle.fill").font(.system(size: 13))
                                .foregroundStyle(AppTheme.textTertiary)
                        }.buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 9)
                .background(AppTheme.cardBackground)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.primary.opacity(0.06), lineWidth: 0.5))

                // Daily picks — one from each category, rotates every day
                if catalogQuery.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("GỢI Ý HÔM NAY", systemImage: "sparkles")
                            .font(.system(size: 11, weight: .heavy))
                            .tracking(0.8)
                            .foregroundStyle(AppTheme.textSecondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(dailyPicks, id: \.id) { sample in
                                    Button {
                                        HapticFeedback.selection()
                                        viewModel.videoURLInput = sample.url
                                        Task { await viewModel.loadVideo() }
                                    } label: {
                                        dailyPickCard(sample)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }

                // Topic pills
                if catalogQuery.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            categoryPill(id: nil, title: "Tất cả", icon: "sparkles")
                            ForEach(YouTubeSubtitleService.shared.recommendedCatalog) { category in
                                categoryPill(id: category.id, title: category.title, icon: category.icon)
                            }
                        }
                    }
                }

                // Categories with 2-column bento video cards
                ForEach(filteredCatalog) { category in
                    VStack(alignment: .leading, spacing: 10) {
                        Label(category.title.uppercased(), systemImage: category.icon)
                            .font(.system(size: 11, weight: .heavy))
                            .tracking(0.8)
                            .foregroundStyle(AppTheme.textSecondary)

                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                            ForEach(category.videos) { sample in
                                Button {
                                    HapticFeedback.selection()
                                    viewModel.videoURLInput = sample.url
                                    Task { await viewModel.loadVideo() }
                                } label: {
                                    videoCard(sample)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                Spacer(minLength: 30)
            }
            .padding(.horizontal, 16)
        }
    }

    private func dailyPickCard(_ sample: YouTubeSubtitleService.SampleVideo) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                AsyncImage(url: URL(string: "https://img.youtube.com/vi/\(sample.id)/mqdefault.jpg")) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFill()
                            .frame(width: 210, height: 96)
                            .clipped()
                    } else {
                        Rectangle().fill(Color.primary.opacity(0.05))
                            .frame(width: 210, height: 96)
                    }
                }

                Text(sample.level)
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(CEFRLevelHelper.color(for: sample.level)))
                    .padding(7)
            }
            .frame(width: 210, height: 96)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(sample.title)
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Text(sample.channel)
                    .font(.system(size: 9.5))
                    .foregroundStyle(AppTheme.textTertiary)
                    .lineLimit(1)
            }
            .padding(10)
        }
        .frame(width: 210)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(red: 0.98, green: 0.25, blue: 0.25).opacity(0.15), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 2)
    }

    private func categoryPill(id: String?, title: String, icon: String) -> some View {
        let isActive = selectedCategoryId == id
        let tint: Color = id == nil ? AppTheme.primary : .red

        return Button {
            HapticFeedback.selection()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { selectedCategoryId = id }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 10, weight: .bold))
                Text(title).font(.system(size: 12.5, weight: .semibold))
            }
            .foregroundStyle(isActive ? .white : tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule().fill(isActive ? AnyShapeStyle(LinearGradient(colors: [tint, tint.opacity(0.65)], startPoint: .topLeading, endPoint: .bottomTrailing)) : AnyShapeStyle(tint.opacity(0.12)))
            )
        }
        .buttonStyle(.plain)
    }

    private func videoCard(_ sample: YouTubeSubtitleService.SampleVideo) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.primary.opacity(0.05))
                        .frame(height: 88)

                    AsyncImage(url: URL(string: "https://img.youtube.com/vi/\(sample.id)/mqdefault.jpg")) { phase in
                        if case .success(let image) = phase {
                            image.resizable().scaledToFill()
                                .frame(height: 88)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        } else {
                            Image(systemName: "play.rectangle.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(.red.opacity(0.6))
                        }
                    }
                }
                .frame(height: 88)

                Text(sample.level)
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(CEFRLevelHelper.color(for: sample.level)))
                    .padding(7)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(sample.title)
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 4) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 8))
                    Text(sample.channel)
                        .font(.system(size: 9.5))
                        .lineLimit(1)
                }
                .foregroundStyle(AppTheme.textTertiary)
            }
            .padding(10)
        }
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 2)
    }

    // MARK: - Loading & Error Views
    private var loadingVideoView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.3)
                .tint(AppTheme.primary)

            VStack(spacing: 6) {
                Text("Đang tải video & bóc tách phụ đề...")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)

                Text("Hệ thống đang trích xuất subtitle tiếng Anh và tiếng Việt đồng bộ theo từng giây.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var fallbackSampleVideo: YouTubeSubtitleService.SampleVideo {
        YouTubeSubtitleService.shared.sampleVideos.first ?? YouTubeSubtitleService.SampleVideo(
            id: "UF8uR6Z6KLc",
            title: "Steve Jobs' 2005 Stanford Commencement Address",
            channel: "Stanford",
            url: "https://www.youtube.com/watch?v=UF8uR6Z6KLc",
            level: "B2"
        )
    }

    private func errorStateView(message: String) -> some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(AppTheme.warning.opacity(0.12))
                    .frame(width: 72, height: 72)

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(AppTheme.warning)
            }

            VStack(spacing: 8) {
                Text("Chưa thể mở phụ đề video này")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            VStack(spacing: 10) {
                // Button to try sample verified video
                Button {
                    HapticFeedback.light()
                    viewModel.videoURLInput = fallbackSampleVideo.url
                    Task { await viewModel.loadVideo() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "play.circle.fill")
                        Text("Thử xem video Steve Jobs (Bản mẫu chuẩn CC)")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 11)
                    .background(AppTheme.primary)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    viewModel.errorMessage = nil
                } label: {
                    Text("Đóng thông báo và chọn link khác")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                        .padding(.top, 4)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxHeight: .infinity)
        .padding(24)
    }
}
