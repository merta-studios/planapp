import SwiftUI
import UIKit

/// Geschätzte Höhe eines Textfelds inkl. Innenabstand – dieselbe Rechnung
/// wie beim Rendern der Notiz-Vorschau, damit Klemme und Vorschau übereinstimmen.
func estimatedTextBoxHeight(
    _ box: NoteTextBox,
    fontStyle: NoteTextFontStyle = .system
) -> CGFloat {
    let width = box.width.isFinite ? CGFloat(box.width) : 240
    let fontSize = box.fontSize.isFinite ? CGFloat(box.fontSize) : 17
    let innerWidth = max(20, width - 16)
    let bounding = (box.text as NSString).boundingRect(
        with: CGSize(width: innerWidth, height: .greatestFiniteMagnitude),
        options: [.usesLineFragmentOrigin],
        attributes: [.font: fontStyle.uiFont(size: max(1, fontSize))],
        context: nil
    )
    let height = bounding.height.isFinite ? bounding.height : 0
    return max(36, ceil(height) + 16)
}

/// Ebene über der PencilKit-Zeichenfläche, die frei bewegliche Textfelder
/// verwaltet.
///
/// Bedienung:
/// - Tippen auf freie Fläche (Text-Werkzeug aktiv): neues Textfeld, direkt
///   mit Tastatur.
/// - Tippen auf ein Feld: auswählen (verschiebbar, Breite ändern, löschen).
/// - Nochmal tippen auf das ausgewählte Feld: Text bearbeiten.
/// - Tippen daneben: Bearbeitung beenden und Auswahl aufheben; der nächste
///   Tipp erzeugt wieder ein neues Feld.
/// - Felder, die leer sind oder nur Leerzeichen enthalten, verschwinden
///   automatisch, sobald sie weder ausgewählt noch in Bearbeitung sind.
///
/// Tastatur-Fokus: Diese Ebene steuert den Fokus ausschließlich über
/// `editingID`. Genau eine Box ist „in Bearbeitung“, und nur für diese wird
/// ein `NoteTextEditor` (UITextView) erzeugt. Das Anfordern der Systemtastatur
/// übernimmt der Editor selbst, sobald seine View in einem aktiven Key-Window
/// hängt (siehe `Utils/SystemKeyboardFocus.swift`). Hier wird deshalb weder
/// `becomeFirstResponder()` aufgerufen noch mit Verzögerungen gearbeitet.
///
/// WICHTIG (Stabilität): Diese Ebene arbeitet bewusst **ohne**
/// `ForEach($textBoxes)`-Element-Bindings. Ein Element-Binding hält einen
/// Index in das Array; wird ein Feld entfernt (z. B. ein leeres Feld beim
/// Verlassen der Tastatur), greift ein noch lebendes Binding auf einen
/// ungültigen Index zu und die App stürzt mit "Index out of range" ab. Genau
/// das war die Absturzursache beim Text-Werkzeug und bei „Handschrift in Text
/// umwandeln“. Stattdessen werden Werte nach unten gereicht und Änderungen
/// über die stabile `id` zurückgemeldet.
struct NoteTextBoxesLayer: View {
    @Binding var textBoxes: [NoteTextBox]
    @Binding var selectedID: UUID?
    @Binding var editingID: UUID?
    let areaSize: CGSize
    /// Undo-Registrierung: (Snapshot vorher, Snapshot nachher).
    let registerUndo: (_ before: [NoteTextBox], _ after: [NoteTextBox]) -> Void
    /// Schriftart der Textfelder.
    var textFontStyle: NoteTextFontStyle = .system
    /// Wirksame Skalierung der Zeichenfläche. Rahmen und Bedienelemente werden
    /// gegen diese Skalierung korrigiert, damit sie auf dem Bildschirm immer
    /// gleich groß wirken.
    var canvasScale: CGFloat = 1

    static let coordinateSpaceName = "noteTextBoxesLayer"

    @State private var gestureSnapshot: [NoteTextBox]? = nil
    @State private var editSessionSnapshot: [NoteTextBox]? = nil

    private let margin: CGFloat = 6

    private var safeAreaSize: CGSize {
        CGSize(
            width: areaSize.width.isFinite && areaSize.width > 0 ? areaSize.width : 320,
            height: areaSize.height.isFinite && areaSize.height > 0 ? areaSize.height : 180
        )
    }

