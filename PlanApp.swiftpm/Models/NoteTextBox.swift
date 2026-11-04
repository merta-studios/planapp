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
    /// Grenzen der Schriftgröße einer **Handy-Notiz** (schlichter Fließtext
    /// auf dem iPhone). Dort gibt es nur einen einzigen Text – seine Größe
    /// lässt sich in der Leiste bzw. in den Einstellungen ändern.
    public static let minimumPhoneFontSize: Double = 10
    public static let maximumPhoneFontSize: Double = 40

    /// Klemmt eine Handy-Schriftgröße in den erlaubten Bereich.
    public static func clampedPhoneFontSize(_ value: Double) -> Double {
        guard value.isFinite else { return defaultFontSize }
        return min(maximumPhoneFontSize, max(minimumPhoneFontSize, value))
    }

    public var id: UUID
    public var text: String
    public var x: Double        // linke obere Ecke, X
    public var y: Double        // linke obere Ecke, Y
    public var width: Double    // Breite des Feldes (Text bricht automatisch um)
    public var fontSize: Double
    /// Textfarbe als Hex-String. Wird über die Farb-Slots der Werkzeugleiste
    /// gesetzt, solange ein Textfeld ausgewählt ist.
    public var colorHex: String
    /// Ob die Breite des Feldes **automatisch** mit dem Tippen wächst.
    ///
    /// Neue Textfelder starten mit `true`: Der Text läuft beim Tippen nach
    /// rechts, bis er den Rand der Zeichenfläche erreicht – erst dann bricht
    /// er um. Sobald man die Breite selbst mit den Seiten-Griffen ändert,
    /// wird daraus `false` und das Feld bleibt genau so breit, wie man es
    /// eingestellt hat.
    public var autoGrowWidth: Bool

    public init(
        id: UUID = UUID(),
        text: String = "",
        x: Double,
        y: Double,
        width: Double = 240,
        fontSize: Double = NoteTextBox.defaultFontSize,
        colorHex: String = NoteTextBox.defaultColorHex,
        autoGrowWidth: Bool = true
    ) {
        self.id = id
        self.text = text
        self.x = x
        self.y = y
        self.width = width
        self.fontSize = fontSize
        self.colorHex = colorHex
        self.autoGrowWidth = autoGrowWidth
    }

    private enum CodingKeys: String, CodingKey {
        case id, text, x, y, width, fontSize, colorHex, autoGrowWidth
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
        // Ältere Textfelder kannten das automatische Mitwachsen nicht – sie
        // bleiben bewusst bei ihrer festen Breite.
        autoGrowWidth = try container.decodeIfPresent(Bool.self, forKey: .autoGrowWidth) ?? false
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

    // MARK: - Textmaß (Text-Werkzeug)

    /// Innenabstand eines Textfelds links und rechts (identisch zum Editor).
    public static let textHorizontalInset: Double = 16

    /// Mittlere Zeichenbreite, gemessen an der Systemschrift.
    ///
    /// Für „wächst der Text über den Rand?“ ist keine exakte Typografie nötig –
    /// eine gute Schätzung reicht und bleibt (anders als `UIFont`) frei von
    /// UIKit, damit dieselben Regeln in den Regressions-Tests laufen.
    public static let averageCharacterWidthRatio: Double = 0.52

    /// Breite eines Textes in einer Zeile – ohne Umbruch.
    public static func singleLineTextWidth(
        _ text: String,
        fontSize: Double
    ) -> Double {
        let line = text.components(separatedBy: .newlines).max { lhs, rhs in
            lhs.count < rhs.count
        } ?? text
        let size = fontSize.isFinite ? max(1, fontSize) : defaultFontSize
        let width = Double(line.count) * size * averageCharacterWidthRatio
        guard width.isFinite, width > 0 else { return 0 }
        return ceil(width) + textHorizontalInset
    }

    /// Breite, die ein Feld mindestens braucht, sobald der Text nicht mehr in
    /// die aktuelle Breite passt (er würde sonst umbrechen und eine Zeile
    /// verlieren). Ist der Text schmaler als das Feld, bleibt `nil`.
    public static func minimumSingleLineWidth(
        _ text: String,
        fontSize: Double
    ) -> Double? {
        guard !text.isEmpty else { return nil }
        return max(90, singleLineTextWidth(text, fontSize: fontSize))
    }

    /// Neue Breite eines automatisch mitwachsenden Feldes.
    ///
    /// Neue Textfelder wachsen mit dem Tippen nach rechts, bis sie den Rand der
    /// Zeichenfläche erreichen; erst dann bricht der Text um. Wer die Breite
    /// selbst mit den Seiten-Griffen ändert, schaltet das ab.
    ///
    /// - Returns: `nil`, wenn sich nichts ändern muss. Sonst die neue Breite –
    ///   sie wächst höchstens bis `maxWidth`.
    public static func autoGrownWidth(
        text: String,
        currentWidth: Double,
        maxWidth: Double,
        fontSize: Double,
        keepAtLeast: Double = 90
    ) -> Double? {
        guard currentWidth.isFinite, maxWidth.isFinite, maxWidth > keepAtLeast else { return nil }
        guard !text.isEmpty else { return nil }
        let needed = max(keepAtLeast, singleLineTextWidth(text, fontSize: fontSize))
        let target = min(maxWidth, needed)
        guard target > currentWidth + 0.5 else { return nil }
        return target
    }

    /// Ob der Text an der aktuellen Feldbreite umbrechen würde.
    public static func wraps(
        _ text: String,
        width: Double,
        fontSize: Double
    ) -> Bool {
        guard !text.isEmpty, width.isFinite, width > 0 else { return false }
        return singleLineTextWidth(text, fontSize: fontSize) > width
    }
}
