import SwiftUI

// MARK: - View Modifiers & Styling Extensions
extension View {
    /// Applies a clean, eye-soothing card style with continuous rounded corners (18-22pt),
    /// subtle 0.5pt border, and soft elevation.
    func locklishCardStyle(
        cornerRadius: CGFloat = AppTheme.cornerRadiusMedium,
        backgroundColor: Color = AppTheme.cardBackground
    ) -> some View {
        self
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.035), radius: 10, x: 0, y: 4)
    }

    /// Applies a minimalist frosted card surface with soft outline.
    func locklishGlassCard(cornerRadius: CGFloat = AppTheme.cornerRadiusMedium) -> some View {
        self
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
    }
}
