import SwiftUI
import UIKit

/// Eingabe-Regeln für die Text-/Bild-Ebene über der Zeichenfläche.
///
/// Eine Berührung kann nicht gleichzeitig einen Strich beginnen **und** ein
/// Element auswählen – die Regeln entscheiden pro Berührungsart (Finger /
/// Apple Pencil) und Modus, ob die Ebene die Berührung annimmt oder an die
/// Zeichenfläche durchreicht:
///
/// * **Text-Werkzeug:** Die Ebene nimmt alles an (Finger **und** Pencil):
///   antippen auswählen, leere Fläche erzeugt Textfelder bzw. hebt die
///   Auswahl auf.
/// * **Zeichen-Werkzeug (Stift/Marker/Radierer/Lasso):**
///   * **Apple Pencil** zeichnet – auch über Bildern/Textfeldern (Striche
///     können dort beginnen). Nur die Fläche des **ausgewählten** Elements
///     bleibt anfassbar (Verschieben, Eck-Griffe, Löschen, Zuschneiden,
///     Tippen hebt die Auswahl auf).
///   * **Finger** fasst Elemente an, wenn „Nur Apple Pencil“ **an** ist
///     (unabhängig vom Werkzeug). Ist „Nur Apple Pencil“ **aus**, zeichnet
///     der Finger wie der Stift – Auswählen geht dann nur im Text-Werkzeug.
///   * Liegt gleichzeitig ein **Pencil-Kontakt** an (Handballen!), gilt
///     jeder Direkt-Kontakt im selben Ereignis als Handballen und wird
///     durchgereicht (Palm-Reject). Sonst schluckt die Hülle jeden
///     Pencil-Strich, sobald die Hand aufliegt – Zeichnen wäre komplett tot.
struct LayerInputPolicy {
    /// Text-Werkzeug aktiv: Ebene bedient alles.
    var textToolActive: Bool
    /// Finger darf Elemente antippen/verschieben („Nur Apple Pencil“ an).
    var fingerSelects: Bool
    /// Flächen, die auch im Zeichen-Modus anfassbar bleiben (die aktuell
    /// ausgewählten Elemente inkl. ihrer Optionen), in Koordinaten der Ebene.
    var selectionRects: () -> [CGRect]
}

/// UIKit-Hit-Test, der die Regeln aus ``LayerInputPolicy`` umsetzt.
///
/// Technisch entscheidet `hitTest` pro Berührung: `super.hitTest` liefert die
/// SwiftUI-Fläche unter dem Punkt (oder die leere Hülle selbst). Entsprechend
/// der Berührungsart und der Regeln wird die Fläche bedient oder die
/// Berührung (`nil`) an die darunter liegende Zeichenfläche weitergereicht.
final class InputFilteredPassthroughView<Content: View>: UIView {
    var host: UIHostingController<Content>?
    var policy: LayerInputPolicy = LayerInputPolicy(
        textToolActive: false,
        fingerSelects: false,
        selectionRects: { [] }
    )

    private enum TouchKind {
        case pencil, finger, unknown
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        // `nil` oder die Hülle selbst = **leerer** Bereich: Die Hosting-View
        // gibt nur dann ein Treffer-View zurück, wenn die SwiftUI-Fläche den
        // Punkt wirklich bedient (sonst `nil` – so fällt z. B. `allowsHitTesting(false)` durch).
        // Ein Treffer auf `host.view` oder tiefer ist also **Inhalt**
        // (Box, Anfasser, Options-Knöpfe, Tip-Hintergrund).
        let isEmptyArea = hit == nil || hit === self

        let touches = event?.allTouches ?? []
        let eventHasPencil = touches.contains {
            Self.isActivePhase($0.phase) && $0.type == .pencil
        }
        let kind = Self.touchKind(at: point, in: self, touches: touches)

        // Diagnose: Gemischte Kontakte (Stift + Handballen) und das
        // Verschlucken von Pencil-Kontakten sind die Kernfälle der
        // Zeichen-Bugs – nur diese Fälle loggen, damit die Konsole ruhig bleibt.
        if eventHasPencil, kind == .finger {
            DrawingDiagnostics.hit.debug(
                "hitTest: Pencil + weiterer Kontakt am selben Punkt (Handballen?)"
            )
        }

        // Text-Werkzeug: Die Ebene bedient alles – Finger und Pencil.
        if policy.textToolActive {
            return hit
        }

        // Zeichen-Werkzeuge: nur die Auswahl-Flächen bleiben anfassbar.
        let onSelection = policy.selectionRects().contains { $0.contains(point) }

