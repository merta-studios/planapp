import SwiftUI
import UIKit

/// UIKit-basiertes mehrzeiliges Textfeld (`UITextView`) für die Textfelder auf
/// der Zeichenfläche. Unterstützt die Apple-Systemtastatur und weiterhin
/// Scribble mit dem Apple Pencil.
///
/// Der Text wird bewusst als **Wert** übergeben und über `onChangeText`
/// zurückgemeldet (kein `@Binding` in ein Array-Element). So kann das Feld
/// jederzeit gefahrlos aus der Ansicht entfernt werden – auch während die
/// Tastatur noch offen ist.
///
/// ## Fokus-Ablauf
///
/// Ein frisch erzeugtes Textfeld soll sofort die Tastatur öffnen. In
/// `makeUIView(context:)` hängt die View aber noch **nicht** im Fenster, ein
/// `becomeFirstResponder()` schlägt dort still fehl. Deshalb wird die Anfrage
/// über ``SystemKeyboardFocusRequester`` gestellt und ereignisgesteuert
/// nachgeholt, sobald die View in einem aktiven Key-Window hängt – ohne Timer
/// und ohne wiederholte `reloadInputViews()`-Aufrufe (die die Einblend-
/// Animation der Tastatur abbrechen und genau zum Zustand „Cursor sichtbar,
/// Tastatur fehlt" führen).
///
/// Beim Verlassen der Bearbeitung bzw. beim Entfernen der View wird eine evtl.
/// offene Anfrage ausdrücklich verworfen, damit später keine fremde Tastatur
/// aufspringt.
struct NoteTextEditor: UIViewRepresentable {
    let text: String
    let fontSize: CGFloat
    /// Schriftart der Textfelder (Einstellungen → Zeichnen).
    var fontStyle: NoteTextFontStyle = .system
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
        textView.isEditable = true
        textView.isSelectable = true
        textView.font = fontStyle.uiFont(size: max(1, fontSize))
        // Text liegt auf dem festen weißen Papier und darf nicht mit dem
        // globalen Dark-Mode-Farbschema weiß werden.
        textView.textColor = textColor
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainer.widthTracksTextView = true
        textView.autocorrectionType = .default
        textView.autocapitalizationType = .sentences
        textView.keyboardDismissMode = .none
        // `nil` ist der Normalzustand und bedeutet „Systemtastatur". Einmalig
        // gesetzt zur Dokumentation der Absicht; danach wird der Wert nicht
        // mehr angefasst, deshalb ist auch kein `reloadInputViews()` nötig.
        textView.inputView = nil
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.setContentHuggingPriority(.required, for: .vertical)
        textView.text = text

        if isEditing {
            // Wird automatisch nachgeholt, sobald die View im Fenster hängt.
            textView.requestSystemKeyboard()
        }

        return textView
    }

    func updateUIView(_ uiView: CustomNoteTextView, context: Context) {
        context.coordinator.parent = self

        let resolvedFont = fontStyle.uiFont(size: max(1, fontSize))
        if uiView.font?.pointSize != resolvedFont.pointSize
            || uiView.font?.fontName != resolvedFont.fontName {
            uiView.font = resolvedFont
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

        if isEditing {
            if !uiView.isFirstResponder {
                uiView.requestSystemKeyboard()
            }
        } else {
            uiView.cancelPendingKeyboardRequest()
            if uiView.isFirstResponder {
                uiView.resignFirstResponder()
            }
        }
    }

    /// Aufräumen, bevor die View entfernt wird: Ein noch aktiver First
    /// Responder oder eine offene Fokus-Anfrage würden sonst nach dem
    /// Entfernen weiterwirken.
    static func dismantleUIView(_ uiView: CustomNoteTextView, coordinator: Coordinator) {
        coordinator.isDismantled = true
        uiView.cancelPendingKeyboardRequest()
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

        func textViewDidBeginEditing(_ textView: UITextView) {
            // Fokus erreicht – eine evtl. noch offene Anfrage ist erledigt.
            (textView as? CustomNoteTextView)?.cancelPendingKeyboardRequest()
        }

        func textViewDidChange(_ textView: UITextView) {
            guard !isApplyingExternalChange, !isDismantled else { return }
            let newText = textView.text ?? ""
            guard newText != parent.text else { return }
            parent.onChangeText(newText)
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            guard !isDismantled else { return }
            (textView as? CustomNoteTextView)?.cancelPendingKeyboardRequest()
            let callback = parent.onEndEditing
            // Der Rückruf ändert SwiftUI-Zustand (`editingID`). Das darf nicht
            // mitten in der UIKit-Responder-Umschaltung passieren.
            DispatchQueue.main.async {
                callback()
            }
        }
    }
}

/// `UITextView` der Zeichenflächen-Textfelder.
///
/// Enthält bewusst **keine** eigenen `touchesBegan`/`touchesEnded`-Overrides:
/// Der Tipp auf ein bereits sichtbares Textfeld wird vollständig von den
/// internen Gesten-Erkennern von UIKit behandelt (Cursor setzen, First
/// Responder werden, Tastatur einblenden). Eigene Touch-Behandlung lief
/// parallel dazu und griff mitten in diesen Ablauf ein.
final class CustomNoteTextView: UITextView {
    private lazy var focusRequester = SystemKeyboardFocusRequester(
        view: self,
        debugLabel: "NoteTextEditor"
    )

    override func didMoveToWindow() {
        super.didMoveToWindow()
        focusRequester.viewDidMoveToWindow()
    }

    /// Fordert den Fokus an (wird automatisch nachgeholt, sobald die View in
    /// einem aktiven Key-Window hängt).
    func requestSystemKeyboard() {
        focusRequester.requestFocus()
    }

    /// Verwirft eine offene Fokus-Anfrage.
    func cancelPendingKeyboardRequest() {
        focusRequester.cancelPendingFocus()
    }
}
