import Foundation

// MARK: - NewsUserSettings
/// Per-user news preferences and reading state, persisted with UserDefaults
/// (same lightweight mechanism the app already uses).
@Observable
@MainActor
final class NewsUserSettings {
    static let shared = NewsUserSettings()

    private let topicsKey = "locklish_news_preferred_topics"
    private let hiddenSourcesKey = "locklish_news_hidden_sources"
    private let preferredLevelKey = "locklish_news_preferred_level"
    private let readKey = "locklish_news_read_ids"
    private let savedKey = "locklish_news_saved_ids"

    /// Topics the learner cares about ("Hôm nay dành cho bạn" picks from these).
    private(set) var preferredTopics: Set<String>
    /// Source ids hidden from the feed.
    private(set) var hiddenSources: Set<String>
    /// Preferred difficulty: "A2" / "B1" / "B2" / "C1".
    private(set) var preferredLevel: String
    /// Article ids marked as read / saved for later.
    private(set) var readIds: Set<String>
    private(set) var savedIds: Set<String>

    private init() {
        let d = UserDefaults.standard
        self.preferredTopics = Set(d.stringArray(forKey: topicsKey) ?? [])
        self.hiddenSources = Set(d.stringArray(forKey: hiddenSourcesKey) ?? [])
        let stored = d.string(forKey: preferredLevelKey)
        self.preferredLevel = ["A2", "B1", "B2", "C1"].contains(stored ?? "") ? stored! : "B1"
        self.readIds = Set(d.stringArray(forKey: readKey) ?? [])
        self.savedIds = Set(d.stringArray(forKey: savedKey) ?? [])
    }

    // MARK: - Toggles

    func togglePreferredTopic(_ topic: String) {
        mutate(\.preferredTopics, topic, key: topicsKey)
    }

    func toggleHiddenSource(_ id: String) {
        mutate(\.hiddenSources, id, key: hiddenSourcesKey)
    }

    func setPreferredLevel(_ level: String) {
        preferredLevel = level
        UserDefaults.standard.set(level, forKey: preferredLevelKey)
    }

    func markRead(_ id: String) {
        if !readIds.contains(id) {
            readIds.insert(id)
            UserDefaults.standard.set(Array(readIds), forKey: readKey)
        }
    }

    func toggleSaved(_ id: String) {
        mutate(\.savedIds, id, key: savedKey)
    }

    func isRead(_ id: String) -> Bool { readIds.contains(id) }
    func isSaved(_ id: String) -> Bool { savedIds.contains(id) }

    private func mutate<T>(_ keyPath: ReferenceWritableKeyPath<NewsUserSettings, Set<T>>, _ value: T, key: String) {
        var set = self[keyPath: keyPath]
        if set.contains(value) { set.remove(value) } else { set.insert(value) }
        self[keyPath: keyPath] = set
        UserDefaults.standard.set(Array(set), forKey: key)
    }
}

// MARK: - Topic display names
extension String {
    var newsTopicLabel: String {
        switch self {
        case "technology": return "Công nghệ"
        case "science": return "Khoa học"
        case "business": return "Kinh doanh"
        case "health": return "Sức khỏe"
        case "world": return "Thế giới"
        case "education": return "Giáo dục"
        case "learning_english": return "Học tiếng Anh"
        default: return self
        }
    }
}
