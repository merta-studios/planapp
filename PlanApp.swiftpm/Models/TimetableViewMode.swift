import Foundation

/// Der komplette Ansichts-Modus des Stundenplans.
/// Wird persistent gespeichert – beim App-Start gilt immer der zuletzt
/// verwendete Modus (Fallback: Standard).
public enum TimetableViewMode: String, Codable, CaseIterable, Identifiable {
    /// Die normale Wochenansicht, so wie immer.
    case standard
    /// Wochenansicht, bei der Blöcke OHNE Notiz stark aufgehellt werden,
    /// damit die Stunden mit Notizen sofort ins Auge springen.
    case notesHighlighted
    /// Reine Notiz-Übersicht: chronologisches Raster aller Stunden, die eine
    /// Notiz enthalten (Hausaufgaben, Tests, ...). Auf dem iPad im Querformat
    /// zweispaltig, sonst einspaltig.
    case notesOnly

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .standard: return "Standard"
        case .notesHighlighted: return "Notizen hervorgehoben"
        case .notesOnly: return "Nur Notizen"
        }
    }

    public var systemImage: String {
        switch self {
        case .standard: return "rectangle.grid.3x2"
        case .notesHighlighted: return "highlighter"
        case .notesOnly: return "list.bullet.rectangle"
        }
    }

    /// Fallback beim Laden, falls kein (oder ein ungültiger) Wert gespeichert ist.
    public static let fallback: TimetableViewMode = .standard
}
