import Foundation
import SwiftUI
import Combine
import FamilyControls
import ManagedSettings
import DeviceActivity

// MARK: - ScreenTimeService
@Observable
@MainActor
final class ScreenTimeService {
    static let shared = ScreenTimeService()

    // MARK: - Managed Settings Store
    private let store = ManagedSettingsStore()
    private let userDefaultsSelectionKey = "locklish_family_activity_selection"
    private let userDefaultsShieldStateKey = "locklish_shield_is_active"
    private let userDefaultsScheduleHourKey = "locklish_schedule_hour"
    private let userDefaultsScheduleMinuteKey = "locklish_schedule_minute"
    private let userDefaultsScheduleEnabledKey = "locklish_schedule_enabled"

    // MARK: - Observable States
    var isAuthorized: Bool = false
    var isShieldActive: Bool = false
    var isScheduleEnabled: Bool = true
    var scheduledHour: Int = 21   // 9:00 PM default
    var scheduledMinute: Int = 0  // 00
    var activitySelection = FamilyActivitySelection()

    private init() {
        loadSettings()
        #if !targetEnvironment(simulator)
        checkAuthorizationStatus()
        #endif
    }

    // MARK: - Authorization
    /// Requests FamilyControls authorization for the individual user's device.
    @MainActor
    func requestAuthorization() async -> Bool {
        #if targetEnvironment(simulator)
        print("Simulator: FamilyControls is only available on physical devices.")
        isAuthorized = false
        return false
        #else
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            checkAuthorizationStatus()
            return isAuthorized
        } catch {
            print("FamilyControls authorization failed: \(error.localizedDescription)")
            isAuthorized = false
            return false
        }
        #endif
    }

    /// Checks the current authorization status.
    func checkAuthorizationStatus() {
        #if targetEnvironment(simulator)
        isAuthorized = false
        #else
        let status = AuthorizationCenter.shared.authorizationStatus
        isAuthorized = (status == .approved)
        #endif
    }

    // MARK: - Shield Operations
    /// Applies restrictions to distracting apps, categories, and web domains selected by user.
    func applyShield() {
        #if targetEnvironment(simulator)
        print("Simulator: Shield simulated.")
        isShieldActive = true
        UserDefaults.standard.set(true, forKey: userDefaultsShieldStateKey)
        #else
        guard !activitySelection.applicationTokens.isEmpty ||
              !activitySelection.categoryTokens.isEmpty ||
              !activitySelection.webDomainTokens.isEmpty else {
            print("Locklish: No apps or categories selected to shield.")
            return
        }

        // Apply application shielding
        store.shield.applications = activitySelection.applicationTokens.isEmpty ? nil : activitySelection.applicationTokens

        // Apply category shielding
        if !activitySelection.categoryTokens.isEmpty {
            store.shield.applicationCategories = ShieldSettings.ActivityCategoryPolicy.specific(activitySelection.categoryTokens)
        } else {
            store.shield.applicationCategories = nil
        }

        // Apply web domains shielding
        store.shield.webDomains = activitySelection.webDomainTokens.isEmpty ? nil : activitySelection.webDomainTokens

        isShieldActive = true
        UserDefaults.standard.set(true, forKey: userDefaultsShieldStateKey)
        print("Locklish Focus Shield ACTIVATED.")
        #endif
    }

    /// Clears and removes all active shields.
    /// This is triggered ONLY when Locklish daily Dictation practice reaches 100% completion.
    func clearShield() {
        #if !targetEnvironment(simulator)
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
        #endif

        isShieldActive = false
        UserDefaults.standard.set(false, forKey: userDefaultsShieldStateKey)
        print("Locklish Focus Shield CLEARED. Freedom earned!")
    }

    // MARK: - Selection Persistence
    func saveSelection(_ newSelection: FamilyActivitySelection) {
        self.activitySelection = newSelection
        do {
            let data = try JSONEncoder().encode(newSelection)
            UserDefaults.standard.set(data, forKey: userDefaultsSelectionKey)
        } catch {
            print("Failed to save FamilyActivitySelection: \(error.localizedDescription)")
        }

        // If shield is currently active, update shield with new selection
        if isShieldActive {
            applyShield()
        }
    }

    private func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsSelectionKey) {
            do {
                self.activitySelection = try JSONDecoder().decode(FamilyActivitySelection.self, from: data)
            } catch {
                print("Failed to decode saved FamilyActivitySelection: \(error.localizedDescription)")
            }
        }

        self.isShieldActive = UserDefaults.standard.bool(forKey: userDefaultsShieldStateKey)
        self.scheduledHour = UserDefaults.standard.object(forKey: userDefaultsScheduleHourKey) != nil
            ? UserDefaults.standard.integer(forKey: userDefaultsScheduleHourKey)
            : 21
        self.scheduledMinute = UserDefaults.standard.integer(forKey: userDefaultsScheduleMinuteKey)
        self.isScheduleEnabled = UserDefaults.standard.object(forKey: userDefaultsScheduleEnabledKey) != nil
            ? UserDefaults.standard.bool(forKey: userDefaultsScheduleEnabledKey)
            : true
    }

    func updateSchedule(hour: Int, minute: Int, enabled: Bool) {
        self.scheduledHour = hour
        self.scheduledMinute = minute
        self.isScheduleEnabled = enabled

        UserDefaults.standard.set(hour, forKey: userDefaultsScheduleHourKey)
        UserDefaults.standard.set(minute, forKey: userDefaultsScheduleMinuteKey)
        UserDefaults.standard.set(enabled, forKey: userDefaultsScheduleEnabledKey)

        configureDeviceActivitySchedule()
    }

    // MARK: - DeviceActivity Monitoring Schedule
    /// Configures DeviceActivitySchedule for automatic daily shielding (e.g. 9:00 PM nightly lock).
    private func configureDeviceActivitySchedule() {
        guard isAuthorized, isScheduleEnabled else { return }

        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: scheduledHour, minute: scheduledMinute),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )

        let activityName = DeviceActivityName("LocklishDailyShield")
        let center = DeviceActivityCenter()

        do {
            center.stopMonitoring([activityName])
            try center.startMonitoring(activityName, during: schedule)
            print("Locklish: Scheduled focus shielding set for \(scheduledHour):\(String(format: "%02d", scheduledMinute)).")
        } catch {
            print("Failed to start DeviceActivity monitoring: \(error.localizedDescription)")
        }
    }
}
