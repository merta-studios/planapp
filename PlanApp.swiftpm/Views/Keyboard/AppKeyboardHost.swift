import SwiftUI
import UIKit

/// Wie die app-eigene Tastatur an eine Ansicht angebunden wird.
enum AppKeyboardPresentation: Equatable {
    /// Unten in die Ansicht **eingebettet** (`safeAreaInset`). Der Inhalt
    /// weicht der Tastatur aus. Passt für Einstellungen, Bearbeiten-Sheets und
    /// jede Liste, in der das aktive Feld sichtbar bleiben soll.
    case embedded
    /// **Schwebend** über dem Inhalt. Die Tastatur liegt als eigene Ebene über
    /// der Ansicht und verändert deren Layout nicht: Kein Safe-Area-Sprung,
    /// kein Verkleinern, kein Verschieben. Wird auf der Zeichenfläche benutzt,
    /// damit die Notiz genau dort bleibt, wo sie ist, wenn getippt wird.
    case floating
}

/// Hängt die app-eigene Tastatur unten an eine Ansicht an.
///
/// Die Tastatur ist Teil der **normalen Ansichts-Hierarchie** und erscheint
/// dadurch zuverlässig am unteren Rand der jeweiligen Ansicht: eingebettet in
/// Einstellungen und verschachtelten Bearbeiten-Sheets, schwebend über der
/// Zeichenfläche.
///
/// Warum kein eigenes Overlay-Fenster: Eine zusätzliche `UIWindow`-Ebene über
/// der App liegt auf echten Geräten unter bzw. über präsentierten Sheets und
/// erhält dort keine zuverlässigen Tipps. Die Folge waren eine falsch
/// platzierte Tastatur, wirkungslose Tasten und Tipps, die „durchrutschen“
/// und das offene Sheet bzw. die Notiz schließen. In der normalen Hierarchie
/// kann all das nicht passieren.
///
/// Damit nie zwei Tastaturen gleichzeitig sichtbar sind, merkt sich der Hub
/// die Reihenfolge aller Hosts; nur der oberste (zuletzt erschienene) Host
/// blendet die Tastatur ein – siehe ``TextInputHub/activeKeyboardHostID``.
struct AppKeyboardHostModifier: ViewModifier {
    @ObservedObject private var hub = TextInputHub.shared
    @State private var hostID = UUID()
    @State private var metrics = HostMetrics()

    /// Ob zusätzlich jeder Tipp im Fenster beobachtet wird (Sicherheitsnetz für
    /// Felder, die keine Bearbeitungs-Benachrichtigung senden). Auf der
    /// Zeichenfläche bleibt das aus, damit die PencilKit-Eingabe völlig
    /// unberührt bleibt.
    let monitorsTaps: Bool
    /// Ob die Tastatur eingebettet oder schwebend dargestellt wird.
    let presentation: AppKeyboardPresentation

    private var showsKeyboard: Bool {
        hub.isAppKeyboardVisible && hub.activeKeyboardHostID == hostID
    }

    private var keyboardHeight: CGFloat {
        AppKeyboardLayout.embeddedHeight(
            windowHeight: metrics.windowHeight,
            bottomInset: metrics.safeInsets.bottom
        )
    }

