import SwiftUI

/// Spalte für einen Schultag (Montag - Freitag) mit dynamischen Stunden-Zellen und Block-Darstellung
public struct DayColumnView: View {
    @EnvironmentObject private var viewModel: TimetableViewModel

    public let day: Date
    public let columnIndex: Int // 1 für Mo, 2 für Di, 3 für Mi, 4 für Do, 5 für Fr
    public let rowHeight: CGFloat
    public let headerHeight: CGFloat

    public init(day: Date, columnIndex: Int, rowHeight: CGFloat, headerHeight: CGFloat) {
        self.day = day
        self.columnIndex = columnIndex
        self.rowHeight = rowHeight
        self.headerHeight = headerHeight
    }

    private var isToday: Bool {
        day.isToday
    }

    public var body: some View {
        VStack(spacing: 0) {
            // SPALTENKOPF (Wochentag und Datum)
            ZStack {
                // Hintergrund des Headers
                if isToday {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.blue.opacity(0.15))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Color.blue.opacity(0.5), lineWidth: 1.5)
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
                            .font(.system(size: 15, weight: isToday ? .heavy : .bold, design: .rounded))
                            .foregroundColor(isToday ? .blue : .primary)

                        if isToday {
                            StatusBadge(.today)
                        }
                    }

                    Text(day.headerDateString)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
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
                        Rectangle()
                            .fill(cellBackgroundColor(column: columnIndex, row: rowIndex))
                            .frame(height: rowHeight)
                    }
                }

                // Heutiger Tag: feiner vertikaler Akzentstreifen links
                if isToday {
                    HStack {
                        Rectangle()
                            .fill(Color.blue.opacity(0.35))
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

                        LessonBlockView(lesson: lesson, height: blockH)
                            .padding(.horizontal, 3)
                            .offset(y: yOffset)
                    }
                }
            }
            .frame(height: CGFloat(viewModel.periods.count) * rowHeight)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    /// Berechnet die Graustufe für das linienlose Tabellenraster
    private func cellBackgroundColor(column: Int, row: Int) -> Color {
        // Jede 2. Spalte und jede 2. Zeile erhalten eine grauere Markierung
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
