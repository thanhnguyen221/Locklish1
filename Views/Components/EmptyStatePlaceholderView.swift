import SwiftUI

// MARK: - EmptyStatePlaceholderView
/// Clean, Apple HIG-style empty state screen for lists and practice decks.
struct EmptyStatePlaceholderView: View {
    let iconName: String
    let title: String
    let subtitle: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppTheme.primary.opacity(0.1))
                    .frame(width: 88, height: 88)

                Image(systemName: iconName)
                    .font(.system(size: 38, weight: .regular))
                    .foregroundStyle(AppTheme.primary)
            }
            .padding(.bottom, 8)

            Text(title)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(AppTheme.textPrimary)
                .multilineTextAlignment(.center)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 32)

            if let actionTitle, let action {
                Button(action: {
                    HapticFeedback.light()
                    action()
                }) {
                    Text(actionTitle)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(AppTheme.primaryGradient)
                        .clipShape(Capsule())
                        .shadow(color: AppTheme.primary.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .padding(.top, 12)
            }
        }
        .padding()
    }
}

#Preview {
    EmptyStatePlaceholderView(
        iconName: "books.vertical.fill",
        title: "Chưa có từ vựng nào",
        subtitle: "Nhập văn bản hoặc tải lên tệp PDF để AI trích xuất từ vựng và phiên âm tiếng Việt tự nhiên.",
        actionTitle: "Thêm từ ngay"
    ) {}
}
