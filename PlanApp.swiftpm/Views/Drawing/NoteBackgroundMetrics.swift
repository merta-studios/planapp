import CoreGraphics

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
public enum NoteBackgroundMetrics {

    /// Abstand zwischen zwei Linien, Kästchen-Kanten bzw. Punkten in Punkten.
    public static func spacing(for style: NoteBackgroundStyle) -> CGFloat {
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

    /// Radius eines einzelnen Punktes im gepunkteten Raster.
    public static let dotRadius: CGFloat = 2.2   // vorher 1.2

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
