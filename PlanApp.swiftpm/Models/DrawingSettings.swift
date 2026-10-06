import Foundation

/// Einstellungen rund um Zeichenfläche und Notizen: Standard-Dicken pro Werkzeug,
/// Größe der Fläche und neuer Textfelder, anpassbare Farb-Slots für Stift und
/// Textmarker sowie die automatische Bereinigung alter Notizen.
public struct DrawingSettings: Codable, Equatable {
    public var penWidth: Double              // Standard-Dicke Stift
    public var markerWidth: Double           // Standard-Dicke Textmarker
    public var eraserWidth: Double           // Standard-Dicke Radierer
    public var defaultCanvasHeight: Double   // Standard-Höhe der Zeichenfläche beim Öffnen
    public var defaultTextFontSize: Double   // Standard-Schriftgröße neuer Textfelder
    /// Schriftart aller Textfelder (Einstellungen → Zeichnen).
    public var textFontStyle: NoteTextFontStyle
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
    /// Dynamische Stiftdicke (Standard **an**): Der PencilKit-Stift reagiert
    /// auf Druck und Geschwindigkeit. Aus: PencilKit-Kugelschreiber
    /// (Monoline), der immer gleich dick schreibt.
    public var dynamicPenWidth: Bool
    /// Stift-Stabilisierung in Prozent (0…100, Standard **0**): Je höher der
    /// Wert, desto stärker werden fertige Striche geglättet – die Handschrift
    /// wird ruhiger, so wie man es aus Notiz-Apps kennt. Bei 0 % bleibt jeder
    /// Strich exakt so, wie er geschrieben wurde.
    public var penStabilization: Double
    /// Standard-Skalierung des Hintergrund-Musters neuer Notizen
    /// (1 = Mitte des Reglers in der Zeichenfläche).
    public var defaultBackgroundScale: Double
    /// Aktion beim Squeeze des Apple Pencil Pro.
    public var squeezeAction: PencilGestureAction
    /// Aktion beim Doppeltipp (Apple Pencil 2 und Pro).
    public var doubleTapAction: PencilGestureAction

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
        defaultTextFontSize: Double = NoteTextBox.defaultFontSize,
        textFontStyle: NoteTextFontStyle = .system,
        autoDeletePastNotes: Bool = false,
        defaultBackgroundStyle: NoteBackgroundStyle = .blank,
        penColorSlots: [String] = DrawingSettings.defaultPenColorSlots,
        markerColorSlots: [String] = DrawingSettings.defaultMarkerColorSlots,
        applePencilOnly: Bool = false,
        autoDeselectEraser: Bool = true,
        dynamicPenWidth: Bool = true,
        penStabilization: Double = PenStabilization.defaultPercent,
        defaultBackgroundScale: Double = 1,
        squeezeAction: PencilGestureAction = .toolbar,
        doubleTapAction: PencilGestureAction = .toggleEraser
    ) {
        self.penWidth = penWidth
        self.markerWidth = markerWidth
        self.eraserWidth = eraserWidth
        self.defaultCanvasHeight = defaultCanvasHeight
        self.defaultTextFontSize = Self.clampedTextFontSize(defaultTextFontSize)
        self.textFontStyle = textFontStyle
        self.autoDeletePastNotes = autoDeletePastNotes
        self.defaultBackgroundStyle = defaultBackgroundStyle
        self.penColorSlots = penColorSlots.isEmpty ? DrawingSettings.defaultPenColorSlots : penColorSlots
        self.markerColorSlots = markerColorSlots.isEmpty ? DrawingSettings.defaultMarkerColorSlots : markerColorSlots
        self.applePencilOnly = applePencilOnly
        self.autoDeselectEraser = autoDeselectEraser
        self.dynamicPenWidth = dynamicPenWidth
        self.penStabilization = PenStabilization.clampedPercent(penStabilization)
        self.defaultBackgroundScale = NoteBackgroundMetrics.clampedScale(defaultBackgroundScale)
        self.squeezeAction = squeezeAction
        self.doubleTapAction = doubleTapAction
    }

    enum CodingKeys: String, CodingKey {
        case penWidth, markerWidth, eraserWidth, defaultCanvasHeight, defaultTextFontSize, textFontStyle, autoDeletePastNotes
        case defaultBackgroundStyle
        case penColorSlots, markerColorSlots
        case applePencilOnly, autoDeselectEraser
        case dynamicPenWidth, penStabilization, defaultBackgroundScale
        case squeezeAction, doubleTapAction
        case defaultPenColorHex, defaultMarkerColorHex, defaultTool
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.penWidth = try container.decodeIfPresent(Double.self, forKey: .penWidth) ?? 3.5
        self.markerWidth = try container.decodeIfPresent(Double.self, forKey: .markerWidth) ?? 16
        self.eraserWidth = try container.decodeIfPresent(Double.self, forKey: .eraserWidth) ?? 24
        self.defaultCanvasHeight = try container.decodeIfPresent(Double.self, forKey: .defaultCanvasHeight) ?? 460
        let decodedTextFontSize = try container.decodeIfPresent(Double.self, forKey: .defaultTextFontSize)
            ?? NoteTextBox.defaultFontSize
        self.defaultTextFontSize = Self.clampedTextFontSize(decodedTextFontSize)
        self.textFontStyle = try container.decodeIfPresent(NoteTextFontStyle.self, forKey: .textFontStyle) ?? .system
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
        self.dynamicPenWidth = try container.decodeIfPresent(Bool.self, forKey: .dynamicPenWidth) ?? true
        // Erst mit dieser Einstellung gespeicherte Stände kennen den Wert noch
        // nicht – alte Speicherstände starten deshalb mit 0 % (unverändert).
        let decodedStabilization = try container.decodeIfPresent(Double.self, forKey: .penStabilization)
            ?? PenStabilization.defaultPercent
        self.penStabilization = PenStabilization.clampedPercent(decodedStabilization)
        let decodedScale = try container.decodeIfPresent(Double.self, forKey: .defaultBackgroundScale) ?? 1
        self.defaultBackgroundScale = NoteBackgroundMetrics.clampedScale(decodedScale)
        self.squeezeAction = try container.decodeIfPresent(PencilGestureAction.self, forKey: .squeezeAction) ?? .toolbar
        self.doubleTapAction = try container.decodeIfPresent(PencilGestureAction.self, forKey: .doubleTapAction) ?? .toggleEraser
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(penWidth, forKey: .penWidth)
        try container.encode(markerWidth, forKey: .markerWidth)
        try container.encode(eraserWidth, forKey: .eraserWidth)
        try container.encode(defaultCanvasHeight, forKey: .defaultCanvasHeight)
        try container.encode(defaultTextFontSize, forKey: .defaultTextFontSize)
        try container.encode(textFontStyle, forKey: .textFontStyle)
        try container.encode(autoDeletePastNotes, forKey: .autoDeletePastNotes)
        try container.encode(defaultBackgroundStyle, forKey: .defaultBackgroundStyle)
        try container.encode(penColorSlots, forKey: .penColorSlots)
        try container.encode(markerColorSlots, forKey: .markerColorSlots)
        try container.encode(applePencilOnly, forKey: .applePencilOnly)
        try container.encode(autoDeselectEraser, forKey: .autoDeselectEraser)
        try container.encode(dynamicPenWidth, forKey: .dynamicPenWidth)
        try container.encode(penStabilization, forKey: .penStabilization)
        try container.encode(defaultBackgroundScale, forKey: .defaultBackgroundScale)
        try container.encode(squeezeAction, forKey: .squeezeAction)
        try container.encode(doubleTapAction, forKey: .doubleTapAction)
    }

    private static func clampedTextFontSize(_ value: Double) -> Double {
        guard value.isFinite else { return NoteTextBox.defaultFontSize }
        return min(
            max(NoteTextBox.minimumFontSize, value),
            NoteTextBox.maximumFontSize
        )
    }

    public static var `default`: DrawingSettings {
        DrawingSettings()
    }
}
