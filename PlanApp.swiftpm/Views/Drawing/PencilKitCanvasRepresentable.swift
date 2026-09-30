import SwiftUI
import PencilKit
import UIKit

/// Ausgewähltes Zeichenwerkzeug für die Notizen
public enum DrawingToolSelection: Equatable {
    case pen(color: UIColor)
    case marker(color: UIColor)
    case eraser

    public static func == (lhs: DrawingToolSelection, rhs: DrawingToolSelection) -> Bool {
        switch (lhs, rhs) {
        case (.eraser, .eraser):
            return true
        case (.pen(let c1), .pen(let c2)):
            return c1 == c2
        case (.marker(let c1), .marker(let c2)):
            return c1 == c2
        default:
            return false
        }
    }
}

/// SwiftUI Wrapper für PKCanvasView mit Apple Pencil Pro Squeeze-Unterstützung
public struct PencilKitCanvasRepresentable: UIViewRepresentable {
    @Binding public var drawing: PKDrawing
    public let toolSelection: DrawingToolSelection
    public let onUndoAvailable: (Bool) -> Void
    public let onRedoAvailable: (Bool) -> Void
    public let onCanvasCreated: (PKCanvasView) -> Void

    public init(
        drawing: Binding<PKDrawing>,
        toolSelection: DrawingToolSelection,
        onUndoAvailable: @escaping (Bool) -> Void = { _ in },
        onRedoAvailable: @escaping (Bool) -> Void = { _ in },
        onCanvasCreated: @escaping (PKCanvasView) -> Void = { _ in }
    ) {
        self._drawing = drawing
        self.toolSelection = toolSelection
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

        // Finger und Apple Pencil unterstützen
        canvasView.drawingPolicy = .anyInput

        // Apple Pencil Pro Squeeze-Interaktion registrieren
        let pencilInteraction = UIPencilInteraction(delegate: context.coordinator)
        canvasView.addInteraction(pencilInteraction)

        context.coordinator.canvasView = canvasView
        applyTool(to: canvasView)

        DispatchQueue.main.async {
            self.onCanvasCreated(canvasView)
        }

        return canvasView
    }

    public func updateUIView(_ uiView: PKCanvasView, context: Context) {
        if uiView.drawing != drawing {
            uiView.drawing = drawing
        }
        applyTool(to: uiView)
    }

    private func applyTool(to canvasView: PKCanvasView) {
        switch toolSelection {
        case .pen(let color):
            canvasView.tool = PKInkingTool(.pencil, color: color, width: 3.5)
        case .marker(let color):
            canvasView.tool = PKInkingTool(.marker, color: color, width: 22.0)
        case .eraser:
            canvasView.tool = PKEraserTool(.vector)
        }
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

        // 12pt Rand um die Zeichnung herum hinzufügen
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
