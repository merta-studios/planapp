import SwiftUI

/// Guide-Fenster für einen noch nicht eingerichteten Stundenplan.
///
/// Statt einer leeren Wochenansicht erklärt die App hier in der Mitte des
/// Bildschirms, dass sich der Stundenplan automatisch von Untis laden lässt,
/// und führt mit einem Tipp direkt zu den API-Einstellungen („WebUntis & Sync“).
public struct UntisSetupGuideView: View {
    @EnvironmentObject private var viewModel: TimetableViewModel

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.blue.opacity(0.14))
                            .frame(width: 52, height: 52)
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 24, weight: .regular, design: .default))
                            .foregroundColor(.blue)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Stundenplan automatisch laden")
                            .font(.system(size: 20, weight: .semibold, design: .default))
                            .foregroundColor(.primary)
                        Text("Dein Stundenplan kann sich automatisch von Untis holen – du musst dafür nur einen Schritt in den Einstellungen erledigen.")
                            .font(.system(size: 14, weight: .regular, design: .default))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    guideStep(
                        number: 1,
                        title: "WebUntis-Zugangsdaten eintragen",
                        text: "Server, Schule, Benutzername und Passwort in „WebUntis & Sync“ ausfüllen."
                    )
                    guideStep(
                        number: 2,
                        title: "Fertig – PlanApp lädt selbst",
                        text: "Danach holt die App deinen Stundenplan vollautomatisch und hält ihn aktuell."
                    )
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(UIColor.tertiarySystemBackground).opacity(0.7))
                )

                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.orange)
                    Text("Noch keine Zugangsdaten oder unvollständige/ungültige Angaben: Deshalb bleibt die Wochenansicht leer, bis der Stundenplan geladen ist.")
                        .font(.system(size: 12, weight: .regular, design: .default))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 12) {
                    Button {
                        Haptics.tap()
                        // Direkt auf die Seite mit den API-Feldern.
                        viewModel.openSettings(category: .untis)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "gearshape")
                                .font(.system(size: 14, weight: .regular, design: .default))
                            Text("Zu den Einstellungen")
                                .font(.system(size: 14, weight: .semibold, design: .default))
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                    }
                    .lightButton(cornerRadius: 12, tint: .blue, isFilled: true)
                    .foregroundColor(.white)
                    .hoverEffect(.lift)

                    Button {
                        Haptics.tap()
                        viewModel.loadDemoData()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 14, weight: .regular, design: .default))
                            Text("Beispieldaten laden")
                                .font(.system(size: 14, weight: .regular, design: .default))
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                    }
                    .lightButton(cornerRadius: 12, tint: .orange)
                    .foregroundColor(.orange)
                    .hoverEffect(.lift)
                }
                .padding(.top, 2)
            }
            .padding(22)
            .frame(maxWidth: 560)
            .lightCard(cornerRadius: 22, strokeOpacity: 0.25)
            .shadow(color: Color.black.opacity(0.08), radius: 16, x: 0, y: 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
        .transition(.opacity.combined(with: .scale(scale: 0.97)))
    }

    private func guideStep(number: Int, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.system(size: 12, weight: .bold, design: .default))
                .foregroundColor(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color.blue))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium, design: .default))
                    .foregroundColor(.primary)
                Text(text)
                    .font(.system(size: 12, weight: .regular, design: .default))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
