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
    /// Ob das Feld gerade bearbeitet wird (Fokus halten/aufheben).
    let isEditing: Bool
    /// Wird bei jeder Texteingabe aufgerufen.
    let onChangeText: (String) -> Void
    /// Wird aufgerufen, wenn die Bearbeitung nativ endet (z. B. Tastatur weg).
    let onEndEditing: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.isOpaque = false
        textView.isScrollEnabled = false
        textView.font = .systemFont(ofSize: max(1, fontSize))
        textView.textColor = .label
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainer.widthTracksTextView = true
        textView.autocorrectionType = .default
        textView.autocapitalizationType = .sentences
        textView.keyboardDismissMode = .none
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.setContentHuggingPriority(.required, for: .vertical)
        textView.text = text
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        context.coordinator.parent = self

        let resolvedFontSize = max(1, fontSize)
        if uiView.font?.pointSize != resolvedFontSize {
            uiView.font = .systemFont(ofSize: resolvedFontSize)
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
            let location = min(selectedRange.location, length)
            uiView.selectedRange = NSRange(location: location, length: 0)
            context.coordinator.isApplyingExternalChange = false
        }

        if isEditing, !uiView.isFirstResponder {
            DispatchQueue.main.async { [weak uiView] in
                guard let uiView, uiView.window != nil, !uiView.isFirstResponder else { return }
                uiView.becomeFirstResponder()
            }
        } else if !isEditing, uiView.isFirstResponder {
            uiView.resignFirstResponder()
        }
    }

    /// Aufräumen, bevor die View entfernt wird: Ein noch aktiver First
    /// Responder würde sonst nach dem Entfernen weiter Delegate-Aufrufe
    /// auslösen.
    static func dismantleUIView(_ uiView: UITextView, coordinator: Coordinator) {
        coordinator.isDismantled = true
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
