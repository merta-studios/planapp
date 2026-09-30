import SwiftUI
import UIKit

/// Zuverlässiges Textfeld für iPadOS & iOS mit voller Tastatur-Unterstützung.
/// Verwendet natives SwiftUI TextField mit angepasstem Liquid-Glass Styling und
/// garantiert, dass die Bildschirmtastatur beim Antippen sofort erscheint.
public struct KeyboardTextField: View {
    @Binding private var text: String
    private let placeholder: String
    private let isSecure: Bool
    private let capitalization: TextInputAutocapitalization
    private let autocorrection: Bool
    private let keyboardType: UIKeyboardType
    private let contentType: UITextContentType?
    private let returnKeyType: SubmitLabel
    private let onSubmit: () -> Void

    @FocusState private var isFocused: Bool

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
        self.autocorrection = (autocorrection != .no)
        self.keyboardType = keyboardType
        self.contentType = contentType
        self.onSubmit = onSubmit

        switch capitalization {
        case .none:
            self.capitalization = .never
        case .allCharacters:
            self.capitalization = .characters
        case .words:
            self.capitalization = .words
        case .sentences:
            self.capitalization = .sentences
        @unknown default:
            self.capitalization = .sentences
        }

        switch returnKeyType {
        case .done:
            self.returnKeyType = .done
        case .go:
            self.returnKeyType = .go
        case .next:
            self.returnKeyType = .next
        case .search:
            self.returnKeyType = .search
        case .send:
            self.returnKeyType = .send
        default:
            self.returnKeyType = .done
        }
    }

    public var body: some View {
        HStack(spacing: 8) {
            if isSecure {
                SecureField(placeholder, text: $text)
                    .font(.system(size: 15, weight: .regular, design: .default))
                    .textInputAutocapitalization(capitalization)
                    .autocorrectionDisabled(!autocorrection)
                    .focused($isFocused)
                    .submitLabel(returnKeyType)
                    .onSubmit(onSubmit)
            } else {
                TextField(placeholder, text: $text)
                    .font(.system(size: 15, weight: .regular, design: .default))
                    .textInputAutocapitalization(capitalization)
                    .autocorrectionDisabled(!autocorrection)
                    .keyboardType(keyboardType)
                    .focused($isFocused)
                    .submitLabel(returnKeyType)
                    .onSubmit(onSubmit)
            }

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
                .strokeBorder(isFocused ? Color.blue.opacity(0.6) : Color.white.opacity(0.15), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            isFocused = true
        }
    }
}
