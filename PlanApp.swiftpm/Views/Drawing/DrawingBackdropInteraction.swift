import SwiftUI
import UIKit
import UIKit.UIGestureRecognizerSubclass

/// Eigene Hit-Fläche hinter dem Zettel. Sie bleibt auch während eines Strichs
/// aktiv: Eingaben werden geprüft, statt die UIView mitten im Touch abzuschalten.
struct PalmSafeBackdropDismissView: UIViewRepresentable {
    let isEnabled: Bool
    /// Erlaubt zusätzlich einen bewussten **Apple-Pencil-Tipp** auf die Seite.
    /// Die Schutzregeln bleiben identisch: keine Mehrfinger-Kontakte, keine
    /// Handballen-Größe, kein Ziehen, keine laufende Zeichen-Berührung.
    var allowsPencilTap: Bool = false
    let canDismiss: () -> Bool
    let onDismiss: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> DrawingBackdropUIView {
        let view = DrawingBackdropUIView()
        view.backgroundColor = .clear
        view.isMultipleTouchEnabled = true
        let tap = IntentionalFingerTapRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        tap.delegate = context.coordinator
        view.addGestureRecognizer(tap)
        context.coordinator.tap = tap
        configure(context.coordinator)
        return view
    }

    func updateUIView(_ view: DrawingBackdropUIView, context: Context) {
        configure(context.coordinator)
    }

    private func configure(_ coordinator: Coordinator) {
        coordinator.tap?.canRecognizeTap = { isEnabled && canDismiss() }
        coordinator.tap?.actionForTap = onDismiss
        coordinator.tap?.allowsPencilTap = allowsPencilTap
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        weak var tap: IntentionalFingerTapRecognizer?

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool { true }

        @objc func handleTap(_ recognizer: IntentionalFingerTapRecognizer) {
            guard recognizer.state == .recognized, recognizer.canRecognizeTap() else { return }
            recognizer.completedAction?()
        }
    }
}

/// Markierung, damit der passive Palette-Observer einen Hintergrund-Tipp nicht
/// doppelt verarbeitet. Der Hintergrund entscheidet selbst: Palette ODER Notiz.
final class DrawingBackdropUIView: UIView {}

/// Prüft den gesamten Kontakt, nicht nur dessen anfangs oft kleinen Radius.
/// Mehrere Finger, Ziehen, langes Aufliegen und gleichzeitig aktive Kontakte
/// auf anderen Views sind keine Schließgeste. Der Apple Pencil darf – wenn
/// ausdrücklich erlaubt – mit derselben strengen Prüfung schließen.
final class IntentionalFingerTapRecognizer: UIGestureRecognizer {
    var canRecognizeTap: () -> Bool = { true }
    var actionForTap: (() -> Void)?
    private(set) var completedAction: (() -> Void)?
    /// Zusätzlich bewusste Apple-Pencil-Tipps annehmen.
    var allowsPencilTap: Bool = false {
        didSet {
            guard allowsPencilTap != oldValue else { return }
            configureTouchHandling()
        }
    }

