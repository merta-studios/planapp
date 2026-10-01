import SwiftUI
import UIKit

/// Einheitlich gestaltetes Texteingabefeld für die Einstellungen.
///
/// Die vorherige `UIViewRepresentable`-Brücke hat einen zweiten,
/// programmatischen Responder-Ablauf parallel zum bereits nativen SwiftUI-
/// Textfeld betrieben. Besonders in einem Sheet konnte diese zweite Anfrage
/// den vom System gestarteten Tastatur-Übergang wieder unterbrechen. Dieses
/// Feld verwendet deshalb direkt `TextField` bzw. `SecureField`: SwiftUI
/// verwaltet damit genau eine native UIKit-Eingabe und genau einen Responder.
///
/// `@FocusState` wird nur für einen Tipp auf den sichtbaren Innenabstand und
/// für den Löschen-Knopf verwendet. Ein direkter Tipp auf das Textfeld läuft
/// vollständig über die Systemsteuerung und zeigt die Bildschirmtastatur auf
/// dem normalen iPadOS-Weg an.
public struct KeyboardTextField: View {
    @Binding private var text: String
    @FocusState private var isFocused: Bool

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
            inputField
                .frame(maxWidth: .infinity)
                .frame(minHeight: 24)

            if !text.isEmpty {
                Button {
                    text = ""
                    isFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14, weight: .regular, design: .default))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .hoverEffect(.lift)
                .accessibilityLabel("Eingabe löschen")
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
        // Auch ein Tipp auf den freien Platz in der sichtbaren Kapsel setzt
        // den normalen SwiftUI-Fokus. `simultaneousGesture` lässt den
        // direkten UIKit-Tipp auf dem Textfeld unangetastet.
        .contentShape(Rectangle())
        .simultaneousGesture(
            TapGesture().onEnded {
                isFocused = true
            }
        )
    }

    @ViewBuilder
    private var inputField: some View {
        if isSecure {
            SecureField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .focused($isFocused)
                .keyboardConfiguration(
                    capitalization: capitalization,
                    autocorrection: autocorrection,
                    keyboardType: keyboardType,
                    contentType: contentType,
                    returnKeyType: returnKeyType,
                    onSubmit: onSubmit
                )
        } else {
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .focused($isFocused)
                .keyboardConfiguration(
                    capitalization: capitalization,
                    autocorrection: autocorrection,
                    keyboardType: keyboardType,
                    contentType: contentType,
                    returnKeyType: returnKeyType,
                    onSubmit: onSubmit
                )
        }
    }
}

private extension View {
    /// Überträgt die bisherigen UIKit-Optionen auf die native SwiftUI-
    /// Texteingabe, ohne selbst mit `becomeFirstResponder()` einzugreifen.
    func keyboardConfiguration(
        capitalization: UITextAutocapitalizationType,
        autocorrection: UITextAutocorrectionType,
        keyboardType: UIKeyboardType,
        contentType: UITextContentType?,
        returnKeyType: UIReturnKeyType,
        onSubmit: @escaping () -> Void
    ) -> some View {
        self
            .textInputAutocapitalization(textInputCapitalization(for: capitalization))
            .autocorrectionDisabled(autocorrection == .no)
            .keyboardType(keyboardType)
            .textContentType(contentType)
            .submitLabel(submitLabel(for: returnKeyType))
            .onSubmit(onSubmit)
    }

    private func textInputCapitalization(
        for capitalization: UITextAutocapitalizationType
    ) -> TextInputAutocapitalization {
        switch capitalization {
        case .none:
            return .never
        case .words:
            return .words
        case .allCharacters:
            return .characters
        case .sentences:
            return .sentences
        @unknown default:
            return .sentences
        }
    }

    private func submitLabel(for returnKeyType: UIReturnKeyType) -> SubmitLabel {
        switch returnKeyType {
        case .continue:
            return .continue
        case .done:
            return .done
        case .go:
            return .go
        case .join:
            return .join
        case .next:
            return .next
        case .route:
            return .route
        case .search:
            return .search
        case .send:
            return .send
        case .default, .emergencyCall, .google, .yahoo:
            return .return
        @unknown default:
            return .done
        }
    }
}
