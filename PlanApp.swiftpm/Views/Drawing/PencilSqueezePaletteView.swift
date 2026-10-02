import SwiftUI
import UIKit

/// Werkzeug-Palette im **Viertelkreis**, die beim Squeeze des Apple Pencil Pro
/// erscheint.
///
/// Sie liegt um die letzte Hover-Position des Stifts herum und öffnet sich in
/// die Richtung, in die der Stift zeigt (Azimut des Pencil). In ihr ist alles
/// einstellbar:
/// - **Werkzeug** (Stift, Textmarker, Radierer, Lasso, Text)
/// - **Farbe** (die Farb-Slots des aktiven Werkzeugs)
/// - **Dicke** (Regler entlang des äußeren Bogens)
/// - **Rückgängig / Wiederholen** und Schließen
///
/// Die Palette ist bewusst eine reine Anzeige: Sie bekommt Anker und Richtung
/// von außen und meldet Änderungen über Bindings/Callbacks zurück.
struct PencilSqueezePaletteView: View {
    /// Ankerpunkt der letzten Hover-Position in **Fenster-Koordinaten**.
    let anchor: CGPoint
    /// Richtung, in die der Stift zeigt (Fenster-Koordinaten, y nach unten).
    let direction: CGVector
    /// Größe und globale Position des Overlays, in dem die Palette liegt.
    let containerSize: CGSize
    let containerOrigin: CGPoint

    @Binding var toolSelection: DrawingToolSelection
    @Binding var penWidth: CGFloat
    @Binding var markerWidth: CGFloat
    @Binding var eraserWidth: CGFloat
    @Binding var penColorSlots: [String]
    @Binding var markerColorSlots: [String]

    let onUndo: () -> Void
    let onRedo: () -> Void
    let onClose: () -> Void

    // MARK: Geometrie (unskalierte Punkte)

    /// Größter Radius inklusive Beschriftung – bestimmt die Skalierung.
    private let maximumRadius: CGFloat = 292
    private let wedgeRadius: CGFloat = 262
    private let wedgeHalfAngle: CGFloat = 45 * .pi / 180
    private let toolRingRadius: CGFloat = 112
    private let colorRingRadius: CGFloat = 162
    private let sliderTrackRadius: CGFloat = 227
    private let sliderTrackWidth: CGFloat = 26
    private let sliderHalfAngle: CGFloat = 36 * .pi / 180

    private let itemSize: CGFloat = 38
    private let smallItemSize: CGFloat = 34

    @State private var isAdjustingWidth = false

    // MARK: Abgeleitete Werte

    /// Position des Ankers in der lokalen Fläche des Overlays.
    private var localAnchor: CGPoint {
        CGPoint(x: anchor.x - containerOrigin.x, y: anchor.y - containerOrigin.y)
    }

    /// Skalierung: Auf kleinen Flächen (Split View) wird die Palette kleiner,
    /// damit der Viertelkreis immer vollständig sichtbar bleibt.
    private var paletteScale: CGFloat {
        let available = min(containerSize.width, containerSize.height) / 2 - 16
        guard available > 0 else { return 0.6 }
        return min(1, max(0.55, available / maximumRadius))
    }

    /// Anker, so verschoben, dass der komplette Viertelkreis auf dem Bildschirm
    /// liegt.
    private var clampedAnchor: CGPoint {
        let radius = maximumRadius * paletteScale + 6
        let minX = min(radius, containerSize.width / 2)
        let minY = min(radius, containerSize.height / 2)
        let x = min(max(localAnchor.x, minX), max(minX, containerSize.width - minX))
        let y = min(max(localAnchor.y, minY), max(minY, containerSize.height - minY))
        return CGPoint(x: x, y: y)
    }

    /// Blickrichtung des Stifts in Radiant (0 = +X, im Uhrzeigersinn).
    private var directionAngle: CGFloat {
        guard direction.dx != 0 || direction.dy != 0 else { return -.pi / 2 }
        return atan2(direction.dy, direction.dx)
    }

    private var scaleAnchor: UnitPoint {
        UnitPoint(
            x: containerSize.width > 0 ? clampedAnchor.x / containerSize.width : 0.5,
            y: containerSize.height > 0 ? clampedAnchor.y / containerSize.height : 0.5
        )
    }

    private func point(radius: CGFloat, angle: CGFloat) -> CGPoint {
        CGPoint(
            x: clampedAnchor.x + radius * cos(angle),
            y: clampedAnchor.y + radius * sin(angle)
        )
    }

    // MARK: Inhalt

