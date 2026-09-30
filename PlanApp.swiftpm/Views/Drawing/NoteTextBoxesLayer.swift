import SwiftUI
import UIKit

/// Geschätzte Höhe eines Textfelds inkl. Innenabstand – dieselbe Rechnung
/// wie beim Rendern der Notiz-Vorschau, damit Klemme und Vorschau übereinstimmen.
func estimatedTextBoxHeight(_ box: NoteTextBox) -> CGFloat {
    let innerWidth = max(20, CGFloat(box.width) - 16)
    let bounding = (box.text as NSString).boundingRect(
        with: CGSize(width: innerWidth, height: .greatestFiniteMagnitude),
        options: [.usesLineFragmentOrigin],
        attributes: [.font: UIFont.systemFont(ofSize: CGFloat(box.fontSize))],
        context: nil
    )
    return max(36, ceil(bounding.height) + 16)
}

/// Ebene über der PencilKit-Zeichenfläche, die frei bewegliche Textfelder
/// verwaltet.
///
/// Bedienung:
/// - Einmal tippen auf ein Feld: auswählen (verschiebbar, Breite ändern, löschen).
/// - Doppeltippen auf ein Feld: Text wirklich bearbeiten (Tastatur erscheint,
///   Lösch-Kreuz und Seiten-Griffe verschwinden).
/// - Tippen daneben: Bearbeiten verlassen (zurück in den Verschiebe-Modus),
///   dann Auswahl aufheben; danach erstellt ein Tipp ein neues Feld.
/// - Felder, die leer sind oder nur Leerzeichen enthalten, werden beim
///   Verlassen automatisch gelöscht.
struct NoteTextBoxesLayer: View {
    @Binding var textBoxes: [NoteTextBox]
    @Binding var selectedID: UUID?
    @Binding var editingID: UUID?
    let isTextToolActive: Bool
    let areaSize: CGSize
    /// Undo-Registrierung: (Snapshot vorher, Snapshot nachher).
    let registerUndo: (_ before: [NoteTextBox], _ after: [NoteTextBox]) -> Void

    @State private var gestureSnapshot: [NoteTextBox]? = nil
    @State private var editSessionSnapshot: [NoteTextBox]? = nil

    private let margin: CGFloat = 6

    var body: some View {
        ZStack(alignment: .topLeading) {
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

            ForEach($textBoxes) { $box in
                NoteTextBoxView(
                    box: $box,
                    isSelected: selectedID == box.id,
                    isEditing: editingID == box.id,
                    areaSize: areaSize,
                    onSelect: {
                        if selectedID != box.id {
                            Haptics.select()
                            selectedID = box.id
                        }
                    },
                    onBeginEditing: {
                        Haptics.select()
                        selectedID = box.id
                        editingID = box.id
                    },
                    onEndEditing: {
                        if editingID == box.id {
                            editingID = nil
                        }
                    },
                    onDelete: { deleteBox(box) },
                    onGestureStart: {
                        gestureSnapshot = textBoxes
                    },
                    onGestureEnd: {
                        finishGesture()
                    },
                    onRegisterMutation: { oldBox, newBox in
                        registerBoxMutation(from: oldBox, to: newBox)
                    }
                )
            }
        }
        .frame(width: areaSize.width, height: areaSize.height, alignment: .topLeading)
        .coordinateSpace(name: "noteTextBoxesLayer")
        .clipped()
        .onChange(of: selectedID) { oldValue, newValue in
            // Wechsel der Auswahl beendet eine laufende Bearbeitung
            // (Undo-Eintrag passiert im onChange von editingID).
            if let oldValue, editingID == oldValue, newValue != oldValue {
                editingID = nil
            }
            cleanupEmptyBoxes(keeping: newValue ?? editingID)
        }
        .onChange(of: editingID) { oldValue, newValue in
            if let newValue, oldValue != newValue {
                editSessionSnapshot = textBoxes
            } else if oldValue != nil, newValue == nil {
                let before = editSessionSnapshot
                editSessionSnapshot = nil
                cleanupEmptyBoxes(keeping: selectedID)
                if let before {
                    registerUndo(before, textBoxes)
                }
            }
        }
    }

    // MARK: - Tipp auf leere Fläche

    private func handleBackgroundTap(at location: CGPoint) {
        if editingID != nil {
            // 1. Schritt: Bearbeiten verlassen → zurück in den Verschiebe-Modus.
            Haptics.tap()
            editingID = nil
        } else if selectedID != nil {
            // 2. Schritt: Auswahl aufheben.
            Haptics.tap()
            selectedID = nil
        } else if isTextToolActive {
            // 3. Schritt: Neues Textfeld erstellen (direkt bearbeitbar).
            createTextBox(at: location)
        }
    }

    // MARK: - Erstellen / Löschen

