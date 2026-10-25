import SwiftUI
import SwiftData

// MARK: - MainTabView
/// Root navigation container — 4 primary tabs: Từ vựng, Luyện tập, Học từ, Cài đặt.
struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var items: [VocabularyItem]
    @Query private var decks: [VocabularyDeck]

    @State private var selectedTab: Int = 0

    init() {
        // ── Tab Bar Styling ───────────────────────────────────────────
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.11, green: 0.13, blue: 0.15, alpha: 1.0)
                : UIColor.white
        }
        appearance.shadowColor = UIColor.black.withAlphaComponent(0.06)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        // Sage green tint for selected tab icons
        UITabBar.appearance().tintColor = UIColor(red: 0.32, green: 0.47, blue: 0.44, alpha: 1.0)

        // ── Navigation Bar Styling ────────────────────────────────────
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.11, green: 0.13, blue: 0.15, alpha: 1.0)
                : UIColor(red: 0.97, green: 0.97, blue: 0.96, alpha: 1.0)
        }
        navAppearance.shadowColor = UIColor.black.withAlphaComponent(0.05)
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
    }

    var body: some View {
        TabView(selection: $selectedTab) {

            // ── Tab 1: Từ vựng ────────────────────────────────────────
            VocabularyListView()
                .tabItem {
                    Label("Từ vựng", systemImage: "square.stack.3d.up.fill")
                }
                .tag(0)

            // ── Tab 2: Học từ theo vòng ───────────────────────────────
            GamifiedGameHubView()
                .tabItem {
                    Label("Học từ", systemImage: "graduationcap.fill")
                }
                .tag(1)

            // ── Tab 3: Ngữ pháp (Lộ trình · IPA · Bài học) ────────────
            GrammarHubView()
                .tabItem {
                    Label("Ngữ pháp", systemImage: "text.book.closed.fill")
                }
                .tag(2)

            // ── Tab 4: Tin tức tiếng Anh hằng ngày ────────────────────
            NewsListView()
                .tabItem {
                    Label("Tin tức", systemImage: "newspaper.fill")
                }
                .tag(3)

            // ── Tab 5: Cài đặt ────────────────────────────────────────
            SettingsView()
                .tabItem {
                    Label("Cài đặt", systemImage: "gearshape.fill")
                }
                .tag(4)
        }
        .background(AppTheme.background.ignoresSafeArea(.all))
        .onAppear {
            seedSampleDataIfNeeded()
            // Keep the daily reminder's due-word count fresh with real SRS data
            ReviewReminderService.shared.refreshMessage()
            // Push today's due count to the home-screen widget
            WidgetDataStore.refresh(items: items)
            // Returning users (already organizing folders) skip the onboarding
            if !UserDefaults.standard.bool(forKey: "locklish_onboarding_completed") && !decks.isEmpty {
                UserDefaults.standard.set(true, forKey: "locklish_onboarding_completed")
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                WidgetDataStore.refresh(items: items)
            }
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            if oldValue != newValue {
                TTSService.shared.stop()
            }
        }
    }

    // MARK: - Sample Data Seed (first launch only)
    private func seedSampleDataIfNeeded() {
        guard items.isEmpty else { return }
        for sample in VocabularyItem.sampleItems {
            modelContext.insert(sample)
        }
        try? modelContext.save()
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: [VocabularyItem.self, VocabularyDeck.self, DailyPracticeRecord.self], inMemory: true)
}
