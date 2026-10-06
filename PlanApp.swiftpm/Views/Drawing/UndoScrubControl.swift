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
    var startRedoCount: Int
    var currentOffset: Int
    /// Kreis: Winkel des Undo-Buttons beim Start (Bogenmaß).
    var circleStartAngle: CGFloat
    var circleRadius: CGFloat
    var circleCenter: CGPoint
}

/// Unsichtbarer Trefferbereich über dem Rückgängig-Knopf. Erkennt Tipp,
/// 1-Sekunden-Halten und anschließendes Ziehen. Bei der Kreis-Palette nur
/// der Apple Pencil, in der oberen Leiste auch der Finger.
struct UndoScrubHandle: UIViewRepresentable {
    var allowsFinger: Bool
    var style: UndoScrubStyle
    var onTap: () -> Void
    var onScrubBegan: (_ origin: CGPoint, _ windowOrigin: CGPoint) -> Void
    var onScrubChanged: (_ translation: CGSize, _ windowLocation: CGPoint) -> Void
    var onScrubEnded: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UndoScrubHandleView {
        let view = UndoScrubHandleView()
        view.isAccessibilityElement = false
        view.backgroundColor = .clear
        view.coordinator = context.coordinator
        return view
    }

    func updateUIView(_ uiView: UndoScrubHandleView, context: Context) {
        context.coordinator.parent = self
        uiView.coordinator = context.coordinator
    }

    final class Coordinator {
        var parent: UndoScrubHandle
        init(_ parent: UndoScrubHandle) { self.parent = parent }
    }
}

