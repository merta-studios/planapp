import Foundation

/// Ein kompakter Viertelkreis mit acht gleichmäßig verteilten 48-pt-Buttons.
/// Keine leeren Trennzeichen-Plätze: So passt mehr Bedienfläche auf einen
/// kleineren Radius, ohne dass sich benachbarte Trefferflächen überschneiden.
struct SqueezePaletteLayout {
    static let arcRadius: CGFloat = 224
    static let arcBandWidth: CGFloat = 58
    static let arcHalfAngle: CGFloat = .pi / 4
    static let buttonSize: CGFloat = 48
    static let colorBandWidth: CGFloat = 58
    static let colorSwatchSize: CGFloat = 30
    static let margin: CGFloat = 14
    static let elementCount = 8
    static let colorElementIndex = 6

    static var colorArcRadius: CGFloat {
        arcRadius + arcBandWidth / 2 + colorBandWidth / 2 + 8
    }

    static func colorHalfAngle(for count: Int) -> CGFloat {
        // Auch zusätzliche Farb-Slots behalten mindestens 6 pt Abstand.
        let minimumStep = 2 * asin((buttonSize + 6) / (2 * colorArcRadius))
        return max(27 * .pi / 180, minimumStep * CGFloat(max(0, count - 1)) / 2)
    }

    static func angle(at index: Int, openingAngle: CGFloat) -> CGFloat {
        openingAngle - arcHalfAngle + 2 * arcHalfAngle * CGFloat(index) / CGFloat(elementCount - 1)
    }

    static func offset(radius: CGFloat, angle: CGFloat) -> CGPoint {
        CGPoint(x: radius * cos(angle), y: radius * sin(angle))
    }

    let anchor: CGPoint
    let scale: CGFloat
    /// Inklusive Schatten und aufgeklappter Farben, relativ zum Hover-Anker.
    let bounds: CGRect

    init(hoverAnchor: CGPoint, containerSize: CGSize, openingAngle: CGFloat, colorCount: Int) {
        var bounds = CGRect.zero
        func includeArc(radius: CGFloat, centerAngle: CGFloat, halfAngle: CGFloat, padding: CGFloat) {
            for step in 0...80 {
                let angle = centerAngle - halfAngle + 2 * halfAngle * CGFloat(step) / 80
                let point = Self.offset(radius: radius, angle: angle)
                bounds = bounds.union(CGRect(
                    x: point.x - padding, y: point.y - padding,
                    width: padding * 2, height: padding * 2
                ))
            }
        }
        includeArc(
            radius: Self.arcRadius, centerAngle: openingAngle, halfAngle: Self.arcHalfAngle,
            padding: max(Self.arcBandWidth, Self.buttonSize) / 2 + 10
        )
        includeArc(
            radius: Self.colorArcRadius,
            centerAngle: Self.angle(at: Self.colorElementIndex, openingAngle: openingAngle),
            halfAngle: Self.colorHalfAngle(for: colorCount),
            padding: max(Self.colorBandWidth, Self.buttonSize) / 2 + 10
        )
        self.bounds = bounds

        let availableWidth = max(1, containerSize.width - Self.margin * 2)
        let availableHeight = max(1, containerSize.height - Self.margin * 2)
        let scale = min(1, min(availableWidth / max(1, bounds.width), availableHeight / max(1, bounds.height)))
        self.scale = scale

        let lowerX = Self.margin - bounds.minX * scale
        let lowerY = Self.margin - bounds.minY * scale
        let upperX = max(lowerX, containerSize.width - Self.margin - bounds.maxX * scale)
        let upperY = max(lowerY, containerSize.height - Self.margin - bounds.maxY * scale)
        self.anchor = CGPoint(
            x: min(max(hoverAnchor.x, lowerX), upperX),
            y: min(max(hoverAnchor.y, lowerY), upperY)
        )
    }
}
