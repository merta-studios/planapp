import Foundation

/// In welchem Slot des konfigurierten Stundenrasters eine Uhrzeit liegt –
/// reine, ohne UIKit testbare Logik (siehe CONTRIBUTING.md).
///
/// `Period` trägt Start und Ende als Minuten seit Mitternacht. Darauf
/// aufbauend beantwortet diese Policy, ob die aktuelle Zeit vor der ersten
/// Stunde, in einer Stunde, in einer Pause (inklusive der als Nächstes
/// folgenden Stunde) oder nach der letzten Stunde liegt. Die
/// Stundenplan-Ansicht kann damit z. B. die gerade laufende Stunde
/// hervorheben und ihren Fortschritt anzeigen.
public enum CurrentPeriodSlot: Equatable {
    /// Vor der ersten Stunde des Tages.
    case beforeFirstPeriod
    /// In einer Stunde: Beginn inklusive, Ende exklusive.
    case inPeriod(Period)
    /// Pause zwischen zwei Stunden; der zugehörige Wert ist die nächste Stunde.
    case inBreak(next: Period)
    /// Nach der letzten Stunde des Tages.
    case afterLastPeriod
}

public enum CurrentPeriodPolicy {
    /// Gültige Stunden, nach Beginn sortiert. Stunden, deren Ende nicht nach
    /// ihrem Beginn liegt, werden ignoriert – ein unvollständiges
    /// WebUntis-Raster darf keine falschen Ergebnisse erzeugen.
    public static func validPeriods(sorted periods: [Period]) -> [Period] {
        periods
            .filter { $0.endMinutes > $0.startMinutes }
            .sorted {
                if $0.startMinutes != $1.startMinutes {
                    return $0.startMinutes < $1.startMinutes
                }
                // Make malformed duplicate-start grids deterministic: prefer
                // the shorter interval rather than input order.
                return $0.endMinutes < $1.endMinutes
            }
    }

    /// In welchem Slot liegt `minutesSinceMidnight` innerhalb von `periods`?
    /// `nil`, wenn das Raster keine gültige Stunde enthält.
    ///
    /// Bei Überlappungen gewinnt die am frühesten beginnende Stunde – das
    /// Raster der App ist disjunkt, aber ein defektes Import-Raster darf
    /// nicht zu einem Absturz oder einer willkürlichen Auswahl führen.
    public static func slot(
        atMinutes minutesSinceMidnight: Int,
        in periods: [Period]
    ) -> CurrentPeriodSlot? {
        let grid = validPeriods(sorted: periods)
        guard let first = grid.first else { return nil }
        if minutesSinceMidnight < first.startMinutes {
            return .beforeFirstPeriod
        }
        for period in grid {
            if period.startMinutes <= minutesSinceMidnight && minutesSinceMidnight < period.endMinutes {
                return .inPeriod(period)
            }
            if minutesSinceMidnight < period.startMinutes {
                return .inBreak(next: period)
            }
        }
        return .afterLastPeriod
    }

    /// Dieselbe Auswertung ausgehend von einem `Date`
    /// (Stunden und Minuten im übergebenen Kalender).
    public static func slot(
        at date: Date,
        in periods: [Period],
        calendar: Calendar = .germanCalendar
    ) -> CurrentPeriodSlot? {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        guard let hour = components.hour, let minute = components.minute else { return nil }
        return slot(atMinutes: hour * 60 + minute, in: periods)
    }

    /// Fortschritt der laufenden Stunde als Anteil 0…1 (für Fortschritts-
    /// anzeigen). Für alle anderen Slots und ungültige Stunden `nil`.
    public static func progress(
        of slot: CurrentPeriodSlot,
        atMinutes minutesSinceMidnight: Int
    ) -> Double? {
        guard case let .inPeriod(period) = slot else { return nil }
        let duration = period.endMinutes - period.startMinutes
        guard duration > 0 else { return nil }
        let elapsed = Double(minutesSinceMidnight - period.startMinutes)
        return min(max(elapsed / Double(duration), 0), 1)
    }
}
