import SwiftUI

/// Leerer Zustand des Stundenplans mit Schnellzugriff auf Einstellungen und Demo-Modus
public struct EmptyTimetableView: View {
    @EnvironmentObject private var viewModel: TimetableViewModel

    public init() {}

    public var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 48, weight: .regular, design: .default))
                .foregroundColor(.blue)

            Text("Kein Stundenplan hinterlegt")
                .font(.system(size: 20, weight: .regular, design: .default))
                .foregroundColor(.primary)

            Text("Richte deine WebUntis-Zugangsdaten in den Einstellungen ein oder teste die App direkt mit realistischen Beispieldaten.")
                .font(.system(size: 14, weight: .regular, design: .default))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 460)

            HStack(spacing: 14) {
                // Einstellungen öffnen Liquid Glass Button
                Button(action: {
                    Haptics.tap()
                    viewModel.isSettingsPresented = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 14, weight: .regular, design: .default))
                        Text("WebUntis konfigurieren")
                            .font(.system(size: 14, weight: .regular, design: .default))
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                }
                .liquidGlassButton(cornerRadius: 12, tint: .blue, isFilled: true)
                .foregroundColor(.white)

                // Beispieldaten laden Liquid Glass Button
                Button(action: {
                    Haptics.tap()
                    viewModel.loadDemoData()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14, weight: .regular, design: .default))
                        Text("Beispieldaten laden")
                            .font(.system(size: 14, weight: .regular, design: .default))
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                }
                .liquidGlassButton(cornerRadius: 12, tint: .orange)
                .foregroundColor(.orange)
            }
            .padding(.top, 6)
        }
        .padding(28)
        .liquidGlassCard(cornerRadius: 20, strokeOpacity: 0.25)
        .frame(maxWidth: 540)
    }
}
