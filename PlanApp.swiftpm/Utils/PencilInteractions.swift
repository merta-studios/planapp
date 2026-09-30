import SwiftUI
import UIKit

/// Delegate zur Verarbeitung von Apple Pencil Pro Squeeze- und Tap-Gesten
public final class PencilInteractionHandler: NSObject, UIPencilInteractionDelegate {
    public var onSqueeze: (() -> Void)?
    public var onDoubleTap: (() -> Void)?

    public init(onSqueeze: (() -> Void)? = nil, onDoubleTap: (() -> Void)? = nil) {
        self.onSqueeze = onSqueeze
        self.onDoubleTap = onDoubleTap
        super.init()
    }

    // iOS 17.5+ Apple Pencil Pro Squeeze Geste
    @available(iOS 17.5, *)
    public func pencilInteraction(_ interaction: UIPencilInteraction, didReceiveSqueeze squeeze: UIPencilInteraction.Squeeze) {
        if squeeze.phase == .ended {
            DispatchQueue.main.async { [weak self] in
                self?.onSqueeze?()
            }
        }
    }

    // Double-Tap für Apple Pencil 2 und Fallback
    public func pencilInteractionDidTap(_ interaction: UIPencilInteraction) {
        DispatchQueue.main.async { [weak self] in
            if let onSqueeze = self?.onSqueeze {
                onSqueeze()
            } else {
                self?.onDoubleTap?()
            }
        }
    }
}

/// SwiftUI ViewModifier für einheitliche Apple Pencil Hover- und Klick-Unterstützung
public struct PencilHoverModifier: ViewModifier {
    public var scale: CGFloat = 1.04
    public var effect: HoverEffect = .lift

    public func body(content: Content) -> some View {
        content
            .hoverEffect(effect)
            .contentShape(Rectangle())
    }
}

extension View {
    /// Aktiviert Apple Pencil Hover-Effekte und optimale Klickbarkeit
    public func pencilInteractive(effect: HoverEffect = .lift) -> some View {
        self.modifier(PencilHoverModifier(effect: effect))
    }

    /// Apple-Pencil-Pro-Haptik beim Hovern: löst einen leichten „Tick" im
    /// Stift aus, sobald dieser über dem Element zu schweben beginnt –
    /// genau einmal pro Hover-Bewegung, nicht während der gesamten Bewegung.
    public func pencilHoverFeedback() -> some View {
        modifier(PencilHoverFeedbackModifier())
    }
}

/// ViewModifier für Apple-Pencil-Pro-Hover-Haptik. `onContinuousHover`
/// meldet sowohl Stift- als auch Zeiger-Hover; das ausgelöste Canvas-
/// Feedback entscheidet das System passend zum Eingabegerät.
public struct PencilHoverFeedbackModifier: ViewModifier {
    @State private var didFireFeedback = false

    public init() {}

    public func body(content: Content) -> some View {
        content
            .onContinuousHover { phase in
                switch phase {
                case .active:
                    guard !didFireFeedback else { return }
                    didFireFeedback = true
                    Haptics.hover()
                case .ended:
                    didFireFeedback = false
                }
            }
    }
}
