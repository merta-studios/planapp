import SwiftUI

/// Spalte für einen Schultag (Montag - Freitag) mit dynamischen Stunden-Zellen und Block-Darstellung
public struct DayColumnView: View {
    @EnvironmentObject private var viewModel: TimetableViewModel

    public let day: Date
    public let columnIndex: Int
    public let rowHeight: CGFloat
    public let headerHeight: CGFloat
    public let noteNamespace: Namespace.ID

    public init(
        day: Date,
        columnIndex: Int,
        rowHeight: CGFloat,
        headerHeight: CGFloat,
        noteNamespace: Namespace.ID
    ) {
        self.day = day
        self.columnIndex = columnIndex
        self.rowHeight = rowHeight
        self.headerHeight = headerHeight
        self.noteNamespace = noteNamespace
    }

    private var isToday: Bool {
        day.isToday
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
        if isToday {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.blue.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.blue.opacity(0.4), lineWidth: 1)
                )
        } else {
            Rectangle()
                .fill(inactiveHeaderBackgroundColor)
        }
    }

    private var headerLabels: some View {
        VStack(spacing: 3) {
            HStack(spacing: 4) {
                Text(day.weekdayLongString)
                    .font(.system(size: 14, weight: .regular, design: .default))
                    .foregroundColor(isToday ? .blue : .primary)

                if isToday {
                    StatusBadge(.today)
                }
            }

            Text(day.headerDateString)
                .font(.system(size: 12, weight: .regular, design: .default))
                .foregroundColor(isToday ? .blue.opacity(0.85) : .secondary)
        }
        .padding(.vertical, 6)
    }

    // MARK: - Timetable content

    private var timetableContent: some View {
        ZStack(alignment: .topLeading) {
            periodBackground
            todayColumnAccent
            lessonBlocks
            currentTimeIndicator
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

            if isToday {
                Rectangle()
                    .fill(Color.blue.opacity(rowIndex.isMultiple(of: 2) ? 0.10 : 0.14))
            }
        }
    }

    @ViewBuilder
    private var todayColumnAccent: some View {
        if isToday {
            HStack {
                Rectangle()
                    .fill(Color.blue.opacity(0.48))
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
                noteNamespace: noteNamespace
            )
            .padding(.horizontal, 3)
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

    private func currentTimeIndicatorLine(at offsetY: CGFloat) -> some View {
        let verticalLineHeight = max(CGFloat.zero, offsetY)
        let horizontalLineOffset = max(CGFloat.zero, offsetY - 1)
        let dotOffset = max(CGFloat.zero, offsetY - 3.5)

        return ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(Color.red.opacity(0.85))
                .frame(width: 3, height: verticalLineHeight)

            Rectangle()
                .fill(Color.red.opacity(0.9))
                .frame(maxWidth: .infinity, height: 2)
                .offset(y: horizontalLineOffset)

            Circle()
                .fill(Color.red)
                .frame(width: 7, height: 7)
                .offset(x: -2, y: dotOffset)
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
            .fill(isToday ? Color.blue.opacity(0.08) : .clear)
    }

    private var columnBorder: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(
                isToday ? Color.blue.opacity(0.38) : .clear,
                lineWidth: isToday ? 1.25 : 0
            )
    }
}
