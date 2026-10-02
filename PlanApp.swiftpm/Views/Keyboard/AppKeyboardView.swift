import SwiftUI
import UIKit

// MARK: - Ebenen

/// Ebene der app-eigenen Tastatur. Der Aufbau entspricht der Apple-Tastatur:
/// Buchstaben, Zahlen, Sonderzeichen und Emoji.
private enum KeyboardLayer: Equatable {
    case letters
    case numbers
    case symbols
    case emoji
}

// MARK: - Tastenmodell

/// Aktion einer Taste.
private enum KeyAction: Equatable {
    /// Zeichen einfügen (in der Buchstaben-Ebene abhängig von Shift/Caps Lock).
    case character(String)
    case shift
    case backspace
    case space
    case newline
    case caret(Int)
    case layer(KeyboardLayer)
}

/// Beschreibung einer einzelnen Taste.
private struct KeySpec: Identifiable {
    let id: String
    let title: String?
    let icon: String?
    let action: KeyAction
    /// Dunkle „Sondertaste“ (Shift, Löschen, 123, Eingabe) wie bei Apple.
    let isModifier: Bool
    /// Ob die Taste beim Halten wiederholt (Löschen).
    let repeats: Bool
    /// Breite in Rastereinheiten (1 = normale Buchstabentaste, 1,5 = Shift).
    let width: CGFloat
    /// Alternativen beim langen Drücken (Akzente, Satzzeichen).
    let accents: [String]
    /// Kleine Zusatzbeschriftung, z. B. „?!,“ über dem Punkt.
    let hint: String?

    init(
        id: String,
        title: String? = nil,
        icon: String? = nil,
        action: KeyAction,
        isModifier: Bool = false,
        repeats: Bool = false,
        width: CGFloat = 1,
        accents: [String] = [],
        hint: String? = nil
    ) {
        self.id = id
        self.title = title
        self.icon = icon
        self.action = action
        self.isModifier = isModifier
        self.repeats = repeats
        self.width = width
        self.accents = accents
        self.hint = hint
    }

    /// Kopie mit fester Breite (in Rastereinheiten).
    func withWidth(_ width: CGFloat) -> KeySpec {
        KeySpec(
            id: id,
            title: title,
            icon: icon,
            action: action,
            isModifier: isModifier,
            repeats: repeats,
            width: width,
            accents: accents,
            hint: hint
        )
    }
}

/// Eine Tastenreihe samt seitlichem Einzug in Rastereinheiten. Apple rückt die
/// zweite Buchstabenreihe um eine halbe Taste ein.
private struct KeyRow: Identifiable {
    let id: String
    let keys: [KeySpec]
    let inset: CGFloat

    init(_ id: String, _ keys: [KeySpec], inset: CGFloat = 0) {
        self.id = id
        self.keys = keys
        self.inset = inset
    }
}

/// Akzent- und Satzzeichen-Alternativen wie auf der Apple-Tastatur.
private enum KeyAccents {
    static func alternatives(for character: String) -> [String] {
        table[character.lowercased()] ?? []
    }

    private static let table: [String: [String]] = [
        "a": ["à", "á", "â", "ä", "æ", "ã", "å", "ā"],
        "c": ["ç", "ć", "č"],
        "e": ["è", "é", "ê", "ë", "ę", "ē", "ė"],
        "i": ["ì", "í", "î", "ï", "į", "ī"],
        "l": ["ł"],
        "n": ["ñ", "ń"],
        "o": ["ò", "ó", "ô", "ö", "œ", "ø", "ō", "õ"],
        "s": ["ß", "ś", "š"],
        "u": ["ù", "ú", "û", "ü", "ū"],
        "y": ["ÿ"],
        "z": ["ź", "ż", "ž"],
        "0": ["°"],
        "-": ["–", "—", "•", "…"],
        "/": ["\\"],
        "?": ["¿"],
        "!": ["¡"],
        "'": ["’", "‘", "‚"],
        "\"": ["„", "“", "”"],
        ".": ["…", ",", "?", "!"]
    ]
}

// MARK: - Farbschema

