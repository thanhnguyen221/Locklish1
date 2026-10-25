import SwiftUI
import SwiftData
import Charts

// MARK: - DeckStatsView
/// Per-deck spaced-repetition statistics powered by the SM-2 (SuperMemo) engine.
/// All numbers come from ONE pass over the deck's items — the screen used to
/// walk the collection 15+ times per render.
struct DeckStatsView: View {
    @Bindable var deck: VocabularyDeck
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// Single-pass aggregation of every statistic the screen shows.
    private struct Stats {
        var dueItems: [VocabularyItem] = []       // review lands today or earlier
        var newItems: [VocabularyItem] = []       // never practiced
        var learning = 0
        var mastered = 0
        var overdue = 0
        var forecastCounts = [Int](repeating: 0, count: 14) // words per day, today + 13
        var dayBuckets = [[VocabularyItem]](repeating: [], count: 8) // index 1...7
        var farFuture: [VocabularyItem] = []      // next review beyond day 7
    }

    private func buildStats() -> Stats {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        var stats = Stats()

        for item in deck.items {
            guard let reviewed = item.lastReviewedDate else {
                stats.newItems.append(item)
                continue
            }
            _ = reviewed
            if item.isMastered { stats.mastered += 1 } else { stats.learning += 1 }

            let offset = calendar.dateComponents(
                [.day],
                from: startOfToday,
                to: calendar.startOfDay(for: item.nextReviewDate)
            ).day ?? 0

            if offset <= 0 {
                stats.dueItems.append(item)
                if offset < 0 { stats.overdue += 1 }
                stats.forecastCounts[0] += 1
            } else if offset < 8 {
                stats.dayBuckets[offset].append(item)
                if offset < 14 { stats.forecastCounts[offset] += 1 }
            } else {
                stats.farFuture.append(item)
                if offset < 14 { stats.forecastCounts[offset] += 1 }
            }
        }

        stats.dueItems.sort { $0.nextReviewDate < $1.nextReviewDate }
        stats.farFuture.sort { $0.nextReviewDate < $1.nextReviewDate }
        return stats
    }

    var body: some View {
        let stats = buildStats()

        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Wide screens (iPad / landscape Max): hero card and chart side by side
                if horizontalSizeClass == .regular {
                    HStack(alignment: .top, spacing: 20) {
                        todayCard(stats)
                        forecastCard(stats)
                    }
                } else {
                    todayCard(stats)
                    forecastCard(stats)
                }
                wordBreakdownSection(stats)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .background(AppTheme.background.ignoresSafeArea(.all))
        .navigationTitle("Thống kê ôn tập")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Helpers

    private var startOfToday: Date {
        Calendar.current.startOfDay(for: Date())
    }

    /// Memory strength 0...1 from the SM-2 interval: 21+ days ≈ long-term memory.
    private func memoryStrength(_ item: VocabularyItem) -> Double {
        guard item.lastReviewedDate != nil else { return 0 }
        return min(1, Double(max(item.intervalDays, 0)) / 21.0)
    }

    private func strengthColor(_ strength: Double) -> Color {
        if strength >= 0.66 { return AppTheme.success }
        if strength >= 0.33 { return AppTheme.warning }
        return .red
    }

    /// Short human status for one word: when it comes back.
    private func statusLabel(_ item: VocabularyItem) -> String {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        if item.lastReviewedDate == nil { return "Chưa học" }
        let offset = calendar.dateComponents([.day], from: startOfToday, to: calendar.startOfDay(for: item.nextReviewDate)).day ?? 0
        if offset < 0 { return "Quá hạn \(max(1, -offset)) ngày" }
        if offset == 0 { return "Ôn hôm nay" }
        return offset == 1 ? "Ngày mai" : "Sau \(offset) ngày"
    }

    private func statusColor(_ item: VocabularyItem) -> Color {
        if item.lastReviewedDate == nil { return AppTheme.textTertiary }
        if item.nextReviewDate < startOfToday { return .red }
        if item.nextReviewDate < Calendar.current.date(byAdding: .day, value: 1, to: startOfToday)! { return AppTheme.primary }
        return AppTheme.textSecondary
    }

    private func dayLabel(for date: Date) -> String {
        let calendar = Calendar.current
        let offset = calendar.dateComponents([.day], from: startOfToday, to: calendar.startOfDay(for: date)).day ?? 0
        switch offset {
        case 0: return "Hôm nay"
        case 1: return "Ngày mai"
        default:
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "vi_VN")
            formatter.dateFormat = "EEEE · dd/MM"
            return formatter.string(from: date).capitalized
        }
    }

    // MARK: - Today Hero Card

