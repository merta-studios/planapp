import SwiftUI
import PencilKit

/// Always-visible, horizontally scrollable drawing controls. The toolbar is
/// deliberately independent from the editor card so moving or resizing the
/// note never moves the tools off-screen.
public struct DrawingToolbarView: View {
    @Binding public var toolSelection: DrawingToolSelection
    @Binding public var penWidth: CGFloat
    @Binding public var markerWidth: CGFloat
    @Binding public var eraserWidth: CGFloat
    @Binding public var penColorSlots: [String]
    @Binding public var markerColorSlots: [String]

    public let onUndo: () -> Void
    public let onRedo: () -> Void
    public let onClear: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var showThicknessSlider = false
    @State private var showClearConfirmation = false
    @State private var editingPenSlotIndex: Int? = nil
    @State private var editingMarkerSlotIndex: Int? = nil

    private let buttonSize: CGFloat = 40
    private let buttonCornerRadius: CGFloat = 10

    public init(
        toolSelection: Binding<DrawingToolSelection>,
        penWidth: Binding<CGFloat>,
        markerWidth: Binding<CGFloat>,
        eraserWidth: Binding<CGFloat>,
        penColorSlots: Binding<[String]>,
        markerColorSlots: Binding<[String]>,
        onUndo: @escaping () -> Void,
        onRedo: @escaping () -> Void,
        onClear: @escaping () -> Void
    ) {
        _toolSelection = toolSelection
        _penWidth = penWidth
        _markerWidth = markerWidth
        _eraserWidth = eraserWidth
        _penColorSlots = penColorSlots
        _markerColorSlots = markerColorSlots
        self.onUndo = onUndo
        self.onRedo = onRedo
        self.onClear = onClear
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                penControls
                toolbarDivider
                markerControls
                toolbarDivider
                textToolButton
                thicknessButton
                eraserButton
                toolbarDivider
                historyControls
                toolbarDivider
                moreOptionsButton
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .fixedSize(horizontal: true, vertical: false)
        }
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.3), Color.white.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 2)
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Zeichenwerkzeuge")
    }

    // MARK: - Stift-Farben

    private var penControls: some View {
        HStack(spacing: 6) {
            Image(systemName: "pencil.tip")
                .font(.system(size: 15))
                .foregroundColor(.primary)
                .accessibilityHidden(true)

            ForEach(Array(penColorSlots.enumerated()), id: \.offset) { index, hex in
                let slotColor = UIColor(hex: hex)
                let isSelected: Bool = {
                    if case .pen(let selectedColor) = toolSelection {
                        return selectedColor.toHex().caseInsensitiveCompare(hex) == .orderedSame
                    }
                    return false
                }()
                let swatch: Color = {
                    if hex.caseInsensitiveCompare("#000000") == .orderedSame || hex.caseInsensitiveCompare("#1E1E1E") == .orderedSame {
                        return colorScheme == .dark ? .white : Color(hex: hex)
                    }
                    return Color(hex: hex)
                }()

                Button {
                    if isSelected {
                        Haptics.tap()
                        editingPenSlotIndex = index
                    } else {
                        Haptics.select()
                        toolSelection = .pen(color: slotColor)
                    }
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: buttonCornerRadius, style: .continuous)
                            .fill(isSelected ? Color.blue.opacity(0.18) : Color.clear)

                        Circle()
                            .fill(swatch)
                            .frame(width: 22, height: 22)
                            .overlay(
                                Circle().strokeBorder(
                                    hex.caseInsensitiveCompare("#FFFFFF") == .orderedSame
                                        ? Color.gray.opacity(0.4)
                                        : Color.white.opacity(0.4),
                                    lineWidth: 1
                                )
                            )

                        if isSelected {
                            RoundedRectangle(cornerRadius: buttonCornerRadius, style: .continuous)
                                .strokeBorder(Color.blue, lineWidth: 2)
                        }
                    }
                    .frame(width: buttonSize - 4, height: buttonSize - 4)
                }
                .buttonStyle(.plain)
                .hoverEffect(.lift)
                .accessibilityLabel("Stift Slot \(index + 1)")
                .accessibilityValue(isSelected ? "Ausgewählt" : "")
                .popover(
                    isPresented: Binding(
                        get: { editingPenSlotIndex == index },
                        set: { isPresented in
                            if !isPresented && editingPenSlotIndex == index {
                                editingPenSlotIndex = nil
                            }
                        }
                    ),
                    arrowEdge: .top
                ) {
                    DrawingColorPalettePopover(
                        selectedHex: hex,
                        onSelectColor: { newHex in
                            if index < penColorSlots.count {
                                penColorSlots[index] = newHex
                            }
                            toolSelection = .pen(color: UIColor(hex: newHex))
                            editingPenSlotIndex = nil
                        }
                    )
                    .presentationCompactAdaptation(.popover)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(UIColor.tertiarySystemBackground).opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Textmarker-Farben

    private var markerControls: some View {
        HStack(spacing: 6) {
            Image(systemName: "highlighter")
                .font(.system(size: 15))
                .foregroundColor(.primary)
                .accessibilityHidden(true)

            ForEach(Array(markerColorSlots.enumerated()), id: \.offset) { index, hex in
                let slotColor = UIColor(hex: hex).withAlphaComponent(0.60)
                let isSelected: Bool = {
                    if case .marker(let selectedColor) = toolSelection {
                        return selectedColor.toHex().caseInsensitiveCompare(hex) == .orderedSame
                    }
                    return false
                }()
                let swatch = Color(hex: hex)

                Button {
                    if isSelected {
                        Haptics.tap()
                        editingMarkerSlotIndex = index
                    } else {
                        Haptics.select()
                        toolSelection = .marker(color: slotColor)
                    }
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: buttonCornerRadius, style: .continuous)
                            .fill(isSelected ? Color.blue.opacity(0.18) : Color.clear)

                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(swatch)
                            .frame(width: 21, height: 21)

                        if isSelected {
                            RoundedRectangle(cornerRadius: buttonCornerRadius, style: .continuous)
                                .strokeBorder(Color.blue, lineWidth: 2)
                        }
                    }
                    .frame(width: buttonSize - 4, height: buttonSize - 4)
                }
                .buttonStyle(.plain)
                .hoverEffect(.lift)
                .accessibilityLabel("Textmarker Slot \(index + 1)")
                .accessibilityValue(isSelected ? "Ausgewählt" : "")
                .popover(
                    isPresented: Binding(
                        get: { editingMarkerSlotIndex == index },
                        set: { isPresented in
                            if !isPresented && editingMarkerSlotIndex == index {
                                editingMarkerSlotIndex = nil
                            }
                        }
                    ),
                    arrowEdge: .top
                ) {
                    DrawingColorPalettePopover(
                        selectedHex: hex,
                        onSelectColor: { newHex in
                            if index < markerColorSlots.count {
                                markerColorSlots[index] = newHex
                            }
                            toolSelection = .marker(color: UIColor(hex: newHex).withAlphaComponent(0.60))
                            editingMarkerSlotIndex = nil
                        }
                    )
                    .presentationCompactAdaptation(.popover)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(UIColor.tertiarySystemBackground).opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Text-Werkzeug

    private var textToolButton: some View {
        let isSelected: Bool = {
            if case .text = toolSelection { return true }
            return false
        }()

        return Button {
            Haptics.select()
            toolSelection = .text
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "textformat")
                    .font(.system(size: 15, weight: .semibold))
                Text("Text")
                    .font(.system(size: 13, weight: .medium))
            }
            .padding(.horizontal, 12)
            .frame(height: buttonSize)
            .background(isSelected ? Color.blue : Color(UIColor.tertiarySystemBackground).opacity(0.72))
            .foregroundColor(isSelected ? .white : .primary)
            .clipShape(RoundedRectangle(cornerRadius: buttonCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .hoverEffect(.lift)
        .accessibilityLabel("Text-Werkzeug")
        .accessibilityValue(isSelected ? "Ausgewählt" : "")
    }

    // MARK: - Strichstärke (pro Werkzeug getrennt)

    /// Öffnet den Dicken-Regler für das aktuell gewählte Werkzeug. Stift,
    /// Textmarker und Radierer merken sich ihre Dicke unabhängig voneinander.
    private var thicknessButton: some View {
        Button {
            Haptics.tap()
            showThicknessSlider = true
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: buttonCornerRadius, style: .continuous)
                    .fill(Color(UIColor.tertiarySystemBackground).opacity(0.72))
                // Punkt 1:1 in pt – der Kreis zeigt exakt die Strichstärke,
                // nur durch die Button-Größe nach oben begrenzt.
                Circle()
                    .fill(Color.primary)
                    .frame(
                        width: max(3, min(24, currentToolWidth)),
                        height: max(3, min(24, currentToolWidth))
                    )
            }
            .frame(width: buttonSize, height: buttonSize)
        }
        .buttonStyle(.plain)
        .hoverEffect(.lift)
        .accessibilityLabel("Strichstärke")
        // Öffnet sich nach UNTEN, weil über der Leiste kein Platz ist.
        .popover(isPresented: $showThicknessSlider, arrowEdge: .top) {
            ThicknessSliderPanel(
                width: currentWidthBinding,
                range: currentWidthRange,
                previewColor: currentToolPreviewColor,
                title: currentThicknessTitle
            )
            .presentationCompactAdaptation(.popover)
        }
    }

    private var currentWidthBinding: Binding<CGFloat> {
        switch toolSelection {
        case .pen, .text:
            return $penWidth
        case .marker:
            return $markerWidth
        case .eraser:
            return $eraserWidth
        }
    }

    private var currentToolWidth: CGFloat {
        currentWidthBinding.wrappedValue
    }

    private var currentWidthRange: ClosedRange<CGFloat> {
        switch toolSelection {
        case .pen, .text:
            return 1...20
        case .marker:
            return 4...40
        case .eraser:
            return 4...60
        }
    }

    private var currentThicknessTitle: String {
        switch toolSelection {
        case .pen, .text:
            return "Stift-Dicke"
        case .marker:
            return "Textmarker-Dicke"
        case .eraser:
            return "Radierer-Dicke"
        }
    }

    /// The color used for the live thickness preview, matching whichever tool
    /// is currently selected.
    private var currentToolPreviewColor: Color {
        switch toolSelection {
        case .pen(let color):
            return colorScheme == .dark && color == .black ? .white : Color(uiColor: color)
        case .marker(let color):
            return Color(uiColor: color.withAlphaComponent(1))
        case .eraser:
            return Color(UIColor.systemGray2)
        case .text:
            return .primary
        }
    }

    // MARK: - Radierer

    private var eraserButton: some View {
        let isSelected: Bool = {
            if case .eraser = toolSelection { return true }
            return false
        }()

        return Button {
            Haptics.select()
            toolSelection = .eraser
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "eraser")
                    .font(.system(size: 15))
                Text("Radierer")
                    .font(.system(size: 13, weight: .medium))
            }
            .padding(.horizontal, 12)
            .frame(height: buttonSize)
            .background(isSelected ? Color.blue : Color(UIColor.tertiarySystemBackground).opacity(0.72))
            .foregroundColor(isSelected ? .white : .primary)
            .clipShape(RoundedRectangle(cornerRadius: buttonCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .hoverEffect(.lift)
        .accessibilityValue(isSelected ? "Ausgewählt" : "")
    }

    // MARK: - Verlauf & mehr Optionen

    private var historyControls: some View {
        HStack(spacing: 6) {
            squareButton(
                systemName: "arrow.uturn.backward",
                accessibilityLabel: "Rückgängig",
                action: onUndo
            )
            squareButton(
                systemName: "arrow.uturn.forward",
                accessibilityLabel: "Wiederholen",
                action: onRedo
            )
        }
    }

    private var moreOptionsButton: some View {
        Menu {
            Button(role: .destructive) {
                showClearConfirmation = true
            } label: {
                Label("Seite leeren", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
                .frame(width: buttonSize, height: buttonSize)
                .background(Color(UIColor.tertiarySystemBackground).opacity(0.72))
                .clipShape(RoundedRectangle(cornerRadius: buttonCornerRadius, style: .continuous))
        }
        .hoverEffect(.lift)
        .accessibilityLabel("Mehr Optionen")
        .confirmationDialog(
            "Seite wirklich leeren?",
            isPresented: $showClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Seite leeren", role: .destructive) {
                Haptics.warning()
                onClear()
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Alle Zeichnungen und Textfelder auf dieser Seite werden entfernt.")
        }
    }

    private var toolbarDivider: some View {
        Divider().frame(height: 26)
    }

    private func squareButton(
        systemName: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .medium))
                .frame(width: buttonSize, height: buttonSize)
                .background(Color(UIColor.tertiarySystemBackground).opacity(0.72))
                .clipShape(RoundedRectangle(cornerRadius: buttonCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .hoverEffect(.lift)
        .accessibilityLabel(accessibilityLabel)
    }
}

/// Großer, gut greifbarer Dicken-Regler, der sich UNTER dem Dicken-Knopf
/// öffnet. Die Kreis-Vorschau hat exakt denselben Durchmesser in Punkten wie
/// der später gezeichnete Strich (1 pt auf dem Schieberegler = 1 pt auf dem
/// Display), nur gegen die Rahmengröße der Vorschaufläche geklemmt.
private struct ThicknessSliderPanel: View {
    @Binding var width: CGFloat
    let range: ClosedRange<CGFloat>
    let previewColor: Color
    let title: String

    /// Exakte Vorschau: 1:1 Punkte, lediglich nach oben durch die 76pt-Fläche
    /// und nach unten durch die Lesbarkeit begrenzt.
    private var previewDiameter: CGFloat {
        max(3, min(72, width))
    }

    var body: some View {
        VStack(spacing: 18) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)

            ZStack {
                Circle()
                    .fill(Color(UIColor.tertiarySystemFill))
                    .frame(width: 76, height: 76)
                Circle()
                    .fill(previewColor)
                    .frame(width: previewDiameter, height: previewDiameter)
            }
            .frame(height: 80)
            .animation(.interactiveSpring(response: 0.15, dampingFraction: 0.8), value: width)

            Slider(value: $width, in: range, step: 0.5)
                .frame(width: 260)

            Text(String(format: "%.1f pt", width))
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(UIColor.secondarySystemBackground))
        )
        .fixedSize()
    }
}