/// Farben der Tastatur – bewusst an die Systemtastatur von iPadOS angelehnt:
/// helle Tasten auf grauem Grund im Light Mode, graue Tasten auf dunklem Grund
/// im Dark Mode.
private struct KeyboardPalette {
    let surface: Color
    let key: Color
    let keyPressed: Color
    let modifier: Color
    let modifierActive: Color
    let text: Color
    let modifierText: Color
    let modifierTextActive: Color
    let border: Color
    let shadow: Color
    let separator: Color
    let popup: Color
    let popupText: Color
    /// Hinterlegung des gewählten Zeichens im Akzent-Popup.
    let popupSelection: Color

    static func resolve(for scheme: ColorScheme) -> KeyboardPalette {
        switch scheme {
        case .dark:
            return KeyboardPalette(
                surface: Color(red: 0.10, green: 0.10, blue: 0.11).opacity(0.72),
                key: Color(red: 0.42, green: 0.42, blue: 0.44),
                keyPressed: Color(red: 0.53, green: 0.53, blue: 0.56),
                modifier: Color(red: 0.25, green: 0.25, blue: 0.27),
                modifierActive: Color(red: 0.86, green: 0.86, blue: 0.89),
                text: .white,
                modifierText: .white,
                modifierTextActive: .black,
                border: Color.white.opacity(0.06),
                shadow: Color.black.opacity(0.55),
                separator: Color.white.opacity(0.14),
                popup: Color(red: 0.20, green: 0.20, blue: 0.22),
                popupText: .white,
                popupSelection: Color.white.opacity(0.20)
            )
        default:
            return KeyboardPalette(
                surface: Color(red: 0.81, green: 0.83, blue: 0.86).opacity(0.92),
                key: .white,
                keyPressed: Color(white: 0.86),
                modifier: Color(red: 0.67, green: 0.70, blue: 0.75),
                modifierActive: .white,
                text: .black,
                modifierText: .black,
                modifierTextActive: .black,
                border: Color.black.opacity(0.05),
                shadow: Color.black.opacity(0.28),
                separator: Color.black.opacity(0.12),
                popup: .white,
                popupText: .black,
                popupSelection: Color.black.opacity(0.12)
            )
        }
    }
}

// MARK: - Tastatur

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
///
/// Aufbau und Bedienung folgen der Apple-Tastatur:
/// - QWERTZ mit Umlauten, `123`/`#+=`-Ebenen und Emoji-Ebene,
/// - Tasten lösen beim **Loslassen** aus (Löschen sofort und wiederholend),
/// - langes Drücken öffnet die Akzent-Auswahl (z. B. `a` → `à á â ä`),
/// - Doppeltipp auf die Umschalttaste aktiviert die Feststelltaste,
/// - die Eingabetaste zeigt die Aktion des Felds (z. B. „Fertig“).
struct AppKeyboardView: View {
    @ObservedObject private var hub = TextInputHub.shared
    @Environment(\.colorScheme) private var colorScheme

    /// Abstände des Host-Fensters. Die unterste Tastenreihe bleibt damit
    /// oberhalb des Home-Indikators – auch in der schwebenden Variante.
    let safeAreaInsets: UIEdgeInsets
    /// Ob die Tastatur über dem Inhalt schwebt (Zeichenfläche) statt unten
    /// eingebettet zu sein (Einstellungen, Sheets).
    let isFloating: Bool

    @State private var layer: KeyboardLayer = .letters
    @State private var isShifted = false
    @State private var isCapsLocked = false
    @State private var lastShiftTap: Date = .distantPast
    @State private var showsPasteKey = false

    init(safeAreaInsets: UIEdgeInsets, isFloating: Bool = false) {
        self.safeAreaInsets = safeAreaInsets
        self.isFloating = isFloating
    }

    private let keySpacing: CGFloat = 6

    /// Farben der Tastatur, abhängig vom System-Erscheinungsbild.
    private var palette: KeyboardPalette {
        KeyboardPalette.resolve(for: colorScheme)
    }

