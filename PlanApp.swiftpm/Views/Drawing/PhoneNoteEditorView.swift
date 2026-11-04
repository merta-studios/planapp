import SwiftUI
import UIKit

/// Der Notiz-Editor des **iPhones**.
///
/// Auf dem iPhone gibt es keinen Zeichenbereich mehr. Eine neue Notiz ist ein
/// schlichter Fließtext wie in der Notizen-App:
///
/// * Der Text bricht automatisch um – er läuft nie über den Rand.
/// * Reicht der Platz nach unten nicht mehr, wird die Schriftgröße in
///   0,1-pt-Schritten so weit verkleinert, dass alles gerade noch hineinpasst.
/// * Ist bereits die kleinste Schriftgröße erreicht, nimmt der Editor **keine
///   weiteren Zeichen** mehr an (statt den Text abzuschneiden).
/// * In der Leiste gibt es genau zwei Dinge: die Schriftgröße für den
///   **gesamten** Text und den grünen „Fertig“-Knopf. Kein „…“-Menü.
public struct PhoneNoteEditorView: View {
    @EnvironmentObject private var viewModel: TimetableViewModel
    @Environment(\.colorScheme) private var colorScheme

    public let lesson: Lesson

    @State private var text: String = ""
    @State private var fontSize: Double = NoteTextBox.defaultFontSize
    @State private var tagID: UUID? = nil
    @State private var didLoad = false
    /// Vom System gemeldete Tastaturhöhe (der Editor hält den Text darüber).
    @State private var keyboardHeight: CGFloat = 0
    /// Kurze Rückmeldung, wenn die kleinste Schriftgröße erreicht ist.
    @State private var showsLimitHint = false
    @State private var limitHintWorkItem: DispatchWorkItem? = nil

    public init(lesson: Lesson) {
        self.lesson = lesson
    }

    private var display: SubjectDisplay {
        viewModel.resolveSubjectDisplay(for: lesson)
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture {
                        finish()
                    }

                VStack(spacing: 0) {
                    toolbar
                    Divider()
                    editorArea(size: geometry.size)
                }
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: Color.black.opacity(0.22), radius: 18, x: 0, y: 8)
                .padding(.horizontal, 10)
                .padding(.top, max(12, geometry.safeAreaInsets.top + 6))
                .padding(.bottom, max(8, keyboardHeight > 0 ? 8 : geometry.safeAreaInsets.bottom + 8))
                .animation(.easeOut(duration: 0.2), value: keyboardHeight)
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .onAppear(perform: loadNote)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { note in
            keyboardHeight = Self.keyboardHeight(from: note)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardHeight = 0
        }
        .overlay(alignment: .bottom) {
            if showsLimitHint {
                Text("Kleinste Schriftgröße erreicht – mehr passt nicht auf die Seite.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color.black.opacity(0.78)))
                    .padding(.bottom, keyboardHeight + 18)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .allowsHitTesting(false)
            }
        }
    }

    // MARK: - Leiste

    /// Genau das, was es auf dem iPhone geben soll: Schriftgröße für den
    /// gesamten Text und der grüne „Fertig“-Knopf.
    private var toolbar: some View {
        HStack(spacing: 10) {
            subjectBadge

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                fontSizeButton(
                    systemName: "textformat.size.smaller",
                    label: "Schrift kleiner",
                    isEnabled: MobileNotePolicy.canShrink(fontSize: fontSize)
                ) {
                    applyFontSize(MobileNotePolicy.shrunk(fontSize: fontSize), showHintOnLimit: false)
                }

                Text("\(Int(fontSize.rounded()))")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.secondary)
                    .frame(minWidth: 24)

                fontSizeButton(
                    systemName: "textformat.size.larger",
                    label: "Schrift größer",
                    isEnabled: MobileNotePolicy.canGrow(fontSize: fontSize)
                ) {
                    applyFontSize(MobileNotePolicy.grown(fontSize: fontSize), showHintOnLimit: true)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(Color(UIColor.secondarySystemBackground).opacity(0.9))
            )

            if viewModel.tagSettings.isEnabled {
                tagMenu
            }

            Button(action: finish) {
                Text("Fertig")
                    .font(.system(size: 15, weight: .semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .background(
                Capsule().fill(Color(red: 0.13, green: 0.68, blue: 0.32))
            )
            .foregroundColor(.white)
            .accessibilityLabel("Fertig")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var subjectBadge: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [display.color, display.gradientEndColor ?? display.color],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 12, height: 12)
            VStack(alignment: .leading, spacing: 1) {
                Text(display.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.black)
                    .lineLimit(1)
                Text("\(lesson.periodNumber). Stunde")
                    .font(.system(size: 11))
                    .foregroundColor(Color.black.opacity(0.55))
            }
        }
    }

    private func fontSizeButton(
        systemName: String,
        label: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: {
            guard isEnabled else { return }
            Haptics.tap()
            action()
        }) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(isEnabled ? .primary : .secondary.opacity(0.4))
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(label)
    }

