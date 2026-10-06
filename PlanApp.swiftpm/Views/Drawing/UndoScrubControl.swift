import SwiftUI
import UIKit

/// Wie der Rückgängig-Scrubber dargestellt wird.
enum UndoScrubStyle: Equatable {
    case linear
    case circular
}

/// Laufende Scrubber-Sitzung: Ursprung im Overlay, Schrittweite vom Startzustand.
struct UndoScrubSession: Equatable {
    var origin: CGPoint
    var style: UndoScrubStyle
    var startUndoCount: Int
    /// Wiederholbare Schritte zum Sitzungsstart. Solange kann der Scrubber
    /// in die **andere** Richtung ziehen und genau die Schritte wiederher-
    /// stellen, die in dieser Sitzung rückgängig gemacht wurden (Redo).
    /// Mehr geht nicht: Ältere Redo-Schritte sind beim Sitzungsstart schon
    /// verbraucht.
    var startRedoCount: Int
    /// Tatsächlich angewandte Schritte (bestimmt die hervorgehobene Stufe).
    var currentOffset: Int
    /// Ziel des Fingers. Der Knopf **gleitet** dorthin, statt zu springen;
    /// die Schritte werden dabei einzeln angewandt. Negativ = Redo.
    var targetOffset: Int
    /// Kreis: Winkel des Undo-Buttons beim Start (Bogenmaß).
    var circleStartAngle: CGFloat
    var circleRadius: CGFloat
    var circleCenter: CGPoint
    /// Höhe des Overlays, damit der lineare Balken am unteren Rand stoppt.
    var containerHeight: CGFloat
}

/// Laufender Dreh-Zustand eines runden Scrubbers (Fingerposition als Winkel
/// um die Kreismitte und die daraus mitaddierte Gesamtdrehung).
///
/// Bewusst eine Referenz **außerhalb** des SwiftUI-States: Der Winkel ändert
/// sich bei jeder Bewegung. Läge er im Session-Struct, müsste er bei jedem
/// Sample in den State zurückgeschrieben werden (Neuzeichnen der ganzen Notiz
/// inklusive Palette) – und genau dieses Zurückschreiben passiert nicht, wenn
/// ein Sample noch keinen neuen Schritt auslöst (`applyScrubOffset` bricht
/// dann früh ab). Dann wurde die Drehung nie mitaddiert und der Rückgängig-
/// Knopf der Kreis-Bar ließ sich nicht auf dem Bogen ziehen.
final class UndoScrubRotationTracker {
    /// Zuletzt gemessener Winkel (Bogenmaß) um die Kreismitte.
    var lastAngle: CGFloat?
    /// Seit Scrub-Start kontinuierlich mitaddierte Gesamtdrehung.
    var accumulatedAngle: CGFloat = 0

    func reset() {
        lastAngle = nil
        accumulatedAngle = 0
    }
}

/// Unsichtbarer Trefferbereich über dem Rückgängig-Knopf. Die Verfolgung liegt
/// am Fenster (`UndoScrubWindowTracker`): Sobald der Halt begonnen hat, bleibt
/// der Balken sichtbar, bis der Stift oder Finger den Bildschirm wirklich
/// loslässt – auch wenn man seitlich weiterstreicht.
struct UndoScrubHandle: UIViewRepresentable {
    var allowsFinger: Bool
    var style: UndoScrubStyle
    /// Fenster-/Global-Mittelpunkt des Kreisbogens (nur Kreis-Bar).
    var circleCenterInGlobal: CGPoint = .zero
    /// Gewünschte on-screen-Radialgröße des Kreises (nur Kreis-Bar).
    /// Die Palette meldet ihren echten Bogendurchmesser, damit der Scrub-Kreis
    /// immer exakt so groß ist wie die Kreis-Bar selbst – unabhängig davon,
    /// ob die geometrische Mittelpunkts-Sonde schon einen Wert geliefert hat.
    var circleRadiusOverride: CGFloat? = nil
    /// Winkel (Bogenmaß, UIKit: 0 = rechts, im Uhrzeigersinn), unter dem der
    /// Knopf auf dem Kreis sitzt. Damit wird die Kreismitte beim Scrub-Start
    /// direkt aus der echten Knopf-Position abgeleitet – Knopf, neuer Kreis
    /// und Zieh-Knopf liegen dadurch immer exakt übereinander.
    var circleButtonAngle: CGFloat? = nil
    var onTap: () -> Void
    var onScrubBegan: (_ buttonCenter: CGPoint, _ circleCenter: CGPoint, _ intendedRadius: CGFloat?) -> Void
    var onScrubChanged: (_ translation: CGSize, _ windowLocation: CGPoint) -> Void
    var onScrubEnded: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UndoScrubHandleView {
        let view = UndoScrubHandleView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        view.isAccessibilityElement = false
        view.box = context.coordinator.box
        return view
    }

