import Foundation

/// Generiert realistische Beispieldaten für den Stundenplan (inkl. Doppelstunden, Ausfall, Vertretung)
public final class DemoDataService {
    public static let shared = DemoDataService()

    /// Generiert einen vollständigen Stundenplan für eine gegebene Woche (Montag bis Freitag)
    public func generateDemoWeek(for weekMonday: Date) -> [Lesson] {
        var lessons: [Lesson] = []
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")

        // Tage von Montag (0) bis Freitag (4)
        var dayDates: [String] = []
        for i in 0..<5 {
            if let d = calendar.date(byAdding: .day, value: i, to: weekMonday) {
                dayDates.append(formatter.string(from: d))
            }
        }
        guard dayDates.count == 5 else { return [] }

        let mon = dayDates[0]
        let tue = dayDates[1]
        let wed = dayDates[2]
        let thu = dayDates[3]
        let fri = dayDates[4]

        // --- MONTAG ---
        // 1. & 2. Stunde: Mathematik (Doppelstunde)
        lessons.append(Lesson(dateString: mon, periodNumber: 1, durationPeriods: 1, subjectRaw: "M", teacherRaw: "MUE", roomRaw: "R204", klasseRaw: "10B"))
        lessons.append(Lesson(dateString: mon, periodNumber: 2, durationPeriods: 1, subjectRaw: "M", teacherRaw: "MUE", roomRaw: "R204", klasseRaw: "10B"))

        // 3. Stunde: Deutsch
        lessons.append(Lesson(dateString: mon, periodNumber: 3, durationPeriods: 1, subjectRaw: "D", teacherRaw: "SCH", roomRaw: "R102", klasseRaw: "10B"))

        // 4. Stunde: Englisch
        lessons.append(Lesson(dateString: mon, periodNumber: 4, durationPeriods: 1, subjectRaw: "E", teacherRaw: "BEC", roomRaw: "R105", klasseRaw: "10B"))

        // 5. Stunde: Physik - ENTFÄLLT (rot durchgestrichen)
        lessons.append(Lesson(dateString: mon, periodNumber: 5, durationPeriods: 1, subjectRaw: "PH", teacherRaw: "MAY", roomRaw: "PHY-1", klasseRaw: "10B", isCancelled: true, substitutionText: "Entfällt wegen Lehrerkonferenz"))

        // 6. Stunde: Geschichte
        lessons.append(Lesson(dateString: mon, periodNumber: 6, durationPeriods: 1, subjectRaw: "GE", teacherRaw: "HOF", roomRaw: "R201", klasseRaw: "10B"))

        // --- DIENSTAG ---
        // 1. Stunde: Biologie
        lessons.append(Lesson(dateString: tue, periodNumber: 1, durationPeriods: 1, subjectRaw: "BIO", teacherRaw: "KLE", roomRaw: "BIO-1", klasseRaw: "10B"))

        // 2. Stunde: Chemie - VERTRETUNG
        lessons.append(Lesson(dateString: tue, periodNumber: 2, durationPeriods: 1, subjectRaw: "CH", teacherRaw: "BAU", roomRaw: "CH-2", klasseRaw: "10B", isSubstitution: true, substitutionText: "Vertretung durch Hr. Bauer in CH-2", originalTeacher: "WAG", originalRoom: "CH-1"))

        // 3. & 4. Stunde: Kunst (Doppelstunde)
        lessons.append(Lesson(dateString: tue, periodNumber: 3, durationPeriods: 1, subjectRaw: "KU", teacherRaw: "ZIM", roomRaw: "KUNST", klasseRaw: "10B"))
        lessons.append(Lesson(dateString: tue, periodNumber: 4, durationPeriods: 1, subjectRaw: "KU", teacherRaw: "ZIM", roomRaw: "KUNST", klasseRaw: "10B"))

        // 5. Stunde: Mathematik
        lessons.append(Lesson(dateString: tue, periodNumber: 5, durationPeriods: 1, subjectRaw: "M", teacherRaw: "MUE", roomRaw: "R204", klasseRaw: "10B"))

        // 6. Stunde: Englisch
        lessons.append(Lesson(dateString: tue, periodNumber: 6, durationPeriods: 1, subjectRaw: "E", teacherRaw: "BEC", roomRaw: "R105", klasseRaw: "10B"))

        // --- MITTWOCH ---
        // 1. & 2. Stunde: Deutsch (Doppelstunde)
        lessons.append(Lesson(dateString: wed, periodNumber: 1, durationPeriods: 1, subjectRaw: "D", teacherRaw: "SCH", roomRaw: "R102", klasseRaw: "10B"))
        lessons.append(Lesson(dateString: wed, periodNumber: 2, durationPeriods: 1, subjectRaw: "D", teacherRaw: "SCH", roomRaw: "R102", klasseRaw: "10B"))

        // 3. Stunde: Geografie
        lessons.append(Lesson(dateString: wed, periodNumber: 3, durationPeriods: 1, subjectRaw: "GEO", teacherRaw: "LAN", roomRaw: "R104", klasseRaw: "10B"))

        // 4. Stunde: Physik
        lessons.append(Lesson(dateString: wed, periodNumber: 4, durationPeriods: 1, subjectRaw: "PH", teacherRaw: "MAY", roomRaw: "PHY-1", klasseRaw: "10B"))

        // 5. Stunde: Religion / Ethik
        lessons.append(Lesson(dateString: wed, periodNumber: 5, durationPeriods: 1, subjectRaw: "REL", teacherRaw: "VOG", roomRaw: "R108", klasseRaw: "10B"))

        // 6. Stunde: Musik
        lessons.append(Lesson(dateString: wed, periodNumber: 6, durationPeriods: 1, subjectRaw: "MU", teacherRaw: "RIC", roomRaw: "MUSIK", klasseRaw: "10B"))

        // --- DONNERSTAG ---
        // 1. & 2. Stunde: Sport (Doppelstunde)
        lessons.append(Lesson(dateString: thu, periodNumber: 1, durationPeriods: 1, subjectRaw: "SP", teacherRaw: "FIT", roomRaw: "HALLE-1", klasseRaw: "10B"))
        lessons.append(Lesson(dateString: thu, periodNumber: 2, durationPeriods: 1, subjectRaw: "SP", teacherRaw: "FIT", roomRaw: "HALLE-1", klasseRaw: "10B"))

        // 3. Stunde: Englisch
        lessons.append(Lesson(dateString: thu, periodNumber: 3, durationPeriods: 1, subjectRaw: "E", teacherRaw: "BEC", roomRaw: "R105", klasseRaw: "10B"))

        // 4. Stunde: Mathematik
        lessons.append(Lesson(dateString: thu, periodNumber: 4, durationPeriods: 1, subjectRaw: "M", teacherRaw: "MUE", roomRaw: "R204", klasseRaw: "10B"))

        // 5. & 6. Stunde: Informatik (Doppelstunde)
        lessons.append(Lesson(dateString: thu, periodNumber: 5, durationPeriods: 1, subjectRaw: "INF", teacherRaw: "NER", roomRaw: "INFO-1", klasseRaw: "10B"))
        lessons.append(Lesson(dateString: thu, periodNumber: 6, durationPeriods: 1, subjectRaw: "INF", teacherRaw: "NER", roomRaw: "INFO-1", klasseRaw: "10B"))

        // --- FREITAG ---
        // 1. Stunde: Geschichte
        lessons.append(Lesson(dateString: fri, periodNumber: 1, durationPeriods: 1, subjectRaw: "GE", teacherRaw: "HOF", roomRaw: "R201", klasseRaw: "10B"))

        // 2. Stunde: Biologie
        lessons.append(Lesson(dateString: fri, periodNumber: 2, durationPeriods: 1, subjectRaw: "BIO", teacherRaw: "KLE", roomRaw: "BIO-1", klasseRaw: "10B"))

        // 3. Stunde: Deutsch
        lessons.append(Lesson(dateString: fri, periodNumber: 3, durationPeriods: 1, subjectRaw: "D", teacherRaw: "SCH", roomRaw: "R102", klasseRaw: "10B"))

        // 4. Stunde: Chemie
        lessons.append(Lesson(dateString: fri, periodNumber: 4, durationPeriods: 1, subjectRaw: "CH", teacherRaw: "WAG", roomRaw: "CH-1", klasseRaw: "10B"))

        // 5. Stunde: Französisch
        lessons.append(Lesson(dateString: fri, periodNumber: 5, durationPeriods: 1, subjectRaw: "F", teacherRaw: "DUP", roomRaw: "R206", klasseRaw: "10B"))

        return lessons
    }
}
