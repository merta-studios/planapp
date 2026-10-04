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
    @State private var pointerHoveredPaletteElements: Set<String> = []
    @State private var continuouslyHoveredPaletteElements: Set<String> = []
    @State private var colorPickerHideWorkItem: DispatchWorkItem?

    @State private var isAdjustingWidth = false
    @State private var widthDragStartRadius: CGFloat = 0
    @State private var widthDragStartValue: CGFloat = 0

    // MARK: - Geometrie

    private let arcRadius = SqueezePaletteLayout.arcRadius
    private let arcBandWidth = SqueezePaletteLayout.arcBandWidth
    private let arcHalfAngle = SqueezePaletteLayout.arcHalfAngle
    private let buttonSize = SqueezePaletteLayout.buttonSize

    private let colorArcBandWidth = SqueezePaletteLayout.colorBandWidth
    private let colorSwatchSize = SqueezePaletteLayout.colorSwatchSize
    private var colorArcHalfAngle: CGFloat {
        SqueezePaletteLayout.colorHalfAngle(for: max(1, colorSlotsForActiveTool.count))
    }

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
        [.undo] + SqueezePaletteTool.allCases.map { .tool($0) } + [.color, .thickness]
    }

    private var colorButtonAngle: CGFloat {
        for (index, element) in paletteElements.enumerated() {
            if case .color = element {
                return angleForElement(at: index)
            }
        }
        return openingAngle
    }

    private var colorArcRadius: CGFloat { SqueezePaletteLayout.colorArcRadius }

    private var layout: SqueezePaletteLayout {
        SqueezePaletteLayout(
            hoverAnchor: localAnchor,
            containerSize: containerSize,
            openingAngle: openingAngle,
            colorCount: max(1, colorSlotsForActiveTool.count)
        )
    }

    private var paletteScale: CGFloat { layout.scale }
    private var clampedAnchor: CGPoint { layout.anchor }

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
        SqueezePaletteLayout.angle(at: index, openingAngle: openingAngle)
    }

    // MARK: - Palette

    var body: some View {
        glassPalette
            .frame(width: containerSize.width, height: containerSize.height)
            .scaleEffect(paletteScale, anchor: scaleAnchor)
            .animation(.spring(response: 0.28, dampingFraction: 0.84), value: isColorPickerVisible)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Apple Pencil Werkzeugpalette")
            .onDisappear { colorPickerHideWorkItem?.cancel() }
    }

    @ViewBuilder
    private var glassPalette: some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 1) { paletteContent }
        } else {
            paletteContent
        }
        #else
        paletteContent
        #endif
    }

    private var paletteContent: some View {
        ZStack {
            if isColorPickerVisible {
                colorChoices
                    .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: scaleAnchor)))
                    .zIndex(0)
            }

            mainArcBackground
                .allowsHitTesting(false)
                .zIndex(1)

            ForEach(Array(paletteElements.enumerated()), id: \.offset) { index, element in
                let angle = angleForElement(at: index)
                paletteElementView(element)
                    .position(point(radius: arcRadius, angle: angle))
                    .zIndex(2)
            }
        }
        .frame(width: containerSize.width, height: containerSize.height)
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
    private func paletteElementView(_ element: SqueezePaletteElement) -> some View {
        switch element {
        case .undo:
            undoButton
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
                .font(.system(size: 18, weight: .semibold))
                .frame(width: buttonSize, height: buttonSize)
                .foregroundColor(.primary)
        }
        .buttonStyle(SqueezePaletteButtonStyle(isHovered: isPaletteElementHovered("undo")))
        .hoverEffect(.lift)
        .modifier(paletteElementHoverTracking("undo"))
        .accessibilityLabel("Rückgängig")
    }

    private func toolButton(_ tool: SqueezePaletteTool) -> some View {
        let isSelected = activeTool == tool
        let hoverID = "tool-\(tool.rawValue)"

        return Button {
            Haptics.select()
            select(tool)
        } label: {
            Image(systemName: tool.icon)
                .font(.system(size: 18, weight: isSelected ? .semibold : .medium))
                .frame(width: buttonSize, height: buttonSize)
                .foregroundColor(isSelected ? .blue : .primary)
        }
        .buttonStyle(
            SqueezePaletteButtonStyle(
                isSelected: isSelected,
                isHovered: isPaletteElementHovered(hoverID)
            )
        )
        .hoverEffect(.lift)
        .modifier(paletteElementHoverTracking(hoverID))
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
                .frame(width: 26, height: 26)
                .overlay(
                    Circle().strokeBorder(
                        currentColorHex.caseInsensitiveCompare("#FFFFFF") == .orderedSame
                            ? Color.gray.opacity(0.55)
                            : Color.white.opacity(0.60),
                        lineWidth: 1
                    )
                )
                .frame(width: buttonSize, height: buttonSize)
        }
        .buttonStyle(
            SqueezePaletteButtonStyle(
                isSelected: isColorPickerVisible,
                isHovered: isPaletteElementHovered("color-button")
            )
        )
        .hoverEffect(.lift)
        .modifier(paletteElementHoverTracking("color-button"))
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
                .allowsHitTesting(false)

            ForEach(Array(colors.enumerated()), id: \.offset) { index, hex in
                let angle = count == 1
                    ? colorButtonAngle
                    : startAngle + (endAngle - startAngle) * CGFloat(index) / CGFloat(count - 1)
                let isSelected = hex.caseInsensitiveCompare(currentColorHex) == .orderedSame
                let hoverID = "color-\(index)"

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
                        .frame(width: buttonSize, height: buttonSize)
                }
                .buttonStyle(
                    SqueezePaletteButtonStyle(
                        isSelected: isSelected,
                        isHovered: isPaletteElementHovered(hoverID)
                    )
                )
                .hoverEffect(.lift)
                .modifier(paletteElementHoverTracking(hoverID))
                .position(point(radius: colorArcRadius, angle: angle))
                .onHover { isHovering in
                    updateHoverTarget(hoverID, isHovering: isHovering, source: .pointer)
                }
                .onContinuousHover { phase in
                    switch phase {
                    case .active(_):
                        updateHoverTarget(hoverID, isHovering: true, source: .continuous)
                    case .ended:
                        updateHoverTarget(hoverID, isHovering: false, source: .continuous)
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
                    .font(.system(size: 16, weight: .semibold))
                Text(formattedWidth)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            .frame(width: buttonSize, height: buttonSize)
            .foregroundColor(.primary)
        }
        .buttonStyle(
            SqueezePaletteButtonStyle(
                isSelected: isAdjustingWidth,
                isHovered: isPaletteElementHovered("thickness")
            )
        )
        .hoverEffect(.lift)
        .modifier(paletteElementHoverTracking("thickness"))
        .simultaneousGesture(thicknessHoldAndDragGesture)
        .accessibilityLabel("Stiftdicke \(formattedWidth) Punkt")
        .accessibilityHint("Gedrückt halten und radial ziehen, um die Dicke anzupassen")
    }

    // MARK: - Farbe und Hover

    private func isPaletteElementHovered(_ identifier: String) -> Bool {
        pointerHoveredPaletteElements.contains(identifier)
            || continuouslyHoveredPaletteElements.contains(identifier)
    }

    private func paletteElementHoverTracking(_ identifier: String) -> SqueezePaletteHoverTrackingModifier {
        SqueezePaletteHoverTrackingModifier(
            identifier: identifier,
            pointerTargets: $pointerHoveredPaletteElements,
            continuousTargets: $continuouslyHoveredPaletteElements
        )
    }

    private func updateHoverTarget(_ target: String, isHovering: Bool, source: HoverSource) {
        let didChange: Bool
        switch source {
        case .pointer:
            if isHovering {
                didChange = pointerHoverTargets.insert(target).inserted
            } else {
                didChange = pointerHoverTargets.remove(target) != nil
            }
        case .continuous:
            if isHovering {
                didChange = continuousHoverTargets.insert(target).inserted
            } else {
                didChange = continuousHoverTargets.remove(target) != nil
            }
        }
        guard didChange else { return }

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

/// Tracking occurs once on enter/exit (not on every Pencil-hover coordinate),
/// then feeds a visible hover treatment into the button style.
private struct SqueezePaletteHoverTrackingModifier: ViewModifier {
    let identifier: String
    @Binding var pointerTargets: Set<String>
    @Binding var continuousTargets: Set<String>

    func body(content: Content) -> some View {
        content
            .onHover { hovering in
                update(hovering, identifier: identifier, targets: $pointerTargets)
            }
            .onContinuousHover { phase in
                switch phase {
                case .active(_):
                    update(true, identifier: identifier, targets: $continuousTargets)
                case .ended:
                    update(false, identifier: identifier, targets: $continuousTargets)
                }
            }
    }

    private func update(_ hovering: Bool, identifier: String, targets: Binding<Set<String>>) {
        var current = targets.wrappedValue
        let changed: Bool
        if hovering {
            changed = current.insert(identifier).inserted
        } else {
            changed = current.remove(identifier) != nil
        }
        guard changed else { return }
        targets.wrappedValue = current
    }
}

private enum SqueezePaletteElement {
    case undo
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
