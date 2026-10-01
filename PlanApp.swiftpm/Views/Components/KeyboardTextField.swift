import SwiftUI
import UIKit

/// Zuverlässiges Textfeld für iPadOS & iOS mit voller Tastatur-Unterstützung.
///
/// Kern ist ein natives UIKit-`UITextField` (per `UIViewRepresentable`). Der
/// Tipp auf das Feld wird vollständig von UIKit verarbeitet: UIKit erkennt ihn
/// mit seinen eigenen Gesten-Erkennern, setzt den Cursor und macht das Feld
/// zum First Responder – daraufhin blendet das System die Tastatur ein.
///
/// Bewusst **nicht** vorhanden (das waren die Ursachen des Fehlers
/// „Cursor erscheint, Tastatur bleibt aus"):
///
/// * keine eigenen `touchesBegan`/`touchesEnded`-Overrides, die parallel zum
///   UIKit-Gesten-Erkenner `becomeFirstResponder()` aufrufen,
/// * keine wiederholten `reloadInputViews()`-Aufrufe per `asyncAfter`. Ein
///   `reloadInputViews()` während der laufenden Einblend-Animation baut die
///   Eingabeansicht neu auf und bricht die Animation ab; das Feld bleibt
///   First Responder (Cursor blinkt), die Tastatur wird aber nie sichtbar.
///
/// Programmatische Fokus-Anfragen (Tipp auf die Kapsel neben dem Feld oder auf
/// den Löschen-Knopf) laufen über ``SystemKeyboardFocusRequester`` und warten
/// ereignisgesteuert, bis Fenster und Szene bereit sind.
public struct KeyboardTextField: View {
    @Binding private var text: String
    @StateObject private var focusController = KeyboardTextFieldFocusController()

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
                focusRequestToken: focusController.requestToken,
                onSubmit: onSubmit
            )
            .frame(maxWidth: .infinity)
            .frame(minHeight: 24)
            .fixedSize(horizontal: false, vertical: true)

            if !text.isEmpty {
                Button(action: {
                    text = ""
                    focusController.requestKeyboard()
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
        // Auch ein Tipp auf den Innenabstand der sichtbaren Kapsel (also neben
        // dem eigentlichen UITextField) soll fokussieren.
        //
        // `simultaneousGesture` ist hier wichtig: Eine normale `.onTapGesture`
        // würde mit den UIKit-Gesten-Erkennern des Textfelds konkurrieren und
        // den direkten Tipp auf das Feld verschlucken. Als simultane Geste
        // bleibt der native UIKit-Fokusablauf vollständig erhalten.
        .contentShape(Rectangle())
        .simultaneousGesture(
            TapGesture().onEnded {
                focusController.requestKeyboard()
            }
        )
    }
}

private final class KeyboardTextFieldFocusController: ObservableObject {
    /// Zähler statt `Bool`: Jede neue Anfrage ist eindeutig unterscheidbar,
    /// auch wenn zwischendurch kein Zustand zurückgesetzt wurde.
    @Published var requestToken: Int = 0

    func requestKeyboard() {
        requestToken = requestToken &+ 1
    }
}

/// Die eigentliche UIKit-Brücke.
private struct NativeTextField: UIViewRepresentable {
    let placeholder: String
    @Binding var text: String
    let isSecure: Bool
    let capitalization: UITextAutocapitalizationType
    let autocorrection: UITextAutocorrectionType
    let keyboardType: UIKeyboardType
    let contentType: UITextContentType?
    let returnKeyType: UIReturnKeyType
    let focusRequestToken: Int
    let onSubmit: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> SystemKeyboardTextField {
        let textField = SystemKeyboardTextField(frame: .zero)
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
        textField.adjustsFontForContentSizeCategory = true
        // `inputView == nil` ist der Normalzustand und bedeutet „System-
        // tastatur". Einmalig gesetzt zur Dokumentation der Absicht; danach
        // wird der Wert nie wieder angefasst, damit kein `reloadInputViews()`
        // nötig ist.
        textField.inputView = nil
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

    func updateUIView(_ uiView: SystemKeyboardTextField, context: Context) {
        context.coordinator.parent = self

        uiView.autocapitalizationType = capitalization
        uiView.autocorrectionType = autocorrection
        uiView.keyboardType = keyboardType
        uiView.textContentType = contentType
        uiView.returnKeyType = returnKeyType
        if uiView.isSecureTextEntry != isSecure {
            uiView.isSecureTextEntry = isSecure
        }
        if uiView.attributedPlaceholder?.string != placeholder {
            uiView.attributedPlaceholder = NSAttributedString(
                string: placeholder,
                attributes: [.foregroundColor: UIColor.placeholderText]
            )
        }

        // Änderungen von außen (z. B. Lösch-Knopf, Zurücksetzen beim
        // Bearbeiten-Sheet) übernehmen, aber nie mitten in einer laufenden
        // IME-Eingabe greifen.
        if uiView.text != text, uiView.markedTextRange == nil {
            uiView.text = text
        }

        // Nur echte, neue Fokus-Anfragen ausführen – `updateUIView` läuft bei
        // jeder Layout-Änderung des umgebenden ScrollView/LazyVStack.
        if focusRequestToken != context.coordinator.lastHandledFocusRequestToken {
            context.coordinator.lastHandledFocusRequestToken = focusRequestToken
            uiView.requestSystemKeyboard()
        }
    }

    static func dismantleUIView(_ uiView: SystemKeyboardTextField, coordinator: Coordinator) {
        coordinator.isDismantled = true
        uiView.cancelPendingKeyboardRequest()
        uiView.delegate = nil
        if uiView.isFirstResponder {
            uiView.resignFirstResponder()
        }
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: NativeTextField
        var lastHandledFocusRequestToken: Int = 0
        var isDismantled = false

        init(_ parent: NativeTextField) {
            self.parent = parent
        }

        @objc func editingChanged(_ textField: UITextField) {
            guard !isDismantled else { return }
            parent.text = textField.text ?? ""
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            // Der Fokus ist da – eine evtl. noch offene programmatische
            // Anfrage ist damit erledigt und darf nicht nachlaufen.
            (textField as? SystemKeyboardTextField)?.cancelPendingKeyboardRequest()
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            parent.onSubmit()
            return true
        }
    }
}

/// `UITextField` mit ereignisgesteuerter, programmatischer Fokus-Anfrage.
///
/// Der direkte Tipp auf das Feld braucht hier **keinen** Sonderweg: Das
/// übernimmt UIKit selbst. Die Klasse existiert nur, um eine programmatische
/// Anfrage (Tipp auf die Kapsel, Löschen-Knopf) sauber zu vertagen, bis die
/// View in einem aktiven Key-Window hängt.
private final class SystemKeyboardTextField: UITextField {
    private lazy var focusRequester = SystemKeyboardFocusRequester(
        view: self,
        debugLabel: "KeyboardTextField"
    )

    override func didMoveToWindow() {
        super.didMoveToWindow()
        focusRequester.viewDidMoveToWindow()
    }

    func requestSystemKeyboard() {
        focusRequester.requestFocus()
    }

    func cancelPendingKeyboardRequest() {
        focusRequester.cancelPendingFocus()
    }
}
