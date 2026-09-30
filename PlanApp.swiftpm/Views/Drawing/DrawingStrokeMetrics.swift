import CoreGraphics

/// Gemeinsame Maße für Werkzeugbreiten in der Zeichenfläche und in der
/// Vorschau.
///
/// `PKInkingTool` bekommt genau die Breite, die in den Einstellungen gewählt
/// wurde. Druck und Neigung können die tatsächliche Form eines Pencil-Strichs
/// später noch verändern; dafür darf die Vorschau aber keinen erfundenen
/// Faktor verwenden. Der Punkt zeigt deshalb die exakte Basisbreite, inklusive
/// der Skalierung, mit der die Notiz dargestellt wird.
public enum DrawingStrokeMetrics {

    /// Der Wert wird direkt an PencilKit übergeben. Der Name bleibt als
    /// gemeinsame API für Toolbar und Tests erhalten.
    public static let penRenderFactor: CGFloat = 1.0
    public static let markerRenderFactor: CGFloat = 1.0
    public static let eraserRenderFactor: CGFloat = 1.0

    /// Faktor für das aktuell gewählte Werkzeug.
    public static func renderFactor(for selection: DrawingToolSelection) -> CGFloat {
        switch selection {
        case .pen, .text:
            return penRenderFactor
        case .marker:
            return markerRenderFactor
        case .eraser:
            return eraserRenderFactor
        }
    }

    /// Strichstärke in Punkten, wie sie in der Zeichenfläche wirklich erscheint.
    public static func renderedWidth(
        for selection: DrawingToolSelection,
        width: CGFloat
    ) -> CGFloat {
        guard width.isFinite, width > 0 else { return 0.1 }
        return width * renderFactor(for: selection)
    }

    /// Strichstärke auf dem Bildschirm inkl. der Skalierung der Notizfläche.
    /// `canvasScale` ist der Faktor, mit dem die Zeichenfläche dargestellt wird.
    public static func onScreenWidth(
        for selection: DrawingToolSelection,
        width: CGFloat,
        canvasScale: CGFloat
    ) -> CGFloat {
        let scale = (canvasScale.isFinite && canvasScale > 0) ? canvasScale : 1
        return max(0.1, renderedWidth(for: selection, width: width) * scale)
    }
}
