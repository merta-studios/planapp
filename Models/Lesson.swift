import Foundation

/// Repräsentiert eine Unterrichtsstunde im Stundenplan
public struct Lesson: Identifiable, Codable, Equatable, Hashable {
    public var id: String
    public var dateString: String // Format: "YYYY-MM-DD"
    public var periodNumber: Int   // z.B. 1 für 1. Stunde
    public var durationPeriods: Int // 1 = Einzelstunde, 2 = Doppelstunde
    public var subjectRaw: String  // Fachname von Untis (z.B. "M", "D", "E-LK")
    public var teacherRaw: String  // Lehrerkürzel/Name (z.B. "MUE", "Fr. Schmidt")
    public var roomRaw: String     // Raum (z.B. "R204", "PHY-1")
    public var klasseRaw: String   // Klasse (z.B. "10B", "Q1")
    public var isCancelled: Bool   // Entfallende Stunde (rot durchgestrichen)
    public var isSubstitution: Bool // Vertretungsstunde (hervorgehoben)
    public var substitutionText: String // Vertretungstext / Notiz (z.B. "Stillarbeit in R101")
    public var originalTeacher: String? // Ursprünglicher Lehrer bei Vertretung
    public var originalRoom: String?    // Ursprünglicher Raum bei Raumwechsel
    public var originalSubject: String? // Ursprüngliches Fach
    public var info: String?            // Zusätzliche Bemerkungen

    public init(
        id: String = UUID().uuidString,
        dateString: String,
        periodNumber: Int,
        durationPeriods: Int = 1,
        subjectRaw: String,
        teacherRaw: String = "",
        roomRaw: String = "",
        klasseRaw: String = "",
        isCancelled: Bool = false,
        isSubstitution: Bool = false,
        substitutionText: String = "",
        originalTeacher: String? = nil,
        originalRoom: String? = nil,
        originalSubject: String? = nil,
        info: String? = nil
    ) {
        self.id = id
        self.dateString = dateString
        self.periodNumber = periodNumber
        self.durationPeriods = durationPeriods
        self.subjectRaw = subjectRaw
        self.teacherRaw = teacherRaw
        self.roomRaw = roomRaw
        self.klasseRaw = klasseRaw
        self.isCancelled = isCancelled
        self.isSubstitution = isSubstitution
        self.substitutionText = substitutionText
        self.originalTeacher = originalTeacher
        self.originalRoom = originalRoom
        self.originalSubject = originalSubject
        self.info = info
    }

    /// Eindeutiger Schlüssel für Notizen & Zeichnungen zu dieser Stunde
    public var noteKey: String {
        "\(dateString)_\(periodNumber)_\(subjectRaw.trimmingCharacters(in: .whitespacesAndNewlines))"
    }

    /// Prüft, ob zwei Stunden zusammengelegt werden können (Doppelstunde)
    public func canMergeWithNext(lesson: Lesson) -> Bool {
        return self.dateString == lesson.dateString &&
            lesson.periodNumber == self.periodNumber + self.durationPeriods &&
            self.subjectRaw.caseInsensitiveCompare(lesson.subjectRaw) == .orderedSame &&
            self.teacherRaw.caseInsensitiveCompare(lesson.teacherRaw) == .orderedSame &&
            self.roomRaw.caseInsensitiveCompare(lesson.roomRaw) == .orderedSame &&
            self.isCancelled == lesson.isCancelled &&
            self.isSubstitution == lesson.isSubstitution
    }
}
