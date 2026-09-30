import UIKit

/// Zentrale, leichtgewichtige Haptik-Helfer. Sie werden bei Tipp- und
/// Auswahl-Interaktionen ausgelöst – auch wenn mit dem Apple Pencil auf
/// Bedienelemente getippt wird, gibt es so immer eine spürbare Rückmeldung.
public enum Haptics {
    private static let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private static let selectionGenerator = UISelectionFeedbackGenerator()
    private static let notificationGenerator = UINotificationFeedbackGenerator()

    /// Kurzes, weiches Klick-Feedback (Buttons, Blöcke, Textfelder).
    public static func tap() {
        lightImpact.prepare()
        lightImpact.impactOccurred(intensity: 0.85)
    }

    /// Feines Auswahl-Feedback (Werkzeug- oder Farbwechsel).
    public static func select() {
        selectionGenerator.prepare()
        selectionGenerator.selectionChanged()
    }

    /// Warn-Feedback (z.B. vor dem Leeren einer Seite).
    public static func warning() {
        notificationGenerator.notificationOccurred(.warning)
    }

    /// Erfolgs-Feedback.
    public static func success() {
        notificationGenerator.notificationOccurred(.success)
    }
}