    private var trackedTouch: UITouch?
    private var startPoint: CGPoint = .zero
    private var startTime: TimeInterval = 0
    private var pendingAction: (() -> Void)?

    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        configureTouchHandling()
    }

    private func configureTouchHandling() {
        var types: [NSNumber] = [
            NSNumber(value: UITouch.TouchType.direct.rawValue),
            NSNumber(value: UITouch.TouchType.indirectPointer.rawValue)
        ]
        if allowsPencilTap {
            types.append(NSNumber(value: UITouch.TouchType.pencil.rawValue))
        }
        allowedTouchTypes = types
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
    }

    private func acceptsTouchType(_ type: UITouch.TouchType) -> Bool {
        switch type {
        case .direct, .indirectPointer:
            return true
        case .pencil:
            return allowsPencilTap
        default:
            return false
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        guard state == .possible else { return }
        guard trackedTouch == nil, touches.count == 1,
              let touch = touches.first,
              acceptsTouchType(touch.type),
              canRecognizeTap() else {
            state = .failed
            return
        }
        trackedTouch = touch
        startPoint = touch.location(in: nil)
        startTime = touch.timestamp
        // Aktion beim Aufsetzen merken. Ein zeitgleich schließender Palette-
        // Observer darf diesen Tipp nicht nachträglich zum Notiz-Schließen machen.
        pendingAction = actionForTap
        validate(touch, event: event)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        guard state == .possible, let touch = trackedTouch else { return }
        validate(touch, event: event)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        guard state == .possible else { return }
        guard let touch = trackedTouch, touches.contains(touch) else {
            state = .failed
            return
        }
        validate(touch, event: event)
        if state == .possible {
            completedAction = pendingAction
            state = .recognized
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        if state == .possible { state = .failed }
    }

    private func validate(_ touch: UITouch, event: UIEvent) {
        guard state == .possible else { return }
        let location = touch.location(in: nil)
        let movement = hypot(location.x - startPoint.x, location.y - startPoint.y)
        // Der Apple Pencil tippt fast immer mit aufliegendem Handballen. Für
        // einen Pencil-Tipp zählen direkte Kontakte (Hand, Finger) deshalb
        // nicht als „zweiter Kontakt“ – ein zweiter **Pencil**-Kontakt oder
        // ein zweiter Fingertipp auf dieselbe Weise schon. Für Fingertipps
        // bleibt die Prüfung unverändert streng.
        let isPencilTap = touch.type == .pencil
        let hasOtherContact = event.allTouches?.contains { other in
            guard other !== touch else { return false }
            switch other.phase {
            case .began, .moved, .stationary:
                if isPencilTap, other.type == .direct { return false }
                return true
            case .ended, .cancelled:
                // Auch zwei im selben Event losgelassene Finger zählen nicht
                // plötzlich als Ein-Finger-Tipp. Hover-Phasen dagegen ignorieren.
                if isPencilTap, other.type == .direct { return false }
                return other.timestamp >= startTime
            default:
                return false
            }
        } ?? false

        guard canRecognizeTap(), !hasOtherContact,
              IntentionalTapPolicy.acceptsSample(
                elapsed: touch.timestamp - startTime,
                movement: movement,
                majorRadius: touch.majorRadius,
                radiusTolerance: touch.majorRadiusTolerance
              ) else {
            state = .failed
            return
        }
    }

    override func reset() {
        super.reset()
        trackedTouch = nil
        pendingAction = nil
        completedAction = nil
    }

    // Rein beobachtend: weder PencilKit noch Textfelder/Buttons verdrängen.
    override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool { false }
    override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool { false }
}

/// Beobachtet die Hover-Position des Apple Pencil im **ganzen Fenster** und
/// legt sie in `Haptics.lastPencilWindowLocation` ab. Werkzeugleiste und
/// Kreis-Bar können damit beim Antippen eines Werkzeugs genau an der
/// Stiftspitze vibrieren – der PencilKit-Canvas sieht den Stift über den
/// Bedienelementen nicht.
struct PencilHoverLocationObserver: UIViewRepresentable {
    let isEnabled: Bool

    func makeUIView(context: Context) -> ObserverView { ObserverView() }

    func updateUIView(_ view: ObserverView, context: Context) {
        view.observesHover = isEnabled
    }

    static func dismantleUIView(_ view: ObserverView, coordinator: ()) {
        view.observesHover = false
        view.detach()
    }

    final class ObserverView: UIView {
        var observesHover = false
        private weak var observedWindow: UIWindow?
        private lazy var hover: UIHoverGestureRecognizer = {
            let recognizer = UIHoverGestureRecognizer(target: self, action: #selector(handleHover(_:)))
            // Nur der Stift: Finger-/Pointer-Hover braucht keine eigene Haptik.
            recognizer.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.pencil.rawValue)]
            return recognizer
        }()

        override func didMoveToWindow() {
            super.didMoveToWindow()
            detach()
            guard let window else { return }
            window.addGestureRecognizer(hover)
            observedWindow = window
        }

        func detach() {
            observedWindow?.removeGestureRecognizer(hover)
            observedWindow = nil
        }

        @objc private func handleHover(_ recognizer: UIHoverGestureRecognizer) {
            guard observesHover else { return }
            switch recognizer.state {
            case .began, .changed:
                // `nil` = Fensterkoordinaten, genau die Einheit, die der
                // UICanvasFeedbackGenerator für die Stift-Haptik erwartet.
                let point = recognizer.location(in: nil)
                if point.x.isFinite, point.y.isFinite {
                    Haptics.lastPencilWindowLocation = point
                }
            default:
                break
            }
        }
    }
}

/// Beobachtet Fingertipps auf Papier, Kopfzeile, Werkzeugen und Tastatur, ohne
/// eine transparente Vollbild-Hit-Fläche über PencilKit/Buttons zu legen.
struct DrawingFingerTapObserver: UIViewRepresentable {
    let isEnabled: Bool
    let onTap: () -> Void

    func makeUIView(context: Context) -> ObserverView { ObserverView() }

    func updateUIView(_ view: ObserverView, context: Context) {
        view.observesTaps = isEnabled
        view.onTap = onTap
    }

    static func dismantleUIView(_ view: ObserverView, coordinator: ()) {
        view.observesTaps = false
        view.onTap = nil
        view.detach()
    }

    final class ObserverView: UIView, UIGestureRecognizerDelegate {
        var observesTaps = false
        var onTap: (() -> Void)?
        private weak var observedWindow: UIWindow?
        private lazy var tap: IntentionalFingerTapRecognizer = {
            let tap = IntentionalFingerTapRecognizer(target: self, action: #selector(handleTap(_:)))
            tap.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
            tap.canRecognizeTap = { [weak self] in self?.observesTaps == true }
            tap.delegate = self
            return tap
        }()

        override func didMoveToWindow() {
            super.didMoveToWindow()
            detach()
            guard let window else { return }
            window.addGestureRecognizer(tap)
            observedWindow = window
        }

        func detach() {
            observedWindow?.removeGestureRecognizer(tap)
            observedWindow = nil
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard observesTaps, touch.type == .direct else { return false }
            var view = touch.view
            while let current = view {
                if current is DrawingBackdropUIView { return false }
                view = current.superview
            }
            return true
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool { true }

        @objc private func handleTap(_ recognizer: UIGestureRecognizer) {
            guard recognizer.state == .recognized, observesTaps else { return }
            // Erst die eigentliche Button-Aktion ausführen lassen, dann schließen.
            DispatchQueue.main.async { [weak self] in
                guard let self, self.observesTaps else { return }
                self.onTap?()
            }
        }
    }
}
