import Foundation

/// Einstellungen rund um die Zeichenfläche: Standard-Dicken pro Werkzeug,
/// Standard-Größe der Fläche, anpassbare Farb-Slots für Stift und Textmarker
/// sowie die automatische Bereinigung alter Notizen.
public struct DrawingSettings: Codable, Equatable {
    public var penWidth: Double              // Standard-Dicke Stift
    public var markerWidth: Double           // Standard-Dicke Textmarker
    public var eraserWidth: Double           // Standard-Dicke Radierer
    public var defaultCanvasHeight: Double   // Standard-Höhe der Zeichenfläche beim Öffnen
    public var autoDeletePastNotes: Bool     // Notizen vergangener Stunden automatisch löschen
    public var defaultBackgroundStyle: NoteBackgroundStyle // Standard-Hintergrund neuer Notizen
    public var penColorSlots: [String]       // Farb-Slots für den Stift in der Werkzeugleiste
    public var markerColorSlots: [String]    // Farb-Slots für den Textmarker in der Werkzeugleiste
    /// Nur mit dem Apple Pencil zeichnen. Standardmäßig **aus**: Dann zeichnet
    /// auch der Finger (normaler Input). Sobald die App irgendwo einen echten
    /// Apple-Pencil-Input bemerkt, wird die Einstellung automatisch aktiviert.
    public var applePencilOnly: Bool
    /// Radierer nach dem Radieren automatisch abwählen: Beim Loslassen wechselt
    /// das Werkzeug zurück zum zuletzt benutzten Werkzeug (Fallback: Stift).
    /// Standardmäßig **an**.
    public var autoDeselectEraser: Bool

    public static let defaultPenColorSlots: [String] = [
        "#1E1E1E", // Schwarz
        "#FF4D4D", // Hellrot
        "#4CA6FF", // Hellblau
        "#4CD948"  // Hellgrün
    ]

    public static let defaultMarkerColorSlots: [String] = [
        "#FFE633", // Gelb
        "#FF4D4D", // Hellrot
        "#4CD948", // Hellgrün
        "#4CA6FF", // Hellblau
        "#B388FF"  // Flieder
    ]

    public init(
        penWidth: Double = 3.5,
        markerWidth: Double = 16,
        eraserWidth: Double = 24,
        defaultCanvasHeight: Double = 460,
        autoDeletePastNotes: Bool = false,
        defaultBackgroundStyle: NoteBackgroundStyle = .blank,
        penColorSlots: [String] = DrawingSettings.defaultPenColorSlots,
        markerColorSlots: [String] = DrawingSettings.defaultMarkerColorSlots,
        applePencilOnly: Bool = false,
        autoDeselectEraser: Bool = true
    ) {
        self.penWidth = penWidth
        self.markerWidth = markerWidth
        self.eraserWidth = eraserWidth
        self.defaultCanvasHeight = defaultCanvasHeight
        self.autoDeletePastNotes = autoDeletePastNotes
        self.defaultBackgroundStyle = defaultBackgroundStyle
        self.penColorSlots = penColorSlots.isEmpty ? DrawingSettings.defaultPenColorSlots : penColorSlots
        self.markerColorSlots = markerColorSlots.isEmpty ? DrawingSettings.defaultMarkerColorSlots : markerColorSlots
        self.applePencilOnly = applePencilOnly
        self.autoDeselectEraser = autoDeselectEraser
    }

    enum CodingKeys: String, CodingKey {
        case penWidth, markerWidth, eraserWidth, defaultCanvasHeight, autoDeletePastNotes
        case defaultBackgroundStyle
        case penColorSlots, markerColorSlots
        case applePencilOnly, autoDeselectEraser
        case defaultPenColorHex, defaultMarkerColorHex, defaultTool
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.penWidth = try container.decodeIfPresent(Double.self, forKey: .penWidth) ?? 3.5
        self.markerWidth = try container.decodeIfPresent(Double.self, forKey: .markerWidth) ?? 16
        self.eraserWidth = try container.decodeIfPresent(Double.self, forKey: .eraserWidth) ?? 24
        self.defaultCanvasHeight = try container.decodeIfPresent(Double.self, forKey: .defaultCanvasHeight) ?? 460
        self.autoDeletePastNotes = try container.decodeIfPresent(Bool.self, forKey: .autoDeletePastNotes) ?? false
        self.defaultBackgroundStyle = try container.decodeIfPresent(NoteBackgroundStyle.self, forKey: .defaultBackgroundStyle) ?? .blank

        if let decodedPenSlots = try container.decodeIfPresent([String].self, forKey: .penColorSlots), !decodedPenSlots.isEmpty {
            self.penColorSlots = decodedPenSlots
        } else if let legacyHex = try container.decodeIfPresent(String.self, forKey: .defaultPenColorHex) {
            var slots = DrawingSettings.defaultPenColorSlots
            slots[0] = legacyHex
            self.penColorSlots = slots
        } else {
            self.penColorSlots = DrawingSettings.defaultPenColorSlots
        }

        if let decodedMarkerSlots = try container.decodeIfPresent([String].self, forKey: .markerColorSlots), !decodedMarkerSlots.isEmpty {
            self.markerColorSlots = decodedMarkerSlots
        } else if let legacyHex = try container.decodeIfPresent(String.self, forKey: .defaultMarkerColorHex) {
            var slots = DrawingSettings.defaultMarkerColorSlots
            slots[0] = legacyHex
            self.markerColorSlots = slots
        } else {
            self.markerColorSlots = DrawingSettings.defaultMarkerColorSlots
        }

        // Beide Schalter sind neuer als die ersten gespeicherten Einstellungen.
        // Ohne die Defaults würden alte Speicherstände die Zeichenfläche
        // (fälschlich) auf „nur Apple Pencil“ stellen.
        self.applePencilOnly = try container.decodeIfPresent(Bool.self, forKey: .applePencilOnly) ?? false
        self.autoDeselectEraser = try container.decodeIfPresent(Bool.self, forKey: .autoDeselectEraser) ?? true
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(penWidth, forKey: .penWidth)
        try container.encode(markerWidth, forKey: .markerWidth)
        try container.encode(eraserWidth, forKey: .eraserWidth)
        try container.encode(defaultCanvasHeight, forKey: .defaultCanvasHeight)
        try container.encode(autoDeletePastNotes, forKey: .autoDeletePastNotes)
        try container.encode(defaultBackgroundStyle, forKey: .defaultBackgroundStyle)
        try container.encode(penColorSlots, forKey: .penColorSlots)
        try container.encode(markerColorSlots, forKey: .markerColorSlots)
        try container.encode(applePencilOnly, forKey: .applePencilOnly)
        try container.encode(autoDeselectEraser, forKey: .autoDeselectEraser)
    }

    public static var `default`: DrawingSettings {
        DrawingSettings()
    }
}
