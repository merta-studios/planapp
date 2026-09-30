import SwiftUI
import PencilKit

private struct DrawingViewport {
    let size: CGSize
    let safeAreaInsets: EdgeInsets

    private let margin: CGFloat = 14

    var bounds: CGRect {
        CGRect(
            x: safeAreaInsets.leading + margin,
            y: safeAreaInsets.top + margin,
            width: max(1, size.width - safeAreaInsets.leading - safeAreaInsets.trailing - (margin * 2)),
            height: max(1, size.height - safeAreaInsets.top - safeAreaInsets.bottom - (margin * 2))
        )
    }

    /// The visual transition deliberately ends at the center of the screen,
    /// not at the position of the tapped timetable cell.
    var screenCenter: CGPoint {
        CGPoint(x: size.width / 2, y: size.height / 2)
    }
}

/// Full-screen editor which expands the selected lesson card into a centered,
/// grey note. Apple Pencil draws; fingers move the note, the round handle
/// below resizes it. Zooming is intentionally not supported.
public struct LessonDrawingOverlayView: View {
    @EnvironmentObject private var viewModel: TimetableViewModel
    @Environment(\.colorScheme) private var colorScheme

    public let lesson: Lesson
    public let noteNamespace: Namespace.ID

    @State private var drawing = PKDrawing()
    @State private var canvasHeight: CGFloat = 460
    @State private var toolSelection: DrawingToolSelection = .pen(color: .black)
    @State private var penWidth: CGFloat = 3.5
    @State private var markerWidth: CGFloat = 16
    @State private var eraserWidth: CGFloat = 24
    @State private var canvasView: PKCanvasView?

    // Textfelder (Text-Werkzeug)
    @State private var textBoxes: [NoteTextBox] = []
    @State private var selectedTextBoxID: UUID? = nil

    // Live transform state. Updates come incrementally from the UIKit canvas so
    // there is no jump when the fingers are released.
    @State private var scale: CGFloat = 1
    @State private var offset: CGSize = .zero

    // Hero (zoom-in / zoom-out) transition state. The note visibly grows out
    // of the tapped lesson card and shrinks back into it on close, instead of
    // just cross-fading in place.
    @State private var heroSourceFrame: CGRect = .zero
    @State private var heroBlend: CGFloat = 0

    // Header drag state.
    @State private var isMovingFromHeader = false
    @State private var headerDragStartOffset: CGSize = .zero

    // Resize state. Keeping the top edge in screen coordinates makes the round
    // handle follow the finger while only the lower edge changes.
    @State private var isResizing = false
    @State private var resizeStartHeight: CGFloat = 460
    @State private var resizeTopY: CGFloat = 0

    // Staged transition: card first moves/grows and turns grey, editor controls
    // become visible only afterwards.
    @State private var isExpanded = false
    @State private var showsEditor = false
    @State private var didInitialize = false

    private let paperWidth: CGFloat = 640
    private let headerHeight: CGFloat = 64
    private let handleSpacing: CGFloat = 8
    private let handleSize: CGFloat = 36
    private let minimumCanvasHeight: CGFloat = 280
    private let maximumCanvasHeight: CGFloat = 656 // ten note rows

    public init(lesson: Lesson, noteNamespace: Namespace.ID) {
        self.lesson = lesson
        self.noteNamespace = noteNamespace
    }

    private var isTextToolActive: Bool {
        if case .text = toolSelection { return true }
        return false
    }

    public var body: some View {
        let display = viewModel.resolveSubjectDisplay(for: lesson)

        GeometryReader { geometry in
            let viewport = DrawingViewport(
                size: geometry.size,
                safeAreaInsets: geometry.safeAreaInsets
            )

            ZStack {
                // A real background layer avoids the note or its UIKit canvas
                // accidentally receiving the close tap.
                Color.black
                    .opacity(isExpanded ? 0.58 : 0)
                    .background(.ultraThinMaterial.opacity(isExpanded ? 1 : 0))
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture(perform: saveAndDismiss)

                editorPanel(
                    display: display,
                    viewport: viewport
                )
                .zIndex(10)

                editorToolbar(viewport: viewport)
                    .opacity(showsEditor ? 1 : 0)
                    .allowsHitTesting(showsEditor)
                    .zIndex(20)
            }
            .onAppear {
                applyDrawingDefaults()
                loadExistingNote()
                heroSourceFrame = viewModel.activeNoteSourceFrame

                // Wait one layout pass so saved height and safe-area dimensions
                // are both present before calculating the initial fit.
                DispatchQueue.main.async {
                    initializeTransform(in: viewport)
                    didInitialize = true

                    // isExpanded fades the card to grey while heroBlend morphs
                    // the panel's size and position from the tapped card to the
                    // centered, fully expanded note in the very same animation.
                    withAnimation(.spring(response: 0.48, dampingFraction: 0.85)) {
                        isExpanded = true
                        heroBlend = 1
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.36) {
                        withAnimation(.easeOut(duration: 0.18)) {
                            showsEditor = true
                        }
                    }
                }
            }
            .onChange(of: geometry.size) { _, _ in
                guard didInitialize else { return }
                normalizeTransform(in: viewport)
            }
            .onChange(of: isTextToolActive) { _, nowActive in
                if !nowActive {
                    selectedTextBoxID = nil
                }
            }
        }
    }