final class UndoScrubHandleView: UIView {
    var coordinator: UndoScrubHandle.Coordinator?
    private var holdWorkItem: DispatchWorkItem?
    private var isScrubbing = false
    private var startLocation: CGPoint = .zero
    private var trackedTouch: UITouch?
    private let holdDuration: TimeInterval = 1.0

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, accepts(touch) else { return }
        trackedTouch = touch
        isScrubbing = false
        startLocation = touch.location(in: nil)
        holdWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self, let touch = self.trackedTouch else { return }
            self.isScrubbing = true
            let windowPoint = touch.location(in: nil)
            let local = self.convert(self.bounds.center, to: nil)
            self.coordinator?.parent.onScrubBegan(local, windowPoint)
            self.playPencilHaptic(intensity: 0.85)
        }
        holdWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + holdDuration, execute: item)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = trackedTouch, touches.contains(touch) else { return }
        let windowPoint = touch.location(in: nil)
        if isScrubbing {
            let translation = CGSize(
                width: windowPoint.x - startLocation.x,
                height: windowPoint.y - startLocation.y
            )
            coordinator?.parent.onScrubChanged(translation, windowPoint)
        } else {
            let distance = hypot(windowPoint.x - startLocation.x, windowPoint.y - startLocation.y)
            if distance > 14 {
                holdWorkItem?.cancel()
                holdWorkItem = nil
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = trackedTouch, touches.contains(touch) else { return }
        finish(didComplete: true)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        finish(didComplete: false)
    }

    private func finish(didComplete: Bool) {
        let wasScrubbing = isScrubbing
        holdWorkItem?.cancel()
        holdWorkItem = nil
        isScrubbing = false
        trackedTouch = nil
        if wasScrubbing {
            coordinator?.parent.onScrubEnded()
        } else if didComplete {
            coordinator?.parent.onTap()
        }
    }

    private func accepts(_ touch: UITouch) -> Bool {
        if touch.type == .pencil { return true }
        return coordinator?.parent.allowsFinger == true && touch.type == .direct
    }

    private func playPencilHaptic(intensity: CGFloat) {
        if #available(iOS 17.5, *) {
            let generator = UIImpactFeedbackGenerator(style: .rigid, view: self)
            generator.impactOccurred(intensity: intensity)
        } else {
            let generator = UIImpactFeedbackGenerator(style: .rigid)
            generator.impactOccurred(intensity: intensity)
        }
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
            availableHeight: max(0, UIScreen.main.bounds.height - session.origin.y - 28)
        )
        let redoTicks = min(session.startRedoCount, 8)
        let spacing = CGFloat(NoteUndoSessionPolicy.linearTickSpacing)

        return ZStack {
            let totalDown = CGFloat(undoTicks) * spacing
            let totalUp = CGFloat(redoTicks) * spacing
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
                        .fill(Color.secondary.opacity(step == -appliedOffset ? 0.95 : 0.45))
                        .frame(width: 18, height: 3)
                        .position(x: session.origin.x, y: session.origin.y - CGFloat(step) * spacing)
                }
            }

            Image(systemName: "arrow.uturn.backward")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.18), lineWidth: 1)
                )
                .position(
                    x: session.origin.x,
                    y: session.origin.y + CGFloat(appliedOffset) * spacing
                )
        }
        .allowsHitTesting(false)
    }

    private var circularBar: some View {
        let undoTicks = NoteUndoSessionPolicy.circularTickCount(undoCount: session.startUndoCount)
        let redoTicks = NoteUndoSessionPolicy.redoTickCount(
            redoCount: session.startRedoCount,
            maxTicks: max(0, NoteUndoSessionPolicy.circularMaxTicks - undoTicks)
        )
        let radius = session.circleRadius
        let center = session.circleCenter
        let start = session.circleStartAngle
        let stepAngle = undoTicks + redoTicks > 0
            ? (2 * CGFloat.pi) / CGFloat(NoteUndoSessionPolicy.circularMaxTicks)
            : 0
        let sweep = CGFloat(undoTicks) * stepAngle

        return ZStack {
            Circle()
                .trim(from: 0, to: max(0.02, sweep / (2 * .pi)))
                .stroke(.ultraThinMaterial, style: StrokeStyle(lineWidth: 44, lineCap: .round))
                .rotationEffect(.radians(Double(start - .pi / 2)))
                .frame(width: radius * 2, height: radius * 2)
                .position(center)

            if undoTicks > 0 {
                ForEach(1...undoTicks, id: \.self) { step in
                    let angle = start + CGFloat(step) * stepAngle
                    tick(at: angle, center: center, radius: radius, emphasized: step == appliedOffset)
                }
            }

            if redoTicks > 0 {
                ForEach(1...redoTicks, id: \.self) { step in
                    let angle = start - CGFloat(step) * stepAngle
                    tick(at: angle, center: center, radius: radius, emphasized: step == -appliedOffset)
                }
            }

            let handleAngle = start + CGFloat(appliedOffset) * stepAngle
            Image(systemName: "arrow.uturn.backward")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().strokeBorder(Color.primary.opacity(0.18), lineWidth: 1))
                .position(
                    x: center.x + radius * cos(handleAngle),
                    y: center.y + radius * sin(handleAngle)
                )
        }
        .allowsHitTesting(false)
    }

    private func tick(at angle: CGFloat, center: CGPoint, radius: CGFloat, emphasized: Bool) -> some View {
        let inner = CGPoint(
            x: center.x + (radius - 16) * cos(angle),
            y: center.y + (radius - 16) * sin(angle)
        )
        let outer = CGPoint(
            x: center.x + (radius + 4) * cos(angle),
            y: center.y + (radius + 4) * sin(angle)
        )
        return Path { path in
            path.move(to: inner)
            path.addLine(to: outer)
        }
        .stroke(Color.secondary.opacity(emphasized ? 0.95 : 0.45), style: StrokeStyle(lineWidth: 3, lineCap: .round))
    }
}

enum UndoScrubMath {
    static func linearOffset(
        translationY: CGFloat,
        undoTicks: Int,
        redoTicks: Int,
        spacing: CGFloat = CGFloat(NoteUndoSessionPolicy.linearTickSpacing)
    ) -> Int {
        guard spacing > 0 else { return 0 }
        let raw = Int((translationY / spacing).rounded())
        return min(max(raw, -redoTicks), undoTicks)
    }

    static func circularOffset(
        from startAngle: CGFloat,
        to point: CGPoint,
        center: CGPoint,
        undoTicks: Int,
        redoTicks: Int,
        stepAngle: CGFloat
    ) -> Int {
        guard stepAngle > 0 else { return 0 }
        let current = atan2(point.y - center.y, point.x - center.x)
        var delta = current - startAngle
        while delta > .pi { delta -= 2 * .pi }
        while delta < -.pi { delta += 2 * .pi }
        let raw = Int((delta / stepAngle).rounded())
        return min(max(raw, -redoTicks), undoTicks)
    }
}
