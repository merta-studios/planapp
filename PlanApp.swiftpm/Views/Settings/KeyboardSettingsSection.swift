import SwiftUI
import UIKit

/// Einstellungen und Diagnose rund um die Texteingabe.
///
/// Die App bringt eine eigene Bildschirmtastatur mit, weil iPadOS in Apps,
/// die in Swift Playgrounds laufen, häufig weder die Systemtastatur noch
/// Tastenereignisse an die App weitergibt (bekannter Apple-Fehler seit
/// iPadOS 16.1, siehe `TextInputHub`). Diese Seite macht sichtbar, was
/// gerade erkannt wird – damit ist sofort klar, ob die Eingabe ankommt.
struct KeyboardSettingsSection: View {
    @ObservedObject private var hub = TextInputHub.shared
    @ObservedObject private var preferences = AppKeyboardPreferences.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            modeCard
            feedbackCard
            statusCard
            helpCard
        }
        .padding(16)
        .lightCard(cornerRadius: 16, strokeOpacity: 0.25)
    }

    // MARK: - Kopf

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "keyboard")
                .font(.system(size: 16, weight: .regular, design: .default))
                .foregroundColor(.blue)
            Text("Tastatur & Eingabe")
                .font(.system(size: 15, weight: .regular, design: .default))
                .foregroundColor(.primary)
        }
    }

    // MARK: - Verhalten

    private var modeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("App-Tastatur")
                .font(.system(size: 14, weight: .medium, design: .default))
                .foregroundColor(.primary)

            ForEach(AppKeyboardMode.allCases) { mode in
                Button {
                    Haptics.select()
                    preferences.mode = mode
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: preferences.mode == mode ? "largecircle.fill.circle" : "circle")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(preferences.mode == mode ? .blue : .secondary)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(mode.title)
                                .font(.system(size: 14, weight: .regular, design: .default))
                                .foregroundColor(.primary)
                            Text(mode.detail)
                                .font(.system(size: 12, weight: .regular, design: .default))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .multilineTextAlignment(.leading)
                        }

                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Button {
                Haptics.tap()
                hub.showAppKeyboard()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "keyboard.badge.eye")
                        .font(.system(size: 14, weight: .regular))
                    Text("App-Tastatur jetzt einblenden")
                        .font(.system(size: 14, weight: .regular, design: .default))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .lightButton(cornerRadius: 10, tint: .blue)
            .foregroundColor(.blue)
            .padding(.top, 2)
        }
        .padding(14)
        .lightCard(cornerRadius: 14, strokeOpacity: 0.18)
    }

    // MARK: - Feedback

    /// Feedback beim Tippen – nach dem Vorbild der Apple-Tastatur.
    private var feedbackCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Feedback beim Tippen")
                .font(.system(size: 14, weight: .medium, design: .default))
                .foregroundColor(.primary)

            Toggle(isOn: Binding(
                get: { preferences.feedbackEnabled },
                set: { newValue in
                    preferences.feedbackEnabled = newValue
                    // Beim Einschalten einmal vorspielen, damit sofort klar ist,
                    // wie sich das Feedback anhört.
                    if newValue { KeyboardFeedback.preview() }
                }
            )) {
                HStack(spacing: 8) {
                    Image(systemName: "hand.tap")
                        .font(.system(size: 14, weight: .regular, design: .default))
                        .foregroundColor(.blue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Klang & Haptik")
                            .font(.system(size: 14, weight: .regular, design: .default))
                        Text("Bei jedem Tastendruck ein leises Klickgeräusch wie bei Apples Tastatur und eine feine Haptik (auf dem iPhone spürbar). Das iPad hat keinen Taptic Engine – dort ist der Klang das Feedback.")
                            .font(.system(size: 12, weight: .regular, design: .default))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            Button {
                KeyboardFeedback.preview()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "speaker.wave.2")
                        .font(.system(size: 14, weight: .regular, design: .default))
                    Text("Feedback ausprobieren")
                        .font(.system(size: 14, weight: .regular, design: .default))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .lightButton(cornerRadius: 10, tint: .blue)
            .foregroundColor(.blue)
            .padding(.top, 2)
        }
        .padding(14)
        .lightCard(cornerRadius: 14, strokeOpacity: 0.18)
    }

    // MARK: - Diagnose

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Status (live)")
                .font(.system(size: 14, weight: .medium, design: .default))
                .foregroundColor(.primary)

            statusRow(
                "iPadOS-Systemtastatur",
                hub.isSystemKeyboardVisible ? "sichtbar" : "nicht sichtbar",
                color: hub.isSystemKeyboardVisible ? .green : .orange
            )
            statusRow(
                "App-Tastatur",
                hub.isAppKeyboardVisible ? "eingeblendet" : "ausgeblendet",
                color: hub.isAppKeyboardVisible ? .green : .secondary
            )
            statusRow(
                "Textfeld erkannt",
                hub.hasActiveInput ? "ja (\(hub.activeInputKind))" : "nein",
                color: hub.hasActiveInput ? .green : .secondary
            )
            statusRow(
                "Hardware-Tastatur",
                hub.hasHardwareKeyboard ? "erkannt" : "keine",
                color: .secondary
            )
            statusRow(
                "App-Fenster ist Key-Window",
                hub.isWindowKey ? "ja" : "nein",
                color: hub.isWindowKey ? .secondary : .orange
            )
            if hub.didRepairKeyWindow {
                statusRow("Key-Window korrigiert", "ja (einmalig)", color: .orange)
            }
            statusRow("Letztes Ereignis", hub.lastEventText, color: .secondary)

            Text("Tipp: Diese Werte aktualisieren sich, während du ein Textfeld benutzt. Bleibt „Systemtastatur“ auf „nicht sichtbar“, während du tippst, ist genau der bekannte Playgrounds-Fehler aktiv – die App-Tastatur übernimmt dann automatisch.")
                .font(.system(size: 11, weight: .regular, design: .default))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .lightCard(cornerRadius: 14, strokeOpacity: 0.18)
    }

    private func statusRow(_ title: String, _ value: String, color: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .regular, design: .default))
                .foregroundColor(.primary)
            Spacer(minLength: 8)
            Text(value)
                .font(.system(size: 12, weight: .regular, design: .default))
                .foregroundColor(color)
                .multilineTextAlignment(.trailing)
        }
    }

    // MARK: - Hilfe

    private var helpCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.orange)
                Text("Warum ist das nötig?")
                    .font(.system(size: 14, weight: .medium, design: .default))
            }

            Text("In Apps, die in Swift Playgrounds auf dem iPad laufen, zeigt iPadOS oft keine Bildschirmtastatur an und leitet auch keine Tasten einer Hardware-Tastatur an die App weiter – der Cursor blinkt, aber es lässt sich nur einsetzen. Das ist ein seit iPadOS 16.1 gemeldeter Fehler von Apple (Developer Forums, Thread 715614) und kann von der App allein nicht behoben werden.\n\nDeshalb tippen die Textfelder dieser App auf Wunsch über eine eigene Tastatur direkt ins Feld. Sie funktioniert immer, weil sie nur Tipps braucht.")
                .font(.system(size: 12, weight: .regular, design: .default))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Wenn zusätzlich die Systemtastatur erscheinen soll: Hardware-Tastatur abtrennen, Swift Playgrounds komplett schließen und mit abgetrennter Tastatur neu öffnen. Hilfreich sein kann auch „Einstellungen → Bedienungshilfen → Tippen → AssistiveTouch → Bildschirmtastatur einblenden“.")
                .font(.system(size: 12, weight: .regular, design: .default))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .lightCard(cornerRadius: 14, strokeOpacity: 0.18)
    }
}
