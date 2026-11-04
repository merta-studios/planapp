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
    /// „Noten & Punkte“: Alle eigenen Fächer aus „Fächer & Farben“ mit ihrem
    /// Durchschnitt in Kreisen. Nur verfügbar, wenn das Modul in den
    /// Einstellungen aktiviert ist – dann erscheint die Option zwischen
    /// „Nur Notizen“ und dem Filter.
    case gradesAndPoints

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .standard: return "Standard"
        case .notesHighlighted: return "Notizen hervorgehoben"
        case .notesOnly: return "Nur Notizen"
        case .gradesAndPoints: return "Noten & Punkte"
        }
    }

    public var systemImage: String {
        switch self {
        case .standard: return "rectangle.grid.3x2"
        case .notesHighlighted: return "highlighter"
        case .notesOnly: return "list.bullet.rectangle"
        case .gradesAndPoints: return "chart.bar.doc.horizontal"
        }
    }

    /// Fallback beim Laden, falls kein (oder ein ungültiger) Wert gespeichert ist.
    public static let fallback: TimetableViewMode = .standard

    /// Anzeigename und Icon in der Modus-Auswahl. „Noten & Punkte“ erscheint
    /// nur, wenn das Modul in den Einstellungen aktiviert ist.
    public static func selectableModes(gradesModuleEnabled: Bool) -> [TimetableViewMode] {
        allCases.filter { mode in
            mode != .gradesAndPoints || gradesModuleEnabled
        }
    }
}
