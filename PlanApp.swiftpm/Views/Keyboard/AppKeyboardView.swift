import SwiftUI
import UIKit

/// Ebene der app-eigenen Tastatur.
private enum KeyboardLayer {
    case letters
    case numbers
    case symbols
}

/// Aktion einer Taste.
private enum KeyAction {
    case character(String)
    case shift
    case backspace
    case space
    case done
    case caret(Int)
    case layer(KeyboardLayer)
}

/// Beschreibung einer einzelnen Taste.
private struct KeySpec: Identifiable {
    let id: String
    let title: String?
    let icon: String?
    let action: KeyAction
    let isAccent: Bool
    let isProminent: Bool
    let repeats: Bool
    /// Feste Breite (z. B. untere Reihe). `nil` = flexible Breite.
    let width: CGFloat?

    init(
        id: String,
        title: String? = nil,
        icon: String? = nil,
        action: KeyAction,
        isAccent: Bool = false,
        isProminent: Bool = false,
        repeats: Bool = false,
        width: CGFloat? = nil
    ) {
        self.id = id
        self.title = title
        self.icon = icon
        self.action = action
        self.isAccent = isAccent
        self.isProminent = isProminent
        self.repeats = repeats
        self.width = width
    }

    /// Kopie mit fester Breite.
    func withWidth(_ width: CGFloat) -> KeySpec {
        KeySpec(
            id: id,
            title: title,
            icon: icon,
            action: action,
            isAccent: isAccent,
            isProminent: isProminent,
            repeats: repeats,
            width: width
        )
    }
}

/// Zeichen-Taste (Basisform ist immer klein; die Umschalttaste wandelt um).
private func characterKey(_ text: String) -> KeySpec {
    KeySpec(id: "char-\(text)", title: text, action: .character(text))
}

/// Die app-eigene Bildschirmtastatur.
///
/// Sie ist eine ganz normale SwiftUI-Ansicht **innerhalb** der App und braucht
/// deshalb weder die Systemtastatur noch Tastenereignisse von iPadOS. Genau
/// das macht Texteingabe in Swift Playgrounds zuverlässig, wo die
/// Systemtastatur in Apps nicht erscheint (siehe ``TextInputHub``).
///
/// Getippt wird über `UIKeyInput.insertText(_:)` / `deleteBackward()` direkt in
/// das fokussierte Feld – dieselbe Schnittstelle wie bei einer echten Tastatur,
/// inklusive Cursorposition und Autokorrektur-Verhalten des Felds.
struct AppKeyboardView: View {
    @ObservedObject private var hub = TextInputHub.shared
    let safeAreaInsets: UIEdgeInsets

    @State private var layer: KeyboardLayer = .letters
    @State private var isShifted = false
    @State private var showsPasteKey = false

    private let keySpacing: CGFloat = 5

    init(safeAreaInsets: UIEdgeInsets) {
        self.safeAreaInsets = safeAreaInsets
    }

