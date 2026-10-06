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
    @Binding public var backgroundStyle: NoteBackgroundStyle
    /// Größe des Hintergrund-Musters (1 = Standard, Mitte des Reglers).
    @Binding public var backgroundScale: Double
    /// Farbe für neue Textfelder (iPhone-Leiste: die Farb-Slots sind dort
    /// Textfarben, weil ohne Apple Pencil nicht gezeichnet wird).
    @Binding public var textColorHex: String

    /// iPhone: nur Lasso, Text, Radierer, Farben (als Textfarben), Verlauf
    /// und „Mehr Optionen“. Stift/Textmarker/Dicke gibt es dort nicht.
    public let isPhoneLayout: Bool
    public let previewScale: CGFloat
    /// Farbe des gerade ausgewählten Textfelds (falls eines ausgewählt ist).
    /// Ist dieser Wert gesetzt, wenden die Farb-Slots die Farbe auf den Text
    /// an, statt das Zeichenwerkzeug zu wechseln.
    public let selectedTextColorHex: String?
    public let onApplyColorToSelectedText: (String) -> Void
    public let isConvertingHandwriting: Bool
    public let onConvertHandwriting: () -> Void
    /// Teilt die aktuelle Notiz als Bild (System-Teilen-Dialog).
    public let onShareAsImage: () -> Void
    /// Kopiert den Text aller Textfelder in die Zwischenablage.
    public let onCopyTextToClipboard: () -> Void
    public let onUndo: () -> Void
    public let onRedo: () -> Void
    public let onClear: () -> Void
    /// Notiz kopieren / einfügen (interne Zwischenablage der App).
    public let canCopyNote: Bool
    public let canPasteNote: Bool
    public let onCopyNote: () -> Void
    public let onPasteNote: () -> Void

    @State private var showThicknessSlider = false
    @State private var showBackgroundScalePanel = false
    @State private var showPasteConfirmation = false
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
        backgroundStyle: Binding<NoteBackgroundStyle>,
        backgroundScale: Binding<Double> = .constant(NoteBackgroundMetrics.defaultScale),
        textColorHex: Binding<String> = .constant(NoteTextBox.defaultColorHex),
        isPhoneLayout: Bool = false,
        previewScale: CGFloat = 1,
        selectedTextColorHex: String? = nil,
        onApplyColorToSelectedText: @escaping (String) -> Void = { _ in },
        isConvertingHandwriting: Bool = false,
        onConvertHandwriting: @escaping () -> Void = {},
        onShareAsImage: @escaping () -> Void = {},
        onCopyTextToClipboard: @escaping () -> Void = {},
        onUndo: @escaping () -> Void,
        onRedo: @escaping () -> Void,
        onClear: @escaping () -> Void,
        canCopyNote: Bool = false,
        canPasteNote: Bool = false,
        onCopyNote: @escaping () -> Void = {},
        onPasteNote: @escaping () -> Void = {}
    ) {
        _toolSelection = toolSelection
        _penWidth = penWidth
        _markerWidth = markerWidth
        _eraserWidth = eraserWidth
        _penColorSlots = penColorSlots
        _markerColorSlots = markerColorSlots
        _backgroundStyle = backgroundStyle
        _backgroundScale = backgroundScale
        _textColorHex = textColorHex
        self.isPhoneLayout = isPhoneLayout
        self.previewScale = previewScale
        self.selectedTextColorHex = selectedTextColorHex
        self.onApplyColorToSelectedText = onApplyColorToSelectedText
        self.isConvertingHandwriting = isConvertingHandwriting
        self.onConvertHandwriting = onConvertHandwriting
        self.onShareAsImage = onShareAsImage
        self.onCopyTextToClipboard = onCopyTextToClipboard
        self.onUndo = onUndo
        self.onRedo = onRedo
        self.onClear = onClear
        self.canCopyNote = canCopyNote
        self.canPasteNote = canPasteNote
        self.onCopyNote = onCopyNote
        self.onPasteNote = onPasteNote
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: isPhoneLayout ? 8 : 10) {
                if isPhoneLayout {
                    lassoButton
                    textToolButton
                    eraserButton
                    toolbarDivider
                    textColorControls
                    toolbarDivider
                    historyControls
                    toolbarDivider
                    moreOptionsButton
                } else {
                    penControls
                    toolbarDivider
                    markerControls
                    toolbarDivider
                    textToolButton
                    eraserButton
                    lassoButton
                    toolbarDivider
                    thicknessButton
                    toolbarDivider
                    historyControls
                    toolbarDivider
                    moreOptionsButton
                }
            }
            .padding(.horizontal, isPhoneLayout ? 10 : 12)
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
        // iPad: Leiste so breit wie ihr Inhalt. iPhone: volle Breite nutzen,
        // damit die Leiste bei Bedarf horizontal scrollt statt abgeschnitten
        // zu werden.
        .fixedSize(horizontal: !isPhoneLayout, vertical: false)
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
                // Nicht mehr über einen lokalen Slot-Index entscheiden:
                // Die Squeeze-Palette ändert `toolSelection` direkt. Eine
                // Ableitung aus dem gemeinsamen Werkzeugzustand hält beide
                // Werkzeugleisten deshalb jederzeit synchron – auch nach
                // Radierer/Lasso/Text oder einer externen Farbänderung.
                let isSelected = isSelectedPenColor(hex)
                // Die Papierfläche bleibt weiß, daher bleibt auch Schwarz im
                // Farbfeld und beim Zeichnen schwarz – unabhängig vom Dark Mode.
                let swatch = Color(hex: hex)

                Button {
                    if selectedTextColorHex != nil {
                        // Textfeld ausgewählt: Farbe auf den Text anwenden,
                        // das Werkzeug bleibt das Text-Werkzeug.
                        onApplyColorToSelectedText(hex)
                    } else if isSelected {
                        Haptics.tap()
                        editingMarkerSlotIndex = nil
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
                            updatePenSlot(index, with: newHex)
                            editingPenSlotIndex = nil
                        },
                        onSelectCustomColor: { newHex in
                            updatePenSlot(index, with: newHex)
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

    // MARK: - Textfarben (iPhone)

    /// Auf dem iPhone wird nicht gezeichnet: Die Farb-Slots des Stifts dienen
    /// dort als Textfarben – für das ausgewählte Textfeld oder für neue Felder.
    private var textColorControls: some View {
        HStack(spacing: 6) {
            Image(systemName: "paintpalette")
                .font(.system(size: 15))
                .foregroundColor(.primary)
                .accessibilityHidden(true)

            ForEach(Array(penColorSlots.enumerated()), id: \.offset) { index, hex in
                let activeHex = selectedTextColorHex ?? textColorHex
                let isSelected = activeHex.caseInsensitiveCompare(hex) == .orderedSame
                let swatch = Color(hex: hex)

                Button {
                    if selectedTextColorHex != nil {
                        onApplyColorToSelectedText(hex)
                        textColorHex = hex
                    } else if isSelected {
                        Haptics.tap()
                        editingMarkerSlotIndex = nil
                        editingPenSlotIndex = index
                    } else {
                        Haptics.select()
                        textColorHex = hex
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
                .accessibilityLabel("Textfarbe \(index + 1)")
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
                            updatePenSlot(index, with: newHex)
                            textColorHex = newHex
                            editingPenSlotIndex = nil
                        },
                        onSelectCustomColor: { newHex in
                            updatePenSlot(index, with: newHex)
                            textColorHex = newHex
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
                // Wie bei den Stift-Slots immer aus dem gemeinsamen
                // `toolSelection` ableiten statt einen zweiten lokalen
                // Auswahlzustand zu pflegen.
                let isSelected = isSelectedMarkerColor(hex)
                let swatch = Color(hex: hex)

                Button {
                    if selectedTextColorHex != nil {
                        onApplyColorToSelectedText(hex)
                    } else if isSelected {
                        Haptics.tap()
                        editingPenSlotIndex = nil
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
                            updateMarkerSlot(index, with: newHex)
                            editingMarkerSlotIndex = nil
                        },
                        onSelectCustomColor: { newHex in
                            updateMarkerSlot(index, with: newHex)
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

    private func updatePenSlot(_ index: Int, with newHex: String) {
        guard penColorSlots.indices.contains(index) else { return }
        let normalized = normalizedHex(newHex)
        penColorSlots[index] = normalized
        toolSelection = .pen(color: UIColor(hex: normalized))
    }

    private func updateMarkerSlot(_ index: Int, with newHex: String) {
        guard markerColorSlots.indices.contains(index) else { return }
        let normalized = normalizedHex(newHex)
        markerColorSlots[index] = normalized
        toolSelection = .marker(color: UIColor(hex: normalized).withAlphaComponent(0.60))
    }

    private func normalizedHex(_ hex: String) -> String {
        UIColor(hex: hex).toHex().uppercased()
    }

    /// Aus genau derselben Quelle wie die Squeeze-Palette ableiten. Die
    /// Alpha-Komponente des Markers ist für die Slot-Zuordnung absichtlich
    /// irrelevant; `toHex()` liefert nur die sichtbare RGB-Farbe.
    private func isSelectedPenColor(_ hex: String) -> Bool {
        if let textHex = selectedTextColorHex {
            return textHex.caseInsensitiveCompare(hex) == .orderedSame
        }
        guard case .pen(let color) = toolSelection else { return false }
        return color.toHex().caseInsensitiveCompare(hex) == .orderedSame
    }

    private func isSelectedMarkerColor(_ hex: String) -> Bool {
        if let textHex = selectedTextColorHex {
            return textHex.caseInsensitiveCompare(hex) == .orderedSame
        }
        guard case .marker(let color) = toolSelection else { return false }
        return color.toHex().caseInsensitiveCompare(hex) == .orderedSame
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
            // Nur das Aa-Symbol, kein Beschriftungstext.
            Image(systemName: "textformat")
                .font(.system(size: 17, weight: .semibold))
                .frame(width: buttonSize, height: buttonSize)
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
                // Sichtbare Vorschau: Sie zeigt die Strichstärke, die PencilKit
                // wirklich zeichnet (siehe `DrawingStrokeMetrics`) – zusätzlich
                // mit der Skalierung der Notizfläche multipliziert.
                Circle()
                    .fill(currentToolPreviewColor)
                    .frame(
                        width: compactPreviewDiameter,
                        height: compactPreviewDiameter
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
                title: currentThicknessTitle,
                previewScale: previewScale,
                toolSelection: toolSelection
            )
            .presentationCompactAdaptation(.popover)
        }
    }

    private var currentWidthBinding: Binding<CGFloat> {
        switch toolSelection {
        case .pen, .text, .lasso:
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

    /// Durchmesser des Punkts im Werkzeugleisten-Knopf. Es gibt absichtlich
    /// keinen zusätzlichen Faktor und keine pauschale Obergrenze: Die Größe
    /// entspricht der eingestellten PencilKit-Breite (inklusive der aktuellen
    /// Darstellungsskalierung der Notizfläche).
    private var compactPreviewDiameter: CGFloat {
        DrawingStrokeMetrics.onScreenWidth(
            for: toolSelection,
            width: currentToolWidth,
            canvasScale: previewScale
        )
    }

    private var currentWidthRange: ClosedRange<CGFloat> {
        switch toolSelection {
        case .pen, .text, .lasso:
            return 1...20
        case .marker:
            return 4...40
        case .eraser:
            return 4...60
        }
    }

    private var currentThicknessTitle: String {
        switch toolSelection {
        case .pen, .text, .lasso:
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
            return Color(uiColor: color)
        case .marker(let color):
            return Color(uiColor: color.withAlphaComponent(1))
        case .eraser:
            return Color(UIColor.systemGray2)
        case .text, .lasso:
            return .primary
        }
    }

    // MARK: - Radierer & Lasso

    private var eraserButton: some View {
        let isSelected: Bool = {
            if case .eraser = toolSelection { return true }
            return false
        }()

        return Button {
            Haptics.select()
            toolSelection = .eraser
        } label: {
            Image(systemName: "eraser")
                .font(.system(size: 16, weight: .medium))
                .frame(width: buttonSize, height: buttonSize)
                .background(isSelected ? Color.blue : Color(UIColor.tertiarySystemBackground).opacity(0.72))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: buttonCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .hoverEffect(.lift)
        .accessibilityLabel("Radierer")
        .accessibilityValue(isSelected ? "Ausgewählt" : "")
    }

    private var lassoButton: some View {
        let isSelected: Bool = {
            if case .lasso = toolSelection { return true }
            return false
        }()

        return Button {
            Haptics.select()
            toolSelection = .lasso
        } label: {
            Image(systemName: "lasso")
                .font(.system(size: 16, weight: .medium))
                .frame(width: buttonSize, height: buttonSize)
                .background(isSelected ? Color.blue : Color(UIColor.tertiarySystemBackground).opacity(0.72))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: buttonCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .hoverEffect(.lift)
        .accessibilityLabel("Lasso-Werkzeug")
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
            Button {
                Haptics.tap()
                onConvertHandwriting()
            } label: {
                Label(
                    isConvertingHandwriting ? "Wird umgewandelt …" : "Handschrift in Text umwandeln",
                    systemImage: "text.viewfinder"
                )
            }
            .disabled(isConvertingHandwriting)

            Menu {
                Button {
                    Haptics.tap()
                    onShareAsImage()
                } label: {
                    Label("Als Bild teilen", systemImage: "photo")
                }

                Button {
                    Haptics.tap()
                    onCopyTextToClipboard()
                } label: {
                    Label(
                        isConvertingHandwriting ? "Text wird erkannt …" : "Als Text kopieren",
                        systemImage: "doc.on.clipboard"
                    )
                }
                .disabled(isConvertingHandwriting)
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }

            Menu {
                ForEach(NoteBackgroundStyle.allCases) { style in
                    Button {
                        Haptics.select()
                        backgroundStyle = style
                    } label: {
                        Label(style.title, systemImage: backgroundStyle == style ? "checkmark" : style.systemImage)
                    }
                }
            } label: {
                Label("Hintergrund", systemImage: "rectangle.on.rectangle")
            }

            Button {
                Haptics.tap()
                showBackgroundScalePanel = true
            } label: {
                Label("Mustergröße …", systemImage: "arrow.up.left.and.arrow.down.right")
            }

            Divider()

            Button {
                Haptics.tap()
                onCopyNote()
            } label: {
                Label("Notiz kopieren", systemImage: "doc.on.doc")
            }
            .disabled(!canCopyNote)

            Button {
                showPasteConfirmation = true
            } label: {
                Label("Notiz einfügen", systemImage: "doc.on.clipboard.fill")
            }
            .disabled(!canPasteNote)

            Divider()

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
        .confirmationDialog(
            "Kopierte Notiz einfügen?",
            isPresented: $showPasteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Einfügen und ersetzen", role: .destructive) {
                Haptics.tap()
                onPasteNote()
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Der aktuelle Inhalt dieser Notiz wird vollständig durch die kopierte Notiz ersetzt.")
        }
        .popover(isPresented: $showBackgroundScalePanel, arrowEdge: .top) {
            BackgroundScalePanel(scale: $backgroundScale, style: backgroundStyle)
                .presentationCompactAdaptation(.popover)
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
/// öffnet.
///
/// Die Vorschau zeigt einen Punkt mit genau dem Durchmesser, der später auf
/// der Zeichenfläche verwendet wird – inklusive Darstellungs-Skalierung der
/// Notiz. Ein Beispielstrich würde die Dicke unnötig wie eine Linie wirken lassen.
private struct ThicknessSliderPanel: View {
    @Binding var width: CGFloat
    let range: ClosedRange<CGFloat>
    let previewColor: Color
    let title: String
    let previewScale: CGFloat
    let toolSelection: DrawingToolSelection

    private let previewLength: CGFloat = 240

    /// Tatsächlich sichtbare Strichstärke in Punkten. Der Regler zeigt einen
    /// Punkt, keinen Beispielstrich, damit der Durchmesser direkt mit der
    /// eingestellten Werkzeugbreite verglichen werden kann.
    private var previewDiameter: CGFloat {
        DrawingStrokeMetrics.onScreenWidth(
            for: toolSelection,
            width: width,
            canvasScale: previewScale
        )
    }

    var body: some View {
        VStack(spacing: 18) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)

            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(UIColor.tertiarySystemFill))
                    .frame(width: previewLength + 20, height: 72)

                Circle()
                    .fill(previewColor)
                    .frame(width: previewDiameter, height: previewDiameter)
            }
            .frame(height: 76)
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

/// Regler für die Größe des Hintergrund-Musters. Die Mitte entspricht der
/// Standardgröße; nach links wird das Muster bis zur Hälfte kleiner, nach
/// rechts bis zum Doppelten größer. Die Vorschau zeigt das Muster live.
struct BackgroundScalePanel: View {
    @Binding var scale: Double
    let style: NoteBackgroundStyle

    private var sliderBinding: Binding<Double> {
        Binding(
            get: { NoteBackgroundMetrics.sliderValue(forScale: scale) },
            set: { scale = NoteBackgroundMetrics.scale(forSliderValue: $0) }
        )
    }

    var body: some View {
        VStack(spacing: 14) {
            Text("Mustergröße")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)

            DrawingCanvasBackgroundView(
                style: style == .blank ? .grid : style,
                scale: scale
            )
            .frame(width: 240, height: 120)
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(Color.gray.opacity(0.25), lineWidth: 1)
            )

            if style == .blank {
                Text("Der Hintergrund ist aktuell leer – die Größe gilt, sobald ein Muster gewählt wird.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(width: 240)
            }

            HStack(spacing: 10) {
                Image(systemName: "minus.magnifyingglass")
                    .foregroundColor(.secondary)
                Slider(value: sliderBinding, in: -1...1)
                    .frame(width: 200)
                Image(systemName: "plus.magnifyingglass")
                    .foregroundColor(.secondary)
            }

            HStack {
                Text(String(format: "%.0f %%", scale * 100))
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.secondary)
                Spacer()
                Button("Zurücksetzen") {
                    Haptics.tap()
                    scale = NoteBackgroundMetrics.defaultScale
                }
                .font(.system(size: 13, weight: .medium))
                .disabled(abs(scale - NoteBackgroundMetrics.defaultScale) < 0.001)
            }
            .frame(width: 240)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(UIColor.secondarySystemBackground))
        )
        .fixedSize()
    }
}
