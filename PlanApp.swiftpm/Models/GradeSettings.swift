import Foundation

/// Eingabe-System des Moduls „Noten & Punkte“.
///
/// * `grades` – klassische Schulnoten von 1 (sehr gut) bis 6 (ungenügend).
/// * `points` – Punkte von 0 bis zu einer einstellbaren Höchstpunktzahl.
/// * `percent` – Prozent von 0 bis 100.
///
/// Punkte und Prozent lassen sich zusätzlich automatisch in eine Note
/// umrechnen (`convertsToGrade`). Damit ist die Eingabe anders, das Ergebnis
/// aber eine normale Note – inklusive Durchschnitt und Farbskala.
public enum GradeSystem: String, Codable, CaseIterable, Identifiable, Equatable {
    case grades
    case points
    case percent

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .grades: return "Normale Noten"
        case .points: return "Punkte"
        case .percent: return "Prozent"
        }
    }

    public var subtitle: String {
        switch self {
        case .grades:
            return "Eintrag von 1 bis 6 – keine weiteren Einstellungen nötig."
        case .points:
            return "Eintrag von 0 bis zur eingestellten Höchstpunktzahl."
        case .percent:
            return "Eintrag von 0 bis 100 %."
        }
    }

    public var systemImage: String {
        switch self {
        case .grades: return "graduationcap"
        case .points: return "number.circle"
        case .percent: return "percent"
        }
    }

    /// Punkte und Prozent müssen erst in eine Note umgerechnet werden.
    public var supportsGradeConversion: Bool {
        self != .grades
    }
}

/// Sortierung der Fächer-Liste im Modus „Noten & Punkte“.
public enum GradeSubjectSort: String, Codable, CaseIterable, Identifiable, Equatable {
    case alphabet
    case alphabetReversed
    case random
    case bestAverage
    case worstAverage
    case mostEntries
    case fewestEntries
    case lastChanged
    case lastChangedReversed

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .alphabet: return "Alphabet"
        case .alphabetReversed: return "Alphabet umgekehrt"
        case .random: return "Zufällig"
        case .bestAverage: return "Bester Durchschnitt"
        case .worstAverage: return "Schlechtester Durchschnitt"
        case .mostEntries: return "Am meisten Einträge"
        case .fewestEntries: return "Am wenigsten Einträge"
        case .lastChanged: return "Letzte Änderung"
        case .lastChangedReversed: return "Letzte Änderung umgekehrt"
        }
    }

    /// Sortierungen, die sich auf den Durchschnitt beziehen, brauchen
    /// vorhandene Einträge.
    public var needsEntries: Bool {
        switch self {
        case .bestAverage, .worstAverage:
            return true
        default:
            return false
        }
    }
}

/// Sortierung der Einträge innerhalb eines Fachs.
public enum GradeEntrySort: String, Codable, CaseIterable, Identifiable, Equatable {
    case newest
    case best
    case worst
    case oldest

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .newest: return "Zuletzt hinzugefügt"
        case .best: return "Beste"
        case .worst: return "Schlechteste"
        case .oldest: return "Älteste"
        }
    }
}

/// Einstellungen des Moduls „Noten & Punkte“ (Einstellungen → „Noten & Punkte“).
///
/// Das Modul ist standardmäßig **aus**. Ist es aus, gibt es weder die
/// Ansichts-Modi „Noten & Punkte“ noch irgendwelche Eingabemöglichkeiten –
/// und der Abschnitt zeigt keine weiteren Einstellungen.
public struct GradeSettings: Codable, Equatable {
    /// Grenzen der einstellbaren Höchstpunktzahl.
    public static let maximumPointsLimit: Int = 200
    public static let minimumPointsLimit: Int = 1