    private func todayCard(_ stats: Stats) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(stats.dueItems.count)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(stats.dueItems.isEmpty ? AppTheme.success : AppTheme.primary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("từ cần ôn hôm nay")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(AppTheme.textPrimary)

                    if stats.overdue > 0 {
                        Text("trong đó \(stats.overdue) từ đã trễ hẹn")
                            .font(.caption)
                            .foregroundStyle(AppTheme.warning)
                    }
                }

                Spacer()
            }

            // Mastery chips — plain language, one row, no chart to decode
            HStack(spacing: 10) {
                masteryChip(icon: "checkmark.seal.fill", color: AppTheme.success, label: "Đã thuộc", count: stats.mastered)
                masteryChip(icon: "arrow.triangle.2.circlepath", color: AppTheme.warning, label: "Đang học", count: stats.learning)
                masteryChip(icon: "sparkles", color: AppTheme.textTertiary, label: "Chưa học", count: stats.newItems.count)
            }

            // Study right away — jumps straight into the SM-2 due queue
            if !stats.dueItems.isEmpty {
                NavigationLink(destination: FlashcardPracticeView(selectedDeck: deck)) {
                    HStack(spacing: 8) {
                        Image(systemName: "bolt.fill")
                        Text("Ôn ngay \(stats.dueItems.count) từ")
                            .fontWeight(.bold)
                        Spacer()
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 20))
                    }
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(colors: [AppTheme.primary, AppTheme.primaryDark], startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .simultaneousGesture(TapGesture().onEnded { HapticFeedback.selection() })
            }

            Text(stats.newItems.isEmpty
                 ? "Bạn đã học hết mọi từ trong folder này — giờ chỉ cần ôn đúng lịch."
                 : "\(stats.newItems.count) từ mới sẽ tự vào lịch ngay khi bạn học lần đầu (mỗi từ ôn đúng sẽ được hẹn ôn lại xa dần: 1 → 6 → 15… ngày).")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusCard, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusCard, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
        )
    }

    private func masteryChip(icon: String, color: Color, label: String, count: Int) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(color)
            Text("\(count) \(label.lowercased())")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(AppTheme.textPrimary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }

    // MARK: - 14-Day Forecast Chart (mountain-style up/down line)

    private struct ForecastPoint: Identifiable {
        let id: Date
        let date: Date
        let count: Int
    }

    private func forecastCard(_ stats: Stats) -> some View {
        let calendar = Calendar.current
        let points: [ForecastPoint] = (0..<14).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: startOfToday).map {
                ForecastPoint(id: $0, date: $0, count: stats.forecastCounts[offset])
            }
        }
        let hasHistory = stats.mastered + stats.learning > 0

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("LỊCH ÔN 14 NGÀY TỚI")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(AppTheme.textSecondary)

                Spacer()

                if stats.overdue > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                        Text("\(stats.overdue) quá hạn")
                            .font(.caption2)
                            .fontWeight(.bold)
                    }
                    .foregroundStyle(AppTheme.warning)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppTheme.warning.opacity(0.1))
                    .clipShape(Capsule())
                }
            }

            if hasHistory {
                forecastChart(points)
                forecastSummary(points)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "chart.xyaxis.line")
                        .font(.system(size: 28))
                        .foregroundStyle(AppTheme.textTertiary)
                    Text("Chưa có lịch ôn nào. Học Flashcard hoặc Chép chính tả lần đầu là biểu đồ sẽ tự vẽ.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }
        }
        .padding(18)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusCard, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusCard, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
        )
    }

    private func forecastChart(_ points: [ForecastPoint]) -> some View {
        let maxCount = points.map(\.count).max() ?? 0

        return Chart(points) { point in
            AreaMark(
                x: .value("Ngày", point.date),
                y: .value("Số từ", point.count)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(
                .linearGradient(
                    colors: [AppTheme.primary.opacity(0.30), AppTheme.primary.opacity(0.02)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            LineMark(
                x: .value("Ngày", point.date),
                y: .value("Số từ", point.count)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(AppTheme.primary)
            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))

            PointMark(
                x: .value("Ngày", point.date),
                y: .value("Số từ", point.count)
            )
            .foregroundStyle(AppTheme.primary)
            .symbolSize(maxCount > 0 ? 28 : 0)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 2)) {
                AxisGridLine()
                AxisValueLabel(format: .dateTime.day(), centered: true)
                    .font(.caption2)
            }
        }
        .chartYAxis {
            // Review counts are whole words — never show fractional ticks
            AxisMarks(values: maxCount > 0 && maxCount <= 8 ? AxisMarkValues.stride(by: 1) : AxisMarkValues.automatic(desiredCount: 4)) {
                AxisGridLine()
                AxisValueLabel()
                    .font(.caption2)
            }
        }
        .frame(height: 150)
    }

    /// One plain-language summary line under the chart.
    private func forecastSummary(_ points: [ForecastPoint]) -> some View {
        let scheduled = points.map(\.count).reduce(0, +)
        let peak = points.max { $0.count < $1.count } ?? points.first
        let average = points.isEmpty ? 0 : Double(scheduled) / Double(points.count)

        return HStack(spacing: 14) {
            if scheduled == 0 {
                Label("7 ngày tới không có từ nào đến hạn — lịch đang rất nhẹ.", systemImage: "leaf.fill")
                    .font(.caption)
                    .foregroundStyle(AppTheme.success)
            } else {
                if let peak, peak.count > 0 {
                    Label("Nhiều nhất: \(peak.count) từ · \(dayLabel(for: peak.date))", systemImage: "arrow.up.right")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Label("Trung bình \(String(format: "%.1f", average)) từ/ngày", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }

    // MARK: - Per-Word Breakdown (strength + real review counts)

    private struct WordGroup: Identifiable {
        let id: String
        let title: String
        let icon: String
        let tint: Color
        let items: [VocabularyItem]
    }

    private func wordGroups(_ stats: Stats) -> [WordGroup] {
        var groups: [WordGroup] = []

        if !stats.dueItems.isEmpty {
            groups.append(WordGroup(
                id: "due",
                title: stats.dueItems.count == 1 ? "1 từ đang chờ bạn ôn" : "\(stats.dueItems.count) từ đang chờ bạn ôn",
                icon: "bell.badge.fill",
                tint: .red,
                items: stats.dueItems
            ))
        }

        for offset in 1...7 {
            let words = stats.dayBuckets[offset]
            if !words.isEmpty {
                let calendar = Calendar.current
                let title = offset == 1
                    ? "Ngày mai — \(words.count) từ"
                    : "\(dayLabel(for: calendar.date(byAdding: .day, value: offset, to: startOfToday)!)) — \(words.count) từ"
                groups.append(WordGroup(id: "day-\(offset)", title: title, icon: "calendar", tint: AppTheme.primary, items: words))
            }
        }

        if !stats.farFuture.isEmpty {
            groups.append(WordGroup(
                id: "far",
                title: "Nhắc lại sau 7 ngày tới — \(stats.farFuture.count) từ",
                icon: "leaf.fill",
                tint: AppTheme.success,
                items: stats.farFuture
            ))
        }

        if !stats.newItems.isEmpty {
            groups.append(WordGroup(
                id: "new",
                title: "Chưa học lần nào — \(stats.newItems.count) từ",
                icon: "sparkles",
                tint: AppTheme.textTertiary,
                items: stats.newItems
            ))
        }

        return groups
    }

    private func wordBreakdownSection(_ stats: Stats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TỪNG TỪ MỘT")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(AppTheme.textSecondary)

            Text("Thanh màu = sức nhớ hiện tại của từ (dài hơn = nhớ vững hơn). Số lần ôn là số thật đã luyện.")
                .font(.caption)
                .foregroundStyle(AppTheme.textTertiary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(wordGroups(stats)) { group in
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 7) {
                        Image(systemName: group.icon)
                            .font(.caption)
                            .foregroundStyle(group.tint)
                        Text(group.title)
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(AppTheme.textPrimary)
                    }

                    ForEach(group.items.prefix(8)) { item in
                        wordRow(item)
                    }

                    if group.items.count > 8 {
                        Text("+ \(group.items.count - 8) từ nữa")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.textTertiary)
                            .padding(.leading, 4)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous)
                        .stroke(Color.primary.opacity(0.05), lineWidth: 0.5)
                )
            }
        }
    }

    private func wordRow(_ item: VocabularyItem) -> some View {
        let strength = memoryStrength(item)

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(item.word)
                    .font(.system(size: 14.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)

                Spacer()

                Text(statusLabel(item))
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(statusColor(item))
            }

            if !item.meaning.isEmpty {
                Text(item.meaning)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(1)
            }

            HStack(spacing: 10) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.primary.opacity(0.07))
                        Capsule()
                            .fill(strengthColor(strength))
                            .frame(width: max(4, geo.size.width * strength))
                    }
                }
                .frame(height: 5)

                Text(reviewCountLabel(item))
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textTertiary)
                    .fixedSize()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color.primary.opacity(0.035))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func reviewCountLabel(_ item: VocabularyItem) -> String {
        if item.reviewCount > 0 { return "Đã ôn \(item.reviewCount) lần" }
        if item.lastReviewedDate != nil { return "Đã từng ôn" }
        return "Chưa ôn"
    }
}
