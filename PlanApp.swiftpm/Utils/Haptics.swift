import UIKit

/// Zentrale, leichtgewichtige Haptik-Helfer. Sie werden bei Tipp- und
/// Auswahl-Interaktionen ausgelöst – auch wenn mit dem Apple Pencil auf
/// Bedienelemente getippt wird, gibt es so immer eine spürbare Rückmeldung.
public enum Haptics {
    private static let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private static let selectionGenerator = UISelectionFeedbackGenerator()
    private static let notificationGenerator = UINotificationFeedbackGenerator()
    /// Ansicht, über die der Apple Pencil Pro die Vibration selbst auslöst.
    private static weak var feedbackView: UIView?
    /// Ansicht, an die der vorbereitete Generator gebunden ist.
    private static weak var preparedPencilView: UIView?
    /// Vor dem Einrasten vorbereitet, sonst kommt die Pencil-Vibration nicht an.
    private static var preparedPencilSnap: UIImpactFeedbackGenerator?

    /// Merkt sich die Ansicht unter dem Stift und bereitet den Generator vor.
    /// Ein frischer Generator erst im Moment des Einrastens vibriert den Pencil
    /// nicht – deshalb wird hier vorbereitet und bei jedem weiteren Aufruf auf
    /// derselben Ansicht nur noch einmal nachgeschärft.
    public static func attachFeedbackView(_ view: UIView?) {
        guard let view else { return }
        if feedbackView === view, let existing = preparedPencilSnap {
            // Bereits vorbereitet: nur die Bereitschaft auffrischen, damit die
            // Apple-Pencil-Pro-Vibration zuverlässig ankommt.
            existing.prepare()
            return
        }
        feedbackView = view
        if #available(iOS 17.5, *), view.window != nil {
            // Die Ansicht muss sichtbar im Fenster liegen: Nur dann leitet
            // iPadOS die Vibration an den Apple Pencil Pro weiter.
            let generator = UIImpactFeedbackGenerator(style: .rigid, view: view)
            generator.prepare()
            preparedPencilSnap = generator
            preparedPencilView = view
        } else {
            let generator = UIImpactFeedbackGenerator(style: .rigid)
            generator.prepare()
            preparedPencilSnap = generator
            preparedPencilView = view
        }
    }

    /// Spürbares, angenehmes Klick-Feedback für Apple Pencil Pro und iPad (Buttons, Blöcke, Textfelder).
    public static func tap() {
        mediumImpact.prepare()
        mediumImpact.impactOccurred(intensity: 1.0)
    }

    /// Feines Auswahl-Feedback (Werkzeug- oder Farbwechsel).
    public static func select() {
        selectionGenerator.prepare()
        selectionGenerator.selectionChanged()
    }

    /// Letzte bekannte Stift-/Fingerposition in Fenster-Koordinaten. Der
    /// Apple Pencil Pro vibriert nur, wenn die Haptik an einer Position im
    /// Fenster ausgelöst wird (`UICanvasFeedbackGenerator`).
    public static var lastPencilWindowLocation: CGPoint?
    /// Generator pro Fenster – `UICanvasFeedbackGenerator` (iOS 17.5+) ist die
    /// einzige API, deren Feedback iPadOS an den Apple Pencil Pro weiterleitet.
    /// `UIImpactFeedbackGenerator` vibriert nur das (iPad-)Gerät selbst, und
    /// iPads haben keinen Taptic-Motor – deshalb kam bisher nie etwas an.
    private static var canvasGenerators = NSMapTable<UIView, AnyObject>.weakToStrongObjects()

    /// Löst Apple-Pencil-Pro-Haptik an einer Fensterposition aus.
    /// - Parameters:
    ///   - view: beliebige View im Zielfenster
    ///   - location: Position in Koordinaten von `view`
    ///   - completed: `true` = „Pfad abgeschlossen“ (z. B. gerade Linie),
    ///     sonst „Ausrichtung“ (Einrasten eines Schritts).
    public static func pencilFeedback(in view: UIView?, at location: CGPoint? = nil, completed: Bool = false) {
        guard let view else { return }
        if #available(iOS 17.5, *) {
            let host: UIView = view.window ?? view
            let generator: UICanvasFeedbackGenerator
            if let existing = canvasGenerators.object(forKey: host) as? UICanvasFeedbackGenerator {
                generator = existing
            } else {
                generator = UICanvasFeedbackGenerator(view: host)
                canvasGenerators.setObject(generator, forKey: host)
            }
            let point: CGPoint
            if let location {
                point = view.convert(location, to: host)
            } else if let last = lastPencilWindowLocation, host is UIWindow {
                point = last
            } else {
                point = view.convert(CGPoint(x: view.bounds.midX, y: view.bounds.midY), to: host)
            }
            if completed {
                generator.pathCompleted(at: point)
            } else {
                generator.alignmentOccurred(at: point)
            }
            generator.prepare()
        }
    }

    /// Einrasten (Undo-Scrub, gerade Linie). Vibriert den Apple Pencil Pro
    /// über `UICanvasFeedbackGenerator` und zusätzlich (falls vorhanden) das Gerät.
    public static func pencilSnap(intensity: CGFloat = 1.0) {
        let clamped = min(1, max(0.4, intensity))
        pencilFeedback(in: feedbackView)
        if preparedPencilSnap == nil {
            let generator = UIImpactFeedbackGenerator(style: .rigid)
            generator.prepare()
            preparedPencilSnap = generator
        }
        preparedPencilSnap?.impactOccurred(intensity: clamped)
        preparedPencilSnap?.prepare()
    }

    /// Warn-Feedback (z.B. vor dem Leeren einer Seite).
    public static func warning() {
        notificationGenerator.prepare()
        notificationGenerator.notificationOccurred(.warning)
    }

    /// Erfolgs-Feedback.
    public static func success() {
        notificationGenerator.prepare()
        notificationGenerator.notificationOccurred(.success)
    }
}
