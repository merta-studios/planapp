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
                    Image(systemName: "clock.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                    Text("Std.")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
            .frame(height: headerHeight)

            // Perioden-Zeilen
            ForEach(Array(viewModel.periods.enumerated()), id: \.element.id) { index, period in
                ZStack {
                    // Jede 2. Zeile / Spalte mit grauerer Markierung (ohne harte Tabellenlinien)
                    Rectangle()
                        .fill(
                            index % 2 == 1
                                ? Color(UIColor.systemGray5).opacity(0.45)
                                : Color(UIColor.systemGray6).opacity(0.2)
                        )

                    VStack(spacing: 2) {
                        // Über der Stundennummer klein die Anfangszeit
                        Text(period.startTime)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary)

                        // Stundennummer groß und fett in der Mitte
                        Text("\(period.periodNumber)")
                            .font(.system(size: 20, weight: .heavy, design: .rounded))
                            .foregroundColor(.primary)

                        // Unter der Stundennummer klein die Endzeit
                        Text(period.endTime)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
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
