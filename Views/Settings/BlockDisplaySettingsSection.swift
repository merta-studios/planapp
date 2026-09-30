import SwiftUI

/// Einstellungsbereich für die im Stunden-Block sichtbaren Elemente
public struct BlockDisplaySettingsSection: View {
    @EnvironmentObject private var viewModel: TimetableViewModel

    public init() {}

    public var body: some View {
        Section(header: Text("Stunden-Block Inhalte anpassen").font(.system(size: 14, weight: .bold))) {
            VStack(alignment: .leading, spacing: 12) {
                // Fester Standard-Eintrag
                HStack {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Fachname (Fett)")
                            .font(.system(size: 15, weight: .bold))
                        Text("Standard-Element – bleibt immer sichtbar und fest verankert.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: "checkmark.circle.fill")
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
                            .foregroundColor(.blue)
                        Text("Lehrer anzeigen")
                            .font(.system(size: 15, weight: .medium))
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
                            .foregroundColor(.purple)
                        Text("Raum anzeigen")
                            .font(.system(size: 15, weight: .medium))
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
                            .foregroundColor(.orange)
                        Text("Handschriftliche Notizen-Vorschau anzeigen")
                            .font(.system(size: 15, weight: .medium))
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
                            .foregroundColor(.yellow)
                        Text("Vertretungs-Details & Gründe anzeigen")
                            .font(.system(size: 15, weight: .medium))
                    }
                }

                Toggle(isOn: Binding(
                    get: { viewModel.displaySettings.showTimes },
                    set: { val in
                        viewModel.displaySettings.showTimes = val
                        viewModel.saveDisplaySettings()
                    }
                )) {
                    HStack(spacing: 8) {
                        Image(systemName: "clock")
                            .foregroundColor(.teal)
                        Text("Uhrzeiten direkt im Block anzeigen")
                            .font(.system(size: 15, weight: .medium))
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
}
