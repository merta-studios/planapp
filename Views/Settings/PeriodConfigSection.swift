import SwiftUI

/// Einstellungsbereich für das Stundenraster (Zeilen und Unterrichtszeiten)
public struct PeriodConfigSection: View {
    @EnvironmentObject private var viewModel: TimetableViewModel

    @State private var newPeriodStart: String = ""
    @State private var newPeriodEnd: String = ""

    public init() {}

    public var body: some View {
        Section(header: Text("Stundenraster & Zeilen").font(.system(size: 14, weight: .bold))) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Das Stundenraster definiert die Zeilen des Stundenplans. Bei der Untis-Synchronisation wird das Raster automatisch von deiner Schule abgerufen.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)

                // Perioden-Liste
                ForEach(viewModel.periods) { period in
                    HStack {
                        Text("\(period.periodNumber). Stunde")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .frame(width: 90, alignment: .leading)

                        Spacer()

                        Text("\(period.startTime) – \(period.endTime)")
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 2)
                }

                Divider()

                // Standardraster wiederherstellen
                Button(action: {
                    withAnimation {
                        viewModel.periods = Period.defaultPeriods
                        viewModel.savePeriods()
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Standardraster (1.–10. Stunde) wiederherstellen")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.blue)
                }
                .hoverEffect(.lift)
            }
            .padding(.vertical, 4)
        }
    }
}
