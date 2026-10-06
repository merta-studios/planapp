import SwiftUI

/// Die Kopfzeile einer Notiz: optionaler Fach-Farbkreis, Fachname, darunter
/// die im Stundenplan aktivierten Zusatzinfos (Lehrer, Raum, Klasse,
/// Uhrzeiten) und rechts die Stunde samt Datum.
///
/// Wird sowohl über der Zeichenfläche im Bearbeiten-Overlay als auch in der
/// "Nur Notizen"-Übersicht verwendet. In der Übersicht kann der Farbkreis
/// ausgeblendet werden, weil dort der komplette Karten-Hintergrund bereits die
/// Fach-Farbe bzw. den Fach-Verlauf trägt.
public struct NoteHeaderContent<Accessory: View>: View {
    public let lesson: Lesson
    public let display: SubjectDisplay
    public let displaySettings: BlockDisplaySettings
    public let periods: [Period]
    /// Grundfarbe der Texte (im Overlay z. B. abhängig vom Ausklapp-Zustand).
    public let primaryColor: Color
    public let showsColorCircle: Bool
    public let isCompact: Bool
    private let teacherDisplayName: String
    private let originalTeacherDisplayName: String?
    private let relativeTo: Date
    /// Optionales Element direkt neben dem Fachnamen (z. B. die Tag-Pille).
    private let accessory: Accessory

    public init(
        lesson: Lesson,
        display: SubjectDisplay,
        displaySettings: BlockDisplaySettings,
        periods: [Period],
        primaryColor: Color = .primary,
        showsColorCircle: Bool = true,
        isCompact: Bool = false,
        teacherDisplayName: String? = nil,
        originalTeacherDisplayName: String? = nil,
        relativeTo: Date = Date(),
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.lesson = lesson
        self.display = display
        self.displaySettings = displaySettings
        self.periods = periods
        self.primaryColor = primaryColor
        self.showsColorCircle = showsColorCircle
        self.isCompact = isCompact
        self.teacherDisplayName = teacherDisplayName ?? lesson.teacherRaw
        self.originalTeacherDisplayName = originalTeacherDisplayName ?? lesson.originalTeacher
        self.relativeTo = relativeTo
        self.accessory = accessory()
    }

    public var body: some View {
        Group {
            if isCompact {
                compactHeader
            } else {
                regularHeader
            }
        }
        .foregroundColor(primaryColor)
    }

