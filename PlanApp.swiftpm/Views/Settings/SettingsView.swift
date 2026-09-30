import SwiftUI

/// Haupt-Einstellungsansicht der PlanApp im Liquid-Glass Design
public struct SettingsView: View {
    @EnvironmentObject private var viewModel: TimetableViewModel
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        NavigationView {
            ZStack {
                // Liquid Glass Hintergrund
                Color(UIColor.systemBackground).ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(spacing: 20) {
                        // 1. WebUntis API Konfiguration
                        UntisConfigSection()

                        // 2. Fächer, Farben & Namen
                        SubjectCustomizationSection()

                        // 3. Block-Inhalte anpassen
                        BlockDisplaySettingsSection()

                        // 4. Zeichenfläche & Notizen
                        DrawingSettingsSection()

                        // 5. Stundenraster & Zeiten
                        PeriodConfigSection()

                        // 6. Apple Pencil Pro & Bedienungshinweise
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 8) {
                                Image(systemName: "pencil.and.scribble")
                                    .font(.system(size: 16, weight: .regular, design: .default))
                                    .foregroundColor(.blue)
                                Text("Apple Pencil Pro & Gesten")
                                    .font(.system(size: 15, weight: .regular, design: .default))
                                    .foregroundColor(.primary)
                            }

                            VStack(alignment: .leading, spacing: 12) {
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: "hand.tap")
                                        .font(.system(size: 15, weight: .regular, design: .default))
                                        .foregroundColor(.blue)
                                        .frame(width: 24)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Notizen öffnen")
                                            .font(.system(size: 14, weight: .regular, design: .default))
                                        Text("Tippe auf ein Fach im Stundenplan, um die handschriftliche Zeichenfläche nahtlos zu öffnen.")
                                            .font(.system(size: 12, weight: .regular, design: .default))
                                            .foregroundColor(.secondary)
                                    }
                                }

                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: "pencil.tip")
                                        .font(.system(size: 15, weight: .regular, design: .default))
                                        .foregroundColor(.orange)
                                        .frame(width: 24)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Apple Pencil Stift & Radierer")
                                            .font(.system(size: 14, weight: .regular, design: .default))
                                        Text("In der Zeichenfläche wird nur mit dem Apple Pencil gezeichnet. Der Standard-Radierer entfernt gezeichnete Pixel präzise.")
                                            .font(.system(size: 12, weight: .regular, design: .default))
                                            .foregroundColor(.secondary)
                                    }
                                }

                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: "hand.draw")
                                        .font(.system(size: 15, weight: .regular, design: .default))
                                        .foregroundColor(.green)
                                        .frame(width: 24)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Verschieben & Größe ändern")
                                            .font(.system(size: 14, weight: .regular, design: .default))
                                        Text("Die Zeichenfläche lässt sich mit Fingern flüssig verschieben und über den runden Griff unten vergrößern oder verkleinern. Textfelder: 1× tippen = auswählen & verschieben, 2× tippen = Text bearbeiten. Rückgängig/Wiederholen gilt auch für Textfelder.")
                                            .font(.system(size: 12, weight: .regular, design: .default))
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        .padding(16)
                        .lightCard(cornerRadius: 16, strokeOpacity: 0.25)

                        // 7. Stundenplan leeren (Zurücksetzen)
                        Button(action: {
                            viewModel.clearTimetable()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "trash")
                                    .font(.system(size: 14, weight: .regular, design: .default))
                                Text("Stundenplan leeren")
                                    .font(.system(size: 14, weight: .regular, design: .default))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        }
                        .lightButton(cornerRadius: 14, tint: .red)
                        .foregroundColor(.red)
                        .padding(.bottom, 24)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Text("Fertig")
                            .font(.system(size: 15, weight: .regular, design: .default))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                    }
                    .lightButton(cornerRadius: 10, tint: .blue, isFilled: true)
                    .foregroundColor(.white)
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}
