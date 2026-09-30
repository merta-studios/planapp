import SwiftUI

/// Haupt-Einstellungsansicht der PlanApp
public struct SettingsView: View {
    @EnvironmentObject private var viewModel: TimetableViewModel
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        NavigationView {
            Form {
                // 1. WebUntis API Konfiguration
                UntisConfigSection()

                // 2. Fächer, Farben & Namen
                SubjectCustomizationSection()

                // 3. Block-Inhalte anpassen
                BlockDisplaySettingsSection()

                // 4. Stundenraster & Zeiten
                PeriodConfigSection()

                // 5. Apple Pencil Pro & Bedienungshinweise
                Section(header: Text("Apple Pencil Pro & Gesten").font(.system(size: 14, weight: .bold))) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "hand.tap.fill")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Notizen öffnen")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Tippe auf ein Fach oder ziehe es mit 2 Fingern auf (Zoom-Geste).")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }

                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "pencil.and.scribble")
                                .foregroundColor(.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Apple Pencil Pro Squeeze")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Drücke den Apple Pencil Pro leicht zusammen (Squeeze), um den letzten Strich sofort rückgängig zu machen.")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }

                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "hand.draw.fill")
                                .foregroundColor(.green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Verschieben & Zoomen")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Im Notizzettel mit 1 Finger verschieben, mit 2 Fingern gleichzeitig zoomen und schwenken.")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }

                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "cursorarrow.rays")
                                .foregroundColor(.purple)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Apple Pencil Hover")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Alle Buttons und Fächer reagieren auf die Schwebegeste des Apple Pencil Pro.")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                // 6. Zurücksetzen
                Section {
                    Button(role: .destructive, action: {
                        viewModel.clearTimetable()
                    }) {
                        HStack {
                            Spacer()
                            Image(systemName: "trash")
                            Text("Stundenplan leeren")
                            Spacer()
                        }
                    }
                    .hoverEffect(.lift)
                }
            }
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fertig") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .bold))
                    .hoverEffect(.lift)
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}