    @ViewBuilder
    private var tagMenu: some View {
        if let selected = viewModel.tagSettings.tag(withID: tagID) {
            Menu {
                tagMenuItems
            } label: {
                NoteTagPill(tag: selected, size: .small)
            }
        } else {
            Menu {
                tagMenuItems
            } label: {
                AddTagPill(size: .small)
            }
        }
    }

    @ViewBuilder
    private var tagMenuItems: some View {
        ForEach(viewModel.tagSettings.tags) { tag in
            Button {
                Haptics.select()
                tagID = tag.id
            } label: {
                if tagID == tag.id {
                    Label(tag.displayName, systemImage: "checkmark")
                } else {
                    Text(tag.displayName)
                }
            }
        }
        if tagID != nil {
            Divider()
            Button(role: .destructive) {
                Haptics.tap()
                tagID = nil
            } label: {
                Label("Tag entfernen", systemImage: "xmark.circle")
            }
        }
    }

    // MARK: - Textbereich

    private func editorArea(size: CGSize) -> some View {
        let horizontalPadding: CGFloat = 16
        let availableWidth = max(40, size.width - 20 - horizontalPadding * 2)
        // Die Leiste der Notiz (ca. 52 pt) steht immer zur Verfügung; der
        // Zettel darunter reicht bis knapp über die Tastatur.
        let availableHeight = max(40, size.height - keyboardHeight - 78)

        return ZStack(alignment: .topLeading) {
            if didLoad {
                PhoneNoteTextEditor(
                    text: $text,
                    fontSize: CGFloat(fontSize),
                    fontStyle: viewModel.drawingSettings.textFontStyle,
                    availableWidth: availableWidth,
                    availableHeight: availableHeight,
                    onFontSizeChange: { newSize in
                        applyFontSize(Double(newSize), showHintOnLimit: false)
                    },
                    onBlockedInput: handleBlockedInput
                )
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, 10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.white)
    }

    // MARK: - Aktionen

    private func loadNote() {
        guard !didLoad else { return }
        if let content = viewModel.phoneNoteContent(for: lesson) {
            text = content.text
            fontSize = content.fontSize
        } else {
            text = ""
            fontSize = MobileNotePolicy.resolvedPhoneFontSize(
                stored: nil,
                fallback: viewModel.drawingSettings.defaultPhoneFontSize
            )
        }
        // Der Standard-Tag aus den Einstellungen gilt automatisch für neue
        // Notizen; eine bestehende Notiz behält ihren Tag.
        if let existing = viewModel.noteFor(lesson: lesson)?.tagID {
            tagID = existing
        } else {
            tagID = viewModel.defaultTagID
        }
        didLoad = true
    }

    private func applyFontSize(_ newValue: Double, showHintOnLimit: Bool) {
        let clamped = MobileNotePolicy.clamped(newValue)
        guard abs(clamped - fontSize) > 0.0001 else {
            if showHintOnLimit { handleBlockedInput() }
            return
        }
        fontSize = clamped
    }

    /// Kleinste Schriftgröße erreicht: kurz erklären, warum nichts mehr geht.
    private func handleBlockedInput() {
        Haptics.warning()
        withAnimation(.easeOut(duration: 0.15)) {
            showsLimitHint = true
        }
        limitHintWorkItem?.cancel()
        let item = DispatchWorkItem {
            withAnimation(.easeOut(duration: 0.25)) {
                showsLimitHint = false
            }
        }
        limitHintWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: item)
    }

    private func finish() {
        viewModel.persistPhoneNote(
            for: lesson,
            text: text,
            fontSize: fontSize,
            tagID: tagID
        )
        Haptics.tap()
        viewModel.closePhoneNote()
    }

    private static func keyboardHeight(from notification: Notification) -> CGFloat {
        guard let frameValue = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else {
            return 0
        }
        let frame = frameValue.cgRectValue
        let screenHeight = UIScreen.main.bounds.height
        let height = max(0, screenHeight - frame.minY)
        // Schwebende Tastatur (iPad) verdeckt nichts Vorhersagbares.
        return height > screenHeight * 0.5 ? height : 0
    }
}

