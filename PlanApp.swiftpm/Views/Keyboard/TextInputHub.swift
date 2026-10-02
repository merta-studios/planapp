import SwiftUI
import UIKit
import Combine

#if canImport(GameController)
import GameController
#endif

// MARK: - Einstellung

/// Verhalten der app-eigenen Bildschirmtastatur.
public enum AppKeyboardMode: String, CaseIterable, Identifiable {
    /// Nur einblenden, wenn das System keine (vollständige) Tastatur zeigt.
    case automatic
    /// Bei jedem fokussierten Textfeld einblenden – auch zusätzlich zum System.
    case always
    /// Keine app-eigene Tastatur; es gilt ausschließlich das Systemverhalten.
    case off

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .automatic: return "Automatisch"
        case .always: return "Immer anzeigen"
        case .off: return "Nur Systemtastatur"
        }
    }

    public var detail: String {
        switch self {
        case .automatic:
            return "Erscheint nur, wenn iPadOS keine vollständige Tastatur einblendet. Empfohlen."
        case .always:
            return "Erscheint bei jedem Textfeld, auch wenn die Systemtastatur sichtbar ist."
        case .off:
            return "Die App zeigt keine eigene Tastatur."
        }
    }
}

/// Speichert die Tastatur-Einstellung dauerhaft in den UserDefaults.
public final class AppKeyboardPreferences: ObservableObject {
    public static let shared = AppKeyboardPreferences()

    private static let storageKey = "planapp.appKeyboard.mode"

    @Published public var mode: AppKeyboardMode {
        didSet {
            guard oldValue != mode else { return }
            UserDefaults.standard.set(mode.rawValue, forKey: Self.storageKey)
        }
    }

    private init() {
        let stored = UserDefaults.standard.string(forKey: Self.storageKey)
        self.mode = stored.flatMap(AppKeyboardMode.init(rawValue:)) ?? .automatic
    }
}

// MARK: - Hub

/// Zentrale Schaltstelle für alle Texteingaben der App.
///
/// ## Warum es diesen Hub gibt
///
/// In Apps, die in **Swift Playgrounds auf dem iPad** laufen, liefert iPadOS
/// die Texteingabe nicht an die App: Ein Tippen setzt zwar den Cursor, aber
/// es erscheint weder die Bildschirmtastatur noch kommen Zeichen einer
/// angeschlossenen Hardware-Tastatur an. Einfügen aus der Zwischenablage
/// funktioniert – deshalb war „Text kopieren und einsetzen“ bisher der einzige
/// Ausweg.
///
/// Der Fehler ist von Apple seit **iPadOS 16.1** dokumentiert
/// (Apple Developer Forums, Thread 715614, „iPad OS 16.1, Playgrounds and
/// input fields“) und wurde auch für iPadOS 18 und iPadOS 26 gemeldet. Er
/// steckt im Playgrounds-Host, nicht in der App: `becomeFirstResponder()`,
/// Wartezeiten oder `reloadInputViews()` können ihn nicht beheben – genau
/// deshalb sind frühere „Fokus-Fixes“ wirkungslos geblieben.
///
/// ## Was hier stattdessen passiert
///
/// 1. Der Hub beobachtet, welches Textfeld gerade bearbeitet wird
///    (`UITextField`/`UITextView` – dazu gehört auch das SwiftUI-`TextField`).
/// 2. Er beobachtet die Tastatur-Benachrichtigungen des Systems.
/// 3. Bleibt die Systemtastatur aus, blendet die App ihre **eigene Tastatur**
///    ein (`AppKeyboardView`). Getippt wird dabei über die öffentliche
///    `UIKeyInput`-Schnittstelle direkt in das fokussierte Feld – dieselbe
///    Schnittstelle, die auch die echte Tastatur benutzt.
///
/// Damit ist die Eingabe unabhängig davon, ob iPadOS in dieser Umgebung
/// Tastatur und Tastenereignisse an die App weiterleitet.
public final class TextInputHub: ObservableObject {

    public static let shared = TextInputHub()

    /// Ab dieser Höhe gilt die Systemtastatur als wirklich sichtbar. Der
    /// schmale Kurzbefehl-Streifen, den iPadOS bei angeschlossener
    /// Hardware-Tastatur zeigt, ist nur ca. 44 pt hoch und darf die
    /// app-eigene Tastatur nicht unterdrücken.
    private static let minimumSystemKeyboardHeight: CGFloat = 120

