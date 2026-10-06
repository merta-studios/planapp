import CoreGraphics
import Foundation

/// Gemeinsame Maße für die Hintergrund-Raster der Zeichenfläche
/// (gepunktet, liniert, kariert).
///
/// Sowohl die live dargestellte Zeichenfläche (`DrawingCanvasBackgroundView`)
/// als auch die gerenderte Notiz-Vorschau (`PencilKitCanvasRepresentable`)
/// greifen auf genau diese Werte zu. Dadurch sehen Bearbeitungsansicht und
/// Vorschau identisch aus, und eine Änderung der Raster-Größe muss nur an
/// einer einzigen Stelle gepflegt werden.
///
/// Die Raster sind bewusst großzügig dimensioniert (rund doppelt so groß wie
/// die ursprünglichen Werte): weniger, dafür deutlich größere Zeilen, Kästchen
/// und Punktabstände lassen sich beim Schreiben mit dem Apple Pencil viel
/// angenehmer nutzen.
///
/// Zusätzlich gibt es einen **Skalierungsfaktor** pro Notiz (Regler im Menü
/// „Mehr Optionen“ der Zeichenfläche). `1` entspricht der bisherigen Größe und
/// liegt genau in der Mitte des Reglers; nach links wird das Muster bis auf die
/// Hälfte kleiner, nach rechts bis auf das Doppelte größer.
public enum NoteBackgroundMetrics {

    /// Kleinster/größter erlaubter Skalierungsfaktor.
    public static let minimumScale: Double = 0.5
    public static let maximumScale: Double = 2.0
    /// Standard (Mitte des Reglers).
    public static let defaultScale: Double = 1.0

    /// Begrenzt einen gespeicherten/eingegebenen Faktor auf den gültigen Bereich.
    public static func clampedScale(_ value: Double) -> Double {
        guard value.isFinite else { return defaultScale }
        return min(maximumScale, max(minimumScale, value))
    }

    // MARK: Regler ↔ Faktor

    /// Der Regler läuft linear von -1 bis +1; die Mitte (0) ist Faktor 1.
    /// Die Umrechnung ist logarithmisch, damit „halb so groß“ und „doppelt
    /// so groß“ gleich weit von der Mitte entfernt liegen.
    public static func sliderValue(forScale scale: Double) -> Double {
        let clamped = clampedScale(scale)
        return log2(clamped)
    }

    public static func scale(forSliderValue value: Double) -> Double {
        guard value.isFinite else { return defaultScale }
        let clampedValue = min(1, max(-1, value))
        return clampedScale(pow(2, clampedValue))
    }

    // MARK: Maße

    /// Abstand zwischen zwei Linien, Kästchen-Kanten bzw. Punkten in Punkten
    /// (Grundgröße ohne Skalierung).
    public static func baseSpacing(for style: NoteBackgroundStyle) -> CGFloat {
        switch style {
        case .blank:
            return 0
        case .dotted:
            return 44      // vorher 22
        case .lined:
            return 56      // vorher 28
        case .grid:
            return 56      // vorher 28
        }
    }

    /// Abstand zwischen zwei Linien, Kästchen-Kanten bzw. Punkten in Punkten.
    public static func spacing(for style: NoteBackgroundStyle, scale: Double = defaultScale) -> CGFloat {
        let base = baseSpacing(for: style)
        guard base > 0 else { return 0 }
        return base * CGFloat(clampedScale(scale))
    }

    /// Radius eines einzelnen Punktes im gepunkteten Raster (Grundgröße).
    public static let dotRadius: CGFloat = 2.2   // vorher 1.2

    /// Punktradius inkl. Skalierung – Punkte wachsen nur gedämpft mit, damit
    /// ein sehr großes Raster nicht aus dicken Klecksen besteht.
    public static func dotRadius(scale: Double) -> CGFloat {
        let factor = CGFloat(clampedScale(scale))
        return dotRadius * (0.6 + 0.4 * factor)
    }

    /// Strichstärke der Linien/Kästchen.
    public static let lineWidth: CGFloat = 1.1

    /// Deckkraft des Rasters – dezent genug, damit Stiftfarben klar lesbar bleiben.
    public static func opacity(for style: NoteBackgroundStyle) -> CGFloat {
        switch style {
        case .blank:
            return 0
        case .dotted:
            return 0.32
        case .lined:
            return 0.26
        case .grid:
            return 0.22
        }
    }
}
