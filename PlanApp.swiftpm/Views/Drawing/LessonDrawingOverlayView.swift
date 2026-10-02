import SwiftUI
import UIKit
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
/// grey note. Drawing is Apple-Pencil-only; two fingers move the note, the round handle
/// below resizes it. Zooming is intentionally not supported.
public struct LessonDrawingOverlayView: View {
    @EnvironmentObject private var viewModel: TimetableViewModel
    @Environment(\.colorScheme) private var colorScheme

    public let lesson: Lesson
    public let noteNamespace: Namespace.ID

    @State private var drawing = PKDrawing()
    @State private var canvasHeight: CGFloat = 460
    @State private var toolSelection: DrawingToolSelection = .pen(color: UIColor(hex: "#1E1E1E"))
    @State private var penWidth: CGFloat = 3.5
    @State private var markerWidth: CGFloat = 16
    @State private var eraserWidth: CGFloat = 24
    @State private var canvasView: PKCanvasView?
    @State private var noteBackgroundStyle: NoteBackgroundStyle = .blank
    @State private var isConvertingHandwriting = false
    @State private var recognitionAlertMessage: String? = nil
    @State private var exportAlertTitle: String = "Export"
    @State private var exportAlertMessage: String? = nil

    // Teilen (Menü „Mehr Optionen")
    @State private var shareImageItem: ShareImageItem? = nil
    /// Kurze Bestätigung, z. B. nach dem Kopieren in die Zwischenablage.
    @State private var toastMessage: String? = nil

    // Textfelder (Text-Werkzeug)
    @State private var textBoxes: [NoteTextBox] = []
    @State private var selectedTextBoxID: UUID? = nil
    /// Feld, das gerade wirklich bearbeitet wird (Tastatur offen). Im Gegensatz
    /// zur reinen Auswahl (Verschiebe-Modus) sind hier Lösch-Kreuz und
    /// Seiten-Griffe ausgeblendet.
    @State private var editingTextBoxID: UUID? = nil

