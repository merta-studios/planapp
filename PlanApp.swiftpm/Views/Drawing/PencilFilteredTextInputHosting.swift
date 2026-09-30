import SwiftUI
import UIKit

/// UIView, das Apple-Pencil-Berührungen nach unten durchreichen kann.
/// Wenn `pencilInteractionAllowed == false` ist, beantwortet ein Pencil-Touch
/// den Hit-Test mit `nil`, sodass die Berührung an die darunterliegende
/// PencilKit-Zeichenfläche geht (der Pencil zeichnet also einfach "über" den
/// Textfeldern, statt sie anzufassen). Finger-Berührungen werden immer
/// angenommen, damit Textfelder jederzeit per Finger ausgewählt und
/// verschoben werden können.
final class PencilFilteringView: UIView {
    var pencilInteractionAllowed: Bool = true

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if !pencilInteractionAllowed,
           let touches = event?.allTouches,
           touches.contains(where: { $0.type == .pencil }) {
            return nil
        }
        return super.hitTest(point, with: event)
    }
}

/// UIViewController, der eine SwiftUI-View in einem `UIHostingController`
/// einbettet und den Hit-Test über `PencilFilteringView` filtert.
final class PencilFilteredHostingController<Content: View>: UIViewController {
    let hosting: UIHostingController<Content>

    var pencilInteractionAllowed: Bool {
        get { (view as? PencilFilteringView)?.pencilInteractionAllowed ?? true }
        set { (view as? PencilFilteringView)?.pencilInteractionAllowed = newValue }
    }

    init(rootView: Content) {
        hosting = UIHostingController(rootView: rootView)
        hosting.view.backgroundColor = .clear
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func loadView() {
        view = PencilFilteringView()
        view.backgroundColor = .clear
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        addChild(hosting)
        hosting.view.frame = view.bounds
        hosting.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(hosting.view)
        hosting.didMove(toParent: self)
    }
}

/// SwiftUI-Brücke: Bettet die Textfeld-Ebene so ein, dass Apple-Pencil-Touches
/// nur dann ankommen, wenn das Text-Werkzeug aktiv ist (`pencilInteractionAllowed`).
struct PencilFilteredHost<Content: View>: UIViewControllerRepresentable {
    let pencilInteractionAllowed: Bool
    let content: Content

    init(pencilInteractionAllowed: Bool, @ViewBuilder content: () -> Content) {
        self.pencilInteractionAllowed = pencilInteractionAllowed
        self.content = content()
    }

    func makeUIViewController(context: Context) -> PencilFilteredHostingController<Content> {
        let controller = PencilFilteredHostingController(rootView: content)
        controller.pencilInteractionAllowed = pencilInteractionAllowed
        return controller
    }

    func updateUIViewController(_ uiViewController: PencilFilteredHostingController<Content>, context: Context) {
        uiViewController.pencilInteractionAllowed = pencilInteractionAllowed
        uiViewController.hosting.rootView = content
    }
}
