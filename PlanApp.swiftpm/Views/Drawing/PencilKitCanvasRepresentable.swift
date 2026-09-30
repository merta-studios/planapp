import SwiftUI
import PencilKit
import UIKit

/// SwiftUI wrapper for `PKCanvasView` with Apple Pencil drawing and direct
/// finger gestures. PencilKit owns Pencil input, while one or two fingers are
/// forwarded to the surrounding note as incremental pan updates. Zooming is
/// deliberately not supported anymore – the note is moved and resized only.
public struct PencilKitCanvasRepresentable: UIViewRepresentable {
    @Binding public var drawing: PKDrawing
    public let toolSelection: DrawingToolSelection
    public let penWidth: CGFloat
    public let markerWidth: CGFloat
    public let eraserWidth: CGFloat
    public let colorScheme: ColorScheme
    public let onUndoAvailable: (Bool) -> Void
    public let onRedoAvailable: (Bool) -> Void
    public let onCanvasCreated: (PKCanvasView) -> Void
    public let onFingerPan: (CGSize) -> Void

    public init(
        drawing: Binding<PKDrawing>,
        toolSelection: DrawingToolSelection,
        penWidth: CGFloat = 3.5,
        markerWidth: CGFloat = 16,
        eraserWidth: CGFloat = 24,
        colorScheme: ColorScheme = .light,
        onUndoAvailable: @escaping (Bool) -> Void = { _ in },
        onRedoAvailable: @escaping (Bool) -> Void = { _ in },
        onCanvasCreated: @escaping (PKCanvasView) -> Void = { _ in },
        onFingerPan: @escaping (CGSize) -> Void = { _ in }
    ) {
        self._drawing = drawing
        self.toolSelection = toolSelection
        self.penWidth = penWidth
        self.markerWidth = markerWidth
        self.eraserWidth = eraserWidth
        self.colorScheme = colorScheme
        self.onUndoAvailable = onUndoAvailable
        self.onRedoAvailable = onRedoAvailable
        self.onCanvasCreated = onCanvasCreated
        self.onFingerPan = onFingerPan
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public func makeUIView(context: Context) -> PKCanvasView {
        let canvasView = PKCanvasView()
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.drawing = drawing
        canvasView.delegate = context.coordinator

        // The Pencil draws; direct finger touches manipulate the complete note.
        // Disable PKCanvasView's own scroll view so it cannot consume the pan
        // and apply it only after the gesture has ended.
        canvasView.drawingPolicy = .pencilOnly
        canvasView.isScrollEnabled = false
        canvasView.bounces = false
        // PKCanvasView is itself a UIScrollView subclass and keeps its own
        // built-in pan (and pinch) recognizers alive even while
        // isScrollEnabled is false. Disabling them explicitly frees finger
        // touches for `fingerPan`.
        canvasView.panGestureRecognizer.isEnabled = false
        canvasView.pinchGestureRecognizer?.isEnabled = false

        let fingerPan = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleFingerPan(_:))
        )
        fingerPan.minimumNumberOfTouches = 1
        fingerPan.maximumNumberOfTouches = 2
        fingerPan.cancelsTouchesInView = false
        fingerPan.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
        fingerPan.delegate = context.coordinator
        canvasView.addGestureRecognizer(fingerPan)

        // Apple Pencil Pro squeeze / Pencil double tap.
        let pencilInteraction = UIPencilInteraction()
        pencilInteraction.delegate = context.coordinator
        canvasView.addInteraction(pencilInteraction)

        context.coordinator.canvasView = canvasView
        applyTool(to: canvasView)

        DispatchQueue.main.async {
            self.onCanvasCreated(canvasView)
        }

