import SwiftUI

/// Die Kopfzeile einer Notiz: Fach-Farbe als Kreis, Fachname, darunter die im
/// Stundenplan aktivierten Zusatzinfos (Lehrer, Raum, Klasse, Uhrzeiten) und
/// rechts die Stunde samt Datum.
///
/// Wird sowohl über der Zeichenfläche im Bearbeiten-Overlay als auch in der
/// "Nur Notizen"-Übersicht verwendet, damit die Titel dort EXAKT gleich
/// aussehen.
public struct NoteHeaderContent: View {
    public let lesson: Lesson
    public let display: SubjectDisplay
    public let displaySettings: BlockDisplaySettings
    public let periods: [Period]
    /// Grundfarbe der Texte (im Overlay z. B. abhängig vom Ausklapp-Zustand).
    public let primaryColor: Color

    public init(
        lesson: Lesson,
        display: SubjectDisplay,
        displaySettings: BlockDisplaySettings,
        periods: [Period],
        primaryColor: Color = .primary
    ) {
        self.lesson = lesson
        self.display = display
        self.displaySettings = displaySettings
        self.periods = periods
        self.primaryColor = primaryColor
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Farbiger Kreis mit der Fach-Farbe vor dem Fachnamen.
            Circle()
                .fill(
                    LinearGradient(
                        colors: [display.color, display.gradientEndColor ?? display.color],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    Circle().strokeBorder(Color.primary.opacity(0.18), lineWidth: 1)
                )
                .frame(width: 16, height: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(display.name)
                    .font(.system(size: 18, weight: .semibold, design: .default))
                    .strikethrough(lesson.isCancelled, color: .red)
                    .lineLimit(1)

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

        return HStack(spacing: 10) {
            if settings.showTeacher && !lesson.teacherRaw.isEmpty {
                HStack(spacing: 3) {
                    Image(systemName: "person")
                        .font(.system(size: 10, weight: .regular, design: .default))
                    if let orig = lesson.originalTeacher, lesson.isSubstitution {
                        Text(orig)
                            .strikethrough(true, color: .red)
                        Text("➔ \(lesson.teacherRaw)")
                            .strikethrough(lesson.isCancelled, color: .red)
                    } else {
                        Text(lesson.teacherRaw)
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
        .font(.system(size: 12, weight: .regular, design: .default))
        .opacity(0.75)
        .lineLimit(1)
    }

    /// Rechte Kopfzeile: relative Angabe wie "Morgen" oder "Nächste Woche
    /// Montag" plus deutsches Datumsformat (z.B. "01.10.2026").
    private var headerDateText: String {
        guard let date = Date.fromYyyyMMdd(lesson.dateString) else {
            return lesson.dateString
        }
        return "\(date.relativeDayDescription()) • \(date.germanDateString)"
    }
}
