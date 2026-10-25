import SwiftUI

// MARK: - GrammarTopicsListView
/// All grammar topics with CEFR level filter chips and Vietnamese/English search.
struct GrammarTopicsListView: View {
    @Binding var searchText: String
    @State private var levelFilter: String? = nil
    @State private var progress = GrammarProgressStore.shared
    private let service = GrammarDataService.shared

    private let levels = ["A1", "A2", "B1", "B2"]

    var body: some View {
        let filtered = filteredTopics

        VStack(spacing: 0) {
            // Level filter chips + search field
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    chip(label: "Tất cả", isSelected: levelFilter == nil) {
                        levelFilter = nil
                    }
                    ForEach(levels, id: \.self) { level in
                        chip(label: level, isSelected: levelFilter == level) {
                            levelFilter = level
                        }
                    }
                    Spacer()
                }

                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textTertiary)
                    TextField("Tìm chủ đề (tiếng Anh hoặc Việt)...", text: $searchText)
                        .font(.system(size: 13))
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(AppTheme.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color.primary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            if filtered.isEmpty {
                VStack(spacing: 10) {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 30))
                        .foregroundStyle(AppTheme.textTertiary)
                    Text("Không tìm thấy chủ đề nào")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filtered) { topic in
                            NavigationLink(destination: GrammarLessonView(topicId: topic.id)) {
                                topicRow(topic)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
        }
    }

    // MARK: - Filtering

    private var filteredTopics: [GrammarTopic] {
        var topics = service.allTopics
        if let level = levelFilter {
            topics = topics.filter { $0.level == level }
        }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            topics = topics.filter {
                $0.titleEn.localizedCaseInsensitiveContains(query)
                    || $0.titleVi.localizedCaseInsensitiveContains(query)
            }
        }
        return topics
    }

    // MARK: - Row

    private func topicRow(_ topic: GrammarTopic) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(CEFRLevelHelper.color(for: topic.level).opacity(0.15))
                    .frame(width: 40, height: 40)
                Text(topic.level)
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(CEFRLevelHelper.color(for: topic.level))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(topic.titleVi)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                Text(topic.titleEn)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            if let score = progress.lastScore(for: topic.id) {
                Text("\(score)/\(topic.exercises.count)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(AppTheme.primary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(AppTheme.primary.opacity(0.1))
                    .clipShape(Capsule())
            }

            Image(systemName: progress.isCompleted(topic.id) ? "checkmark.circle.fill" : "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(progress.isCompleted(topic.id) ? AppTheme.success : AppTheme.textTertiary)
        }
        .padding(12)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.05), lineWidth: 0.5)
        )
    }

    private func chip(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            HapticFeedback.selection()
            withAnimation(.easeInOut(duration: 0.15)) { action() }
        } label: {
            Text(label)
                .font(.caption)
                .fontWeight(isSelected ? .bold : .medium)
                .foregroundStyle(isSelected ? .white : AppTheme.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? AnyShapeStyle(AppTheme.primaryGradient) : AnyShapeStyle(AppTheme.cardBackground))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
