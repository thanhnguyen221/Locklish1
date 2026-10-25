import SwiftUI
import FamilyControls

// MARK: - FocusLockSettingsView
/// Detailed Screen Time & Focus Lock configuration screen using Apple FamilyControls & ManagedSettings.
struct FocusLockSettingsView: View {
    @State private var screenTime = ScreenTimeService.shared
    @State private var isPickerPresented: Bool = false
    @State private var showDailyUnlockMission: Bool = false
    @State private var scheduledDate: Date = {
        Calendar.current.date(
            bySettingHour: ScreenTimeService.shared.scheduledHour,
            minute: ScreenTimeService.shared.scheduledMinute,
            second: 0,
            of: Date()
        ) ?? Date()
    }()

    var body: some View {
        Form {
            // Section 1: Authorization
            Section {
                HStack(spacing: 12) {
                    Image(systemName: screenTime.isAuthorized ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .font(.title2)
                        .foregroundStyle(screenTime.isAuthorized ? AppTheme.success : AppTheme.warning)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(screenTime.isAuthorized ? "Đã cấp quyền Screen Time" : "Chưa cấp quyền Screen Time")
                            .font(.headline)
                            .foregroundStyle(AppTheme.textPrimary)

                        Text(screenTime.isAuthorized ? "Thiết bị đã sẵn sàng cho chế độ kỷ luật Locklish." : "Cần ủy quyền để có thể khóa ứng dụng gây sao nhãng.")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
                .padding(.vertical, 4)

                if !screenTime.isAuthorized {
                    Button("Yêu cầu quyền truy cập cá nhân") {
                        Task {
                            _ = await screenTime.requestAuthorization()
                        }
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.primary)
                }
            } header: {
                Text("Quyền hạn Screen Time")
            } footer: {
                Text("Apple FamilyControls yêu cầu sự cho phép để bảo vệ sự tập trung của bạn.")
            }

            // Section 2: Distracting Apps & Categories Selection
            Section {
                Button(action: {
                    isPickerPresented = true
                }) {
                    HStack {
                        Label("Chọn ứng dụng cần khóa", systemImage: "apps.iphone")
                            .foregroundStyle(AppTheme.textPrimary)

                        Spacer()

                        let appCount = screenTime.activitySelection.applicationTokens.count
                        let catCount = screenTime.activitySelection.categoryTokens.count

                        Text("\(appCount) ứng dụng, \(catCount) danh mục")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textTertiary)
                    }
                }
                .disabled(!screenTime.isAuthorized)
            } header: {
                Text("Danh sách ứng dụng sao nhãng")
            } footer: {
                Text("Chọn mạng xã hội, game hoặc ứng dụng giải trí bạn muốn bị khóa để tập trung học từ vựng.")
            }

            // Section 3: Scheduled Focus Shielding
            Section {
                Toggle("Khóa tự động theo lịch hẹn", isOn: Binding(
                    get: { screenTime.isScheduleEnabled },
                    set: { newValue in
                        let comp = Calendar.current.dateComponents([.hour, .minute], from: scheduledDate)
                        screenTime.updateSchedule(hour: comp.hour ?? 21, minute: comp.minute ?? 0, enabled: newValue)
                    }
                ))
                .tint(AppTheme.primary)

                if screenTime.isScheduleEnabled {
                    DatePicker(
                        "Thời điểm kích hoạt",
                        selection: $scheduledDate,
                        displayedComponents: .hourAndMinute
                    )
                    .tint(AppTheme.primary)
                    .onChange(of: scheduledDate) { _, newDate in
                        let comp = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                        screenTime.updateSchedule(hour: comp.hour ?? 21, minute: comp.minute ?? 0, enabled: true)
                    }
                }
            } header: {
                Text("Lịch khóa tự động hằng ngày")
            } footer: {
                Text("Mặc định kích hoạt vào 21:00 mỗi tối để bảo vệ thời gian học trước khi ngủ.")
            }

            // Section 4: Daily unlock mission, intentionally kept in Settings
            // so the learning workspace stays dedicated to practice.
            Section {
                Button {
                    HapticFeedback.selection()
                    showDailyUnlockMission = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: screenTime.isShieldActive ? "shield.lefthalf.filled" : "checkmark.shield.fill")
                            .font(.title3)
                            .foregroundStyle(screenTime.isShieldActive ? AppTheme.accent : AppTheme.success)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(screenTime.isShieldActive ? "Làm nhiệm vụ để mở khóa" : "Nhiệm vụ mở khóa hôm nay")
                                .fontWeight(.semibold)
                                .foregroundStyle(AppTheme.textPrimary)
                            Text(screenTime.isShieldActive ? "Chính tả 10 từ, cần đúng 100%" : "Lá chắn đang được gỡ; bạn vẫn có thể luyện lại")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                        }

                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.textTertiary)
                    }
                }
            } header: {
                Text("Mở khóa Focus")
            } footer: {
                Text("Hoàn thành chính tả với độ chính xác 100% để gỡ lá chắn qua quá trình học tập.")
            }

            // Section 5: Shield Status & Manual Trigger
            Section {
                HStack {
                    Text("Trạng thái lá chắn hiện tại")
                    Spacer()
                    Text(screenTime.isShieldActive ? "Đang khóa (Shielded)" : "Bình thường (Unshielded)")
                        .fontWeight(.bold)
                        .foregroundStyle(screenTime.isShieldActive ? AppTheme.accent : AppTheme.success)
                }

                Button(role: screenTime.isShieldActive ? .destructive : .none) {
                    HapticFeedback.medium()
                    if screenTime.isShieldActive {
                        screenTime.clearShield()
                    } else {
                        screenTime.applyShield()
                    }
                } label: {
                    HStack {
                        Image(systemName: screenTime.isShieldActive ? "lock.open.fill" : "lock.fill")
                        Text(screenTime.isShieldActive ? "Dỡ bỏ lá chắn thử nghiệm" : "Bật lá chắn ngay lập tức")
                    }
                    .fontWeight(.medium)
                    .foregroundStyle(screenTime.isShieldActive ? AppTheme.danger : AppTheme.primary)
                    .frame(maxWidth: .infinity)
                }
            } header: {
                Text("Kiểm tra lá chắn thủ công")
            } footer: {
                Text("Trong chu trình thực tế, lá chắn sẽ CHỈ được dỡ bỏ khi bạn đạt 100% điểm bài luyện nghe chính tả trong ngày.")
            }
        }
        .navigationTitle("Cài đặt Focus Lock")
        .navigationBarTitleDisplayMode(.inline)
        .familyActivityPicker(
            isPresented: $isPickerPresented,
            selection: $screenTime.activitySelection
        )
        .onChange(of: screenTime.activitySelection) { _, newSelection in
            screenTime.saveSelection(newSelection)
        }
        .fullScreenCover(isPresented: $showDailyUnlockMission) {
            NavigationStack {
                DictationPracticeView(
                    selectedDeck: nil,
                    isDailyMission: true,
                    onDismissMission: {
                        showDailyUnlockMission = false
                    }
                )
                .navigationTitle("Mở khóa Focus")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            HapticFeedback.light()
                            showDailyUnlockMission = false
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(AppTheme.textTertiary)
                        }
                    }
                }
            }
        }
    }
}