    private var floatingHeight: CGFloat {
        AppKeyboardLayout.floatingHeight(
            windowHeight: metrics.windowHeight,
            bottomInset: metrics.safeInsets.bottom
        )
    }

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if showsKeyboard, presentation == .embedded {
                    AppKeyboardView(safeAreaInsets: metrics.safeInsets)
                        .frame(height: keyboardHeight)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .overlay(alignment: .bottom) {
                if showsKeyboard, presentation == .floating {
                    floatingKeyboard
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
            .background(
                HostMetricsProbe { newMetrics in
                    if metrics != newMetrics { metrics = newMetrics }
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)
            )
            .onAppear { hub.keyboardHostDidAppear(hostID) }
            .onDisappear { hub.keyboardHostDidDisappear(hostID) }
    }

    /// Die schwebende Tastatur: eine abgerundete, leicht durchscheinende
    /// Fläche über dem Inhalt – wie die freigestellte Tastatur von iPadOS.
    /// Sie liegt **über** der Notiz, ohne deren Größe oder Position zu ändern;
    /// die Tasten bleiben dabei oberhalb des Home-Indikators.
    private var floatingKeyboard: some View {
        AppKeyboardView(safeAreaInsets: metrics.safeInsets, isFloating: true)
            .frame(height: floatingHeight)
            .background(.ultraThinMaterial)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: AppKeyboardLayout.floatingCornerRadius,
                    style: .continuous
                )
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: AppKeyboardLayout.floatingCornerRadius,
                    style: .continuous
                )
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.30), radius: 20, x: 0, y: 8)
            .padding(.horizontal, AppKeyboardLayout.floatingHorizontalMargin)
            .padding(.bottom, AppKeyboardLayout.floatingBottomMargin)
            .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

extension View {
    /// Blendet bei Bedarf die app-eigene Bildschirmtastatur an dieser Ansicht
    /// ein. Wird auf jeder Ansicht verwendet, die Textfelder enthält
    /// (Einstellungen, Bearbeiten-Sheets, Zeichenfläche); sichtbar ist immer
    /// nur die Tastatur des obersten Hosts.
    ///
    /// - Parameter presentation: `.embedded` (Standard) schiebt den Inhalt nach
    ///   oben, `.floating` legt die Tastatur über den Inhalt, ohne ihn zu
    ///   verändern (Zeichenfläche).
    func appKeyboardHost(
        monitorsTaps: Bool = true,
        presentation: AppKeyboardPresentation = .embedded
    ) -> some View {
        modifier(
            AppKeyboardHostModifier(
                monitorsTaps: monitorsTaps,
                presentation: presentation
            )
        )
    }
}

// MARK: - Metrik des Host-Fensters

/// Maße der Host-Ansicht: bestimmt Tastaturhöhe und den Abstand, den die
/// unterste Tastenreihe über dem Home-Indikator hält.
private struct HostMetrics: Equatable {
    var windowHeight: CGFloat = 0
    var safeInsets: UIEdgeInsets = .zero
}

/// Misst Fensterhöhe und Safe Area über UIKit statt über SwiftUI-„global“ –
/// dadurch stimmen die Werte auch in Sheets, Split View und Stage Manager.
private struct HostMetricsProbe: UIViewRepresentable {
    let onChange: (HostMetrics) -> Void

    func makeUIView(context: Context) -> ProbeView {
        ProbeView()
    }

    func updateUIView(_ uiView: ProbeView, context: Context) {
        uiView.onChange = onChange
        uiView.scheduleMeasurement()
    }

    final class ProbeView: UIView {
        var onChange: ((HostMetrics) -> Void)?
        private var isScheduled = false

        override func didMoveToWindow() {
            super.didMoveToWindow()
            scheduleMeasurement()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            scheduleMeasurement()
        }

        override func safeAreaInsetsDidChange() {
            super.safeAreaInsetsDidChange()
            scheduleMeasurement()
        }

        func scheduleMeasurement() {
            guard !isScheduled else { return }
            isScheduled = true
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.isScheduled = false
                // Eigene Höhe = Höhe der Host-Ansicht (ganzer Bildschirm auf
                // der Zeichenfläche, Sheet-Karte in den Einstellungen).
                let height = self.bounds.height > 0
                    ? self.bounds.height
                    : (self.window?.bounds.height ?? 0)
                self.onChange?(
                    HostMetrics(
                        windowHeight: height,
                        safeInsets: self.safeAreaInsets
                    )
                )
            }
        }
    }
}

// MARK: - Passive Tipp-Überwachung

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
            recognizer.allowedTouchTypes = [
                NSNumber(value: UITouch.TouchType.direct.rawValue),
                NSNumber(value: UITouch.TouchType.indirectPointer.rawValue)
            ]
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
