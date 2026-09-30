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
/// grey note. Apple Pencil draws; one or two fingers move and zoom the note.
public struct LessonDrawingOverlayView: View {
    @EnvironmentObject private var viewModel: TimetableViewModel
    @Environment(\.colorScheme) private var colorScheme

    public let lesson: Lesson
    public let noteNamespace: Namespace.ID

    @State private var drawing = PKDrawing()
    @State private var canvasHeight: CGFloat = 460
    @State private var toolSelection: DrawingToolSelection = .pen(color: .black)
    @State private var penWidth: CGFloat = 3.5
    @State private var canvasView: PKCanvasView?

    // Live transform state. Updates come incrementally from the UIKit canvas so
    // there is no jump when the fingers are released.
    @State private var scale: CGFloat = 1
    @State private var offset: CGSize = .zero

    // Hero (zoom-in / zoom-out) transition state. The note visibly grows out
    // of the tapped lesson card and shrinks back into it on close, instead of
    // just cross-fading in place.
    @State private var heroSourceFrame: CGRect = .zero
    @State private var heroBlend: CGFloat = 0
    // The scale right after opening. Used to keep header text and the resize
    // handle visually constant while the user later pinch-zooms the canvas.
    @State private var baseScale: CGFloat = 1

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
    private let headerHeight: CGFloat = 56
    private let handleSpacing: CGFloat = 8
    private let handleSize: CGFloat = 36
    private let minimumCanvasHeight: CGFloat = 280
    private let maximumCanvasHeight: CGFloat = 656 // ten note rows

    public init(lesson: Lesson, noteNamespace: Namespace.ID) {
        self.lesson = lesson
        self.noteNamespace = noteNamespace
    }

    public var body: some View {
        let (displayName, _, subjectColor) = viewModel.resolveSubjectDisplay(for: lesson)

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
                    displayName: displayName,
                    subjectColor: subjectColor,
                    viewport: viewport
                )
                .zIndex(10)

