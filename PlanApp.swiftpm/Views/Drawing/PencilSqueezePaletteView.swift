import SwiftUI
import UIKit

/// Abgerundete, viertelkreisförmige Werkzeugleiste für den Apple-Pencil-Squeeze.
/// Die Bedienung sitzt auf einem schmalen Kreisbogen statt in einem gefüllten
/// Tortenstück; die Mitte bleibt frei.
struct PencilSqueezePaletteView: View {
    /// Hover-Anker und Fensterkoordinaten werden vom PencilKit-Wrapper geliefert.
    let anchor: CGPoint
    let direction: CGVector
    let containerSize: CGSize
    let containerOrigin: CGPoint

    @Binding var toolSelection: DrawingToolSelection
    @Binding var penWidth: CGFloat
    @Binding var markerWidth: CGFloat
    @Binding var eraserWidth: CGFloat
    @Binding var penColorSlots: [String]
    @Binding var markerColorSlots: [String]

    let onUndo: () -> Void

    @State private var isColorPickerVisible = false
    @State private var pointerHoverTargets: Set<String> = []
    @State private var continuousHoverTargets: Set<String> = []
    @State private var colorPickerHideWorkItem: DispatchWorkItem?

    @State private var isAdjustingWidth = false
    @State private var widthDragStartRadius: CGFloat = 0
    @State private var widthDragStartValue: CGFloat = 0

    // MARK: - Geometrie

    private let arcRadius: CGFloat = 244
    private let arcBandWidth: CGFloat = 76
    private let arcHalfAngle: CGFloat = .pi / 4
    private let buttonSize: CGFloat = 40

    private let colorArcBandWidth: CGFloat = 50
    private let colorSwatchSize: CGFloat = 30
    private let colorArcHalfAngle: CGFloat = 27 * .pi / 180

    private var localAnchor: CGPoint {
        CGPoint(x: anchor.x - containerOrigin.x, y: anchor.y - containerOrigin.y)
    }

    /// Der Pencil-Azimut wurde in der bisherigen Palette um 180 Grad verkehrt
    /// interpretiert. Die Bedienelemente öffnen nun auf der gegenüberliegenden,
    /// zur Stiftspitze passenden Seite.
    private var openingAngle: CGFloat {
        guard direction.dx.isFinite, direction.dy.isFinite,
              direction.dx != 0 || direction.dy != 0 else {
            return .pi / 2
        }
        return atan2(direction.dy, direction.dx) + .pi
    }

    private var arcStartAngle: CGFloat { openingAngle - arcHalfAngle }
    private var arcEndAngle: CGFloat { openingAngle + arcHalfAngle }

    private var paletteElements: [SqueezePaletteElement] {
        [.undo, .divider]
            + SqueezePaletteTool.allCases.map { .tool($0) }
            + [.divider, .color, .thickness]
    }

    private var colorButtonAngle: CGFloat {
        for (index, element) in paletteElements.enumerated() {
            if case .color = element {
                return angleForElement(at: index)
            }
        }
        return openingAngle
    }

    private var colorArcRadius: CGFloat {
        arcRadius + arcBandWidth / 2 + colorArcBandWidth / 2 + 10
    }

    /// Die Palette wird auf kleinen Fenstern skaliert. Für die Berechnung wird
    /// auch die nach außen aufklappende Farbkurve berücksichtigt, damit beim
    /// Öffnen nichts am Bildschirmrand abgeschnitten wird.
    private var paletteScale: CGFloat {
        let bounds = unscaledPaletteBounds()
        let availableWidth = max(1, containerSize.width - 28)
        let availableHeight = max(1, containerSize.height - 28)
        let scaleX = availableWidth / max(1, bounds.width)
        let scaleY = availableHeight / max(1, bounds.height)
        return min(1, max(0.48, min(scaleX, scaleY)))
    }