    func updateUIView(_ uiView: UndoScrubHandleView, context: Context) {
        let box = context.coordinator.box
        box.allowsFinger = allowsFinger
        box.style = style
        box.circleCenterInGlobal = circleCenterInGlobal
        box.circleRadiusOverride = circleRadiusOverride
        box.circleButtonAngle = circleButtonAngle
        box.onTap = onTap
        box.onScrubBegan = onScrubBegan
        box.onScrubChanged = onScrubChanged
        box.onScrubEnded = onScrubEnded
        uiView.box = box
        uiView.registerIfNeeded()
    }

    final class Coordinator {
        let box = UndoScrubCallbackBox()
    }
}

/// Stabile Callbacks. Der Coordinator überlebt SwiftUI-Updates, sodass ein
/// laufender Scrub nicht abreißt, wenn die Leiste neu gezeichnet wird.
final class UndoScrubCallbackBox {
    var allowsFinger = true
    var style: UndoScrubStyle = .linear
    var circleCenterInGlobal: CGPoint = .zero
    var circleRadiusOverride: CGFloat? = nil
    var circleButtonAngle: CGFloat? = nil
    var onTap: () -> Void = {}
    var onScrubBegan: (CGPoint, CGPoint, CGFloat?) -> Void = { _, _, _ in }
    var onScrubChanged: (CGSize, CGPoint) -> Void = { _, _ in }
    var onScrubEnded: () -> Void = {}
    weak var view: UIView?
    /// Höher gewinnt, wenn sich zwei Knöpfe überlappen (Kreis-Bar über der Leiste).
    var zOrder: Int { style == .circular ? 30 : 10 }
}

final class UndoScrubHandleView: UIView {
    var box: UndoScrubCallbackBox?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        registerIfNeeded()
        if window != nil {
            // Sobald der Knopf sichtbar ist: Pencil-Pro-Haptik vorbereiten.
            Haptics.attachFeedbackView(self)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        box?.view = self
    }

    func registerIfNeeded() {
        box?.view = self
        guard let window, let box else {
            if let box { UndoScrubRegistry.shared.unregister(box) }
            return
        }
        UndoScrubRegistry.shared.register(box)
        UndoScrubWindowTracker.install(on: window)
    }

    deinit {
        if let box { UndoScrubRegistry.shared.unregister(box) }
    }
}

/// Alle gerade sichtbaren Rückgängig-Knöpfe. Der Overlay fragt hier, ob ein
/// Punkt auf einem Knopf liegt – ohne selbst die restliche Fläche zu blockieren.
final class UndoScrubRegistry {
    static let shared = UndoScrubRegistry()
    private var boxes: [ObjectIdentifier: UndoScrubCallbackBox] = [:]

    func register(_ box: UndoScrubCallbackBox) {
        boxes[ObjectIdentifier(box)] = box
    }

    func unregister(_ box: UndoScrubCallbackBox) {
        boxes.removeValue(forKey: ObjectIdentifier(box))
    }

    func box(at windowPoint: CGPoint, touch: UITouch?) -> UndoScrubCallbackBox? {
        boxes.values
            .filter { candidate in
                guard let view = candidate.view, view.window != nil else { return false }
                let frame = view.convert(view.bounds, to: nil)
                guard frame.contains(windowPoint), frame.width > 1, frame.height > 1 else { return false }
                guard let touch else { return true }
                if touch.type == .pencil { return true }
                return candidate.allowsFinger && touch.type == .direct
            }
            .max { $0.zOrder < $1.zOrder }
    }

