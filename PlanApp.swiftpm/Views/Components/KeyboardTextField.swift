import SwiftUI
import UIKit

/// Robustes UIKit-Textfeld für SwiftUI-Forms.
///
/// SwiftUIs natives TextField verliert in als Sheet präsentierten Forms auf
/// manchen iPad-/Swift-Playgrounds-Konfigurationen zwar nicht den Cursor, fordert
/// aber keine Bildschirmtastatur an. Dieses Textfeld wird direkt First Responder
/// und lädt seine Eingabeansicht beim Antippen explizit neu.
public struct KeyboardTextField: UIViewRepresentable {
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
        returnKeyType: UIReturnKeyType = .next,
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

    public func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    public func makeUIView(context: Context) -> ActivatingTextField {
        let textField = ActivatingTextField()
        textField.delegate = context.coordinator
        textField.borderStyle = .roundedRect
        textField.clearButtonMode = .whileEditing
        textField.font = .preferredFont(forTextStyle: .body)
        textField.adjustsFontForContentSizeCategory = true
        textField.addTarget(
            context.coordinator,
            action: #selector(Coordinator.textChanged(_:)),
            for: .editingChanged
        )
        configure(textField)
        return textField
    }

    public func updateUIView(_ textField: ActivatingTextField, context: Context) {
        context.coordinator.parent = self
        if textField.text != text {
            textField.text = text
        }
        configure(textField)
    }

    private func configure(_ textField: UITextField) {
        textField.placeholder = placeholder
        if textField.isSecureTextEntry != isSecure {
            textField.isSecureTextEntry = isSecure
        }
        textField.autocapitalizationType = capitalization
        textField.autocorrectionType = autocorrection
        textField.spellCheckingType = autocorrection == .no ? .no : .default
        textField.keyboardType = keyboardType
        textField.textContentType = contentType
        textField.returnKeyType = returnKeyType
    }

    public final class Coordinator: NSObject, UITextFieldDelegate {
        fileprivate var parent: KeyboardTextField

        fileprivate init(parent: KeyboardTextField) {
            self.parent = parent
        }

        @objc fileprivate func textChanged(_ sender: UITextField) {
            parent.text = sender.text ?? ""
        }

        public func textFieldDidBeginEditing(_ textField: UITextField) {
            // `inputView = nil` stellt sicher, dass keine alte PencilKit- oder
            // benutzerdefinierte Eingabeansicht am Responder hängen bleibt.
            textField.inputView = nil
            textField.reloadInputViews()
        }

        public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            parent.onSubmit()
            textField.resignFirstResponder()
            return true
        }
    }
}

/// UITextField, das auch nach einem fehlgeschlagenen SwiftUI-Fokuswechsel die
/// Systemtastatur zuverlässig anfordert.
public final class ActivatingTextField: UITextField {
    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        guard isEnabled else { return }

        if !isFirstResponder {
            becomeFirstResponder()
        }
        DispatchQueue.main.async { [weak self] in
            self?.inputView = nil
            self?.reloadInputViews()
        }
    }
}
