import SwiftUI
import UIKit

/// Behälter, der Apple-Pencil-Berührungen an darunterliegende Views (die
/// Zeichenfläche) durchreicht, Finger-Berührungen aber an den eingebetteten
/// SwiftUI-Inhalt liefert.
///
/// Verwendung: Ist die Einstellung „Apple Pencil“ an, kann der Finger damit
/// Text (und Bilder) anfassen, auswählen und verschieben – egal welches
/// Werkzeug gewählt ist. Der Apple Pencil zeichnet gleichzeitig unbehelligt
/// weiter, weil seine Berührungen diese Ebene nie erreichen.
///
/// Technisch entscheidet `hitTest`: Enthält das Ereignis ausschließlich
/// Stift-Berührungen, wird die gesamte Ebene übersprungen (`nil`) und UIKit
/// stellt die Berührung der darunterliegenden Zeichenfläche zu.
final class FingerOnlyPassthroughView<Content: View>: UIView {
    var host: UIHostingController<Content>?

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let touches = event?.allTouches, !touches.isEmpty {
            let hasFingerTouch = touches.contains {
                $0.type == .direct || $0.type == .indirect
            }
            // Nur Stift (kein Finger dabei): komplett durchreichen.
            if !hasFingerTouch {
                return nil
            }
        }
        return super.hitTest(point, with: event)
    }
}

/// Bettet SwiftUI-Inhalt so ein, dass nur Finger ihn bedienen können.
/// Siehe ``FingerOnlyPassthroughView``.
struct FingerOnlyContent<Content: View>: UIViewRepresentable {
    var content: Content

    func makeUIView(context: Context) -> FingerOnlyPassthroughView<Content> {
        let view = FingerOnlyPassthroughView<Content>()
        view.backgroundColor = .clear
        view.isOpaque = false
        let host = UIHostingController(rootView: content)
        host.view.backgroundColor = .clear
        host.view.isOpaque = false
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.host = host
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        return view
    }

    func updateUIView(_ uiView: FingerOnlyPassthroughView<Content>, context: Context) {
        uiView.host?.rootView = content
    }

    static func dismantleUIView(_ uiView: FingerOnlyPassthroughView<Content>, coordinator: Void) {
        uiView.host?.view.removeFromSuperview()
        uiView.host = nil
    }
}
