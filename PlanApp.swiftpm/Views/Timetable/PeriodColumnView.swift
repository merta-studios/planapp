import SwiftUI

/// Erste Spalte des Stundenplans mit Stundennummer, Anfangs- und Endzeit
public struct PeriodColumnView: View {
    @EnvironmentObject private var viewModel: TimetableViewModel
    public let rowHeight: CGFloat
    public let headerHeight: CGFloat
    public let width: CGFloat
    /// Kompakt (iPhone): nur Stundennummer und Beginn, kleinere Schrift.
    public let isCompact: Bool

    public init(rowHeight: CGFloat, headerHeight: CGFloat, width: CGFloat = 76, isCompact: Bool = false) {
        self.rowHeight = rowHeight
        self.headerHeight = headerHeight
        self.width = width
        self.isCompact = isCompact
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Spaltenkopf (Header)
            ZStack {
                Rectangle()
                    .fill(Color(UIColor.secondarySystemBackground).opacity(0.8))

                if isCompact {
                    Image(systemName: "clock")
                        .font(.system(size: 10, weight: .regular, design: .default))
                        .foregroundColor(.secondary)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 13, weight: .regular, design: .default))
                            .foregroundColor(.secondary)
                        Text("Std.")
                            .font(.system(size: 13, weight: .regular, design: .default))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(height: headerHeight)

            // Perioden-Zeilen
            ForEach(Array(viewModel.periods.enumerated()), id: \.element.id) { index, period in
                ZStack {
                    Rectangle()
                        .fill(
                            index % 2 == 1
                                ? Color(UIColor.systemGray5).opacity(0.45)
                                : Color(UIColor.systemGray6).opacity(0.2)
                        )

                    if isCompact {
                        VStack(spacing: 0) {
                            Text("\(period.periodNumber)")
                                .font(.system(size: 12, weight: .semibold, design: .default))
                                .foregroundColor(.primary)
                            Text(period.startTime)
                                .font(.system(size: 7, weight: .regular, design: .default))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .padding(.vertical, 1)
                    } else {
                        VStack(spacing: 2) {
                            Text(period.startTime)
                                .font(.system(size: 11, weight: .regular, design: .default))
                                .foregroundColor(.secondary)

                            Text("\(period.periodNumber)")
                                .font(.system(size: 18, weight: .regular, design: .default))
                                .foregroundColor(.primary)

                            Text(period.endTime)
                                .font(.system(size: 11, weight: .regular, design: .default))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .frame(height: rowHeight)
            }
        }
        .frame(width: width)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
