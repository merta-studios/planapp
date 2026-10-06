import SwiftUI

/// Spalte für einen Schultag (Montag - Freitag) mit dynamischen Stunden-Zellen und Block-Darstellung
public struct DayColumnView: View {
    @EnvironmentObject private var viewModel: TimetableViewModel

    public let day: Date
    public let columnIndex: Int
    public let rowHeight: CGFloat
    public let headerHeight: CGFloat
    /// Kompakt (iPhone): kurze Wochentagsnamen, kleinere Blöcke.
    public let isCompact: Bool
    public let noteNamespace: Namespace.ID

    public init(
        day: Date,
        columnIndex: Int,
        rowHeight: CGFloat,
        headerHeight: CGFloat,
        isCompact: Bool = false,
        noteNamespace: Namespace.ID
    ) {
        self.day = day
        self.columnIndex = columnIndex
        self.rowHeight = rowHeight
        self.headerHeight = headerHeight
        self.isCompact = isCompact
        self.noteNamespace = noteNamespace
    }

    private var isToday: Bool {
        day.isToday
    }

    /// Montag der kommenden Schulwoche, wenn die laufende Woche schon vorbei
    /// ist (Wochenende bzw. Freitag nach der letzten Stunde). Dieser Tag wird
    /// wie „heute“ hervorgehoben – aber bewusst in **hellem Gelb**, damit die
    /// kommende Woche sofort ins Auge fällt.
    private var isUpcomingWeekDay: Bool {
        guard !isToday else { return false }
        guard let highlight = viewModel.upcomingWeekHighlightDay() else { return false }
        return day.isSameDay(as: highlight)
    }

    /// Hervorgehobener Tag der Spalte (heute oder kommender Schultag).
    private var isHighlightedDay: Bool { isToday || isUpcomingWeekDay }

    /// Hervorhebungsfarbe der Spalte. Heute = Blau, kommende Woche = helles
    /// Gelb.
    private var highlightColor: Color {
        isToday ? .blue : Color(red: 0.98, green: 0.84, blue: 0.30)
    }

    /// Schrift-/Akzentfarbe für den Kopf der kommenden Woche: dunkles Amber,
    /// damit sie auf hellem Gelb gut lesbar bleibt.
    private var upcomingWeekTextColor: Color {
        Color(red: 0.62, green: 0.47, blue: 0.03)
    }

    private var highlightTextColor: Color {
        isToday ? .blue : upcomingWeekTextColor
    }

    private var timetableHeight: CGFloat {
        CGFloat(viewModel.periods.count) * rowHeight
    }

    private var inactiveHeaderBackgroundColor: Color {
        columnIndex % 2 == 1
            ? Color(UIColor.secondarySystemBackground).opacity(0.6)
            : Color(UIColor.tertiarySystemBackground).opacity(0.4)
    }