    func anyBoxFrame(contains windowPoint: CGPoint) -> Bool {
        box(at: windowPoint, touch: nil) != nil
    }
}

/// Verfolgt den Rückgängig-Halt am Fenster, nicht an der kleinen Taste.
/// Dadurch endet der Balken erst, wenn der Stift oder Finger den Bildschirm
/// loslässt – auch wenn die Berührung seitlich neben dem Balken weiterläuft.
/// Die Scroll-Leiste muss warten, bis dieser Erkenner scheitert, sonst
/// klaut sie den Kontakt beim ersten seitlichen Wisch.
final class UndoScrubWindowTracker: UIGestureRecognizer, UIGestureRecognizerDelegate {
    private static let trackers = NSMapTable<UIWindow, UndoScrubWindowTracker>.weakToStrongObjects()

    static func install(on window: UIWindow) {
        if trackers.object(forKey: window) != nil { return }
        let tracker = UndoScrubWindowTracker()
        tracker.cancelsTouchesInView = false
        tracker.delaysTouchesBegan = false
        tracker.delaysTouchesEnded = false
        tracker.delegate = tracker
        window.addGestureRecognizer(tracker)
        trackers.setObject(tracker, forKey: window)
    }

    private var trackedTouch: UITouch?
    private var activeBox: UndoScrubCallbackBox?
    private var startLocation: CGPoint = .zero
    private var isScrubbing = false
    private var holdWorkItem: DispatchWorkItem?
    private var ignoredThisSequence = false
    private var cancelFallback: DispatchWorkItem?
    private let holdDuration: TimeInterval = 1
    private let cancelSlop: CGFloat = 14

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        guard trackedTouch == nil, let touch = touches.first, let host = view else { return }
        let windowPoint = touch.location(in: host)
        guard let box = UndoScrubRegistry.shared.box(at: windowPoint, touch: touch) else {
            ignoredThisSequence = true
            state = .failed
            return
        }
        ignoredThisSequence = false
        Haptics.lastPencilWindowLocation = windowPoint
        trackedTouch = touch
        activeBox = box
        startLocation = windowPoint
        isScrubbing = false
        cancelFallback?.cancel()
        cancelFallback = nil
        // Für die Pencil-Pro-Haptik zählt die eigentliche Knopf-View, nicht
        // irgendeine SwiftUI-Hosting-View unter dem Stift.
        Haptics.attachFeedbackView(box.view ?? touch.view ?? host)
        holdWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.beginScrubIfStillHolding()
        }
        holdWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + holdDuration, execute: item)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        guard !ignoredThisSequence, let touch = trackedTouch, touches.contains(touch), let host = view else { return }
        cancelFallback?.cancel()
        cancelFallback = nil
        let windowPoint = touch.location(in: host)
        Haptics.lastPencilWindowLocation = windowPoint
        // Für die Pencil-Pro-Haptik zählt die tatsächliche Knopf-View, nicht
        // irgendein Treffer-View unter dem Stift.
        Haptics.attachFeedbackView(activeBox?.view ?? touch.view ?? host)
        if isScrubbing {
            // Bewusst KEIN Wechsel nach `.began`: Hatte eine SwiftUI-Geste der
            // Palette (Hover/Tap) den Kontakt schon erkannt, scheiterte dieser
            // Wechsel und UIKit lieferte danach keine Bewegungen mehr – man
            // konnte nach dem Halten nicht ziehen. Im Zustand `.possible`
            // bekommt der Erkenner alle Bewegungen bis zum Loslassen.
            let translation = CGSize(
                width: windowPoint.x - startLocation.x,
                height: windowPoint.y - startLocation.y
            )
            activeBox?.onScrubChanged(translation, windowPoint)
            return
        }
        let distance = hypot(windowPoint.x - startLocation.x, windowPoint.y - startLocation.y)
        if distance > cancelSlop {
            holdWorkItem?.cancel()
            holdWorkItem = nil
            state = .failed
            clearTracking()
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        guard let touch = trackedTouch, touches.contains(touch) else { return }
        let lifted = touch.location(in: nil)
        let moved = hypot(lifted.x - startLocation.x, lifted.y - startLocation.y)
        let wasScrubbing = isScrubbing
        let box = activeBox
        holdWorkItem?.cancel()
        holdWorkItem = nil
        clearTracking()
        if wasScrubbing {
            state = .failed
            box?.onScrubEnded()
        } else if moved <= cancelSlop {
            state = .failed
            box?.onTap()
        } else {
            state = .failed
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        guard let touch = trackedTouch, touches.contains(touch) else { return }
        // Während des Scrubs ignorieren wir einen Abbruch, der nur daher kommt,
        // dass die Berührung die Taste verlassen hat. Ein echter Systemabbruch
        // liefert danach kein `touchesEnded` mehr – dann schließt der Fallback.
        if isScrubbing {
            // Ein Abbruch, weil der Finger die Taste verlassen hat, beendet den
            // Balken nicht. Nur wenn danach wirklich keine Bewegung mehr kommt,
            // schließt der Fallback einen hängengebliebenen Kontakt.
            let box = activeBox
            let touchIdentity = touch
            cancelFallback?.cancel()
            let item = DispatchWorkItem { [weak self] in
                guard let self, self.trackedTouch === touchIdentity, self.isScrubbing else { return }
                let active = self.activeBox
                self.clearTracking()
                self.state = .failed
                (active ?? box)?.onScrubEnded()
            }
            cancelFallback = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: item)
            return
        }
        holdWorkItem?.cancel()
        holdWorkItem = nil
        clearTracking()
        state = .cancelled
    }

    override func reset() {
        super.reset()
        if !isScrubbing {
            holdWorkItem?.cancel()
            holdWorkItem = nil
            clearTracking()
        }
        ignoredThisSequence = false
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if let trackedTouch { return touch === trackedTouch }
        guard let host = view else { return false }
        return UndoScrubRegistry.shared.anyBoxFrame(contains: touch.location(in: host))
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        // Scroll-Gesten der Leiste warten, solange der Kontakt auf dem Knopf
        // begann. Sonst blendet der Balken aus, sobald man seitlich streicht.
        if trackedTouch != nil || isScrubbing { return true }
        guard let host = view else { return false }
        return UndoScrubRegistry.shared.anyBoxFrame(contains: otherGestureRecognizer.location(in: host))
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        // Immer gleichzeitig erlauben: Sonst zwingt eine bereits erkannte
        // Palette-Geste diesen Erkenner zum Scheitern und das Ziehen bricht ab.
        true
    }

    override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool {
        trackedTouch == nil && !isScrubbing
    }

    private func beginScrubIfStillHolding() {
        guard trackedTouch != nil, let box = activeBox, !isScrubbing else { return }
        isScrubbing = true
        // Zustandswechsel nur in Touch-Callbacks. Ein `.began` aus dem Timer
        // lässt UIKit den Kontakt abbrechen, obwohl der Finger noch liegt.
        let buttonCenter = box.view.map { $0.convert($0.bounds.center, to: nil) } ?? startLocation
        Haptics.attachFeedbackView(box.view ?? view)
        Haptics.pencilSnap(intensity: 0.85)
        var circleCenter = box.circleCenterInGlobal
        if box.style == .circular, let angle = box.circleButtonAngle,
           let radius = box.circleRadiusOverride, radius > 8 {
            // Mitte aus der echten Knopf-Position: kein Versatz durch eine
            // veraltete Mittelpunkts-Sonde oder die Skalierungs-Animation.
            circleCenter = CGPoint(
                x: buttonCenter.x - radius * cos(angle),
                y: buttonCenter.y - radius * sin(angle)
            )
        }
        box.onScrubBegan(buttonCenter, circleCenter, box.circleRadiusOverride)
    }

    private func clearTracking() {
        trackedTouch = nil
        activeBox = nil
        isScrubbing = false
        cancelFallback?.cancel()
        cancelFallback = nil
    }
}

