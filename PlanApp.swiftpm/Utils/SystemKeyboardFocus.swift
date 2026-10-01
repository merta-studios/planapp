import UIKit
#if DEBUG
import os
#if canImport(GameController)
import GameController
#endif
#endif

/// Ereignisgesteuerte Fokus-Anforderung für UIKit-Texteingaben, die über
/// `UIViewRepresentable` in SwiftUI eingebettet sind.
///
/// ## Warum es diesen Helfer gibt
///
/// `becomeFirstResponder()` ist kein „Tastatur anzeigen"-Befehl. UIKit blendet
/// die Bildschirmtastatur nur ein, wenn **alle** folgenden Bedingungen erfüllt
/// sind:
///
/// 1. Die View hängt in einer `UIWindow`-Hierarchie (`view.window != nil`).
///    In `makeUIView(context:)` ist das **noch nicht** der Fall – die View wird
///    erst danach vom SwiftUI-Host eingehängt. Ein dort abgesetztes
///    `becomeFirstResponder()` schlägt still fehl (Rückgabewert `false`).
/// 2. Das Fenster gehört zu einer `UIWindowScene` im Zustand
///    `.foregroundActive` und ist Key-Window. Während eines Szenen-Starts, beim
///    Zurückkehren aus dem Hintergrund oder während ein Sheet eingeblendet
///    wird, trifft das kurzzeitig nicht zu.
/// 3. Die View ist interaktiv (`isUserInteractionEnabled`, nicht `isHidden`).
///
/// Ist eine Bedingung nicht erfüllt, kann UIKit trotzdem einen Cursor
/// darstellen (die Textauswahl ist unabhängig von der Eingabeansicht) – genau
/// das ist das gemeldete Symptom „Cursor sichtbar, aber keine Tastatur".
///
/// Statt die Anfrage mit Timern (`asyncAfter`) zu wiederholen, merkt sich
/// dieser Helfer eine offene Anfrage und versucht es **ereignisgesteuert**
/// erneut: beim Einhängen ins Fenster (`didMoveToWindow`), wenn das Fenster
/// Key-Window wird und wenn die Szene aktiv wird. Danach wird die Anfrage
/// verworfen. Dadurch gibt es keine „nachlaufenden" Fokus-Anfragen mehr,
/// nachdem ein Textfeld beendet oder entfernt wurde.
///
/// ## Hinweis zur externen Hardware-Tastatur
///
/// Ist eine Hardware-Tastatur (Magic Keyboard, Smart Keyboard Folio,
/// Bluetooth-Tastatur) gekoppelt, **unterdrückt iPadOS die Bildschirmtastatur
/// absichtlich**. Sichtbar ist dann nur die schmale Kurzbefehlleiste am
/// unteren Rand. Das ist kein Fehler der App und lässt sich mit öffentlichen
/// APIs auch nicht übersteuern. In Debug-Builds protokolliert
/// ``KeyboardFocusDiagnostics`` deshalb, ob eine Hardware-Tastatur erkannt
/// wurde, damit dieser Fall bei Fehlerberichten nicht mit einem echten
/// Fokus-Problem verwechselt wird.
final class SystemKeyboardFocusRequester {

    /// Gründe, aus denen ein Fokusversuch (noch) nicht erfolgreich war.
    enum Blocker: String {
        case viewDeallocated
        case notInteractive
        case notInWindow
        case noWindowScene
        case sceneNotActive
        case cannotBecomeFirstResponder
        case rejectedByUIKit
    }

    private weak var view: UIView?
    private var isPending = false
    private var observerTokens: [NSObjectProtocol] = []
    private let debugLabel: String

    init(view: UIView, debugLabel: String) {
        self.view = view
        self.debugLabel = debugLabel
    }

    deinit {
        let center = NotificationCenter.default
        for token in observerTokens {
            center.removeObserver(token)
        }
    }

    /// Fordert den First-Responder-Status (und damit die Systemtastatur) an.
    ///
    /// Gelingt das sofort, ist nichts weiter zu tun. Andernfalls bleibt die
    /// Anfrage offen und wird genau dann wiederholt, wenn sich eine der
    /// Voraussetzungen tatsächlich ändert – nicht nach einer geratenen Zeit.
    @discardableResult
    func requestFocus() -> Bool {
        isPending = true
        if attemptFocus() {
            return true
        }
        // Nur wenn die Anfrage wirklich noch offen ist, auf die passenden
        // Systemereignisse warten.
        if isPending {
            installObservers()
        }
        return false
    }

