import SwiftUI
import UIKit

/// UIKit-basiertes mehrzeiliges Textfeld (`UITextView`) für die Textfelder auf
/// der Zeichenfläche. Gegenüber dem SwiftUI-`TextField` garantiert es, dass
/// die Bildschirmtastatur zuverlässig erscheint (`becomeFirstResponder`), und
/// unterstützt weiterhin Scribble mit dem Apple Pencil.
struct NoteTextEditor: UIViewRepresentable {
    @Binding var text: String
    let fontSize: CGFloat
    /// Ob das Feld gerade bearbeitet wird (Fokus halten/aufheben).
    let isEditing: Bool
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
        textView.font = .systemFont(ofSize: fontSize)
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

        if uiView.font?.pointSize != fontSize {
            uiView.font = .systemFont(ofSize: fontSize)
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
            // Ein Runloop-Tick warten, damit die View sicher im Fenster hängt –
            // dann erscheint die Tastatur garantiert.
            DispatchQueue.main.async {
                if isEditing, !uiView.isFirstResponder {
                    uiView.becomeFirstResponder()
                }
            }
        } else if !isEditing, uiView.isFirstResponder {
            uiView.resignFirstResponder()
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: NoteTextEditor
        var isApplyingExternalChange = false

        init(_ parent: NoteTextEditor) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            guard !isApplyingExternalChange else { return }
            parent.text = textView.text
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            parent.onEndEditing()
        }
    }
}