    private func createTextBox(at location: CGPoint) {
        Haptics.tap()

        let before = textBoxes
        let defaultWidth: CGFloat = 240
        let minWidth: CGFloat = 120

        // Nie über den rechten Rand hinaus: Das Feld wird notfalls schmaler
        // oder rutscht nach links, der Text bricht dann automatisch um.
        var x = max(margin, location.x)
        var width = defaultWidth
        let maxAvailable = areaSize.width - margin - x
        if width > maxAvailable {
            width = max(minWidth, maxAvailable)
            if maxAvailable < minWidth {
                width = minWidth
                x = max(margin, areaSize.width - margin - width)
            }
        }
        let y = min(max(margin, location.y - 20), max(margin, areaSize.height - 60))

        let box = NoteTextBox(x: Double(x), y: Double(y), width: Double(width))
        withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
            textBoxes.append(box)
        }
        registerUndo(before, textBoxes)

        // Neues Feld direkt auswählen und zum Bearbeiten öffnen. Das Fokussieren
        // läuft bewusst im nächsten Main-Loop, nachdem SwiftUI die neue
        // ForEach-Zeile materialisiert hat; so wird beim Text-Werkzeug kein
        // Binding-Element mitten im Update fokussiert/ersetzt.
        DispatchQueue.main.async {
            guard textBoxes.contains(where: { $0.id == box.id }) else { return }
            selectedID = box.id
            editingID = box.id
        }
    }

    private func deleteBox(_ box: NoteTextBox) {
        Haptics.tap()
        let before = textBoxes
        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
            textBoxes.removeAll { $0.id == box.id }
        }
        registerUndo(before, textBoxes)
        if selectedID == box.id { selectedID = nil }
        if editingID == box.id { editingID = nil }
    }

    // MARK: - Undo-Registrierung

    /// Wird nach einer Zieh-Geste (Verschieben oder Breite ändern) aufgerufen.
    private func finishGesture() {
        guard let before = gestureSnapshot else { return }
        gestureSnapshot = nil
        registerUndo(before, textBoxes)
    }

    /// Registriert eine Punkt-Änderung an einem Feld (Schriftgröße).
    /// `oldBox`/`newBox` beschreiben das Feld vor bzw. nach der Mutation.
    private func registerBoxMutation(from oldBox: NoteTextBox, to newBox: NoteTextBox) {
        guard oldBox != newBox else { return }
        let before = textBoxes.map { $0.id == oldBox.id ? oldBox : $0 }
        registerUndo(before, textBoxes)

        // Durch größere Schrift könnte das Feld unten herausragen → einklemmen.
        if let index = textBoxes.firstIndex(where: { $0.id == newBox.id }) {
            var clamped = textBoxes[index]
            clampBoxIntoArea(&clamped)
            if clamped != textBoxes[index] {
                textBoxes[index] = clamped
            }
        }
    }

    // MARK: - Aufräumen & Klemmen

    /// Entfernt Felder, die leer sind oder nur Leerzeichen enthalten.
    private func cleanupEmptyBoxes(keeping keepID: UUID?) {
        let removableIDs = Set(textBoxes.compactMap { box -> UUID? in
            guard box.id != keepID,
                  box.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return nil
            }
            return box.id
        })
        guard !removableIDs.isEmpty else { return }

        // Auf den nächsten Main-Loop schieben: So wird kein Binding-Element
        // mitten in SwiftUIs ForEach-Update entfernt (das konnte beim Text-Tool
        // zu instabilen Zuständen führen).
        let textBoxesBinding = $textBoxes
        let selectedBinding = $selectedID
        let editingBinding = $editingID
        DispatchQueue.main.async {
            var updatedBoxes = textBoxesBinding.wrappedValue
            updatedBoxes.removeAll { removableIDs.contains($0.id) }
            textBoxesBinding.wrappedValue = updatedBoxes

            if let selectedID = selectedBinding.wrappedValue, removableIDs.contains(selectedID) {
                selectedBinding.wrappedValue = nil
            }
            if let editingID = editingBinding.wrappedValue, removableIDs.contains(editingID) {
                editingBinding.wrappedValue = nil
            }
        }
    }

    /// Klemmt ein Feld vollständig in die Zeichenfläche ein.
    fileprivate func clampBoxIntoArea(_ box: inout NoteTextBox) {
        let height = estimatedTextBoxHeight(box)
        let maxX = max(Double(margin), Double(areaSize.width) - box.width - Double(margin))
        let maxY = max(Double(margin), Double(areaSize.height - height) - Double(margin))
        box.x = min(max(Double(margin), box.x), maxX)
        box.y = min(max(Double(margin), box.y), maxY)
    }
}

