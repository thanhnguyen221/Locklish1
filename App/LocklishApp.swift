import SwiftUI
import SwiftData

// MARK: - LocklishApp
/// Locklish: AI Focus Vocabulary App
@main
struct LocklishApp: App {
    let sharedModelContainer: ModelContainer = {
        // The CloudKit-compatible schema change (dropped unique constraints,
        // added defaults) migrates the store on first open — snapshot it once
        // beforehand as cheap insurance for the user's data.
        Self.backupLegacyStoreOnce()

        let schema = Schema([VocabularyDeck.self, VocabularyItem.self, DailyPracticeRecord.self])

        // Attempt 1: open the configured store as-is.
        do {
            let config = ModelConfiguration("LocklishData", schema: schema, isStoredInMemoryOnly: false)
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            print("ModelContainer primary open failed: \(error)")
        }

        // Attempt 2: same file with CloudKit mirroring disabled — CK mirror
        // metadata written by a differently-signed session can block loading.
        if let container = try? ModelContainer(
            for: schema,
            configurations: [ModelConfiguration("LocklishData", schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: .none)]
        ) {
            print("ModelContainer recovered with CloudKit disabled (local-only mode).")
            return container
        }

        // Attempt 3: the store file itself is unreadable. Quarantine it (kept
        // for manual recovery) and start a fresh store — the app must never
        // crash-loop at launch.
        Self.quarantineUnreadableStore()
        if let container = try? ModelContainer(
            for: schema,
            configurations: [ModelConfiguration("LocklishData", schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: .none)]
        ) {
            print("ModelContainer started with a FRESH store; the unreadable one was quarantined.")
            return container
        }

        // Last resort: in-memory so the app still runs this session.
        print("ModelContainer falling back to in-memory store.")
        if let container = try? ModelContainer(
            for: schema,
            configurations: [ModelConfiguration("LocklishData", schema: schema, isStoredInMemoryOnly: true)]
        ) {
            return container
        }
        fatalError("Could not create any ModelContainer")
    }()

    /// Moves an unloadable store (plus its -wal/-shm sidecars) aside under a
    /// timestamped name instead of deleting it — recovery stays possible.
    private static func quarantineUnreadableStore() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        guard let dir = support else { return }
        let fm = FileManager.default
        let stamp = Int(Date().timeIntervalSince1970)
        for name in ["LocklishData.store", "LocklishData.store-wal", "LocklishData.store-shm"] {
            let source = dir.appendingPathComponent(name)
            guard fm.fileExists(atPath: source.path) else { continue }
            let target = dir.appendingPathComponent("Recovery-\(stamp)-\(name)")
            try? fm.moveItem(at: source, to: target)
        }
    }

    private static func backupLegacyStoreOnce() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        guard let dir = support else { return }
        let store = dir.appendingPathComponent("LocklishData.store")
        let backup = dir.appendingPathComponent("LocklishData.backup-once.store")
        let fm = FileManager.default
        guard fm.fileExists(atPath: store.path),
              !fm.fileExists(atPath: backup.path) else { return }
        try? fm.copyItem(at: store, to: backup)
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .tint(AppTheme.primary)
                // ✅ Fill the ENTIRE screen — including dynamic island & home indicator
                .background(AppTheme.background)
                .ignoresSafeArea(.all)
                .fullScreenCover(isPresented: .init(
                    get: { !UserDefaults.standard.bool(forKey: "locklish_onboarding_completed") },
                    set: { _ in }
                )) {
                    OnboardingView()
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