    /// Umriss der gesamten Palette relativ zum Squeeze-Anker.
    private func unscaledPaletteBounds() -> CGRect {
        var minX: CGFloat = 0
        var maxX: CGFloat = 0
        var minY: CGFloat = 0
        var maxY: CGFloat = 0

        func include(_ point: CGPoint, padding: CGFloat) {
            minX = min(minX, point.x - padding)
            maxX = max(maxX, point.x + padding)
            minY = min(minY, point.y - padding)
            maxY = max(maxY, point.y + padding)
        }

        // Hauptbogen inklusive Buttons und Schatten.
        for step in 0...64 {
            let fraction = CGFloat(step) / 64
            let angle = arcStartAngle + (arcEndAngle - arcStartAngle) * fraction
            let radius = arcRadius + arcBandWidth / 2
            include(offsetPoint(radius: radius, angle: angle), padding: buttonSize / 2 + 12)
        }

        // Außenliegender Farbbogen (wird beim Hover aufgeklappt).
        let paletteColors = colorSlotsForActiveTool.isEmpty
            ? [currentColorHex]
            : colorSlotsForActiveTool
        let colorHalfSpan = colorArcHalfAngle
        for step in 0...max(16, paletteColors.count * 8) {
            let fraction = CGFloat(step) / CGFloat(max(16, paletteColors.count * 8))
            let angle = colorButtonAngle - colorHalfSpan + 2 * colorHalfSpan * fraction
            include(
                offsetPoint(radius: colorArcRadius, angle: angle),
                padding: colorSwatchSize / 2 + 10
            )
        }

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private var clampedAnchor: CGPoint {
        let bounds = unscaledPaletteBounds()
        let margin: CGFloat = 14
        let scaledMinX = bounds.minX * paletteScale
        let scaledMaxX = bounds.maxX * paletteScale
        let scaledMinY = bounds.minY * paletteScale
        let scaledMaxY = bounds.maxY * paletteScale

        let lowerX = max(margin, -scaledMinX + margin)
        let upperX = max(lowerX, containerSize.width - scaledMaxX - margin)
        let lowerY = max(margin, -scaledMinY + margin)
        let upperY = max(lowerY, containerSize.height - scaledMaxY - margin)

        return CGPoint(
            x: min(max(localAnchor.x, lowerX), upperX),
            y: min(max(localAnchor.y, lowerY), upperY)
        )
    }

    private var scaleAnchor: UnitPoint {
        UnitPoint(
            x: containerSize.width > 0 ? clampedAnchor.x / containerSize.width : 0.5,
            y: containerSize.height > 0 ? clampedAnchor.y / containerSize.height : 0.5
        )
    }

    private func offsetPoint(radius: CGFloat, angle: CGFloat) -> CGPoint {
        CGPoint(x: radius * cos(angle), y: radius * sin(angle))
    }

    private func point(radius: CGFloat, angle: CGFloat) -> CGPoint {
        let offset = offsetPoint(radius: radius, angle: angle)
        return CGPoint(x: clampedAnchor.x + offset.x, y: clampedAnchor.y + offset.y)
    }

    private func angleForElement(at index: Int) -> CGFloat {
        let count = max(1, paletteElements.count - 1)
        let fraction = CGFloat(index) / CGFloat(count)
        return arcStartAngle + (arcEndAngle - arcStartAngle) * fraction
    }

    // MARK: - Palette

    var body: some View {
        ZStack {
            if isColorPickerVisible {
                colorChoices
                    .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: scaleAnchor)))
                    .zIndex(0)
            }

            mainArcBackground
                .zIndex(1)