    /// Das ausgewählte bzw. in Bearbeitung befindliche Feld liegt **ganz oben**,
    /// damit seine Griffe und Knöpfe nie hinter anderen Textfeldern verschwinden.
    /// Über `zIndex` statt Umsortieren: Die Views bleiben an Ort und Stelle,
    /// ein aktives UITextView wird dadurch nicht umgehängt.
    private func isFrontBox(_ id: UUID) -> Bool {
        id == selectedID || id == editingID
    }

    var body: some View {
        let size = safeAreaSize

        return ZStack(alignment: .topLeading) {
            // Explizite ID verhindert, dass SwiftUI bei einer gerade
            // erzeugten/entfernten Box einen veralteten Element-Index
            // wiederverwendet. Die Box wird weiter als Wert übergeben und
            // Änderungen gehen ausschließlich über ihre stabile UUID zurück.
            ForEach(textBoxes, id: \.id) { box in
                NoteTextBoxView(
                    box: box,
                    isSelected: selectedID == box.id,
                    isEditing: editingID == box.id,
                    areaSize: size,
                    canvasScale: canvasScale,
                    onSelect: { select(box.id) },
                    onBeginEditing: { beginEditing(box.id) },
                    onEndEditing: { endEditing(box.id) },
                    onDelete: { deleteBox(id: box.id) },
                    onChangeText: { newText in
                        updateBox(id: box.id) { $0.text = newText }
                    },
                    onGestureStart: {
                        if gestureSnapshot == nil {
                            gestureSnapshot = textBoxes
                        }
                    },
                    onMove: { newOrigin in
                        updateBox(id: box.id) {
                            $0.x = Double(newOrigin.x)
                            $0.y = Double(newOrigin.y)
                        }
                    },
                    onResize: { newX, newWidth in
                        updateBox(id: box.id) {
                            $0.x = Double(newX)
                            $0.width = Double(newWidth)
                        }
                    },
                    onGestureEnd: { finishGesture() },
                    onChangeFontSize: { delta in
                        changeFontSize(id: box.id, by: delta)
                    },
                    fontStyle: textFontStyle
                )
                .zIndex(isFrontBox(box.id) ? 1 : 0)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .coordinateSpace(name: Self.coordinateSpaceName)
        .onChange(of: selectedID) { _, newValue in
            if editingID == nil {
                pruneEmptyBoxes(keeping: newValue)
            }
        }
        .onChange(of: editingID) { oldValue, newValue in
            if let newValue, newValue != oldValue {
                if editSessionSnapshot == nil {
                    editSessionSnapshot = textBoxes
                }
            } else if oldValue != nil, newValue == nil {
                let before = editSessionSnapshot
                editSessionSnapshot = nil
                pruneEmptyBoxes(keeping: selectedID)
                if let before, before != textBoxes {
                    registerUndo(before, textBoxes)
                }
            }
        }
    }

    // MARK: - Auswahl & Bearbeitung

    private func select(_ id: UUID) {
        if editingID == id { return }
        Haptics.select()
        // Eine laufende Bearbeitung wird beendet; das onChange oben
        // registriert dafür den Undo-Schritt.
        if editingID != nil { editingID = nil }
        if selectedID != id { selectedID = id }
    }

    private func beginEditing(_ id: UUID) {
        guard textBoxes.contains(where: { $0.id == id }) else { return }
        guard editingID != id else { return }
        Haptics.select()
        selectedID = id
        editingID = id
    }

    /// Wird vom Textfeld gemeldet, wenn die Tastatur/der Fokus nativ endet.
    private func endEditing(_ id: UUID) {
        guard editingID == id else { return }
        editingID = nil
    }

    // MARK: - Erstellen (Tipp auf leere Fläche, Text-Werkzeug)

    /// Neues Textfeld an der Tipp-Stelle. Reine Rechnung ohne Zustand: Die
    /// Ebene darüber (Overlay) fügt es ein, damit der Tipp-Catcher ganz
    /// unten liegen kann – unter Text- **und** Bildebene.
    static func makeNewBox(
        at location: CGPoint,
        areaSize: CGSize,
        colorHex: String,
        fontSize: Double
    ) -> NoteTextBox? {
        let size = CGSize(
            width: areaSize.width.isFinite && areaSize.width > 0 ? areaSize.width : 320,
            height: areaSize.height.isFinite && areaSize.height > 0 ? areaSize.height : 180
        )
        let margin: CGFloat = 6
        guard location.x.isFinite, location.y.isFinite else { return nil }

        let defaultWidth: CGFloat = 240
        let minWidth: CGFloat = 120

        // Nie über den rechten Rand hinaus: Das Feld wird notfalls schmaler
        // oder rutscht nach links, der Text bricht dann automatisch um.
        var x = max(margin, location.x)
        var width = defaultWidth
        let maxAvailable = size.width - margin - x
        if width > maxAvailable {
            width = max(minWidth, maxAvailable)
            if maxAvailable < minWidth {
                width = minWidth
                x = max(margin, size.width - margin - width)
            }
        }
        let y = min(max(margin, location.y - 20), max(margin, size.height - 60))

        let rawBox = NoteTextBox(
            x: Double(x),
            y: Double(y),
            width: Double(width),
            fontSize: fontSize,
            colorHex: colorHex.isEmpty ? NoteTextBox.defaultColorHex : colorHex
        )
        return rawBox.sanitized(in: size)
    }

    // MARK: - Löschen


    private func deleteBox(id: UUID) {
        guard textBoxes.contains(where: { $0.id == id }) else { return }
        Haptics.tap()
        let before = textBoxes
        if editingID == id { editingID = nil }
        if selectedID == id { selectedID = nil }
        // UIKit-Textfelder nicht während einer Löschanimation aus dem
        // View-Baum nehmen; der aktive First Responder wird oben explizit
        // beendet und kann so sauber dismantled werden.
        textBoxes.removeAll { $0.id == id }
        editSessionSnapshot = nil
        registerUndo(before, textBoxes)
    }

    // MARK: - Änderungen an einem Feld (immer über die stabile id)

    private func updateBox(id: UUID, _ transform: (inout NoteTextBox) -> Void) {
        guard let index = textBoxes.firstIndex(where: { $0.id == id }) else { return }
        var updated = textBoxes[index]
        transform(&updated)
        guard let sanitized = updated.sanitized(in: safeAreaSize) else { return }
        guard sanitized != textBoxes[index] else { return }
        textBoxes[index] = sanitized
    }

    private func changeFontSize(id: UUID, by delta: Double) {
        guard textBoxes.contains(where: { $0.id == id }) else { return }
        let before = textBoxes
        Haptics.select()

        updateBox(id: id) { box in
            box.fontSize = min(48, max(10, box.fontSize + delta))
        }

        // Durch größere Schrift könnte das Feld unten herausragen → einklemmen.
        if let index = textBoxes.firstIndex(where: { $0.id == id }) {
            var clamped = textBoxes[index]
            clampBoxIntoArea(&clamped)
            if clamped != textBoxes[index] {
                textBoxes[index] = clamped
            }
        }

        if before != textBoxes {
            registerUndo(before, textBoxes)
        }
    }

    /// Wird nach einer Zieh-Geste (Verschieben oder Breite ändern) aufgerufen.
    private func finishGesture() {
        guard let before = gestureSnapshot else { return }
        gestureSnapshot = nil
        guard before != textBoxes else { return }
        registerUndo(before, textBoxes)
    }

    // MARK: - Aufräumen & Klemmen

    /// Entfernt Felder, die leer sind oder nur Leerzeichen enthalten.
    /// Das gerade ausgewählte bzw. bearbeitete Feld bleibt immer erhalten.
    private func pruneEmptyBoxes(keeping keepID: UUID?) {
        let editing = editingID
        let filtered = textBoxes.filter { box in
            if box.id == keepID || box.id == editing { return true }
            return !box.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        guard filtered.count != textBoxes.count else { return }

        let remainingIDs = Set(filtered.map(\.id))
        textBoxes = filtered

        if let current = selectedID, !remainingIDs.contains(current) {
            selectedID = nil
        }
        if let current = editingID, !remainingIDs.contains(current) {
            editingID = nil
        }
    }

    /// Klemmt ein Feld vollständig in die Zeichenfläche ein.
    private func clampBoxIntoArea(_ box: inout NoteTextBox) {
        let size = safeAreaSize
        let height = estimatedTextBoxHeight(box, fontStyle: textFontStyle)
        let maxX = max(Double(margin), Double(size.width) - box.width - Double(margin))
        let maxY = max(Double(margin), Double(size.height - height) - Double(margin))
        box.x = min(max(Double(margin), box.x), maxX)
        box.y = min(max(Double(margin), box.y), maxY)
    }
}

/// Einzelnes Textfeld: im Verschiebe-Modus (ausgewählt) mit Rahmen,
/// Lösch-Kreuz, Seiten-Griffen und Schriftgrößen-Steuerung; im
/// Bearbeiten-Modus mit echtem Texteingabefeld (Tastatur), ohne Kreuz
/// und ohne Seiten-Griffe.
///
/// Das Feld bekommt seinen Zustand als **Wert** (kein Binding) und meldet
/// jede Änderung über Callbacks zurück – dadurch kann es gefahrlos entfernt
/// werden, während eine Geste oder die Tastatur noch aktiv ist.
private struct NoteTextBoxView: View {
    let box: NoteTextBox
    let isSelected: Bool
    let isEditing: Bool
    let areaSize: CGSize
    let canvasScale: CGFloat
    let onSelect: () -> Void
    let onBeginEditing: () -> Void
    let onEndEditing: () -> Void
    let onDelete: () -> Void
    let onChangeText: (String) -> Void
    let onGestureStart: () -> Void
    let onMove: (CGPoint) -> Void
    let onResize: (_ newX: CGFloat, _ newWidth: CGFloat) -> Void
    let onGestureEnd: () -> Void
    let onChangeFontSize: (Double) -> Void
    /// Schriftart aller Textfelder (aus den Einstellungen).
    let fontStyle: NoteTextFontStyle

    @State private var moveStart: CGPoint? = nil
    @State private var resizeStartX: CGFloat? = nil
    @State private var resizeStartWidth: CGFloat? = nil

    private let minWidth: CGFloat = 90
    private let margin: CGFloat = 6
    private var inverseScale: CGFloat { 1 / max(0.01, canvasScale) }
    /// Durchmesser der runden Schriftgrößen-Knöpfe (bewusst groß genug,
    /// um sie auch mit dem Finger sicher zu treffen). Gegen die Zoom-
    /// Skalierung korrigiert, damit sie auf dem Bildschirm gleich groß bleiben.
    private var fontSizeButtonDiameter: CGFloat { 46 * inverseScale }
    /// Durchmesser der beiden blauen Breiten-Griffe links und rechts am Feld.
    /// Auf dem iPhone bewusst kleiner, damit die Griffe das Feld nicht
    /// verdecken (wie bei den Bild-Griffen in der Bild-Ebene).
    private var handleDiameter: CGFloat { (DeviceLayout.isPhone ? 20 : 24) * inverseScale }

    private enum ResizeEdge {
        case leading
        case trailing
    }

    private var boxWidth: CGFloat {
        let value = CGFloat(box.width)
        return value.isFinite && value > 0 ? value : 240
    }

    private var boxFontSize: CGFloat {
        let value = CGFloat(box.fontSize)
        return value.isFinite && value > 0 ? value : 17
    }

    private var boxOrigin: CGPoint {
        CGPoint(
            x: CGFloat(box.x).isFinite ? CGFloat(box.x) : margin,
            y: CGFloat(box.y).isFinite ? CGFloat(box.y) : margin
        )
    }

    /// Textfarbe des Feldes (über die Farb-Slots der Werkzeugleiste änderbar).
    private var boxTextUIColor: UIColor {
        UIColor(hex: box.colorHex.isEmpty ? NoteTextBox.defaultColorHex : box.colorHex)
    }

    var body: some View {
        Group {
            if isEditing {
                editingContent
            } else {
                displayContent
            }
        }
        // Auswahl-Rahmen und Steuerelemente je nach Modus. Rahmen und Griffe
        // werden gegen die Zoom-Skalierung korrigiert, damit sie auf dem
        // Bildschirm immer gleich groß wirken (siehe Issue: Ränder und Buttons
        // sollen beim Zoomen nicht mitwachsen).
        .background(
            RoundedRectangle(cornerRadius: 8 * inverseScale, style: .continuous)
                .fill(isSelected || isEditing ? Color.blue.opacity(0.07) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8 * inverseScale, style: .continuous)
                .strokeBorder(
                    (isSelected || isEditing) ? Color.blue.opacity(0.85) : Color.blue.opacity(0.28),
                    style: StrokeStyle(
                        lineWidth: (isSelected || isEditing ? 1.5 : 1) * inverseScale,
                        dash: (isSelected || isEditing) ? [] : [4 * inverseScale, 3 * inverseScale]
                    )
                )
        )
        .overlay(alignment: .leading) {
            // Seiten-Griff nur im Verschiebe-Modus (nicht beim Bearbeiten).
            if isSelected, !isEditing {
                resizeHandle(edge: .leading)
                    .offset(x: -13 * inverseScale)
            }
        }
        .overlay(alignment: .trailing) {
            if isSelected, !isEditing {
                resizeHandle(edge: .trailing)
                    .offset(x: 13 * inverseScale)
            }
        }
        .overlay(alignment: .topTrailing) {
            // Lösch-Kreuz nur im Verschiebe-Modus (nicht beim Bearbeiten).
            if isSelected, !isEditing {
                deleteButton
                    .offset(x: 14 * inverseScale, y: -14 * inverseScale)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            // Schriftgröße bleibt in beiden Modi verfügbar.
            if isSelected || isEditing {
                fontSizeControls
                    .offset(y: (fontSizeButtonDiameter + 8 * inverseScale))
            }
        }
        .offset(x: boxOrigin.x, y: boxOrigin.y)
    }

    // MARK: - Inhalte

    /// Anzeige-Modus: reiner Text (kein TextField!), damit Verschieben mit
    /// Finger oder Apple Pencil sofort greift und nichts erst beim Loslassen
    /// "springt".
    private var displayContent: some View {
        let trimmed = box.text.trimmingCharacters(in: .whitespacesAndNewlines)

        return Text(trimmed.isEmpty ? "Text" : box.text)
            .font(fontStyle.font(size: boxFontSize))
            // Die Zeichenfläche ist immer weiß, auch wenn die App im Dark
            // Mode läuft. Deshalb kein dynamisches `.primary` verwenden.
            .foregroundColor(trimmed.isEmpty ? .gray : Color(uiColor: boxTextUIColor))
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(width: max(20, boxWidth - 16), alignment: .topLeading)
            .padding(8)
            .frame(width: boxWidth, alignment: .topLeading)
            .contentShape(Rectangle())
            .gesture(moveGesture)
            // Ein Tipp wählt aus, der nächste Tipp öffnet die Tastatur.
            // (Bewusst kein kombiniertes Einzel-/Doppeltippen: Das war in
            // SwiftUI unzuverlässig, sodass das Bearbeiten nie startete.)
            .onTapGesture {
                if isSelected {
                    onBeginEditing()
                } else {
                    onSelect()
                }
            }
    }

    /// Bearbeiten-Modus: natives UITextView mit garantierter Tastatur
    /// (und weiterhin Scribble-Unterstützung für den Apple Pencil).
    private var editingContent: some View {
        NoteTextEditor(
            text: box.text,
            fontSize: boxFontSize,
            fontStyle: fontStyle,
            textColor: boxTextUIColor,
            isEditing: isEditing,
            onChangeText: onChangeText,
            onEndEditing: onEndEditing
        )
        // Ein UITextView gehört immer zu genau einer Box. So wird beim
        // Wechsel von Anzeige- zu Editiermodus niemals ein alter UIKit-
        // Responder mit einer anderen UUID weiterverwendet.
        .id(box.id)
        .frame(
            width: boxWidth,
            height: estimatedTextBoxHeight(box, fontStyle: fontStyle),
            alignment: .topLeading
        )
    }

    // MARK: - Verschieben (sofort, folgt dem Finger)

    private var moveGesture: some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .named(NoteTextBoxesLayer.coordinateSpaceName))
            .onChanged { value in
                if moveStart == nil {
                    moveStart = boxOrigin
                    onGestureStart()
                    if !isSelected {
                        onSelect()
                    }
                    Haptics.tap()
                }
                guard let start = moveStart else { return }
                let boxHeight = estimatedTextBoxHeight(box, fontStyle: fontStyle)
                let maxX = max(margin, areaSize.width - boxWidth - margin)
                let maxY = max(margin, areaSize.height - boxHeight - margin)
                let newX = min(max(margin, start.x + value.translation.width), maxX)
                let newY = min(max(margin, start.y + value.translation.height), maxY)
                onMove(CGPoint(x: newX, y: newY))
            }
            .onEnded { _ in
                let hadStarted = moveStart != nil
                moveStart = nil
                if hadStarted {
                    onGestureEnd()
                }
            }
    }

    // MARK: - Breite ändern

    private func resizeHandle(edge: ResizeEdge) -> some View {
        Circle()
            .fill(Color.blue)
            .frame(width: handleDiameter, height: handleDiameter)
            .overlay(
                Image(systemName: "arrow.left.and.right")
                    .font(.system(size: 10 * inverseScale, weight: .bold))
                    .foregroundColor(.white)
            )
            .shadow(color: Color.black.opacity(0.25), radius: 3 * inverseScale, x: 0, y: 1 * inverseScale)
            .contentShape(Circle().inset(by: -12 * inverseScale))
            .gesture(resizeGesture(edge: edge))
    }

    private func resizeGesture(edge: ResizeEdge) -> some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .named(NoteTextBoxesLayer.coordinateSpaceName))
            .onChanged { value in
                if resizeStartX == nil {
                    resizeStartX = boxOrigin.x
                    resizeStartWidth = boxWidth
                    onGestureStart()
                }
                guard let startX = resizeStartX, let startWidth = resizeStartWidth else { return }

                switch edge {
                case .trailing:
                    let maxWidth = max(minWidth, areaSize.width - margin - startX)
                    let newWidth = min(max(minWidth, startWidth + value.translation.width), maxWidth)
                    onResize(startX, newWidth)
                case .leading:
                    let proposedX = startX + value.translation.width
                    let maxX = max(margin, startX + startWidth - minWidth)
                    let newX = min(max(margin, proposedX), maxX)
                    onResize(newX, startWidth + (startX - newX))
                }
            }
            .onEnded { _ in
                let hadStarted = resizeStartX != nil
                resizeStartX = nil
                resizeStartWidth = nil
                if hadStarted {
                    onGestureEnd()
                }
            }
    }

