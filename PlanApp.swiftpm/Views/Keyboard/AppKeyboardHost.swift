import SwiftUI
import UIKit

/// Installiert die gemeinsame Tastaturebene einmal am App-Root. Sie gehört
/// zum Fenster, nicht zur Navigation oder zum Inhalt eines Einstellungen-Sheets.
struct AppKeyboardHostModifier: ViewModifier {
    @ObservedObject private var hub = TextInputHub.shared
    let monitorsTaps: Bool

    func body(content: Content) -> some View {
        content
            .background(
                KeyboardWindowAttachment(monitorsTaps: monitorsTaps)
                    .allowsHitTesting(false)
            )
            .onAppear { hub.keyboardHostDidAppear() }
            .onDisappear { hub.keyboardHostDidDisappear() }
    }
}

/// Hält unter einem Eingabebereich nur dessen Überlappung mit der globalen
/// Tastatur frei. Hier wird ausdrücklich KEINE weitere Tastatur erzeugt.
private struct AppKeyboardAvoidanceModifier: ViewModifier {
    @ObservedObject private var hub = TextInputHub.shared
    @State private var viewport = KeyboardViewport()

    private var bottomInset: CGFloat {
        guard hub.isAppKeyboardVisible,
              let window = viewport.window,
              let sourceWindow = hub.appKeyboardSourceWindow,
              window.windowScene === sourceWindow.windowScene else { return 0 }
        return AppKeyboardLayout.bottomOverlap(
            keyboardFrame: sourceWindow.convert(hub.appKeyboardFrame, to: window),
            viewport: viewport.frame
        )
    }

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if bottomInset > 0 {
                    Color.clear
                        .frame(height: bottomInset)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            // Außerhalb des Inset messen: Die äußere Größe des Sheets bleibt
            // gleich, nur der sichere Inhaltsbereich wird verkleinert.
            .background(
                KeyboardViewportReader { newViewport in
                    viewport = newViewport
                }
                .allowsHitTesting(false)
            )
            .onChange(of: bottomInset) { _, _ in
                hub.keyboardHostLayoutDidChange()
            }
            .onAppear { hub.keyboardHostDidAppear() }
            .onDisappear { hub.keyboardHostDidDisappear() }
    }
}

extension View {
    /// Einmal am App-Root verwenden. Bleibt auch über verschachtelten Sheets
    /// sichtbar; pro Fenster wird nur eine Tastatur angelegt.
    func appKeyboardHost(monitorsTaps: Bool = true) -> some View {
        modifier(AppKeyboardHostModifier(monitorsTaps: monitorsTaps))
    }

    /// Auf Notiz-/Einstellungen-Ansichten anwenden, damit deren Inhalt nicht
    /// von der fensterweiten Tastatur verdeckt wird.
    func appKeyboardAvoidance() -> some View {
        modifier(AppKeyboardAvoidanceModifier())
    }
}

/// Fenster-Verbindung und passive Tipp-Überwachung. Pencil-Berührungen werden
/// nie beobachtet; auf der Zeichenfläche kann auch die Tipp-Überwachung aus sein.
private struct KeyboardWindowAttachment: UIViewRepresentable {
    let monitorsTaps: Bool

    func makeUIView(context: Context) -> AttachmentView {
        AttachmentView()
    }

    func updateUIView(_ uiView: AttachmentView, context: Context) {
        uiView.monitorsTaps = monitorsTaps
    }

    static func dismantleUIView(_ uiView: AttachmentView, coordinator: ()) {
        uiView.detach()
    }

    final class AttachmentView: UIView, UIGestureRecognizerDelegate {
        var monitorsTaps = false {
            didSet {
                if oldValue != monitorsTaps { updateTapObserver() }
            }
        }

        private weak var observedWindow: UIWindow?
        private var presenter: AppKeyboardWindowPresenter?
        private var tapRecognizer: UITapGestureRecognizer?
        private var isUpdateScheduled = false

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard observedWindow !== window else { return }
            detach()
            guard let window else { return }
            observedWindow = window
            presenter = AppKeyboardWindowPresenter(sourceWindow: window)
            updateTapObserver()
            scheduleUpdate()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            scheduleUpdate()
        }

        override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
            super.traitCollectionDidChange(previousTraitCollection)
            scheduleUpdate()
        }

        private func scheduleUpdate() {
            guard !isUpdateScheduled else { return }
            isUpdateScheduled = true
            // Nicht während eines SwiftUI-/UIKit-Layoutpasses veröffentlichen.
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.isUpdateScheduled = false
                self.presenter?.update()
            }
        }

        private func updateTapObserver() {
            if let recognizer = tapRecognizer {
                observedWindow?.removeGestureRecognizer(recognizer)
                tapRecognizer = nil
            }
            guard monitorsTaps, let window = observedWindow else { return }
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

        func detach() {
            if let recognizer = tapRecognizer {
                observedWindow?.removeGestureRecognizer(recognizer)
            }
            tapRecognizer = nil
            presenter?.tearDown()
            presenter = nil
            observedWindow = nil
        }
    }
}

/// UIKit-Koordinaten statt SwiftUI-„global“: Auch in einem Sheet bezieht sich
/// das Rechteck dadurch auf das tatsächliche App-Fenster.
private struct KeyboardViewport {
    weak var window: UIWindow?
    var frame: CGRect = .zero
}

private struct KeyboardViewportReader: UIViewRepresentable {
    let onChange: (KeyboardViewport) -> Void

    func makeUIView(context: Context) -> MeasuringView {
        let view = MeasuringView()
        view.onChange = onChange
        return view
    }

    func updateUIView(_ uiView: MeasuringView, context: Context) {
        uiView.onChange = onChange
        uiView.scheduleMeasurement()
    }

    final class MeasuringView: UIView {
        var onChange: ((KeyboardViewport) -> Void)?
        private var lastViewport = KeyboardViewport()
        private var isMeasurementScheduled = false

        override func didMoveToWindow() {
            super.didMoveToWindow()
            scheduleMeasurement()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            scheduleMeasurement()
        }

        func scheduleMeasurement() {
            guard !isMeasurementScheduled else { return }
            isMeasurementScheduled = true
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.isMeasurementScheduled = false
                let viewport = KeyboardViewport(
                    window: self.window,
                    frame: self.window.map { self.convert(self.bounds, to: $0) } ?? .zero
                )
                guard self.lastViewport.window !== viewport.window
                        || self.lastViewport.frame != viewport.frame else { return }
                self.lastViewport = viewport
                self.onChange?(viewport)
            }
        }
    }
}
