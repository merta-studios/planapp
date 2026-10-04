import SwiftUI
import UIKit

/// Wie die app-eigene Tastatur an eine Ansicht angebunden wird.
enum AppKeyboardPresentation: Equatable {
    /// Unten am **Fensterrand angedockt**. Die Tastatur liegt über dem Inhalt;
    /// Einstellungen scrollen das aktive Feld bei Bedarf sichtbar. Passt für
    /// WebUntis, Bearbeiten-Sheets und andere Formularlisten.
    case embedded
    /// **Schwebend** über dem Inhalt. Die Tastatur liegt als eigene Ebene über
    /// der Ansicht und verändert deren Layout nicht: Kein Safe-Area-Sprung,
    /// kein Verkleinern, kein Verschieben. Wird auf der Zeichenfläche benutzt,
    /// damit die Notiz genau dort bleibt, wo sie ist, wenn getippt wird.
    case floating
}

/// Hängt die app-eigene Tastatur unten an eine Ansicht an.
///
/// Die Tastatur ist Teil der **normalen Ansichts-Hierarchie**, wird für
/// Einstellungen aber als angedocktes Overlay bis an den unteren Fensterrand
/// gelegt. So bleibt sie auch auf WebUntis-/Sync-Seiten und in verschachtelten
/// Settings-Sheets am Bildschirmrand statt mitten im Scroll-Inhalt. Auf der
/// Zeichenfläche bleibt sie weiterhin schwebend über dem Papier.
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
            // Der transparente Inset reserviert Scroll-Platz für das aktive
            // Formularfeld, ohne die Tastatur selbst innerhalb des ScrollView
            // zu platzieren. Die sichtbare Tastatur kommt ausschließlich über
            // das nachfolgende, am Fenster ausgerichtete Overlay.
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if showsKeyboard, presentation == .embedded {
                    Color.clear
                        .frame(height: keyboardHeight)
                        .allowsHitTesting(false)
                }
            }
            // Die Systemtastatur darf den Host nicht verkleinern. Für die
            // eigene Tastatur wird unten immer das tatsächliche App-Fenster
            // verwendet, nicht die sichtbare Höhe eines ScrollViews.
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .overlay(alignment: .bottom) {
                if showsKeyboard {
                    switch presentation {
                    case .embedded:
                        dockedKeyboard
                    case .floating:
                        floatingKeyboard
                    }
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

    /// Die eingebettete Variante ist visuell am unteren **Fensterrand**
    /// angedockt, nicht Teil eines `ScrollView.safeAreaInset`. Letzteres kann
    /// auf Detailseiten dazu führen, dass die Tastatur innerhalb der gerade
    /// sichtbaren Formularfläche landet. Der Eingabe-Hub hält das aktive Feld
    /// weiterhin durch Scrollen sichtbar.
    private var dockedKeyboard: some View {
        AppKeyboardView(safeAreaInsets: metrics.safeInsets)
            .frame(maxWidth: .infinity)
            .frame(height: keyboardHeight)
            .background(Color.clear)
            .ignoresSafeArea(.container, edges: .bottom)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .zIndex(1_000)
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
                // Nicht die Höhe eines ScrollViews bzw. einer Detailseite
                // verwenden: Die Tastatur soll immer am unteren Rand des
                // aktiven App-Fensters andocken. Das Fenster liefert auch bei
                // Stage Manager, Split View und verschachtelten Settings-Sheets
                // die verlässlichen Maße.
                let window = self.window
                let height = window?.bounds.height ?? self.bounds.height
                let safeInsets = window?.safeAreaInsets ?? self.safeAreaInsets
                self.onChange?(
                    HostMetrics(
                        windowHeight: height,
                        safeInsets: safeInsets
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