    var body: some View {
        ZStack {
            wedgeBackground
            toolItems
            colorItems
            widthSlider
            // Die Wert-Anzeige liegt unter dem Hub und nimmt keine Tipps an –
            // so bleibt der Schließen-Knopf immer erreichbar.
            valuePill
            hubControls
        }
        .frame(width: containerSize.width, height: containerSize.height)
        .scaleEffect(paletteScale, anchor: scaleAnchor)
        .simultaneousGesture(widthDragGesture)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Apple Pencil Werkzeugpalette")
    }

    // MARK: Hintergrund

    private var wedgeBackground: some View {
        let shape = SqueezeWedgeShape(
            center: clampedAnchor,
            radius: wedgeRadius,
            startAngle: directionAngle - wedgeHalfAngle,
            endAngle: directionAngle + wedgeHalfAngle
        )

        return ZStack {
            shape
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.22), radius: 18, x: 0, y: 8)

            shape
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.55), Color.white.opacity(0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )

            // Kleiner Punkt am Anker: markiert die Hover-Position des Stifts.
            Circle()
                .fill(Color.primary.opacity(0.35))
                .frame(width: 6, height: 6)
                .position(clampedAnchor)
        }
    }

    // MARK: Werkzeuge (innerer Ring)

    private var toolItems: some View {
        ForEach(Array(PaletteTool.allCases.enumerated()), id: \.element.id) { index, tool in
            let angle = directionAngle - 40 * .pi / 180 + CGFloat(index) * 20 * .pi / 180
            let isSelected = activeTool == tool

            Button {
                Haptics.select()
                select(tool)
            } label: {
                Image(systemName: tool.icon)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(isSelected ? .white : .primary)
                    .frame(width: itemSize, height: itemSize)
                    .background(
                        Circle().fill(isSelected ? Color.blue : Color(UIColor.tertiarySystemBackground))
                    )
                    .overlay(
                        Circle().strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.18), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)
            .hoverEffect(.lift)
            .position(point(radius: toolRingRadius, angle: angle))
            .accessibilityLabel(tool.title)
            .accessibilityValue(isSelected ? "Ausgewählt" : "")
        }
    }

    // MARK: Farben (mittlerer Ring)

    private var colorItems: some View {
        let slots = colorSlotsForActiveTool
        let count = max(1, slots.count)
        let span: CGFloat = 80 * .pi / 180
        let selectedHex = activeInkingColorHex

        return ForEach(Array(slots.enumerated()), id: \.offset) { index, hex in
            let angle: CGFloat
            if count == 1 {
                angle = directionAngle
            } else {
                angle = directionAngle - span / 2 + span * CGFloat(index) / CGFloat(count - 1)
            }
            let isSelected = selectedHex?.caseInsensitiveCompare(hex) == .orderedSame
            let swatch = Color(hex: hex)

            Button {
                Haptics.select()
                applyColor(hex)
            } label: {
                ZStack {
                    Circle()
                        .fill(swatch)
                        .frame(width: smallItemSize, height: smallItemSize)

                    Circle()
                        .strokeBorder(
                            hex.caseInsensitiveCompare("#FFFFFF") == .orderedSame
                                ? Color.gray.opacity(0.5)
                                : Color.white.opacity(0.55),
                            lineWidth: 1
                        )
                        .frame(width: smallItemSize, height: smallItemSize)

                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(swatch.contrastingTextColor)
                            .shadow(
                                color: swatch.contrastingTextColor == .white
                                    ? Color.black.opacity(0.5)
                                    : Color.clear,
                                radius: 1
                            )
                    }
                }
                .frame(width: smallItemSize + 8, height: smallItemSize + 8)
                .overlay(
                    Circle()
                        .strokeBorder(Color.blue, lineWidth: isSelected ? 2.5 : 0)
                        .frame(width: smallItemSize + 7, height: smallItemSize + 7)
                )
                .shadow(color: Color.black.opacity(0.18), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)
            .hoverEffect(.lift)
            .position(point(radius: colorRingRadius, angle: angle))
            .accessibilityLabel("Farbe \(hex)")
            .accessibilityValue(isSelected ? "Ausgewählt" : "")
        }
    }

    // MARK: Dicke (äußerer Bogen-Regler)

    private var widthSlider: some View {
        let progress = widthProgress
        let startAngle = directionAngle - sliderHalfAngle
        let endAngle = directionAngle + sliderHalfAngle
        let knobAngle = startAngle + (endAngle - startAngle) * progress

        return ZStack {
            SqueezeArcShape(
                center: clampedAnchor,
                radius: sliderTrackRadius,
                startAngle: startAngle,
                endAngle: endAngle
            )
            .stroke(
                Color.primary.opacity(0.14),
                style: StrokeStyle(lineWidth: sliderTrackWidth, lineCap: .round)
            )

            // Gefüllter Teil bis zum aktuellen Wert.
            SqueezeArcShape(
                center: clampedAnchor,
                radius: sliderTrackRadius,
                startAngle: startAngle,
                endAngle: max(startAngle, knobAngle)
            )
            .stroke(
                currentToolPreviewColor,
                style: StrokeStyle(lineWidth: sliderTrackWidth, lineCap: .round)
            )
            .opacity(0.55)

            Circle()
                .fill(currentToolPreviewColor)
                .frame(width: 26, height: 26)
                .overlay(Circle().strokeBorder(Color.white, lineWidth: 2))
                .shadow(color: Color.black.opacity(0.25), radius: 4, x: 0, y: 2)
                .position(point(radius: sliderTrackRadius, angle: knobAngle))
        }
    }

    // MARK: Mittelpunkt (Fertig, Rückgängig, Wiederholen)

    private var hubControls: some View {
        ZStack {
            hubButton(icon: "xmark", label: "Palette schließen", action: onClose)
                .position(point(radius: 76, angle: directionAngle + .pi))

            hubButton(icon: "arrow.uturn.backward", label: "Rückgängig", action: onUndo)
                .position(point(radius: 66, angle: directionAngle - 44 * .pi / 180))

            hubButton(icon: "arrow.uturn.forward", label: "Wiederholen", action: onRedo)
                .position(point(radius: 66, angle: directionAngle + 44 * .pi / 180))
        }
    }

    private func hubButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)
                .frame(width: 32, height: 32)
                .background(Circle().fill(.ultraThinMaterial))
                .overlay(Circle().strokeBorder(Color.white.opacity(0.35), lineWidth: 1))
                .shadow(color: Color.black.opacity(0.18), radius: 3, x: 0, y: 1.5)
        }
        .buttonStyle(.plain)
        .hoverEffect(.lift)
        .accessibilityLabel(label)
    }

    /// Anzeige von Werkzeug und aktueller Dicke – bewusst kompakt, damit sie
    /// am Anker weder den Schließen-Knopf noch die Werkzeuge überdeckt.
    private var valuePill: some View {
        HStack(spacing: 5) {
            Image(systemName: activePaletteTool.icon)
                .font(.system(size: 12, weight: .semibold))
            Text("\(formattedWidth) pt")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
        .foregroundColor(.primary)
        .allowsHitTesting(false)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            Capsule().fill(.ultraThinMaterial)
        )
        .overlay(
            Capsule().strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.16), radius: 4, x: 0, y: 2)
        .fixedSize()
        // Bewusst direkt am Anker: Dort kollidiert die Beschriftung nicht mit
        // dem mittleren Werkzeug-Symbol – egal, in welche Richtung der Stift
        // zeigt.
        .position(clampedAnchor)
    }

    // MARK: Regler-Geste

    private var widthDragGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                let dx = value.location.x - clampedAnchor.x
                let dy = value.location.y - clampedAnchor.y
                let radius = sqrt(dx * dx + dy * dy)

                if !isAdjustingWidth {
                    // Der Zug muss im äußeren Ring beginnen – Tipps auf
                    // Werkzeuge/Farben bleiben dadurch unberührt. Alle Werte
                    // sind unskalierte Punkte: `scaleEffect` ändert die
                    // lokalen Koordinaten nicht.
                    let lower = sliderTrackRadius - sliderTrackWidth * 1.6
                    let upper = sliderTrackRadius + sliderTrackWidth * 1.6
                    guard radius >= lower, radius <= upper else { return }
                    isAdjustingWidth = true
                }

                var delta = atan2(dy, dx) - directionAngle
                while delta > .pi { delta -= 2 * .pi }
                while delta < -.pi { delta += 2 * .pi }
                let clamped = min(max(delta, -sliderHalfAngle), sliderHalfAngle)
                let progress = (clamped + sliderHalfAngle) / (2 * sliderHalfAngle)
                setWidth(progress: progress)
            }
            .onEnded { _ in
                isAdjustingWidth = false
            }
    }

    // MARK: Werkzeug-Zustand

    private var activeTool: PaletteTool {
        switch toolSelection {
        case .pen: return .pen
        case .marker: return .marker
        case .eraser: return .eraser
        case .lasso: return .lasso
        case .text: return .text
        }
    }

    private var activePaletteTool: PaletteTool { activeTool }

    private func select(_ tool: PaletteTool) {
        switch tool {
        case .pen:
            toolSelection = .pen(color: UIColor(hex: fallbackPenHex))
        case .marker:
            toolSelection = .marker(color: UIColor(hex: fallbackMarkerHex).withAlphaComponent(0.60))
        case .eraser:
            toolSelection = .eraser
        case .lasso:
            toolSelection = .lasso
        case .text:
            toolSelection = .text
        }
    }

    private var fallbackPenHex: String {
        if case .pen(let color) = toolSelection { return color.toHex() }
        return penColorSlots.first ?? "#1E1E1E"
    }

    private var fallbackMarkerHex: String {
        if case .marker(let color) = toolSelection { return color.toHex() }
        return markerColorSlots.first ?? "#FFE633"
    }

    /// Farb-Slots des aktiven Werkzeugs (Textmarker → Marker-Farben, sonst
    /// Stift-Farben).
    private var colorSlotsForActiveTool: [String] {
        if case .marker = toolSelection { return markerColorSlots }
        return penColorSlots
    }

    private var activeInkingColorHex: String? {
        switch toolSelection {
        case .pen(let color), .marker(let color):
            return color.toHex()
        default:
            return nil
        }
    }

    private func applyColor(_ hex: String) {
        let color = UIColor(hex: hex)
        if case .marker = toolSelection {
            toolSelection = .marker(color: color.withAlphaComponent(0.60))
        } else {
            toolSelection = .pen(color: color)
        }
    }

    // MARK: Dicke

    private var widthBinding: Binding<CGFloat> {
        switch toolSelection {
        case .pen, .text, .lasso:
            return $penWidth
        case .marker:
            return $markerWidth
        case .eraser:
            return $eraserWidth
        }
    }

    private var widthRange: ClosedRange<CGFloat> {
        switch toolSelection {
        case .pen, .text, .lasso:
            return 1...20
        case .marker:
            return 4...40
        case .eraser:
            return 4...60
        }
    }

    private var widthProgress: CGFloat {
        let range = widthRange
        let value = min(max(widthBinding.wrappedValue, range.lowerBound), range.upperBound)
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0 }
        return (value - range.lowerBound) / span
    }

    private var formattedWidth: String {
        String(format: "%.1f", widthBinding.wrappedValue)
    }

    private func setWidth(progress: CGFloat) {
        let range = widthRange
        let clamped = min(max(progress, 0), 1)
        let value = range.lowerBound + clamped * (range.upperBound - range.lowerBound)
        widthBinding.wrappedValue = (value * 2).rounded() / 2
    }

    /// Vorschau-Farbe der Dicke: die Farbe des aktiven Werkzeugs.
    private var currentToolPreviewColor: Color {
        switch toolSelection {
        case .pen(let color):
            return Color(uiColor: color)
        case .marker(let color):
            return Color(uiColor: color.withAlphaComponent(1))
        case .eraser:
            return Color(UIColor.systemGray2)
        case .text, .lasso:
            return .primary
        }
    }
}