/// `UITextView` des Handy-Editors.
///
/// Übernimmt die Umbruch- und Verkleinerungsregeln aus
/// ``MobileNotePolicy`` direkt in `shouldChangeTextIn`: Ein Zeichen, das selbst
/// mit der kleinsten Schriftgröße nicht mehr passt, wird abgelehnt – so kann
/// der Text niemals abgeschnitten werden.
private struct PhoneNoteTextEditor: UIViewRepresentable {
    @Binding var text: String
    let fontSize: CGFloat
    let fontStyle: NoteTextFontStyle
    let availableWidth: CGFloat
    let availableHeight: CGFloat
    /// Meldet die nötige kleinere Schriftgröße (falls der Text sonst nicht passt).
    let onFontSizeChange: (CGFloat) -> Void
    /// Wird aufgerufen, wenn selbst die kleinste Schriftgröße nicht reicht.
    let onBlockedInput: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.backgroundColor = .clear
        textView.isScrollEnabled = true
        textView.alwaysBounceVertical = false
        textView.textContainerInset = UIEdgeInsets(top: 2, left: 0, bottom: 8, right: 0)
        textView.textContainer.lineFragmentPadding = 0
        textView.autocorrectionType = .default
        textView.autocapitalizationType = .sentences
        textView.keyboardDismissMode = .interactive
        textView.delegate = context.coordinator
        textView.text = text
        textView.font = fontStyle.uiFont(size: max(1, fontSize))
        textView.textColor = UIColor(hex: NoteTextBox.defaultColorHex)
        // Der Text liegt auf weißem Papier – im Dark Mode darf daraus keine
        // weiße Schrift werden.
        textView.overrideUserInterfaceStyle = .light
        textView.tintColor = UIColor(red: 0.13, green: 0.68, blue: 0.32, alpha: 1)
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        context.coordinator.parent = self
        let resolved = fontStyle.uiFont(size: max(1, fontSize))
        if textView.font?.pointSize != resolved.pointSize || textView.font?.fontName != resolved.fontName {
            textView.font = resolved
        }
        if textView.text != text, textView.markedTextRange == nil,
           !context.coordinator.isApplyingChange {
            context.coordinator.isApplyingChange = true
            let selected = textView.selectedRange
            textView.text = text
            let length = (text as NSString).length
            textView.selectedRange = NSRange(location: max(0, min(selected.location, length)), length: 0)
            context.coordinator.isApplyingChange = false
        }
    }

    static func dismantleUIView(_ uiView: UITextView, coordinator: Coordinator) {
        coordinator.isDismantled = true
        uiView.delegate = nil
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: PhoneNoteTextEditor
        var isApplyingChange = false
        var isDismantled = false

        init(_ parent: PhoneNoteTextEditor) {
            self.parent = parent
        }

        private func characterSize(for fontSize: Double) -> MobileNotePolicy.TextSize {
            let font = parent.fontStyle.uiFont(size: CGFloat(max(1, fontSize)))
            let reference = ("M" as NSString).size(withAttributes: [.font: font])
            let line = ("Ag" as NSString).size(withAttributes: [.font: font])
            return MobileNotePolicy.TextSize(
                width: Double(max(1, reference.width)),
                height: Double(max(1, line.height * 1.28))
            )
        }

        func textView(
            _ textView: UITextView,
            shouldChangeTextIn range: NSRange,
            replacementText replacement: String
        ) -> Bool {
            guard !isDismantled else { return false }
            let current = textView.text ?? ""
            guard let swiftRange = Range(range, in: current) else { return true }
            let proposed = current.replacingCharacters(in: swiftRange, with: replacement)
            // Eingaben mit IME (Markierungstext) nicht filtern.
            if textView.markedTextRange != nil { return true }

            let layout = MobileNotePolicy.layout(
                text: proposed,
                fontSize: Double(parent.fontSize),
                availableWidth: Double(parent.availableWidth),
                availableHeight: Double(parent.availableHeight),
                characterSize: { [weak self] size in
                    self?.characterSize(for: size)
                        ?? MobileNotePolicy.TextSize(width: size * 0.55, height: size * 1.25)
                }
            )

            if layout.fits {
                return true
            }
            if layout.isBlocked {
                parent.onBlockedInput()
                return false
            }
            // Der Text passt nur mit einer kleineren Schriftgröße: erst
            // verkleinern, dann das Zeichen übernehmen.
            parent.onFontSizeChange(CGFloat(layout.requiredFontSize))
            return true
        }

        func textViewDidChange(_ textView: UITextView) {
            guard !isDismantled, !isApplyingChange else { return }
            let newText = textView.text ?? ""
            if newText != parent.text {
                parent.text = newText
            }
        }
    }
}
