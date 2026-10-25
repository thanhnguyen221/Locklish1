import SwiftUI

// MARK: - GrammarHubView
/// Tab "Ngữ pháp": Lộ trình · Bảng IPA · Bài học — one hub, three sections.
struct GrammarHubView: View {
    enum Section: String, CaseIterable, Identifiable {
        case roadmap = "Lộ trình"
        case ipa = "Bảng IPA"
        case lessons = "Bài học"

        var id: String { rawValue }
    }

    @State private var section: Section = .roadmap
    @State private var searchText: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Phân mục", selection: $section) {
                    ForEach(Section.allCases) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(AppTheme.cardBackground)

                switch section {
                case .roadmap:
                    GrammarRoadmapView()
                case .ipa:
                    IPATableView()
                case .lessons:
                    GrammarTopicsListView(searchText: $searchText)
                }
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Ngữ pháp")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