private extension CGRect {
    var center: CGPoint { CGPoint(x: midX, y: midY) }
}

/// Sichtbare Ticks des linearen oder kreisförmigen Undo-Scrubbers.
struct UndoScrubOverlay: View {
    let session: UndoScrubSession
    let appliedOffset: Int

    var body: some View {
        switch session.style {
        case .linear:
            linearBar
        case .circular:
            circularBar
        }
    }

    private var linearBar: some View {
        let undoTicks = NoteUndoSessionPolicy.linearTickCount(
            undoCount: session.startUndoCount,
            availableHeight: max(0, session.containerHeight - session.origin.y - 28)
        )
        // Wiederhol-Bereich über dem Knopf (dünner gezeichnet): Die Schritte
        // dieser Sitzung, die gerade rückgängig gemacht wurden.
        let redoTicks = max(0, session.startRedoCount)
        let spacing = CGFloat(NoteUndoSessionPolicy.linearTickSpacing)
        let totalDown = CGFloat(undoTicks) * spacing
        let totalUp = CGFloat(redoTicks) * spacing

        return ZStack {
            Capsule()
                .fill(.ultraThinMaterial)
                .frame(width: 44, height: totalDown + totalUp + 44)
                .overlay(
                    Capsule().strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                )
                .position(
                    x: session.origin.x,
                    y: session.origin.y + (totalDown - totalUp) / 2
                )

            if undoTicks > 0 {
                ForEach(1...undoTicks, id: \.self) { step in
                    Capsule()
                        .fill(Color.secondary.opacity(step == appliedOffset ? 0.95 : 0.45))
                        .frame(width: 18, height: 3)
                        .position(x: session.origin.x, y: session.origin.y + CGFloat(step) * spacing)
                }
            }

            if redoTicks > 0 {
                ForEach(1...redoTicks, id: \.self) { step in
                    Capsule()
                        .fill(Color.accentColor.opacity(step == -appliedOffset ? 0.95 : 0.30))
                        .frame(width: 18, height: 3)
                        .position(x: session.origin.x, y: session.origin.y - CGFloat(step) * spacing)
                }
            }

            scrubHandle(systemPointSize: 16, diameter: 40, circular: false)
                .position(
                    x: session.origin.x,
                    y: session.origin.y + CGFloat(session.targetOffset) * spacing
                )
                .animation(handleSnap, value: session.targetOffset)
        }
        .allowsHitTesting(false)
    }

