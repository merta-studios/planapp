import Foundation
import CoreGraphics

/// Ein frei bewegliches Textfeld auf der Zeichenfläche einer Stunden-Notiz.
/// Koordinaten sind in Punkt-Koordinaten der Zeichenfläche (unskaliert).
public struct NoteTextBox: Identifiable, Codable, Equatable {
    /// Standard-Textfarbe: Die Zeichenfläche ist immer weiß, deshalb ein
    /// festes Dunkelgrau/Schwarz statt einer dynamischen Systemfarbe.
    public static let defaultColorHex = "#1E1E1E"
    /// Standard-Schriftgröße und Grenzen für manuell erstellte Textfelder.
    public static let defaultFontSize: Double = 17
    public static let minimumFontSize: Double = 10
    public static let maximumFontSize: Double = 48

    public var id: UUID
    public var text: String
    public var x: Double        // linke obere Ecke, X
    public var y: Double        // linke obere Ecke, Y
    public var width: Double    // Breite des Feldes (Text bricht automatisch um)
    public var fontSize: Double
    /// Textfarbe als Hex-String. Wird über die Farb-Slots der Werkzeugleiste
    /// gesetzt, solange ein Textfeld ausgewählt ist.
    public var colorHex: String

    public init(
        id: UUID = UUID(),
        text: String = "",
        x: Double,
        y: Double,
        width: Double = 240,
        fontSize: Double = NoteTextBox.defaultFontSize,
        colorHex: String = NoteTextBox.defaultColorHex
    ) {
        self.id = id
        self.text = text
        self.x = x
        self.y = y
        self.width = width
        self.fontSize = fontSize
        self.colorHex = colorHex
    }

    private enum CodingKeys: String, CodingKey {
        case id, text, x, y, width, fontSize, colorHex
    }

    /// Bereits gespeicherte Notizen kennen `colorHex` noch nicht. Ohne diesen
    /// eigenen Decoder würde das Laden solcher Notizen fehlschlagen und die
    /// Textfelder wären verloren.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        text = try container.decodeIfPresent(String.self, forKey: .text) ?? ""
        x = try container.decodeIfPresent(Double.self, forKey: .x) ?? 6
        y = try container.decodeIfPresent(Double.self, forKey: .y) ?? 6
        width = try container.decodeIfPresent(Double.self, forKey: .width) ?? 240
        fontSize = try container.decodeIfPresent(Double.self, forKey: .fontSize) ?? NoteTextBox.defaultFontSize
        colorHex = try container.decodeIfPresent(String.self, forKey: .colorHex)
            ?? NoteTextBox.defaultColorHex
    }

    /// Defensive Normalisierung für geladene oder per OCR erzeugte Textfelder.
    /// Ungültige Zahlen (NaN/∞) führen in SwiftUI bei `frame`/`offset` zu
    /// Laufzeit-Abbrüchen; deshalb werden sie konsequent auf sichere Werte
    /// geklemmt.
    public func sanitized(in areaSize: CGSize? = nil) -> NoteTextBox? {
        let fallbackWidth: Double = 240
        let fallbackFontSize = NoteTextBox.defaultFontSize
        let margin: Double = 6

        var sanitized = self
        sanitized.x = x.isFinite ? x : margin
        sanitized.y = y.isFinite ? y : margin
        sanitized.width = width.isFinite ? width : fallbackWidth
        sanitized.fontSize = fontSize.isFinite ? fontSize : fallbackFontSize

        sanitized.width = min(max(90, sanitized.width), 640)
        sanitized.fontSize = min(
            max(NoteTextBox.minimumFontSize, sanitized.fontSize),
            NoteTextBox.maximumFontSize
        )
        if sanitized.colorHex.trimmingCharacters(in: .whitespaces).isEmpty {
            sanitized.colorHex = NoteTextBox.defaultColorHex
        }

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
