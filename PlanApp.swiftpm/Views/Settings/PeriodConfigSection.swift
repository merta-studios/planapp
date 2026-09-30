import SwiftUI

/// Einstellungsbereich für das Stundenraster (Zeilen und Unterrichtszeiten)
public struct PeriodConfigSection: View {
    @EnvironmentObject private var viewModel: TimetableViewModel

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Abschnittsüberschrift
            HStack(spacing: 8) {
                Image(systemName: "clock")
                    .font(.system(size: 16, weight: .regular, design: .default))
                    .foregroundColor(.blue)
                Text("Stundenraster & Zeiten")
                    .font(.system(size: 15, weight: .regular, design: .default))
                    .foregroundColor(.primary)
            }

            Text("Das Stundenraster definiert die Zeilen des Stundenplans. Bei der Untis-Synchronisation wird das Raster automatisch von deiner Schule abgerufen.")
                .font(.system(size: 13, weight: .regular, design: .default))
                .foregroundColor(.secondary)

            // Perioden-Liste
            VStack(spacing: 8) {
                ForEach(viewModel.periods) { period in
                    HStack {
                        Text("\(period.periodNumber). Stunde")
                            .font(.system(size: 14, weight: .regular, design: .default))
                            .frame(width: 90, alignment: .leading)

                        Spacer()

                        Text("\(period.startTime) – \(period.endTime)")
                            .font(.system(size: 13, weight: .regular, design: .default))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .lightCard(cornerRadius: 10, strokeOpacity: 0.15)
                }
            }

            Divider()
                .padding(.vertical, 2)

            // Erneut von meiner Schule laden Button
            Button(action: {
                Task {
                    if viewModel.untisCredentials.isConfigured {
                        await viewModel.syncWithUntis()
                    } else {
                        viewModel.periods = Period.defaultPeriods
                        viewModel.savePeriods()
                        viewModel.successMessage = "Standard-Raster geladen. Für das Schulraster bitte WebUntis-Daten konfigurieren."
                    }
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .regular, design: .default))
                    Text("Erneut von meiner Schule laden")
                        .font(.system(size: 14, weight: .regular, design: .default))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .lightButton(cornerRadius: 10, tint: .blue)
            .foregroundColor(.blue)
        }
        .padding(16)
        .lightCard(cornerRadius: 16, strokeOpacity: 0.25)
    }
}