                editorToolbar(viewport: viewport)
                    .opacity(showsEditor ? 1 : 0)
                    .allowsHitTesting(showsEditor)
                    .zIndex(20)
            }
            .onAppear {
                loadExistingNote()
                heroSourceFrame = viewModel.activeNoteSourceFrame

                // Wait one layout pass so saved height and safe-area dimensions
                // are both present before calculating the initial fit.
                DispatchQueue.main.async {
                    initializeTransform(in: viewport)
                    baseScale = scale
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
        }
    }

    // MARK: - Editor panel

    private func editorPanel(
        displayName: String,
        subjectColor: Color,
        viewport: DrawingViewport
    ) -> some View {
        VStack(spacing: handleSpacing) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        isExpanded
                            ? Color(UIColor.secondarySystemBackground)
                            : subjectColor
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(
                                isExpanded
                                    ? Color.white.opacity(0.28)
                                    : subjectColor.contrastingTextColor.opacity(0.25),
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
                    colorScheme: colorScheme,
                    onCanvasCreated: { createdCanvas in
                        canvasView = createdCanvas
                    },
                    onFingerPan: { delta in
                        applyFingerPan(delta, in: viewport)
                    },
                    onFingerZoom: { factor, focalPoint in
                        applyFingerZoom(factor, focalPoint: focalPoint, in: viewport)
                    }
                )
                .frame(
                    width: paperWidth,
                    height: max(180, canvasHeight - headerHeight)
                )
                .offset(y: headerHeight)
                .opacity(showsEditor ? 1 : 0)
                .allowsHitTesting(showsEditor)

                noteHeader(
                    displayName: displayName,
                    subjectColor: subjectColor,
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
    /// hero transition has settled this simply equals the normal uniform
    /// pinch-zoom `scale`.
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

    /// Counter-scale so header text and the resize handle keep a constant
    /// apparent size while the user pinch-zooms the drawing canvas. During the
    /// opening/closing hero transition this stays neutral (1), so everything
    /// morphs together for the "cool" zoom animation.
    private var chromeScaleCompensation: CGFloat {
        guard baseScale > 0.0001 else { return 1 }
        return min(1.6, max(0.6, baseScale / max(scale, 0.0001)))
    }

    private func noteHeader(
        displayName: String,
        subjectColor: Color,
        viewport: DrawingViewport
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(displayName)
                .font(.system(size: 18, weight: .semibold, design: .default))
                .lineLimit(1)

            Spacer(minLength: 8)

            Text("\(lesson.dateString) • \(lesson.periodNumber). Stunde")
                .font(.system(size: 13, weight: .regular, design: .default))
                .opacity(0.78)
                .lineLimit(1)
        }
        .foregroundColor(
            isExpanded ? .primary : subjectColor.contrastingTextColor
        )
        .padding(.horizontal, 20)
        .scaleEffect(chromeScaleCompensation, anchor: .center)
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
            .scaleEffect(chromeScaleCompensation, anchor: .center)
            .frame(width: handleSize, height: handleSize)
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
        // toolbar only needs to hold the drawing tools. Centering it (instead
        // of stretching it edge-to-edge) avoids the large empty area that
        // used to sit to the right of it.
        HStack {
            Spacer(minLength: 0)
            DrawingToolbarView(
                toolSelection: $toolSelection,
                penWidth: $penWidth,
                onUndo: { canvasView?.undoManager?.undo() },
                onRedo: { canvasView?.undoManager?.redo() },
                onClear: {
                    let emptyDrawing = PKDrawing()
                    drawing = emptyDrawing
                    canvasView?.drawing = emptyDrawing
                }
            )
            Spacer(minLength: 0)
        }
        .padding(.horizontal, max(16, viewport.safeAreaInsets.leading + 12))
        .padding(.top, max(12, viewport.safeAreaInsets.top + 8))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Live pan, zoom and constraints

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

    private func minimumScale(for height: CGFloat, in viewport: DrawingViewport) -> CGFloat {
        min(0.58, maximumScale(for: height, in: viewport))
    }

    private func initializeTransform(in viewport: DrawingViewport) {
        scale = min(1, maximumScale(for: canvasHeight, in: viewport))
        offset = clampedOffset(.zero, scale: scale, height: canvasHeight, in: viewport)
    }

    private func normalizeTransform(in viewport: DrawingViewport) {
        let normalizedScale = max(
            minimumScale(for: canvasHeight, in: viewport),
            min(maximumScale(for: canvasHeight, in: viewport), scale)
        )
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

    private func applyFingerZoom(
        _ factor: CGFloat,
        focalPoint: CGPoint,
        in viewport: DrawingViewport
    ) {
        guard showsEditor, factor.isFinite, factor > 0 else { return }

        let oldScale = scale
        let newScale = max(
            minimumScale(for: canvasHeight, in: viewport),
            min(maximumScale(for: canvasHeight, in: viewport), oldScale * factor)
        )
        guard abs(newScale - oldScale) > 0.0001 else { return }

        // focalPoint is local to the Pencil canvas. Convert it to a vector from
        // the center of the complete note (including header and resize handle).
        let localFocus = CGPoint(
            x: focalPoint.x - (paperWidth / 2),
            y: headerHeight + focalPoint.y - (panelHeight / 2)
        )

        var candidate = offset
        candidate.width += localFocus.x * (oldScale - newScale)
        candidate.height += localFocus.y * (oldScale - newScale)

        scale = newScale
        offset = clampedOffset(candidate, scale: newScale, height: canvasHeight, in: viewport)
    }

    // MARK: - Persistence and transition

    private func loadExistingNote() {
        guard let note = viewModel.noteFor(lesson: lesson) else { return }

        canvasHeight = max(
            minimumCanvasHeight,
            min(maximumCanvasHeight, CGFloat(note.lineCount) * 56 + headerHeight + 40)
        )
        resizeStartHeight = canvasHeight

        if let savedDrawing = try? PKDrawing(data: note.drawingData) {
            drawing = savedDrawing
        }
    }

    private func saveAndDismiss() {
        guard viewModel.isDrawingOverlayPresented else { return }

        let currentDrawing = canvasView?.drawing ?? drawing
        let croppedImage = PencilKitCanvasRepresentable.cropDrawingToContent(currentDrawing)
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
                lineCount: calculatedLines
            )
        }
    }
}
