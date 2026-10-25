import SwiftUI

// MARK: - AppTheme
/// Eye-soothing, warm, minimalist design system tailored for focus and readability.
/// Built around warm linen surfaces, soft sage greens, dark charcoal typography,
/// and smooth continuous rounded corners.
enum AppTheme {
    // MARK: - Eye-Soothing Palette
    /// Soft Sage Green (#52796F) - primary calming brand color
    static let primary = Color(red: 0.32, green: 0.47, blue: 0.44)
    /// Deeper Pine Sage (#354F52)
    static let primaryDark = Color(red: 0.21, green: 0.31, blue: 0.32)
    /// Light Sage (#84A98C) for gentle highlights
    static let primaryLight = Color(red: 0.52, green: 0.66, blue: 0.55)
    /// Gentle Olive / Earthy Mint
    static let secondary = Color(red: 0.40, green: 0.58, blue: 0.53)
    /// Warm Terracotta / Sand Coral for highlights without harshness
    static let accent = Color(red: 0.85, green: 0.50, blue: 0.40)

    // MARK: - Adaptive Backgrounds (Warm Linen & Pure White)
    /// Light: Warm Off-White / Light Linen (RGB: 0.97, 0.97, 0.96) | Dark: Deep Slate
    static let background = Color(
        UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.11, green: 0.13, blue: 0.15, alpha: 1.0)
                : UIColor(red: 0.97, green: 0.97, blue: 0.96, alpha: 1.0)
        }
    )

    /// Light: Pure White (#FFFFFF) | Dark: Elevated Dark Slate
    static let cardBackground = Color(
        UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.16, green: 0.18, blue: 0.21, alpha: 1.0)
                : UIColor.white
        }
    )

    // MARK: - Typography Colors (Dark Charcoal & Muted Slate)
    /// Dark Charcoal (#222222) for high legibility without pitch-black glare
    static let textPrimary = Color(
        UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.95, green: 0.96, blue: 0.97, alpha: 1.0)
                : UIColor(red: 0.13, green: 0.13, blue: 0.13, alpha: 1.0)
        }
    )

    /// Muted Slate (#666666) for soft subtitles and metadata
    static let textSecondary = Color(
        UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.65, green: 0.68, blue: 0.72, alpha: 1.0)
                : UIColor(red: 0.40, green: 0.40, blue: 0.40, alpha: 1.0)
        }
    )

    static let textTertiary = Color(
        UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.45, green: 0.48, blue: 0.52, alpha: 1.0)
                : UIColor(red: 0.62, green: 0.64, blue: 0.66, alpha: 1.0)
        }
    )

    // MARK: - Status Colors (Subdued & Elegant)
    static let success = Color(red: 0.26, green: 0.62, blue: 0.45) // Soothing emerald
    static let warning = Color(red: 0.88, green: 0.62, blue: 0.26) // Warm amber
    static let danger = Color(red: 0.82, green: 0.36, blue: 0.36)  // Soft crimson

    // MARK: - Gentle Natural Gradients
    static let primaryGradient = LinearGradient(
        colors: [primary, primaryDark],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let sageLightGradient = LinearGradient(
        colors: [primaryLight.opacity(0.2), primary.opacity(0.08)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let focusGradient = LinearGradient(
        colors: [Color(red: 0.18, green: 0.22, blue: 0.25), Color(red: 0.11, green: 0.13, blue: 0.15)],
        startPoint: .top,
        endPoint: .bottom
    )

    static let successGradient = LinearGradient(
        colors: [Color(red: 0.30, green: 0.66, blue: 0.48), Color(red: 0.22, green: 0.54, blue: 0.38)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Continuous Corner Radii
    static let cornerRadiusSmall: CGFloat = 10
    static let cornerRadiusMedium: CGFloat = 18
    static let cornerRadiusCard: CGFloat = 22
    static let cornerRadiusLarge: CGFloat = 26

    // MARK: - Soft Eye-Soothing Elevation
    static func cardShadow<V: View>(_ view: V) -> some View {
        view.shadow(color: Color.black.opacity(0.035), radius: 10, x: 0, y: 4)
    }
}
