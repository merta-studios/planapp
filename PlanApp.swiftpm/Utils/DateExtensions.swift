import Foundation

extension Date {
    /// Gibt den Montag (00:00 Uhr) der aktuellen Kalenderwoche zurück
    public func startOfWeek(using calendar: Calendar = .germanCalendar) -> Date {
        var cal = calendar
        cal.firstWeekday = 2 // Montag
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        return cal.date(from: comps) ?? self
    }

    /// Gibt die 5 Schultage (Montag bis Freitag) der Woche zurück
    public func schoolWeekDays(using calendar: Calendar = .germanCalendar) -> [Date] {
        let monday = self.startOfWeek(using: calendar)
        var days: [Date] = []
        for i in 0..<5 {
            if let d = calendar.date(byAdding: .day, value: i, to: monday) {
                days.append(d)
            }
        }
        return days
    }

    /// Prüft, ob dieses Datum der heutige Tag ist
    public var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }

    /// Prüft, ob zwei Daten derselbe Kalendertag sind
    public func isSameDay(as other: Date) -> Bool {
        Calendar.current.isDate(self, inSameDayAs: other)
    }

    /// Formatiert Datum zu "YYYY-MM-DD"
    public var yyyyMMddString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: self)
    }

    /// Kalenderwoche (z.B. "KW 40")
    public var calendarWeekString: String {
        let cal = Calendar.germanCalendar
        let week = cal.component(.weekOfYear, from: self)
        return "KW \(week)"
    }

    /// Wochentagsname (z.B. "Montag", "Dienstag")
    public var weekdayLongString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "EEEE"
        return formatter.string(from: self).capitalized
    }

    /// Datum kurz für den Spalten-Header (z.B. "30. Sep" oder "14. Okt")
    public var headerDateString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "d. MMM"
        return formatter.string(from: self)
    }

    /// Vollständiger Wochenbereich für den Header (z.B. "30.09. – 04.10.2026")
    public func weekRangeString(using calendar: Calendar = .germanCalendar) -> String {
        let monday = self.startOfWeek(using: calendar)
        let friday = calendar.date(byAdding: .day, value: 4, to: monday) ?? monday

        let startFormatter = DateFormatter()
        startFormatter.locale = Locale(identifier: "de_DE")
        startFormatter.dateFormat = "dd.MM."

        let endFormatter = DateFormatter()
        endFormatter.locale = Locale(identifier: "de_DE")
        endFormatter.dateFormat = "dd.MM.yyyy"

        return "\(startFormatter.string(from: monday)) – \(endFormatter.string(from: friday))"
    }
}

extension Calendar {
    public static var germanCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "de_DE")
        cal.firstWeekday = 2 // Montag
        cal.timeZone = TimeZone.current
        return cal
    }
}
