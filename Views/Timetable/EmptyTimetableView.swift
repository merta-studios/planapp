import SwiftUI

/// Leerer Zustand des Stundenplans mit Schnellzugriff auf Einstellungen und Demo-Modus
public struct EmptyTimetableView: View {
    @EnvironmentObject private var viewModel: TimetableViewModel

    public init() {}

    public var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 54))
                .foregroundColor(.blue)

            Text("Kein Stundenplan hinterlegt")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            Text("Richte deine WebUntis-Zugangsdaten in den Einstellungen ein oder teste die App direkt mit realistischen Beispieldaten.")
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 480)

            HStack(spacing: 16) {
                // Einstellungen öffnen
                Button(action: { viewModel.isSettingsPresented = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "gearshape.fill")
                        Text("WebUntis konfigurieren")
                    }
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(PlainButtonStyle())
                .hoverEffect(.lift)

                // Beispieldaten laden
                Button(action: { viewModel.loadDemoData() }) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                        Text("Beispieldaten laden")
                    }
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color(UIColor.secondarySystemFill))
                    .foregroundColor(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(PlainButtonStyle())
                .hoverEffect(.lift)
            }
            .padding(.top, 8)
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(UIColor.secondarySystemBackground).opacity(0.85))
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
        )
        .frame(maxWidth: 580)
    }
}
