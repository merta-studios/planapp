import UIKit

/// Zentrale, leichtgewichtige Haptik-Helfer. Sie werden bei Tipp- und
/// Auswahl-Interaktionen ausgelöst – auch wenn mit dem Apple Pencil auf
/// Bedienelemente getippt wird, gibt es so immer eine spürbare Rückmeldung.
///
/// WICHTIG (Apple Pencil Pro): `UIImpactFeedbackGenerator` und die anderen
/// klassischen Generatoren spielen auf dem iPad KEINE Haptik – iPads besitzen
/// kein Taptic Engine. Die spürbare Rückmeldung am Apple Pencil Pro läuft
/// ausschließlich über `UICanvasFeedbackGenerator` (iPadOS 17.5+). Jeder
/// Helfer hier feuert deshalb zusätzlich einen Canvas-Feedback-Impuls, den
/// das System – wenn ein Apple Pencil Pro die aktive Eingabe ist – direkt im
/// Stift als Vibration auslöst. Auf Geräten ohne passende Hardware oder ohne
/// Stift ignoriert das System die Anfrage einfach.
public enum Haptics {
    private static let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private static let selectionGenerator = UISelectionFeedbackGenerator()
    private static let notificationGenerator = UINotificationFeedbackGenerator()

    /// Spürbares, angenehmes Klick-Feedback für Apple Pencil Pro und iPad (Buttons, Blöcke, Textfelder).
    public static func tap() {
        mediumImpact.prepare()
        mediumImpact.impactOccurred(intensity: 1.0)
        PencilHaptics.fire()
    }

    /// Feines Auswahl-Feedback (Werkzeug- oder Farbwechsel).
    public static func select() {
        selectionGenerator.prepare()
        selectionGenerator.selectionChanged()
        PencilHaptics.fire()
    }

    /// Warn-Feedback (z.B. vor dem Leeren einer Seite).
    public static func warning() {
        notificationGenerator.prepare()
        notificationGenerator.notificationOccurred(.warning)
        PencilHaptics.fire()
    }

    /// Erfolgs-Feedback.
    public static func success() {
        notificationGenerator.prepare()
        notificationGenerator.notificationOccurred(.success)
        PencilHaptics.fire()
    }

    /// Leichter „Tick", sobald der Apple Pencil über ein Bedienelement schwebt.
    /// Feuert bewusst NUR die Stift-Haptik – für Finger/iPhone gibt es kein
    /// Hover, ein zusätzliches Impact-Feedback wäre dort reine Verschwendung.
    public static func hover() {
        PencilHaptics.fire()
    }
}

/// Apple-Pencil-Pro-Haptik: `UICanvasFeedbackGenerator` ist die einzige
/// Feedback-API, deren Impulse auf dem iPad tatsächlich im Apple Pencil Pro
/// spürbar sind (die klassischen Impact-/Selection-Generatoren bleiben auf
/// dem iPad stumm – dort fehlt schlicht die Hardware dafür). Der Generator
/// wird an das aktive Fenster gebunden; der Punkt liefert dem System Kontext
/// darüber, wo das Ereignis passiert ist.
enum PencilHaptics {
    /// Hält den 17.5+-Generator versionssicher – auf älteren Systemen bleibt
    /// das Feld leer und `fire()` ist ein No-Op.
    private static var canvasFeedback: AnyObject?

    @available(iOS 17.5, *)
    private final class CanvasFeedback {
        let generator: UICanvasFeedbackGenerator
        weak var window: UIWindow?

        init(window: UIWindow) {
            self.window = window
            self.generator = UICanvasFeedbackGenerator(view: window)
        }

        var anchorPoint: CGPoint {
            guard let window else { return .zero }
            return CGPoint(x: window.bounds.midX, y: window.bounds.midY)
        }
    }

    private static var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }

    /// Löst eine Stift-Vibration aus. Muss nicht auf dem Haupt-Thread
    /// aufgerufen werden – bei Bedarf wird auf den Main-Thread gehüpft.
    static func fire() {
        let trigger = {
            guard #available(iOS 17.5, *) else { return }
            guard let window = keyWindow else { return }

            if let existing = canvasFeedback as? CanvasFeedback, existing.window === window {
                existing.generator.prepare()
                existing.generator.alignmentOccurred(at: existing.anchorPoint)
                return
            }

            let feedback = CanvasFeedback(window: window)
            canvasFeedback = feedback
            feedback.generator.prepare()
            feedback.generator.alignmentOccurred(at: feedback.anchorPoint)
        }

        if Thread.isMainThread {
            trigger()
        } else {
            DispatchQueue.main.async(execute: trigger)
        }
    }
}
