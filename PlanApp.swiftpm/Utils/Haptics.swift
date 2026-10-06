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
    /// Vor dem Einrasten vorbereitet, sonst kommt die Pencil-Vibration nicht an.
    private static var preparedPencilSnap: UIImpactFeedbackGenerator?

    /// Merkt sich die Ansicht unter dem Stift und bereitet den Generator vor.
    /// Ein frischer Generator erst im Moment des Einrastens vibriert den Pencil nicht.
    public static func attachFeedbackView(_ view: UIView?) {
        guard let view else { return }
        if feedbackView === view, preparedPencilSnap != nil { return }
        feedbackView = view
        if #available(iOS 17.5, *), view.window != nil {
            let generator = UIImpactFeedbackGenerator(style: .rigid, view: view)
            generator.prepare()
            preparedPencilSnap = generator
        } else {
            let generator = UIImpactFeedbackGenerator(style: .rigid)
            generator.prepare()
            preparedPencilSnap = generator
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

    /// Einrasten (Undo-Scrub, gerade Linie). Mit gesetzter Feedback-Ansicht
    /// vibriert der Apple Pencil, sonst das Gerät.
    public static func pencilSnap(intensity: CGFloat = 1.0) {
        let clamped = min(1, max(0.4, intensity))
        if preparedPencilSnap == nil {
            attachFeedbackView(feedbackView)
        }
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
