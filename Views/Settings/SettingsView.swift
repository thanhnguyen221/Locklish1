import SwiftUI

// MARK: - SettingsView
/// Tab 3: Redesigned modern configuration center for Gemini AI and learning settings.
struct SettingsView: View {
    @State private var viewModel = SettingsViewModel()
    @State private var isAPIKeyVisible: Bool = false
    @State private var showReloadSuccessToast: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Brand hero stays on top as the visual anchor
                    appHeroHeader

                    // ── HỌC TẬP ──
                    settingsSectionHeader("HỌC TẬP", icon: "graduationcap.fill")
                    methodologyCard
                    dailyReminderCard
                    iCloudSyncCard
                    dataManagementCard

                    // ── AI & DỊCH DỤNG ──
                    settingsSectionHeader("AI & DỊCH DỤNG", icon: "sparkles")
                    geminiAICard

                    // ── GIỚI THIỆU ──
                    settingsSectionHeader("GIỚI THIỆU", icon: "info.circle.fill")
                    appInfoCard

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Cài đặt")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Section Header
    private func settingsSectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(AppTheme.primary)
            Text(title)
                .font(.caption)
                .fontWeight(.heavy)
                .foregroundStyle(AppTheme.textSecondary)
                .tracking(0.8)
            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.top, 6)
    }

    // MARK: - 1. App Hero Header
    private var appHeroHeader: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppTheme.sageLightGradient)
                    .frame(width: 76, height: 76)

                Image(systemName: "character.book.closed.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(AppTheme.primary)
            }

            VStack(spacing: 4) {
                Text("Locklish")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)

                Text("Học từ vựng thông minh cùng AI & Spaced Repetition")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 8) {
                badgePill(text: "iOS 17+", icon: "applelogo")
                badgePill(text: "SwiftData", icon: "cylinder.split.1x2.fill")
                badgePill(text: "Gemini 2.5", icon: "sparkles")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusCard, style: .continuous))
        .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 3)
    }

    private func badgePill(text: String, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
            Text(text)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(AppTheme.primary)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(AppTheme.primary.opacity(0.1))
        .clipShape(Capsule())
    }

    // MARK: - Daily Review Reminder
    private var dailyReminderCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(AppTheme.warning.opacity(0.12))
                        .frame(width: 38, height: 38)
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 17))
                        .foregroundStyle(AppTheme.warning)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Nhắc ôn tập hằng ngày")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Thông báo số từ cần ôn theo lịch Spaced Repetition")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { ReviewReminderService.shared.isEnabled },
                    set: { newValue in
                        HapticFeedback.selection()
                        ReviewReminderService.shared.isEnabled = newValue
                    }
                ))
                .labelsHidden()
                .tint(AppTheme.primary)
            }

            if ReviewReminderService.shared.isEnabled {
                Menu {
                    ForEach([7, 12, 18, 20, 21, 22], id: \.self) { hour in
                        Button {
                            ReviewReminderService.shared.reminderHour = hour
                        } label: {
                            if hour == ReviewReminderService.shared.reminderHour {
                                Label(String(format: "%02d:00", hour), systemImage: "checkmark")
                            } else {
                                Text(String(format: "%02d:00", hour))
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.fill")
                            .font(.caption)
                        Text("Nhắc lúc \(String(format: "%02d:00", ReviewReminderService.shared.reminderHour))")
                            .font(.caption)
                            .fontWeight(.semibold)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2)
                    }
                    .foregroundStyle(AppTheme.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppTheme.primary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusCard, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusCard, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
        )
    }

    // MARK: - iCloud Sync Status
    @State private var cloudStatus: CloudSyncService.SyncStatus = .unknown

    private var iCloudSyncCard: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(CloudSyncService.shared.statusColor.opacity(0.12))
                    .frame(width: 38, height: 38)
                Image(systemName: "icloud.fill")
                    .font(.system(size: 17))
                    .foregroundStyle(CloudSyncService.shared.statusColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(CloudSyncService.shared.statusTitle)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(AppTheme.textPrimary)

                    if CloudSyncService.shared.status == .syncing {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(AppTheme.success)
                    }
                }

                Text(CloudSyncService.shared.statusDetail)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusCard, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusCard, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
        )
        .task {
            await CloudSyncService.shared.refreshStatus()
            cloudStatus = CloudSyncService.shared.status
        }
    }

    // MARK: - 2. Gemini AI Card
    private var geminiAICard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppTheme.primary.opacity(0.12))
                        .frame(width: 38, height: 38)

                    Image(systemName: "sparkles")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(AppTheme.primary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Google Gemini AI")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(AppTheme.textPrimary)

                    Text("Trích xuất từ vựng từ văn bản, PDF & tạo câu ví dụ")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }

            // Key Input Box
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.primary)

                    Group {
                        if isAPIKeyVisible {
                            TextField("AIzaSy...", text: $viewModel.geminiAPIKeyInput)
                        } else {
                            SecureField("AIzaSy...", text: $viewModel.geminiAPIKeyInput)
                        }
                    }
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .font(.system(.subheadline, design: .monospaced))

                    Button {
                        isAPIKeyVisible.toggle()
                    } label: {
                        Image(systemName: isAPIKeyVisible ? "eye.slash.fill" : "eye.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(AppTheme.background)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppTheme.primary.opacity(0.2), lineWidth: 1)
                )

                // Quick Link to Google AI Studio
                Link(destination: URL(string: "https://aistudio.google.com/apikey")!) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 11))
                        Text("Lấy API Key miễn phí tại Google AI Studio")
                            .font(.caption)
                            .underline()
                    }
                    .foregroundStyle(AppTheme.primary)
                }
                .padding(.leading, 4)
            }

            // Action Buttons
            HStack(spacing: 12) {
                Button {
                    viewModel.saveGeminiKey()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: viewModel.showKeySavedToast ? "checkmark" : "square.and.arrow.down.fill")
                            .font(.system(size: 13, weight: .bold))
                        Text(viewModel.showKeySavedToast ? "Đã lưu!" : "Lưu API Key")
                            .font(.subheadline)
                            .fontWeight(.bold)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(viewModel.showKeySavedToast ? AnyShapeStyle(AppTheme.success) : AnyShapeStyle(AppTheme.primaryGradient))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    Task { await viewModel.testGeminiKey() }
                } label: {
                    HStack(spacing: 6) {
                        if viewModel.isTestingKey {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 13, weight: .bold))
                        }
                        Text(viewModel.isTestingKey ? "Đang thử..." : "Kiểm tra")
                            .font(.subheadline)
                            .fontWeight(.bold)
                    }
                    .foregroundStyle(AppTheme.primary)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(AppTheme.primary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isTestingKey)
            }

            // Test Key Result Box
            if let result = viewModel.testKeyResult {
                let isSuccess = result.contains("✅")
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(isSuccess ? AppTheme.success : AppTheme.danger)
                        .font(.subheadline)

                    Text(result)
                        .font(.caption)
                        .foregroundStyle(isSuccess ? AppTheme.success : AppTheme.danger)
                        .lineSpacing(3)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background((isSuccess ? AppTheme.success : AppTheme.danger).opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(18)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusCard, style: .continuous))
        .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 3)
    }

    // MARK: - 3. Learning Methodology Card
    private var methodologyCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppTheme.primary.opacity(0.12))
                        .frame(width: 38, height: 38)

                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(AppTheme.warning)
                }

                Text("Phương pháp học tập")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(AppTheme.textPrimary)
            }

            VStack(spacing: 10) {
                methodologyRow(
                    icon: "mouth.fill",
                    title: "Phiên âm tiếng Việt tự nhiên",
                    detail: "Phiên âm trực giác gần gũi với người Việt: Schedule → /ˈskedʒ.uːl/ → sờ-ké-chồ."
                )

                Divider()
                    .overlay(Color.primary.opacity(0.06))

                methodologyRow(
                    icon: "repeat.circle.fill",
                    title: "Spaced Repetition (SRS SM-2)",
                    detail: "Khoa học ngắt quãng giúp não bộ kích hoạt trí nhớ dài hạn vào đúng thời điểm chuẩn bị quên."
                )

                Divider()
                    .overlay(Color.primary.opacity(0.06))

                methodologyRow(
                    icon: "headphones",
                    title: "Nghe chép chính tả & Lộ trình 20 Vòng",
                    detail: "Luyện phát âm chuẩn US kết hợp gõ phím phản xạ từng ký tự giúp nhớ mặt chữ 100%."
                )
            }
        }
        .padding(18)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusCard, style: .continuous))
        .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 3)
    }

    private func methodologyRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(AppTheme.primary)
                .frame(width: 22)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(AppTheme.textPrimary)

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineSpacing(3)
            }
        }
    }

    // MARK: - 4. Data Management Card
    private var dataManagementCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppTheme.primary.opacity(0.12))
                        .frame(width: 38, height: 38)

                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(AppTheme.primary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Dữ liệu Lộ trình Học từ")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(AppTheme.textPrimary)

                    Text("Cập nhật lại toàn bộ 20 vòng từ vựng theo chủ đề")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }

            Button {
                viewModel.reloadGameCatalog()
                showReloadSuccessToast = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    showReloadSuccessToast = false
                }
            } label: {
                HStack {
                    Image(systemName: showReloadSuccessToast ? "checkmark.circle.fill" : "arrow.counterclockwise")
                        .font(.system(size: 14, weight: .bold))
                    Text(showReloadSuccessToast ? "Đã nạp lại 20 vòng thành công!" : "Tải lại dữ liệu 20 vòng từ vựng")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Spacer()
                }
                .foregroundStyle(showReloadSuccessToast ? AppTheme.success : AppTheme.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background((showReloadSuccessToast ? AppTheme.success : AppTheme.primary).opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusCard, style: .continuous))
        .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 3)
    }

    // MARK: - 5. App Info Card
    private var appInfoCard: some View {
        VStack(spacing: 12) {
            infoRow(title: "Phiên bản", value: "1.0.0 (Build 2026)")
            Divider().overlay(Color.primary.opacity(0.06))
            infoRow(title: "Nền tảng", value: "iOS 17+ · SwiftData")
            Divider().overlay(Color.primary.opacity(0.06))
            infoRow(title: "Âm thanh", value: "AVSpeechSynthesizer (US English)")
        }
        .padding(18)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusCard, style: .continuous))
        .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 3)
    }

    private func infoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(AppTheme.textPrimary)
        }
    }
}

#Preview {
    SettingsView()
}
