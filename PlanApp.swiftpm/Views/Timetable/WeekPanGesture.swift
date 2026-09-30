import SwiftUI
import UIKit

/// Installs a native `UIPanGestureRecognizer` on the enclosing vertical
/// `UIScrollView` of the timetable. This is what makes horizontal week
/// swiping track the finger continuously even when the swipe STARTS on top
/// of a lesson block: SwiftUI drag gestures attached to the scroll content
/// were silently losing the competition against the tap/hover gestures of
/// the many lesson cards, so the drag only reported once on finger lift.
/// A UIKit recognizer on the scroll view itself sees every touch first,
/// decides purely on the initial direction, and cancels the card touches
/// once a horizontal pan begins.
struct WeekPanGestureAttachment: UIViewRepresentable {
    /// Continuous horizontal translation while the finger moves.
    let onChanged: (CGFloat) -> Void
    /// Final translation and horizontal velocity (points/second) on lift.
    let onEnded: (CGFloat, CGFloat) -> Void
    var isEnabled: Bool = true

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> AttachmentView {
        let view = AttachmentView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        view.coordinator = context.coordinator
        return view
    }

    func updateUIView(_ uiView: AttachmentView, context: Context) {
        context.coordinator.parent = self
        uiView.coordinator = context.coordinator
        uiView.attachIfNeeded()
    }

    static func dismantleUIView(_ uiView: AttachmentView, coordinator: Coordinator) {
        if let pan = coordinator.pan {
            pan.view?.removeGestureRecognizer(pan)
            coordinator.pan = nil
        }
    }

    final class AttachmentView: UIView {
        weak var coordinator: Coordinator?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            attachIfNeeded()
        }

        func attachIfNeeded() {
            guard window != nil, let coordinator, coordinator.pan == nil else { return }

            // Walk up to the UIScrollView that backs the vertical ScrollView.
            var candidate: UIView? = superview
            var scrollView: UIScrollView?
            while let view = candidate {
                if let found = view as? UIScrollView {
                    scrollView = found
                    break
                }
                candidate = view.superview
            }
            guard let scrollView else { return }

            let pan = UIPanGestureRecognizer(
                target: coordinator,
                action: #selector(Coordinator.handlePan(_:))
            )
            pan.maximumNumberOfTouches = 1
            pan.delegate = coordinator
            scrollView.addGestureRecognizer(pan)
            // Vertical scrolling waits until our recognizer has failed. It
            // fails immediately for clearly vertical movements, so scrolling
            // stays responsive while horizontal swipes always win.
            scrollView.panGestureRecognizer.require(toFail: pan)
            coordinator.pan = pan
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: WeekPanGestureAttachment
        var pan: UIPanGestureRecognizer?

        init(_ parent: WeekPanGestureAttachment) {
            self.parent = parent
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard parent.isEnabled,
                  let pan = gestureRecognizer as? UIPanGestureRecognizer,
                  let view = pan.view else { return false }
            let velocity = pan.velocity(in: view)
            // Horizontal intent wins even for slightly diagonal swipes.
            return abs(velocity.x) > abs(velocity.y)
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            false
        }

        @objc func handlePan(_ recognizer: UIPanGestureRecognizer) {
            guard let view = recognizer.view else { return }
            let translation = recognizer.translation(in: view).x

            switch recognizer.state {
            case .began, .changed:
                parent.onChanged(translation)
            case .ended:
                parent.onEnded(translation, recognizer.velocity(in: view).x)
            case .cancelled, .failed:
                parent.onEnded(0, 0)
            default:
                break
            }
        }
    }
}
