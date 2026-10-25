import Foundation

// MARK: - WidgetSnapshot
/// Tiny dependency-free snapshot shared between the app and its widget through
/// the App Group container. Stored as a JSON file (FileManager container URL)
/// rather than a UserDefaults suite: suite-to-container mapping proved flaky on
/// some simulator runtimes, while the shared container itself works everywhere.
enum WidgetDataKeys {
    static let appGroupId = "group.com.locklish.shared"
    static let fileName = "widget-snapshot.json"
}

struct WidgetSnapshot: Codable {
    var dueCount: Int = 0
    var masteredCount: Int = 0
    var totalWords: Int = 0
    var updatedAt: Date = Date()

    private static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: WidgetDataKeys.appGroupId)?
            .appendingPathComponent(WidgetDataKeys.fileName)
    }

    static func load() -> WidgetSnapshot {
        guard let url = fileURL,
              let data = try? Data(contentsOf: url),
              let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) else {
            return WidgetSnapshot()
        }
        return snapshot
    }

    func save() {
        guard let url = Self.fileURL,
              let data = try? JSONEncoder().encode(self) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