    // MARK: - Editor panel

    private func editorPanel(
        display: SubjectDisplay,
        viewport: DrawingViewport
    ) -> some View {
        VStack(spacing: handleSpacing) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        isExpanded
                            ? Color(UIColor.secondarySystemBackground)
                            : display.color
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(
                                isExpanded
                                    ? Color.white.opacity(0.28)
                                    : display.color.contrastingTextColor.opacity(0.25),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: Color.black.opacity(0.24), radius: 20, x: 0, y: 10)

                // A lightly separated writing surface keeps all Pencil colors
                // readable while the selected lesson itself visibly turns grey.
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(Color(UIColor.systemBackground).opacity(0.76))
                    .frame(
                        width: paperWidth - 16,
                        height: max(180, canvasHeight - headerHeight - 8)
                    )
                    .offset(x: 8, y: headerHeight)
                    .opacity(showsEditor ? 1 : 0)

                PencilKitCanvasRepresentable(
                    drawing: $drawing,
                    toolSelection: toolSelection,
                    penWidth: penWidth,
                    markerWidth: markerWidth,
                    eraserWidth: eraserWidth,
                    colorScheme: colorScheme,
                    onCanvasCreated: { createdCanvas in
                        canvasView = createdCanvas
                    },
                    onFingerPan: { delta in
                        applyFingerPan(delta, in: viewport)
                    }
                )
                .frame(
                    width: paperWidth,
                    height: max(180, canvasHeight - headerHeight)
                )
                .offset(y: headerHeight)
                .opacity(showsEditor ? 1 : 0)
                .allowsHitTesting(showsEditor)

                // Frei bewegliche Textfelder über der Zeichenfläche.
                NoteTextBoxesLayer(
                    textBoxes: $textBoxes,
                    selectedID: $selectedTextBoxID,
                    isTextToolActive: isTextToolActive,
                    areaSize: CGSize(
                        width: paperWidth,
                        height: max(180, canvasHeight - headerHeight)
                    )
                )
                .frame(
                    width: paperWidth,
                    height: max(180, canvasHeight - headerHeight),
                    alignment: .topLeading
                )
                .offset(y: headerHeight)
                .opacity(showsEditor ? 1 : 0)
                .allowsHitTesting(showsEditor)

                noteHeader(
                    display: display,
                    viewport: viewport
                )
            }
            .frame(width: paperWidth, height: canvasHeight)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            resizeHandle(viewport: viewport)
                .opacity(showsEditor ? 1 : 0)
                .allowsHitTesting(showsEditor)
        }
        .frame(width: paperWidth, height: panelHeight, alignment: .top)
        .scaleEffect(
            x: renderScale(in: viewport).width,
            y: renderScale(in: viewport).height,
            anchor: .center
        )
        .position(renderCenter(in: viewport))
    }

    /// Non-uniform scale used while the note morphs from the small lesson
    /// card into its expanded, centered shape (and back on close). Once the
    /// hero transition has settled this simply equals the fixed fitting scale.
    private func renderScale(in viewport: DrawingViewport) -> CGSize {
        let target = CGSize(width: scale, height: scale)
        guard heroBlend < 0.999, heroSourceFrame != .zero, panelHeight > 0 else {
            return target
        }
        let sourceScaleX = heroSourceFrame.width / paperWidth
        let sourceScaleY = heroSourceFrame.height / panelHeight
        let x = sourceScaleX + (target.width - sourceScaleX) * heroBlend
        let y = sourceScaleY + (target.height - sourceScaleY) * heroBlend
        return CGSize(width: max(0.01, x), height: max(0.01, y))
    }

    /// Screen position used while the note morphs from the tapped card's
    /// location to the centered layout (and back on close).
    private func renderCenter(in viewport: DrawingViewport) -> CGPoint {
        let target = CGPoint(
            x: viewport.screenCenter.x + offset.width,
            y: viewport.screenCenter.y + offset.height
        )
        guard heroBlend < 0.999, heroSourceFrame != .zero else { return target }
        let source = CGPoint(x: heroSourceFrame.midX, y: heroSourceFrame.midY)
        return CGPoint(
            x: source.x + (target.x - source.x) * heroBlend,
            y: source.y + (target.y - source.y) * heroBlend
        )
    }

    // MARK: - Kopfzeile der Notiz

    private func noteHeader(
        display: SubjectDisplay,
        viewport: DrawingViewport
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            // Farbiger Kreis mit der Fach-Farbe vor dem Fachnamen.
            Circle()
                .fill(
                    LinearGradient(
                        colors: [display.color, display.gradientEndColor ?? display.color],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    Circle().strokeBorder(Color.primary.opacity(0.18), lineWidth: 1)
                )
                .frame(width: 16, height: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(display.name)
                    .font(.system(size: 18, weight: .semibold, design: .default))
                    .lineLimit(1)

                if hasHeaderDetails {
                    headerDetails
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(lesson.periodNumber). Stunde")
                    .font(.system(size: 13, weight: .semibold, design: .default))
                Text(headerDateText)
                    .font(.system(size: 12, weight: .regular, design: .default))
                    .opacity(0.78)
            }
            .lineLimit(1)
        }
        .foregroundColor(
            isExpanded ? .primary : display.color.contrastingTextColor
        )
        .padding(.horizontal, 20)
        .frame(width: paperWidth, height: headerHeight)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 1, coordinateSpace: .global)
                .onChanged { value in
                    guard showsEditor else { return }
                    if !isMovingFromHeader {
                        isMovingFromHeader = true
                        headerDragStartOffset = offset
                    }
                    let candidate = CGSize(
                        width: headerDragStartOffset.width + value.translation.width,
                        height: headerDragStartOffset.height + value.translation.height
                    )
                    offset = clampedOffset(candidate, scale: scale, height: canvasHeight, in: viewport)
                }
                .onEnded { _ in
                    isMovingFromHeader = false
                    headerDragStartOffset = offset
                }
        )
    }

    /// Zusatz-Infos unter dem Fachnamen – exakt die Elemente, die auch im
    /// Stundenplan-Block aktiviert sind (Lehrer, Raum, Klasse, Uhrzeiten).
    private var hasHeaderDetails: Bool {
        let settings = viewModel.displaySettings
        return (settings.showTeacher && !lesson.teacherRaw.isEmpty)
            || (settings.showRoom && !lesson.roomRaw.isEmpty)
            || (settings.showKlasse && !lesson.klasseRaw.isEmpty)
            || settings.showTimes
    }

    private var headerDetails: some View {
        let settings = viewModel.displaySettings

        return HStack(spacing: 10) {
            if settings.showTeacher && !lesson.teacherRaw.isEmpty {
                HStack(spacing: 3) {
                    Image(systemName: "person")
                        .font(.system(size: 10, weight: .regular, design: .default))
                    if let orig = lesson.originalTeacher, lesson.isSubstitution {
                        Text(orig)
                            .strikethrough(true, color: .red)
                        Text("➔ \(lesson.teacherRaw)")
                    } else {
                        Text(lesson.teacherRaw)
                    }
                }
            }

            if settings.showRoom && !lesson.roomRaw.isEmpty {
                HStack(spacing: 3) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 10, weight: .regular, design: .default))
                    if let orig = lesson.originalRoom, lesson.isSubstitution {
                        Text(orig)
                            .strikethrough(true, color: .red)
                        Text("➔ \(lesson.roomRaw)")
                    } else {
                        Text(lesson.roomRaw)
                    }
                }
            }

            if settings.showKlasse && !lesson.klasseRaw.isEmpty {
                HStack(spacing: 3) {
                    Image(systemName: "person.3")
                        .font(.system(size: 10, weight: .regular, design: .default))
                    Text(lesson.klasseRaw)
                }
            }

            if settings.showTimes,
               let period = viewModel.periods.first(where: { $0.periodNumber == lesson.periodNumber }) {
                HStack(spacing: 3) {
                    Image(systemName: "clock")
                        .font(.system(size: 10, weight: .regular, design: .default))
                    Text("\(period.startTime) – \(period.endTime)")
                }
            }
        }
        .font(.system(size: 12, weight: .regular, design: .default))
        .opacity(0.75)
        .lineLimit(1)
    }

    /// Rechte Kopfzeile: relative Angabe wie "Morgen" oder "Nächste Woche
    /// Montag" plus deutsches Datumsformat (z.B. "01.10.2026").
    private var headerDateText: String {
        guard let date = Date.fromYyyyMMdd(lesson.dateString) else {
            return lesson.dateString
        }
        return "\(date.relativeDayDescription()) • \(date.germanDateString)"
    }

    private func resizeHandle(viewport: DrawingViewport) -> some View {
        Circle()
            .fill(.ultraThinMaterial)
            .frame(width: handleSize, height: handleSize)
            .overlay(
                Image(systemName: "arrow.up.and.down")
                    .font(.system(size: 14, weight: .semibold, design: .default))
                    .foregroundColor(.primary)
            )
            .overlay(
                Circle()
                    .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.18), radius: 4, x: 0, y: 2)
            .contentShape(Circle())
            .hoverEffect(.lift)
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .onChanged { value in
                        guard showsEditor else { return }
                        if !isResizing {
                            isResizing = true
                            resizeStartHeight = canvasHeight
                            resizeTopY = viewport.screenCenter.y
                                + offset.height
                                - (panelHeight * scale / 2)
                        }

                        let requestedHeight = resizeStartHeight + (value.translation.height / max(scale, 0.01))
                        let maximumHeightAtCurrentTop = (
                            (viewport.bounds.maxY - resizeTopY) / max(scale, 0.01)
                        ) - handleExtent
                        let upperLimit = max(
                            canvasHeight,
                            min(maximumCanvasHeight, maximumHeightAtCurrentTop)
                        )
                        let newHeight = max(
                            minimumCanvasHeight,
                            min(upperLimit, requestedHeight)
                        )

                        canvasHeight = newHeight

                        // The center moves down by half of the added height, so
                        // the top edge remains at resizeTopY and the handle stays
                        // directly under the dragging finger.
                        var candidate = offset
                        candidate.height = resizeTopY
                            + (panelHeight(for: newHeight) * scale / 2)
                            - viewport.screenCenter.y
                        offset = clampedOffset(
                            candidate,
                            scale: scale,
                            height: newHeight,
                            in: viewport
                        )
                    }
                    .onEnded { _ in
                        isResizing = false
                        resizeStartHeight = canvasHeight
                    }
            )
    }

    // MARK: - Floating controls

    private func editorToolbar(viewport: DrawingViewport) -> some View {
        // Closing happens by tapping the dimmed edge around the note, so the
        // toolbar only needs to hold the drawing tools.
        HStack {
            Spacer(minLength: 0)
            DrawingToolbarView(
                toolSelection: $toolSelection,
                penWidth: $penWidth,
                markerWidth: $markerWidth,
                eraserWidth: $eraserWidth,
                onUndo: { canvasView?.undoManager?.undo() },
                onRedo: { canvasView?.undoManager?.redo() },
                onClear: {
                    let emptyDrawing = PKDrawing()
                    drawing = emptyDrawing
                    canvasView?.drawing = emptyDrawing
                    textBoxes = []
                    selectedTextBoxID = nil
                }
            )
            Spacer(minLength: 0)
        }
        .padding(.horizontal, max(16, viewport.safeAreaInsets.leading + 12))
        .padding(.top, max(12, viewport.safeAreaInsets.top + 8))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Live pan and constraints

    private var handleExtent: CGFloat {
        handleSpacing + handleSize
    }

    private var panelHeight: CGFloat {
        panelHeight(for: canvasHeight)
    }

    private func panelHeight(for height: CGFloat) -> CGFloat {
        height + handleExtent
    }

    private func maximumScale(for height: CGFloat, in viewport: DrawingViewport) -> CGFloat {
        let widthLimit = viewport.bounds.width / paperWidth
        let heightLimit = viewport.bounds.height / panelHeight(for: height)
        return max(0.2, min(3.0, min(widthLimit, heightLimit)))
    }

    private func initializeTransform(in viewport: DrawingViewport) {
        scale = min(1, maximumScale(for: canvasHeight, in: viewport))
        offset = clampedOffset(.zero, scale: scale, height: canvasHeight, in: viewport)
    }

    /// Ohne Zoom entspricht die Skalierung immer der Einpass-Skalierung.
    private func normalizeTransform(in viewport: DrawingViewport) {
        let normalizedScale = min(1, maximumScale(for: canvasHeight, in: viewport))
        scale = normalizedScale
        offset = clampedOffset(offset, scale: normalizedScale, height: canvasHeight, in: viewport)
    }

    private func clampedOffset(
        _ proposedOffset: CGSize,
        scale: CGFloat,
        height: CGFloat,
        in viewport: DrawingViewport
    ) -> CGSize {
        let halfWidth = paperWidth * scale / 2
        let halfHeight = panelHeight(for: height) * scale / 2

        let minCenterX = viewport.bounds.minX + halfWidth
        let maxCenterX = viewport.bounds.maxX - halfWidth
        let minCenterY = viewport.bounds.minY + halfHeight
        let maxCenterY = viewport.bounds.maxY - halfHeight

        let proposedCenterX = viewport.screenCenter.x + proposedOffset.width
        let proposedCenterY = viewport.screenCenter.y + proposedOffset.height

        let centerX = min(max(proposedCenterX, minCenterX), maxCenterX)
        let centerY = min(max(proposedCenterY, minCenterY), maxCenterY)

        return CGSize(
            width: centerX - viewport.screenCenter.x,
            height: centerY - viewport.screenCenter.y
        )
    }

    private func applyFingerPan(_ delta: CGSize, in viewport: DrawingViewport) {
        guard showsEditor else { return }
        let candidate = CGSize(
            width: offset.width + delta.width,
            height: offset.height + delta.height
        )
        offset = clampedOffset(candidate, scale: scale, height: canvasHeight, in: viewport)
    }

    // MARK: - Persistence and transition

    /// Übernimmt Standard-Werkzeug, Standard-Farbe, Standard-Dicken und die
    /// Standard-Größe der Zeichenfläche aus den Einstellungen.
    private func applyDrawingDefaults() {
        let settings = viewModel.drawingSettings

        penWidth = CGFloat(settings.penWidth)
        markerWidth = CGFloat(settings.markerWidth)
        eraserWidth = CGFloat(settings.eraserWidth)

        switch settings.defaultTool {
        case .pen:
            toolSelection = .pen(color: DrawingPalette.penColor(forHex: settings.defaultPenColorHex).uiColor)
        case .marker:
            toolSelection = .marker(color: DrawingPalette.markerColor(forHex: settings.defaultMarkerColorHex).uiColor)
        case .eraser:
            toolSelection = .eraser
        }

        canvasHeight = min(
            maximumCanvasHeight,
            max(minimumCanvasHeight, CGFloat(settings.defaultCanvasHeight))
        )
        resizeStartHeight = canvasHeight
    }

    private func loadExistingNote() {
        guard let note = viewModel.noteFor(lesson: lesson) else { return }

        canvasHeight = max(
            minimumCanvasHeight,
            min(maximumCanvasHeight, CGFloat(note.lineCount) * 56 + headerHeight + 40)
        )
        resizeStartHeight = canvasHeight
        textBoxes = note.textBoxes

        if let savedDrawing = try? PKDrawing(data: note.drawingData) {
            drawing = savedDrawing
        }
    }

    private func saveAndDismiss() {
        guard viewModel.isDrawingOverlayPresented else { return }

        selectedTextBoxID = nil

        let currentDrawing = canvasView?.drawing ?? drawing
        let cleanedTextBoxes = textBoxes.filter {
            !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        let croppedImage = PencilKitCanvasRepresentable.renderNotePreview(
            drawing: currentDrawing,
            textBoxes: cleanedTextBoxes
        )
        let drawingData = currentDrawing.dataRepresentation()
        let calculatedLines = max(3, min(10, Int((canvasHeight - headerHeight) / 56)))

        withAnimation(.easeOut(duration: 0.12)) {
            showsEditor = false
        }
        // heroBlend shrinks the note back onto the lesson card at the same
        // time as the grey-to-color cross-fade, mirroring the opening
        // animation instead of just fading out in place.
        withAnimation(.spring(response: 0.40, dampingFraction: 0.88)) {
            isExpanded = false
            heroBlend = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
            viewModel.saveNote(
                for: lesson,
                drawingData: drawingData,
                croppedImageData: croppedImage?.pngData(),
                lineCount: calculatedLines,
                textBoxes: cleanedTextBoxes
            )
        }
    }
}