    /// Datum unter statt neben dem Fach: So bleibt der Titel auch in drei
    /// Spalten lesbar, ohne die 64-pt-Kopfzeile der Zeichenfläche zu ändern.
    private var compactHeader: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(display.name)
                    .font(.system(size: 15, weight: .semibold))
                    .strikethrough(lesson.isCancelled, color: .red)
                    .lineLimit(1)
                accessory
                Spacer(minLength: 0)
                Text("\(lesson.periodNumber). Std.")
                    .font(.system(size: 11, weight: .semibold))
                    .strikethrough(lesson.isCancelled, color: .red)
                    .fixedSize()
            }
            if hasHeaderDetails { headerDetails }
            Text(headerDateText)
                .font(.system(size: 10))
                .opacity(0.78)
                .strikethrough(lesson.isCancelled, color: .red)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
    }

    private var regularHeader: some View {
        HStack(alignment: .center, spacing: showsColorCircle ? 12 : 0) {
            if showsColorCircle {
                Circle()
                    .fill(subjectGradient)
                    .overlay(
                        Circle().strokeBorder(Color.primary.opacity(0.18), lineWidth: 1)
                    )
                    .frame(width: 16, height: 16)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 10) {
                    Text(display.name)
                        .font(.system(size: 18, weight: .semibold, design: .default))
                        .strikethrough(lesson.isCancelled, color: .red)
                        .lineLimit(1)
                    accessory
                }

                if hasHeaderDetails {
                    headerDetails
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(lesson.periodNumber). Stunde")
                    .font(.system(size: 13, weight: .semibold, design: .default))
                    .strikethrough(lesson.isCancelled, color: .red)
                Text(headerDateText)
                    .font(.system(size: 12, weight: .regular, design: .default))
                    .strikethrough(lesson.isCancelled, color: .red)
                    .opacity(0.78)
            }
            .lineLimit(1)
        }
        .foregroundColor(primaryColor)
        .frame(height: 64)
    }

    private var subjectGradient: LinearGradient {
        LinearGradient(
            colors: [display.color, display.gradientEndColor ?? display.color],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Zusatz-Infos unter dem Fachnamen – exakt die Elemente, die auch im
    /// Stundenplan-Block aktiviert sind (Lehrer, Raum, Klasse, Uhrzeiten).
    private var hasHeaderDetails: Bool {
        let settings = displaySettings
        return (settings.showTeacher && !lesson.teacherRaw.isEmpty)
            || (settings.showRoom && !lesson.roomRaw.isEmpty)
            || (settings.showKlasse && !lesson.klasseRaw.isEmpty)
            || settings.showTimes
    }

    private var headerDetails: some View {
        let settings = displaySettings

        return HStack(spacing: isCompact ? 6 : 10) {
            if settings.showTeacher && !lesson.teacherRaw.isEmpty {
                HStack(spacing: 3) {
                    Image(systemName: "person")
                        .font(.system(size: 10, weight: .regular, design: .default))
                    if let orig = originalTeacherDisplayName, lesson.isSubstitution {
                        Text(orig)
                            .strikethrough(true, color: .red)
                        Text("➔ \(teacherDisplayName)")
                            .strikethrough(lesson.isCancelled, color: .red)
                    } else {
                        Text(teacherDisplayName)
                            .strikethrough(lesson.isCancelled, color: .red)
                    }
                }
            }

            if settings.showRoom && !lesson.roomRaw.isEmpty {
                HStack(spacing: 3) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 10, weight: .regular, design: .default))
                    if let orig = lesson.originalRoom, lesson.isSubstitution {
                        Text(orig)
                            .strikethrough(true, color: .red)
                        Text("➔ \(lesson.roomRaw)")
                            .strikethrough(lesson.isCancelled, color: .red)
                    } else {
                        Text(lesson.roomRaw)
                            .strikethrough(lesson.isCancelled, color: .red)
                    }
                }
            }

            if settings.showKlasse && !lesson.klasseRaw.isEmpty {
                HStack(spacing: 3) {
                    Image(systemName: "person.3")
                        .font(.system(size: 10, weight: .regular, design: .default))
                    Text(lesson.klasseRaw)
                        .strikethrough(lesson.isCancelled, color: .red)
                }
            }

            if settings.showTimes,
               let period = periods.first(where: { $0.periodNumber == lesson.periodNumber }) {
                HStack(spacing: 3) {
                    Image(systemName: "clock")
                        .font(.system(size: 10, weight: .regular, design: .default))
                    Text("\(period.startTime) – \(period.endTime)")
                        .strikethrough(lesson.isCancelled, color: .red)
                }
            }
        }
        .font(.system(size: isCompact ? 10 : 12, weight: .regular, design: .default))
        .opacity(0.75)
        .lineLimit(1)
    }

    /// Rechte Kopfzeile: relative Angabe wie "Morgen" oder "Nächste Woche
    /// Montag" plus deutsches Datumsformat (z.B. "01.10.2026").
    private var headerDateText: String {
        guard let date = Date.fromYyyyMMdd(lesson.dateString) else {
            return lesson.dateString
        }
        return "\(date.relativeDayDescription(relativeTo: relativeTo)) • \(date.germanDateString)"
    }
}

extension NoteHeaderContent where Accessory == EmptyView {
    /// Kopfzeile ohne Zusatz-Element neben dem Fachnamen.
    public init(
        lesson: Lesson,
        display: SubjectDisplay,
        displaySettings: BlockDisplaySettings,
        periods: [Period],
        primaryColor: Color = .primary,
        showsColorCircle: Bool = true,
        isCompact: Bool = false,
        teacherDisplayName: String? = nil,
        originalTeacherDisplayName: String? = nil,
        relativeTo: Date = Date()
    ) {
        self.init(
            lesson: lesson,
            display: display,
            displaySettings: displaySettings,
            periods: periods,
            primaryColor: primaryColor,
            showsColorCircle: showsColorCircle,
            isCompact: isCompact,
            teacherDisplayName: teacherDisplayName,
            originalTeacherDisplayName: originalTeacherDisplayName,
            relativeTo: relativeTo,
            accessory: { EmptyView() }
        )
    }
}