    private var circularBar: some View {
        let undoTicks = NoteUndoSessionPolicy.circularTickCount(undoCount: session.startUndoCount)
        let radius = session.circleRadius
        let center = session.circleCenter
        let handleOnButton = radius < 8
        let start = session.circleStartAngle
        let sign = CGFloat(InteractionPolicies.circularUndoSweepSign)
        // Fester Winkel je Schritt: Bei wenigen Schritten ist der Rand nur ein
        // kurzer Teilbogen. Wiederholbare Schritte dieser Sitzung liegen in
        // Gegenrichtung (dünner, Akzentfarbe) – wie beim linearen Balken.
        let stepAngle = CGFloat(NoteUndoSessionPolicy.circularStepAngle(undoCount: session.startUndoCount))
        let redoTicks = max(0, session.startRedoCount)
        let lineWidth = CGFloat(InteractionPolicies.circularRingLineWidth)
        let undoSweep = CGFloat(undoTicks) * stepAngle * sign
        let redoSweep = -CGFloat(redoTicks) * stepAngle * sign

        return ZStack {
            if undoTicks > 0 || redoTicks > 0 {
                // Ein durchgehender Bogen über Redo- und Undo-Bereich; immer
                // mindestens so lang, dass der Knopf darauf sitzt.
                ring(from: start + redoSweep, sweep: undoSweep - redoSweep, radius: radius, center: center, lineWidth: lineWidth)
            }

            if undoTicks > 0 {
                ForEach(1...undoTicks, id: \.self) { step in
                    let angle = CGFloat(InteractionPolicies.circularTickAngle(
                        startAngle: Double(start),
                        step: step,
                        stepAngle: Double(stepAngle)
                    ))
                    tick(
                        at: angle,
                        center: center,
                        radius: radius,
                        lineWidth: lineWidth,
                        emphasized: step == appliedOffset
                    )
                }
            }

            if redoTicks > 0 {
                ForEach(1...redoTicks, id: \.self) { step in
                    let angle = CGFloat(InteractionPolicies.circularTickAngle(
                        startAngle: Double(start),
                        step: -step,
                        stepAngle: Double(stepAngle)
                    ))
                    tick(
                        at: angle,
                        center: center,
                        radius: radius,
                        lineWidth: lineWidth,
                        emphasized: step == -appliedOffset,
                        tint: .accentColor
                    )
                }
            }

            let handleAngle = start + CGFloat(session.targetOffset) * stepAngle * sign
            let handlePoint = handleOnButton
                ? session.origin
                : CGPoint(
                    x: center.x + radius * cos(handleAngle),
                    y: center.y + radius * sin(handleAngle)
                )
            scrubHandle(systemPointSize: 16, diameter: 44, circular: true)
                .position(handlePoint)
                .animation(handleSnap, value: session.targetOffset)
        }
        .allowsHitTesting(false)
    }

