import WidgetKit
import SwiftUI

// MARK: - Locklish Review Widget
/// Home-screen widget showing today's real SM-2 due count. Data flows one way:
/// the app computes the count from SwiftData and stores a WidgetSnapshot in the
/// shared App Group; the widget only reads that snapshot.
@main
struct LocklishWidgetBundle: WidgetBundle {
    var body: some Widget {
        LocklishReviewWidget()
    }
}

// MARK: - Locklish palette (standalone — the widget can't import the app target)
private enum WidgetTheme {
    static let sage = Color(red: 0.32, green: 0.47, blue: 0.44)
    static let sageDark = Color(red: 0.21, green: 0.31, blue: 0.32)
    static let cream = Color(red: 0.97, green: 0.97, blue: 0.94)
    static let amber = Color(red: 0.88, green: 0.62, blue: 0.26)
}

// MARK: - Timeline
struct ReviewEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct ReviewProvider: TimelineProvider {
    func placeholderEntry() -> ReviewEntry {
        ReviewEntry(date: .now, snapshot: WidgetSnapshot(dueCount: 5, masteredCount: 12, totalWords: 30, updatedAt: .now))
    }

    func placeholder(in context: Context) -> ReviewEntry {
        placeholderEntry()
    }

    func getSnapshot(in context: Context, completion: @escaping (ReviewEntry) -> Void) {
        completion(ReviewEntry(date: .now, snapshot: WidgetSnapshot.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ReviewEntry>) -> Void) {
        // Entries every hour keep the widget alive; a short 2-hour refresh
        // policy makes WidgetKit re-run this provider (re-reading the shared
        // snapshot) even when the app hasn't been opened — the widget never
        // sits stale/"waiting" for days.
        let snapshot = WidgetSnapshot.load()
        let calendar = Calendar.current
        var entries: [ReviewEntry] = [ReviewEntry(date: .now, snapshot: snapshot)]

        for hour in 1...12 {
            if let date = calendar.date(byAdding: .hour, value: hour, to: .now) {
                entries.append(ReviewEntry(date: date, snapshot: snapshot))
            }
        }

        let refreshDate = calendar.date(byAdding: .hour, value: 2, to: .now) ?? .now
        completion(Timeline(entries: entries, policy: .after(refreshDate)))
    }
}

// MARK: - Widget Views
struct ReviewWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ReviewEntry

    private var progressRatio: Double {
        guard entry.snapshot.totalWords > 0 else { return 0 }
        return Double(entry.snapshot.masteredCount) / Double(entry.snapshot.totalWords)
    }

    var body: some View {
        content
            .containerBackground(for: .widget) {
                LinearGradient(
                    colors: [WidgetTheme.sage, WidgetTheme.sageDark],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .widgetURL(URL(string: "locklish://review"))
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .systemSmall:
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Image(systemName: "character.book.closed.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.9))
                    Text("LOCKLISH")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(.white.opacity(0.85))
                        .kerning(1)
                    Spacer()
                }

                Spacer()

                Text("\(entry.snapshot.dueCount)")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.6)

                Text("từ cần ôn")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))

                Text(entry.snapshot.dueCount == 0 ? "Đã ôn đủ hôm nay 🎉" : "Chạm để ôn ngay")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(14)

        default:
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 5) {
                        Image(systemName: "character.book.closed.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white.opacity(0.9))
                        Text("LOCKLISH · Ôn tập")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(.white.opacity(0.85))
                            .kerning(0.6)
                    }

                    Spacer()

                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(entry.snapshot.dueCount)")
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .minimumScaleFactor(0.6)
                        Text("từ cần ôn")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.92))
                    }

                    Text(entry.snapshot.dueCount == 0 ? "Đã ôn đủ hôm nay — quá đỉnh! 🎉" : "Chạm để mở Locklish và ôn ngay")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.white.opacity(0.75))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    ZStack {
                        Circle()
                            .stroke(.white.opacity(0.25), lineWidth: 5)

                        Circle()
                            .trim(from: 0, to: progressRatio)
                            .stroke(.white, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                            .rotationEffect(.degrees(-90))

                        Text("\(Int(progressRatio * 100))%")
                            .font(.system(size: 12, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 52, height: 52)

                    Text("\(entry.snapshot.masteredCount)/\(entry.snapshot.totalWords) đã thuộc")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(16)
        }
    }
}

// MARK: - Widget Definition
struct LocklishReviewWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "LocklishReviewWidget", provider: ReviewProvider()) { entry in
            ReviewWidgetView(entry: entry)
        }
        .configurationDisplayName("Từ cần ôn hôm nay")
        .description("Số từ vựng đến hạn ôn tập theo lịch Spaced Repetition (SM-2). Chạm để mở Locklish ôn ngay.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
