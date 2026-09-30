import Foundation

/// Das Werkzeug, das beim Öffnen der Zeichenfläche standardmäßig ausgerüstet ist
public enum DefaultDrawingTool: String, Codable, CaseIterable, Identifiable {
    case pen
    case marker
    case eraser

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .pen: return "Stift"
        case .marker: return "Textmarker"
        case .eraser: return "Radierer"
        }
    }

    public var systemImage: String {
        switch self {
        case .pen: return "pencil.tip"
        case .marker: return "highlighter"
        case .eraser: return "eraser"
        }
    }
}

/// Einstellungen rund um die Zeichenfläche: Standard-Dicken pro Werkzeug,
/// Standard-Größe der Fläche, Standard-Werkzeug samt Farbe und die
/// automatische Bereinigung alter Notizen.
public struct DrawingSettings: Codable, Equatable {
    public var penWidth: Double              // Standard-Dicke Stift
    public var markerWidth: Double           // Standard-Dicke Textmarker
    public var eraserWidth: Double           // Standard-Dicke Radierer
    public var defaultCanvasHeight: Double   // Standard-Höhe der Zeichenfläche beim Öffnen
    public var autoDeletePastNotes: Bool     // Notizen vergangener Stunden automatisch löschen
    public var defaultTool: DefaultDrawingTool
    public var defaultPenColorHex: String    // Standard-Stiftfarbe (aus der Stift-Palette)
    public var defaultMarkerColorHex: String // Standard-Markerfarbe (aus der Marker-Palette)

    public init(
        penWidth: Double = 3.5,
        markerWidth: Double = 16,
        eraserWidth: Double = 24,
        defaultCanvasHeight: Double = 460,
        autoDeletePastNotes: Bool = false,
        defaultTool: DefaultDrawingTool = .pen,
        defaultPenColorHex: String = "#000000",
        defaultMarkerColorHex: String = "#FFE633"
    ) {
        self.penWidth = penWidth
        self.markerWidth = markerWidth
        self.eraserWidth = eraserWidth
        self.defaultCanvasHeight = defaultCanvasHeight
        self.autoDeletePastNotes = autoDeletePastNotes
        self.defaultTool = defaultTool
        self.defaultPenColorHex = defaultPenColorHex
        self.defaultMarkerColorHex = defaultMarkerColorHex
    }

    public static var `default`: DrawingSettings {
        DrawingSettings()
    }
}
