import SwiftUI

/// Einstellungen für das Erscheinungsbild der App.
///
/// Die Notizflächen sind absichtlich **immer weißes Papier** mit schwarzer
/// Schrift – so wie ein echter Notizblock. Damit ein dunkles System-Design
/// nirgends weiße Schrift auf weißem Papier erzeugen kann, lässt sich das
/// Erscheinungsbild hier festlegen. Standard ist **Hell**.
struct AppearanceSettingsSection: View {
    @EnvironmentObject private var viewModel: TimetableViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "circle.lefthalf.filled")
                    .font(.system(size: 16, weight: .regular, design: .default))
                    .foregroundColor(.blue)
                Text("Erscheinungsbild")
                    .font(.system(size: 15, weight: .regular, design: .default))
                    .foregroundColor(.primary)
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(AppAppearance.allCases) { appearance in
                    Button {
                        Haptics.select()
                        viewModel.setAppearance(appearance)
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: viewModel.appearance == appearance
                                  ? "largecircle.fill.circle"
                                  : "circle")
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(viewModel.appearance == appearance ? .blue : .secondary)

                            Image(systemName: appearance.systemImage)
                                .font(.system(size: 15, weight: .regular))
                                .foregroundColor(.secondary)
                                .frame(width: 20)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(appearance.title)
                                    .font(.system(size: 14, weight: .regular, design: .default))
                                    .foregroundColor(.primary)
                                Text(appearance.detail)
                                    .font(.system(size: 12, weight: .regular, design: .default))
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Spacer(minLength: 0)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(DeviceLayout.settingsInnerPadding)
            .liquidGlassCard(cornerRadius: 14, strokeOpacity: 0.18)

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "pencil.tip")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.orange)
                    .frame(width: 20)
                Text("Das Notizpapier bleibt in jedem Erscheinungsbild weiß – die Schrift darauf bleibt immer schwarz. Nur die Umgebung (Menüs, Werkzeugleisten) folgt dem gewählten Design.")
                    .font(.system(size: 12, weight: .regular, design: .default))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(DeviceLayout.settingsInnerPadding)
            .liquidGlassCard(cornerRadius: 14, strokeOpacity: 0.18)
        }
        .padding(DeviceLayout.settingsOuterPadding)
        .liquidGlassCard(cornerRadius: 16, strokeOpacity: 0.25)
    }
}