    /// Verwirft eine noch offene Fokus-Anfrage.
    ///
    /// Muss aufgerufen werden, sobald das Feld die Bearbeitung beendet, aus der
    /// View-Hierarchie entfernt oder gelöscht wird. So kann keine verzögerte
    /// Anfrage später eine fremde Tastatur öffnen.
    func cancelPendingFocus() {
        isPending = false
        removeObservers()
    }

    /// Aus `UIView.didMoveToWindow()` aufzurufen.
    func viewDidMoveToWindow() {
        guard isPending else { return }
        if view?.window == nil {
            // Beim Aushängen aus dem Fenster bleibt die Anfrage bewusst offen:
            // SwiftUI hängt Views beim Layout gelegentlich kurz um. Die
            // Observer sorgen dafür, dass es danach erneut versucht wird.
            return
        }
        _ = attemptFocus()
    }

    // MARK: - Intern

    @discardableResult
    private func attemptFocus() -> Bool {
        guard isPending else { return true }

        guard let view else {
            log(.viewDeallocated)
            finish()
            return false
        }
        guard view.isUserInteractionEnabled, !view.isHidden else {
            log(.notInteractive)
            return false
        }
        guard let window = view.window else {
            log(.notInWindow)
            return false
        }
        guard let scene = window.windowScene else {
            log(.noWindowScene)
            return false
        }
        guard scene.activationState == .foregroundActive else {
            log(.sceneNotActive)
            return false
        }

        // Ein nicht-aktives Fenster (z. B. direkt nach dem Einblenden eines
        // Sheets) nimmt zwar den First Responder an, bekommt aber keine
        // Tastatur. Deshalb vorher ausdrücklich zum Key-Window machen.
        if !window.isKeyWindow {
            window.makeKey()
        }

        if view.isFirstResponder {
            finish()
            return true
        }
        guard view.canBecomeFirstResponder else {
            log(.cannotBecomeFirstResponder)
            return false
        }
        guard view.becomeFirstResponder() else {
            log(.rejectedByUIKit)
            return false
        }

        finish()
        return true
    }

    private func finish() {
        isPending = false
        removeObservers()
    }

    private func installObservers() {
        guard observerTokens.isEmpty else { return }

        let center = NotificationCenter.default
        let names: [Notification.Name] = [
            UIWindow.didBecomeKeyNotification,
            UIScene.didActivateNotification,
            UIApplication.didBecomeActiveNotification
        ]

        observerTokens = names.map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                guard let self, self.isPending else { return }
                _ = self.attemptFocus()
            }
        }
    }

    private func removeObservers() {
        guard !observerTokens.isEmpty else { return }
        let center = NotificationCenter.default
        for token in observerTokens {
            center.removeObserver(token)
        }
        observerTokens.removeAll()
    }

    private func log(_ blocker: Blocker) {
        #if DEBUG
        KeyboardFocusDiagnostics.logDeferredFocus(label: debugLabel, blocker: blocker)
        #endif
    }
}

#if DEBUG
/// Diagnose-Ausgaben rund um den Tastaturfokus. Ausschließlich in
/// Debug-Builds aktiv – Release-Builds enthalten keinerlei Logging.
enum KeyboardFocusDiagnostics {
    private static let logger = Logger(
        subsystem: "com.planapp.stundenplan",
        category: "keyboard-focus"
    )

    /// Ob aktuell eine externe Hardware-Tastatur gekoppelt ist. In diesem Fall
    /// blendet iPadOS die Bildschirmtastatur bewusst nicht ein.
    static var hasHardwareKeyboard: Bool {
        #if canImport(GameController)
        return GCKeyboard.coalesced != nil
        #else
        return false
        #endif
    }

    static func logDeferredFocus(label: String, blocker: SystemKeyboardFocusRequester.Blocker) {
        let hardware = hasHardwareKeyboard ? "ja" : "nein"
        logger.debug(
            "Fokus vertagt – \(label, privacy: .public): \(blocker.rawValue, privacy: .public), Hardware-Tastatur: \(hardware, privacy: .public)"
        )
    }
}
#endif
