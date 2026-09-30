import SwiftUI
import UIKit

/// UIKit-basiertes mehrzeiliges Textfeld (`UITextView`) für die Textfelder auf
/// der Zeichenfläche. Gegenüber dem SwiftUI-`TextField` garantiert es, dass
/// die Bildschirmtastatur zuverlässig erscheint (`becomeFirstResponder`), und
/// unterstützt weiterhin Scribble mit dem Apple Pencil.
///
/// Der Text wird bewusst als **Wert** übergeben und über `onChangeText`
/// zurückgemeldet (kein `@Binding` in ein Array-Element). So kann das Feld
/// jederzeit gefahrlos aus der Ansicht entfernt werden – auch während die
/// Tastatur noch offen ist.
struct NoteTextEditor: UIViewRepresentable {
    let text: String
    let fontSize: CGFloat
    /// Farbe des Textes (über die Farb-Slots der Werkzeugleiste änderbar).
    let textColor: UIColor
    /// Ob das Feld gerade bearbeitet wird (Fokus halten/aufheben).
    let isEditing: Bool
    /// Wird bei jeder Texteingabe aufgerufen.
    let onChangeText: (String) -> Void
    /// Wird aufgerufen, wenn die Bearbeitung nativ endet (z. B. Tastatur weg).
    let onEndEditing: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> CustomNoteTextView {
        let textView = CustomNoteTextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.isOpaque = false
        textView.isScrollEnabled = false
        textView.font = .systemFont(ofSize: max(1, fontSize))
        // Text liegt auf dem festen weißen Papier und darf nicht mit dem
        // globalen Dark-Mode-Farbschema weiß werden.
        textView.textColor = textColor
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainer.widthTracksTextView = true
        textView.autocorrectionType = .default
        textView.autocapitalizationType = .sentences
        textView.keyboardDismissMode = .none
        // Immer die Apple-Systemtastatur verwenden; keine alte Eingabeansicht
        // vom PencilKit-Canvas übernehmen.
        textView.inputView = nil
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.setContentHuggingPriority(.required, for: .vertical)
        textView.text = text

        textView.onWindowAttached = { [weak textView, weak coordinator = context.coordinator] in
            guard let textView,
                  let coordinator,
                  !coordinator.isDismantled,
                  coordinator.parent.isEditing else { return }
            DispatchQueue.main.async {
                guard coordinator.parent.isEditing, !coordinator.isDismantled else { return }
                textView.requestSystemKeyboard()
            }
        }

        if isEditing {
            let coordinator = context.coordinator
            DispatchQueue.main.async { [weak textView, weak coordinator] in
                guard let textView,
                      let coordinator,
                      !coordinator.isDismantled,
                      coordinator.parent.isEditing,
                      textView.window != nil else { return }
                textView.requestSystemKeyboard()
            }
        }

        return textView
    }

    func updateUIView(_ uiView: CustomNoteTextView, context: Context) {
        context.coordinator.parent = self

        let resolvedFontSize = max(1, fontSize)
        if uiView.font?.pointSize != resolvedFontSize {
            uiView.font = .systemFont(ofSize: resolvedFontSize)
        }
        if uiView.textColor != textColor {
            uiView.textColor = textColor
        }

        // Externe Änderungen (Undo/Redo) auch während der Bearbeitung anzeigen,
        // ohne die Cursor-Position zu zerstören – aber nie mitten in einer
        // laufenden IME-Eingabe.
        if uiView.text != text,
           !context.coordinator.isApplyingExternalChange,
           uiView.markedTextRange == nil {
            context.coordinator.isApplyingExternalChange = true
            let selectedRange = uiView.selectedRange
            uiView.text = text
            let length = (text as NSString).length
            // UIKit kann während des Ein-/Ausblendens kurz NSNotFound oder
            // eine negative Cursorposition liefern. Niemals eine ungültige
            // NSRange an UITextView zurückgeben – das endet in einer
            // Objective-C Exception und damit in einem kompletten App-Crash.
            let location = max(0, min(selectedRange.location, length))
            uiView.selectedRange = NSRange(location: location, length: 0)
            context.coordinator.isApplyingExternalChange = false
        }

        if isEditing, !uiView.isFirstResponder {
            let coordinator = context.coordinator
            DispatchQueue.main.async { [weak uiView, weak coordinator] in
                guard let uiView,
                      let coordinator,
                      !coordinator.isDismantled,
                      coordinator.parent.isEditing,
                      uiView.window != nil else { return }
                uiView.requestSystemKeyboard()
            }
        } else if !isEditing, uiView.isFirstResponder {
            uiView.resignFirstResponder()
        }
    }

    /// Aufräumen, bevor die View entfernt wird: Ein noch aktiver First
    /// Responder würde sonst nach dem Entfernen weiter Delegate-Aufrufe
    /// auslösen.
    static func dismantleUIView(_ uiView: CustomNoteTextView, coordinator: Coordinator) {
        coordinator.isDismantled = true
        uiView.onWindowAttached = nil
        uiView.delegate = nil
        if uiView.isFirstResponder {
            uiView.resignFirstResponder()
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: NoteTextEditor
        var isApplyingExternalChange = false
        var isDismantled = false

        init(_ parent: NoteTextEditor) {
            self.parent = parent
        }

        func textViewShouldBeginEditing(_ textView: UITextView) -> Bool {
            (textView as? CustomNoteTextView)?.prepareForSystemKeyboard()
            return true
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            guard !isDismantled else { return }
            // Wie bei den einzeiligen Einstellungsfeldern die native
            // Systemtastatur nach dem Fokuswechsel ausdrücklich neu laden.
            (textView as? CustomNoteTextView)?.requestSystemKeyboard()
        }

        func textViewDidChange(_ textView: UITextView) {
            guard !isApplyingExternalChange, !isDismantled else { return }
            let newText = textView.text ?? ""
            guard newText != parent.text else { return }
            parent.onChangeText(newText)
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            guard !isDismantled else { return }
            let callback = parent.onEndEditing
            DispatchQueue.main.async {
                callback()
            }
        }
    }
}

final class CustomNoteTextView: UITextView {
    var onWindowAttached: (() -> Void)?

    override var canBecomeFirstResponder: Bool { true }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            onWindowAttached?()
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        prepareForSystemKeyboard()
        super.touchesBegan(touches, with: event)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        requestSystemKeyboard()
    }

    func prepareForSystemKeyboard() {
        inputView = nil
    }

    /// Fordert neben dem First-Responder-Status ausdrücklich die native
    /// iPadOS-/iOS-Tastatur an. Das behebt den Zustand „Cursor sichtbar,
    /// Tastatur fehlt", der in SwiftUI-Overlays mit PencilKit auftreten kann.
    func requestSystemKeyboard() {
        guard isEditable, isUserInteractionEnabled, window != nil else { return }

        prepareForSystemKeyboard()
        if !isFirstResponder {
            _ = becomeFirstResponder()
        }
        guard isFirstResponder else { return }

        for delay in [0.0, 0.05, 0.18] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self, self.isFirstResponder, self.window != nil else { return }
                self.inputView = nil
                self.reloadInputViews()
            }
        }
    }
}