    // Undo/Redo für Textfelder (kombiniert mit dem Canvas-Undo der Zeichnung).
    @StateObject private var textUndo = TextFieldUndoController()
    /// Zeitstempel der letzten Strich-Mutation im Canvas – entscheidet bei
    /// kombiniertem Undo, welcher der beiden Stacks zuerst dran ist.
    @State private var lastStrokeMutation: Date = .distantPast

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
                configureTextUndo()
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
                    // Werkzeugwechsel: Auswahl und Bearbeitung beenden; leere
                    // Felder verschwinden dabei sofort.
                    selectedTextBoxID = nil
                    editingTextBoxID = nil
                    textBoxes = textBoxes.filter {
                        !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    }
                }
            }
            .overlay(alignment: .bottom) {
                if let toastMessage {
                    Text(toastMessage)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(
                            Capsule().fill(Color.black.opacity(0.78))
                        )
                        .padding(.bottom, 40)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                        .allowsHitTesting(false)
                }
            }
            .sheet(item: $shareImageItem) { item in
                ShareSheet(activityItems: [item.image])
            }
            .alert("Handschrift umwandeln", isPresented: Binding(
                get: { recognitionAlertMessage != nil },
                set: { isPresented in
                    if !isPresented { recognitionAlertMessage = nil }
                }
            )) {
                Button("OK", role: .cancel) {
                    recognitionAlertMessage = nil
                }
            } message: {
                Text(recognitionAlertMessage ?? "")
            }
            .alert(exportAlertTitle, isPresented: Binding(
                get: { exportAlertMessage != nil },
                set: { isPresented in
                    if !isPresented { exportAlertMessage = nil }
                }
            )) {
                Button("OK", role: .cancel) {
                    exportAlertMessage = nil
                }
            } message: {
                Text(exportAlertMessage ?? "")
            }
        }
        // App-eigene Tastatur für das Text-Werkzeug: Sie erscheint unten auf
        // der Zeichenfläche, wenn iPadOS keine Systemtastatur einblendet.
        // Ohne Tipp-Überwachung, damit die PencilKit-Eingabe völlig unberührt
        // bleibt – das Textfeld meldet sich hier ausdrücklich selbst an.
        .appKeyboardHost(monitorsTaps: false)
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
                DrawingCanvasBackgroundView(style: noteBackgroundStyle)
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
                    },
                    onStrokeMutation: {
                        lastStrokeMutation = Date()
                    },
                    onRequestUndo: {
                        performUndo()
                    }
                )
                .frame(
                    width: paperWidth,
                    height: max(180, canvasHeight - headerHeight)
                )
                .offset(y: headerHeight)
                .opacity(showsEditor ? 1 : 0)
                .allowsHitTesting(showsEditor && !isTextToolActive)

                // Frei bewegliche Textfelder über der Zeichenfläche.
                NoteTextBoxesLayer(
                    textBoxes: $textBoxes,
                    selectedID: $selectedTextBoxID,
                    editingID: $editingTextBoxID,
                    isTextToolActive: isTextToolActive,
                    areaSize: CGSize(
                        width: paperWidth,
                        height: max(180, canvasHeight - headerHeight)
                    ),
                    registerUndo: { before, after in
                        textUndo.push(before: before, after: after)
                    }
                )
                .frame(
                    width: paperWidth,
                    height: max(180, canvasHeight - headerHeight),
                    alignment: .topLeading
                )
                .offset(y: headerHeight)
                .opacity(showsEditor ? 1 : 0)
                .allowsHitTesting(showsEditor && (isTextToolActive || selectedTextBoxID != nil || editingTextBoxID != nil))

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
        NoteHeaderContent(
            lesson: lesson,
            display: display,
            displaySettings: viewModel.displaySettings,
            periods: viewModel.periods,
            primaryColor: Color.black,
            teacherDisplayName: viewModel.resolveTeacherName(lesson.teacherRaw),
            originalTeacherDisplayName: lesson.originalTeacher.map { viewModel.resolveTeacherName($0) }
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
        HStack {
            Spacer(minLength: 0)
            DrawingToolbarView(
                toolSelection: $toolSelection,
                penWidth: $penWidth,
                markerWidth: $markerWidth,
                eraserWidth: $eraserWidth,
                penColorSlots: Binding(
                    get: { viewModel.drawingSettings.penColorSlots },
                    set: { newSlots in
                        viewModel.drawingSettings.penColorSlots = newSlots
                        viewModel.saveDrawingSettings()
                    }
                ),
                markerColorSlots: Binding(
                    get: { viewModel.drawingSettings.markerColorSlots },
                    set: { newSlots in
                        viewModel.drawingSettings.markerColorSlots = newSlots
                        viewModel.saveDrawingSettings()
                    }
                ),
                backgroundStyle: $noteBackgroundStyle,
                previewScale: max(0.01, scale),
                selectedTextColorHex: activeTextBoxColorHex,
                onApplyColorToSelectedText: { hex in
                    applyColorToSelectedTextBox(hex)
                },
                isConvertingHandwriting: isConvertingHandwriting,
                onConvertHandwriting: { convertHandwritingToEditableText() },
                onShareAsImage: { shareNoteAsImage() },
                onCopyTextToClipboard: { copyNoteTextToClipboard() },
                onUndo: { performUndo() },
                onRedo: { performRedo() },
                onClear: { clearPage() }
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

    // MARK: - Kombiniertes Undo/Redo (Zeichnung + Textfelder)

    private func configureTextUndo() {
        textUndo.getter = { textBoxes }
        textUndo.drawingSetter = { data in
            let restoredDrawing = (try? PKDrawing(data: data)) ?? PKDrawing()
            drawing = restoredDrawing
            canvasView?.drawing = restoredDrawing
            // Der Canvas-eigene Undo-Stack passt nach einem von außen
            // gesetzten Zeichnungs-Zustand nicht mehr zur Realität.
            canvasView?.undoManager?.removeAllActions()
            lastStrokeMutation = .distantPast
        }
        textUndo.setter = { restored in
            textBoxes = restored
            if let sel = selectedTextBoxID, !restored.contains(where: { $0.id == sel }) {
                selectedTextBoxID = nil
            }
            if let edit = editingTextBoxID, !restored.contains(where: { $0.id == edit }) {
                editingTextBoxID = nil
            }
        }
    }

    private func performUndo() {
        let canvasUndoManager = canvasView?.undoManager
        let canvasCanUndo = canvasUndoManager?.canUndo ?? false
        let textCanUndo = textUndo.canUndo

        if textCanUndo && (!canvasCanUndo || textUndo.lastChangeDate > lastStrokeMutation) {
            Haptics.tap()
            textUndo.undo()
        } else if canvasCanUndo {
            Haptics.tap()
            canvasUndoManager?.undo()
        } else if textCanUndo {
            Haptics.tap()
            textUndo.undo()
        }
    }

    private func performRedo() {
        let canvasUndoManager = canvasView?.undoManager
        let canvasCanRedo = canvasUndoManager?.canRedo ?? false
        let textCanRedo = textUndo.canRedo

        if textCanRedo && (!canvasCanRedo || textUndo.lastChangeDate > lastStrokeMutation) {
            Haptics.tap()
            textUndo.redo()
        } else if canvasCanRedo {
            Haptics.tap()
            canvasUndoManager?.redo()
        } else if textCanRedo {
            Haptics.tap()
            textUndo.redo()
        }
    }

    private func clearPage() {
        let beforeBoxes = textBoxes
        let beforeDrawing = (canvasView?.drawing ?? drawing).dataRepresentation()

        selectedTextBoxID = nil
        editingTextBoxID = nil
        textBoxes = []

        let emptyDrawing = PKDrawing()
        drawing = emptyDrawing
        canvasView?.drawing = emptyDrawing
        canvasView?.undoManager?.removeAllActions()
        lastStrokeMutation = .distantPast

        // Ein einziger Undo-Schritt holt Textfelder UND Striche zurück.
        textUndo.push(
            before: NoteUndoSnapshot(textBoxes: beforeBoxes, drawingData: beforeDrawing),
            after: NoteUndoSnapshot(textBoxes: [], drawingData: emptyDrawing.dataRepresentation())
        )
    }

    // MARK: - Textfarbe des ausgewählten Feldes

    /// Das Feld, auf das sich die Farb-Slots der Werkzeugleiste gerade
    /// beziehen: entweder das bearbeitete oder das ausgewählte Textfeld.
    private var activeTextBoxID: UUID? {
        editingTextBoxID ?? selectedTextBoxID
    }

    private var activeTextBoxColorHex: String? {
        guard let id = activeTextBoxID else { return nil }
        return textBoxes.first(where: { $0.id == id })?.colorHex
    }

    /// Wendet eine in der Werkzeugleiste angetippte Farbe auf das aktuell
    /// ausgewählte Textfeld an (statt das Zeichenwerkzeug zu wechseln).
    private func applyColorToSelectedTextBox(_ hex: String) {
        guard let id = activeTextBoxID,
              let index = textBoxes.firstIndex(where: { $0.id == id }) else { return }

        let normalized = UIColor(hex: hex).toHex().uppercased()
        guard textBoxes[index].colorHex.caseInsensitiveCompare(normalized) != .orderedSame else {
            return
        }

        let before = textBoxes
        textBoxes[index].colorHex = normalized
        Haptics.select()
        textUndo.push(before: before, after: textBoxes)
    }

    // MARK: - Teilen

    /// Rendert die Notiz (Hintergrund, Striche und Textfelder) und öffnet den
    /// System-Teilen-Dialog.
    private func shareNoteAsImage() {
        selectedTextBoxID = nil
        editingTextBoxID = nil

        let currentDrawing = canvasView?.drawing ?? drawing
        let canvasRect = CGRect(origin: .zero, size: recognitionCanvasSize)
        let visibleBoxes = textBoxes.filter {
            !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        guard !currentDrawing.strokes.isEmpty || !visibleBoxes.isEmpty,
              let image = PencilKitCanvasRepresentable.renderNotePreview(
                drawing: currentDrawing.cropped(to: canvasRect),
                textBoxes: visibleBoxes,
                backgroundStyle: noteBackgroundStyle,
                clipRect: canvasRect
              ) else {
            Haptics.warning()
            showToast("Diese Notiz ist noch leer.")
            return
        }

        Haptics.tap()
        shareImageItem = ShareImageItem(image: image)
    }

    /// Kopiert den gesamten ermittelbaren Text in die Zwischenablage.
    ///
    /// Dabei werden zuerst alle vorhandenen editierbaren Textfelder gesammelt.
    /// Wenn noch Pencil-Striche vorhanden sind, läuft zusätzlich eine
    /// Texterkennung über die Zeichnung. Nach Erfolg zeigt ein Dialog den
    /// tatsächlich kopierten Text an.
    private func copyNoteTextToClipboard() {
        guard !isConvertingHandwriting else { return }

        selectedTextBoxID = nil
        editingTextBoxID = nil

        let existingBoxes = copyableTextBoxes(from: textBoxes)
        let currentDrawing = canvasView?.drawing ?? drawing

        guard !currentDrawing.strokes.isEmpty else {
            finishTextExport(
                existingBoxes: existingBoxes,
                recognizedBoxes: [],
                handwritingAttempted: false,
                recognitionFailed: false
            )
            return
        }

        let canvasSize = recognitionCanvasSize
        guard canvasSize.width > 0, canvasSize.height > 0,
              let renderedImage = PencilKitCanvasRepresentable.renderDrawingForRecognition(
                drawing: currentDrawing,
                canvasSize: canvasSize
              ),
              let cgImage = renderedImage.cgImage else {
            finishTextExport(
                existingBoxes: existingBoxes,
                recognizedBoxes: [],
                handwritingAttempted: true,
                recognitionFailed: true
            )
            return
        }

        isConvertingHandwriting = true
        showToast("Text wird erkannt …")

        HandwritingRecognizer.recognizeTextBoxes(
            in: cgImage,
            canvasSize: canvasSize
        ) { result in
            isConvertingHandwriting = false

            switch result {
            case .failure:
                finishTextExport(
                    existingBoxes: existingBoxes,
                    recognizedBoxes: [],
                    handwritingAttempted: true,
                    recognitionFailed: true
                )

            case .success(let recognizedBoxes):
                finishTextExport(
                    existingBoxes: existingBoxes,
                    recognizedBoxes: copyableTextBoxes(from: recognizedBoxes),
                    handwritingAttempted: true,
                    recognitionFailed: false
                )
            }
        }
    }

    private func copyableTextBoxes(from boxes: [NoteTextBox]) -> [NoteTextBox] {
        boxes.filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private func sortedTextBoxesForReading(_ boxes: [NoteTextBox]) -> [NoteTextBox] {
        boxes.sorted { lhs, rhs in
            // Zeilenweise lesen: erst grob nach Höhe, dann von links nach rechts.
            if abs(lhs.y - rhs.y) > 12 { return lhs.y < rhs.y }
            return lhs.x < rhs.x
        }
    }

    private func finishTextExport(
        existingBoxes: [NoteTextBox],
        recognizedBoxes: [NoteTextBox],
        handwritingAttempted: Bool,
        recognitionFailed: Bool
    ) {
        let allBoxes = sortedTextBoxesForReading(existingBoxes + recognizedBoxes)
        let joined = allBoxes
            .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")

        guard !joined.isEmpty else {
            Haptics.warning()
            if recognitionFailed {
                showExportAlert(
                    title: "Text-Export fehlgeschlagen",
                    message: "Die Handschrift konnte nicht erkannt werden und es gibt keine Textfelder zum Kopieren."
                )
            } else if handwritingAttempted {
                showExportAlert(
                    title: "Kein Text erkannt",
                    message: "Die Texterkennung ist durchgelaufen, konnte aber keine gut lesbare Handschrift finden."
                )
            } else {
                showExportAlert(
                    title: "Kein Text vorhanden",
                    message: "Es gibt keine Textfelder oder erkannte Handschrift zum Kopieren."
                )
            }
            showToast("Kein Text zum Kopieren.")
            return
        }

        UIPasteboard.general.string = joined
        Haptics.success()
        showToast("Text kopiert.")

        let status: String
        if recognitionFailed {
            status = "Texterkennung fehlgeschlagen. Die vorhandenen Textfelder wurden trotzdem kopiert."
        } else if handwritingAttempted {
            if recognizedBoxes.isEmpty {
                status = "Texterkennung abgeschlossen: Es wurde keine zusätzliche Handschrift erkannt. Vorhandene Textfelder wurden kopiert."
            } else {
                status = "Texterkennung erfolgreich: \(recognizedBoxes.count) erkannte Textzeile(n) wurden zusammen mit vorhandenen Textfeldern kopiert."
            }
        } else {
            status = "Alle vorhandenen Textfelder wurden kopiert."
        }

        showExportAlert(
            title: "Text kopiert",
            message: "\(status)\n\nKopierter Text:\n\n\(joined)"
        )
    }

    private func showExportAlert(title: String, message: String) {
        exportAlertTitle = title
        exportAlertMessage = message
    }

    /// Blendet eine kurze Bestätigung ein, die von selbst wieder verschwindet.
    private func showToast(_ message: String) {
        withAnimation(.easeOut(duration: 0.2)) {
            toastMessage = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeIn(duration: 0.25)) {
                if toastMessage == message { toastMessage = nil }
            }
        }
    }

    // MARK: - Handschrift in Text

    private func convertHandwritingToEditableText() {
        guard !isConvertingHandwriting else { return }

        let currentDrawing = canvasView?.drawing ?? drawing
        guard !currentDrawing.strokes.isEmpty else {
            Haptics.warning()
            recognitionAlertMessage = "Es wurde keine Handschrift gefunden, die umgewandelt werden kann."
            return
        }

        let canvasSize = recognitionCanvasSize
        guard canvasSize.width > 0, canvasSize.height > 0,
              let renderedImage = PencilKitCanvasRepresentable.renderDrawingForRecognition(
                drawing: currentDrawing,
                canvasSize: canvasSize
              ),
              let cgImage = renderedImage.cgImage else {
            Haptics.warning()
            recognitionAlertMessage = "Die Zeichnung konnte nicht für die Texterkennung vorbereitet werden."
            return
        }

        isConvertingHandwriting = true

        // Die komplette Vision-Arbeit liegt in `HandwritingRecognizer`. Dort
        // laufen Bildanalyse und Fehlerbehandlung vollständig gekapselt ab und
        // das Ergebnis kommt garantiert auf dem Main-Thread zurück.
        HandwritingRecognizer.recognizeTextBoxes(
            in: cgImage,
            canvasSize: canvasSize
        ) { result in
            isConvertingHandwriting = false

            switch result {
            case .failure:
                Haptics.warning()
                recognitionAlertMessage = "Die Handschrift konnte nicht umgewandelt werden. Bitte versuche es noch einmal."

            case .success(let recognizedBoxes):
                guard !recognizedBoxes.isEmpty else {
                    Haptics.warning()
                    recognitionAlertMessage = "Es konnte keine gut lesbare Handschrift erkannt werden."
                    return
                }

                applyRecognizedTextBoxes(recognizedBoxes)
            }
        }
    }

    /// Ersetzt die erkannten Striche durch bearbeitbare Textfelder.
    private func applyRecognizedTextBoxes(_ recognizedBoxes: [NoteTextBox]) {
        // Erst die Auswahl auflösen: So hängt kein Textfeld-Zustand mehr an
        // Elementen, die gleich ersetzt werden.
        selectedTextBoxID = nil
        editingTextBoxID = nil

        let beforeBoxes = textBoxes
        let beforeDrawing = (canvasView?.drawing ?? drawing).dataRepresentation()

        textBoxes.append(contentsOf: recognizedBoxes)

        let emptyDrawing = PKDrawing()
        drawing = emptyDrawing
        canvasView?.drawing = emptyDrawing
        // Die Striche wurden nicht über den Canvas-Undo-Stack entfernt,
        // sondern ersetzt. Der alte Stack würde sonst gegen den kombinierten
        // Schritt unten arbeiten.
        canvasView?.undoManager?.removeAllActions()
        lastStrokeMutation = .distantPast

        // Ein einziger Rückgängig-Schritt macht die komplette Umwandlung
        // rückgängig: Die erzeugten Textfelder verschwinden und die
        // ursprüngliche Handschrift kommt zurück.
        textUndo.push(
            before: NoteUndoSnapshot(textBoxes: beforeBoxes, drawingData: beforeDrawing),
            after: NoteUndoSnapshot(textBoxes: textBoxes, drawingData: emptyDrawing.dataRepresentation())
        )

        toolSelection = .text
        Haptics.success()
        showToast("Handschrift umgewandelt: \(recognizedBoxes.count) Textfeld(er).")
    }

    /// Größe der Zeichenfläche in Punkten – Basis für die Rückrechnung der
    /// von Vision gelieferten, normalisierten Koordinaten.
    private var recognitionCanvasSize: CGSize {
        CGSize(
            width: paperWidth,
            height: max(180, canvasHeight - headerHeight)
        )
    }

    // MARK: - Persistence and transition

    /// Übernimmt Standard-Dicken, Standard-Größe und startet immer mit dem
    /// Stift und der ersten Farbe aus den Stift-Farb-Slots.
    private func applyDrawingDefaults() {
        let settings = viewModel.drawingSettings

        penWidth = CGFloat(settings.penWidth)
        markerWidth = CGFloat(settings.markerWidth)
        eraserWidth = CGFloat(settings.eraserWidth)

        // Immer standardmäßig Stift mit der ersten Farbe aus dem Slot
        let initialHex = settings.penColorSlots.first ?? "#1E1E1E"
        toolSelection = .pen(color: UIColor(hex: initialHex))
        noteBackgroundStyle = settings.defaultBackgroundStyle

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
        noteBackgroundStyle = note.backgroundStyle

        let canvasSize = CGSize(
            width: paperWidth,
            height: max(180, canvasHeight - headerHeight)
        )
        // Alte oder hand-edited Speicherstände können doppelte IDs
        // enthalten. SwiftUI würde solche Elemente in einer ForEach als
        // dasselbe View-Element behandeln und beim ersten Text-Tap instabil
        // werden lassen. Beim Laden wird deshalb genau eine sichere Box je
        // UUID übernommen.
        var loadedIDs = Set<UUID>()
        textBoxes = note.textBoxes.compactMap { box in
            guard loadedIDs.insert(box.id).inserted else { return nil }
            return box.sanitized(in: canvasSize)
        }

        if let savedDrawing = try? PKDrawing(data: note.drawingData) {
            drawing = savedDrawing
        }
    }

    private func saveAndDismiss() {
        guard viewModel.isDrawingOverlayPresented else { return }

        // Erst die Bearbeitung beenden: Dadurch gibt das UIKit-Textfeld den
        // First Responder ab und verwirft eine evtl. offene Fokus-Anfrage,
        // bevor die Overlay-Hierarchie abgebaut wird. Sonst könnte nach dem
        // Schließen noch eine Tastatur aufspringen.
        selectedTextBoxID = nil
        editingTextBoxID = nil

        let currentDrawing = canvasView?.drawing ?? drawing
        let fallbackCanvasSize = CGSize(
            width: paperWidth,
            height: max(180, canvasHeight - headerHeight)
        )
        let rawCanvasSize = canvasView?.bounds.size ?? fallbackCanvasSize
        let canvasSize = rawCanvasSize.width > 0 && rawCanvasSize.height > 0
            ? rawCanvasSize
            : fallbackCanvasSize
        let canvasRect = CGRect(origin: .zero, size: canvasSize)
        let croppedDrawing = currentDrawing.cropped(to: canvasRect)

        let cleanedTextBoxes = textBoxes.compactMap { box -> NoteTextBox? in
            guard !box.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return box.sanitized(in: canvasRect.size)
        }
        let croppedImage = PencilKitCanvasRepresentable.renderNotePreview(
            drawing: croppedDrawing,
            textBoxes: cleanedTextBoxes,
            backgroundStyle: noteBackgroundStyle,
            clipRect: canvasRect
        )
        let drawingData = croppedDrawing.dataRepresentation()
        let calculatedLines = max(3, min(10, Int((canvasHeight - headerHeight) / 56)))

        withAnimation(.easeOut(duration: 0.12)) {
            showsEditor = false
        }
        withAnimation(.spring(response: 0.40, dampingFraction: 0.88)) {
            isExpanded = false
            heroBlend = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
            // `saveNote` persists the note and closes the overlay itself.
            // Do not call a second, non-existent close method here: with an
            // `@EnvironmentObject` that produces misleading Binding/dynamic
            // member diagnostics and prevents the package from building.
            viewModel.saveNote(
                for: lesson,
                drawingData: drawingData,
                croppedImageData: croppedImage?.pngData(),
                lineCount: calculatedLines,
                textBoxes: cleanedTextBoxes,
                backgroundStyle: noteBackgroundStyle
            )
        }
    }
}