        return canvasView
    }

    public func updateUIView(_ uiView: PKCanvasView, context: Context) {
        context.coordinator.parent = self
        if uiView.drawing != drawing {
            uiView.drawing = drawing
        }
        applyTool(to: uiView)
    }

    private func applyTool(to canvasView: PKCanvasView) {
        var isTextTool = false

        switch toolSelection {
        case .pen(let color):
            let resolvedColor = resolveDynamicColor(color)
            canvasView.tool = PKInkingTool(.pen, color: resolvedColor, width: penWidth)
        case .marker(let color):
            canvasView.tool = PKInkingTool(.marker, color: color, width: markerWidth)
        case .eraser:
            canvasView.tool = PKEraserTool(.bitmap, width: eraserWidth)
        case .text:
            // While the text tool is active the Pencil must not draw; taps
            // create text boxes in the SwiftUI layer above the canvas.
            isTextTool = true
        }

        canvasView.drawingGestureRecognizer.isEnabled = !isTextTool
    }

    /// Adapts the black preset to dark appearance without changing stored
    /// strokes of the other explicit colors.
    private func resolveDynamicColor(_ color: UIColor) -> UIColor {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)

        let isBlack = r < 0.05 && g < 0.05 && b < 0.05
        let isWhite = r > 0.95 && g > 0.95 && b > 0.95

        if colorScheme == .dark {
            if isBlack { return .white }
            if isWhite { return .black }
        } else {
            if isWhite { return .white }
            if isBlack { return .black }
        }
        return color
    }

    public final class Coordinator: NSObject, PKCanvasViewDelegate, UIPencilInteractionDelegate, UIGestureRecognizerDelegate {
        var parent: PencilKitCanvasRepresentable
        weak var canvasView: PKCanvasView?

        init(_ parent: PencilKitCanvasRepresentable) {
            self.parent = parent
        }

        @objc func handleFingerPan(_ recognizer: UIPanGestureRecognizer) {
            guard let canvasView else { return }

            // Window coordinates make the note follow the finger 1:1 even if
            // the complete note is currently scaled.
            let coordinateView: UIView
            if let window = canvasView.window {
                coordinateView = window
            } else {
                coordinateView = canvasView
            }
            let translation = recognizer.translation(in: coordinateView)
            if translation != .zero {
                parent.onFingerPan(CGSize(width: translation.x, height: translation.y))
                recognizer.setTranslation(.zero, in: coordinateView)
            }
        }

        public func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }

        public func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            DispatchQueue.main.async {
                self.parent.drawing = canvasView.drawing
                self.parent.onUndoAvailable(canvasView.undoManager?.canUndo ?? false)
                self.parent.onRedoAvailable(canvasView.undoManager?.canRedo ?? false)
            }
        }

        // Apple Pencil Pro squeeze -> undo.
        @available(iOS 17.5, *)
        public func pencilInteraction(
            _ interaction: UIPencilInteraction,
            didReceiveSqueeze squeeze: UIPencilInteraction.Squeeze
        ) {
            if squeeze.phase == .ended {
                DispatchQueue.main.async { [weak self] in
                    Haptics.tap()
                    self?.canvasView?.undoManager?.undo()
                }
            }
        }

        // Double-tap fallback -> undo.
        public func pencilInteractionDidTap(_ interaction: UIPencilInteraction) {
            DispatchQueue.main.async { [weak self] in
                Haptics.tap()
                self?.canvasView?.undoManager?.undo()
            }
        }
    }

    // MARK: - Notiz-Vorschau (Zeichnung + Textfelder)

    /// Rendert die Vorschau einer Notiz, zugeschnitten auf den Inhalt.
    /// Sowohl Pencil-Striche als auch Textfelder werden berücksichtigt.
    public static func renderNotePreview(drawing: PKDrawing, textBoxes: [NoteTextBox]) -> UIImage? {
        var contentRect = CGRect.null

        if !drawing.strokes.isEmpty {
            let bounds = drawing.bounds
            if !bounds.isNull && !bounds.isInfinite && bounds.width > 2 && bounds.height > 2 {
                contentRect = contentRect.union(bounds)
            }
        }

        let visibleBoxes = textBoxes.filter {
            !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        func attributes(for box: NoteTextBox) -> [NSAttributedString.Key: Any] {
            [
                .font: UIFont.systemFont(ofSize: box.fontSize),
                .foregroundColor: UIColor.black
            ]
        }

        func textRect(for box: NoteTextBox) -> CGRect {
            let attrs = attributes(for: box)
            let innerWidth = max(20, box.width - 16)
            let bounding = (box.text as NSString).boundingRect(
                with: CGSize(width: innerWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin],
                attributes: attrs,
                context: nil
            )
            return CGRect(
                x: box.x + 8,
                y: box.y + 8,
                width: innerWidth,
                height: ceil(bounding.height)
            )
        }

        for box in visibleBoxes {
            contentRect = contentRect.union(textRect(for: box))
        }

        guard !contentRect.isNull, contentRect.width > 2, contentRect.height > 2 else {
            return nil
        }

        let padded = contentRect.insetBy(dx: -12, dy: -12)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: padded.size, format: format)

        return renderer.image { _ in
            if !drawing.strokes.isEmpty {
                let drawingImage = drawing.image(from: padded, scale: 2)
                drawingImage.draw(in: CGRect(origin: .zero, size: padded.size))
            }
            for box in visibleBoxes {
                let rect = textRect(for: box)
                let localRect = CGRect(
                    x: rect.minX - padded.minX,
                    y: rect.minY - padded.minY,
                    width: rect.width,
                    height: rect.height
                )
                (box.text as NSString).draw(
                    with: localRect,
                    options: [.usesLineFragmentOrigin],
                    attributes: attributes(for: box),
                    context: nil
                )
            }
        }
    }
}
