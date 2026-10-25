import SwiftUI
import SwiftData

// MARK: - GamifiedGameHubView
/// Tab 2: Gamified vocabulary roadmap with CEFR level categorization (A1, A2, B1, B2, C2)
/// and a non-overlapping, spacious winding adventure trail with connecting rope.
struct GamifiedGameHubView: View {
    @State private var viewModel = GamifiedViewModel()
    @State private var activeDrillRound: GameThemeRound? = nil
    @State private var isPulsing: Bool = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                AppTheme.background.ignoresSafeArea(.all)

                VStack(spacing: 0) {
                    // Top Stats Bar (Streak, Stars, Level)
                    statsBar
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        .padding(.bottom, 10)

                    // CEFR Level Selector (A1, A2, B1, B2, C2)
                    cefrLevelSelector
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)

                    // Thematic Roadmap with Connected Rope
                    roadmapScrollView
                }
            }
            .navigationTitle("Học từ")
            .navigationBarTitleDisplayMode(.inline)
            .fullScreenCover(item: $activeDrillRound) { round in
                GamifiedDrillView(
                    viewModel: viewModel,
                    round: round,
                    onDismiss: {
                        activeDrillRound = nil
                    }
                )
            }
            .onAppear {
                if viewModel.rounds.isEmpty || viewModel.rounds.count < 20 {
                    viewModel.catalogService.reloadCatalogFromSource()
                }
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
        }
    }

    // MARK: - Top Stats Bar (bento gradient mini-cards)
    private var statsBar: some View {
        HStack(spacing: 10) {
            statCard(
                icon: "flame.fill",
                gradient: LinearGradient(colors: [AppTheme.warning, Color(red: 0.95, green: 0.42, blue: 0.25)], startPoint: .topLeading, endPoint: .bottomTrailing),
                value: "\(viewModel.currentStreak)",
                label: "ngày chuỗi"
            )

            statCard(
                icon: "star.fill",
                gradient: LinearGradient(colors: [Color(red: 0.99, green: 0.75, blue: 0.15), Color(red: 0.98, green: 0.55, blue: 0.12)], startPoint: .topLeading, endPoint: .bottomTrailing),
                value: "\(viewModel.totalStars)",
                label: "ngôi sao"
            )

            statCard(
                icon: "trophy.fill",
                gradient: LinearGradient(colors: [Color(red: 0.30, green: 0.45, blue: 0.96), Color(red: 0.62, green: 0.36, blue: 0.96)], startPoint: .topLeading, endPoint: .bottomTrailing),
                value: "C\(viewModel.currentLevel)",
                label: "cấp độ"
            )
        }
    }

    private func statCard(icon: String, gradient: LinearGradient, value: String, label: String) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.22))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }

            Text(value)
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)

            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(gradient)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 3)
    }

    // MARK: - CEFR Level Selector (gradient pills)
    private var cefrLevelSelector: some View {
        HStack(spacing: 8) {
            ForEach(viewModel.cefrLevels, id: \.self) { level in
                let isSelected = viewModel.selectedLevel == level
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        viewModel.selectedLevel = level
                    }
                    HapticFeedback.selection()
                } label: {
                    Text(level)
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(isSelected ? .white : AppTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            isSelected
                                ? AnyShapeStyle(LinearGradient(
                                    colors: [Color(red: 0.30, green: 0.45, blue: 0.96), Color(red: 0.62, green: 0.36, blue: 0.96)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing))
                                : AnyShapeStyle(AppTheme.cardBackground)
                        )
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(isSelected ? Color.clear : Color.primary.opacity(0.08), lineWidth: 0.5)
                        )
                        .shadow(color: isSelected ? Color(red: 0.45, green: 0.4, blue: 0.96).opacity(0.3) : .clear, radius: 6, x: 0, y: 3)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Winding S-Curve Offset (Alternates cleanly without collision)
    private func nodeOffset(for index: Int) -> CGFloat {
        let pattern: [CGFloat] = [0, -65, 0, 65]
        return pattern[index % pattern.count]
    }

    // MARK: - Roadmap ScrollView with Connecting Rope
    private var roadmapScrollView: some View {
        let rounds = viewModel.roundsForSelectedLevel

        return ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // Section Header
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "flag.checkered")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(AppTheme.primary)
                        Text("Trình độ \(viewModel.selectedLevel)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(AppTheme.textSecondary)
                            .textCase(.uppercase)
                    }

                    Spacer()

                    let completedCount = rounds.filter(\.isCompleted).count
                    Text("\(completedCount)/\(rounds.count) vòng hoàn thành")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(AppTheme.primary)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

                if rounds.isEmpty {
                    emptyLevelPlaceholder
                        .padding(.top, 40)
                        .padding(.horizontal, 24)
                } else {
                    // Adventure Trail with Generous 165pt Step Height (Zero Overlap)
                    GeometryReader { geo in
                        let width = geo.size.width
                        let centerX = width / 2
                        let stepHeight: CGFloat = 165
                        let topPadding: CGFloat = 45

                        ZStack(alignment: .top) {
                            // 1. Connecting Rope Background Paths
                            connectingRopeLayer(rounds: rounds, centerX: centerX, stepHeight: stepHeight, topPadding: topPadding)

                            // 2. Interactive Round Nodes
                            ForEach(Array(rounds.enumerated()), id: \.element.id) { index, round in
                                let x = centerX + nodeOffset(for: index)
                                let y = topPadding + CGFloat(index) * stepHeight
                                let isCurrentActive = (round.id == viewModel.currentActiveRoundId)

                                Button {
                                    guard !round.isLocked else {
                                        HapticFeedback.error()
                                        return
                                    }
                                    HapticFeedback.selection()
                                    viewModel.startRound(round: round)
                                    activeDrillRound = round
                                } label: {
                                    roundNode(round: round, index: index, isCurrentActive: isCurrentActive)
                                }
                                .buttonStyle(.plain)
                                .position(x: x, y: y)
                            }

                            // 3. Level Complete Trophy Milestone at end of path
                            if let lastIndex = rounds.indices.last {
                                let y = topPadding + CGFloat(lastIndex) * stepHeight + 95
                                levelTrophyBanner(level: viewModel.selectedLevel)
                                    .position(x: centerX, y: y)
                            }
                        }
                    }
                    .frame(height: CGFloat(rounds.count) * 165 + 130)
                    .padding(.bottom, 50)
                }
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Connecting Rope Path Layer
    @ViewBuilder
    private func connectingRopeLayer(rounds: [GameThemeRound], centerX: CGFloat, stepHeight: CGFloat, topPadding: CGFloat) -> some View {
        if rounds.count > 1 {
            ForEach(0..<(rounds.count - 1), id: \.self) { i in
                let p0 = CGPoint(x: centerX + nodeOffset(for: i), y: topPadding + CGFloat(i) * stepHeight)
                let p1 = CGPoint(x: centerX + nodeOffset(for: i + 1), y: topPadding + CGFloat(i + 1) * stepHeight)
                let midY = (p0.y + p1.y) / 2
                let ctrl1 = CGPoint(x: p0.x, y: midY)
                let ctrl2 = CGPoint(x: p1.x, y: midY)

                let isSegmentCompleted = rounds[i].isCompleted
                let isSegmentUnlocked = !rounds[i + 1].isLocked

                // Base Shadow Track
                Path { path in
                    path.move(to: p0)
                    path.addCurve(to: p1, control1: ctrl1, control2: ctrl2)
                }
                .stroke(
                    AppTheme.primary.opacity(0.12),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round)
                )

                // Foreground Styled Track
                Path { path in
                    path.move(to: p0)
                    path.addCurve(to: p1, control1: ctrl1, control2: ctrl2)
                }
                .stroke(
                    isSegmentCompleted
                        ? AnyShapeStyle(AppTheme.primaryGradient)
                        : (isSegmentUnlocked
                            ? AnyShapeStyle(AppTheme.primary.opacity(0.45))
                            : AnyShapeStyle(Color.gray.opacity(0.22))),
                    style: StrokeStyle(
                        lineWidth: isSegmentCompleted ? 5 : 4,
                        lineCap: .round,
                        lineJoin: .round,
                        dash: isSegmentUnlocked ? [] : [6, 6]
                    )
                )

                // Decorative connector pearl at center of curve
                Circle()
                    .fill(isSegmentCompleted ? AppTheme.primary : (isSegmentUnlocked ? AppTheme.secondary : Color.gray.opacity(0.35)))
                    .frame(width: 8, height: 8)
                    .position(x: (p0.x + p1.x) / 2, y: midY)
            }
        }
    }

    // MARK: - Level Trophy Banner
    private func levelTrophyBanner(level: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "crown.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.yellow)

            Text("Đích đến Cấp độ \(level)")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(AppTheme.cardBackground)
        .clipShape(Capsule())
        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
        .overlay(
            Capsule()
                .stroke(Color.yellow.opacity(0.4), lineWidth: 1)
        )
    }

    // MARK: - Empty Level Placeholder
    private var emptyLevelPlaceholder: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppTheme.primary.opacity(0.1))
                    .frame(width: 80, height: 80)

                Image(systemName: "square.and.pencil")
                    .font(.system(size: 36))
                    .foregroundStyle(AppTheme.primary)
            }

            VStack(spacing: 6) {
                Text("Chưa có vòng học cho Cấp độ \(viewModel.selectedLevel)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(AppTheme.textPrimary)

                Text("Bạn có thể soạn thêm từ vựng và vòng học cho cấp độ \(viewModel.selectedLevel) vào file JSON. App sẽ tự động tải lên lộ trình!")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusCard, style: .continuous))
        .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 3)
    }

    // MARK: - Round Node View (Compact, Clean, Spaced)
    @ViewBuilder
    private func roundNode(round: GameThemeRound, index: Int, isCurrentActive: Bool) -> some View {
        VStack(spacing: 4) {
            // Stars Row (above node)
            starsRow(count: round.starsEarned)

            // Thematic Round Circle
            ZStack {
                // Bottom 3D Bevel Shadow
                Circle()
                    .fill(nodeShadowColor(for: round))
                    .frame(width: 68, height: 68)
                    .offset(y: 3)

                // Main Circle Node
                Circle()
                    .fill(nodeBackground(for: round))
                    .frame(width: 68, height: 68)
                    .shadow(
                        color: round.isCompleted
                            ? AppTheme.success.opacity(0.22)
                            : (round.isLocked ? Color.clear : AppTheme.primary.opacity(0.16)),
                        radius: 6, x: 0, y: 3
                    )
                    .overlay {
                        if isCurrentActive {
                            Circle()
                                .stroke(AppTheme.primary, lineWidth: 3)
                                .scaleEffect(isPulsing ? 1.05 : 1.0)
                        }
                    }

                // Node content (Emoji or Lock)
                if round.isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.gray.opacity(0.45))
                } else {
                    Text(round.iconEmoji)
                        .font(.system(size: 32))
                }

                // Checkmark badge if completed
                if round.isCompleted {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 17))
                                .foregroundStyle(AppTheme.success)
                                .background(Circle().fill(AppTheme.cardBackground).padding(1.5))
                                .offset(x: 2, y: 2)
                        }
                    }
                    .frame(width: 68, height: 68)
                }
            }

            // Labels: BẮT ĐẦU badge (only on current active round) & Titles
            VStack(spacing: 2) {
                if isCurrentActive {
                    Text("BẮT ĐẦU")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2.5)
                        .background(AppTheme.primaryGradient)
                        .clipShape(Capsule())
                }

                Text("Vòng \(round.id)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(round.isLocked ? AppTheme.textTertiary : AppTheme.textPrimary)

                Text(round.title.replacingOccurrences(of: "Vòng \(round.id) – ", with: ""))
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
                    .foregroundStyle(round.isLocked ? AppTheme.textTertiary : AppTheme.textSecondary)
            }
            .frame(width: 110)
        }
    }

    // MARK: - Stars Row
    private func starsRow(count: Int) -> some View {
        HStack(spacing: 3) {
            ForEach(1...3, id: \.self) { star in
                Image(systemName: "star.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(star <= count ? Color.yellow : Color.gray.opacity(0.25))
            }
        }
    }

    // MARK: - Node Background & Shadow
    private func nodeBackground(for round: GameThemeRound) -> some ShapeStyle {
        if round.isCompleted {
            return AnyShapeStyle(Color(red: 0.88, green: 0.95, blue: 0.91))
        } else if round.isLocked {
            return AnyShapeStyle(Color.gray.opacity(0.12))
        } else {
            return AnyShapeStyle(AppTheme.cardBackground)
        }
    }

    private func nodeShadowColor(for round: GameThemeRound) -> Color {
        if round.isCompleted {
            return Color(red: 0.76, green: 0.88, blue: 0.80)
        } else if round.isLocked {
            return Color.gray.opacity(0.18)
        } else {
            return Color.black.opacity(0.08)
        }
    }
}

#Preview {
    GamifiedGameHubView()
}
