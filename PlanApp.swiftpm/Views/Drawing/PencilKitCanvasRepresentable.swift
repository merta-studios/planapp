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
    /// Zentrale Undo-Anfrage (Doppeltippen des Apple Pencil). Läuft
    /// über dasselbe kombinierte Undo wie der Toolbar-Button.
    public let onRequestUndo: () -> Void
    /// Ob ausschließlich der Apple Pencil zeichnen darf. `false` = auch der
    /// Finger (normaler Input) zeichnet.
    public let pencilOnlyDrawing: Bool
    /// Wird aufgerufen, sobald die App einen echten Apple-Pencil-Input bemerkt
    /// (Hover, Strich oder Squeeze). Damit schaltet sich die Einstellung
    /// „Nur Apple Pencil“ automatisch ein.
    public let onPencilInputDetected: () -> Void
    /// Squeeze des Apple Pencil Pro: Ankerpunkt der letzten Hover-Position in
    /// **Fenster-Koordinaten** (nil, wenn keine Pose vorliegt) und die Richtung,
    /// in die der Stift zeigt (Einheitsvektor im Fenster-Koordinatensystem).
    public let onPencilSqueeze: (CGPoint?, CGVector) -> Void
    /// Wird aufgerufen, sobald eine Zeichen- oder Radier-Geste auf der Fläche
    /// beginnt (z. B. um die Squeeze-Palette zu schließen).
    public let onCanvasGestureBegan: () -> Void
    /// Wird aufgerufen, wenn eine Zeichen- oder Radier-Geste auf der Fläche
    /// beendet wurde (z. B. um den Radierer automatisch abzuwählen).
    public let onCanvasGestureEnded: () -> Void

    public init(
        drawing: Binding<PKDrawing>,
        toolSelection: DrawingToolSelection,
        penWidth: CGFloat = 3.5,
        markerWidth: CGFloat = 16,
        eraserWidth: CGFloat = 24,
        colorScheme: ColorScheme = .light,
        pencilOnlyDrawing: Bool = true,
        onUndoAvailable: @escaping (Bool) -> Void = { _ in },
        onRedoAvailable: @escaping (Bool) -> Void = { _ in },
        onCanvasCreated: @escaping (PKCanvasView) -> Void = { _ in },
        onFingerPan: @escaping (CGSize) -> Void = { _ in },
        onStrokeMutation: @escaping () -> Void = {},
        onRequestUndo: @escaping () -> Void = {},
        onPencilInputDetected: @escaping () -> Void = {},
        onPencilSqueeze: @escaping (CGPoint?, CGVector) -> Void = { _, _ in },
        onCanvasGestureBegan: @escaping () -> Void = {},
        onCanvasGestureEnded: @escaping () -> Void = {}
    ) {
        self._drawing = drawing
        self.toolSelection = toolSelection
        self.penWidth = penWidth
        self.markerWidth = markerWidth
        self.eraserWidth = eraserWidth
        self.colorScheme = colorScheme
        self.pencilOnlyDrawing = pencilOnlyDrawing
        self.onUndoAvailable = onUndoAvailable
        self.onRedoAvailable = onRedoAvailable
        self.onCanvasCreated = onCanvasCreated
        self.onFingerPan = onFingerPan
        self.onStrokeMutation = onStrokeMutation
        self.onRequestUndo = onRequestUndo
        self.onPencilInputDetected = onPencilInputDetected
        self.onPencilSqueeze = onPencilSqueeze
        self.onCanvasGestureBegan = onCanvasGestureBegan
        self.onCanvasGestureEnded = onCanvasGestureEnded
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

        // Zeichen-Eingabe: standardmäßig nur der Apple Pencil. Ist die
        // Einstellung „Apple Pencil“ aus, zeichnet auch der Finger (normaler
        // Input) – die eigene Zwei-Finger-Geste verschiebt weiterhin die Notiz.
        canvasView.drawingPolicy = pencilOnlyDrawing ? .pencilOnly : .anyInput
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

        // Nur Apple-Pencil-Berührungen beobachten: Damit erkennt die App
        // zuverlässig, dass ein echter Apple Pencil benutzt wird. Der Erkenner
        // bricht nichts ab (`cancelsTouchesInView = false`) und läuft parallel
        // zu allen anderen Gesten – das Zeichnen bleibt völlig unberührt.
        let pencilTouchDetector = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePencilTouch(_:))
        )
        pencilTouchDetector.minimumNumberOfTouches = 1
        pencilTouchDetector.maximumNumberOfTouches = 1
        pencilTouchDetector.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.pencil.rawValue)]
        pencilTouchDetector.cancelsTouchesInView = false
        pencilTouchDetector.delaysTouchesBegan = false
        pencilTouchDetector.delaysTouchesEnded = false
        pencilTouchDetector.delegate = context.coordinator
        canvasView.addGestureRecognizer(pencilTouchDetector)

        // Apple Pencil Hover: liefert die letzte Position und Blickrichtung des
        // Stifts, damit der Squeeze-Kreis genau dort erscheint, wo der Stift
        // hinzeigt.
        let hoverRecognizer = UIHoverGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePencilHover(_:))
        )
        hoverRecognizer.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.pencil.rawValue)]
        canvasView.addGestureRecognizer(hoverRecognizer)

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

        // Zeichen-Eingabe an die Einstellung „Apple Pencil“ anpassen. Nur bei
        // echter Änderung schreiben: Ein Wechsel mitten in einer Berührung
        // würde laufende Gesten abbrechen.
        let policy: PKCanvasViewDrawingPolicy = pencilOnlyDrawing ? .pencilOnly : .anyInput
        if canvasView.drawingPolicy != policy {
            canvasView.drawingPolicy = policy
            // Beim Zeichnen mit dem Finger dürfen die internen Scroll-/Zoom-
            // Gesten des Canvas nicht dazwischenfunken. (Beim Umschalten der
            // Policy kann PencilKit sie wieder aktivieren.)
            canvasView.isScrollEnabled = false
            canvasView.panGestureRecognizer.isEnabled = false
            canvasView.pinchGestureRecognizer?.isEnabled = false
        }

        switch toolSelection {
        case .pen(let color):
            let resolvedColor = resolveDynamicColor(color)
            canvasView.tool = PKInkingTool(.pen, color: resolvedColor, width: penWidth)
        case .marker(let color):
            canvasView.tool = PKInkingTool(.marker, color: color, width: markerWidth)
        case .eraser:
            canvasView.tool = PKEraserTool(.bitmap, width: eraserWidth)
        case .lasso:
            canvasView.tool = PKLassoTool()
        case .text:
            // Bei aktivem Text-Werkzeug zeichnet der Canvas nicht;
            // stattdessen werden Textfelder in der SwiftUI-Ebene platziert/bearbeitet.
            isTextTool = true
        }

        // Im Text-Modus nimmt die SwiftUI-Text-Ebene die Eingaben entgegen.
        //
        // WICHTIG: Der Canvas ist eine echte UIView im View-Baum. Solange sie
        // `isUserInteractionEnabled == true` hat, gewinnt sie beim UIKit-
        // Hit-Testing gegen die darüberliegende SwiftUI-Ebene – Tipps zum
        // Erstellen/Auswählen von Textfeldern kamen dadurch nie an (das
        // Text-Werkzeug wirkte schlicht "tot"). Früher wurde hier sogar
        // ausdrücklich `true` gesetzt und damit das `allowsHitTesting(false)`
        // der SwiftUI-Seite wieder ausgehebelt.
        //
        // Deshalb: im Text-Modus die Interaktion der Canvas-View komplett
        // abschalten, sonst wieder aktivieren. Das ist ausreichend, um den
        // PencilKit-Recognizer zu stoppen. Den internen
        // `drawingGestureRecognizer` zusätzlich während eines laufenden
        // Touch-Events ein-/auszuschalten, kann UIKit mit einem
        // "gesture recognizer changed while handling touches"-Abbruch
        // quittieren und war die Ursache des App-Crashs.
        // Nur bei echter Änderung schreiben: `isUserInteractionEnabled`
        // während eines laufenden Touch-Events neu zu setzen bricht UIKit-
        // Gesten ab. `updateUIView` läuft bei jedem SwiftUI-Update.
        if canvasView.isUserInteractionEnabled != !isTextTool {
            canvasView.isUserInteractionEnabled = !isTextTool
        }

        // Der Canvas darf im Text-Modus nicht First Responder bleiben:
        // Sonst gehört die Eingabeansicht weiterhin ihm (Scribble), und das
        // Textfeld der SwiftUI-Ebene bekommt zwar den Cursor, aber keine
        // Systemtastatur.
        if isTextTool, canvasView.isFirstResponder {
            canvasView.resignFirstResponder()
        }
    }

    /// Liefert die gewählte Farbe unverändert zurück.
    ///
    /// Die Zeichenfläche ist immer weiß, auch wenn die restliche App im
    /// Dark Mode läuft. Eine frühere automatische Schwarz/Weiß-Umkehr machte
    /// deshalb den Standardstift weiß auf weiß und die OCR unlesbar. Farben
    /// gehören zur Werkzeugauswahl und dürfen nicht vom UI-Erscheinungsbild
    /// abhängen.
    private func resolveDynamicColor(_ color: UIColor) -> UIColor {
        color
    }

    public final class Coordinator: NSObject, PKCanvasViewDelegate, UIPencilInteractionDelegate, UIGestureRecognizerDelegate {
        var parent: PencilKitCanvasRepresentable
        weak var canvasView: PKCanvasView?
        /// Letzte Hover-Position des Apple Pencil in Fenster-Koordinaten.
        private var lastHoverLocation: CGPoint?
        /// Richtung, in die der Stift zuletzt gezeigt hat (Fenster-Koordinaten).
        /// Standard „nach oben“, wenn das Gerät keine Azimut-Werte liefert.
        private var lastHoverDirection = CGVector(dx: 0, dy: -1)

        init(_ parent: PencilKitCanvasRepresentable) {
            self.parent = parent
        }

        // MARK: - Apple Pencil erkennen & verfolgen

        /// Eine echte Stylus-Berührung: Damit ist sicher ein Apple Pencil im
        /// Spiel – die App schaltet „Nur Apple Pencil“ automatisch ein.
        @objc func handlePencilTouch(_ recognizer: UIPanGestureRecognizer) {
            switch recognizer.state {
            case .began, .changed:
                DispatchQueue.main.async { [weak self] in
                    self?.parent.onPencilInputDetected()
                }
            default:
                break
            }
        }

        /// Hover des Apple Pencil: Position und Blickrichtung merken – ganz
        /// ohne SwiftUI-State, damit die vielen Hover-Ereignisse keine
        /// Neuzeichnung auslösen.
        @objc func handlePencilHover(_ recognizer: UIHoverGestureRecognizer) {
            guard let view = recognizer.view else { return }

            let windowLocation = recognizer.location(in: view.window)
            if windowLocation.x.isFinite, windowLocation.y.isFinite {
                lastHoverLocation = windowLocation
            }

            let vector = recognizer.azimuthUnitVector(in: view)
            if vector.dx.isFinite, vector.dy.isFinite, vector.dx != 0 || vector.dy != 0 {
                lastHoverDirection = vector
            }

            if recognizer.state == .began || recognizer.state == .changed {
                DispatchQueue.main.async { [weak self] in
                    self?.parent.onPencilInputDetected()
                }
            }
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

        /// Zeichen- oder Radier-Geste begonnen. Wird u. a. genutzt, um die
        /// Squeeze-Palette zu schließen, sobald wieder geschrieben wird.
        public func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
            DispatchQueue.main.async { [weak self] in
                self?.parent.onCanvasGestureBegan()
            }
        }

        /// Zeichen- oder Radier-Geste beendet (z. B. Radierer automatisch
        /// abwählen, sobald der Stift losgelassen wird).
        public func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
            DispatchQueue.main.async { [weak self] in
                self?.parent.onCanvasGestureEnded()
            }
        }

        /// Apple Pencil Pro Squeeze → Bogen-Werkzeugpalette an der letzten
        /// Hover-Position, mit korrigierter Orientierung.
        @available(iOS 17.5, *)
        public func pencilInteraction(
            _ interaction: UIPencilInteraction,
            didReceiveSqueeze squeeze: UIPencilInteraction.Squeeze
        ) {
            guard squeeze.phase == .ended else { return }

            var anchor = lastHoverLocation
            var direction = lastHoverDirection

            if let pose = squeeze.hoverPose, let canvasView {
                let windowPoint = canvasView.convert(pose.location, to: nil)
                if windowPoint.x.isFinite, windowPoint.y.isFinite {
                    anchor = windowPoint
                    lastHoverLocation = windowPoint
                }
                // `azimuthUnitVector` zeigt in die Richtung, in die die
                // Stiftspitze deutet (0 rad = +X, im Uhrzeigersinn).
                let azimuth = Double(pose.azimuthAngle)
                let vector = CGVector(dx: CGFloat(cos(azimuth)), dy: CGFloat(sin(azimuth)))
                if vector.dx.isFinite, vector.dy.isFinite, vector.dx != 0 || vector.dy != 0 {
                    direction = vector
                    lastHoverDirection = vector
                }
            }

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.parent.onPencilInputDetected()
                self.parent.onPencilSqueeze(anchor, direction)
            }
        }

        // Double-tap fallback -> kombiniertes Undo
        public func pencilInteractionDidTap(_ interaction: UIPencilInteraction) {
            DispatchQueue.main.async { [weak self] in
                Haptics.tap()
                self?.parent.onPencilInputDetected()
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
                let font = UIFont.systemFont(ofSize: CGFloat(box.fontSize))
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: UIColor(hex: box.colorHex.isEmpty
                        ? NoteTextBox.defaultColorHex
                        : box.colorHex)
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
    ///
    /// Wichtig: Alle Striche werden vorher auf kräftiges Schwarz umgefärbt.
    /// Sonst wären helle Striche (z. B. der im Dunkelmodus automatisch weiße
    /// Stift oder ein gelber Textmarker) auf dem weißen OCR-Hintergrund
    /// unsichtbar und die Erkennung würde grundsätzlich nichts finden.
    public static func renderDrawingForRecognition(
        drawing: PKDrawing,
        canvasSize: CGSize
    ) -> UIImage? {
        guard canvasSize.width.isFinite, canvasSize.height.isFinite,
              canvasSize.width > 0, canvasSize.height > 0,
              !drawing.strokes.isEmpty else {
            return nil
        }

        let canvasRect = CGRect(origin: .zero, size: canvasSize)
        let contrastDrawing = highContrastCopy(of: drawing)

        // Vision erkennt Handschrift deutlich zuverlässiger, wenn die
        // Buchstaben nicht in der relativ kleinen Vorschau-Auflösung landen.
        // Die Bildgröße bleibt dabei auf maximal ungefähr 4x begrenzt.
        let renderScale = max(3, min(4, 2200 / max(canvasSize.width, 1)))

        let format = UIGraphicsImageRendererFormat()
        format.scale = renderScale
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)
        return renderer.image { context in
            UIColor.white.setFill()
            context.cgContext.fill(canvasRect)

            let drawingImage = contrastDrawing.image(from: canvasRect, scale: renderScale)
            drawingImage.draw(in: canvasRect)
        }
    }

    /// Kopie der Zeichnung, in der jeder Strich mit deckendem Schwarz
    /// eingefärbt ist. Der Strichverlauf bleibt unverändert.
    private static func highContrastCopy(of drawing: PKDrawing) -> PKDrawing {
        let strokes: [PKStroke] = drawing.strokes.map { stroke in
            var copy = stroke
            copy.ink = PKInk(stroke.ink.inkType, color: .black)
            return copy
        }
        return PKDrawing(strokes: strokes)
    }

    private static func drawPaperBackground(
        style: NoteBackgroundStyle,
        in rect: CGRect,
        context: CGContext
    ) {
        // Gespeicherte Vorschauen verwenden dieselbe weiße Papierfläche wie
        // der Editor. Eine halbtransparente Füllung würde im Dark Mode den
        // dunklen Untergrund durchscheinen lassen.
        context.saveGState()
        UIColor.white.setFill()
        context.fill(rect)

        guard style != .blank else {
            context.restoreGState()
            return
        }

        let spacing = NoteBackgroundMetrics.spacing(for: style)
        let alpha = NoteBackgroundMetrics.opacity(for: style)

        switch style {
        case .blank:
            break
        case .dotted:
            let radius = NoteBackgroundMetrics.dotRadius
            UIColor(white: 0.5, alpha: alpha).setFill()
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
            drawLines(in: rect, context: context, spacing: spacing, vertical: false, alpha: alpha)
        case .grid:
            drawLines(in: rect, context: context, spacing: spacing, vertical: false, alpha: alpha)
            drawLines(in: rect, context: context, spacing: spacing, vertical: true, alpha: alpha)
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
        guard spacing > 0 else { return }

        context.setStrokeColor(UIColor(white: 0.5, alpha: alpha).cgColor)
        context.setLineWidth(NoteBackgroundMetrics.lineWidth)
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
