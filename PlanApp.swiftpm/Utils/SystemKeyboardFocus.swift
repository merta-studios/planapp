import UIKit
#if DEBUG
import os
#if canImport(GameController)
import GameController
#endif
#endif

/// Koordiniert eine programmatische Fokus-Anfrage für eine UIKit-Texteingabe,
/// die in SwiftUI eingebettet ist.
///
/// Ein Aufruf in `makeUIView` erfolgt zu früh: Die View hat zu diesem Zeitpunkt
/// noch kein Fenster und ist noch nicht beim Text-Input-System registriert.
/// Der Requester merkt sich die Anfrage deshalb bis zum Einhängen ins aktive
/// Key-Window und versucht den Fokus zusätzlich einmal im nächsten Main-Runloop.
/// Dieser einzelne Runloop-Schritt ist wichtig für frisch von SwiftUI erzeugte
/// `UIViewRepresentable`s: `didMoveToWindow()` kann vor dem Abschluss der
/// aktuellen Hosting-Transaktion eintreffen.
///
/// Es gibt ausdrücklich weder `reloadInputViews()` noch eine Timer-/Retry-
/// Schleife. Beides kann die laufende Tastatur-Animation abbrechen und führte
/// zuvor zum Zustand „Cursor sichtbar, aber keine Bildschirmtastatur“.
final class SystemKeyboardFocusRequester {

    /// Gründe, aus denen ein Fokusversuch (noch) nicht erfolgreich war.
    enum Blocker: String {
        case viewDeallocated
        case notInteractive
        case notInWindow
        case noWindowScene
        case sceneNotActive
        case windowNotKey
        case cannotBecomeFirstResponder
        case rejectedByUIKit
    }

    private weak var view: UIView?
    private var isPending = false
    private var isAttemptScheduled = false
    private var observerTokens: [NSObjectProtocol] = []
    private let debugLabel: String

    init(view: UIView, debugLabel: String) {
        self.view = view
        self.debugLabel = debugLabel
    }

    deinit {
        removeObservers()
    }

    /// Fordert den First-Responder-Status an. Ist die View noch nicht bereit,
    /// bleibt die Anfrage bis zum passenden UIKit-Ereignis aktiv.
    @discardableResult
    func requestFocus() -> Bool {
        isPending = true

        if attemptFocus() {
            return true
        }

        // Bei einer gerade von SwiftUI eingebauten View ist der nächste
        // Main-Runloop der früheste Zeitpunkt, an dem die Hosting-Transaktion
        // sicher abgeschlossen ist. Das ist eine einzelne, abbrechbare
        // Übergabe – keine zeitbasierte Retry-Schleife.
        scheduleNextRunLoopAttempt()
        installObservers()
        return false
    }

    /// Verwirft eine noch offene Fokus-Anfrage. Das muss beim Ende einer
    /// Bearbeitung und beim Entfernen der View passieren, damit kein späteres
    /// Scene-/Window-Ereignis ein bereits geschlossenes Feld wieder fokussiert.
    func cancelPendingFocus() {
        isPending = false
        isAttemptScheduled = false
        removeObservers()
    }

    /// Aus `UIView.didMoveToWindow()` aufrufen. Der Fokusversuch selbst läuft
    /// bewusst im nächsten Main-Runloop, siehe Typ-Dokumentation.
    func viewDidMoveToWindow() {
        guard isPending, view?.window != nil else { return }
        scheduleNextRunLoopAttempt()
    }

    // MARK: - Intern

    /// Führt genau einen Fokusversuch aus. Falls etwa ein Sheet noch nicht sein
    /// Key-Window erhalten hat, bleibt der Request offen und die registrierten
    /// UIKit-Benachrichtigungen stoßen später einen neuen einzelnen Versuch an.
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

        // Das Key-Window wird niemals gewaltsam gewechselt. `makeKey()` in
        // einem Eingabefeld kann gerade präsentierte Sheets vom normalen
        // UIKit-Responder-Ablauf abkoppeln. Stattdessen warten wir auf das
        // echte `UIWindow.didBecomeKeyNotification` des Host-Fensters.
        guard window.isKeyWindow else {
            log(.windowNotKey)
            return false
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

    /// Wartet genau bis zur nächsten Main-Loop-Iteration. Die Closure prüft
    /// danach erneut `isPending`; ein abgebautes Feld kann daher nicht mehr
    /// ungewollt zum First Responder werden.
    private func scheduleNextRunLoopAttempt() {
        guard isPending, !isAttemptScheduled else { return }
        isAttemptScheduled = true

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isAttemptScheduled = false
            guard self.isPending else { return }

            _ = self.attemptFocus()
            if self.isPending {
                self.installObservers()
            }
        }
    }

    private func finish() {
        isPending = false
        isAttemptScheduled = false
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
                self.scheduleNextRunLoopAttempt()
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
    /// blendet iPadOS die Bildschirmtastatur bewusst nicht automatisch ein.
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
