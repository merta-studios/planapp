import Foundation

/// Gemeinsame, wiederverwendete Kalender und Datums-Formatierer.
///
/// `DateFormatter` und `Calendar(identifier:)` sind im Anlegen teuer: Locale,
/// Kalender und Zeichensatz werden dabei jedes Mal neu aufgebaut. Beim
/// Wochenwechsel werden allein für die Spaltenköpfe und Tages-Schlüssel des
/// Drei-Wochen-Karussells weit über hundert Datumsangaben formatiert – das
/// Anlegen der Formatierer war ein wesentlicher Teil der Ruckler.
///
/// `DateFormatter` ist seit iOS 7 thread-sicher, die gemeinsame Nutzung also
/// unbedenklich (Notizen werden auch aus Hintergrund-Queues geladen).
/// `TimeZone.autoupdatingCurrent` sorgt dafür, dass ein Zeitzonenwechsel
/// während der Laufzeit trotz gecachter Instanzen berücksichtigt wird.
enum PlanDateFormatting {
    /// Deutscher Kalender mit Montag als erstem Wochentag.
    static let germanCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "de_DE")
        calendar.firstWeekday = 2 // Montag
        calendar.timeZone = TimeZone.autoupdatingCurrent
        return calendar
    }()

    /// „YYYY-MM-DD“ – der Tages-/Wochenschlüssel der App (Notiz-IDs,
    /// Wochen-Cache, API-Abfragen). Derselbe Formatierer schreibt und liest,
    /// damit aus einem Schlüssel immer wieder dasselbe Datum wird.
    static let isoDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.autoupdatingCurrent
        return formatter
    }()

    /// Deutsches Datum, z. B. „01.10.2026“.
    static let germanDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "dd.MM.yyyy"
        formatter.timeZone = TimeZone.autoupdatingCurrent
        return formatter
    }()

    /// Ausgeschriebener Wochentag, z. B. „Montag“.
    static let weekdayLong: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "EEEE"
        formatter.timeZone = TimeZone.autoupdatingCurrent
        return formatter
    }()

    /// Kurzes Datum für den Spaltenkopf, z. B. „30. Sep“.
    static let headerDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "d. MMM"
        formatter.timeZone = TimeZone.autoupdatingCurrent
        return formatter
    }()

    /// Sehr kurzes Datum für schmale Spalten, z. B. „30.09.“.
    static let compactHeaderDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "dd.MM."
        formatter.timeZone = TimeZone.autoupdatingCurrent
        return formatter
    }()
}

extension Date {
    /// Gibt den Montag (00:00 Uhr) der aktuellen Kalenderwoche zurück
    public func startOfWeek(using calendar: Calendar = .germanCalendar) -> Date {
        var cal = calendar
        // Der deutsche Kalender der App hat Montag bereits als ersten
        // Wochentag. Nur fremde Kalender werden umgestellt – das erspart beim
        // häufigen Aufruf eine überflüssige Kalender-Kopie.
        if cal.firstWeekday != 2 {
            cal.firstWeekday = 2 // Montag
        }
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        return cal.date(from: comps) ?? self
    }

    /// Gibt die 5 Schultage (Montag bis Freitag) der Woche zurück
    public func schoolWeekDays(using calendar: Calendar = .germanCalendar) -> [Date] {
        // Die Regel „Montag bis Freitag“ steht in `SchoolWeekPolicy` – so gilt
        // sie an jeder Stelle gleich, auch für das Wochenende als Ausgangspunkt.
        SchoolWeekPolicy.schoolDays(inWeekOf: self, calendar: calendar)
    }

