import UIKit

/// Zentrale, leichtgewichtige Haptik-Helfer. Sie werden bei Tipp- und
/// Auswahl-Interaktionen ausgelöst – auch wenn mit dem Apple Pencil auf
/// Bedienelemente getippt wird, gibt es so immer eine spürbare Rückmeldung.
public enum Haptics {
    private static let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private static let selectionGenerator = UISelectionFeedbackGenerator()
    private static let notificationGenerator = UINotificationFeedbackGenerator()

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
