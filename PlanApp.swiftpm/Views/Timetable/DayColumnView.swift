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

    public var body: some View {
        VStack(spacing: 0) {
            // SPALTENKOPF (Wochentag und Datum)
            ZStack {
                if isToday {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.blue.opacity(0.15))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Color.blue.opacity(0.4), lineWidth: 1.0)
                        )
                } else {
                    Rectangle()
                        .fill(
                            columnIndex % 2 == 1
                                ? Color(UIColor.secondarySystemBackground).opacity(0.6)
                                : Color(UIColor.tertiarySystemBackground).opacity(0.4)
                        )
                }

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
            .frame(height: headerHeight)

            // SPALTENINHALT (Perioden-Zellen ohne Linien mit alternierender Grauschattierung)
            ZStack(alignment: .topLeading) {
                // Hintergrund-Zebra-Muster
                VStack(spacing: 0) {
                    ForEach(0..<viewModel.periods.count, id: \.self) { rowIndex in
                        ZStack {
                            Rectangle()
                                .fill(cellBackgroundColor(column: columnIndex, row: rowIndex))

                            // The complete current-day column receives the blue
                            // tint, while the zebra structure remains visible.
                            if isToday {
                                Rectangle()
                                    .fill(Color.blue.opacity(rowIndex % 2 == 0 ? 0.10 : 0.14))
                            }
                        }
                        .frame(height: rowHeight)
                    }
                }

                // Continuous accent from the header to the last period.
                if isToday {
                    HStack {
                        Rectangle()
                            .fill(Color.blue.opacity(0.48))
                            .frame(width: 3)
                        Spacer()
                    }
                }

                // Unterrichtsstunden / Blöcke
                let dayLessons = viewModel.lessonsFor(day: day)
                ForEach(dayLessons) { lesson in
                    let periodIndex = viewModel.periods.firstIndex(where: { $0.periodNumber == lesson.periodNumber }) ?? (lesson.periodNumber - 1)
                    if periodIndex >= 0 && periodIndex < viewModel.periods.count {
                        let yOffset = CGFloat(periodIndex) * rowHeight + 3
                        let blockH = CGFloat(lesson.durationPeriods) * rowHeight - 6

                        LessonBlockView(
                            lesson: lesson,
                            height: blockH,
                            noteNamespace: noteNamespace
                        )
                        .padding(.horizontal, 3)
                        .offset(y: yOffset)
                    }
                }

                // Rote "Jetzt"-Markierung beim heutigen Tag: ein seitlicher
                // Strich an der linken Kante von oben bis zur aktuellen
                // Uhrzeit plus eine horizontale Linie quer durch die Spalte.
                if isToday {
                    TimelineView(.periodic(from: .now, by: 30)) { timeline in
                        if let nowY = nowIndicatorOffsetY(at: timeline.date) {
                            ZStack(alignment: .topLeading) {
                                // Seitlicher Strich links vom Rand bis zur Uhrzeit.
                                Rectangle()
                                    .fill(Color.red.opacity(0.85))
                                    .frame(width: 3, height: max(0, nowY))

                                // Horizontale Linie quer durch die Spalte auf
                                // Höhe der aktuellen Uhrzeit.
                                Rectangle()
                                    .fill(Color.red.opacity(0.9))
                                    .frame(maxWidth: .infinity, height: 2)
                                    .offset(y: max(0, nowY - 1))

                                // Kleiner Punkt an der linken Ecke als Anker.
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 7, height: 7)
                                    .offset(x: -2, y: max(0, nowY - 3.5))
                            }
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .allowsHitTesting(false)
                        }
                    }
                }
            }
            .frame(height: CGFloat(viewModel.periods.count) * rowHeight)
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isToday ? Color.blue.opacity(0.08) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    isToday ? Color.blue.opacity(0.38) : Color.clear,
                    lineWidth: isToday ? 1.25 : 0
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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

        let totalHeight = CGFloat(viewModel.periods.count) * rowHeight
        let fraction = CGFloat(minutes - start) / CGFloat(end - start)
        return max(0, min(totalHeight, fraction * totalHeight))
    }

    /// Berechnet die Graustufe für das linienlose Tabellenraster
    private func cellBackgroundColor(column: Int, row: Int) -> Color {
        let isColShaded = (column % 2 == 1)
        let isRowShaded = (row % 2 == 1)

        if isColShaded && isRowShaded {
            return Color(UIColor.systemGray5).opacity(0.40)
        } else if isColShaded || isRowShaded {
            return Color(UIColor.systemGray6).opacity(0.30)
        } else {
            return Color(UIColor.systemBackground).opacity(0.15)
        }
    }
}
