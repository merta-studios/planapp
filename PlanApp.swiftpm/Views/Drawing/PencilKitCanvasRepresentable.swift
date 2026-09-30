import SwiftUI
import PencilKit
import UIKit

/// SwiftUI wrapper for `PKCanvasView` with Apple-Pencil-only drawing.
/// Direct finger touches never draw; two fingers are forwarded to the surrounding
/// note as incremental pan updates. Zooming is deliberately not supported – the
/// note is moved and resized only.
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
    /// Wird bei jeder Änderung der Zeichnung aufgerufen (Strich gezeichnet,
    /// radiert, Undo/Redo im Canvas) – dient zum Zeitstempel der letzten
    /// Strich-Mutation für das kombinierte Undo (Zeichnung + Textfelder).
    public let onStrokeMutation: () -> Void
    /// Zentrale Undo-Anfrage (Squeeze / Doppeltippen des Apple Pencil). Läuft
    /// über dasselbe kombinierte Undo wie der Toolbar-Button.
    public let onRequestUndo: () -> Void

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
        onFingerPan: @escaping (CGSize) -> Void = { _ in },
        onStrokeMutation: @escaping () -> Void = {},
        onRequestUndo: @escaping () -> Void = {}
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
        self.onStrokeMutation = onStrokeMutation
        self.onRequestUndo = onRequestUndo
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

        // Nur der Apple Pencil darf Striche erzeugen. Finger bleiben für
        // UI-Bedienung und die eigene Zwei-Finger-Verschiebe-Geste reserviert.
        canvasView.drawingPolicy = .pencilOnly
        canvasView.isScrollEnabled = false
        canvasView.bounces = false
        // Eigene Scroll-Gesten des CanvasView deaktivieren
        canvasView.panGestureRecognizer.isEnabled = false
        canvasView.pinchGestureRecognizer?.isEnabled = false

        // 2-Finger-Geste zum Verschieben der gesamten Notiz
        let fingerPan = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleFingerPan(_:))
        )
        fingerPan.minimumNumberOfTouches = 2
        fingerPan.maximumNumberOfTouches = 2
        fingerPan.cancelsTouchesInView = false
        fingerPan.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
        fingerPan.delegate = context.coordinator
        canvasView.addGestureRecognizer(fingerPan)

        // Apple Pencil Pro squeeze / Pencil double tap
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
            // Bei aktivem Text-Werkzeug zeichnet der Canvas nicht;
            // stattdessen werden Textfelder in der SwiftUI-Ebene platziert/bearbeitet.
            isTextTool = true
        }

        // Im Text-Modus nimmt die SwiftUI-Text-Ebene die Eingaben entgegen.
        // Den PencilKit-Recognizer selbst lassen wir aktiv, weil das Umschalten
        // mitten in UIKit-Gesten instabil sein kann; stattdessen deaktivieren wir
        // die Interaktion des Canvas als Ganzes.
        canvasView.drawingGestureRecognizer.isEnabled = true
        canvasView.isUserInteractionEnabled = !isTextTool
    }

    /// Passt reines Schwarz/Weiß dynamisch an das Erscheinungsbild an
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

            let coordinateView: UIView = canvasView.window ?? canvasView
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
                self.parent.onStrokeMutation()
                self.parent.onUndoAvailable(canvasView.undoManager?.canUndo ?? false)
                self.parent.onRedoAvailable(canvasView.undoManager?.canRedo ?? false)
            }
        }

        // Apple Pencil Pro squeeze -> kombiniertes Undo (Zeichnung + Textfelder)
        @available(iOS 17.5, *)
        public func pencilInteraction(
            _ interaction: UIPencilInteraction,
            didReceiveSqueeze squeeze: UIPencilInteraction.Squeeze
        ) {
            if squeeze.phase == .ended {
                DispatchQueue.main.async { [weak self] in
                    Haptics.tap()
                    self?.parent.onRequestUndo()
                }
            }
        }

        // Double-tap fallback -> kombiniertes Undo
        public func pencilInteractionDidTap(_ interaction: UIPencilInteraction) {
            DispatchQueue.main.async { [weak self] in
                Haptics.tap()
                self?.parent.onRequestUndo()
            }
        }
    }

    // MARK: - Notiz-Vorschau (Zeichnung + Textfelder)

    /// Rendert die Vorschau einer Notiz, zugeschnitten auf den Inhalt.
    /// Sowohl Pencil-Striche als auch Textfelder werden berücksichtigt.
    /// Mit `clipRect` (z. B. Grenzen der Zeichenfläche) werden Inhalte hart
    /// auf diesen Bereich begrenzt – nichts außerhalb landet in der Vorschau.
    public static func renderNotePreview(
        drawing: PKDrawing,
        textBoxes: [NoteTextBox],
        backgroundStyle: NoteBackgroundStyle = .blank,
        clipRect: CGRect? = nil
    ) -> UIImage? {
        var contentRect = CGRect.null

        if !drawing.strokes.isEmpty {
            contentRect = drawing.bounds
        }

        for box in textBoxes {
            let boxHeight = estimatedTextBoxHeight(box)
            let boxRect = CGRect(
                x: CGFloat(box.x),
                y: CGFloat(box.y),
                width: CGFloat(box.width),
                height: boxHeight
            )
            contentRect = contentRect.isNull ? boxRect : contentRect.union(boxRect)
        }

        guard !contentRect.isNull, contentRect.width > 0, contentRect.height > 0 else {
            return nil
        }

        var renderBounds = contentRect.insetBy(dx: -12, dy: -12)

        if let clip = clipRect {
            renderBounds = renderBounds.intersection(clip)
            guard !renderBounds.isNull, renderBounds.width > 0, renderBounds.height > 0 else {
                return nil
            }
        }

        let maxDimension: CGFloat = 800
        let scaleFactor = min(1.0, maxDimension / max(renderBounds.width, renderBounds.height))
        let targetSize = CGSize(
            width: max(1, renderBounds.width * scaleFactor),
            height: max(1, renderBounds.height * scaleFactor)
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = UIScreen.main.scale
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { context in
            let cgContext = context.cgContext

            cgContext.saveGState()
            cgContext.scaleBy(x: scaleFactor, y: scaleFactor)
            cgContext.translateBy(x: -renderBounds.origin.x, y: -renderBounds.origin.y)

            drawPaperBackground(style: backgroundStyle, in: renderBounds, context: cgContext)

            if !drawing.strokes.isEmpty {
                let drawingImage = drawing.image(from: renderBounds, scale: UIScreen.main.scale)
                drawingImage.draw(in: renderBounds)
            }

            for box in textBoxes {
                guard !box.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    continue
                }
                let font = UIFont.systemFont(ofSize: box.fontSize)
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: UIColor.label
                ]
                let innerWidth = max(20, CGFloat(box.width) - 16)
                let textRect = CGRect(
                    x: CGFloat(box.x) + 8,
                    y: CGFloat(box.y) + 8,
                    width: innerWidth,
                    height: .greatestFiniteMagnitude
                )
                (box.text as NSString).draw(
                    with: textRect,
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: attributes,
                    context: nil
                )
            }

            cgContext.restoreGState()
        }
    }

    /// Rendert die Zeichnung auf weißem Hintergrund für Vision-OCR.
    /// Die Ausgabe ist absichtlich nicht zugeschnitten, damit erkannte
    /// Textpositionen direkt in Canvas-Koordinaten zurückgerechnet werden können.
    public static func renderDrawingForRecognition(
        drawing: PKDrawing,
        canvasSize: CGSize
    ) -> UIImage? {
        guard canvasSize.width > 0, canvasSize.height > 0 else { return nil }

        let canvasRect = CGRect(origin: .zero, size: canvasSize)
        let format = UIGraphicsImageRendererFormat()
        format.scale = UIScreen.main.scale
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)
        return renderer.image { context in
            UIColor.white.setFill()
            context.cgContext.fill(canvasRect)

            guard !drawing.strokes.isEmpty else { return }
            let drawingImage = drawing.image(from: canvasRect, scale: UIScreen.main.scale)
            drawingImage.draw(in: canvasRect)
        }
    }

    private static func drawPaperBackground(
        style: NoteBackgroundStyle,
        in rect: CGRect,
        context: CGContext
    ) {
        guard style != .blank else { return }

        context.saveGState()
        UIColor.white.withAlphaComponent(0.70).setFill()
        context.fill(rect)

        switch style {
        case .blank:
            break
        case .dotted:
            let spacing: CGFloat = 22
            let radius: CGFloat = 1.2
            UIColor.systemGray.withAlphaComponent(0.30).setFill()
            var y = floor(rect.minY / spacing) * spacing
            while y <= rect.maxY {
                var x = floor(rect.minX / spacing) * spacing
                while x <= rect.maxX {
                    let dot = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                    context.fillEllipse(in: dot)
                    x += spacing
                }
                y += spacing
            }
        case .lined:
            drawLines(in: rect, context: context, spacing: 28, vertical: false, alpha: 0.26)
        case .grid:
            drawLines(in: rect, context: context, spacing: 28, vertical: false, alpha: 0.22)
            drawLines(in: rect, context: context, spacing: 28, vertical: true, alpha: 0.22)
        }

        context.restoreGState()
    }

    private static func drawLines(
        in rect: CGRect,
        context: CGContext,
        spacing: CGFloat,
        vertical: Bool,
        alpha: CGFloat
    ) {
        context.setStrokeColor(UIColor.systemGray.withAlphaComponent(alpha).cgColor)
        context.setLineWidth(1)
        context.beginPath()

        if vertical {
            var x = floor(rect.minX / spacing) * spacing
            while x <= rect.maxX {
                context.move(to: CGPoint(x: x, y: rect.minY))
                context.addLine(to: CGPoint(x: x, y: rect.maxY))
                x += spacing
            }
        } else {
            var y = floor(rect.minY / spacing) * spacing
            while y <= rect.maxY {
                context.move(to: CGPoint(x: rect.minX, y: y))
                context.addLine(to: CGPoint(x: rect.maxX, y: y))
                y += spacing
            }
        }

        context.strokePath()
    }
}
