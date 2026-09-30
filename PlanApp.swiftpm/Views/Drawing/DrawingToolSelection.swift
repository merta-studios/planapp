import UIKit

/// The drawing tool currently selected in the custom PencilKit toolbar.
///
/// This is deliberately kept separate from `PKTool`: the toolbar needs to
/// retain the selected color and width while the canvas wrapper translates it
/// into a PencilKit tool. `.text` switches the canvas into the text-field
/// mode in which tapping creates movable text boxes instead of drawing.
public enum DrawingToolSelection: Equatable {
    case pen(color: UIColor)
    case marker(color: UIColor)
    case eraser
    case text
}

/// Gemeinsame Farb-Paletten für Stift und Textmarker. Sie werden sowohl von
/// der Zeichen-Werkzeugleiste als auch von den Einstellungen (Standard-Farbe)
/// verwendet, damit beide immer exakt dieselben Farben anbieten.
public enum DrawingPalette {
    public struct PaletteColor {
        public let name: String
        public let hex: String
        public let uiColor: UIColor

        public init(name: String, hex: String, uiColor: UIColor) {
            self.name = name
            self.hex = hex
            self.uiColor = uiColor
        }
    }

    public static let penColors: [PaletteColor] = [
        PaletteColor(name: "Schwarz", hex: "#000000", uiColor: .black),
        PaletteColor(name: "Rot", hex: "#E12626", uiColor: UIColor(red: 0.88, green: 0.15, blue: 0.15, alpha: 1)),
        PaletteColor(name: "Blau", hex: "#1A73E6", uiColor: UIColor(red: 0.10, green: 0.45, blue: 0.90, alpha: 1)),
        PaletteColor(name: "Grün", hex: "#1FA640", uiColor: UIColor(red: 0.12, green: 0.65, blue: 0.25, alpha: 1))
    ]

    /// Textmarker-Farben. Statt des früheren bräunlichen Orange-Tons gibt es
    /// hier bewusst ein kräftiges Rot.
    public static let markerColors: [PaletteColor] = [
        PaletteColor(name: "Gelb", hex: "#FFE633", uiColor: UIColor(red: 1, green: 0.90, blue: 0.20, alpha: 0.60)),
        PaletteColor(name: "Rot", hex: "#F23333", uiColor: UIColor(red: 0.95, green: 0.20, blue: 0.20, alpha: 0.60)),
        PaletteColor(name: "Grün", hex: "#40D959", uiColor: UIColor(red: 0.25, green: 0.85, blue: 0.35, alpha: 0.60)),
        PaletteColor(name: "Blau", hex: "#33A6FF", uiColor: UIColor(red: 0.20, green: 0.65, blue: 1, alpha: 0.60)),
        PaletteColor(name: "Lila", hex: "#BF59F2", uiColor: UIColor(red: 0.75, green: 0.35, blue: 0.95, alpha: 0.60))
    ]

    public static func penColor(forHex hex: String) -> PaletteColor {
        penColors.first { $0.hex.caseInsensitiveCompare(hex) == .orderedSame } ?? penColors[0]
    }

    public static func markerColor(forHex hex: String) -> PaletteColor {
        markerColors.first { $0.hex.caseInsensitiveCompare(hex) == .orderedSame } ?? markerColors[0]
    }
}