        switch kind {
        case .pencil:
            // Stift zeichnet – auch über Bildern/Textfeldern und über den
            // unsichtbaren Tip-Hintergründen der Ebene. Nur echter Inhalt der
            // **Auswahl** (Box, Eck-Griffe, Options-Knöpfe) bleibt anfassbar.
            if onSelection, !isEmptyArea {
                return hit
            }
            return nil
        case .finger:
            // Handballen-Filter: gleichzeitig anliegender Pencil kontaktiert –
            // jeder Finger-Kontakt in diesem Ereignis ist ein Handballen.
            if eventHasPencil {
                return nil
            }
            if policy.fingerSelects {
                // Finger darf Elemente anfassen; leere Fläche fällt durch
                // (Zwei-Finger-Verschieben/-Zoomen landet auf dem Canvas).
                return isEmptyArea ? nil : hit
            }
            // Finger zeichnet („Nur Apple Pencil“ aus) – nur die Auswahl
            // bleibt bedienbar.
            return onSelection ? hit : nil
        case .unknown:
            // Kein Ereignis / keine Berührung am Punkt (z. B. systeminterne
            // Abfragen): wie im Zeichen-Modus nur Auswahl-Flächen bedienen,
            // im Text-Modus alles – konservativ zum bisherigen Verhalten.
            return onSelection ? hit : (isEmptyArea ? nil : hit)
        }
    }

    private static func isActivePhase(_ phase: UITouch.Phase) -> Bool {
        switch phase {
        case .began, .moved, .stationary:
            return true
        default:
            return false
        }
    }

    /// Berührungsart der Kontakte, die genau diesen Punkt berühren.
    ///
    /// Bewusst **ohne** Phasen-Filter: `hitTest` läuft vor der Auslieferung,
    /// die Phase kann da noch fehlen. Eine Berührung an diesem Punkt ist
    /// ohnehin die, für die getestet wird.
    private static func touchKind(
        at point: CGPoint,
        in view: UIView,
        touches: Set<UITouch>
    ) -> TouchKind {
        var result: TouchKind = .unknown
        for touch in touches {
            let location = touch.location(in: view)
            guard hypot(location.x - point.x, location.y - point.y) <= 4 else {
                continue
            }
            switch touch.type {
            case .pencil:
                // Pencil gewinnt: Der Strich gehört an diese Stelle.
                return .pencil
            case .direct, .indirect, .indirectPointer:
                result = .finger
            @unknown default:
                break
            }
        }
        return result
    }
}

/// Bettet den Text-/Bild-Ebenen-Inhalt so ein, dass die Regeln aus
/// ``LayerInputPolicy`` greifen. Siehe ``InputFilteredPassthroughView``.
struct InputFilteredContent<Content: View>: UIViewRepresentable {
    var content: Content
    var policy: LayerInputPolicy

    func makeUIView(context: Context) -> InputFilteredPassthroughView<Content> {
        let view = InputFilteredPassthroughView<Content>()
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
        view.policy = policy
        return view
    }

    func updateUIView(_ uiView: InputFilteredPassthroughView<Content>, context: Context) {
        uiView.host?.rootView = content
        uiView.policy = policy
    }

    static func dismantleUIView(_ uiView: InputFilteredPassthroughView<Content>, coordinator: Void) {
        uiView.host?.view.removeFromSuperview()
        uiView.host = nil
    }
}

/// Unsichtbare Vollflächen-Tip-Fläche der Text-/Bild-Ebene („Auswahl
/// aufheben“, „neues Textfeld“), die Apple-Pencil-Berührungen im
/// **Zeichen-Modus** durchlässt.
///
/// Ohne diesen Filter würde ein Pencil-Tipp auf die leere Fläche (mit
/// ausgewähltem Bild) die Auswahl aufheben, statt zu zeichnen – die Fläche
/// soll dann aber zeichnen (nur Tippen auf das Bild selbst hebt die Auswahl
/// auf). Im Text-Modus gibt es nichts zu zeichnen; dort tippt auch der Pencil
/// normal auf die Fläche.
struct PencilPassThroughHitTest<Content: View>: UIViewRepresentable {
    var content: Content
    /// `true`: Pencil-Berührungen fallen durch (Zeichen-Modus).
    var pencilPassesThrough: Bool

    final class PassThroughView<Hosted: View>: UIView {
        var host: UIHostingController<Hosted>?
        var pencilPassesThrough = true

        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            if pencilPassesThrough,
               let touches = event?.allTouches,
               touches.contains(where: { $0.type == .pencil }) {
                return nil
            }
            return super.hitTest(point, with: event)
        }
    }

    func makeUIView(context: Context) -> PassThroughView<Content> {
        let view = PassThroughView<Content>()
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
        view.pencilPassesThrough = pencilPassesThrough
        return view
    }

    func updateUIView(_ uiView: PassThroughView<Content>, context: Context) {
        uiView.host?.rootView = content
        uiView.pencilPassesThrough = pencilPassesThrough
    }

    static func dismantleUIView(_ uiView: PassThroughView<Content>, coordinator: Void) {
        uiView.host?.view.removeFromSuperview()
        uiView.host = nil
    }
}
