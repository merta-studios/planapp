import SwiftUI

/// Einstellungsbereich für die im Stunden-Block sichtbaren Elemente
public struct BlockDisplaySettingsSection: View {
    @EnvironmentObject private var viewModel: TimetableViewModel

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Abschnittsüberschrift
            HStack(spacing: 8) {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 16, weight: .regular, design: .default))
                    .foregroundColor(.blue)
                Text("Stunden-Block Inhalte anpassen")
                    .font(.system(size: 15, weight: .regular, design: .default))
                    .foregroundColor(.primary)
            }

            VStack(alignment: .leading, spacing: 12) {
                // Fester Standard-Eintrag
                HStack {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 13, weight: .regular, design: .default))
                        .foregroundColor(.secondary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Fachname")
                            .font(.system(size: 14, weight: .regular, design: .default))
                        Text("Standard-Element – bleibt immer sichtbar.")
                            .font(.system(size: 12, weight: .regular, design: .default))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 15, weight: .regular, design: .default))
                        .foregroundColor(.green)
                }
                .padding(.vertical, 4)

                Divider()

                // Anpassbare Zusatzelemente
                Toggle(isOn: Binding(
                    get: { viewModel.displaySettings.showTeacher },
                    set: { val in
                        viewModel.displaySettings.showTeacher = val
                        viewModel.saveDisplaySettings()
                    }
                )) {
                    HStack(spacing: 8) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 14, weight: .regular, design: .default))
                            .foregroundColor(.blue)
                        Text("Lehrer anzeigen")
                            .font(.system(size: 14, weight: .regular, design: .default))
                    }
                }

                Toggle(isOn: Binding(
                    get: { viewModel.displaySettings.showRoom },
                    set: { val in
                        viewModel.displaySettings.showRoom = val
                        viewModel.saveDisplaySettings()
                    }
                )) {
                    HStack(spacing: 8) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 14, weight: .regular, design: .default))
                            .foregroundColor(.purple)
                        Text("Raum anzeigen")
                            .font(.system(size: 14, weight: .regular, design: .default))
                    }
                }

                Toggle(isOn: Binding(
                    get: { viewModel.displaySettings.showNotesPreview },
                    set: { val in
                        viewModel.displaySettings.showNotesPreview = val
                        viewModel.saveDisplaySettings()
                    }
                )) {
                    HStack(spacing: 8) {
                        Image(systemName: "pencil.line")
                            .font(.system(size: 14, weight: .regular, design: .default))
                            .foregroundColor(.orange)
                        Text("Handschriftliche Notizen-Vorschau anzeigen")
                            .font(.system(size: 14, weight: .regular, design: .default))
                    }
                }

                Toggle(isOn: Binding(
                    get: { viewModel.displaySettings.showSubstitutionDetails },
                    set: { val in
                        viewModel.displaySettings.showSubstitutionDetails = val
                        viewModel.saveDisplaySettings()
                    }
                )) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 14, weight: .regular, design: .default))
                            .foregroundColor(.yellow)
                        Text("Vertretungs-Details & Gründe anzeigen")
                            .font(.system(size: 14, weight: .regular, design: .default))
                    }
                }

                Toggle(isOn: Binding(
                    get: { viewModel.displaySettings.showTags },
                    set: { val in
                        viewModel.displaySettings.showTags = val
                        viewModel.saveDisplaySettings()
                    }
                )) {
                    HStack(spacing: 8) {
                        Image(systemName: "tag")
                            .font(.system(size: 14, weight: .regular, design: .default))
                            .foregroundColor(.indigo)
                        Text("Tags anzeigen")
                            .font(.system(size: 14, weight: .regular, design: .default))
                    }
                }

                Text("Standardmäßig an. Zeigt den Tag einer Notiz im Stunden-Block und in den Notiz-Karten an.")
                    .font(.system(size: 12, weight: .regular, design: .default))
                    .foregroundColor(.secondary)
                    .padding(.leading, 4)
            }
        }
        .padding(DeviceLayout.settingsOuterPadding)
        .lightCard(cornerRadius: 16, strokeOpacity: 0.25)
    }
}
