import Foundation
import CoreGraphics
import UIKit

/// Ein frei bewegliches Textfeld auf der Zeichenfläche einer Stunden-Notiz.
/// Koordinaten sind in Punkt-Koordinaten der Zeichenfläche (unskaliert).
public struct NoteTextBox: Identifiable, Codable, Equatable {
    public var id: UUID
    public var text: String
    public var x: Double        // linke obere Ecke, X
    public var y: Double        // linke obere Ecke, Y
    public var width: Double    // Breite des Feldes (Text bricht automatisch um)
    public var fontSize: Double
    /// Textfarbe als Hex-String (z. B. "#1E1E1E"). Wird in der Werkzeugleiste
    /// gewählt, während das Textfeld ausgewählt ist. Ältere Speicherstände
    /// ohne dieses Feld werden beim Dekodieren auf Schwarz zurückgesetzt.
    public var color: String

    /// Standard-Textfarbe: reines Schwarz, exakt wie vor der Einführung der
    /// wählbaren Textfarbe – bestehende Notizen sehen unverändert aus.
    public static let defaultColorHex = "#000000"

    public init(
        id: UUID = UUID(),
        text: String = "",
        x: Double,
        y: Double,
        width: Double = 240,
        fontSize: Double = 17,
        color: String = NoteTextBox.defaultColorHex
    ) {
        self.id = id
        self.text = text
        self.x = x
        self.y = y
        self.width = width
        self.fontSize = fontSize
        self.color = color
    }

    private enum CodingKeys: String, CodingKey {
        case id, text, x, y, width, fontSize, color
    }

    /// Bewusst handgeschriebenes Dekodieren: `color` ist ein später
    /// hinzugekommenes Feld. Mit `decodeIfPresent` bleiben alle alten
    /// Speicherstände (ohne Farbe) ohne Datenverlust lesbar.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.text = try container.decodeIfPresent(String.self, forKey: .text) ?? ""
        self.x = try container.decodeIfPresent(Double.self, forKey: .x) ?? 6
        self.y = try container.decodeIfPresent(Double.self, forKey: .y) ?? 6
        self.width = try container.decodeIfPresent(Double.self, forKey: .width) ?? 240
        self.fontSize = try container.decodeIfPresent(Double.self, forKey: .fontSize) ?? 17
        self.color = try container.decodeIfPresent(String.self, forKey: .color) ?? NoteTextBox.defaultColorHex
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(text, forKey: .text)
        try container.encode(x, forKey: .x)
        try container.encode(y, forKey: .y)
        try container.encode(width, forKey: .width)
        try container.encode(fontSize, forKey: .fontSize)
        try container.encode(color, forKey: .color)
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

        // Farbangabe normalisieren: Der UIColor-Round-Trip garantiert auch bei
        // ungültigen oder alten Hex-Werten einen gültigen, renderbaren Wert.
        sanitized.color = UIColor(hex: sanitized.color).toHex()

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
