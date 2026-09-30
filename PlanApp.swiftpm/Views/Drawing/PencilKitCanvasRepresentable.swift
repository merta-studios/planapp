import SwiftUI
import PencilKit
import UIKit

/// SwiftUI Wrapper für PKCanvasView mit Apple Pencil Unterstützung
public struct PencilKitCanvasRepresentable: UIViewRepresentable {
    @Binding public var drawing: PKDrawing
    public let toolSelection: DrawingToolSelection
    public let penWidth: CGFloat
    public let colorScheme: ColorScheme
    public let onUndoAvailable: (Bool) -> Void
    public let onRedoAvailable: (Bool) -> Void
    public let onCanvasCreated: (PKCanvasView) -> Void

    public init(
        drawing: Binding<PKDrawing>,
        toolSelection: DrawingToolSelection,
        penWidth: CGFloat = 3.5,
        colorScheme: ColorScheme = .light,
        onUndoAvailable: @escaping (Bool) -> Void = { _ in },
        onRedoAvailable: @escaping (Bool) -> Void = { _ in },
        onCanvasCreated: @escaping (PKCanvasView) -> Void = { _ in }
    ) {
        self._drawing = drawing
        self.toolSelection = toolSelection
        self.penWidth = penWidth
        self.colorScheme = colorScheme
        self.onUndoAvailable = onUndoAvailable
        self.onRedoAvailable = onRedoAvailable
        self.onCanvasCreated = onCanvasCreated
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

        // Nur Apple Pencil zum Zeichnen verwenden – Finger dienen ausschließlich zum Zoomen & Verschieben
        canvasView.drawingPolicy = .pencilOnly

        // Apple Pencil Interaktion (Squeeze / Double Tap)
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
            // Standard-Pixelradierer (Bitmap) anstelle des Objektradierers (Vector)
            canvasView.tool = PKEraserTool(.bitmap)
        }
    }

    /// Passt Schwarz & Weiß im Dark Mode automatisch an
    private func resolveDynamicColor(_ color: UIColor) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)

        let isBlack = (r < 0.05 && g < 0.05 && b < 0.05)
        let isWhite = (r > 0.95 && g > 0.95 && b > 0.95)

        if colorScheme == .dark {
            if isBlack { return .white }
            if isWhite { return .black }
        } else {
            if isWhite { return .white }
            if isBlack { return .black }
        }
        return color
    }

    public class Coordinator: NSObject, PKCanvasViewDelegate, UIPencilInteractionDelegate {
        var parent: PencilKitCanvasRepresentable
        weak var canvasView: PKCanvasView?

        init(_ parent: PencilKitCanvasRepresentable) {
            self.parent = parent
        }

        public func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            DispatchQueue.main.async {
                self.parent.drawing = canvasView.drawing
                self.parent.onUndoAvailable(canvasView.undoManager?.canUndo ?? false)
                self.parent.onRedoAvailable(canvasView.undoManager?.canRedo ?? false)
            }
        }

        // Apple Pencil Pro Squeeze -> Rückgängig
        @available(iOS 17.5, *)
        public func pencilInteraction(_ interaction: UIPencilInteraction, didReceiveSqueeze squeeze: UIPencilInteraction.Squeeze) {
            if squeeze.phase == .ended {
                DispatchQueue.main.async { [weak self] in
                    self?.canvasView?.undoManager?.undo()
                }
            }
        }

        // Double Tap Fallback -> Rückgängig
        public func pencilInteractionDidTap(_ interaction: UIPencilInteraction) {
            DispatchQueue.main.async { [weak self] in
                self?.canvasView?.undoManager?.undo()
            }
        }
    }

    // MARK: - Auto-Crop Helper

    /// Schneidet die Zeichnung automatisch an den Außenrändern zu
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

        let image = drawing.image(from: paddedRect, scale: 2.0)
        return image
    }
}
