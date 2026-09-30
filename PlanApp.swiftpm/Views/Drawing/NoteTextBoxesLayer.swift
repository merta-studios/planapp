import SwiftUI

/// Layer über der PencilKit-Zeichenfläche, der frei bewegliche Textfelder
/// verwaltet. Mit aktivem Text-Werkzeug erstellt ein Tipp (Finger oder Apple
/// Pencil) ein neues Feld. Felder lassen sich per Finger verschieben, an den
/// Seiten breiter/schmaler ziehen, in der Schriftgröße ändern und löschen.
/// Text bricht am rechten Rand des Feldes automatisch in eine neue Zeile um.
struct NoteTextBoxesLayer: View {
    @Binding var textBoxes: [NoteTextBox]
    @Binding var selectedID: UUID?
    let isTextToolActive: Bool
    let areaSize: CGSize

    private let margin: CGFloat = 6

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Hintergrund fängt Tipp-Gesten ab: mit Text-Werkzeug wird ein
            // neues Feld erstellt, ansonsten wird nur die Auswahl aufgehoben.
            if isTextToolActive || selectedID != nil {
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        SpatialTapGesture(coordinateSpace: .named("noteTextBoxLayer"))
                            .onEnded { value in
                                if isTextToolActive {
                                    createTextBox(at: value.location)
                                } else {
                                    selectedID = nil
                                }
                            }
                    )
            }

            ForEach($textBoxes) { $box in
                NoteTextBoxView(
                    box: $box,
                    isSelected: selectedID == box.id,
                    areaSize: areaSize,
                    onSelect: {
                        if selectedID != box.id {
                            Haptics.select()
                            selectedID = box.id
                        }
                    },
                    onDelete: {
                        Haptics.tap()
                        let boxID = box.id
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                            textBoxes.removeAll { $0.id == boxID }
                        }
                        if selectedID == boxID {
                            selectedID = nil
                        }
                    }
                )
            }
        }
        .frame(width: areaSize.width, height: areaSize.height, alignment: .topLeading)
        .coordinateSpace(name: "noteTextBoxLayer")
        .clipped()
    }

    private func createTextBox(at location: CGPoint) {
        Haptics.tap()

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

        let box = NoteTextBox(x: x, y: y, width: width)
        withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
            textBoxes.append(box)
        }
        selectedID = box.id
    }
}

/// Einzelnes bewegliches Textfeld mit Auswahl-Rahmen, Verschiebe-Geste,
/// seitlichen Breiten-Griffen, Schriftgrößen-Steuerung und Löschen-Knopf.
private struct NoteTextBoxView: View {
    @Binding var box: NoteTextBox
    let isSelected: Bool
    let areaSize: CGSize
    let onSelect: () -> Void
    let onDelete: () -> Void

    @FocusState private var isFocused: Bool
    @State private var moveStart: CGPoint? = nil
    @State private var resizeStartX: CGFloat? = nil
    @State private var resizeStartWidth: CGFloat? = nil

    private let minWidth: CGFloat = 90
    private let margin: CGFloat = 4

    private enum ResizeEdge {
        case leading
        case trailing
    }

    var body: some View {
        TextField("Text", text: $box.text, axis: .vertical)
            .font(.system(size: box.fontSize))
            .foregroundColor(.primary)
            .textFieldStyle(.plain)
            .focused($isFocused)
            .padding(8)
            .frame(width: box.width, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.blue.opacity(0.07) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.blue.opacity(0.85) : Color.blue.opacity(0.28),
                        style: StrokeStyle(
                            lineWidth: isSelected ? 1.5 : 1,
                            dash: isSelected ? [] : [4, 3]
                        )
                    )
            )
            .overlay(alignment: .leading) {
                if isSelected {
                    resizeHandle(edge: .leading)
                        .offset(x: -13)
                }
            }
            .overlay(alignment: .trailing) {
                if isSelected {
                    resizeHandle(edge: .trailing)
                        .offset(x: 13)
                }
            }
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    deleteButton
                        .offset(x: 14, y: -14)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if isSelected {
                    fontSizeControls
                        .offset(y: 34)
                }
            }
            .simultaneousGesture(
                TapGesture().onEnded {
                    onSelect()
                }
            )
            .gesture(moveGesture, including: isFocused ? .subviews : .all)
            .offset(x: box.x, y: box.y)
            .onChange(of: isSelected) { _, nowSelected in
                if !nowSelected {
                    isFocused = false
                }
            }
    }

    // MARK: - Verschieben

    private var moveGesture: some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .named("noteTextBoxLayer"))
            .onChanged { value in
                if moveStart == nil {
                    moveStart = CGPoint(x: box.x, y: box.y)
                    onSelect()
                    Haptics.tap()
                }
                guard let start = moveStart else { return }
                let maxX = max(margin, areaSize.width - box.width - margin)
                let maxY = max(margin, areaSize.height - 44)
                box.x = min(max(margin, start.x + value.translation.width), maxX)
                box.y = min(max(margin, start.y + value.translation.height), maxY)
            }
            .onEnded { _ in
                moveStart = nil
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
        DragGesture(minimumDistance: 1, coordinateSpace: .named("noteTextBoxLayer"))
            .onChanged { value in
                if resizeStartX == nil {
                    resizeStartX = box.x
                    resizeStartWidth = box.width
                }
                guard let startX = resizeStartX, let startWidth = resizeStartWidth else { return }

                switch edge {
                case .trailing:
                    let maxWidth = areaSize.width - margin - startX
                    box.width = min(max(minWidth, startWidth + value.translation.width), maxWidth)
                case .leading:
                    let proposedX = startX + value.translation.width
                    let maxX = startX + startWidth - minWidth
                    let newX = min(max(margin, proposedX), maxX)
                    box.width = startWidth + (startX - newX)
                    box.x = newX
                }
            }
            .onEnded { _ in
                resizeStartX = nil
                resizeStartWidth = nil
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
                box.fontSize = max(10, box.fontSize - 2)
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
                box.fontSize = min(48, box.fontSize + 2)
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
