import CoreGraphics

/// Umrechnung zwischen der *eingestellten* Werkzeug-Breite und der Strichstärke,
/// die PencilKit tatsächlich auf dem Display zeichnet.
///
/// Hintergrund: Die `width` eines `PKInkingTool` ist laut Apple ausdrücklich
/// nur ein **Basiswert** („this width represents a base value based on an
/// average pencil user characteristic“, WWDC19 – *Introducing PencilKit*).
/// Die real gerenderte Breite ergibt sich zusätzlich aus Druck, Neigung und
/// Geschwindigkeit des Apple Pencil und liegt beim normalen Schreiben spürbar
/// **unter** dem eingestellten Basiswert.
///
/// Genau deshalb wirkte die frühere 1:1-Vorschau (Kreis-Durchmesser = Basiswert)
/// immer zu groß. Die Faktoren hier bilden die tatsächlich sichtbare Strichstärke
/// ab, sodass Vorschau und gezeichneter Strich übereinstimmen.
public enum DrawingStrokeMetrics {

    /// Stift: kräftig druckabhängig, zeichnet im Mittel deutlich feiner als der Basiswert.
    public static let penRenderFactor: CGFloat = 0.6

    /// Textmarker: flache Spitze, kaum druckabhängig – nahe am Basiswert.
    public static let markerRenderFactor: CGFloat = 0.85

    /// Radierer: der Basiswert entspricht direkt dem Durchmesser des Radierers.
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
