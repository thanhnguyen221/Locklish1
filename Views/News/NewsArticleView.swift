import SwiftUI

// MARK: - NewsArticleView
/// Full reading experience: publisher's complete article (text + inline images
/// in original order), opaque navigation bar, tappable images with a zoomable
/// fullscreen viewer, tap-to-lookup word mode, and an accurate paragraph-level
/// bilingual mode (Gemini batch → Google fallback, cached offline).
struct NewsArticleView: View {
    @State var item: NewsItem

    @State private var settings = NewsUserSettings.shared
    @State private var fullArticle: NewsFullTextService.FullArticle? = nil
    @State private var isLoadingFull: Bool = false
    @State private var fullTextFailed: Bool = false

    @State private var lookupMode: Bool = false
    @State private var showTranslation: Bool = false
    @State private var translations: [Int: String] = [:]
    @State private var isTranslating: Bool = false

    @State private var viewerImage: ViewerImage? = nil
    @State private var selectedWordInfo: WordDetailInfo? = nil
    @State private var isLookingUpWord: Bool = false
    @State private var isDictPresented: Bool = false
    @Environment(\.openURL) private var openURL

    struct ViewerImage: Identifiable {
        let id: String
        let caption: String?
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                heroSection
                headerSection
                contentSection
                originalLinkSection
            }
        }
        .scrollIndicators(.hidden)
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Đọc tin")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppTheme.cardBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onAppear {
            settings.markRead(item.id)
            loadFullArticle()
        }
        .onChange(of: fullArticle != nil) { _, hasArticle in
            if hasArticle, showTranslation { startTranslations() }
        }
        .sheet(isPresented: $isDictPresented) {
            CambridgeDictionarySheet(
                wordInfo: selectedWordInfo,
                isLoading: isLookingUpWord,
                currentDeck: nil,
                onWordAdded: { _ in }
            )
        }
        .fullScreenCover(item: $viewerImage) { image in
            ImageViewer(imageURL: image.id, caption: image.caption)
        }
    }

    // MARK: - Hero image

    @ViewBuilder
    private var heroSection: some View {
        let imageURL = fullArticle?.heroImageURL ?? item.imageURL
        if let urlString = imageURL, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                ZStack(alignment: .bottom) {
                    if case .success(let image) = phase {
                        image.resizable().scaledToFill()
                            .frame(height: 230)
                            .clipped()
                    } else {
                        LinearGradient(colors: [AppTheme.primary.opacity(0.25), AppTheme.primaryDark.opacity(0.4)], startPoint: .top, endPoint: .bottom)
                            .frame(height: 230)
                            .overlay {
                                Image(systemName: "newspaper.fill")
                                    .font(.system(size: 40))
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                    }
                    LinearGradient(colors: [.clear, AppTheme.background], startPoint: .top, endPoint: .bottom)
                        .frame(height: 60)
                }
            }
        }
    }

    // MARK: - Header

    private var readingMinutes: Int {
        let words = fullArticle?.wordCount
            ?? item.summary.components(separatedBy: .whitespaces).count
        return max(1, Int(round(Double(words) / 200.0)))
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(NewsTopicStyle.gradient(item.topic))
                        .frame(width: 34, height: 34)
                    Image(systemName: NewsTopicStyle.icon(item.topic))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(item.sourceName)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(AppTheme.textPrimary)
                    HStack(spacing: 5) {
                        Text(item.publishedAt?.formatted(.relative(presentation: .named)) ?? "")
                        Text("· \(readingMinutes) phút đọc")
                    }
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textTertiary)
                }

                Spacer()

                Button {
                    HapticFeedback.selection()
                    settings.toggleSaved(item.id)
                } label: {
                    Image(systemName: settings.isSaved(item.id) ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 16))
                        .foregroundStyle(settings.isSaved(item.id) ? AppTheme.warning : AppTheme.textSecondary)
                        .frame(width: 34, height: 34)
                        .background(AppTheme.cardBackground)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(settings.isSaved(item.id) ? "Bỏ lưu bài" : "Lưu bài đọc sau")
            }

            tappableText(item.title, fontSize: 24, weight: .heavy, design: .rounded)
                .fixedSize(horizontal: false, vertical: true)

            FlowLayout(spacing: 6, lineSpacing: 6) {
                chip(item.topic.newsTopicLabel, tint: NewsTopicStyle.color(item.topic), filled: false)
                chip("\(item.estimatedLevel) · ước lượng", tint: CEFRLevelHelper.color(for: item.estimatedLevel), filled: true)

                ForEach(GrammarHintDetector.hints(forTitle: item.title)) { hint in
                    NavigationLink(destination: GrammarLessonView(topicId: hint.id)) {
                        HStack(spacing: 3) {
                            Image(systemName: "text.book.closed.fill").font(.system(size: 8))
                            Text(hint.label).font(.system(size: 10, weight: .bold))
                        }
                        .foregroundStyle(AppTheme.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(AppTheme.accent.opacity(0.12))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider().opacity(0.4)
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 14)
    }

    private func chip(_ text: String, tint: Color, filled: Bool) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(filled ? .white : tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(filled ? AnyShapeStyle(tint) : AnyShapeStyle(tint.opacity(0.12)))
            .clipShape(filled ? AnyShape(RoundedRectangle(cornerRadius: 5, style: .continuous)) : AnyShape(Capsule()))
    }

    // MARK: - Content

    private var bodyBlocks: [NewsContentBlock] {
        fullArticle?.blocks ?? [.text(item.summary)]
    }

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Mode toggles: bilingual + word lookup
            HStack(spacing: 8) {
                Button {
                    HapticFeedback.selection()
                    withAnimation(.easeInOut(duration: 0.2)) { showTranslation.toggle() }
                    if showTranslation { startTranslations() }
                } label: {
                    HStack(spacing: 5) {
                        if isTranslating {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: showTranslation ? "character.bubble" : "character.bubble")
                                .font(.system(size: 11))
                        }
                        Text(showTranslation ? "Song ngữ: BẬT" : "Song ngữ")
                            .font(.system(size: 11.5, weight: .bold))
                    }
                    .foregroundStyle(showTranslation ? .white : NewsTopicStyle.color("learning_english"))
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(
                        showTranslation
                            ? AnyShapeStyle(NewsTopicStyle.gradient("learning_english"))
                            : AnyShapeStyle(NewsTopicStyle.color("learning_english").opacity(0.12))
                    )
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Bật tắt dịch song ngữ")

                Button {
                    HapticFeedback.selection()
                    withAnimation(.easeInOut(duration: 0.2)) { lookupMode.toggle() }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: lookupMode ? "text.magnifyingglass" : "textformat")
                            .font(.system(size: 11))
                        Text(lookupMode ? "Đang tra từ" : "Tra từ")
                            .font(.system(size: 11.5, weight: .bold))
                    }
                    .foregroundStyle(lookupMode ? .white : AppTheme.primary)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(lookupMode ? AnyShapeStyle(AppTheme.primaryGradient) : AnyShapeStyle(AppTheme.primary.opacity(0.1)))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                if isLoadingFull {
                    Text("Đang tải bài…")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textTertiary)
                }

                Spacer()
            }
            .padding(.horizontal, 18)

            if fullTextFailed {
                Label("Không lấy được toàn văn (trang chặn hoặc cần JavaScript) — hiển thị tóm tắt từ feed.", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(AppTheme.warning)
                    .padding(12)
                    .background(AppTheme.warning.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.horizontal, 18)
            } else if let article = fullArticle, article.isPartial {
                Label("Trang chỉ cung cấp một phần bài viết — bản đầy đủ tại nguồn gốc bên dưới.", systemImage: "lock.open")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textTertiary)
                    .padding(.horizontal, 18)
            }

            LazyVStack(alignment: .leading, spacing: 18) {
                ForEach(Array(bodyBlocks.enumerated()), id: \.offset) { index, block in
                    switch block {
                    case .text(let paragraph):
                        VStack(alignment: .leading, spacing: 7) {
                            if lookupMode {
                                tappableText(paragraph, fontSize: 17, weight: .regular, design: .default)
                                    .lineSpacing(5)
                                    .fixedSize(horizontal: false, vertical: true)
                            } else {
                                Text(paragraph)
                                    .font(.system(size: 17, design: .serif))
                                    .lineSpacing(6)
                                    .foregroundStyle(AppTheme.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            if showTranslation, let vi = translations[index], !vi.isEmpty {
                                Text(vi)
                                    .font(.system(size: 15, design: .default))
                                    .foregroundStyle(NewsTopicStyle.color("learning_english").opacity(0.9))
                                    .lineSpacing(4)
                                    .padding(.leading, 10)
                                    .overlay(alignment: .leading) {
                                        Rectangle()
                                            .fill(NewsTopicStyle.color("learning_english").opacity(0.4))
                                            .frame(width: 2.5)
                                    }
                                    .fixedSize(horizontal: false, vertical: true)
                            } else if showTranslation, isTranslating {
                                HStack(spacing: 6) {
                                    ProgressView().tint(AppTheme.textTertiary)
                                    Text("Đang dịch…")
                                        .font(.caption2)
                                        .foregroundStyle(AppTheme.textTertiary)
                                }
                            }
                        }

                        if index == 0 {
                            Divider().opacity(0.3).padding(.top, 2)
                        }

                    case .image(let urlString, let caption):
                        if let url = URL(string: urlString) {
                            VStack(alignment: .leading, spacing: 5) {
                                // scaledToFit → tall images never crop; cap height for sanity
                                AsyncImage(url: url) { phase in
                                    if case .success(let image) = phase {
                                        image.resizable().scaledToFit()
                                            .frame(maxWidth: .infinity)
                                            .frame(maxHeight: 380)
                                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                            .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
                                    }
                                }
                                .onTapGesture {
                                    HapticFeedback.light()
                                    viewerImage = ViewerImage(id: urlString, caption: caption)
                                }

                                if let caption, !caption.isEmpty {
                                    Text(caption)
                                        .font(.caption2)
                                        .italic()
                                        .foregroundStyle(AppTheme.textTertiary)
                                        .lineLimit(2)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .animation(.easeInOut(duration: 0.2), value: lookupMode)

            Spacer(minLength: 8)
        }
    }

    // MARK: - Original link

    private var originalLinkSection: some View {
        VStack(spacing: 12) {
            Text("Nguồn: \(item.sourceName) · nội dung thuộc bản quyền của nhà xuất bản")
                .font(.caption2)
                .foregroundStyle(AppTheme.textTertiary)
                .multilineTextAlignment(.center)

            Button {
                HapticFeedback.light()
                if let url = URL(string: item.link) { openURL(url) }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Đọc bản gốc tại \(item.sourceName)")
                            .font(.subheadline)
                            .fontWeight(.bold)
                        Text("Mở trong Safari")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right.square.fill")
                        .font(.system(size: 22))
                }
                .foregroundStyle(.white)
                .padding(14)
                .background(AppTheme.primaryGradient)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Mở bài gốc tại \(item.sourceName)")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(AppTheme.cardBackground.opacity(0.6))
    }

    // MARK: - Loaders

    private func loadFullArticle() {
        guard fullArticle == nil, !isLoadingFull else { return }
        if let cached = NewsFullTextService.shared.cached(articleId: item.id) {
            fullArticle = cached
            return
        }
        isLoadingFull = true
        Task {
            let fetched = await NewsFullTextService.shared.fullArticle(for: item)
            await MainActor.run {
                isLoadingFull = false
                if let fetched {
                    fullArticle = fetched
                } else {
                    fullTextFailed = true
                }
            }
        }
    }

    private func startTranslations() {
        guard !isTranslating else { return }
        let blocks = bodyBlocks
        let articleId = item.id
        isTranslating = true
        Task {
            // onUpdate streams each finished batch into the UI immediately
            let map = await ArticleTranslationService.shared.translations(for: articleId, blocks: blocks) { snapshot in
                translations = snapshot
            }
            translations = map
            isTranslating = false
        }
    }

    // MARK: - Tappable text

    @ViewBuilder
    private func tappableText(_ text: String, fontSize: CGFloat, weight: Font.Weight, design: Font.Design) -> some View {
        let tokens = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }

        FlowLayout(spacing: 4, lineSpacing: fontSize > 20 ? 6 : 7) {
            ForEach(Array(tokens.enumerated()), id: \.offset) { _, token in
                let clean = WordInfoService.shared.sanitizeWord(token)
                if clean.isEmpty {
                    Text(token)
                        .font(.system(size: fontSize, weight: weight, design: design))
                        .foregroundStyle(AppTheme.textPrimary)
                } else {
                    Button {
                        lookup(token, sentence: text)
                    } label: {
                        Text(token)
                            .font(.system(size: fontSize, weight: weight, design: design))
                            .foregroundStyle(AppTheme.textPrimary)
                            .underline(color: AppTheme.primary.opacity(0.18))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Tra từ \(token)")
                }
            }
        }
    }

    private func lookup(_ rawWord: String, sentence: String) {
        let clean = WordInfoService.shared.sanitizeWord(rawWord)
        guard !clean.isEmpty else { return }

        HapticFeedback.light()
        isLookingUpWord = true
        isDictPresented = true

        Task {
            let info = await WordInfoService.shared.lookupWord(
                rawWord: clean,
                sentenceContext: sentence,
                deckItems: []
            )
            selectedWordInfo = info
            isLookingUpWord = false
        }
    }
}

// MARK: - ImageViewer (fullscreen, pinch-zoom, drag-to-dismiss)
struct ImageViewer: View {
    let imageURL: String
    let caption: String?
    @Environment(\.dismiss) private var dismiss

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var dragOffset: CGSize = .zero

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let url = URL(string: imageURL) {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFit()
                            .scaleEffect(scale)
                            .offset(dragOffset)
                    } else {
                        ProgressView().tint(.white)
                    }
                }
            }

            if let caption, !caption.isEmpty {
                VStack {
                    Spacer()
                    Text(caption)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.bottom, 40)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
            }

            VStack {
                HStack {
                    Spacer()
                    Button {
                        HapticFeedback.light()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(.trailing, 20)
                            .padding(.top, 12)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Đóng ảnh")
                }
                Spacer()
            }
        }
        .gesture(
            MagnificationGesture()
                .onChanged { value in
                    scale = max(1.0, min(4.0, lastScale * value))
                }
                .onEnded { _ in
                    lastScale = scale
                    if scale <= 1.02 { withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { scale = 1; lastScale = 1 } }
                }
        )
        .simultaneousGesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.height > 120 {
                        HapticFeedback.light()
                        dismiss()
                    } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { dragOffset = .zero }
                    }
                }
                .onChanged { value in
                    if scale <= 1.02 { dragOffset = value.translation }
                }
        )
        .onTapGesture(count: 2) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                scale = scale > 1.05 ? 1.0 : 2.2
                lastScale = scale
            }
        }
    }
}