// MARK: - Werkzeugliste

/// Die Werkzeuge der Palette in fester Reihenfolge (innerer Ring).
enum PaletteTool: Int, CaseIterable, Identifiable {
    case pen
    case marker
    case eraser
    case lasso
    case text

    var id: Int { rawValue }

    var icon: String {
        switch self {
        case .pen: return "pencil.tip"
        case .marker: return "highlighter"
        case .eraser: return "eraser"
        case .lasso: return "lasso"
        case .text: return "textformat"
        }
    }

    var title: String {
        switch self {
        case .pen: return "Stift"
        case .marker: return "Textmarker"
        case .eraser: return "Radierer"
        case .lasso: return "Lasso"
        case .text: return "Text"
        }
    }
}

// MARK: - Formen

/// Viertelkreis-Segment (Tortenstück) zwischen zwei Winkeln.
struct SqueezeWedgeShape: Shape {
    let center: CGPoint
    let radius: CGFloat
    let startAngle: CGFloat
    let endAngle: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: center)

        let steps = 40
        for step in 0...steps {
            let fraction = CGFloat(step) / CGFloat(steps)
            let angle = startAngle + (endAngle - startAngle) * fraction
            path.addLine(to: CGPoint(
                x: center.x + radius * cos(angle),
                y: center.y + radius * sin(angle)
            ))
        }

        path.closeSubpath()
        return path
    }
}

/// Offener Bogen – Basis für den Dicke-Regler.
struct SqueezeArcShape: Shape {
    let center: CGPoint
    let radius: CGFloat
    let startAngle: CGFloat
    let endAngle: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let steps = 32
        for step in 0...steps {
            let fraction = CGFloat(step) / CGFloat(steps)
            let angle = startAngle + (endAngle - startAngle) * fraction
            let point = CGPoint(
                x: center.x + radius * cos(angle),
                y: center.y + radius * sin(angle)
            )
            if step == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        return path
    }
}
