import Foundation

/// Regeln rund um die Schulwoche – reine, ohne UIKit testbare Logik.
///
/// Die App zeigt Montag bis Freitag; das Wochenende gehört zur Kalenderwoche,
/// enthält aber keinen Schultag. Diese Regel steckte bisher verteilt in
/// Wochen-Schlüssel, „Nächste Woche“-Sprung und Tagesspalten – hier steht sie
/// einmal und ist damit auch unter Linux prüfbar (siehe CONTRIBUTING.md).
public enum SchoolWeekPolicy {
    /// `Calendar.component(.weekday, ...)` zählt 1 = Sonntag … 7 = Samstag.
    /// Eine Schulwoche läuft deshalb von 2 (Montag) bis 6 (Freitag).
    public static let firstSchoolWeekday = 2
    public static let lastSchoolWeekday = 6

    /// Montag bis Freitag.
    public static func isSchoolDay(_ date: Date, calendar: Calendar = .germanCalendar) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        return (firstSchoolWeekday...lastSchoolWeekday).contains(weekday)
    }

    /// Der erste Schultag **nach** `date` – vom Wochenende aus also der Montag.
    ///
    /// Es wird höchstens eine Woche weitergeschaltet: mehr braucht die App
    /// nicht, und so kann ein unplausibler Kalender keine Endlosschleife bauen.
    public static func nextSchoolDay(after date: Date, calendar: Calendar = .germanCalendar) -> Date {
        var day = calendar.startOfDay(for: date)
        for _ in 0..<7 {
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { return day }
            day = next
            if isSchoolDay(day, calendar: calendar) { return day }
        }
        return day
    }

    /// Der letzte Schultag **vor** `date` – vom Montag aus also der Freitag.
    public static func previousSchoolDay(before date: Date, calendar: Calendar = .germanCalendar) -> Date {
        var day = calendar.startOfDay(for: date)
        for _ in 0..<7 {
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { return day }
            day = previous
            if isSchoolDay(day, calendar: calendar) { return day }
        }
        return day
    }

    /// Alle Schultage der Woche, in der `date` liegt (immer Montag bis Freitag).
    public static func schoolDays(inWeekOf date: Date, calendar: Calendar = .germanCalendar) -> [Date] {
        let monday = date.startOfWeek(using: calendar)
        var days: [Date] = []
        days.reserveCapacity(lastSchoolWeekday - firstSchoolWeekday + 1)
        for offset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: monday) else { continue }
            if isSchoolDay(day, calendar: calendar) { days.append(day) }
        }
        return days
    }
}