    /// Prüft, ob dieses Datum der heutige Tag ist
    public var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }

    /// Die Woche, die für die Navigation als "aktuell" gelten soll.
    ///
    /// * An Wochenenden (Samstag/Sonntag) gibt es keinen Schultag mehr in der
    ///   laufenden Woche – dann zeigt dies bereits auf die Montagswoche danach.
    /// * Am **Freitag nach der letzten Stunde** ist die Schulwoche ebenfalls
    ///   vorbei; auch dann ist die kommende Woche die relevante. Dafür wird
    ///   `lastLessonEndMinutes` (Ende der letzten Stunde des Tages, Minuten seit
    ///   Mitternacht) übergeben.
    public static func relevantCurrentWeekStart(
        from date: Date = Date(),
        lastLessonEndMinutes: Int? = nil,
        calendar: Calendar = .germanCalendar
    ) -> Date {
        let monday = date.startOfWeek(using: calendar)
        // component(.weekday) liefert unabhängig von firstWeekday immer 1 = Sonntag ... 7 = Samstag.
        let weekday = calendar.component(.weekday, from: date)
        if weekday == 1 || weekday == 7 {
            return calendar.date(byAdding: .day, value: 7, to: monday) ?? monday
        }
        // Freitag: Nach dem Ende der letzten Stunde läuft die Woche aus.
        if weekday == 6, let lastLessonEndMinutes {
            let components = calendar.dateComponents([.hour, .minute], from: date)
            let minutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)
            if minutes >= lastLessonEndMinutes {
                return calendar.date(byAdding: .day, value: 7, to: monday) ?? monday
            }
        }
        return monday
    }

    /// Der Tag, der als "kommende Schulwoche" wie „heute“ hervorgehoben wird:
    /// der Montag der nächsten Woche, wenn die laufende Schulwoche bereits
    /// vorbei ist (Wochenende oder Freitag nach der letzten Stunde). Sonst
    /// `nil`, dann wird der echte heutige Tag blau markiert.
    public static func upcomingWeekHighlightDay(
        from date: Date = Date(),
        lastLessonEndMinutes: Int? = nil,
        calendar: Calendar = .germanCalendar
    ) -> Date? {
        let relevant = relevantCurrentWeekStart(
            from: date,
            lastLessonEndMinutes: lastLessonEndMinutes,
            calendar: calendar
        )
        let currentMonday = date.startOfWeek(using: calendar)
        guard relevant > currentMonday else { return nil }
        return relevant
    }

    /// Prüft, ob zwei Daten derselbe Kalendertag sind
    public func isSameDay(as other: Date) -> Bool {
        Calendar.current.isDate(self, inSameDayAs: other)
    }

    /// Formatiert Datum zu "YYYY-MM-DD"
    public var yyyyMMddString: String {
        PlanDateFormatting.isoDay.string(from: self)
    }

    /// Parst einen "YYYY-MM-DD"-String zurück in ein Datum
    public static func fromYyyyMMdd(_ string: String) -> Date? {
        PlanDateFormatting.isoDay.date(from: string)
    }

    /// Deutsches Datumsformat, z.B. "01.10.2026"
    public var germanDateString: String {
        PlanDateFormatting.germanDate.string(from: self)
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
        PlanDateFormatting.weekdayLong.string(from: self).capitalized
    }

    /// Datum kurz für den Spalten-Header (z.B. "30. Sep" oder "14. Okt")
    public var headerDateString: String {
        PlanDateFormatting.headerDate.string(from: self)
    }

    /// Sehr kurzes Datum für schmale Spalten (z.B. "30.09.")
    public var compactHeaderDateString: String {
        PlanDateFormatting.compactHeaderDate.string(from: self)
    }

    /// Vollständiger Wochenbereich für den Header (z.B. "30.09. – 04.10.2026")
    public func weekRangeString(using calendar: Calendar = .germanCalendar) -> String {
        let monday = self.startOfWeek(using: calendar)
        let friday = calendar.date(byAdding: .day, value: 4, to: monday) ?? monday

        return "\(PlanDateFormatting.compactHeaderDate.string(from: monday)) – \(PlanDateFormatting.germanDate.string(from: friday))"
    }
}

extension Calendar {
    /// Deutscher Kalender mit Montag als erstem Wochentag.
    ///
    /// Die Instanz wird geteilt (siehe `PlanDateFormatting`): Früher wurde bei
    /// jedem Zugriff ein neuer Kalender samt `Locale` gebaut – und dieser
    /// Zugriff steckt in fast jeder Datumsrechnung der App.
    public static var germanCalendar: Calendar {
        PlanDateFormatting.germanCalendar
    }
}
