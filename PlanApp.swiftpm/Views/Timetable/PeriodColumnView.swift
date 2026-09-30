import SwiftUI

/// Erste Spalte des Stundenplans mit Stundennummer, Anfangs- und Endzeit
public struct PeriodColumnView: View {
    @EnvironmentObject private var viewModel: TimetableViewModel
    public let rowHeight: CGFloat
    public let headerHeight: CGFloat

    public init(rowHeight: CGFloat, headerHeight: CGFloat) {
        self.rowHeight = rowHeight
        self.headerHeight = headerHeight
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Spaltenkopf (Header)
            ZStack {
                Rectangle()
                    .fill(Color(UIColor.secondarySystemBackground).opacity(0.8))

                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 13, weight: .regular, design: .default))
                        .foregroundColor(.secondary)
                    Text("Std.")
                        .font(.system(size: 13, weight: .regular, design: .default))
                        .foregroundColor(.secondary)
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
                .frame(height: rowHeight)
            }
        }
        .frame(width: 76)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
