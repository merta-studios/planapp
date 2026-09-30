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
}