    // MARK: Veröffentlichter Zustand

    /// Ob die app-eigene Tastatur gerade eingeblendet ist.
    @Published public private(set) var isAppKeyboardVisible = false
    /// Ob das System eine vollständige Bildschirmtastatur zeigt.
    @Published public private(set) var isSystemKeyboardVisible = false
    /// Ob aktuell ein Textfeld aktiv ist (Fokus oder app-eigene Bearbeitung).
    @Published public private(set) var hasActiveInput = false
    /// Zählt jeden Wechsel des aktiven Felds. Die Tastatur richtet damit ihre
    /// Umschalttaste und Ebene am neuen Feld aus.
    @Published public private(set) var activationCounter = 0

    // MARK: Diagnose (Einstellungen → Tastatur & Eingabe)

    @Published public private(set) var isWindowKey = true
    @Published public private(set) var didRepairKeyWindow = false
    @Published public private(set) var lastEventText = "Noch kein Textfeld benutzt"
    @Published public private(set) var activeInputKind = "–"

    /// Ob eine Hardware-Tastatur (Magic Keyboard, Bluetooth usw.) erkannt wird.
    public var hasHardwareKeyboard: Bool {
        #if canImport(GameController)
        return GCKeyboard.coalesced != nil
        #else
        return false
        #endif
    }

    // MARK: Intern

    private weak var focusedInput: UIView?
    private weak var registeredInput: UIView?
    private var observers: [NSObjectProtocol] = []
    private var revealWorkItem: DispatchWorkItem?
    private var didAttemptKeyWindowRepair = false
    private var keyboardHostCount = 0
    /// Nach „Ausblenden“ soll die Tastatur für dieses Feld nicht sofort wieder
    /// auftauchen – erst beim nächsten Fokuswechsel.
    private var isRevealSuppressed = false
    /// Bündelt die First-Responder-Suche nach schnellen Tippfolgen.
    private var isAdoptScheduled = false

    /// Das Feld, das gerade Text erhalten soll: bevorzugt das echte
    /// First-Responder-Feld, sonst das ausdrücklich angemeldete Feld
    /// (Zeichenflächen-Textfeld).
    private var currentInputView: UIView? {
        focusedInput ?? registeredInput
    }

    /// Schreibweise, die das aktive Feld erwartet (für die Umschalt-Taste).
    private var activeAutocapitalization: UITextAutocapitalizationType {
        if let field = currentInputView as? UITextField { return field.autocapitalizationType }
        if let view = currentInputView as? UITextView { return view.autocapitalizationType }
        return .sentences
    }

    /// Ob das aktive Feld mit einem Großbuchstaben beginnen soll.
    public var prefersUppercaseStart: Bool {
        switch activeAutocapitalization {
        case .none: return false
        case .sentences, .words, .allCharacters: return true
        @unknown default: return true
        }
    }

    /// Ob nach einem Satzzeichen wieder groß geschrieben wird (Sentences-Modus).
    public var isSentenceMode: Bool {
        switch activeAutocapitalization {
        case .sentences: return true
        default: return false
        }
    }

    private init() {
        installObservers()
    }

    // MARK: - Beobachtung

