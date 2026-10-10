import SwiftUI
import UIKit

/// Ebene über der Zeichenfläche für frei bewegliche, skalierbare Bilder.
///
/// Bedienung (Auswahl-Regeln siehe `LayerInputPolicy`):
/// - Tippen auf ein Bild: auswählen (verschiebbar, skalierbar, löschbar).
///   Finger tippt Elemente immer an, wenn „Nur Apple Pencil“ an ist – sonst
///   nur im Text-Werkzeug. Der Apple Pencil tippt nur im Text-Werkzeug an.
/// - Tippen auf das **ausgewählte** Bild hebt im Zeichen-Modus die Auswahl
///   wieder auf (danach ist die Stelle wieder frei für Striche).
/// - Ziehen an den vier Eckpunkten: seitenrichtig skalieren.
/// - Ziehen in der Mitte: verschieben.
/// - Roter Knopf: löschen. Blauer Knopf: zuschneiden (eigene Übersicht).
/// - Tippen daneben (Text-Werkzeug/Finger-Modus): Auswahl aufheben (die
///   Ebene darunter, `LessonDrawingOverlayView.layerBackdrop`).
///
/// Wie die Text-Ebene arbeitet auch diese Ebene bewusst **ohne**
/// `ForEach($images)`-Element-Bindings: Werte gehen nach unten, Änderungen
/// kommen über die stabile `id` zurück – so kann ein Bild gefahrlos entfernt
/// werden, während eine Geste noch aktiv ist.
struct NoteImagesLayer: View {
    @Binding var images: [NoteImageBox]
    @Binding var selectedID: UUID?
    /// Ob das Text-Werkzeug aktiv ist: Im Text-Modus tippt auch der Apple
    /// Pencil auf die Fläche (Auswahl aufheben); im Zeichen-Modus reicht die
    /// Fläche Pencil-Berührungen durch (Strich statt Deselect).
    let isTextToolActive: Bool
    /// Ob Elemente neu auswählt werden dürfen (Tap oder Zieh-Beginn):
    /// Text-Werkzeug oder Finger-Modus bei „Nur Apple Pencil“. Die Fläche des
    /// **bereits ausgewählten** Bildes bleibt davon unabhängig anfassbar.
    let canSelectElements: Bool
    let areaSize: CGSize
    /// Undo-Registrierung: (Snapshot vorher, Snapshot nachher).
    let registerUndo: (_ before: [NoteImageBox], _ after: [NoteImageBox]) -> Void
    /// Öffnet die Zuschneide-Übersicht für das Bild.
    let onCrop: (UUID) -> Void
    /// Wirksame Skalierung der Zeichenfläche. Rahmen und Bedienelemente werden
    /// gegen diese Skalierung korrigiert, damit sie auf dem Bildschirm immer
    /// gleich groß wirken.
    var canvasScale: CGFloat = 1

    static let coordinateSpaceName = "noteImagesLayer"

    @State private var gestureSnapshot: [NoteImageBox]? = nil

    private let margin: CGFloat = 6

    private var safeAreaSize: CGSize {
        CGSize(
            width: areaSize.width.isFinite && areaSize.width > 0 ? areaSize.width : 320,
            height: areaSize.height.isFinite && areaSize.height > 0 ? areaSize.height : 180
        )
    }

    /// Das ausgewählte Bild liegt **ganz oben**, damit seine Griffe und Knöpfe
    /// nie hinter anderen Bildern verschwinden (über `zIndex`, ohne Umsortieren).
    private func isFrontImage(_ id: UUID) -> Bool {
        id == selectedID
    }

