import SwiftUI
import UIKit

/// Abgerundete, kompakte Bogen-Werkzeugleiste für den Apple-Pencil-Squeeze.
/// Die Bedienung sitzt auf einem dicken Kreisbogen nahe der Hover-Position
/// statt in einem gefüllten Tortenstück; die Mitte bleibt frei.
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
    /// Zuletzt ausgewählte Tintenfarben bleiben auch beim Wechsel über
    /// Radierer/Lasso/Text erhalten. Damit öffnen beide Werkzeugleisten den
    /// jeweiligen Stift wieder mit derselben Farbe.
    let preferredPenColorHex: String
    let preferredMarkerColorHex: String
    /// Ist ein Textfeld aktiv, ist dessen Farbe die gemeinsame Quelle für
    /// beide Werkzeugleisten – eine Farbauswahl darf nicht heimlich zum Stift
    /// wechseln.
    let selectedTextColorHex: String?
    let onApplyColorToSelectedText: (String) -> Void

    let onUndo: () -> Void
    var undoCount: Int = 0
    var redoCount: Int = 0
    var historyRevision: Int = 0
    var onUndoScrubBegan: (CGPoint, CGPoint) -> Void = { _, _ in }
    var onUndoScrubChanged: (CGSize, CGPoint) -> Void = { _, _ in }
    var onUndoScrubEnded: () -> Void = {}
    var hidesNonUndoElements: Bool = false

    @State private var isColorPickerVisible = false
    @State private var pointerHoverTargets: Set<String> = []
    @State private var continuousHoverTargets: Set<String> = []
    @State private var pointerHoveredPaletteElements: Set<String> = []
    @State private var continuouslyHoveredPaletteElements: Set<String> = []
    @State private var colorPickerHideWorkItem: DispatchWorkItem?

    @State private var isAdjustingWidth = false
    @State private var widthDragStartValue: CGFloat = 0
    /// Sichtbarer Mittelpunkt des Bogens nach dem Einpassen (Global-Koordinaten).
    @State private var visualCircleCenter: CGPoint = .zero
    /// Startpunkt der laufenden Dicken-Geste (Fensterkoordinaten).
    @State private var widthDragStartLocation: CGPoint = .zero
    /// Ob sich die Dicke in dieser Geste tatsächlich geändert hat (zählt als
    /// „gelernt“ für die Hilfslinien).
    @State private var didChangeWidthInGesture = false
    /// Wie oft die Dicken-Geste bereits erfolgreich benutzt wurde. Solange
    /// der Wert klein ist, zeigt die Palette beim Halten Hilfslinien.
    @State private var thicknessGestureSuccessCount = SqueezeThicknessHints.successCount

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
            colorCount: max(1, colorSlotsForActiveTool.count),
            includesColorArc: isColorPickerVisible
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
            if isColorPickerVisible, !hidesNonUndoElements {
                colorChoices
                    .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: scaleAnchor)))
                    .zIndex(0)
            }

            if !hidesNonUndoElements {
                mainArcBackground
                    .allowsHitTesting(false)
                    .zIndex(1)
            }

            if isAdjustingWidth {
                thicknessGuide
                    .allowsHitTesting(false)
                    .transition(.opacity)
                    .zIndex(4)
            }

            Color.clear
                .frame(width: 2, height: 2)
                .position(clampedAnchor)
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: SqueezeCircleCenterPreference.self,
                            value: CGPoint(
                                x: proxy.frame(in: .global).midX,
                                y: proxy.frame(in: .global).midY
                            )
                        )
                    }
                )
                .allowsHitTesting(false)
                .zIndex(0)

            ForEach(Array(paletteElements.enumerated()), id: \.offset) { index, element in
                let angle = angleForElement(at: index)
                if hidesNonUndoElements && !element.isUndo {
                    EmptyView()
                } else {
                    paletteElementView(element)
                        .position(point(radius: arcRadius, angle: angle))
                        .zIndex(element.isUndo ? 3 : 2)
                }
            }
        }
        .onPreferenceChange(SqueezeCircleCenterPreference.self) { center in
            if center != .zero { visualCircleCenter = center }
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
        ZStack {
            Image(systemName: "arrow.uturn.backward")
                .font(.system(size: 18, weight: .semibold))
                .frame(width: buttonSize, height: buttonSize)
                .foregroundColor(.primary)
                .opacity(hidesNonUndoElements ? 0 : 1)

            UndoScrubHandle(
                allowsFinger: false,
                style: .circular,
                circleCenterInGlobal: visualCircleCenter,
                onTap: {
                    Haptics.tap()
                    onUndo()
                },
                onScrubBegan: onUndoScrubBegan,
                onScrubChanged: onUndoScrubChanged,
                onScrubEnded: onUndoScrubEnded
            )
        }
        .frame(width: buttonSize, height: buttonSize)
        .modifier(SqueezePaletteSurface(isHovered: isPaletteElementHovered("undo")))
        .contentShape(Circle())
        .hoverEffect(.lift)
        .modifier(paletteElementHoverTracking("undo"))
        .accessibilityLabel("Rückgängig")
        .accessibilityHint("Mit dem Stift eine Sekunde halten, um im Kreis mehrere Schritte zu scrubben")
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
    ///
    /// Kein `Button` und keine Long-Press-Sequenz mehr: Beides hat die Geste
    /// häufig verschluckt (der Button beanspruchte die Berührung, die
    /// Long-Press-Phase scheiterte, sobald der Stift sich sofort bewegte).
    /// Jetzt reagiert ein einfaches `DragGesture(minimumDistance: 0)` ab dem
    /// ersten Kontakt; die Bewegung wird auf die radiale Achse projiziert.
    private var thicknessButton: some View {
        VStack(spacing: 1) {
            Image(systemName: "lineweight")
                .font(.system(size: 16, weight: .semibold))
            Text(formattedWidth)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .monospacedDigit()
        }
        .frame(width: buttonSize, height: buttonSize)
        .foregroundColor(.primary)
        .modifier(
            SqueezePaletteSurface(
                isSelected: isAdjustingWidth,
                isHovered: isPaletteElementHovered("thickness")
            )
        )
        .contentShape(Circle())
        .scaleEffect(isAdjustingWidth ? 1.08 : 1)
        .animation(.spring(response: 0.22, dampingFraction: 0.8), value: isAdjustingWidth)
        .hoverEffect(.lift)
        .modifier(paletteElementHoverTracking("thickness"))
        .overlay {
            ThicknessTouchCatcher(
                onBegan: { beginThickness(at: $0) },
                onMoved: { updateThickness(at: $0) },
                onEnded: { finishThicknessGesture() }
            )
        }
        .accessibilityLabel("Stiftdicke \(formattedWidth) Punkt")
        .accessibilityHint("Gedrückt halten und vom Kreis weg ziehen für dicker, zum Kreis hin für dünner")
    }

    /// Winkel, unter dem der Dicken-Button auf dem Bogen sitzt – entlang
    /// dieser Achse (Anker → Button) wird die Dicke verändert.
    private var thicknessButtonAngle: CGFloat {
        for (index, element) in paletteElements.enumerated() {
            if case .thickness = element {
                return angleForElement(at: index)
            }
        }
        return openingAngle
    }

    /// Einheitsvektor vom Anker durch den Dicken-Button (dicker = in diese Richtung).
    private var thicknessAxis: CGVector {
        let angle = thicknessButtonAngle
        return CGVector(dx: cos(angle), dy: sin(angle))
    }

    /// Hilfslinien: Beim Halten erscheint durch den Button
    /// eine Linie in beide radiale Richtungen – je weiter vom Button entfernt,
    /// desto transparenter. Außen „+“ (dicker), innen „−“ (dünner).
    private var thicknessGuide: some View {
        let center = point(radius: arcRadius, angle: thicknessButtonAngle)
        let axis = thicknessAxis
        let reach: CGFloat = 150
        let segments = 18

        return ZStack {
            Canvas { context, _ in
                for directionSign in [CGFloat(1), CGFloat(-1)] {
                    for index in 0..<segments {
                        let startDistance = buttonSize / 2 + 6 + CGFloat(index) * (reach / CGFloat(segments))
                        let endDistance = startDistance + reach / CGFloat(segments) - 2
                        let progress = CGFloat(index) / CGFloat(segments - 1)
                        let opacity = 0.9 * (1 - progress) * (1 - progress) + 0.05
                        var path = Path()
                        path.move(to: CGPoint(
                            x: center.x + axis.dx * startDistance * directionSign,
                            y: center.y + axis.dy * startDistance * directionSign
                        ))
                        path.addLine(to: CGPoint(
                            x: center.x + axis.dx * endDistance * directionSign,
                            y: center.y + axis.dy * endDistance * directionSign
                        ))
                        context.stroke(
                            path,
                            with: .color(Color.blue.opacity(opacity)),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                    }
                }
            }

            thicknessGuideLabel("plus", distance: buttonSize / 2 + reach * 0.55, sign: 1, center: center, axis: axis)
            thicknessGuideLabel("minus", distance: buttonSize / 2 + reach * 0.55, sign: -1, center: center, axis: axis)
        }
        .frame(width: containerSize.width, height: containerSize.height)
    }

    private func thicknessGuideLabel(
        _ symbol: String,
        distance: CGFloat,
        sign: CGFloat,
        center: CGPoint,
        axis: CGVector
    ) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(.white)
            .frame(width: 20, height: 20)
            .background(Circle().fill(Color.blue.opacity(0.75)))
            .position(
                x: center.x + axis.dx * distance * sign,
                y: center.y + axis.dy * distance * sign
            )
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

    /// Ab dem ersten Kontakt aktiv. Die Bewegung seit dem Start wird auf die
    /// Achse Anker → Dicken-Button projiziert: vom Kreis weg = dicker, zum
    /// Kreis hin = dünner. Dadurch zählt jede Wischrichtung mit ihrem Anteil
    /// entlang dieser Achse – auch leicht schräge Bewegungen.
    private func beginThickness(at location: CGPoint) {
        widthDragStartLocation = location
        widthDragStartValue = widthBinding.wrappedValue
        didChangeWidthInGesture = false
        withAnimation(.easeOut(duration: 0.12)) {
            isAdjustingWidth = true
        }
        Haptics.select()
    }

    private func updateThickness(at location: CGPoint) {
        if !isAdjustingWidth {
            beginThickness(at: location)
        }

        // Fensterkoordinaten sind von der Skalierung der Palette unabhängig;
        // der Richtungsvektor der Achse ist skalierungsneutral.
        let axis = thicknessAxis
        let deltaX = location.x - widthDragStartLocation.x
        let deltaY = location.y - widthDragStartLocation.y
        let radialChange = (deltaX * axis.dx + deltaY * axis.dy) / max(paletteScale, 0.01)

        let range = widthRange
        // Doppelt so viel Weg pro Wertebereich wie früher: Jeder 0,5er-Schritt
        // liegt damit ungefähr doppelt so weit auseinander und lässt sich
        // deutlich genauer einstellen.
        let pointsForFullRange: CGFloat = 280
        let widthChange = radialChange * (range.upperBound - range.lowerBound) / pointsForFullRange
        let previous = widthBinding.wrappedValue
        setWidth(widthDragStartValue + widthChange)
        if widthBinding.wrappedValue != previous {
            didChangeWidthInGesture = true
        }
    }

    private func finishThicknessGesture() {
        if didChangeWidthInGesture {
            Haptics.tap()
            thicknessGestureSuccessCount += 1
            SqueezeThicknessHints.successCount = thicknessGestureSuccessCount
        }
        withAnimation(.easeOut(duration: 0.16)) {
            isAdjustingWidth = false
        }
        didChangeWidthInGesture = false
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
        return preferredPenColorHex
    }

    private var fallbackMarkerHex: String {
        if case .marker(let color) = toolSelection { return color.toHex() }
        return preferredMarkerColorHex
    }

    private var colorSlotsForActiveTool: [String] {
        // Ein selektiertes Textfeld hat Vorrang vor dem Zeichenwerkzeug –
        // exakt wie in der normalen Toolbar.
        if selectedTextColorHex != nil { return penColorSlots }
        if case .marker = toolSelection { return markerColorSlots }
        return penColorSlots
    }

    private var currentColorHex: String {
        if let selectedTextColorHex { return selectedTextColorHex }
        switch toolSelection {
        case .pen(let color), .marker(let color):
            return color.toHex()
        case .eraser, .lasso, .text:
            return fallbackPenHex
        }
    }

    private func applyColor(_ hex: String) {
        if selectedTextColorHex != nil {
            onApplyColorToSelectedText(hex)
            return
        }

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

    var isUndo: Bool {
        if case .undo = self { return true }
        return false
    }
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

/// Merkt sich, wie oft die Dicken-Geste erfolgreich benutzt wurde. Die
/// Hilfslinien erscheinen nur für neue Nutzer und verschwinden nach einigen
/// erfolgreichen Anpassungen von selbst.
struct SqueezeCircleCenterPreference: PreferenceKey {
    static var defaultValue: CGPoint = .zero
    static func reduce(value: inout CGPoint, nextValue: () -> CGPoint) {
        let next = nextValue()
        if next != .zero { value = next }
    }
}

/// Fängt Stift und Finger auf dem Dicken-Knopf ab. SwiftUI-DragGesten haben
/// den Halt mit dem Pencil oft verschluckt, sodass die Hilfslinie ausblieb.
struct ThicknessTouchCatcher: UIViewRepresentable {
    var onBegan: (CGPoint) -> Void
    var onMoved: (CGPoint) -> Void
    var onEnded: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> ThicknessTouchView {
        let view = ThicknessTouchView()
        view.backgroundColor = .clear
        view.coordinator = context.coordinator
        return view
    }

    func updateUIView(_ uiView: ThicknessTouchView, context: Context) {
        context.coordinator.parent = self
        uiView.coordinator = context.coordinator
    }

    final class Coordinator {
        var parent: ThicknessTouchCatcher
        init(_ parent: ThicknessTouchCatcher) { self.parent = parent }
    }
}

final class ThicknessTouchView: UIView, UIGestureRecognizerDelegate {
    var coordinator: ThicknessTouchCatcher.Coordinator?
    private var tracking = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = true
        let recognizer = ThicknessPressRecognizer(target: self, action: #selector(handlePress(_:)))
        recognizer.cancelsTouchesInView = false
        recognizer.delaysTouchesBegan = false
        recognizer.delaysTouchesEnded = false
        recognizer.allowedTouchTypes = [
            NSNumber(value: UITouch.TouchType.pencil.rawValue),
            NSNumber(value: UITouch.TouchType.direct.rawValue)
        ]
        recognizer.delegate = self
        addGestureRecognizer(recognizer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        bounds.contains(point)
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        false
    }

    @objc private func handlePress(_ recognizer: UIGestureRecognizer) {
        let location = recognizer.location(in: nil)
        switch recognizer.state {
        case .began:
            tracking = true
            coordinator?.parent.onBegan(location)
        case .changed:
            if !tracking {
                tracking = true
                coordinator?.parent.onBegan(location)
            }
            coordinator?.parent.onMoved(location)
        case .ended, .cancelled, .failed:
            let wasTracking = tracking
            tracking = false
            if wasTracking {
                coordinator?.parent.onEnded()
            }
        default:
            break
        }
    }
}

/// Beginnt beim ersten Kontakt, nicht erst nach einer Mindestbewegung.
/// SwiftUI-Drags haben den Pencil-Halt auf dem Dicken-Knopf sonst verschluckt.
final class ThicknessPressRecognizer: UIGestureRecognizer {
    override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool {
        false
    }

    override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        guard let touch = touches.first, (touch.type == .pencil || touch.type == .direct) else {
            state = .failed
            return
        }
        state = .began
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        if state == .began || state == .changed {
            state = .changed
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        state = .ended
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        state = .cancelled
    }
}

enum SqueezeThicknessHints {
    static let guideUntilSuccessCount = 6
    private static let key = "planapp_squeeze_thickness_success_count"

    static var successCount: Int {
        get { UserDefaults.standard.integer(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}
