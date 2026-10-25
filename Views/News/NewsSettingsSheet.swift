import SwiftUI

// MARK: - NewsSettingsSheet
/// News preferences: preferred topics, hidden sources, preferred difficulty.
struct NewsSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var settings = NewsUserSettings.shared

    private let allTopics = ["technology", "science", "business", "health", "world", "education", "learning_english"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Preferred difficulty
                    VStack(alignment: .leading, spacing: 10) {
                        sectionTitle("MỨC ĐỘ ƯA THÍCH", icon: "chart.bar.fill")
                        Text("Dùng cho mục “Hôm nay dành cho bạn” — tin có độ khó ước lượng quanh mức này.")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)

                        HStack(spacing: 8) {
                            ForEach(["A2", "B1", "B2", "C1"], id: \.self) { level in
                                let isSelected = settings.preferredLevel == level
                                Button {
                                    HapticFeedback.selection()
                                    settings.setPreferredLevel(level)
                                } label: {
                                    Text(level)
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundStyle(isSelected ? .white : AppTheme.textSecondary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 9)
                                        .background(isSelected ? AnyShapeStyle(AppTheme.primaryGradient) : AnyShapeStyle(AppTheme.cardBackground))
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Preferred topics
                    VStack(alignment: .leading, spacing: 10) {
                        sectionTitle("CHỦ ĐỀ QUAN TÂM", icon: "folder.fill")
                        Text("Bỏ trống = gợi ý từ mọi chủ đề.")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(allTopics, id: \.self) { topic in
                                let isSelected = settings.preferredTopics.contains(topic)
                                let tint = NewsTopicStyle.color(topic)
                                Button {
                                    HapticFeedback.selection()
                                    settings.togglePreferredTopic(topic)
                                } label: {
                                    HStack(spacing: 8) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                                .fill(isSelected ? AnyShapeStyle(Color.white.opacity(0.2)) : AnyShapeStyle(tint.opacity(0.12)))
                                                .frame(width: 28, height: 28)
                                            Image(systemName: NewsTopicStyle.icon(topic))
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundStyle(isSelected ? .white : tint)
                                        }
                                        Text(topic.newsTopicLabel)
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(isSelected ? .white : AppTheme.textPrimary)
                                        Spacer()
                                    }
                                    .padding(10)
                                    .background(isSelected ? AnyShapeStyle(NewsTopicStyle.gradient(topic)) : AnyShapeStyle(AppTheme.cardBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Sources show/hide
                    VStack(alignment: .leading, spacing: 10) {
                        sectionTitle("NGUỒN TIN", icon: "antenna.radiowaves.left.and.right")
                        Text("Tắt nguồn bạn không muốn thấy trong bảng tin.")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)

                        ForEach(NewsFetchService.shared.loadSources()) { source in
                            let isHidden = settings.hiddenSources.contains(source.id)
                            Button {
                                HapticFeedback.selection()
                                settings.toggleHiddenSource(source.id)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(source.name)
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(AppTheme.textPrimary)
                                        Text("\(source.topic.newsTopicLabel) · \(source.levelHint)")
                                            .font(.caption2)
                                            .foregroundStyle(AppTheme.textTertiary)
                                    }
                                    Spacer()
                                    Toggle("", isOn: Binding(
                                        get: { !isHidden },
                                        set: { _ in settings.toggleHiddenSource(source.id) }
                                    ))
                                    .labelsHidden()
                                    .tint(AppTheme.primary)
                                }
                                .padding(10)
                                .background(AppTheme.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Copyright note
                    Label("Locklish chỉ hiển thị tiêu đề, tóm tắt ngắn và link về bài gốc — không sao chép toàn văn. Nội dung thuộc bản quyền của từng nguồn tin.", systemImage: "info.circle")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textTertiary)
                        .lineSpacing(2)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.primary.opacity(0.03))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .padding(16)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Tuỳ chọn Tin tức")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Xong") { dismiss() }
                        .font(.subheadline.bold())
                        .foregroundStyle(AppTheme.primary)
                }
            }
        }
        .presentationDetents([.large])
    }

    private func sectionTitle(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.caption)
            .fontWeight(.heavy)
            .foregroundStyle(AppTheme.textSecondary)
    }
}
