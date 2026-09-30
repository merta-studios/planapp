import SwiftUI
import UIKit

/// Zuverlässiges Textfeld für iPadOS & iOS mit voller Tastatur-Unterstützung.
///
/// Kern ist ein natives UIKit-`UITextField` (per UIViewRepresentable). Im
/// Gegensatz zum SwiftUI-`TextField` mit FocusState erscheint die
/// Bildschirmtastatur damit garantiert beim Antippen – auch auf iPads mit
/// gekoppeltem Apple Pencil / Scribble, wo SwiftUI-Felder zuverlässig
/// versagten. Scribble (Handschrift direkt ins Feld schreiben) bleibt
/// weiterhin möglich.
public struct KeyboardTextField: View {
    @Binding private var text: String
    private let placeholder: String
    private let isSecure: Bool
    private let capitalization: UITextAutocapitalizationType
    private let autocorrection: UITextAutocorrectionType
    private let keyboardType: UIKeyboardType
    private let contentType: UITextContentType?
    private let returnKeyType: UIReturnKeyType
    private let onSubmit: () -> Void

    public init(
        _ placeholder: String,
        text: Binding<String>,
        isSecure: Bool = false,
        capitalization: UITextAutocapitalizationType = .sentences,
        autocorrection: UITextAutocorrectionType = .default,
        keyboardType: UIKeyboardType = .default,
        contentType: UITextContentType? = nil,
        returnKeyType: UIReturnKeyType = .done,
        onSubmit: @escaping () -> Void = {}
    ) {
        self.placeholder = placeholder
        self._text = text
        self.isSecure = isSecure
        self.capitalization = capitalization
        self.autocorrection = autocorrection
        self.keyboardType = keyboardType
        self.contentType = contentType
        self.returnKeyType = returnKeyType
        self.onSubmit = onSubmit
    }

    public var body: some View {
        HStack(spacing: 8) {
            NativeTextField(
                placeholder: placeholder,
                text: $text,
                isSecure: isSecure,
                capitalization: capitalization,
                autocorrection: autocorrection,
                keyboardType: keyboardType,
                contentType: contentType,
                returnKeyType: returnKeyType,
                onSubmit: onSubmit
            )
            .fixedSize(horizontal: false, vertical: true)

            if !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14, weight: .regular, design: .default))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
                .hoverEffect(.lift)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(UIColor.tertiarySystemBackground).opacity(0.75))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
        )
    }
}

/// Die eigentliche UIKit-Brücke. Das Feld wird nativ First Responder, wenn es
/// angetippt wird – dadurch öffnet iPadOS zuverlässig die Tastatur.
private struct NativeTextField: UIViewRepresentable {
    let placeholder: String
    @Binding var text: String
    let isSecure: Bool
    let capitalization: UITextAutocapitalizationType
    let autocorrection: UITextAutocorrectionType
    let keyboardType: UIKeyboardType
    let contentType: UITextContentType?
    let returnKeyType: UIReturnKeyType
    let onSubmit: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField(frame: .zero)
        textField.delegate = context.coordinator
        textField.borderStyle = .none
        textField.backgroundColor = .clear
        textField.font = .systemFont(ofSize: 15)
        textField.textColor = .label
        textField.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: UIColor.placeholderText]
        )
        textField.autocapitalizationType = capitalization
        textField.autocorrectionType = autocorrection
        textField.keyboardType = keyboardType
        textField.textContentType = contentType
        textField.returnKeyType = returnKeyType
        textField.enablesReturnKeyAutomatically = false
        textField.clearButtonMode = .never
        textField.isSecureTextEntry = isSecure
        textField.text = text

        textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textField.setContentHuggingPriority(.required, for: .vertical)

        textField.addTarget(
            context.coordinator,
            action: #selector(Coordinator.editingChanged(_:)),
            for: .editingChanged
        )

        return textField
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        context.coordinator.parent = self

        uiView.autocapitalizationType = capitalization
        uiView.autocorrectionType = autocorrection
        uiView.keyboardType = keyboardType
        uiView.textContentType = contentType
        uiView.returnKeyType = returnKeyType
        if uiView.isSecureTextEntry != isSecure {
            uiView.isSecureTextEntry = isSecure
        }
        let attributed = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: UIColor.placeholderText]
        )
        if uiView.attributedPlaceholder?.string != placeholder {
            uiView.attributedPlaceholder = attributed
        }

        // Änderungen von außen (z. B. Lösch-Button, Zurücksetzen beim
        // Bearbeiten-Sheet) übernehmen, aber nie mitten in einer laufenden
        // IME-Eingabe greifen.
        if uiView.text != text, uiView.markedTextRange == nil {
            uiView.text = text
        }
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: NativeTextField

        init(_ parent: NativeTextField) {
            self.parent = parent
        }

        @objc func editingChanged(_ textField: UITextField) {
            parent.text = textField.text ?? ""
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            parent.onSubmit()
            return true
        }
    }
}
