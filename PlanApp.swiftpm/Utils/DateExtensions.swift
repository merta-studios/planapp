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

    /// Die Woche, die für die Navigation als "aktuell" gelten soll.
    /// An Wochenenden (Samstag/Sonntag) gibt es keinen Schultag mehr in der
    /// laufenden Woche, daher zeigt dies bereits auf die Montag-Woche danach.
    public static func relevantCurrentWeekStart(
        from date: Date = Date(),
        calendar: Calendar = .germanCalendar
    ) -> Date {
        let monday = date.startOfWeek(using: calendar)
        // component(.weekday) liefert unabhängig von firstWeekday immer 1 = Sonntag ... 7 = Samstag.
        let weekday = calendar.component(.weekday, from: date)
        if weekday == 1 || weekday == 7 {
            return calendar.date(byAdding: .day, value: 7, to: monday) ?? monday
        }
        return monday
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

    /// Parst einen "YYYY-MM-DD"-String zurück in ein Datum
    public static func fromYyyyMMdd(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        return formatter.date(from: string)
    }

    /// Deutsches Datumsformat, z.B. "01.10.2026"
    public var germanDateString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter.string(from: self)
    }

    /// Relative, deutsche Beschreibung des Tages, z.B. "Heute", "Morgen",
    /// "Übermorgen", "Montag" (gleiche Woche), "Nächste Woche Montag",
    /// "Übernächste Woche Montag" oder "Montag in 3 Wochen".
    public func relativeDayDescription(relativeTo now: Date = Date()) -> String {
        let cal = Calendar.germanCalendar
        let startToday = cal.startOfDay(for: now)
        let startSelf = cal.startOfDay(for: self)
        let dayDiff = cal.dateComponents([.day], from: startToday, to: startSelf).day ?? 0

        switch dayDiff {
        case 0: return "Heute"
        case 1: return "Morgen"
        case 2: return "Übermorgen"
        case -1: return "Gestern"
        case -2: return "Vorgestern"
        default: break
        }

        let weekday = self.weekdayLongString
        let weekDays = cal.dateComponents(
            [.day],
            from: now.startOfWeek(using: cal),
            to: self.startOfWeek(using: cal)
        ).day ?? 0
        let weeks = weekDays / 7

        switch weeks {
        case 0: return weekday
        case 1: return "Nächste Woche \(weekday)"
        case 2: return "Übernächste Woche \(weekday)"
        case -1: return "Letzte Woche \(weekday)"
        case -2: return "Vorletzte Woche \(weekday)"
        default:
            if weeks > 0 {
                return "\(weekday) in \(weeks) Wochen"
            } else {
                return "\(weekday) vor \(-weeks) Wochen"
            }
        }
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

    /// Sehr kurzes Datum für schmale Spalten (z.B. "30.09.")
    public var compactHeaderDateString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "dd.MM."
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