            ForEach(Array(paletteElements.enumerated()), id: \.offset) { index, element in
                let angle = angleForElement(at: index)
                paletteElementView(element, angle: angle)
                    .position(point(radius: arcRadius, angle: angle))
                    .zIndex(2)
            }
        }
        .frame(width: containerSize.width, height: containerSize.height)
        .scaleEffect(paletteScale, anchor: scaleAnchor)
        .animation(.spring(response: 0.28, dampingFraction: 0.84), value: isColorPickerVisible)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Apple Pencil Werkzeugpalette")
    }

    private var mainArcBackground: some View {
        let arc = SqueezeArcShape(
            center: clampedAnchor,
            radius: arcRadius,
            startAngle: arcStartAngle,
            endAngle: arcEndAngle
        )
        let rim = SqueezeArcShape(
            center: clampedAnchor,
            radius: arcRadius + arcBandWidth / 2 - 3,
            startAngle: arcStartAngle,
            endAngle: arcEndAngle
        )

        return ZStack {
            arc
                .stroke(
                    .ultraThinMaterial,
                    style: StrokeStyle(lineWidth: arcBandWidth, lineCap: .round, lineJoin: .round)
                )
                .shadow(color: Color.black.opacity(0.24), radius: 15, x: 0, y: 6)

            rim
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.42), Color.white.opacity(0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 1, lineCap: .round)
                )
        }
    }

    @ViewBuilder
    private func paletteElementView(_ element: SqueezePaletteElement, angle: CGFloat) -> some View {
        switch element {
        case .undo:
            undoButton
        case .divider:
            Capsule()
                .fill(Color.primary.opacity(0.20))
                .frame(width: 1.5, height: 24)
                // Die Linie steht senkrecht zur lokalen Laufrichtung des Bogens.
                .rotationEffect(Angle(radians: Double(angle - .pi / 2)))
                .accessibilityHidden(true)
        case .tool(let tool):
            toolButton(tool)
        case .color:
            colorButton
        case .thickness:
            thicknessButton
        }
    }

    private var undoButton: some View {
        Button {
            Haptics.tap()
            onUndo()
        } label: {
            Image(systemName: "arrow.uturn.backward")
                .font(.system(size: 16, weight: .semibold))
                .frame(width: buttonSize, height: buttonSize)
                .lightButton(cornerRadius: 13, tint: .blue, isFilled: true)
                .foregroundColor(.white)
        }
        .buttonStyle(.plain)
        .hoverEffect(.lift)
        .accessibilityLabel("Rückgängig")
    }

    private func toolButton(_ tool: SqueezePaletteTool) -> some View {
        let isSelected = activeTool == tool

        return Button {
            Haptics.select()
            select(tool)
        } label: {
            Image(systemName: tool.icon)
                .font(.system(size: 16, weight: .medium))
                .frame(width: buttonSize, height: buttonSize)
                .lightButton(
                    cornerRadius: 13,
                    tint: isSelected ? .blue : nil,
                    isFilled: isSelected
                )
                .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
        .hoverEffect(.lift)
        .accessibilityLabel(tool.title)
        .accessibilityValue(isSelected ? "Ausgewählt" : "")
    }

    /// Farbe als einzelner Farbkreis. Der zusätzliche Bogen mit Farb-Slots wird
    /// beim Hovern eingeblendet; Antippen öffnet ihn auch ohne Pointer.
    private var colorButton: some View {
        Button {
            Haptics.tap()
            withAnimation(.spring(response: 0.25, dampingFraction: 0.84)) {
                isColorPickerVisible.toggle()
            }
        } label: {
            Circle()
                .fill(Color(hex: currentColorHex))
                .frame(width: 22, height: 22)
                .overlay(
                    Circle().strokeBorder(
                        currentColorHex.caseInsensitiveCompare("#FFFFFF") == .orderedSame
                            ? Color.gray.opacity(0.55)
                            : Color.white.opacity(0.60),
                        lineWidth: 1
                    )
                )
                .frame(width: buttonSize, height: buttonSize)
                .lightButton(cornerRadius: 13)
        }
        .buttonStyle(.plain)
        .hoverEffect(.lift)
        .onHover { isHovering in
            updateHoverTarget("color-button", isHovering: isHovering, source: .pointer)
        }
        .onContinuousHover { phase in
            switch phase {
            case .active(_):
                updateHoverTarget("color-button", isHovering: true, source: .continuous)
            case .ended:
                updateHoverTarget("color-button", isHovering: false, source: .continuous)
            }
        }
        .accessibilityLabel("Farbe \(currentColorHex)")
        .accessibilityHint("Beim Hovern oder Antippen werden die Farb-Slots geöffnet")
    }

    private var colorChoices: some View {
        let colors = colorSlotsForActiveTool.isEmpty ? [currentColorHex] : colorSlotsForActiveTool
        let count = max(1, colors.count)
        let startAngle = colorButtonAngle - colorArcHalfAngle
        let endAngle = colorButtonAngle + colorArcHalfAngle
        let arc = SqueezeArcShape(
            center: clampedAnchor,
            radius: colorArcRadius,
            startAngle: startAngle,
            endAngle: endAngle
        )

        return ZStack {
            arc
                .stroke(
                    .ultraThinMaterial,
                    style: StrokeStyle(lineWidth: colorArcBandWidth, lineCap: .round, lineJoin: .round)
                )
                .shadow(color: Color.black.opacity(0.20), radius: 10, x: 0, y: 4)

            ForEach(Array(colors.enumerated()), id: \.offset) { index, hex in
                let angle = count == 1
                    ? colorButtonAngle
                    : startAngle + (endAngle - startAngle) * CGFloat(index) / CGFloat(count - 1)
                let isSelected = hex.caseInsensitiveCompare(currentColorHex) == .orderedSame

                Button {
                    Haptics.select()
                    applyColor(hex)
                    withAnimation(.easeOut(duration: 0.16)) {
                        isColorPickerVisible = false
                    }
                } label: {
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(width: colorSwatchSize, height: colorSwatchSize)
                        .overlay(
                            Circle().strokeBorder(
                                hex.caseInsensitiveCompare("#FFFFFF") == .orderedSame
                                    ? Color.gray.opacity(0.55)
                                    : Color.white.opacity(0.75),
                                lineWidth: 1
                            )
                        )
                        .overlay(
                            Circle()
                                .strokeBorder(Color.blue, lineWidth: isSelected ? 2.5 : 0)
                                .padding(-3)
                        )
                        .frame(width: 40, height: 40)
                        .lightButton(
                            cornerRadius: 20,
                            tint: isSelected ? .blue : nil,
                            isFilled: false
                        )
                }
                .buttonStyle(.plain)
                .hoverEffect(.lift)
                .position(point(radius: colorArcRadius, angle: angle))
                .onHover { isHovering in
                    updateHoverTarget("color-\(index)", isHovering: isHovering, source: .pointer)
                }
                .onContinuousHover { phase in
                    switch phase {
                    case .active(_):
                        updateHoverTarget("color-\(index)", isHovering: true, source: .continuous)
                    case .ended:
                        updateHoverTarget("color-\(index)", isHovering: false, source: .continuous)
                    }
                }
                .accessibilityLabel("Farbe \(hex)")
                .accessibilityValue(isSelected ? "Ausgewählt" : "")
            }
        }
        .frame(width: containerSize.width, height: containerSize.height)
        .allowsHitTesting(isColorPickerVisible)
        .accessibilityLabel("Farbauswahl")
    }

    /// Die Dicke wird durch Halten und radiales Ziehen angepasst: zum Anker hin
    /// dünner, vom Anker weg dicker.
    private var thicknessButton: some View {
        Button {} label: {
            VStack(spacing: 1) {
                Image(systemName: "lineweight")
                    .font(.system(size: 13, weight: .semibold))
                Text(formattedWidth)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            .frame(width: buttonSize, height: buttonSize)
            .lightButton(cornerRadius: 13)
            .foregroundColor(.primary)
        }
        .buttonStyle(.plain)
        .hoverEffect(.lift)
        .simultaneousGesture(thicknessHoldAndDragGesture)
        .accessibilityLabel("Stiftdicke \(formattedWidth) Punkt")
        .accessibilityHint("Gedrückt halten und radial ziehen, um die Dicke anzupassen")
    }

    // MARK: - Farbe und Hover

    private func updateHoverTarget(_ target: String, isHovering: Bool, source: HoverSource) {
        switch source {
        case .pointer:
            if isHovering {
                pointerHoverTargets.insert(target)
            } else {
                pointerHoverTargets.remove(target)
            }
        case .continuous:
            if isHovering {
                continuousHoverTargets.insert(target)
            } else {
                continuousHoverTargets.remove(target)
            }
        }

        if isHovering {
            colorPickerHideWorkItem?.cancel()
            withAnimation(.spring(response: 0.25, dampingFraction: 0.84)) {
                isColorPickerVisible = true
            }
        } else {
            scheduleColorPickerDismissal()
        }
    }

    private func scheduleColorPickerDismissal() {
        colorPickerHideWorkItem?.cancel()
        let workItem = DispatchWorkItem {
            guard pointerHoverTargets.isEmpty, continuousHoverTargets.isEmpty else { return }
            withAnimation(.easeOut(duration: 0.16)) {
                isColorPickerVisible = false
            }
        }
        colorPickerHideWorkItem = workItem
        // Die kurze Verzögerung lässt den Pointer/Pencil den schmalen Abstand
        // zwischen Farbbutton und äußerem Farbsegment überqueren.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: workItem)
    }

    // MARK: - Dicke per radialer Geste

    private var thicknessHoldAndDragGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.22)
            .sequenced(
                before: DragGesture(
                    minimumDistance: 0,
                    coordinateSpace: .named(GlobalCoordinateSpace.name)
                )
            )
            .onChanged { value in
                guard case .second(true, let possibleDragValue) = value,
                      let dragValue = possibleDragValue else { return }
                updateThickness(using: dragValue)
            }
            .onEnded { _ in
                isAdjustingWidth = false
                widthDragStartRadius = 0
            }
    }

    private func updateThickness(using drag: DragGesture.Value) {
        let center = CGPoint(
            x: clampedAnchor.x + containerOrigin.x,
            y: clampedAnchor.y + containerOrigin.y
        )
        let startRadius = distance(drag.startLocation, center)
        let currentRadius = distance(drag.location, center)

        if !isAdjustingWidth {
            isAdjustingWidth = true
            widthDragStartRadius = startRadius
            widthDragStartValue = widthBinding.wrappedValue
            Haptics.select()
        }

        let range = widthRange
        let radialChange = currentRadius - widthDragStartRadius
        let pointsForFullRange: CGFloat = 120
        let widthChange = radialChange * (range.upperBound - range.lowerBound) / pointsForFullRange
        setWidth(widthDragStartValue + widthChange)
    }

    private func distance(_ first: CGPoint, _ second: CGPoint) -> CGFloat {
        let dx = first.x - second.x
        let dy = first.y - second.y
        return sqrt(dx * dx + dy * dy)
    }

    // MARK: - Werkzeugzustand

    private var activeTool: SqueezePaletteTool {
        switch toolSelection {
        case .pen: return .pen
        case .marker: return .marker
        case .eraser: return .eraser
        case .lasso: return .lasso
        case .text: return .text
        }
    }

    private func select(_ tool: SqueezePaletteTool) {
        switch tool {
        case .lasso:
            toolSelection = .lasso
        case .pen:
            toolSelection = .pen(color: UIColor(hex: fallbackPenHex))
        case .marker:
            toolSelection = .marker(color: UIColor(hex: fallbackMarkerHex).withAlphaComponent(0.60))
        case .eraser:
            toolSelection = .eraser
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

    private var colorSlotsForActiveTool: [String] {
        if case .marker = toolSelection { return markerColorSlots }
        return penColorSlots
    }

    private var currentColorHex: String {
        switch toolSelection {
        case .pen(let color), .marker(let color):
            return color.toHex()
        case .eraser, .lasso, .text:
            return fallbackPenHex
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

    // MARK: - Dicke

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

    private var formattedWidth: String {
        String(format: "%.1f", widthBinding.wrappedValue)
    }

    private func setWidth(_ value: CGFloat) {
        let range = widthRange
        let clamped = min(max(value, range.lowerBound), range.upperBound)
        widthBinding.wrappedValue = (clamped * 2).rounded() / 2
    }
}

private enum HoverSource {
    case pointer
    case continuous
}

private enum SqueezePaletteElement {
    case undo
    case divider
    case tool(SqueezePaletteTool)
    case color
    case thickness
}

/// Reihenfolge wie vom Nutzer gewünscht: Lasso, Stift, Textmarker, Radierer, Text.
private enum SqueezePaletteTool: Int, CaseIterable, Identifiable {
    case lasso
    case pen
    case marker
    case eraser
    case text

    var id: Int { rawValue }

    var icon: String {
        switch self {
        case .lasso: return "lasso"
        case .pen: return "pencil.tip"
        case .marker: return "highlighter"
        case .eraser: return "eraser"
        case .text: return "textformat"
        }
    }

    var title: String {
        switch self {
        case .lasso: return "Lasso"
        case .pen: return "Stift"
        case .marker: return "Textmarker"
        case .eraser: return "Radierer"
        case .text: return "Text"
        }
    }
}

/// Open circle arc. Beim Strich mit `lineCap: .round` entsteht ein gerundetes
/// Bogen-Segment statt eines Tortenstücks.
struct SqueezeArcShape: Shape {
    let center: CGPoint
    let radius: CGFloat
    let startAngle: CGFloat
    let endAngle: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let steps = 80
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
