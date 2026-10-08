import SwiftUI

/// Startseite der Einstellungen: nur noch die Kategorien-Übersicht.
///
/// Jede Zeile öffnet eine eigene Seite mit allen Einstellungen dieser
/// Kategorie – dadurch ist die Eingangsliste kurz und übersichtlich.
public struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: TimetableViewModel
    /// Navigationspfad – erlaubt es, die Einstellungen direkt auf einer
    /// bestimmten Seite zu öffnen (z. B. „WebUntis & Sync“ aus dem Guide).
    @State private var path: [SettingsCategory] = []

    public init() {}

    public var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                Color(UIColor.systemBackground).ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: true) {
                    // Bewusst `VStack` statt `LazyVStack`: Eine LazyVStack baut
                    // Zeilen ab, sobald sie aus dem sichtbaren Bereich
                    // scrollen. Wird beim Einblenden einer Tastatur gescrollt,
                    // kann dabei genau das UIKit-Textfeld entfernt werden, das
                    // gerade First Responder ist – die Tastatur klappt wieder
                    // zu bzw. erscheint gar nicht erst.
                    VStack(spacing: DeviceLayout.isPhone ? 10 : 12) {
                        ForEach(SettingsCategory.allCases) { category in
                            NavigationLink(value: category) {
                                SettingsCategoryRow(category: category)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, DeviceLayout.isPhone ? 12 : 20)
                    .padding(.top, 16)
                    .padding(.bottom, 28)
                }
                .scrollDismissesKeyboard(.never)
            }
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Haptics.tap()
                        dismiss()
                    }) {
                        Text("Fertig")
                            .font(.system(size: 15, weight: .regular, design: .default))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                    }
                    .liquidGlassButton(cornerRadius: 10, tint: .blue, isFilled: true)
                    .foregroundColor(.white)
                }
            }
            .navigationDestination(for: SettingsCategory.self) { category in
                SettingsCategoryDetailView(category: category)
            }
        }
        .onAppear(perform: applyLaunchCategoryIfNeeded)
    }

    /// Springt beim Öffnen direkt auf die gewünschte Kategorie, wenn eine
    /// angefragt wurde (z. B. über „Zu den Einstellungen“ aus dem Guide).
    private func applyLaunchCategoryIfNeeded() {
        guard let target = viewModel.settingsLaunchCategory else { return }
        viewModel.settingsLaunchCategory = nil
        path = [target]
    }
}

/// Eine Zeile der Kategorien-Übersicht (Icon, Titel, Untertitel, Pfeil).
private struct SettingsCategoryRow: View {
    let category: SettingsCategory

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: category.icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 30, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(category.tint)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(category.title)
                    .font(.system(size: 15, weight: .medium, design: .default))
                    .foregroundColor(.primary)
                Text(category.subtitle)
                    .font(.system(size: 12, weight: .regular, design: .default))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary.opacity(0.7))
        }
        .padding(DeviceLayout.settingsInnerPadding)
        .liquidGlassCard(cornerRadius: 14, strokeOpacity: 0.18)
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