    private func installObservers() {
        let center = NotificationCenter.default
        let names: [Notification.Name] = [
            UITextField.textDidBeginEditingNotification,
            UITextField.textDidEndEditingNotification,
            UITextView.textDidBeginEditingNotification,
            UITextView.textDidEndEditingNotification,
            UIResponder.keyboardWillShowNotification,
            UIResponder.keyboardDidShowNotification,
            UIResponder.keyboardWillChangeFrameNotification,
            UIResponder.keyboardWillHideNotification,
            UIResponder.keyboardDidHideNotification,
            UIApplication.didBecomeActiveNotification
        ]

        observers = names.map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                self?.handle(note)
            }
        }
    }

    private func handle(_ note: Notification) {
        let name = note.name

        if name == UITextField.textDidBeginEditingNotification || name == UITextView.textDidBeginEditingNotification {
            if let view = note.object as? UIView {
                activate(view, reason: "Fokus auf \(Self.kind(of: view))")
            }
        } else if name == UITextField.textDidEndEditingNotification || name == UITextView.textDidEndEditingNotification {
            if let view = note.object as? UIView {
                deactivate(view, reason: "Bearbeitung beendet")
            }
        } else if name == UIApplication.didBecomeActiveNotification {
            updateWindowKeyState()
        } else {
            handleSystemKeyboardNotification(note)
        }
    }

    // MARK: - Aktives Feld

    /// Meldet ein Feld als aktives Eingabeziel an. Wird automatisch über die
    /// Bearbeitungs-Benachrichtigungen von `UITextField`/`UITextView`
    /// aufgerufen – auch für die in SwiftUI eingebetteten Textfelder.
    public func activate(_ view: UIView, reason: String = "Feld aktiv") {
        guard view is UIKeyInput else { return }

        let isNewInput = focusedInput !== view
        focusedInput = view
        if let existing = registeredInput, existing !== view { registeredInput = nil }

        hasActiveInput = true
        activeInputKind = Self.kind(of: view)
        lastEventText = reason
        if isNewInput {
            activationCounter += 1
            isRevealSuppressed = false
        }
        updateWindowKeyState()
        repairKeyWindowIfNeeded()
        revealActiveInputInScrollView()
        scheduleAutomaticReveal()
    }

    /// Meldet ein app-eigenes Feld an (Zeichenflächen-Textfeld), das ohne
    /// System-Fokus bearbeitet wird.
    public func registerInput(_ view: UIView) {
        guard view is UIKeyInput else { return }
        guard registeredInput !== view else { return }
        registeredInput = view
        hasActiveInput = true
        activeInputKind = Self.kind(of: view)
        lastEventText = "Textfeld auf der Zeichenfläche"
        activationCounter += 1
        isRevealSuppressed = false
        updateWindowKeyState()
        scheduleAutomaticReveal()
    }

    /// Meldet ein Feld wieder ab.
    public func deactivate(_ view: UIView, reason: String = "Feld inaktiv") {
        if focusedInput === view { focusedInput = nil }
        if registeredInput === view { registeredInput = nil }
        if currentInputView == nil {
            lastEventText = reason
            activeInputKind = "–"
        }
        refreshActiveState()
    }

    private func refreshActiveState() {
        let isActive = currentInputView != nil
        if hasActiveInput != isActive { hasActiveInput = isActive }
        if !isActive {
            revealWorkItem?.cancel()
            hideAppKeyboard()
        }
    }

    /// Sicherheitsnetz: Falls eine Bearbeitung ohne Benachrichtigung beginnt,
    /// wird das aktuelle First-Responder-Feld nach einem Tipp gesucht.
    ///
    /// Aufrufe werden gebündelt, damit eine Folge schneller Tipps die
    /// Ansichts-Hierarchie nicht mehrfach durchsucht.
    public func adoptCurrentFirstResponderIfNeeded() {
        guard AppKeyboardPreferences.shared.mode != .off else { return }
        guard !isAdoptScheduled else { return }

        isAdoptScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isAdoptScheduled = false
            self.discardDetachedInputs()
            guard self.currentInputView == nil else { return }
            self.performFirstResponderSearch()
        }
    }

    /// Räumt Felder auf, die nicht mehr in einem Fenster hängen – z. B. nach
    /// dem Schließen eines Blatts. Ohne diese Prüfung könnte die app-eigene
    /// Tastatur ohne Eingabeziel stehen bleiben.
    private func discardDetachedInputs() {
        var didChange = false

        if let view = focusedInput, view.window == nil {
            focusedInput = nil
            didChange = true
        }
        if let view = registeredInput, view.window == nil {
            registeredInput = nil
            didChange = true
        }

        if didChange {
            refreshActiveState()
        }
    }

    private func performFirstResponderSearch() {
        guard currentInputView == nil else { return }

        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        for scene in scenes where scene.activationState == .foregroundActive {
            for window in scene.windows {
                if let responder = Self.firstResponder(in: window), responder is UIKeyInput {
                    activate(responder, reason: "Tippen erkannt")
                    return
                }
            }
        }
    }

    // MARK: - Tippen

    /// Fügt Text an der Cursorposition des aktiven Felds ein.
    public func insert(_ text: String) {
        guard !text.isEmpty, let input = currentInputView as? UIKeyInput else { return }
        input.insertText(text)
        notifyPlatformAboutTextChange()
    }

    /// Löscht ein Zeichen vor dem Cursor.
    public func deleteBackward() {
        guard let input = currentInputView as? UIKeyInput else { return }
        input.deleteBackward()
        notifyPlatformAboutTextChange()
    }

    /// Fügt den Inhalt der Zwischenablage ein.
    public func pasteFromPasteboard() {
        guard let string = UIPasteboard.general.string, !string.isEmpty else { return }
        insert(string)
    }

    /// Ob die Zwischenablage Text enthält (für die Einfügen-Taste).
    public var canPaste: Bool {
        UIPasteboard.general.hasStrings
    }

    /// Verschiebt den Cursor (negative Werte nach links).
    public func moveCaret(by offset: Int) {
        guard let textInput = currentInputView as? UITextInput,
              let range = textInput.selectedTextRange,
              let position = textInput.position(from: range.start, offset: offset),
              let newRange = textInput.textRange(from: position, to: position) else { return }
        textInput.selectedTextRange = newRange
    }

    /// Beendet die Bearbeitung („Fertig“ auf der app-eigenen Tastatur).
    public func dismissActiveInput() {
        hideAppKeyboard()
        guard let view = currentInputView else { return }
        _ = view.resignFirstResponder()
    }

    /// Nach einer programmatischen Änderung müssen die UIKit-/SwiftUI-Seiten
    /// erfahren, dass sich der Text geändert hat – die Systemtastatur macht das
    /// über den Ereignisweg, den es in Swift Playgrounds nicht gibt.
    private func notifyPlatformAboutTextChange() {
        guard let view = currentInputView else { return }

        // Doppelt abgesichert: Je nach Umgebung hängt die Aktualisierung der
        // SwiftUI-Bindung am Control-Event oder an der Benachrichtigung. Beide
        // Wege sind idempotent und melden nur den bereits eingetragenen Text.
        if let textField = view as? UITextField {
            textField.sendActions(for: .editingChanged)
            NotificationCenter.default.post(name: UITextField.textDidChangeNotification, object: textField)
        } else if let textView = view as? UITextView {
            textView.delegate?.textViewDidChange?(textView)
            NotificationCenter.default.post(name: UITextView.textDidChangeNotification, object: textView)
        }
    }

    // MARK: - Tastatur ein-/ausblenden

    public func showAppKeyboard() {
        guard AppKeyboardPreferences.shared.mode != .off else { return }
        isRevealSuppressed = false
        guard !isAppKeyboardVisible else { return }
        withAnimation(.easeOut(duration: 0.22)) {
            isAppKeyboardVisible = true
        }
        lastEventText = "App-Tastatur eingeblendet"
        revealActiveInputInScrollView()
        // Nach dem Layout-Sprung noch einmal nachfassen, damit das Feld
        // sicher über der Tastatur liegt.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.revealActiveInputInScrollView()
        }
    }

    public func hideAppKeyboard() {
        guard isAppKeyboardVisible else { return }
        withAnimation(.easeOut(duration: 0.18)) {
            isAppKeyboardVisible = false
        }
    }

    /// Blendet die app-eigene Tastatur aus. Sie bleibt aus, bis ein Feld neu
    /// fokussiert wird – deshalb wird der Fokus hier zusätzlich aufgehoben,
    /// damit ein erneutes Tippen die Tastatur wieder hervorholt.
    public func suppressAppKeyboardForCurrentInput() {
        isRevealSuppressed = true
        revealWorkItem?.cancel()
        hideAppKeyboard()
        if let view = currentInputView {
            _ = view.resignFirstResponder()
        }
        lastEventText = "App-Tastatur ausgeblendet"
    }

    /// Vor Anzeige der App-Tastatur prüfen, ob sie überhaupt nötig ist.
    private func scheduleAutomaticReveal(after delay: TimeInterval = 0.7) {
        revealWorkItem?.cancel()
        guard AppKeyboardPreferences.shared.mode != .off else { return }
        guard !isRevealSuppressed else { return }

        let item = DispatchWorkItem { [weak self] in
            self?.performAutomaticReveal()
        }
        revealWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    private func performAutomaticReveal() {
        guard currentInputView != nil else { return }

        switch AppKeyboardPreferences.shared.mode {
        case .always:
            showAppKeyboard()
        case .off:
            hideAppKeyboard()
        case .automatic:
            if isSystemKeyboardVisible {
                hideAppKeyboard()
            } else {
                showAppKeyboard()
            }
        }
    }

    private func handleSystemKeyboardNotification(_ note: Notification) {
        let name = note.name

        if name == UIResponder.keyboardWillHideNotification || name == UIResponder.keyboardDidHideNotification {
            isSystemKeyboardVisible = false
        } else {
            let frame = (note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue ?? .zero
            isSystemKeyboardVisible = frame.height >= Self.minimumSystemKeyboardHeight
        }

        // Bei „Immer anzeigen“ bleibt die app-eigene Tastatur bewusst stehen:
        // sie sitzt dann direkt über der Systemtastatur.
        guard AppKeyboardPreferences.shared.mode != .always else { return }

        if isSystemKeyboardVisible {
            hideAppKeyboard()
        } else if currentInputView != nil {
            scheduleAutomaticReveal(after: 0.25)
        }
    }

    // MARK: - Fenster / Diagnose

    private func updateWindowKeyState() {
        guard let window = currentInputView?.window else { return }
        isWindowKey = window.isKeyWindow
    }

    /// „Cursor sichtbar, aber keine Tastatur“ ist klassisch für ein Fenster,
    /// das nicht das Key-Window ist. Genau in diesem Fehlerfall – und höchstens
    /// einmal pro App-Start – wird das eigene Fenster wieder zum Key-Window
    /// gemacht. Ist bereits ein Systemfenster (z. B. ein Alert) oberhalb,
    /// passiert nichts.
    private func repairKeyWindowIfNeeded() {
        guard !didAttemptKeyWindowRepair else { return }
        guard let view = currentInputView, let window = view.window, !window.isKeyWindow else { return }
        guard let scene = window.windowScene, scene.activationState == .foregroundActive else { return }

        let hasAlertWindow = scene.windows.contains { other in
            other !== window && other.isKeyWindow && other.windowLevel.rawValue >= UIWindow.Level.alert.rawValue
        }
        guard !hasAlertWindow else { return }

        didAttemptKeyWindowRepair = true
        didRepairKeyWindow = true
        lastEventText = "Fenster zum Key-Window gemacht"
        window.makeKey()
        isWindowKey = window.isKeyWindow
    }

    /// Schiebt das aktive Feld in den sichtbaren Bereich. Die Systemtastatur
    /// erledigt das automatisch – die app-eigene Tastatur hier von Hand.
    private func revealActiveInputInScrollView() {
        DispatchQueue.main.async { [weak self] in
            guard let view = self?.currentInputView,
                  let scrollView = Self.enclosingScrollView(of: view) else { return }
            let rect = view.convert(view.bounds, to: scrollView).insetBy(dx: 0, dy: -24)
            guard rect.isFinite, rect.width > 0, rect.height > 0 else { return }
            scrollView.scrollRectToVisible(rect, animated: true)
        }
    }

    // MARK: - Hosts (Settings-Ansicht, Zeichenfläche)

    public func keyboardHostDidAppear() {
        keyboardHostCount += 1
    }

    public func keyboardHostDidDisappear() {
        keyboardHostCount = max(0, keyboardHostCount - 1)

        // Nach dem Schließen eines Blatts (Einstellungen, Fach-/Lehrer-Blatt)
        // kann ein Feld kurz „aktiv“ bleiben, obwohl es schon verschwindet.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.discardDetachedInputs()
        }

        guard keyboardHostCount == 0 else { return }
        revealWorkItem?.cancel()
        isRevealSuppressed = false
        focusedInput = nil
        registeredInput = nil
        refreshActiveState()
    }

    // MARK: - Hilfsfunktionen

    private static func kind(of view: UIView) -> String {
        if view is UITextField { return "Texteingabe" }
        if view is UITextView { return "Mehrzeiliges Textfeld" }
        return String(describing: type(of: view))
    }

    private static func enclosingScrollView(of view: UIView) -> UIScrollView? {
        var current: UIView? = view.superview
        while let candidate = current {
            if let scrollView = candidate as? UIScrollView { return scrollView }
            current = candidate.superview
        }
        return nil
    }

    private static func firstResponder(in view: UIView) -> UIView? {
        if view.isFirstResponder { return view }
        for subview in view.subviews {
            if let found = firstResponder(in: subview) { return found }
        }
        return nil
    }
}