    /// Der Knopf **gleitet** sichtbar über den Bogen zum Finger – er springt
    /// nicht mit einem Ruck ans Ziel.
    private var handleSnap: Animation {
        .spring(response: 0.22, dampingFraction: 0.82)
    }

    private func ring(
        from start: CGFloat,
        sweep: CGFloat,
        radius: CGFloat,
        center: CGPoint,
        lineWidth: CGFloat
    ) -> some View {
        CircularScrubArc(startAngle: start, sweep: sweep)
            .stroke(.ultraThinMaterial, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .frame(width: radius * 2, height: radius * 2)
            .position(center)
    }

    private func scrubHandle(systemPointSize: CGFloat, diameter: CGFloat, circular: Bool) -> some View {
        Image(systemName: "arrow.uturn.backward")
            .font(.system(size: systemPointSize, weight: .semibold))
            .foregroundColor(.primary)
            .frame(width: diameter, height: diameter)
            .background(.ultraThinMaterial, in: circular ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: 10, style: .continuous)))
            .overlay(
                Group {
                    if circular {
                        Circle().strokeBorder(Color.primary.opacity(0.18), lineWidth: 1)
                    } else {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.18), lineWidth: 1)
                    }
                }
            )
    }

    private func tick(
        at angle: CGFloat,
        center: CGPoint,
        radius: CGFloat,
        lineWidth: CGFloat,
        emphasized: Bool,
        tint: Color = .secondary
    ) -> some View {
        let inset = lineWidth * 0.32
        let inner = CGPoint(
            x: center.x + (radius - inset) * cos(angle),
            y: center.y + (radius - inset) * sin(angle)
        )
        let outer = CGPoint(
            x: center.x + (radius + inset) * cos(angle),
            y: center.y + (radius + inset) * sin(angle)
        )
        return Path { path in
            path.move(to: inner)
            path.addLine(to: outer)
        }
        .stroke(tint.opacity(emphasized ? 0.95 : 0.45), style: StrokeStyle(lineWidth: emphasized ? 4 : 3, lineCap: .round))
    }
}

/// Bogen im eigenen Quadrat: 0 liegt rechts, positive Winkel im Uhrzeigersinn
/// (UIKit-y nach unten). Kein zusätzlicher Vierteldreh.
struct CircularScrubArc: Shape {
    var startAngle: CGFloat
    var sweep: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let steps = max(2, Int(abs(sweep) / 0.06))
        for index in 0...steps {
            let fraction = CGFloat(index) / CGFloat(steps)
            let angle = startAngle + sweep * fraction
            let point = CGPoint(
                x: center.x + radius * cos(angle),
                y: center.y + radius * sin(angle)
            )
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        return path
    }
}
