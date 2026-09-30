import Foundation
import CoreGraphics

/// Ein frei bewegliches Textfeld auf der Zeichenfläche einer Stunden-Notiz.
/// Koordinaten sind in Punkt-Koordinaten der Zeichenfläche (unskaliert).
public struct NoteTextBox: Identifiable, Codable, Equatable {
    public var id: UUID
    public var text: String
    public var x: Double        // linke obere Ecke, X
    public var y: Double        // linke obere Ecke, Y
    public var width: Double    // Breite des Feldes (Text bricht automatisch um)
    public var fontSize: Double

    public init(
        id: UUID = UUID(),
        text: String = "",
        x: Double,
        y: Double,
        width: Double = 240,
        fontSize: Double = 17
    ) {
        self.id = id
        self.text = text
        self.x = x
        self.y = y
        self.width = width
        self.fontSize = fontSize
    }

    /// Defensive Normalisierung für geladene oder per OCR erzeugte Textfelder.
    /// Ungültige Zahlen (NaN/∞) führen in SwiftUI bei `frame`/`offset` zu
    /// Laufzeit-Abbrüchen; deshalb werden sie konsequent auf sichere Werte
    /// geklemmt.
    public func sanitized(in areaSize: CGSize? = nil) -> NoteTextBox? {
        let fallbackWidth: Double = 240
        let fallbackFontSize: Double = 17
        let margin: Double = 6

        var sanitized = self
        sanitized.x = x.isFinite ? x : margin
        sanitized.y = y.isFinite ? y : margin
        sanitized.width = width.isFinite ? width : fallbackWidth
        sanitized.fontSize = fontSize.isFinite ? fontSize : fallbackFontSize

        sanitized.width = min(max(90, sanitized.width), 640)
        sanitized.fontSize = min(max(10, sanitized.fontSize), 48)

        if let areaSize,
           areaSize.width.isFinite,
           areaSize.height.isFinite,
           areaSize.width > 0,
           areaSize.height > 0 {
            sanitized.width = min(sanitized.width, max(90, Double(areaSize.width) - margin * 2))
            let maxX = max(margin, Double(areaSize.width) - sanitized.width - margin)
            let maxY = max(margin, Double(areaSize.height) - 42 - margin)
            sanitized.x = min(max(margin, sanitized.x), maxX)
            sanitized.y = min(max(margin, sanitized.y), maxY)
        } else {
            sanitized.x = max(margin, sanitized.x)
            sanitized.y = max(margin, sanitized.y)
        }

        guard sanitized.x.isFinite,
              sanitized.y.isFinite,
              sanitized.width.isFinite,
              sanitized.fontSize.isFinite else {
            return nil
        }
        return sanitized
    }
}
