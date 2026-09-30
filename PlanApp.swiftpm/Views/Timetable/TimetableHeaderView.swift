import SwiftUI

/// Kopfzeile des Stundenplans mit Wochen-Navigation, Live-Aktualisierungsanzeige und Einstellungs-Button
public struct TimetableHeaderView: View {
    @EnvironmentObject private var viewModel: TimetableViewModel

    public init() {}

    public var body: some View {
        HStack(spacing: 16) {
            // App-Titel & Icon
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .font(.system(size: 20, weight: .regular, design: .default))
                    .foregroundColor(.blue)

                Text("PlanApp")
                    .font(.system(size: 20, weight: .regular, design: .default))
                    .foregroundColor(.primary)
            }

            Spacer()

            // WOCHENANZEIGE
            VStack(spacing: 2) {
                Text(viewModel.selectedWeekStart.calendarWeekString)
                    .font(.system(size: 15, weight: .regular, design: .default))
                    .foregroundColor(.primary)

                Text(viewModel.selectedWeekStart.weekRangeString())
                    .font(.system(size: 12, weight: .regular, design: .default))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .liquidGlassCard(cornerRadius: 14, strokeOpacity: 0.25)

            Spacer()

            // RECHTE LEISTE (Letzte Aktualisierung als kleiner grüner Text & Einstellungen)
            HStack(spacing: 12) {
                // Dynamischer grüner Aktualisierungstext
                TimelineView(.periodic(from: .now, by: 1.0)) { timeline in
                    HStack(spacing: 5) {
                        Circle()
                            .fill(Color(red: 0.15, green: 0.75, blue: 0.35))
                            .frame(width: 6, height: 6)

                        Text(viewModel.relativeLastSyncString(relativeTo: timeline.date))
                            .font(.system(size: 12, weight: .regular, design: .default))
                            .foregroundColor(Color(red: 0.15, green: 0.75, blue: 0.35))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color(red: 0.15, green: 0.75, blue: 0.35).opacity(0.12))
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(Color(red: 0.15, green: 0.75, blue: 0.35).opacity(0.25), lineWidth: 1)
                    )
                }

                // Einstellungs-Button
                Button(action: { viewModel.isSettingsPresented = true }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 16, weight: .regular, design: .default))
                        .foregroundColor(.primary)
                        .frame(width: 38, height: 38)
                }
                .liquidGlassButton(cornerRadius: 19)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }
}
