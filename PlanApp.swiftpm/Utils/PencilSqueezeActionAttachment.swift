import SwiftUI
import UIKit

/// Unsichtbare UIKit-Brücke für Apple-Pencil-Squeeze auf SwiftUI-Views.
/// Wird z.B. an Stunden-Blöcke gehängt, damit ein Squeeze beim Hovern dieselben
/// Optionen öffnet wie ein langer Druck.
public struct PencilSqueezeActionAttachment: UIViewRepresentable {
    public let onSqueeze: () -> Void

    public init(onSqueeze: @escaping () -> Void) {
        self.onSqueeze = onSqueeze
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(onSqueeze: onSqueeze)
    }

    public func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = true

        let interaction = UIPencilInteraction()
        interaction.delegate = context.coordinator
        view.addInteraction(interaction)
        context.coordinator.interaction = interaction

        return view
    }

    public func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onSqueeze = onSqueeze
    }

    public final class Coordinator: NSObject, UIPencilInteractionDelegate {
        var onSqueeze: () -> Void
        weak var interaction: UIPencilInteraction?

        init(onSqueeze: @escaping () -> Void) {
            self.onSqueeze = onSqueeze
        }

        @available(iOS 17.5, *)
        public func pencilInteraction(
            _ interaction: UIPencilInteraction,
            didReceiveSqueeze squeeze: UIPencilInteraction.Squeeze
        ) {
            if squeeze.phase == .ended {
                DispatchQueue.main.async { [onSqueeze] in
                    onSqueeze()
                }
            }
        }

        public func pencilInteractionDidTap(_ interaction: UIPencilInteraction) {
            DispatchQueue.main.async { [onSqueeze] in
                onSqueeze()
            }
        }
    }
}
