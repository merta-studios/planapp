import Foundation

/// Ein einzelner Eintrag im Modul „Noten & Punkte“ (eine Note, eine
/// Punktzahl oder ein Prozentwert) – immer mit Datum und optionaler
/// Anmerkung (z. B. „Deutsch Test“).
///
/// Der Wert wird **in seiner eigenen Einheit** gespeichert. Wer die
/// Einstellungen später von Punkten auf Noten umstellt, verliert dadurch
/// nicht die Bedeutung alter Einträge: Jeder Eintrag kennt sein eigenes
/// System samt Höchstpunktzahl und Richtung.
public struct GradeEntry: Identifiable, Codable, Equatable {
    public var id: UUID
    /// Eingabewert in der Einheit `unit` (Note 1–6, Punkte oder Prozent).
    public var value: Double
    /// Einheit, in der der Wert eingegeben wurde.
    public var unit: GradeSystem
    /// Höchstpunktzahl zum Zeitpunkt der Eingabe (nur bei `points` relevant).
    public var maximumPoints: Int
    /// Ob die höhere Punktzahl die bessere war (nur bei `points` relevant).
    public var higherPointsAreBetter: Bool
    /// Freie Anmerkung, z. B. „Deutsch Test“.
    public var note: String
    /// Datum des Eintrags (wird oben im Kästchen angezeigt).
    public var date: Date
    /// Zeitpunkt der letzten Änderung (für die Sortierung „Letzte Änderung“).
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        value: Double,
        unit: GradeSystem,
        maximumPoints: Int = 15,
        higherPointsAreBetter: Bool = true,
        note: String = "",
        date: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.value = GradeMath.sanitizedValue(
            value,
            unit: unit,
            maximumPoints: maximumPoints
        )
        self.unit = unit
        self.maximumPoints = GradeSettings.clampedMaximumPoints(maximumPoints)
        self.higherPointsAreBetter = higherPointsAreBetter
        self.note = note
        self.date = date
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, value, unit, maximumPoints, higherPointsAreBetter, note, date, updatedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        unit = try container.decodeIfPresent(GradeSystem.self, forKey: .unit) ?? .grades
        let decodedMax = try container.decodeIfPresent(Int.self, forKey: .maximumPoints) ?? 15
        maximumPoints = GradeSettings.clampedMaximumPoints(decodedMax)
        higherPointsAreBetter = try container.decodeIfPresent(Bool.self, forKey: .higherPointsAreBetter) ?? true
        let decodedValue = try container.decodeIfPresent(Double.self, forKey: .value) ?? 1
        value = GradeMath.sanitizedValue(decodedValue, unit: unit, maximumPoints: maximumPoints)
        note = try container.decodeIfPresent(String.self, forKey: .note) ?? ""
        date = try container.decodeIfPresent(Date.self, forKey: .date) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? date
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(value, forKey: .value)
        try container.encode(unit, forKey: .unit)
        try container.encode(maximumPoints, forKey: .maximumPoints)
        try container.encode(higherPointsAreBetter, forKey: .higherPointsAreBetter)
        try container.encode(note, forKey: .note)
        try container.encode(date, forKey: .date)
        try container.encode(updatedAt, forKey: .updatedAt)
    }

    // MARK: - Abgeleitete Werte

    /// Wie gut der Eintrag war – 0 (schlecht) bis 1 (perfekt). Grundlage für
    /// Durchschnitt, Farbe und Sortierung. Unabhängig von der Einheit, damit
    /// Punkte, Prozent und Noten vergleichbar bleiben.
    public var fraction: Double {
        GradeMath.fraction(
            for: value,
            unit: unit,
            maximumPoints: maximumPoints,
            higherPointsAreBetter: higherPointsAreBetter
        )
    }

    /// Der Eintrag als Schulnote (1 … 6). Bei Punkten/Prozent wird aus dem
    /// Verhältnis umgerechnet.
    public var gradeEquivalent: Double {
        GradeMath.grade(forFraction: fraction)
    }

    /// Anzeigetext des eigentlichen Werts, z. B. „2,3“, „12“ oder „85 %“.
    public var valueText: String {
        GradeMath.valueText(
            value,
            unit: unit,
            maximumPoints: maximumPoints
        )
    }

    /// Einheitlich formatierte Note, z. B. „2,3“.
    public var gradeText: String {
        GradeMath.gradeText(gradeEquivalent)
    }

    /// Hintergrundfarbe des Kästchens – pastellgrün bei sehr guten, rot bei
    /// sehr schlechten Einträgen.
    public var colorHex: String {
        GradeMath.colorHex(forFraction: fraction)
    }

    /// Kurzes Datum für die Kopfzeile des Kästchens.
    public var shortDateText: String {
        GradeMath.shortDateFormatter.string(from: date)
    }

    public var trimmedNote: String {
        note.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Alle Einträge je Fach. Der Schlüssel ist der (normalisierte) Fachname aus
/// „Fächer & Farben“ (`originalSubject`); so bleiben die Einträge auch dann
/// zugeordnet, wenn der Anzeigename später geändert wird.
public struct GradeBook: Codable, Equatable {
    /// Höchstzahl an Einträgen je Fach (schützt Speicher & Sync).
    public static let maximumEntriesPerSubject = 500

    /// Fach-Schlüssel → Einträge (neueste zuerst ist **nicht** garantiert;
    /// sortiert wird in der Ansicht).
    public var entriesBySubject: [String: [GradeEntry]]

    public init(entriesBySubject: [String: [GradeEntry]] = [:]) {
        self.entriesBySubject = entriesBySubject
    }

    private enum CodingKeys: String, CodingKey {
        case entriesBySubject
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decoded = try container.decodeIfPresent([String: [GradeEntry]].self, forKey: .entriesBySubject) ?? [:]
        var cleaned: [String: [GradeEntry]] = [:]
        for (key, list) in decoded {
            let limited = Array(list.sorted { $0.date > $1.date }.prefix(GradeBook.maximumEntriesPerSubject))
            if !limited.isEmpty { cleaned[key] = limited }
        }
        self.entriesBySubject = cleaned
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(entriesBySubject, forKey: .entriesBySubject)
    }

    public static func subjectKey(for subject: SubjectCustomization) -> String {
        GradeBook.normalizedKey(subject.originalSubject)
    }

    public static func normalizedKey(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    public func entries(forSubjectKey key: String) -> [GradeEntry] {
        entriesBySubject[key] ?? []
    }

    public func entries(for subject: SubjectCustomization) -> [GradeEntry] {
        entries(forSubjectKey: GradeBook.subjectKey(for: subject))
    }

    /// Fügt einen Eintrag hinzu (oder ersetzt ihn, gleiche ID).
    @discardableResult
    public mutating func upsert(_ entry: GradeEntry, subjectKey: String) -> Bool {
        var list = entriesBySubject[subjectKey] ?? []
        if let index = list.firstIndex(where: { $0.id == entry.id }) {
            list[index] = entry
        } else {
            guard list.count < GradeBook.maximumEntriesPerSubject else { return false }
            list.append(entry)
        }
        entriesBySubject[subjectKey] = list
        return true
    }

    public mutating func remove(entryID: UUID, subjectKey: String) {
        guard var list = entriesBySubject[subjectKey] else { return }
        list.removeAll { $0.id == entryID }
        if list.isEmpty {
            entriesBySubject.removeValue(forKey: subjectKey)
        } else {
            entriesBySubject[subjectKey] = list
        }
    }

    /// Entfernt alle Einträge eines Fachs (z. B. wenn das Fach gelöscht wird).
    public mutating func removeAll(subjectKey: String) {
        entriesBySubject.removeValue(forKey: subjectKey)
    }

    /// Verschiebt die Einträge eines Fachs auf einen neuen Schlüssel (z. B.
    /// wenn das Kürzel in „Fächer & Farben“ geändert wird).
    public mutating func renameSubject(from oldKey: String, to newKey: String) {
        guard oldKey != newKey, let list = entriesBySubject.removeValue(forKey: oldKey) else { return }
        var target = entriesBySubject[newKey] ?? []
        target.append(contentsOf: list)
        entriesBySubject[newKey] = target
    }
}

/// Reine Rechen- und Formatier-Regeln für Noten, Punkte und Prozent – ohne
/// UIKit, damit sie in den Regressions-Tests (Linux/`swiftc`) laufen.
public enum GradeMath {
    /// Note 1 … 6.
    public static let bestGrade: Double = 1
    public static let worstGrade: Double = 6

    public static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "dd.MM.yy"
        return formatter
    }()

    // MARK: - Werte & Verhältnisse

    public static func sanitizedValue(
        _ value: Double,
        unit: GradeSystem,
        maximumPoints: Int
    ) -> Double {
        guard value.isFinite else { return fallbackValue(unit: unit, maximumPoints: maximumPoints) }
        switch unit {
        case .grades:
            return min(worstGrade, max(bestGrade, value))
        case .points:
            let maxPoints = Double(GradeSettings.clampedMaximumPoints(maximumPoints))
            return min(maxPoints, max(0, value))
        case .percent:
            return min(100, max(0, value))
        }
    }

    public static func fallbackValue(unit: GradeSystem, maximumPoints: Int) -> Double {
        switch unit {
        case .grades: return 1
        case .points: return Double(GradeSettings.clampedMaximumPoints(maximumPoints)) / 2
        case .percent: return 50
        }
    }

    /// Größter zulässiger Eingabewert der Einheit.
    public static func upperBound(unit: GradeSystem, maximumPoints: Int) -> Double {
        switch unit {
        case .grades: return worstGrade
        case .points: return Double(GradeSettings.clampedMaximumPoints(maximumPoints))
        case .percent: return 100
        }
    }

    public static func lowerBound(unit: GradeSystem) -> Double {
        unit == .grades ? bestGrade : 0
    }

    /// Wie gut ein Wert war: 1 = perfekt, 0 = schlecht.
    public static func fraction(
        for value: Double,
        unit: GradeSystem,
        maximumPoints: Int,
        higherPointsAreBetter: Bool
    ) -> Double {
        let safeValue = value.isFinite ? value : 0
        switch unit {
        case .grades:
            // Note 1 → 1,0 ; Note 6 → 0,0
            let clamped = min(worstGrade, max(bestGrade, safeValue))
            return (worstGrade - clamped) / (worstGrade - bestGrade)
        case .points:
            let maxPoints = Double(GradeSettings.clampedMaximumPoints(maximumPoints))
            guard maxPoints > 0 else { return 0 }
            let ratio = min(1, max(0, safeValue / maxPoints))
            return higherPointsAreBetter ? ratio : 1 - ratio
        case .percent:
            let ratio = min(1, max(0, safeValue / 100))
            return ratio
        }
    }

    /// Verhältnis (0 … 1) zurück in einen Wert der Einheit.
    public static func value(
        forFraction fraction: Double,
        unit: GradeSystem,
        maximumPoints: Int,
        higherPointsAreBetter: Bool
    ) -> Double {
        let clamped = min(1, max(0, fraction.isFinite ? fraction : 0))
        switch unit {
        case .grades:
            return min(worstGrade, max(bestGrade, worstGrade - clamped * (worstGrade - bestGrade)))
        case .points:
            let maxPoints = Double(GradeSettings.clampedMaximumPoints(maximumPoints))
            let ratio = higherPointsAreBetter ? clamped : 1 - clamped
            return ratio * maxPoints
        case .percent:
            return clamped * 100
        }
    }

    /// Standard-Position des Reglers in Prozent-Einheiten.
    public static func sliderRange(unit: GradeSystem, maximumPoints: Int) -> ClosedRange<Double> {
        lowerBound(unit: unit)...upperBound(unit: unit, maximumPoints: maximumPoints)
    }

    /// Regler-Position (0 … 1) eines Werts – Note 1 liegt links.
    public static func sliderFraction(
        for value: Double,
        unit: GradeSystem,
        maximumPoints: Int
    ) -> Double {
        let lower = lowerBound(unit: unit)
        let upper = upperBound(unit: unit, maximumPoints: maximumPoints)
        guard upper > lower else { return 0 }
        let clamped = min(upper, max(lower, value.isFinite ? value : lower))
        return (clamped - lower) / (upper - lower)
    }

    public static func value(
        forSliderFraction fraction: Double,
        unit: GradeSystem,
        maximumPoints: Int
    ) -> Double {
        let lower = lowerBound(unit: unit)
        let upper = upperBound(unit: unit, maximumPoints: maximumPoints)
        let clamped = min(1, max(0, fraction.isFinite ? fraction : 0))
        let raw = lower + clamped * (upper - lower)
        switch unit {
        case .grades:
            // Noten in halben Schritten – so bleibt der Regler gut bedienbar.
            return (raw * 2).rounded() / 2
        case .points:
            return raw.rounded()
        case .percent:
            return raw.rounded()
        }
    }

    // MARK: - Noten-Umrechnung

    /// Schulnote (1 … 6) aus dem Verhältnis – 1 ist die beste Note.
    public static func grade(forFraction fraction: Double) -> Double {
        let clamped = min(1, max(0, fraction.isFinite ? fraction : 0))
        let grade = worstGrade - clamped * (worstGrade - bestGrade)
        return (grade * 10).rounded() / 10
    }

    /// Anzeige einer Note mit deutschem Dezimalkomma („2,3“).
    public static func gradeText(_ grade: Double) -> String {
        guard grade.isFinite else { return "–" }
        let rounded = (grade * 10).rounded() / 10
        if abs(rounded.rounded() - rounded) < 0.001 {
            return String(format: "%.0f", rounded)
        }
        return String(format: "%.1f", rounded).replacingOccurrences(of: ".", with: ",")
    }

    /// Anzeige eines Werts in seiner Einheit (Noten mit Komma, Punkte ohne
    /// Nachkommastellen, Prozent mit Prozentzeichen).
    public static func valueText(
        _ value: Double,
        unit: GradeSystem,
        maximumPoints: Int
    ) -> String {
        let safe = sanitizedValue(value, unit: unit, maximumPoints: maximumPoints)
        switch unit {
        case .grades:
            return gradeText(safe)
        case .points:
            return String(format: "%.0f", safe)
        case .percent:
            return String(format: "%.0f %%", safe)
        }
    }

    // MARK: - Durchschnitt

    /// Durchschnitt von Einträgen als Note (1 … 6). `nil` ohne Einträge.
    public static func averageGrade(for entries: [GradeEntry]) -> Double? {
        guard !entries.isEmpty else { return nil }
        let total = entries.reduce(0.0) { $0 + $1.fraction }
        return grade(forFraction: total / Double(entries.count))
    }

    /// Durchschnitt als Verhältnis (1 = perfekt). `nil` ohne Einträge.
    public static func averageFraction(for entries: [GradeEntry]) -> Double? {
        guard !entries.isEmpty else { return nil }
        return entries.reduce(0.0) { $0 + $1.fraction } / Double(entries.count)
    }

    public static func averageText(for entries: [GradeEntry]) -> String {
        guard let average = averageGrade(for: entries) else { return "–" }
        return gradeText(average)
    }

    // MARK: - Farbskala

    /// Hintergrundfarbe passend zur Güte eines Eintrags:
    /// sehr gut = pastellgrün, mittel = gelb/orange, schlecht = rot.
    /// Je besser der Eintrag, desto pastelliger (heller) wird er – so
    /// stechen die schlechten Einträge deutlich hervor.
    public static func colorHex(forFraction fraction: Double) -> String {
        let clamped = min(1, max(0, fraction.isFinite ? fraction : 0))
        // Note 1 → 0, Note 6 → 1
        let badness = 1 - clamped
        // Farbton: 130° (grün) → 48° (gelb) → 4° (rot)
        let hue: Double
        if badness <= 0.5 {
            hue = 130 - (badness / 0.5) * (130 - 48)
        } else {
            hue = 48 - ((badness - 0.5) / 0.5) * (48 - 4)
        }
        // Gute Einträge: wenig Sättigung, sehr hell (pastellig).
        // Schlechte Einträge: kräftiger und dunkler – sie fallen auf.
        let saturation = 0.30 + badness * 0.62
        let brightness = 0.98 - badness * 0.30
        return hslHex(hue: hue, saturation: saturation, brightness: brightness)
    }

    /// Wandelt Helligkeit/Sättigung/Farbton in einen Hex-String (`#RRGGBB`).
    public static func hslHex(hue: Double, saturation: Double, brightness: Double) -> String {
        let h = min(360, max(0, hue.isFinite ? hue : 0)) / 360
        let s = min(1, max(0, saturation.isFinite ? saturation : 0))
        let v = min(1, max(0, brightness.isFinite ? brightness : 0))

        let i = Int(h * 6)
        let f = h * 6 - Double(i)
        let p = v * (1 - s)
        let q = v * (1 - f * s)
        let t = v * (1 - (1 - f) * s)

        var r: Double = 0
        var g: Double = 0
        var b: Double = 0
        switch i % 6 {
        case 0:
            r = v; g = t; b = p
        case 1:
            r = q; g = v; b = p
        case 2:
            r = p; g = v; b = t
        case 3:
            r = p; g = q; b = v
        case 4:
            r = t; g = p; b = v
        default:
            r = v; g = p; b = q
        }
        return String(
            format: "#%02X%02X%02X",
            Int((r * 255).rounded()),
            Int((g * 255).rounded()),
            Int((b * 255).rounded())
        )
    }

    // MARK: - Sortierung

    /// Sortiert die Fächer-Schlüssel einer Liste nach der gewählten Regel.
    /// Die Eingabe bleibt unverändert; das Ergebnis enthält jeden Schlüssel
    /// genau einmal.
    public static func sortedSubjectKeys(
        _ keys: [String],
        displayName: (String) -> String,
        entries: (String) -> [GradeEntry],
        sort: GradeSubjectSort,
        randomSeed: UInt64 = 0
    ) -> [String] {
        let unique = Array(Set(keys))
        switch sort {
        case .alphabet:
            return unique.sorted {
                displayName($0).localizedCaseInsensitiveCompare(displayName($1)) == .orderedAscending
            }
        case .alphabetReversed:
            return unique.sorted {
                displayName($0).localizedCaseInsensitiveCompare(displayName($1)) == .orderedDescending
            }
        case .random:
            return unique.sorted {
                seededRank($0, seed: randomSeed) < seededRank($1, seed: randomSeed)
            }
        case .bestAverage:
            return unique.sorted {
                let lhs = averageFraction(for: entries($0)) ?? -1
                let rhs = averageFraction(for: entries($1)) ?? -1
                if lhs == rhs { return displayName($0).localizedCaseInsensitiveCompare(displayName($1)) == .orderedAscending }
                return lhs > rhs
            }
        case .worstAverage:
            return unique.sorted {
                let lhs = averageFraction(for: entries($0)) ?? 2
                let rhs = averageFraction(for: entries($1)) ?? 2
                if lhs == rhs { return displayName($0).localizedCaseInsensitiveCompare(displayName($1)) == .orderedAscending }
                return lhs < rhs
            }
        case .mostEntries:
            return unique.sorted {
                let lhs = entries($0).count
                let rhs = entries($1).count
                if lhs == rhs { return displayName($0).localizedCaseInsensitiveCompare(displayName($1)) == .orderedAscending }
                return lhs > rhs
            }
        case .fewestEntries:
            return unique.sorted {
                let lhs = entries($0).count
                let rhs = entries($1).count
                if lhs == rhs { return displayName($0).localizedCaseInsensitiveCompare(displayName($1)) == .orderedAscending }
                return lhs < rhs
            }
        case .lastChanged:
            return unique.sorted {
                let lhs = entries($0).map(\.updatedAt).max() ?? .distantPast
                let rhs = entries($1).map(\.updatedAt).max() ?? .distantPast
                if lhs == rhs { return displayName($0).localizedCaseInsensitiveCompare(displayName($1)) == .orderedAscending }
                return lhs > rhs
            }
        case .lastChangedReversed:
            return unique.sorted {
                let lhs = entries($0).map(\.updatedAt).max() ?? .distantFuture
                let rhs = entries($1).map(\.updatedAt).max() ?? .distantFuture
                if lhs == rhs { return displayName($0).localizedCaseInsensitiveCompare(displayName($1)) == .orderedAscending }
                return lhs < rhs
            }
        }
    }

    /// Sortiert die Einträge eines Fachs.
    public static func sortedEntries(_ entries: [GradeEntry], sort: GradeEntrySort) -> [GradeEntry] {
        switch sort {
        case .newest:
            return entries.sorted { $0.date > $1.date }
        case .oldest:
            return entries.sorted { $0.date < $1.date }
        case .best:
            return entries.sorted {
                if $0.fraction == $1.fraction { return $0.date > $1.date }
                return $0.fraction > $1.fraction
            }
        case .worst:
            return entries.sorted {
                if $0.fraction == $1.fraction { return $0.date > $1.date }
                return $0.fraction < $1.fraction
            }
        }
    }

    /// Stabile Pseudo-Zufalls-Reihenfolge über einen Seed. Gleicher Seed →
    /// gleiche Reihenfolge (die Liste springt beim Neurendern nicht).
    private static func seededRank(_ key: String, seed: UInt64) -> UInt64 {
        var hash: UInt64 = 1469598103934665603 &+ seed
        for byte in key.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1099511628211
        }
        return hash
    }
}
