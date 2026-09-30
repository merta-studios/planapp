import SwiftUI
import PencilKit
import UIKit

/// SwiftUI wrapper for `PKCanvasView` with Apple Pencil drawing and direct
/// finger gestures. PencilKit owns Pencil input, while one or two fingers are
/// forwarded to the surrounding note as incremental pan/zoom updates.
public struct PencilKitCanvasRepresentable: UIViewRepresentable {
    @Binding public var drawing: PKDrawing
    public let toolSelection: DrawingToolSelection
    public let penWidth: CGFloat
    public let colorScheme: ColorScheme
    public let onUndoAvailable: (Bool) -> Void
    public let onRedoAvailable: (Bool) -> Void
    public let onCanvasCreated: (PKCanvasView) -> Void
    public let onFingerPan: (CGSize) -> Void
    public let onFingerZoom: (CGFloat, CGPoint) -> Void

    public init(
        drawing: Binding<PKDrawing>,
        toolSelection: DrawingToolSelection,
        penWidth: CGFloat = 3.5,
        colorScheme: ColorScheme = .light,
        onUndoAvailable: @escaping (Bool) -> Void = { _ in },
        onRedoAvailable: @escaping (Bool) -> Void = { _ in },
        onCanvasCreated: @escaping (PKCanvasView) -> Void = { _ in },
        onFingerPan: @escaping (CGSize) -> Void = { _ in },
        onFingerZoom: @escaping (CGFloat, CGPoint) -> Void = { _, _ in }
    ) {
        self._drawing = drawing
        self.toolSelection = toolSelection
        self.penWidth = penWidth
        self.colorScheme = colorScheme
        self.onUndoAvailable = onUndoAvailable
        self.onRedoAvailable = onRedoAvailable
        self.onCanvasCreated = onCanvasCreated
        self.onFingerPan = onFingerPan
        self.onFingerZoom = onFingerZoom
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

        let fingerPinch = UIPinchGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleFingerPinch(_:))
        )
        fingerPinch.cancelsTouchesInView = false
        fingerPinch.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
        fingerPinch.delegate = context.coordinator
        canvasView.addGestureRecognizer(fingerPinch)

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
        switch toolSelection {
        case .pen(let color):
            let resolvedColor = resolveDynamicColor(color)
            canvasView.tool = PKInkingTool(.pen, color: resolvedColor, width: penWidth)
        case .marker(let color):
            canvasView.tool = PKInkingTool(.marker, color: color, width: max(16.0, penWidth * 4.0))
        case .eraser:
            canvasView.tool = PKEraserTool(.bitmap)
        }
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

        @objc func handleFingerPinch(_ recognizer: UIPinchGestureRecognizer) {
            guard let canvasView else { return }
            let factor = recognizer.scale
            if factor.isFinite && factor > 0 && abs(factor - 1) > 0.0001 {
                // The local focal point is used by the SwiftUI container to
                // keep the content under both fingers while zooming.
                parent.onFingerZoom(factor, recognizer.location(in: canvasView))
                recognizer.scale = 1
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
                    self?.canvasView?.undoManager?.undo()
                }
            }
        }

        // Double-tap fallback -> undo.
        public func pencilInteractionDidTap(_ interaction: UIPencilInteraction) {
            DispatchQueue.main.async { [weak self] in
                self?.canvasView?.undoManager?.undo()
            }
        }
    }

    // MARK: - Auto-Crop Helper

    /// Crops a note preview to the outer bounds of its strokes.
    public static func cropDrawingToContent(_ drawing: PKDrawing) -> UIImage? {
        guard !drawing.strokes.isEmpty else { return nil }

        let bounds = drawing.bounds
        guard bounds.width > 2 && bounds.height > 2 && !bounds.isNull && !bounds.isInfinite else {
            return nil
        }

        let padding: CGFloat = 12
        let paddedRect = CGRect(
            x: max(0, bounds.origin.x - padding),
            y: max(0, bounds.origin.y - padding),
            width: bounds.width + (padding * 2),
            height: bounds.height + (padding * 2)
        )

        return drawing.image(from: paddedRect, scale: 2.0)
    }
}