    var body: some View {
        GeometryReader { geometry in
            let rows = self.rows
            let keyHeight = AppKeyboardLayout.keyHeight(
                totalHeight: geometry.size.height,
                bottomInset: safeAreaInsets.bottom,
                rowCount: rows.count
            )
            let horizontalPadding = max(8, max(safeAreaInsets.left, safeAreaInsets.right))
            let gridWidth = max(160, geometry.size.width - horizontalPadding * 2)

            VStack(spacing: AppKeyboardLayout.rowSpacing) {
                shortcutBar(palette: palette)

                ForEach(rows) { row in
                    keyRow(
                        row,
                        palette: palette,
                        keyHeight: keyHeight,
                        gridWidth: gridWidth
                    )
                }
            }
            .padding(.leading, horizontalPadding)
            .padding(.trailing, horizontalPadding)
            .padding(.top, AppKeyboardLayout.topPadding)
            .padding(.bottom, AppKeyboardLayout.bottomPadding + safeAreaInsets.bottom)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .background(
            Group {
                if isFloating {
                    // Die schwebende Variante liegt auf einem Material des
                    // Hosts; die Tönung bleibt deshalb durchscheinend.
                    palette.surface
                } else {
                    // Eingebettet reicht der Hintergrund bis an den unteren
                    // Bildschirmrand (Home-Indikator), die Tasten darüber.
                    palette.surface.ignoresSafeArea(edges: .bottom)
                }
            }
        )
        .overlay(alignment: .top) {
            if !isFloating {
                Rectangle()
                    .fill(palette.separator)
                    .frame(height: 0.5)
            }
        }
        .onAppear { syncWithActiveInput() }
        .onChange(of: hub.activationCounter) { _, _ in
            syncWithActiveInput()
        }
    }

    // MARK: - Kopfzeile (Kurzbefehl-Leiste)

    private func shortcutBar(palette: KeyboardPalette) -> some View {
        HStack(spacing: 6) {
            barKey(palette: palette, icon: "arrow.left", label: "Cursor nach links") {
                hub.moveCaret(by: -1)
            }
            barKey(palette: palette, icon: "arrow.right", label: "Cursor nach rechts") {
                hub.moveCaret(by: 1)
            }

            Spacer(minLength: 0)

            if showsPasteKey {
                barKey(palette: palette, icon: "doc.on.clipboard", label: "Einfügen") {
                    hub.pasteFromPasteboard()
                    showsPasteKey = hub.canPaste
                }
            }

            barKey(palette: palette, icon: "chevron.down", label: "Tastatur ausblenden") {
                hub.suppressAppKeyboardForCurrentInput()
            }
        }
        .frame(height: AppKeyboardLayout.topBarHeight)
    }

    private func barKey(
        palette: KeyboardPalette,
        icon: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(palette.modifierText)
                .frame(width: 44, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(palette.modifier)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: - Zeilen

    private var rows: [KeyRow] {
        switch layer {
        case .letters: return letterRows
        case .numbers: return numberRows
        case .symbols: return symbolRows
        case .emoji: return emojiRows
        }
    }

    private var letterRows: [KeyRow] {
        [
            KeyRow(
                "letters-1",
                ["Q", "W", "E", "R", "T", "Z", "U", "I", "O", "P", "Ü"].map(characterKey)
            ),
            KeyRow(
                "letters-2",
                ["A", "S", "D", "F", "G", "H", "J", "K", "L", "Ö", "Ä"].map(characterKey),
                inset: 0.5
            ),
            KeyRow(
                "letters-3",
                [shiftKey] + ["Y", "X", "C", "V", "B", "N", "M", "ß"].map(characterKey) + [backspaceKey]
            ),
            // Wie bei Apple: In der Buchstaben-Ebene führt „123“ zu den Zahlen,
            // in der Zahlen-/Symbol-Ebene führt „ABC“ zurück.
            KeyRow("letters-4", bottomRow(leading: numberLayerKey))
        ]
    }

    private var numberRows: [KeyRow] {
        [
            KeyRow("numbers-1", ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"].map(characterKey)),
            KeyRow("numbers-2", ["-", "/", ":", ";", "(", ")", "€", "&", "@", "\""].map(characterKey)),
            KeyRow(
                "numbers-3",
                [symbolLayerKey] + [".", ",", "?", "!", "'", "+"].map(characterKey) + [backspaceKey],
                inset: 0.5
            ),
            KeyRow("numbers-4", bottomRow(leading: lettersLayerKey))
        ]
    }

    private var symbolRows: [KeyRow] {
        [
            KeyRow("symbols-1", ["[", "]", "{", "}", "#", "%", "^", "*", "+", "="].map(characterKey)),
            KeyRow("symbols-2", ["_", "\\", "|", "~", "<", ">", "€", "£", "¥", "•"].map(characterKey)),
            KeyRow(
                "symbols-3",
                [numberLayerKey] + [".", ",", "?", "!", "\"", "§"].map(characterKey) + [backspaceKey],
                inset: 0.5
            ),
            KeyRow("symbols-4", bottomRow(leading: lettersLayerKey))
        ]
    }

    private var emojiRows: [KeyRow] {
        [
            KeyRow("emoji-1", ["😀", "😃", "😄", "😁", "😅", "😂", "🙂", "🙃", "😉", "😊"].map(characterKey)),
            KeyRow("emoji-2", ["😍", "🥰", "😘", "😎", "🤩", "🥳", "😇", "🤗", "🤔", "😐"].map(characterKey), inset: 0.5),
            KeyRow("emoji-3", ["👍", "👎", "👏", "🙌", "🙏", "💪", "✌", "🤞", "👋", "✋"].map(characterKey)),
            KeyRow("emoji-4", emojiBottomRow)
        ]
    }

    /// Untere Reihe wie auf der Apple-Tastatur: Ebenen-Taste, Emoji-Taste,
    /// Leertaste, Punkt (mit „?!,“-Hinweis) und Eingabetaste.
    private func bottomRow(leading: KeySpec) -> [KeySpec] {
        [
            leading.withWidth(1.5),
            emojiKey,
            spaceKey,
            periodKey,
            returnKey
        ]
    }

    private var emojiBottomRow: [KeySpec] {
        [
            lettersLayerKey.withWidth(1.5),
            spaceKey,
            backspaceKey.withWidth(1.5)
        ]
    }

    // MARK: - Einzelne Tasten

    /// Zeichen-Taste (Basisform ist immer klein; Umschalten wandelt um).
    private func characterKey(_ text: String) -> KeySpec {
        KeySpec(
            id: "char-\(text)",
            title: text,
            action: .character(text),
            accents: KeyAccents.alternatives(for: text)
        )
    }

    private var lettersLayerKey: KeySpec {
        KeySpec(id: "layer-letters", title: "ABC", action: .layer(.letters), isModifier: true)
    }

    private var numberLayerKey: KeySpec {
        KeySpec(id: "layer-numbers", title: "123", action: .layer(.numbers), isModifier: true)
    }

    private var symbolLayerKey: KeySpec {
        KeySpec(id: "layer-symbols", title: "#+=", action: .layer(.symbols), isModifier: true)
    }

    private var emojiKey: KeySpec {
        KeySpec(
            id: "layer-emoji",
            icon: "face.smiling",
            action: .layer(.emoji),
            isModifier: true
        )
    }

    private var spaceKey: KeySpec {
        KeySpec(id: "space", title: nil, action: .space, width: 6)
    }

    /// Punkt-Taste der unteren Reihe mit kleinem „?!,“-Hinweis – wie bei Apple.
    private var periodKey: KeySpec {
        KeySpec(
            id: "period",
            title: ".",
            action: .character("."),
            isModifier: true,
            accents: [",", "?", "!", "…"],
            hint: "?!,"
        )
    }

    private var shiftKey: KeySpec {
        KeySpec(id: "shift", icon: "shift", action: .shift, isModifier: true, width: 1.5)
    }

    private var backspaceKey: KeySpec {
        KeySpec(
            id: "backspace",
            icon: "delete.left",
            action: .backspace,
            isModifier: true,
            repeats: true,
            width: 1.5
        )
    }

    /// Die Eingabetaste. Sie trägt – wie bei Apple – die Aktion des Felds.
    private var returnKey: KeySpec {
        KeySpec(
            id: "return",
            title: hub.activeReturnKeyTitle,
            icon: hub.activeReturnKeyTitle == nil ? "return" : nil,
            action: .newline,
            isModifier: true,
            width: 1.5
        )
    }

    // MARK: - Reihen-Darstellung

    private func keyRow(
        _ row: KeyRow,
        palette: KeyboardPalette,
        keyHeight: CGFloat,
        gridWidth: CGFloat
    ) -> some View {
        let count = row.keys.count
        let sumWidths = row.keys.reduce(CGFloat(0)) { $0 + $1.width }
        let usableWidth = gridWidth - keySpacing * CGFloat(max(0, count - 1))
        let unit = max(
            22,
            usableWidth / max(0.001, sumWidths + 2 * row.inset)
        )

        return HStack(spacing: keySpacing) {
            ForEach(Array(row.keys.enumerated()), id: \.offset) { index, key in
                let leading = row.inset * unit
                    + row.keys.prefix(index).reduce(CGFloat(0)) { $0 + $1.width * unit }
                    + keySpacing * CGFloat(index)
                keyView(
                    key,
                    palette: palette,
                    keyHeight: keyHeight,
                    width: key.width * unit,
                    centerX: leading + key.width * unit / 2,
                    gridWidth: gridWidth
                )
            }
        }
        .padding(.horizontal, row.inset * unit)
    }

    private func keyView(
        _ key: KeySpec,
        palette: KeyboardPalette,
        keyHeight: CGFloat,
        width: CGFloat,
        centerX: CGFloat,
        gridWidth: CGFloat
    ) -> some View {
        let isActive: Bool = {
            if case .shift = key.action { return isShifted || isCapsLocked }
            return false
        }()

        let popupCellWidth: CGFloat = 40
        let popupWidth = min(
            max(80, gridWidth - 8),
            CGFloat(key.accents.count) * popupCellWidth + 10
        )

        return KeyboardKeyButton(
            height: keyHeight,
            palette: palette,
            isModifier: key.isModifier,
            isActive: isActive,
            repeats: key.repeats,
            accents: key.accents,
            popupWidth: popupWidth,
            popupOffset: popupOffset(centerX: centerX, popupWidth: popupWidth, gridWidth: gridWidth),
            action: { perform(key) },
            insertAccent: { accent in insertAccent(accent) },
            label: { keyLabel(key, height: keyHeight) }
        )
        .frame(width: width)
        .zIndex(isActive ? 1 : 0)
    }

    /// Hält das Akzent-Popup innerhalb der Tastatur.
    private func popupOffset(centerX: CGFloat, popupWidth: CGFloat, gridWidth: CGFloat) -> CGFloat {
        let half = popupWidth / 2
        let clamped = min(max(centerX, half + 4), max(half + 4, gridWidth - half - 4))
        return clamped - centerX
    }

    @ViewBuilder
    private func keyLabel(_ key: KeySpec, height: CGFloat) -> some View {
        if let icon = resolvedIcon(for: key) {
            Image(systemName: icon)
                .font(.system(size: min(24, max(15, height * 0.30)), weight: .regular))
        } else if let title = key.title {
            if let hint = key.hint {
                VStack(spacing: -3) {
                    Text(hint)
                        .font(.system(size: 9, weight: .regular, design: .default))
                        .opacity(0.8)
                    Text(displayTitle(for: key, base: title))
                        .font(.system(size: min(28, max(19, height * 0.28)), weight: .regular, design: .default))
                }
            } else {
                Text(displayTitle(for: key, base: title))
                    .font(.system(size: keyFontSize(key, height: height), weight: .regular, design: .default))
            }
        } else {
            // Leertaste: wie bei Apple ohne Beschriftung.
            Color.clear
        }
    }

    private func keyFontSize(_ key: KeySpec, height: CGFloat) -> CGFloat {
        switch key.action {
        case .layer, .newline, .shift, .backspace:
            return min(18, max(13, height * 0.30))
        default:
            return min(28, max(19, height * 0.28))
        }
    }

    /// Symbol einer Taste. Die Umschalttaste zeigt – wie bei Apple – den
    /// gefüllten Pfeil bei aktiver Umschaltung und die Feststelltaste, wenn
    /// sie doppelt angetippt wurde.
    private func resolvedIcon(for key: KeySpec) -> String? {
        guard key.action == .shift else { return key.icon }
        if isCapsLocked { return "capslock.fill" }
        return isShifted ? "shift.fill" : "shift"
    }

    private func displayTitle(for key: KeySpec, base: String) -> String {
        guard layer == .letters,
              case .character(let value) = key.action,
              value.first?.isLetter == true else { return base }
        return letterForm(value)
    }

    /// Form eines Buchstabens je nach Umschalt- bzw. Feststelltaste. „ß“ bleibt
    /// „ß“, weil `uppercased()` daraus „SS“ machen würde.
    private func letterForm(_ value: String) -> String {
        guard value.count == 1, value.first?.isLetter == true else { return value }
        if isShifted || isCapsLocked {
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
            insert(text)

        case .shift:
            let now = Date()
            if now.timeIntervalSince(lastShiftTap) < 0.45 {
                // Doppeltipp = Feststelltaste (wie bei Apple).
                isCapsLocked.toggle()
                isShifted = false
            } else {
                isShifted.toggle()
                if isShifted { isCapsLocked = false }
            }
            lastShiftTap = now
            Haptics.select()

        case .backspace:
            // Wird von `KeyboardKeyButton` schon beim Drücken ausgelöst und
            // beim Halten wiederholt (siehe `repeats`).
            hub.deleteBackward()

        case .space:
            // Doppelter Leertipp wird – wie bei Apple – zu „. “.
            if hub.insertSpace() {
                if hub.isSentenceMode { isShifted = true }
            } else {
                updateShiftState(after: " ")
            }

        case .newline:
            if hub.insertNewline() {
                if hub.isSentenceMode { isShifted = true }
            }

        case .caret(let offset):
            hub.moveCaret(by: offset)

        case .layer(let target):
            layer = target
            isShifted = false
            isCapsLocked = false
            Haptics.select()
        }
    }

    /// Fügt ein Zeichen ein und pflegt dabei den Umschalt-Zustand.
    private func insert(_ text: String) {
        hub.insert(text)
        updateShiftState(after: text)
    }

    /// Ein im Popup gewähltes Zeichen – bei aktiver Umschaltung groß
    /// geschrieben (Apple zeigt bei Shift ebenfalls die großen Varianten).
    private func insertAccent(_ accent: String) {
        guard isShifted || isCapsLocked, layer == .letters else {
            insert(accent)
            return
        }
        let upperText = accent.uppercased()
        // „ß“ wird nicht zu „SS“.
        insert(upperText.count == accent.count ? upperText : accent)
    }

    private func shiftedText(for base: String) -> String {
        guard layer == .letters else { return base }
        return letterForm(base)
    }

    private func updateShiftState(after inserted: String) {
        guard layer == .letters else { return }
        guard !isCapsLocked else { return }

        if hub.isSentenceMode, inserted == ". " || inserted == "." || inserted == "!" || inserted == "?" {
            isShifted = true
            return
        }
        if inserted.count == 1, inserted.first?.isLetter == true {
            isShifted = false
        }
    }

    /// Beim Wechsel des Textfelds Schrift/Shift auf das neue Feld abstimmen.
    private func syncWithActiveInput() {
        isShifted = hub.prefersUppercaseStart
        isCapsLocked = false
        layer = .letters
        showsPasteKey = hub.canPaste
    }
}

// MARK: - Tastenansicht

/// Einzelne Taste im Stil der Apple-Tastatur.
///
/// - Die Taste löst beim **Loslassen** aus (`action`).
/// - Tasten mit Wiederholung (Löschen) wirken sofort beim Drücken und
///   wiederholen sich, solange sie gehalten werden (`repeats`).
/// - Lange gedrückt zeigt sie – falls vorhanden – die Alternativen
///   (Akzente/Satzzeichen); seitliches Ziehen wählt aus.
private struct KeyboardKeyButton<Label: View>: View {
    let height: CGFloat
    let palette: KeyboardPalette
    let isModifier: Bool
    let isActive: Bool
    let repeats: Bool
    let accents: [String]
    let popupWidth: CGFloat
    let popupOffset: CGFloat
    let action: () -> Void
    let insertAccent: (String) -> Void
    let label: Label

    @State private var isPressed = false
    @State private var isPopupOpen = false
    @State private var selectedAccentIndex: Int?
    @State private var popupTask: Task<Void, Never>?
    @State private var repeatTask: Task<Void, Never>?

    init(
        height: CGFloat,
        palette: KeyboardPalette,
        isModifier: Bool,
        isActive: Bool = false,
        repeats: Bool = false,
        accents: [String] = [],
        popupWidth: CGFloat = 0,
        popupOffset: CGFloat = 0,
        action: @escaping () -> Void,
        insertAccent: @escaping (String) -> Void,
        @ViewBuilder label: () -> Label
    ) {
        self.height = height
        self.palette = palette
        self.isModifier = isModifier
        self.isActive = isActive
        self.repeats = repeats
        self.accents = accents
        self.popupWidth = popupWidth
        self.popupOffset = popupOffset
        self.action = action
        self.insertAccent = insertAccent
        self.label = label()
    }

    private let cornerRadius: CGFloat = 6
    private let popupHeight: CGFloat = 52

    var body: some View {
        label
            .foregroundColor(foregroundColor)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(backgroundColor)
                    .shadow(color: palette.shadow, radius: 0, x: 0, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(palette.border, lineWidth: 0.5)
            )
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .gesture(pressGesture)
            .overlay(alignment: .top) {
                if isPopupOpen, !accents.isEmpty {
                    popup
                        .offset(x: popupOffset, y: -(popupHeight + 6))
                }
            }
            .onDisappear {
                popupTask?.cancel()
                stopRepeating()
            }
    }

    // MARK: Darstellung

    private var foregroundColor: Color {
        if isModifier {
            return isActive ? palette.modifierTextActive : palette.modifierText
        }
        return palette.text
    }

    private var backgroundColor: Color {
        if isModifier {
            return isActive ? palette.modifierActive : palette.modifier
        }
        if isPressed {
            return palette.keyPressed
        }
        return palette.key
    }

    private var popup: some View {
        let cellWidth = max(28, (popupWidth - 10) / CGFloat(max(1, accents.count)))
        return HStack(spacing: 0) {
            ForEach(Array(accents.enumerated()), id: \.offset) { index, value in
                Text(value)
                    .font(.system(size: 22, weight: .regular, design: .default))
                    .foregroundColor(palette.popupText)
                    .frame(width: cellWidth, height: popupHeight - 10)
                    .background(
                        Circle()
                            .fill(palette.popupSelection)
                            .opacity(selectedAccentIndex == index ? 1 : 0)
                    )
            }
        }
        .padding(.horizontal, 5)
        .frame(width: popupWidth, height: popupHeight)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(palette.popup)
                .shadow(color: Color.black.opacity(0.30), radius: 10, x: 0, y: 5)
        )
        .fixedSize()
        .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: .bottom)))
    }