    var body: some View {
        GeometryReader { geometry in
            let keyHeight = AppKeyboardLayout.keyHeight(
                totalHeight: geometry.size.height,
                bottomInset: safeAreaInsets.bottom,
                rowCount: rows.count
            )
            let widthScale = max(0.75, geometry.size.width / 900)

            VStack(spacing: AppKeyboardLayout.rowSpacing) {
                topBar

                ForEach(rows.indices, id: \.self) { index in
                    HStack(spacing: keySpacing) {
                        ForEach(rows[index]) { key in
                            keyView(key, height: keyHeight, widthScale: widthScale)
                        }
                    }
                }
            }
            .padding(.leading, max(8, safeAreaInsets.left))
            .padding(.trailing, max(8, safeAreaInsets.right))
            .padding(.top, AppKeyboardLayout.topPadding)
            .padding(.bottom, AppKeyboardLayout.bottomPadding + safeAreaInsets.bottom)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .background(
            // Der Hintergrund reicht bis an den unteren Bildschirmrand
            // (Home-Indikator), während die Tasten darüber bleiben.
            Color(UIColor.secondarySystemBackground)
                .overlay(Color.primary.opacity(0.05))
                .ignoresSafeArea(edges: .bottom)
        )
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.primary.opacity(0.12))
                .frame(height: 0.5)
        }
        .onAppear { syncWithActiveInput() }
        .onChange(of: hub.activationCounter) { _, _ in
            syncWithActiveInput()
        }
    }

    // MARK: - Kopfzeile

    private var topBar: some View {
        HStack(spacing: 6) {
            compactKey(title: nil, icon: "arrow.left") {
                hub.moveCaret(by: -1)
            }
            .frame(width: 46)

            compactKey(title: nil, icon: "arrow.right") {
                hub.moveCaret(by: 1)
            }
            .frame(width: 46)

            Spacer(minLength: 4)

            Text(infoText)
                .font(.system(size: 11, weight: .regular, design: .default))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 4)

            if showsPasteKey {
                compactKey(title: "Einfügen", icon: "doc.on.clipboard") {
                    hub.pasteFromPasteboard()
                    showsPasteKey = hub.canPaste
                }
            }

            compactKey(title: "Ausblenden", icon: "chevron.down") {
                hub.suppressAppKeyboardForCurrentInput()
            }
        }
        .frame(height: AppKeyboardLayout.topBarHeight)
    }

    private var infoText: String {
        if hub.isSystemKeyboardVisible {
            return "App-Tastatur (zusätzlich)"
        }
        return "App-Tastatur – iPadOS zeigt hier keine Systemtastatur"
    }

    private func compactKey(
        title: String?,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        KeyboardKeyButton(height: 30, isAccent: true, action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                if let title {
                    Text(title)
                        .font(.system(size: 12, weight: .medium))
                }
            }
        }
    }

    // MARK: - Zeilen

    private var rows: [[KeySpec]] {
        switch layer {
        case .letters: return letterRows
        case .numbers: return numberRows
        case .symbols: return symbolRows
        }
    }

    private var letterRows: [[KeySpec]] {
        [
            ["Q", "W", "E", "R", "T", "Z", "U", "I", "O", "P", "Ü"].map(characterKey),
            ["A", "S", "D", "F", "G", "H", "J", "K", "L", "Ö", "Ä"].map(characterKey),
            [shiftKey] + ["Y", "X", "C", "V", "B", "N", "M", "ß"].map(characterKey) + [backspaceKey],
            [
                KeySpec(id: "layer-numbers", title: "123", action: .layer(.numbers), isAccent: true, width: 64),
                characterKey(",").withWidth(52),
                characterKey(".").withWidth(52),
                spaceKey,
                doneKey
            ]
        ]
    }

    private var numberRows: [[KeySpec]] {
        [
            ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"].map(characterKey),
            ["-", "/", ":", ";", "(", ")", "&", "@", "\""].map(characterKey),
            [KeySpec(id: "layer-letters", title: "ABC", action: .layer(.letters), isAccent: true)]
                + [".", ",", "?", "!", "'", "+"].map(characterKey)
                + [backspaceKey],
            [
                KeySpec(id: "layer-symbols", title: "#+=", action: .layer(.symbols), isAccent: true, width: 64),
                spaceKey,
                doneKey
            ]
        ]
    }

    private var symbolRows: [[KeySpec]] {
        [
            ["[", "]", "{", "}", "#", "%", "^", "*", "+", "="].map(characterKey),
            ["_", "\\", "|", "~", "<", ">", "€", "£", "¥"].map(characterKey),
            [KeySpec(id: "layer-numbers-2", title: "123", action: .layer(.numbers), isAccent: true)]
                + [".", ",", "?", "!", "\"", "§"].map(characterKey)
                + [backspaceKey],
            [
                KeySpec(id: "layer-letters-2", title: "ABC", action: .layer(.letters), isAccent: true, width: 64),
                spaceKey,
                doneKey
            ]
        ]
    }

    private var spaceKey: KeySpec {
        KeySpec(id: "space", title: "Leertaste", action: .space)
    }

    private var shiftKey: KeySpec {
        KeySpec(id: "shift", icon: "shift.fill", action: .shift, isAccent: true)
    }

    private var backspaceKey: KeySpec {
        KeySpec(id: "backspace", icon: "delete.left", action: .backspace, isAccent: true, repeats: true)
    }

    private var doneKey: KeySpec {
        KeySpec(id: "done", title: "Fertig", action: .done, isProminent: true, width: 88)
    }

    // MARK: - Tasten

    private func keyView(_ key: KeySpec, height: CGFloat, widthScale: CGFloat) -> some View {
        let button = KeyboardKeyButton(
            height: height,
            isActive: isActiveKey(key),
            isAccent: key.isAccent,
            isProminent: key.isProminent,
            repeats: key.repeats,
            action: { perform(key) }
        ) {
            keyLabel(key, height: height)
        }

        return Group {
            if let width = key.width {
                button.frame(width: width * widthScale)
            } else {
                button.frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    private func keyLabel(_ key: KeySpec, height: CGFloat) -> some View {
        if let icon = key.icon {
            Image(systemName: icon)
                .font(.system(size: min(26, max(16, height * 0.28)), weight: .regular))
        } else if let title = key.title {
            Text(displayTitle(for: key, base: title))
                .font(.system(
                    size: key.isProminent ? 15 : min(28, max(19, height * 0.28)),
                    weight: key.isProminent ? .semibold : .regular,
                    design: .default
                ))
        }
    }

    private func isActiveKey(_ key: KeySpec) -> Bool {
        if case .shift = key.action { return isShifted }
        return false
    }

    /// Anzeigeform einer Buchstabentaste (Groß-/Kleinschreibung).
    private func displayTitle(for key: KeySpec, base: String) -> String {
        guard layer == .letters,
              case .character(let value) = key.action,
              value.first?.isLetter == true else { return base }
        return letterForm(value)
    }

    /// Form eines Buchstabens je nach Umschalttaste. „ß“ bleibt „ß“, weil
    /// `uppercased()` daraus „SS“ machen würde.
    private func letterForm(_ value: String) -> String {
        guard value.count == 1, value.first?.isLetter == true else { return value }
        if isShifted {
            let upperText = value.uppercased()
            return upperText.count == value.count ? upperText : value
        }
        return value.lowercased()
    }

    // MARK: - Aktionen

    private func perform(_ key: KeySpec) {
        switch key.action {
        case .character(let base):
            let text = shiftedText(for: base)
            hub.insert(text)
            updateShiftState(after: text, base: base)

        case .shift:
            isShifted.toggle()
            Haptics.select()

        case .backspace:
            hub.deleteBackward()

        case .space:
            // Der Shift-Zustand bleibt erhalten: nach einem Satzzeichen ist er
            // bereits gesetzt, mitten im Satz bleibt er aus.
            hub.insert(" ")

        case .done:
            hub.dismissActiveInput()

        case .caret(let offset):
            hub.moveCaret(by: offset)

        case .layer(let target):
            layer = target
            isShifted = false
            Haptics.select()
        }
    }

    private func shiftedText(for base: String) -> String {
        guard layer == .letters else { return base }
        return letterForm(base)
    }

    private func updateShiftState(after inserted: String, base: String) {
        guard layer == .letters else { return }

        if hub.isSentenceMode, inserted == "." || inserted == "!" || inserted == "?" {
            isShifted = true
            return
        }
        if base.count == 1, base.first?.isLetter == true {
            isShifted = false
        }
    }

    /// Beim Wechsel des Textfelds Schrift/Shift auf das neue Feld abstimmen.
    private func syncWithActiveInput() {
        isShifted = hub.prefersUppercaseStart
        layer = .letters
        showsPasteKey = hub.canPaste
    }
}

// MARK: - Tastenansicht

/// Einzelne Taste mit Druck-Zustand und optionaler Wiederholung (Löschen).
private struct KeyboardKeyButton<Content: View>: View {
    let height: CGFloat
    let isActive: Bool
    let isAccent: Bool
    let isProminent: Bool
    let repeats: Bool
    let action: () -> Void
    let content: Content

    @State private var isPressed = false
    @State private var repeatTask: Task<Void, Never>?

    init(
        height: CGFloat,
        isActive: Bool = false,
        isAccent: Bool = false,
        isProminent: Bool = false,
        repeats: Bool = false,
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.height = height
        self.isActive = isActive
        self.isAccent = isAccent
        self.isProminent = isProminent
        self.repeats = repeats
        self.action = action
        self.content = content()
    }

    var body: some View {
        content
            .foregroundColor(foregroundColor)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(Color.primary.opacity(isProminent ? 0 : 0.10), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .scaleEffect(isPressed ? 0.95 : 1)
            .gesture(pressGesture)
            .onDisappear { stopRepeating() }
    }

    private var foregroundColor: Color {
        if isProminent { return .white }
        if isActive { return .white }
        return .primary
    }

    private var backgroundColor: Color {
        if isProminent { return .accentColor }
        if isActive { return .accentColor.opacity(0.85) }
        if isAccent { return Color.primary.opacity(0.12) }
        return Color(UIColor.tertiarySystemBackground)
    }

    private var pressGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                guard !isPressed else { return }
                beginPress()
            }
            .onEnded { _ in
                endPress()
            }
    }

    private func beginPress() {
        isPressed = true
        Haptics.select()
        action()

        guard repeats else { return }
        stopRepeating()
        repeatTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: 380_000_000)
            } catch {
                return
            }

            // Bewusst begrenzt: Selbst wenn ein Loslass-Ereignis einmal
            // ausbleiben sollte, hört das Wiederholen nach kurzer Zeit auf.
            var repeatCount = 0
            while !Task.isCancelled && repeatCount < 120 {
                action()
                repeatCount += 1
                do {
                    try await Task.sleep(nanoseconds: 70_000_000)
                } catch {
                    return
                }
            }
        }
    }

    private func endPress() {
        isPressed = false
        stopRepeating()
    }

    private func stopRepeating() {
        repeatTask?.cancel()
        repeatTask = nil
    }
}
