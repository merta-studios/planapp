import SwiftUI
import UIKit

/// Zuverlässiges Textfeld für iPadOS & iOS mit voller Tastatur-Unterstützung.
///
/// Kern ist ein natives UIKit-`UITextField` (per UIViewRepresentable). Im
/// Gegensatz zum SwiftUI-`TextField` mit FocusState erscheint die
/// Bildschirmtastatur damit zuverlässig beim Antippen – auch auf iPads mit
/// gekoppeltem Apple Pencil / Scribble, wo SwiftUI-Felder zuvor nur den Cursor,
/// aber keine Tastatur zeigten.
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
        // Nicht nur der exakt von UIKit belegte TextField-Bereich soll
        // fokussieren: Ein Tipp irgendwo in der sichtbaren Kapsel fordert das
        // native Feld und seine Apple-Systemtastatur an. Das behebt besonders
        // auf dem iPad Fälle, in denen SwiftUI den Tap auf den Container statt
        // auf das eingebettete UITextField routet.
        .contentShape(Rectangle())
        .simultaneousGesture(
            TapGesture().onEnded {
                focusController.requestKeyboard()
            }
        )
    }
}

private final class KeyboardTextFieldFocusController: ObservableObject {
    @Published var requestToken: Int = 0

    func requestKeyboard() {
        requestToken = requestToken &+ 1
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
        // Keine alte PencilKit-, Scribble- oder benutzerdefinierte
        // Eingabeansicht darf die Apple-Systemtastatur dieses Felds ersetzen.
        textField.inputView = nil
        textField.text = text

        textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textField.setContentHuggingPriority(.required, for: .vertical)

        textField.addTarget(
            context.coordinator,
            action: #selector(Coordinator.editingChanged(_:)),
            for: .editingChanged
        )

        let coordinator = context.coordinator
        textField.onWindowAttached = { [weak textField, weak coordinator] in
            guard let textField, let coordinator, coordinator.pendingKeyboardRequest else { return }
            if textField.requestSystemKeyboard() {
                coordinator.pendingKeyboardRequest = false
            }
        }

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

        if focusRequestToken != context.coordinator.lastHandledFocusRequestToken {
            context.coordinator.lastHandledFocusRequestToken = focusRequestToken
            context.coordinator.pendingKeyboardRequest = true
            if uiView.requestSystemKeyboard() {
                context.coordinator.pendingKeyboardRequest = false
            }
        }
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: NativeTextField
        var lastHandledFocusRequestToken: Int = 0
        var pendingKeyboardRequest = false

        init(_ parent: NativeTextField) {
            self.parent = parent
        }

        @objc func editingChanged(_ textField: UITextField) {
            parent.text = textField.text ?? ""
        }

        func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
            // Während UIKit den Fokus vorbereitet, bereits die normale
            // Eingabeansicht vormerken. Das verhindert den Zustand
            // „Cursor ja, Tastatur nein“ nach Scribble/PencilKit-Fokus.
            (textField as? SystemKeyboardTextField)?.prepareForSystemKeyboard()
            return true
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            // `becomeFirstResponder()` allein reicht auf einigen iPad- und
            // Swift-Playgrounds-Konfigurationen nicht: Der Cursor ist dann
            // sichtbar, die Bildschirmtastatur bleibt aber aus. Die native
            // Eingabeansicht deshalb nach jedem echten Fokuswechsel mehrfach
            // im nächsten Runloop neu laden.
            _ = (textField as? SystemKeyboardTextField)?.requestSystemKeyboard()
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            parent.onSubmit()
            return true
        }
    }
}

/// `UITextField`, das bei jedem direkten Tipp nicht nur den Fokus, sondern
/// ausdrücklich auch die Apple-Systemtastatur anfordert. Die explizite
/// Aktivierung ist besonders in SwiftUI-Sheets und bei gekoppeltem Apple
/// Pencil nötig, wo UIKit gelegentlich nur den Cursor anzeigt.
private final class SystemKeyboardTextField: UITextField {
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
        _ = requestSystemKeyboard()
    }

    func prepareForSystemKeyboard() {
        // `nil` bedeutet die normale, von iPadOS/iOS bereitgestellte Tastatur.
        // Das Zurücksetzen vor dem Fokuswechsel verhindert, dass eine alte
        // PencilKit-/Scribble-Eingabeansicht wiederverwendet wird.
        inputView = nil
    }

    @discardableResult
    func requestSystemKeyboard() -> Bool {
        guard isEnabled, isUserInteractionEnabled, window != nil else { return false }

        prepareForSystemKeyboard()
        if !isFirstResponder {
            _ = becomeFirstResponder()
            DispatchQueue.main.async { [weak self] in
                guard let self, self.window != nil else { return }
                _ = self.becomeFirstResponder()
            }
        }

        guard isFirstResponder else { return false }

        // Nach Ende des aktuellen Touch-/Fokus-Ereignisses neu laden. Direkt
        // innerhalb von `touchesEnded` kann UIKit die Anforderung sonst noch
        // durch seine eigene Responder-Verarbeitung überschreiben. Mehrere
        // kurze Wiederholungen sind bewusst: SwiftUI-Sheets, PencilKit und
        // Scribble können im Folge-Runloop erneut am InputView-Zustand drehen.
        for delay in [0.0, 0.05, 0.18] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self, self.isFirstResponder, self.window != nil else { return }
                self.inputView = nil
                self.reloadInputViews()
            }
        }

        return true
    }
}