    // MARK: - Löschen & Schriftgröße

    private var deleteButton: some View {
        Button(action: onDelete) {
            Image(systemName: "xmark")
                .font(.system(size: 11 * inverseScale, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 26 * inverseScale, height: 26 * inverseScale)
                .background(Circle().fill(Color.red))
                .shadow(color: Color.black.opacity(0.25), radius: 3 * inverseScale, x: 0, y: 1 * inverseScale)
        }
        .buttonStyle(.plain)
        .hoverEffect(.lift)
        .accessibilityLabel("Textfeld löschen")
    }

    /// Große, runde Liquid-Glass-Knöpfe zum Ändern der Schriftgröße.
    private var fontSizeControls: some View {
        HStack(spacing: 10 * inverseScale) {
            fontSizeButton(
                systemName: "textformat.size.smaller",
                accessibilityLabel: "Schrift kleiner",
                delta: -2
            )
            fontSizeButton(
                systemName: "textformat.size.larger",
                accessibilityLabel: "Schrift größer",
                delta: 2
            )
        }
    }

    private func fontSizeButton(
        systemName: String,
        accessibilityLabel: String,
        delta: Double
    ) -> some View {
        Button {
            onChangeFontSize(delta)
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 19 * inverseScale, weight: .semibold))
                .foregroundColor(.primary)
                .frame(width: fontSizeButtonDiameter, height: fontSizeButtonDiameter)
                .background(
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                        // Leichte Glanzkante oben – der typische
                        // „Flüssigglas“-Eindruck.
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.45),
                                        Color.white.opacity(0.05)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .blendMode(.plusLighter)
                            .opacity(0.5)
                    }
                )
                .overlay(
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.75),
                                    Color.white.opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1 * inverseScale
                        )
                )
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(0.2), radius: 6 * inverseScale, x: 0, y: 3 * inverseScale)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .hoverEffect(.lift)
        .accessibilityLabel(accessibilityLabel)
    }
}