/// Einzelnes Textfeld: im Verschiebe-Modus (ausgewählt) mit Rahmen,
/// Lösch-Kreuz, Seiten-Griffen und Schriftgrößen-Steuerung; im
/// Bearbeiten-Modus mit echtem Texteingabefeld (Tastatur), ohne Kreuz
/// und ohne Seiten-Griffe.
private struct NoteTextBoxView: View {
    @Binding var box: NoteTextBox
    let isSelected: Bool
    let isEditing: Bool
    let areaSize: CGSize
    let onSelect: () -> Void
    let onBeginEditing: () -> Void
    let onEndEditing: () -> Void
    let onDelete: () -> Void
    let onGestureStart: () -> Void
    let onGestureEnd: () -> Void
    let onRegisterMutation: (_ before: NoteTextBox, _ after: NoteTextBox) -> Void

    @State private var moveStart: CGPoint? = nil
    @State private var resizeStartX: CGFloat? = nil
    @State private var resizeStartWidth: CGFloat? = nil

    private let minWidth: CGFloat = 90
    private let margin: CGFloat = 6

    private enum ResizeEdge {
        case leading
        case trailing
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
                    .offset(y: 34)
            }
        }
        .offset(x: CGFloat(box.x), y: CGFloat(box.y))
    }

    // MARK: - Inhalte

    /// Anzeige-Modus: reiner Text (kein TextField!), damit Verschieben mit
    /// Finger oder Apple Pencil sofort greift und nichts erst beim Loslassen
    /// "springt".
    private var displayContent: some View {
        Text(box.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Text" : box.text)
            .font(.system(size: CGFloat(box.fontSize)))
            .foregroundColor(
                box.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? .secondary
                    : .primary
            )
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(width: max(20, CGFloat(box.width) - 16), alignment: .topLeading)
            .padding(8)
            .frame(width: CGFloat(box.width), alignment: .topLeading)
            .contentShape(Rectangle())
            .gesture(moveGesture)
            // Doppeltippen (egal ob ausgewählt oder nicht) = Text bearbeiten.
            .onTapGesture(count: 2) {
                onBeginEditing()
            }
            // Einfaches Tippen = auswählen.
            .onTapGesture(count: 1) {
                onSelect()
            }
    }

    /// Bearbeiten-Modus: natives UITextView mit garantierter Tastatur
    /// (und weiterhin Scribble-Unterstützung für den Apple Pencil).
    private var editingContent: some View {
        NoteTextEditor(
            text: $box.text,
            fontSize: CGFloat(box.fontSize),
            isEditing: isEditing,
            onEndEditing: onEndEditing
        )
        .frame(
            width: CGFloat(box.width),
            height: estimatedTextBoxHeight(box),
            alignment: .topLeading
        )
    }

    // MARK: - Verschieben (sofort, folgt dem Finger)

    private var moveGesture: some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .named("noteTextBoxesLayer"))
            .onChanged { value in
                if moveStart == nil {
                    moveStart = CGPoint(x: CGFloat(box.x), y: CGFloat(box.y))
                    onGestureStart()
                    if !isSelected {
                        onSelect()
                    }
                    Haptics.tap()
                }
                guard let start = moveStart else { return }
                let boxHeight = estimatedTextBoxHeight(box)
                let maxX = max(margin, areaSize.width - CGFloat(box.width) - margin)
                let maxY = max(margin, areaSize.height - boxHeight - margin)
                box.x = Double(min(max(margin, start.x + value.translation.width), maxX))
                box.y = Double(min(max(margin, start.y + value.translation.height), maxY))
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
        DragGesture(minimumDistance: 1, coordinateSpace: .named("noteTextBoxesLayer"))
            .onChanged { value in
                if resizeStartX == nil {
                    resizeStartX = CGFloat(box.x)
                    resizeStartWidth = CGFloat(box.width)
                    onGestureStart()
                }
                guard let startX = resizeStartX, let startWidth = resizeStartWidth else { return }

                switch edge {
                case .trailing:
                    let maxWidth = areaSize.width - margin - startX
                    box.width = Double(min(max(minWidth, startWidth + value.translation.width), maxWidth))
                case .leading:
                    let proposedX = startX + value.translation.width
                    let maxX = startX + startWidth - minWidth
                    let newX = min(max(margin, proposedX), maxX)
                    box.width = Double(startWidth + (startX - newX))
                    box.x = Double(newX)
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

    private var fontSizeControls: some View {
        HStack(spacing: 0) {
            Button {
                Haptics.select()
                let before = box
                box.fontSize = max(10, box.fontSize - 2)
                onRegisterMutation(before, box)
            } label: {
                Image(systemName: "textformat.size.smaller")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 34, height: 30)
            }
            .buttonStyle(.plain)

            Divider()
                .frame(height: 18)

            Button {
                Haptics.select()
                let before = box
                box.fontSize = min(48, box.fontSize + 2)
                onRegisterMutation(before, box)
            } label: {
                Image(systemName: "textformat.size.larger")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 34, height: 30)
            }
            .buttonStyle(.plain)
        }
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.15), radius: 3, x: 0, y: 1)
        .accessibilityLabel("Schriftgröße ändern")
    }
}
