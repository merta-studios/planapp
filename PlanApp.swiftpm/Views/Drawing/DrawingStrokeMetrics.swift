import CoreGraphics

/// Gemeinsame Maße für Werkzeugbreiten in der Zeichenfläche und in der
/// Vorschau.
///
/// `PKInkingTool` bekommt genau die Breite, die in den Einstellungen gewählt
/// wurde. Druck und Neigung können die tatsächliche Form eines Pencil-Strichs
/// später noch verändern; dafür darf die Vorschau aber keinen erfundenen
/// Faktor verwenden – **außer** dem einen, der gemessen wurde:
///
/// Der Vergleich auf dem iPad hat gezeigt, dass ein PencilKit-Strich rund
/// **doppelt so dick** ausfällt wie alles, was die App aus derselben
/// Werkzeugbreite selbst berechnet. Die vom System gerade gemachte Linie (und
/// die Vorschau-Punkte) waren deshalb exakt **50 % dünner** als der echte
/// Stift. Genau dieses Verhältnis steht in `InteractionPolicies` und wird
/// hier überall benutzt, wo eine Breite nicht direkt von PencilKit gezeichnet
/// wird – Vorschau-Punkte ebenso wie die nachgebauten (geraden) Linien.
public enum DrawingStrokeMetrics {

    /// Gemessenes Verhältnis (siehe `InteractionPolicies.strokeWidthMatchFactor`).
    public static let inkWidthMatchFactor: CGFloat = CGFloat(InteractionPolicies.strokeWidthMatchFactor)

    /// Der Wert wird direkt an PencilKit übergeben. Diese Namen bleiben als
    /// gemeinsame API für Toolbar und Tests erhalten.
    public static let penRenderFactor: CGFloat = inkWidthMatchFactor
    /// Der Textmarker hat eine eigene Umrechnung von Punktdicke zu
    /// gezeichneter Breite (`syntheticPointSize`) – dort stimmt die Dicke
    /// schon, hier wird nichts zusätzlich gestreckt.
    public static let markerRenderFactor: CGFloat = 1.0
    /// Der Radierer radiert mit der eingestellten Bitmap-Breite; hier wird
    /// nichts umgerechnet.
    public static let eraserRenderFactor: CGFloat = 1.0

    /// Faktor für das aktuell gewählte Werkzeug.
    public static func renderFactor(for selection: DrawingToolSelection) -> CGFloat {
        switch selection {
        case .pen, .text, .lasso:
            return penRenderFactor
        case .marker:
            return markerRenderFactor
        case .eraser:
            return eraserRenderFactor
        }
    }

    /// Zielbreite für alles, was die App selbst zeichnet (gerade Linien,
    /// Vorschau-Punkte). PencilKit selbst bekommt weiterhin die eingestellte
    /// Werkzeugbreite.
    public static func targetWidth(
        for selection: DrawingToolSelection,
        width: CGFloat
    ) -> CGFloat {
        switch selection {
        case .pen, .text, .lasso:
            return CGFloat(InteractionPolicies.matchedStrokeWidth(Double(width)))
        case .marker:
            return CGFloat(InteractionPolicies.matchedStrokeWidth(Double(width), isMarker: true))
        case .eraser:
            return CGFloat(InteractionPolicies.matchedStrokeWidth(Double(width), isEraser: true))
        }
    }

    /// Zielbreite für einen selbst gebauten Strich, wenn nur die Tinte bekannt
    /// ist (z. B. in der Gerade-Linie-Sitzung).
    public static func targetInkWidth(
        width: CGFloat,
        isMarker: Bool = false
    ) -> CGFloat {
        CGFloat(InteractionPolicies.matchedStrokeWidth(
            Double(width),
            isMarker: isMarker
        ))
    }

    /// Strichstärke in Punkten, wie sie in der Zeichenfläche wirklich erscheint.
    public static func renderedWidth(
        for selection: DrawingToolSelection,
        width: CGFloat
    ) -> CGFloat {
        targetWidth(for: selection, width: width)
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
