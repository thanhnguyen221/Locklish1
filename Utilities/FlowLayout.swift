import SwiftUI

// MARK: - FlowLayout
/// A responsive layout that arranges views horizontally and wraps to subsequent lines
/// when horizontal space is exceeded. Ideal for vocabulary phrases and letter slot groups.
public struct FlowLayout: Layout {
    public var alignment: HorizontalAlignment
    public var spacing: CGFloat
    public var lineSpacing: CGFloat

    public init(alignment: HorizontalAlignment = .center, spacing: CGFloat = 8, lineSpacing: CGFloat = 8) {
        self.alignment = alignment
        self.spacing = spacing
        self.lineSpacing = lineSpacing
    }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var currentPoint = CGPoint.zero
        var maxY: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentPoint.x + size.width > width && currentPoint.x > 0 {
                currentPoint.x = 0
                currentPoint.y += lineHeight + lineSpacing
                lineHeight = 0
            }
            lineHeight = max(lineHeight, size.height)
            currentPoint.x += size.width + spacing
            maxY = max(maxY, currentPoint.y + lineHeight)
        }

        return CGSize(width: width == .infinity ? currentPoint.x : width, height: maxY)
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let width = bounds.width
        var rows: [[(subview: LayoutSubviews.Element, size: CGSize)]] = [[]]
        var currentRowWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentRowWidth + size.width > width && !rows[rows.count - 1].isEmpty {
                rows.append([(subview, size)])
                currentRowWidth = size.width + spacing
            } else {
                rows[rows.count - 1].append((subview, size))
                currentRowWidth += size.width + spacing
            }
        }

        var y = bounds.minY
        for row in rows {
            let rowHeight = row.map(\.size.height).max() ?? 0
            let totalRowWidth = row.map(\.size.width).reduce(0, +) + CGFloat(max(0, row.count - 1)) * spacing

            var x: CGFloat
            switch alignment {
            case .leading:
                x = bounds.minX
            case .trailing:
                x = bounds.maxX - totalRowWidth
            default:
                x = bounds.minX + max(0, (width - totalRowWidth) / 2)
            }

            for item in row {
                item.subview.place(at: CGPoint(x: x, y: y + (rowHeight - item.size.height) / 2), proposal: ProposedViewSize(item.size))
                x += item.size.width + spacing
            }
            y += rowHeight + lineSpacing
        }
    }
}
