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
    public var onUndoScrubBegan: (CGPoint, CGPoint, CGFloat?) -> Void = { _, _, _ in }
    public var onUndoScrubChanged: (CGSize, CGPoint) -> Void = { _, _ in }
    public var onUndoScrubEnded: () -> Void = {}
    /// Während des linearen Scrubs verschwindet das feststehende Symbol,
    /// damit der Knopf sichtbar zum Strich rutscht statt zu teleportieren.
    public var hidesUndoGlyph: Bool = false
    /// Ob es etwas rückgängig zu machen gibt. Ohne Schritt ist der Knopf sehr
    /// transparent und nimmt keine Berührung an.
    public let canUndo: Bool
    /// Ob es etwas zu wiederholen gibt (gleiches Verhalten für den
    /// Vorwärts-Knopf).
    public let canRedo: Bool
    /// Verfügbare Breite über der Zeichenfläche. Ist die Leiste breiter,
    /// wird sie dünner und lässt sich seitlich scrollen.
    public var availableWidth: CGFloat = 2_000
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

    /// Werkzeuge, die im gewählten Zustand einen Mini-Hinweis statt einer
    /// Abwahl zeigen. Früher führte der zweite Tipp auf Text/Radierer/Lasso
    /// in eine Sackgasse (z. B. stummer Rückfall zum schwarzen Stift); jetzt
    /// erscheint ein kleines Popover, was das Werkzeug tut.
    @State private var activeToolHint: ToolHint? = nil

    private enum ToolHint: String, Identifiable {
        case text, lasso, eraser

        var id: String { rawValue }

        var systemImage: String {
            switch self {
            case .text: return "textformat"
            case .lasso: return "lasso.badge.record"
            case .eraser: return "eraser"
            }
        }

        var title: String {
            switch self {
            case .text: return "Text"
            case .lasso: return "Lasso"
            case .eraser: return "Radierer"
            }
        }

        var message: String {
            switch self {
            case .text:
                return "Verwalte die Standard-Schriftgröße und Schriftart in den Einstellungen dieser App!"
            case .lasso:
                return "Was suchst du? Mehr gibt es hier nicht einzustellen!"
            case .eraser:
                return "Verwalte automatisches Abwählen des Radierers in den Einstellungen dieser App!"
            }
        }
    }

    private func toolHintBinding(for hint: ToolHint) -> Binding<Bool> {
        Binding(
            get: { activeToolHint == hint },
            set: { newValue in
                if !newValue { activeToolHint = nil }
            }
        )
    }

    private func toggleToolHint(_ hint: ToolHint) {
        Haptics.tap()
        activeToolHint = activeToolHint == hint ? nil : hint
    }

    @ViewBuilder
    private func toolHintPopover(_ hint: ToolHint) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(hint.title, systemImage: hint.systemImage)
                .font(.footnote.weight(.semibold))
            Text(hint.message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)
        }
        .padding(14)
        .frame(
            width: DrawingColorPalettePopover.popoverSize.width,
            height: DrawingColorPalettePopover.popoverSize.height,
            alignment: .leading
        )
    }

    private var isCompactToolbar: Bool {
        InteractionPolicies.usesCompactScrollingToolbar(
            availableWidth: availableWidth,
            contentWidth: InteractionPolicies.estimatedToolbarContentWidth(
                penSlots: penColorSlots.count,
                markerSlots: markerColorSlots.count,
                isPhone: isPhoneLayout
            )
        )
    }

    /// Auf dem iPhone ist die Leiste bewusst noch einmal kleiner, damit
    /// wirklich alle Werkzeuge Platz haben.
    private var buttonSize: CGFloat {
        if isPhoneLayout { return isCompactToolbar ? 28 : 32 }
        return isCompactToolbar ? 32 : 40
    }
    private var buttonCornerRadius: CGFloat {
        DeviceLayout.buttonCornerRadius(isCompactToolbar ? 8 : 10)
    }

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
        canUndo: Bool = true,
        canRedo: Bool = true,
        onUndoScrubBegan: @escaping (CGPoint, CGPoint, CGFloat?) -> Void = { _, _, _ in },
        onUndoScrubChanged: @escaping (CGSize, CGPoint) -> Void = { _, _ in },
        onUndoScrubEnded: @escaping () -> Void = {},
        hidesUndoGlyph: Bool = false,
        availableWidth: CGFloat = 2_000,
        onClear: @escaping () -> Void,
        canCopyNote: Bool = false,
        canPasteNote: Bool = false,
        onCopyNote: @escaping () -> Void = {},
        onPasteNote: @escaping () -> Void = {},
        onAddImage: @escaping (NoteImageSource) -> Void = { _ in }
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
        self.canUndo = canUndo
        self.canRedo = canRedo
        self.onUndoScrubBegan = onUndoScrubBegan
        self.onUndoScrubChanged = onUndoScrubChanged
        self.onUndoScrubEnded = onUndoScrubEnded
        self.hidesUndoGlyph = hidesUndoGlyph
        self.availableWidth = availableWidth
        self.onClear = onClear
        self.canCopyNote = canCopyNote
        self.canPasteNote = canPasteNote
        self.onCopyNote = onCopyNote
        self.onPasteNote = onPasteNote
    }

    public var body: some View {
        let compact = isCompactToolbar
        let corner = compact ? 14.0 : 18.0
        return Group {
            if compact {
                ScrollView(.horizontal, showsIndicators: false) {
                    toolbarControls
                }
                .frame(maxWidth: max(1, availableWidth))
            } else {
                toolbarControls
            }
        }
        .background(
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.3), Color.white.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 2)
        // Passt die Leiste: volle Breite nur als Inhalt. Wird der Bildschirm
        // zu schmal, ist die Leiste oben bereits dünner und scrollt seitlich.
        .fixedSize(horizontal: !compact, vertical: false)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Zeichenwerkzeuge")
    }

    private var toolbarControls: some View {
        HStack(spacing: (isCompactToolbar || isPhoneLayout) ? 6 : 10) {
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
        .padding(.horizontal, isCompactToolbar ? 8 : (isPhoneLayout ? 10 : 12))
        .padding(.vertical, isCompactToolbar ? 4 : 8)
        .fixedSize(horizontal: true, vertical: false)
    }

    // MARK: - Stift-Farben

    private var penControls: some View {
        HStack(spacing: 6) {
            Image(systemName: "pencil.tip")
                .font(.system(size: isPhoneLayout ? 13 : 15))
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
                        // Werkzeugwahl: Rückmeldung auch am Apple Pencil Pro – die
                        // Klick-Haptik allein erreicht den Stift nicht.
                        Haptics.toolSelect()
                        toolSelection = .pen(color: slotColor)
                    }
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: buttonCornerRadius, style: .continuous)
                            .fill(isSelected ? Color.blue.opacity(0.18) : Color.clear)

                        Circle()
                            .fill(swatch)
                            .frame(width: isPhoneLayout ? 19 : 22, height: isPhoneLayout ? 19 : 22)
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
                .font(.system(size: isPhoneLayout ? 13 : 15))
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
                            .frame(width: isPhoneLayout ? 19 : 22, height: isPhoneLayout ? 19 : 22)
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
                            updateTextColorSlot(index, with: newHex)
                            editingPenSlotIndex = nil
                        },
                        onSelectCustomColor: { newHex in
                            updateTextColorSlot(index, with: newHex)
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
                .font(.system(size: isPhoneLayout ? 13 : 15))
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
                        // Werkzeugwahl: Rückmeldung auch am Apple Pencil Pro.
                        Haptics.toolSelect()
                        toolSelection = .marker(color: slotColor)
                    }
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: buttonCornerRadius, style: .continuous)
                            .fill(isSelected ? Color.blue.opacity(0.18) : Color.clear)

                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(swatch)
                            .frame(width: isPhoneLayout ? 18 : 21, height: isPhoneLayout ? 18 : 21)

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

    /// iPhone: Farb-Slot als Textfarbe ändern – ohne das Werkzeug zu wechseln
    /// (Stift gibt es dort nicht).
    private func updateTextColorSlot(_ index: Int, with newHex: String) {
        guard penColorSlots.indices.contains(index) else { return }
        let normalized = normalizedHex(newHex)
        penColorSlots[index] = normalized
        textColorHex = normalized
        if selectedTextColorHex != nil {
            onApplyColorToSelectedText(normalized)
        }
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
            if isSelected {
                // Zweiter Tipp: Mini-Hinweis statt Abwahl / Stift-Rückfall.
                toggleToolHint(.text)
                return
            }
            Haptics.toolSelect()
            activeToolHint = nil
            toolSelection = .text
        } label: {
            // Nur das Aa-Symbol, kein Beschriftungstext.
            Image(systemName: "textformat")
                .font(.system(size: isPhoneLayout ? 15 : 17, weight: .semibold))
                .frame(width: buttonSize, height: buttonSize)
                .background(isSelected ? Color.blue : Color(UIColor.tertiarySystemBackground).opacity(0.72))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: buttonCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .hoverEffect(.lift)
        .popover(isPresented: toolHintBinding(for: .text), arrowEdge: .top) {
            toolHintPopover(.text)
                .presentationCompactAdaptation(.popover)
        }
        .accessibilityLabel("Text-Werkzeug")
        .accessibilityValue(isSelected ? "Ausgewählt" : "")
        .accessibilityHint(isSelected ? "Erneut tippen, um einen Hinweis anzuzeigen" : "")
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
            if isSelected {
                // Zweiter Tipp: Mini-Hinweis statt Abwahl / Stift-Rückfall.
                toggleToolHint(.eraser)
                return
            }
            Haptics.toolSelect()
            activeToolHint = nil
            toolSelection = .eraser
        } label: {
            Image(systemName: "eraser")
                .font(.system(size: isPhoneLayout ? 14 : 16, weight: .medium))
                .frame(width: buttonSize, height: buttonSize)
                .background(isSelected ? Color.blue : Color(UIColor.tertiarySystemBackground).opacity(0.72))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: buttonCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .hoverEffect(.lift)
        .popover(isPresented: toolHintBinding(for: .eraser), arrowEdge: .top) {
            toolHintPopover(.eraser)
                .presentationCompactAdaptation(.popover)
        }
        .accessibilityLabel("Radierer")
        .accessibilityValue(isSelected ? "Ausgewählt" : "")
        .accessibilityHint(isSelected ? "Erneut tippen, um einen Hinweis anzuzeigen" : "")
    }

    private var lassoButton: some View {
        let isSelected: Bool = {
            if case .lasso = toolSelection { return true }
            return false
        }()

        return Button {
            if isSelected {
                // Zweiter Tipp: Mini-Hinweis statt Abwahl / Stift-Rückfall.
                toggleToolHint(.lasso)
                return
            }
            Haptics.toolSelect()
            activeToolHint = nil
            toolSelection = .lasso
        } label: {
            Image(systemName: "lasso")
                .font(.system(size: isPhoneLayout ? 14 : 16, weight: .medium))
                .frame(width: buttonSize, height: buttonSize)
                .background(isSelected ? Color.blue : Color(UIColor.tertiarySystemBackground).opacity(0.72))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: buttonCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .hoverEffect(.lift)
        .popover(isPresented: toolHintBinding(for: .lasso), arrowEdge: .top) {
            toolHintPopover(.lasso)
                .presentationCompactAdaptation(.popover)
        }
        .accessibilityLabel("Lasso-Werkzeug")
        .accessibilityValue(isSelected ? "Ausgewählt" : "")
        .accessibilityHint(isSelected ? "Erneut tippen, um einen Hinweis anzuzeigen" : "")
    }

    // MARK: - Verlauf & mehr Optionen

    private var historyControls: some View {
        HStack(spacing: 6) {
            undoScrubButton
            squareButton(
                systemName: "arrow.uturn.forward",
                accessibilityLabel: "Wiederholen",
                isEnabled: canRedo,
                action: onRedo
            )
        }
    }

    /// Rückgängig: kurzer Tipp macht einen Schritt. Eine Sekunde halten öffnet
    /// den vertikalen Scrubber (auch mit dem Finger).
    ///
    /// Ohne Rückgängig-Schritt ist der Knopf nur noch sehr blass und nimmt
    /// keine Berührung an (der Scrubber gehört zum Knopf). Er bleibt bedienbar,
    /// solange sich Schritte **wiederholen** lassen: Nach oben gezogen holt der
    /// Scrubber sie zurück.
    private var undoScrubButton: some View {
        let isInteractive = canUndo || canRedo
        return ZStack {
            Image(systemName: "arrow.uturn.backward")
                .font(.system(size: (isCompactToolbar || isPhoneLayout) ? 13 : 15, weight: .medium))
                .frame(width: buttonSize, height: buttonSize)
                .background(Color(UIColor.tertiarySystemBackground).opacity(0.72))
                .clipShape(RoundedRectangle(cornerRadius: buttonCornerRadius, style: .continuous))
                .opacity(hidesUndoGlyph ? 0 : (canUndo ? 1 : 0.28))

            UndoScrubHandle(
                allowsFinger: true,
                style: .linear,
                isEnabled: isInteractive,
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
        .hoverEffect(.lift)
        .accessibilityLabel("Rückgängig")
        .accessibilityHint("Halten und ziehen, um mehrere Schritte rückgängig zu machen oder wiederherzustellen")
    }

    private var moreOptionsButton: some View {
        Menu {
            Menu {
                Button {
                    Haptics.tap()
                    onAddImage(.file)
                } label: {
                    Label("Aus Datei", systemImage: "folder")
                }

                Button {
                    Haptics.tap()
                    onAddImage(.photos)
                } label: {
                    Label("Aus Fotos", systemImage: "photo.on.rectangle")
                }

                if NoteImageCameraAvailability.isCameraOffered {
                    Button {
                        Haptics.tap()
                        onAddImage(.camera)
                    } label: {
                        Label("Mit Kamera aufnehmen", systemImage: "camera")
                    }
                }
            } label: {
                Label("Bild hinzufügen", systemImage: "photo.badge.plus")
            }

            Divider()

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
                .font(.system(size: isPhoneLayout ? 14 : 16, weight: .semibold))
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
            Text("Alle Zeichnungen, Textfelder und Bilder auf dieser Seite werden entfernt.")
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
        Divider().frame(height: isCompactToolbar ? 18 : 26)
    }

    private func squareButton(
        systemName: String,
        accessibilityLabel: String,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: isPhoneLayout ? 13 : 15, weight: .medium))
                .frame(width: buttonSize, height: buttonSize)
                .background(Color(UIColor.tertiarySystemBackground).opacity(0.72))
                .clipShape(RoundedRectangle(cornerRadius: buttonCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .hoverEffect(.lift)
        .disabled(!isEnabled)
        // Sehr transparent statt ausgegraut: Der Knopf bleibt sichtbar, ist
        // aber klar nicht verfügbar und nimmt keinen Tipp an.
        .opacity(isEnabled ? 1 : 0.28)
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