    /// Hauptschalter des Moduls (Standard: aus).
    public var isEnabled: Bool
    /// Eingabe-System: Noten, Punkte oder Prozent.
    public var system: GradeSystem
    /// Höchstpunktzahl im Punkte-System (1 … 200).
    public var maximumPoints: Int
    /// `true` = die höchste Punktzahl ist die „gute“ 1 im Test,
    /// `false` = die niedrigste Punktzahl ist die gute 1.
    public var higherPointsAreBetter: Bool
    /// Punkte/Prozent automatisch in eine Zensur umrechnen (Standard: aus).
    public var convertsToGrade: Bool
    /// Standard-Sortierung der Fächer-Liste beim Wechsel in den Modus.
    public var defaultSubjectSort: GradeSubjectSort
    /// Standard-Sortierung der Einträge eines Fachs.
    public var defaultEntrySort: GradeEntrySort
    /// Standard-Position des Reglers beim Hinzufügen eines Eintrags
    /// (0 = Minimum, 1 = Maximum). Standard ist die Mitte (0,5).
    public var defaultSliderFraction: Double

    public init(
        isEnabled: Bool = false,
        system: GradeSystem = .grades,
        maximumPoints: Int = 15,
        higherPointsAreBetter: Bool = true,
        convertsToGrade: Bool = false,
        defaultSubjectSort: GradeSubjectSort = .alphabet,
        defaultEntrySort: GradeEntrySort = .newest,
        defaultSliderFraction: Double = 0.5
    ) {
        self.isEnabled = isEnabled
        self.system = system
        self.maximumPoints = GradeSettings.clampedMaximumPoints(maximumPoints)
        self.higherPointsAreBetter = higherPointsAreBetter
        self.convertsToGrade = convertsToGrade
        self.defaultSubjectSort = defaultSubjectSort
        self.defaultEntrySort = defaultEntrySort
        self.defaultSliderFraction = GradeSettings.clampedFraction(defaultSliderFraction)
    }

    private enum CodingKeys: String, CodingKey {
        case isEnabled, system, maximumPoints, higherPointsAreBetter, convertsToGrade
        case defaultSubjectSort, defaultEntrySort, defaultSliderFraction
    }

    /// Alle Werte defensiv lesen: ältere Speicherstände kennen einzelne
    /// Schlüssel noch nicht – ohne Defaults würden sie die Einstellungen
    /// verlieren.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? false
        self.system = try container.decodeIfPresent(GradeSystem.self, forKey: .system) ?? .grades
        let decodedMax = try container.decodeIfPresent(Int.self, forKey: .maximumPoints) ?? 15
        self.maximumPoints = GradeSettings.clampedMaximumPoints(decodedMax)
        self.higherPointsAreBetter = try container.decodeIfPresent(Bool.self, forKey: .higherPointsAreBetter) ?? true
        self.convertsToGrade = try container.decodeIfPresent(Bool.self, forKey: .convertsToGrade) ?? false
        self.defaultSubjectSort = try container.decodeIfPresent(GradeSubjectSort.self, forKey: .defaultSubjectSort) ?? .alphabet
        self.defaultEntrySort = try container.decodeIfPresent(GradeEntrySort.self, forKey: .defaultEntrySort) ?? .newest
        let decodedFraction = try container.decodeIfPresent(Double.self, forKey: .defaultSliderFraction) ?? 0.5
        self.defaultSliderFraction = GradeSettings.clampedFraction(decodedFraction)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(system, forKey: .system)
        try container.encode(maximumPoints, forKey: .maximumPoints)
        try container.encode(higherPointsAreBetter, forKey: .higherPointsAreBetter)
        try container.encode(convertsToGrade, forKey: .convertsToGrade)
        try container.encode(defaultSubjectSort, forKey: .defaultSubjectSort)
        try container.encode(defaultEntrySort, forKey: .defaultEntrySort)
        try container.encode(defaultSliderFraction, forKey: .defaultSliderFraction)
    }

    // MARK: - Hilfsrechnungen

    public static func clampedMaximumPoints(_ value: Int) -> Int {
        min(maximumPointsLimit, max(minimumPointsLimit, value))
    }

    public static func clampedFraction(_ value: Double) -> Double {
        guard value.isFinite else { return 0.5 }
        return min(1, max(0, value))
    }

    /// Ob ein Eintrag tatsächlich als Note angezeigt wird (Noten-System oder
    /// Umrechnung aktiv).
    public var showsGradesForEntries: Bool {
        system == .grades || convertsToGrade
    }

    public static var `default`: GradeSettings { GradeSettings() }
}
