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
    let isTextToolActive: Bool
    let areaSize: CGSize
    /// Undo-Registrierung: (Snapshot vorher, Snapshot nachher).
    let registerUndo: (_ before: [NoteTextBox], _ after: [NoteTextBox]) -> Void
    /// Farbe, Schriftgröße und Schriftart der Textfelder.
    var newTextColorHex: String = NoteTextBox.defaultColorHex
    var newTextFontSize: Double = NoteTextBox.defaultFontSize
    var textFontStyle: NoteTextFontStyle = .system

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

    var body: some View {
        let size = safeAreaSize

        return ZStack(alignment: .topLeading) {
            // Hintergrund fängt Tipp-Gesten ab: Bearbeiten beenden, Auswahl
            // aufheben oder (mit Text-Werkzeug) ein neues Feld erstellen.
            if isTextToolActive || selectedID != nil || editingID != nil {
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        SpatialTapGesture(coordinateSpace: .local)
                            .onEnded { value in
                                handleBackgroundTap(at: value.location)
                            }
                    )
            }

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
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .coordinateSpace(name: Self.coordinateSpaceName)
        .clipped()
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

    private func finishEditingAndDeselect() {
        let wasEditing = editingID != nil
        if wasEditing { editingID = nil }
        if selectedID != nil { selectedID = nil }
        if !wasEditing {
            pruneEmptyBoxes(keeping: nil)
        }
    }

    // MARK: - Tipp auf leere Fläche

    private func handleBackgroundTap(at location: CGPoint) {
        if editingID != nil || selectedID != nil {
            // Bearbeiten beenden und Auswahl aufheben – der nächste Tipp
            // erzeugt dann sofort ein neues Feld.
            Haptics.tap()
            finishEditingAndDeselect()
        } else if isTextToolActive {
            createTextBox(at: location)
        }
    }

    // MARK: - Erstellen / Löschen

    private func createTextBox(at location: CGPoint) {
        let size = safeAreaSize
        guard location.x.isFinite, location.y.isFinite else { return }

        Haptics.tap()

        let before = textBoxes
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
            fontSize: newTextFontSize,
            colorHex: newTextColorHex.isEmpty ? NoteTextBox.defaultColorHex : newTextColorHex
        )
        guard let box = rawBox.sanitized(in: size) else { return }

        // Das neue UIKit-Textfeld wird direkt nach dem State-Update
        // Erstbeantworter. Eine Layout-Animation um einen neu erzeugten
        // UITextView kann den Responder während `makeUIView` entfernen und
        // war dadurch eine weitere Quelle für Abstürze.
        textBoxes.append(box)
        registerUndo(before, textBoxes)

        // Kein DispatchQueue-Umweg mehr nötig: Ohne Element-Bindings ist es
        // sicher, Auswahl und Bearbeitung direkt zu setzen.
        selectedID = box.id
        editingID = box.id
    }

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
    /// Durchmesser der runden Schriftgrößen-Knöpfe (bewusst groß genug,
    /// um sie auch mit dem Finger sicher zu treffen).
    private let fontSizeButtonDiameter: CGFloat = 46

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
        // Auswahl-Rahmen und Steuerelemente je nach Modus.
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected || isEditing ? Color.blue.opacity(0.07) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(
                    (isSelected || isEditing) ? Color.blue.opacity(0.85) : Color.blue.opacity(0.28),
                    style: StrokeStyle(
                        lineWidth: (isSelected || isEditing) ? 1.5 : 1,
                        dash: (isSelected || isEditing) ? [] : [4, 3]
                    )
                )
        )
        .overlay(alignment: .leading) {
            // Seiten-Griff nur im Verschiebe-Modus (nicht beim Bearbeiten).
            if isSelected, !isEditing {
                resizeHandle(edge: .leading)
                    .offset(x: -13)
            }
        }
        .overlay(alignment: .trailing) {
            if isSelected, !isEditing {
                resizeHandle(edge: .trailing)
                    .offset(x: 13)
            }
        }
        .overlay(alignment: .topTrailing) {
            // Lösch-Kreuz nur im Verschiebe-Modus (nicht beim Bearbeiten).
            if isSelected, !isEditing {
                deleteButton
                    .offset(x: 14, y: -14)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            // Schriftgröße bleibt in beiden Modi verfügbar.
            if isSelected || isEditing {
                fontSizeControls
                    .offset(y: fontSizeButtonDiameter + 8)
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
            .frame(width: 24, height: 24)
            .overlay(
                Image(systemName: "arrow.left.and.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
            )
            .shadow(color: Color.black.opacity(0.25), radius: 3, x: 0, y: 1)
            .contentShape(Circle().inset(by: -12))
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
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 26, height: 26)
                .background(Circle().fill(Color.red))
                .shadow(color: Color.black.opacity(0.25), radius: 3, x: 0, y: 1)
        }
        .buttonStyle(.plain)
        .hoverEffect(.lift)
        .accessibilityLabel("Textfeld löschen")
    }

    /// Große, runde Liquid-Glass-Knöpfe zum Ändern der Schriftgröße.
    private var fontSizeControls: some View {
        HStack(spacing: 10) {
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
                .font(.system(size: 19, weight: .semibold))
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
                            lineWidth: 1
                        )
                )
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(0.2), radius: 6, x: 0, y: 3)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .hoverEffect(.lift)
        .accessibilityLabel(accessibilityLabel)
    }
}
