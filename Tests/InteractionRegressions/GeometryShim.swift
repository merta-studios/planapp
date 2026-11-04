import Foundation

// Minimale CoreGraphics-Ersatztypen für die Regressions-Tests auf Linux.
//
// Die App benutzt auf iOS `CoreGraphics` (`CGSize`, `CGPoint`, `CGFloat`, …).
// Das Modul gibt es auf Linux nicht. Diese Datei stellt genau die Typen und
// Operationen bereit, die die reinen Policy-/Layout-Dateien der App verwenden –
// damit dieselben Dateien ohne Änderung mitübersetzt und getestet werden
// können. Auf iOS/macOS wird sie nie kompiliert.

#if !canImport(CoreGraphics)

public typealias CGFloat = Double

public struct CGPoint: Equatable {
    public var x: CGFloat
    public var y: CGFloat

    public init(x: CGFloat = 0, y: CGFloat = 0) {
        self.x = x
        self.y = y
    }

    public static let zero = CGPoint()
}

public struct CGSize: Equatable {
    public var width: CGFloat
    public var height: CGFloat

    public init(width: CGFloat = 0, height: CGFloat = 0) {
        self.width = width
        self.height = height
    }

    public static let zero = CGSize()
}

public struct CGRect: Equatable {
    public var origin: CGPoint
    public var size: CGSize

    public init(origin: CGPoint = .zero, size: CGSize = .zero) {
        self.origin = origin
        self.size = size
    }

    public init(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
        self.init(origin: CGPoint(x: x, y: y), size: CGSize(width: width, height: height))
    }

    public static let zero = CGRect()

    public var width: CGFloat { size.width }
    public var height: CGFloat { size.height }
    public var minX: CGFloat { origin.x }
    public var minY: CGFloat { origin.y }
    public var maxX: CGFloat { origin.x + size.width }
    public var maxY: CGFloat { origin.y + size.height }
    public var midX: CGFloat { origin.x + size.width / 2 }
    public var midY: CGFloat { origin.y + size.height / 2 }

    /// Kleinste Hülle beider Rechtecke (wie in CoreGraphics).
    public func union(_ other: CGRect) -> CGRect {
        let newMinX = min(minX, other.minX)
        let newMinY = min(minY, other.minY)
        let newMaxX = max(maxX, other.maxX)
        let newMaxY = max(maxY, other.maxY)
        return CGRect(
            x: newMinX,
            y: newMinY,
            width: newMaxX - newMinX,
            height: newMaxY - newMinY
        )
    }

    public func contains(_ point: CGPoint) -> Bool {
        point.x >= minX && point.x <= maxX && point.y >= minY && point.y <= maxY
    }
}

#endif