    public var body: some View {
        VStack(spacing: 0) {
            dayHeader
            timetableContent
                .frame(height: timetableHeight)
        }
        .background(columnBackground)
        .overlay(columnBorder)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Header

    private var dayHeader: some View {
        ZStack {
            headerBackground
            headerLabels
        }
        .frame(height: headerHeight)
    }

    @ViewBuilder
    private var headerBackground: some View {
        if isHighlightedDay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(highlightColor.opacity(isToday ? 0.15 : 0.22))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(highlightColor.opacity(isToday ? 0.4 : 0.6), lineWidth: 1)
                )
        } else {
            Rectangle()
                .fill(inactiveHeaderBackgroundColor)
        }
    }

    private var headerLabels: some View {
        VStack(spacing: isCompact ? 1 : 3) {
            HStack(spacing: 4) {
                Text(isCompact ? String(day.weekdayLongString.prefix(2)) : day.weekdayLongString)
                    .font(.system(size: isCompact ? 12 : 14, weight: isCompact && isHighlightedDay ? .semibold : .regular, design: .default))
                    .foregroundColor(isHighlightedDay ? highlightTextColor : .primary)

                if isHighlightedDay, !isCompact {
                    if isToday {
                        StatusBadge(.today)
                    } else {
                        StatusBadge(.upcomingWeek)
                    }
                }
            }

            Text(isCompact ? day.compactHeaderDateString : day.headerDateString)
                .font(.system(size: isCompact ? 9 : 12, weight: .regular, design: .default))
                .foregroundColor(isHighlightedDay ? highlightTextColor.opacity(0.85) : .secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.vertical, isCompact ? 3 : 6)
    }

    // MARK: - Timetable content

    private var timetableContent: some View {
        ZStack(alignment: .topLeading) {
            periodBackground
            todayColumnAccent
            lessonBlocks
            freeDayPlaceholder
            currentTimeIndicator
        }
    }

    /// Freier Tag (keine einzige Stunde): In der Spalte steht ein um 90°
    /// gedrehter, grauer Hinweis „Kein Unterricht“.
    ///
    /// Während eine Woche gerade zum ersten Mal geladen wird, bleibt der
    /// Hinweis ausgeblendet – dort dreht sich stattdessen das Lade-Symbol.
    @ViewBuilder
    private var freeDayPlaceholder: some View {
        if viewModel.lessonsFor(day: day).isEmpty,
           !viewModel.isWeekPendingInitialLoad(day.startOfWeek()) {
            Text("Kein Unterricht")
                .font(.system(size: isCompact ? 11 : 15, weight: .semibold, design: .default))
                .foregroundColor(Color(UIColor.systemGray))
                .fixedSize()
                .rotationEffect(.degrees(-90))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)
                .accessibilityLabel("Kein Unterricht")
        }
    }

    private var periodBackground: some View {
        VStack(spacing: 0) {
            ForEach(viewModel.periods.indices, id: \.self) { rowIndex in
                periodBackgroundCell(for: rowIndex)
                    .frame(height: rowHeight)
            }
        }
    }

    private func periodBackgroundCell(for rowIndex: Int) -> some View {
        ZStack {
            Rectangle()
                .fill(cellBackgroundColor(column: columnIndex, row: rowIndex))

            if isHighlightedDay {
                Rectangle()
                    .fill(
                        highlightColor.opacity(
                            isToday
                                ? (rowIndex.isMultiple(of: 2) ? 0.10 : 0.14)
                                : (rowIndex.isMultiple(of: 2) ? 0.10 : 0.16)
                        )
                    )
            }
        }
    }

    @ViewBuilder
    private var todayColumnAccent: some View {
        if isHighlightedDay {
            HStack {
                Rectangle()
                    .fill(highlightColor.opacity(isToday ? 0.48 : 0.75))
                    .frame(width: 3)
                Spacer()
            }
        }
    }

    private var lessonBlocks: some View {
        ForEach(viewModel.lessonsFor(day: day)) { lesson in
            lessonBlock(for: lesson)
        }
    }

    @ViewBuilder
    private func lessonBlock(for lesson: Lesson) -> some View {
        if let periodIndex = periodIndex(for: lesson) {
            let yOffset = CGFloat(periodIndex) * rowHeight + 3
            let blockHeight = CGFloat(lesson.durationPeriods) * rowHeight - 6

            LessonBlockView(
                lesson: lesson,
                blockHeight: blockHeight,
                noteNamespace: noteNamespace,
                isCompact: isCompact
            )
            .padding(.horizontal, isCompact ? 1.5 : 3)
            .offset(y: yOffset)
        }
    }

    private func periodIndex(for lesson: Lesson) -> Int? {
        let index = viewModel.periods.firstIndex {
            $0.periodNumber == lesson.periodNumber
        } ?? lesson.periodNumber - 1

        return viewModel.periods.indices.contains(index) ? index : nil
    }

    // MARK: - Current-time indicator

    @ViewBuilder
    private var currentTimeIndicator: some View {
        if isToday {
            TimelineView(.periodic(from: .now, by: 30)) { timeline in
                currentTimeIndicator(at: timeline.date)
            }
        }
    }

    @ViewBuilder
    private func currentTimeIndicator(at date: Date) -> some View {
        if let offsetY = nowIndicatorOffsetY(at: date) {
            currentTimeIndicatorLine(at: offsetY)
        }
    }

    /// „Jetzt“-Markierung: bewusst nur eine **waagerechte** Linie mit Punkt.
    ///
    /// Der frühere senkrechte rote Balken lief vom Spaltenkopf bis zur
    /// aktuellen Uhrzeit und lag direkt neben dem blauen (bzw. gelben)
    /// Tagesbalken am linken Rand – das sah wie ein roter „Strich bis zur
    /// Seitenkante“ aus. Die Uhrzeit lässt sich an der waagerechten Linie
    /// genauso gut ablesen.
    private func currentTimeIndicatorLine(at offsetY: CGFloat) -> some View {
        let horizontalLineOffset = max(CGFloat.zero, offsetY - 1)
        let dotOffset = max(CGFloat.zero, offsetY - 3.5)

        return ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(Color.red.opacity(0.9))
                .frame(height: 2)
                .frame(maxWidth: .infinity)
                .offset(y: horizontalLineOffset)

            Circle()
                .fill(Color.red)
                .frame(width: 7, height: 7)
                .offset(x: 1, y: dotOffset)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .allowsHitTesting(false)
    }

    /// Y-Position der aktuellen Uhrzeit im Stundenraster (nil außerhalb der
    /// unterrichteten Zeit). Linear zwischen dem Beginn der ersten und dem
    /// Ende der letzten Stunde gemappt.
    private func nowIndicatorOffsetY(at date: Date) -> CGFloat? {
        let sortedPeriods = viewModel.periods.sorted { $0.periodNumber < $1.periodNumber }
        guard let first = sortedPeriods.first, let last = sortedPeriods.last else { return nil }

        let components = Calendar.current.dateComponents([.hour, .minute, .second], from: date)
        let minutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)

        let start = first.startMinutes
        let end = last.endMinutes
        guard end > start, minutes >= start, minutes <= end else { return nil }

        let fraction = CGFloat(minutes - start) / CGFloat(end - start)
        return max(.zero, min(timetableHeight, fraction * timetableHeight))
    }

    /// Berechnet die Graustufe für das linienlose Tabellenraster.
    private func cellBackgroundColor(column: Int, row: Int) -> Color {
        let isColumnShaded = column.isMultiple(of: 2) == false
        let isRowShaded = row.isMultiple(of: 2) == false

        switch (isColumnShaded, isRowShaded) {
        case (true, true):
            return Color(UIColor.systemGray5).opacity(0.40)
        case (true, false), (false, true):
            return Color(UIColor.systemGray6).opacity(0.30)
        case (false, false):
            return Color(UIColor.systemBackground).opacity(0.15)
        }
    }

    private var columnBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(
                isToday
                    ? Color.blue.opacity(0.08)
                    : (isUpcomingWeekDay ? highlightColor.opacity(0.10) : .clear)
            )
    }

    private var columnBorder: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(
                isToday
                    ? Color.blue.opacity(0.38)
                    : (isUpcomingWeekDay ? highlightColor.opacity(0.55) : .clear),
                lineWidth: isHighlightedDay ? 1.25 : 0
            )
    }
}
