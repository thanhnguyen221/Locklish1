import SwiftUI

// MARK: - NewsTopicStyle
/// Vibrant per-topic identity (2025-26 bento/gradient trend): every topic gets
/// its own color, gradient, and SF Symbol so the feed scans like a bento grid.
enum NewsTopicStyle {
    static func color(_ topic: String) -> Color {
        switch topic {
        case "technology": return Color(red: 0.30, green: 0.45, blue: 0.96)   // electric blue
        case "science": return Color(red: 0.62, green: 0.36, blue: 0.96)      // violet
        case "business": return Color(red: 0.06, green: 0.66, blue: 0.52)     // emerald
        case "health": return Color(red: 0.94, green: 0.32, blue: 0.50)       // rose
        case "world": return Color(red: 0.98, green: 0.55, blue: 0.15)        // amber
        case "education": return Color(red: 0.25, green: 0.38, blue: 0.88)    // indigo
        case "learning_english": return Color(red: 0.05, green: 0.62, blue: 0.62) // teal
        default: return AppTheme.primary
        }
    }

    static func gradient(_ topic: String) -> LinearGradient {
        LinearGradient(
            colors: [color(topic), color(topic).opacity(0.65)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func icon(_ topic: String) -> String {
        switch topic {
        case "technology": return "cpu.fill"
        case "science": return "atom"
        case "business": return "chart.line.uptrend.xyaxis"
        case "health": return "heart.circle.fill"
        case "world": return "globe.asia.australia.fill"
        case "education": return "graduationcap.fill"
        case "learning_english": return "text.bubble.fill"
        default: return "newspaper.fill"
        }
    }

    static func label(_ topic: String) -> String {
        topic.newsTopicLabel
    }
}