    var body: some View {
        let size = safeAreaSize

        return ZStack(alignment: .topLeading) {
            ForEach(images, id: \.id) { box in
                NoteImageBoxView(
                    box: box,
                    isSelected: selectedID == box.id,
                    areaSize: size,
                    canvasScale: canvasScale,
                    onTap: { handleTapSelect(box.id) },
                    onEnsureSelected: { ensureSelected(box.id) },
                    onDelete: { deleteBox(id: box.id) },
                    onCrop: { onCrop(box.id) },
                    onGestureStart: {
                        if gestureSnapshot == nil {
                            gestureSnapshot = images
                        }
                    },
                    onMove: { newOrigin in
                        updateBox(id: box.id) {
                            $0.x = Double(newOrigin.x)
                            $0.y = Double(newOrigin.y)
                        }
                    },
                    onTransform: { newX, newY, newWidth, newHeight in
                        updateBox(id: box.id) {
                            $0.x = Double(newX)
                            $0.y = Double(newY)
                            $0.width = Double(newWidth)
                            $0.height = Double(newHeight)
                        }
                    },
                    onGestureEnd: { finishGesture(id: box.id) }
                )
                .zIndex(isFrontImage(box.id) ? 1 : 0)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .coordinateSpace(name: Self.coordinateSpaceName)
    }

    // MARK: - Auswahl & Löschen

    /// Tap auf ein Bild: auswählen – oder im Zeichen-Modus die Auswahl des
    /// **angewählten** Bilds aufheben (Toggle). So kommt man nach dem
    /// Einfügen/Anpassen mit einem weiteren Tipp zurück zum Zeichnen, auch
    /// mitten auf dem Bild.
    private func handleTapSelect(_ id: UUID) {
        if selectedID == id, !isTextToolActive {
            Haptics.select()
            DrawingDiagnostics.hit.debug("Bild-Auswahl per Tap aufgehoben")
            selectedID = nil
            return
        }
        ensureSelected(id)
    }

    /// Auswahl sicherstellen (Tap auf ein anderes Bild, Beginn einer Zieh-
    /// oder Skalier-Geste). Ziehen auf dem bereits ausgewählten Bild bleibt
    /// auch dann eine Verschiebung, wenn Neu-Auswählen nicht erlaubt ist.
    private func ensureSelected(_ id: UUID) {
        guard images.contains(where: { $0.id == id }) else { return }
        guard selectedID != id else { return }
        // Neue Auswahl nur, wenn der aktuelle Modus Elemente antippen darf
        // (Text-Werkzeug oder Finger-Modus bei „Nur Apple Pencil“). Die
        // Berührungsart filtert bereits die Eingabe-Hülle.
        guard canSelectElements else { return }
        Haptics.select()
        selectedID = id
    }

    private func deleteBox(id: UUID) {
        guard let index = images.firstIndex(where: { $0.id == id }) else { return }
        Haptics.tap()
        let before = images
        if selectedID == id { selectedID = nil }
        images.remove(at: index)
        gestureSnapshot = nil
        registerUndo(before, images)
    }

    // MARK: - Änderungen (immer über die stabile id)

    private func updateBox(id: UUID, _ transform: (inout NoteImageBox) -> Void) {
        guard let index = images.firstIndex(where: { $0.id == id }) else { return }
        var updated = images[index]
        transform(&updated)
        guard let sanitized = updated.sanitized(in: safeAreaSize) else { return }
        guard sanitized != images[index] else { return }
        images[index] = sanitized
    }

    /// Wird nach einer Zieh-Geste (Verschieben oder Skalieren) aufgerufen.
    private func finishGesture(id: UUID) {
        guard let before = gestureSnapshot else { return }
        gestureSnapshot = nil
        // Bearbeitungszeitpunkt für die Sync-Zusammenführung nachführen.
        if let index = images.firstIndex(where: { $0.id == id }) {
            images[index].updatedAt = Date()
        }
        guard before != images else { return }
        registerUndo(before, images)
    }
}

/// Einzelnes Bild: in der Mitte ziehen zum Verschieben, an den vier
/// Eckpunkten ziehen zum seitenrichtigen Skalieren. Ausgewählt kommen
/// Rahmen, Lösch-Knopf und Zuschneide-Knopf dazu.
private struct NoteImageBoxView: View {
    let box: NoteImageBox
    let isSelected: Bool
    let areaSize: CGSize
    let canvasScale: CGFloat
    /// Tap auf das Bild (Auswahl bzw. Auswahl aufheben im Zeichen-Modus).
    let onTap: () -> Void
    /// Auswahl sicherstellen, bevor eine Zieh-/Skalier-Geste greift.
    let onEnsureSelected: () -> Void
    let onDelete: () -> Void
    let onCrop: () -> Void
    let onGestureStart: () -> Void
    let onMove: (CGPoint) -> Void
    let onTransform: (_ newX: CGFloat, _ newY: CGFloat, _ newWidth: CGFloat, _ newHeight: CGFloat) -> Void
    let onGestureEnd: () -> Void

    @State private var moveStart: CGPoint? = nil
    @State private var scaleStartBox: NoteImageBox? = nil

    private let margin: CGFloat = 6
    private var inverseScale: CGFloat { 1 / max(0.01, canvasScale) }
    private var cornerDotDiameter: CGFloat { (DeviceLayout.isPhone ? 20 : 24) * inverseScale }
    private var actionButtonDiameter: CGFloat { (DeviceLayout.isPhone ? 22 : 26) * inverseScale }

    private enum Corner {
        case topLeading, topTrailing, bottomLeading, bottomTrailing
    }

    private var boxWidth: CGFloat {
        let value = CGFloat(box.width)
        return value.isFinite && value > 0 ? value : 240
    }

    private var boxHeight: CGFloat {
        let value = CGFloat(box.height)
        return value.isFinite && value > 0 ? value : 160
    }

    private var boxOrigin: CGPoint {
        CGPoint(
            x: CGFloat(box.x).isFinite ? CGFloat(box.x) : margin,
            y: CGFloat(box.y).isFinite ? CGFloat(box.y) : margin
        )
    }

    var body: some View {
        Group {
            if let uiImage = box.uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: boxWidth, height: boxHeight)
            } else {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(UIColor.tertiarySystemFill))
                    .frame(width: boxWidth, height: boxHeight)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.secondary)
                    )
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8 * inverseScale, style: .continuous)
                .fill(isSelected ? Color.blue.opacity(0.07) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8 * inverseScale, style: .continuous)
                .strokeBorder(
                    isSelected ? Color.blue.opacity(0.9) : Color.blue.opacity(0.28),
                    style: StrokeStyle(
                        lineWidth: (isSelected ? 1.5 : 1) * inverseScale,
                        dash: isSelected ? [] : [4 * inverseScale, 3 * inverseScale]
                    )
                )
        )
        .overlay(alignment: .topLeading) {
            if isSelected {
                cornerDot(.topLeading)
                    .offset(x: -cornerDotDiameter / 2, y: -cornerDotDiameter / 2)
            }
        }
        .overlay(alignment: .topTrailing) {
            if isSelected {
                cornerDot(.topTrailing)
                    .offset(x: cornerDotDiameter / 2, y: -cornerDotDiameter / 2)
            }
        }
        .overlay(alignment: .bottomLeading) {
            if isSelected {
                cornerDot(.bottomLeading)
                    .offset(x: -cornerDotDiameter / 2, y: cornerDotDiameter / 2)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if isSelected {
                cornerDot(.bottomTrailing)
                    .offset(x: cornerDotDiameter / 2, y: cornerDotDiameter / 2)
            }
        }
        .overlay(alignment: .topTrailing) {
            if isSelected {
                deleteButton
                    .offset(x: 14 * inverseScale, y: -34 * inverseScale)
            }
        }
        .overlay(alignment: .topLeading) {
            if isSelected {
                cropButton
                    .offset(x: -14 * inverseScale, y: -34 * inverseScale)
            }
        }
        .offset(x: boxOrigin.x, y: boxOrigin.y)
        .contentShape(Rectangle().inset(by: -12 * inverseScale))
        .gesture(moveGesture)
        .onTapGesture {
            onTap()
        }
    }

    // MARK: - Verschieben

    private var moveGesture: some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .named(NoteImagesLayer.coordinateSpaceName))
            .onChanged { value in
                if moveStart == nil {
                    moveStart = boxOrigin
                    onGestureStart()
                    onEnsureSelected()
                    Haptics.tap()
                }
                guard let start = moveStart else { return }
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

    // MARK: - Seitenrichtiges Skalieren an den Ecken

    private func cornerDot(_ corner: Corner) -> some View {
        Circle()
            .fill(Color.blue)
            .frame(width: cornerDotDiameter, height: cornerDotDiameter)
            .overlay(
                Circle().strokeBorder(Color.white.opacity(0.85), lineWidth: 2 * inverseScale)
            )
            .shadow(color: Color.black.opacity(0.25), radius: 3 * inverseScale, x: 0, y: 1 * inverseScale)
            .contentShape(Circle().inset(by: -14 * inverseScale))
            .gesture(scaleGesture(corner: corner))
    }

    private func scaleGesture(corner: Corner) -> some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .named(NoteImagesLayer.coordinateSpaceName))
            .onChanged { value in
                if scaleStartBox == nil {
                    scaleStartBox = box
                    onGestureStart()
                    onEnsureSelected()
                }
                guard let start = scaleStartBox else { return }
                let startOrigin = CGPoint(x: CGFloat(start.x), y: CGFloat(start.y))
                let startSize = CGSize(width: CGFloat(start.width), height: CGFloat(start.height))
                guard startSize.width > 0, startSize.height > 0 else { return }

                // Die gezogene Ecke bewegt sich, die gegenüberliegende bleibt fix.
                let anchor = oppositeCornerPoint(corner, origin: startOrigin, size: startSize)
                let handleStart = cornerPoint(corner, origin: startOrigin, size: startSize)
                let startDistance = hypot(handleStart.x - anchor.x, handleStart.y - anchor.y)
                guard startDistance > 20 else { return }

                let touch = value.location
                guard touch.x.isFinite, touch.y.isFinite else { return }
                let touchDistance = hypot(touch.x - anchor.x, touch.y - anchor.y)
                let factor = touchDistance / startDistance
                guard factor.isFinite, factor > 0 else { return }

                let aspect = max(0.1, min(10, box.aspectRatio))
                let maxWidth = max(NoteImageBox.minimumWidth, areaSize.width - margin * 2)
                let maxHeight = max(30, areaSize.height - margin * 2)
                var newWidth = min(max(CGFloat(NoteImageBox.minimumWidth), startSize.width * factor), maxWidth)
                var newHeight = newWidth / aspect
                if newHeight > maxHeight {
                    newHeight = maxHeight
                    newWidth = newHeight * aspect
                }
                let applied = newWidth / startSize.width
                // Uniform vom Anker aus: Der Rahmen wächst/schrumpft exakt
                // um den fixen Gegenpol.
                let newX = anchor.x + (startOrigin.x - anchor.x) * applied
                let newY = anchor.y + (startOrigin.y - anchor.y) * applied
                onTransform(newX, newY, newWidth, newHeight)
            }
            .onEnded { _ in
                let hadStarted = scaleStartBox != nil
                scaleStartBox = nil
                if hadStarted {
                    onGestureEnd()
                }
            }
    }

    private func cornerPoint(_ corner: Corner, origin: CGPoint, size: CGSize) -> CGPoint {
        switch corner {
        case .topLeading: return origin
        case .topTrailing: return CGPoint(x: origin.x + size.width, y: origin.y)
        case .bottomLeading: return CGPoint(x: origin.x, y: origin.y + size.height)
        case .bottomTrailing: return CGPoint(x: origin.x + size.width, y: origin.y + size.height)
        }
    }

    private func oppositeCornerPoint(_ corner: Corner, origin: CGPoint, size: CGSize) -> CGPoint {
        switch corner {
        case .topLeading: return cornerPoint(.bottomTrailing, origin: origin, size: size)
        case .topTrailing: return cornerPoint(.bottomLeading, origin: origin, size: size)
        case .bottomLeading: return cornerPoint(.topTrailing, origin: origin, size: size)
        case .bottomTrailing: return cornerPoint(.topLeading, origin: origin, size: size)
        }
    }

    // MARK: - Löschen & Zuschneiden

    private var deleteButton: some View {
        Button(action: onDelete) {
            Image(systemName: "xmark")
                .font(.system(size: 11 * inverseScale, weight: .bold))
                .foregroundColor(.white)
                .frame(width: actionButtonDiameter, height: actionButtonDiameter)
                .background(Circle().fill(Color.red))
                .shadow(color: Color.black.opacity(0.25), radius: 3 * inverseScale, x: 0, y: 1 * inverseScale)
        }
        .buttonStyle(.plain)
        .contentShape(Circle().inset(by: -10 * inverseScale))
        .hoverEffect(.lift)
        .accessibilityLabel("Bild entfernen")
    }

    private var cropButton: some View {
        Button(action: onCrop) {
            Image(systemName: "crop")
                .font(.system(size: 11 * inverseScale, weight: .bold))
                .foregroundColor(.white)
                .frame(width: actionButtonDiameter, height: actionButtonDiameter)
                .background(Circle().fill(Color.blue))
                .shadow(color: Color.black.opacity(0.25), radius: 3 * inverseScale, x: 0, y: 1 * inverseScale)
        }
        .buttonStyle(.plain)
        .contentShape(Circle().inset(by: -10 * inverseScale))
        .hoverEffect(.lift)
        .accessibilityLabel("Bild zuschneiden")
    }
}
