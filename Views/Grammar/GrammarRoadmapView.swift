import SwiftUI

// MARK: - GrammarRoadmapView
/// CEFR roadmap (A1–B2) as a vertical timeline of phase cards. Each card shows
/// level, goal, duration, per-phase progress, and its topic list; tapping a
/// topic opens the lesson.
struct GrammarRoadmapView: View {
    @State private var progress = GrammarProgressStore.shared
    private let service = GrammarDataService.shared

    var body: some View {
        let phases = service.phases
        let totalTopics = service.allTopics.count
        let completed = progress.completedTopics.count
        let overall = progress.overallProgress(totalTopics: totalTopics)

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Overall progress header
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(completed)/\(totalTopics)")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.primary)
                        Text("chủ đề đã học")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                        Spacer()
                        Text("\(Int(overall * 100))%")
                            .font(.system(size: 20, weight: .heavy, design: .rounded))
                            .foregroundStyle(AppTheme.primary)
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.primary.opacity(0.08))
                            Capsule()
                                .fill(AppTheme.primaryGradient)
                                .frame(width: geo.size.width * overall)
                        }
                    }
                    .frame(height: 8)
                }
                .padding(16)
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))

                // Phase timeline
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(phases.enumerated()), id: \.element.id) { index, phase in
                        phaseCard(phase)
                        if index < phases.count - 1 {
                            timelineConnector
                        }
                    }
                }

                Spacer(minLength: 30)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
    }

    // MARK: - Phase Card
    private func phaseCard(_ phase: GrammarPhase) -> some View {
        let topics = service.topicsByPhase[phase.phase] ?? []
        let done = topics.filter { progress.isCompleted($0.id) }.count
        let tint = CEFRLevelHelper.color(for: phase.level)
        let gradient = LinearGradient(colors: [tint, tint.opacity(0.65)], startPoint: .topLeading, endPoint: .bottomTrailing)
        let phaseDone = done >= topics.count && !topics.isEmpty

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                // Level badge — gradient tile
                ZStack {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(gradient)
                        .frame(width: 48, height: 48)
                        .shadow(color: tint.opacity(0.3), radius: 6, x: 0, y: 3)

                    Text(phase.level)
                        .font(.system(size: 19, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("Giai đoạn \(phase.phase) · \(phase.titleVi)")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.textPrimary)

                        Spacer()

                        Text("\(done)/\(topics.count)")
                            .font(.system(size: 12, weight: .heavy, design: .rounded))
                            .foregroundStyle(phaseDone ? .white : tint)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(phaseDone ? AnyShapeStyle(AppTheme.successGradient) : AnyShapeStyle(tint.opacity(0.12)))
                            .clipShape(Capsule())
                    }

                    Text(phase.goalsVi)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineSpacing(2)

                    HStack(spacing: 6) {
                        Label("\(phase.durationWeeks) tuần", systemImage: "clock")
                        Label(phase.ipaFocus.joined(separator: ", "), systemImage: "waveform")
                            .lineLimit(1)
                    }
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textTertiary)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(tint.opacity(0.1))
                            Capsule()
                                .fill(phaseDone ? AnyShapeStyle(AppTheme.successGradient) : AnyShapeStyle(gradient))
                                .frame(width: topics.isEmpty ? 0 : geo.size.width * CGFloat(done) / CGFloat(topics.count))
                        }
                    }
                    .frame(height: 5)
                }
            }

            // Topics of this phase
            VStack(spacing: 6) {
                ForEach(topics) { topic in
                    NavigationLink(destination: GrammarLessonView(topicId: topic.id)) {
                        HStack(spacing: 10) {
                            Image(systemName: progress.isCompleted(topic.id) ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 15))
                                .foregroundStyle(progress.isCompleted(topic.id) ? AppTheme.success : tint.opacity(0.25))

                            VStack(alignment: .leading, spacing: 1) {
                                Text(topic.titleVi)
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundStyle(AppTheme.textPrimary)
                                    .lineLimit(1)
                                Text(topic.titleEn)
                                    .font(.caption2)
                                    .foregroundStyle(AppTheme.textTertiary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(AppTheme.textTertiary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(tint.opacity(progress.isCompleted(topic.id) ? 0.03 : 0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(tint.opacity(0.15), lineWidth: 0.5)
        )
        .shadow(color: tint.opacity(0.12), radius: 10, x: 0, y: 4)
    }

    private var timelineConnector: some View {
        HStack {
            Rectangle()
                .fill(AppTheme.primary.opacity(0.2))
                .frame(width: 3, height: 22)
                .padding(.leading, 36)
            Spacer()
        }
    }
}
