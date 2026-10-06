import SwiftUI
import UIKit

/// Hält eine schwache Referenz auf eine unsichtbare UIView. Der Bildschirm-
/// Rahmen wird erst beim Antippen gelesen – zuverlässiger als ein gecachter
/// GeometryReader-Wert, der beim ersten Layout oft 0 oder winzig ist.
final class ViewFrameHolder {
    weak var view: UIView?

    var currentWindowFrame: CGRect {
        guard let view else { return .zero }
        let target: UIView = view.window ?? view
        let frame = view.convert(view.bounds, to: target)
        return frame
    }

    var plausibleWindowFrame: CGRect {
        let frame = currentWindowFrame
        guard HeroTransitionPolicy.isPlausibleSourceFrame(
            x: frame.minX,
            y: frame.minY,
            width: frame.width,
            height: frame.height
        ) else { return .zero }
        return frame
    }
}

/// Unsichtbare UIKit-Sonde, die den echten Fenster-Rahmen einer SwiftUI-View liefert.
struct ViewFrameProbe: UIViewRepresentable {
    let holder: ViewFrameHolder

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        holder.view = view
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        holder.view = uiView
    }
}
