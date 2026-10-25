import SwiftUI
import SwiftData

// MARK: - OnboardingView
/// First-launch flow, 3 steps: pick a goal → learn about smart import →
/// understand the SM-2 review loop. Everything is skippable; finishing sets
/// the completed flag so it never appears again.
struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var page: Int = 0
    @State private var selectedGoal: String? = nil
    @State private var isImportPresented = false

    @AppStorage("locklish_onboarding_completed") private var onboardingCompleted = false
    @AppStorage("locklish_learning_goal") private var learningGoal = ""

    static let goals: [(id: String, icon: String, title: String)] = [
        ("ielts", "graduationcap.fill", "IELTS / TOEIC"),
        ("communication", "bubble.left.and.bubble.right.fill", "Giao tiếp hằng ngày"),
        ("work", "briefcase.fill", "Công việc / IT"),
        ("growth", "leaf.fill", "Phát triển bản thân")
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                goalPage.tag(0)
                importPage.tag(1)
                srsPage.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.25), value: page)

            // Bottom controls
            HStack {
                if page > 0 {
                    Button {
                        HapticFeedback.light()
                        withAnimation { page -= 1 }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                            .frame(width: 38, height: 38)
                            .background(Color.primary.opacity(0.06))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                Button {
                    HapticFeedback.light()
                    completeOnboarding()
                } label: {
                    Text(page == 2 ? "Bắt đầu học" : "Bỏ qua")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 10)

            // Page dots + next
            HStack(spacing: 14) {
                HStack(spacing: 7) {
                    ForEach(0..<3, id: \.self) { i in
                        Capsule()
                            .fill(i == page ? AppTheme.primary : Color.primary.opacity(0.15))
                            .frame(width: i == page ? 22 : 7, height: 7)
                            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: page)
                    }
                }

                Spacer()

                Button {
                    HapticFeedback.selection()
                    if page >= 2 {
                        // Last page: the CTA completes onboarding
                        withAnimation { completeOnboarding() }
                    } else {
                        withAnimation { page += 1 }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text("Tiếp tục")
                            .font(.subheadline)
                            .fontWeight(.bold)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(AppTheme.primaryGradient)
                    .clipShape(Capsule())
                    .shadow(color: AppTheme.primary.opacity(0.25), radius: 8, x: 0, y: 3)
                }
                .buttonStyle(.plain)
                .disabled(page == 0 && selectedGoal == nil)
                .opacity(page == 0 && selectedGoal == nil ? 0.4 : 1)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 22)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .fullScreenCover(isPresented: $isImportPresented) {
            ImportVocabularyView()
        }
    }

    // MARK: - Step 1: Goal
    private var goalPage: some View {
        VStack(spacing: 26) {
            Spacer(minLength: 30)

            ZStack {
                Circle()
                    .fill(AppTheme.sageLightGradient)
                    .frame(width: 110, height: 110)
                Image(systemName: "character.book.closed.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(AppTheme.primary)
            }

            VStack(spacing: 8) {
                Text("Chào mừng đến Locklish!")
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)

                Text("Bạn học tiếng Anh để làm gì? Mình sẽ ưu tiên từ vựng và bài học theo mục tiêu của bạn.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            .padding(.horizontal, 28)

            VStack(spacing: 11) {
                ForEach(Self.goals, id: \.id) { goal in
                    let isSelected = selectedGoal == goal.id
                    Button {
                        HapticFeedback.selection()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedGoal = goal.id
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: goal.icon)
                                .font(.system(size: 17))
                                .foregroundStyle(isSelected ? .white : AppTheme.primary)
                                .frame(width: 38, height: 38)
                                .background(isSelected ? AppTheme.primary : AppTheme.primary.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                            Text(goal.title)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(AppTheme.textPrimary)

                            Spacer()

                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 20))
                                .foregroundStyle(isSelected ? AppTheme.primary : Color.primary.opacity(0.15))
                        }
                        .padding(13)
                        .background(AppTheme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(isSelected ? AppTheme.primary.opacity(0.5) : Color.primary.opacity(0.06), lineWidth: isSelected ? 1.5 : 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 28)

            Spacer(minLength: 20)
        }
    }

    // MARK: - Step 2: Smart Import
    private var importPage: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 34)

            VStack(spacing: 18) {
                featureRow(
                    icon: "doc.text.viewfinder",
                    tint: AppTheme.primary,
                    title: "Dán PDF hoặc văn bản",
                    subtitle: "App tự nhận danh sách từ soạn sẵn, lấy đúng 100% từ và nghĩa bạn đã ghi."
                )
                featureRow(
                    icon: "sparkles",
                    tint: AppTheme.accent,
                    title: "AI chọn từ trọng tâm",
                    subtitle: "Với bài đọc, AI lọc từ vựng đơn đắt giá — kèm phiên âm kiểu Việt tự nhiên."
                )
                featureRow(
                    icon: "play.rectangle.fill",
                    tint: .red,
                    title: "Học qua video YouTube",
                    subtitle: "Phụ đề song ngữ bám từng từ đang nói, chạm để tra từ điển và lưu ngay."
                )
            }
            .padding(20)
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusCard, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusCard, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
            )
            .padding(.horizontal, 24)

            Button {
                HapticFeedback.light()
                isImportPresented = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "wand.and.stars")
                    Text("Trích xuất từ vựng đầu tiên ngay")
                        .fontWeight(.bold)
                }
                .font(.subheadline)
                .foregroundStyle(.white)
                .padding(.horizontal, 22)
                .padding(.vertical, 13)
                .background(AppTheme.primaryGradient)
                .clipShape(Capsule())
                .shadow(color: AppTheme.primary.opacity(0.25), radius: 8, x: 0, y: 3)
            }
            .buttonStyle(.plain)

            Text("Hoặc để sau — bạn có thể mở tính năng này bất cứ lúc nào từ nút “Trích xuất”.")
                .font(.caption)
                .foregroundStyle(AppTheme.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer(minLength: 20)
        }
    }

    // MARK: - Step 3: SRS loop
    private var srsPage: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 34)

            ZStack {
                Circle()
                    .fill(AppTheme.success.opacity(0.1))
                    .frame(width: 104, height: 104)
                Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                    .font(.system(size: 46))
                    .foregroundStyle(AppTheme.success)
            }

            VStack(spacing: 8) {
                Text("Ôn đúng lúc, nhớ dài hạn")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)

                Text("Mỗi từ bạn trả lời đúng sẽ được hẹn ôn lại đúng trước lúc sắp quên: 1 → 6 → 15 → 30+ ngày (thuật toán SM-2 theo nghiên cứu Spaced Repetition). Mỗi folder có biểu đồ lịch ôn và nhắc từ cần học từng ngày.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 30)

            HStack(spacing: 10) {
                srsStepChip(day: "Hôm nay", label: "Học lần đầu")
                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textTertiary)
                srsStepChip(day: "+1 ngày", label: "Ôn lại")
                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textTertiary)
                srsStepChip(day: "+6 ngày", label: "Nhớ vững")
            }
            .padding(.horizontal, 24)

            Spacer(minLength: 20)
        }
    }

    private func featureRow(icon: String, tint: Color, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(tint)
                .frame(width: 42, height: 42)
                .background(tint.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(AppTheme.textPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func srsStepChip(day: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(day)
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(AppTheme.success)
            Text(label)
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(AppTheme.success.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Completion
    private func completeOnboarding() {
        if let selectedGoal {
            learningGoal = selectedGoal
        }
        onboardingCompleted = true
        HapticFeedback.success()
        dismiss()
    }
}