    // MARK: Gesten

    private var pressGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !isPressed {
                    beginPress()
                }
                if isPopupOpen, !accents.isEmpty {
                    selectedAccentIndex = accentIndex(for: value.translation.width)
                }
            }
            .onEnded { _ in
                endPress()
            }
    }

    private func beginPress() {
        isPressed = true
        Haptics.select()

        guard !repeats else {
            // Löschen wirkt sofort und wiederholt sich beim Halten.
            action()
            startRepeating()
            return
        }

        guard !accents.isEmpty else { return }
        popupTask?.cancel()
        popupTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: 320_000_000)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.12)) {
                isPopupOpen = true
                selectedAccentIndex = nil
            }
        }
    }

    private func endPress() {
        popupTask?.cancel()
        popupTask = nil
        stopRepeating()

        let wasPopupOpen = isPopupOpen
        let chosen = selectedAccentIndex.flatMap { index in
            accents.indices.contains(index) ? accents[index] : nil
        }

        isPressed = false
        isPopupOpen = false
        selectedAccentIndex = nil

        guard !repeats else { return }

        if wasPopupOpen, let chosen {
            insertAccent(chosen)
        } else {
            action()
        }
    }

    /// Auswahl im Popup: erst ab einer halben Zellenbreite wird ein Zeichen
    /// gewählt – davor bleibt es beim Grundzeichen der Taste.
    private func accentIndex(for offset: CGFloat) -> Int? {
        guard !accents.isEmpty else { return nil }
        let cellWidth = max(28, (popupWidth - 10) / CGFloat(accents.count))
        let steps = (offset - cellWidth * 0.5) / cellWidth
        guard steps >= 0 else { return nil }
        return min(Int(steps.rounded(.down)), accents.count - 1)
    }

    private func startRepeating() {
        stopRepeating()
        repeatTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: 400_000_000)
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

    private func stopRepeating() {
        repeatTask?.cancel()
        repeatTask = nil
    }
}
