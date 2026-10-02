import AudioToolbox
import UIKit

/// Feedback beim Tippen auf der App-Tastatur – nach dem Vorbild von Apples
/// eigener Bildschirmtastatur.
///
/// **Wie Apple es macht:** Apple gibt bei jedem Tastendruck eine feine Haptik
/// über die Taptic Engine aus (Einstellungen → Töne & Haptik → Tastatur-
/// Feedback, seit iOS 16 als Nutzer-Option) und spielt – wenn eingeschaltet –
/// zusätzlich ein leises Klickgeräusch.
///
/// **Warum hier auch der Klang kommt:** Das iPad hat (außer dem Apple Pencil
/// Pro) keinen Taptic Engine; `UIImpactFeedbackGenerator` bleibt dort
/// wirkungslos. Das hörbare Klickgeräusch ist deshalb auf dem iPad das
/// eigentliche Feedback. Die Lautstärke folgt der Systemlautstärke, und der
/// Stummschalter schaltet es mit ab. Über die Einstellung „Tastatur &
/// Eingabe“ lässt es sich komplett abschalten.
public enum KeyboardFeedback {
    /// Systemklang „Tock“ – derselbe Klick, den iPadOS bei der eigenen
    /// Tastatur verwendet. (Der Klang ist ein System-Sound; es gibt dafür
    /// keine öffentlich dokumentierte Konstante.)
    private static let clickSoundID: SystemSoundID = 1104

    /// Wird bei jedem Tastendruck der App-Tastatur aufgerufen.
    public static func keyPress() {
        guard AppKeyboardPreferences.shared.feedbackEnabled else { return }
        preview()
    }

    /// Spielt das Feedback einmal ab – bewusst auch dann, wenn es gerade
    /// abgeschaltet ist: So lässt es sich in den Einstellungen vorher anhören.
    public static func preview() {
        // Feine Haptik – auf iPhones und mit Apple Pencil Pro spürbar, auf
        // iPads ohne Taptic Engine ohne Wirkung.
        Haptics.select()

        // Leiser Klick wie bei Apples Tastatur.
        AudioServicesPlaySystemSound(clickSoundID)
    }
}
