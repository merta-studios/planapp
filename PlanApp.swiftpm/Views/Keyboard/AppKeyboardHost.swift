import SwiftUI
import UIKit

/// Hängt die app-eigene Tastatur unten an eine Ansicht an.
///
/// Die Tastatur ist Teil der normalen Ansichts-Hierarchie (`safeAreaInset`)
/// und wird deshalb auch von Sheets und Vollbild-Overlays korrekt angezeigt.
struct AppKeyboardHostModifier: ViewModifier {
    @ObservedObject private var hub = TextInputHub.shared

    /// Ob zusätzlich jeder Tipp im Fenster beobachtet wird (Sicherheitsnetz für
    /// Felder, die keine Bearbeitungs-Benachrichtigung senden). Auf der
    /// Zeichenfläche bleibt das aus, damit die PencilKit-Eingabe völlig
    /// unberührt bleibt.
    let monitorsTaps: Bool

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if hub.isAppKeyboardVisible {
                    AppKeyboardView()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .background(
                Group {
                    if monitorsTaps {
                        WindowTapObserver()
                            .frame(width: 0, height: 0)
                            .allowsHitTesting(false)
                    }
                }
            )
            .onAppear { hub.keyboardHostDidAppear() }
            .onDisappear { hub.keyboardHostDidDisappear() }
    }
}

extension View {
    /// Blendet bei Bedarf die app-eigene Bildschirmtastatur ein.
    ///
    /// Muss auf jeder Ansicht liegen, die Textfelder enthält (bzw. darüber),
    /// z. B. auf der Einstellungen-Navigation und der Zeichenfläche.
    func appKeyboardHost(monitorsTaps: Bool = true) -> some View {
        modifier(AppKeyboardHostModifier(monitorsTaps: monitorsTaps))
    }
}

/// Unsichtbare Hilfsansicht, die jeden Tipp im Fenster bemerkt.
///
/// Manche Umgebungen beenden eine Texteingabe, ohne die passende
/// `UITextField`-Benachrichtigung zu senden. Nach einem Tipp sucht der Hub
/// deshalb zusätzlich das aktuelle First-Responder-Feld und meldet es an
/// (siehe ``TextInputHub/adoptCurrentFirstResponderIfNeeded()``).
///
/// Der Erkenner ist bewusst passiv: Er bricht keine Berührung ab
/// (`cancelsTouchesInView = false`) und läuft parallel zu allen anderen
/// Gesten (`shouldRecognizeSimultaneouslyWith` → `true`), damit die übrige
/// Bedienung unverändert bleibt.
private struct WindowTapObserver: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        ObserverView()
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    final class ObserverView: UIView, UIGestureRecognizerDelegate {
        private weak var observedWindow: UIWindow?
        private var tapRecognizer: UITapGestureRecognizer?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            attach(to: window)
        }

        private func attach(to window: UIWindow?) {
            guard observedWindow !== window else { return }

            if let recognizer = tapRecognizer, let previous = observedWindow {
                previous.removeGestureRecognizer(recognizer)
            }
            observedWindow = window
            tapRecognizer = nil

            guard let window else { return }

            let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap))
            recognizer.cancelsTouchesInView = false
            recognizer.delegate = self
            window.addGestureRecognizer(recognizer)
            tapRecognizer = recognizer
        }

        @objc private func handleTap() {
            DispatchQueue.main.async {
                TextInputHub.shared.adoptCurrentFirstResponderIfNeeded()
            }
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }

        deinit {
            if let recognizer = tapRecognizer, let window = observedWindow {
                window.removeGestureRecognizer(recognizer)
            }
        }
    }
}
