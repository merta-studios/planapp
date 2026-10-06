import SwiftUI
import PencilKit
import UIKit

/// Canvas whose responder-chain undo manager is intentionally disabled.
/// The note editor owns a combined drawing-and-text history, so PencilKit must
/// not register a competing, drawing-only undo history with the system.
private final class UndoDisabledPKCanvasView: PKCanvasView {
    override var undoManager: UndoManager? { nil }
}

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
    /// Dynamische Stiftdicke (PencilKit-Stift mit Druck/Geschwindigkeit) oder
    /// Kugelschreiber (Monoline, immer gleich dick).
    public let dynamicPenWidth: Bool
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
    /// Synchrone, nicht UI-verändernde Aktivitätsmeldung für den Handballenfilter.
    /// Sie darf nicht erst nach dem asynchronen SwiftUI-Update eintreffen.
    public let onCanvasActivity: () -> Void
    /// Wird aufgerufen, sobald eine Zeichen- oder Radier-Geste auf der Fläche
    /// beginnt (z. B. um die Squeeze-Palette zu schließen).
    public let onCanvasGestureBegan: () -> Void
    /// Wird aufgerufen, wenn eine Zeichen- oder Radier-Geste auf der Fläche
    /// beendet wurde (z. B. um den Radierer automatisch abzuwählen).
    public let onCanvasGestureEnded: () -> Void
    /// Ein Strich wurde nach dem Stillhalten in eine gerade Linie verwandelt.
    public let onStraightLineSnap: () -> Void

    /// Wie lange der Stift am Ende eines Strichs still gehalten werden muss,
    /// bis der Strich zur geraden Linie einrastet.
    public static let straightLineHoldDuration: TimeInterval = 1.5

    public init(
        drawing: Binding<PKDrawing>,
        toolSelection: DrawingToolSelection,
        penWidth: CGFloat = 3.5,
        markerWidth: CGFloat = 16,
        eraserWidth: CGFloat = 24,
        colorScheme: ColorScheme = .light,
        pencilOnlyDrawing: Bool = true,
        dynamicPenWidth: Bool = true,
        onUndoAvailable: @escaping (Bool) -> Void = { _ in },
        onRedoAvailable: @escaping (Bool) -> Void = { _ in },
        onCanvasCreated: @escaping (PKCanvasView) -> Void = { _ in },
        onFingerPan: @escaping (CGSize) -> Void = { _ in },
        onStrokeMutation: @escaping () -> Void = {},
        onRequestUndo: @escaping () -> Void = {},
        onPencilInputDetected: @escaping () -> Void = {},
        onPencilSqueeze: @escaping (CGPoint?, CGVector) -> Void = { _, _ in },
        onCanvasActivity: @escaping () -> Void = {},
        onCanvasGestureBegan: @escaping () -> Void = {},
        onCanvasGestureEnded: @escaping () -> Void = {},
        onStraightLineSnap: @escaping () -> Void = {}
    ) {
        self._drawing = drawing
        self.toolSelection = toolSelection
        self.penWidth = penWidth
        self.markerWidth = markerWidth
        self.eraserWidth = eraserWidth
        self.colorScheme = colorScheme
        self.pencilOnlyDrawing = pencilOnlyDrawing
        self.dynamicPenWidth = dynamicPenWidth
        self.onStraightLineSnap = onStraightLineSnap
        self.onUndoAvailable = onUndoAvailable
        self.onRedoAvailable = onRedoAvailable
        self.onCanvasCreated = onCanvasCreated
        self.onFingerPan = onFingerPan
        self.onStrokeMutation = onStrokeMutation
        self.onRequestUndo = onRequestUndo
        self.onPencilInputDetected = onPencilInputDetected
        self.onPencilSqueeze = onPencilSqueeze
        self.onCanvasActivity = onCanvasActivity
        self.onCanvasGestureBegan = onCanvasGestureBegan
        self.onCanvasGestureEnded = onCanvasGestureEnded
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public func makeUIView(context: Context) -> PKCanvasView {
        let canvasView = UndoDisabledPKCanvasView()
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        // Das Papier ist immer weiß. PencilKit würde im Dark Mode des Geräts
        // dunkle Tinte automatisch aufhellen (Schwarz → Weiß) – genau das
        // machte gespeicherte schwarze Notizen beim Öffnen weiß auf weiß.
        // Die Zeichenfläche läuft deshalb fest im hellen Erscheinungsbild.
        canvasView.overrideUserInterfaceStyle = .light
        canvasView.drawing = drawing
        canvasView.delegate = context.coordinator

        // Die eigene, Notiz umfassende Undo-Historie (Zeichnung + Textfelder)
        // wird im Overlay geführt. `undoManager` ist in UIKit nur lesbar; die
        // Unterklasse oben liefert deshalb dauerhaft nil, damit System-Undo
        // keine konkurrierenden PencilKit-Striche registriert.

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
        let pencilTouchDetector = StrokeHoldGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePencilTouch(_:))
        )
        pencilTouchDetector.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.pencil.rawValue)]
        pencilTouchDetector.cancelsTouchesInView = false
        pencilTouchDetector.delaysTouchesBegan = false
        pencilTouchDetector.delaysTouchesEnded = false
        pencilTouchDetector.delegate = context.coordinator
        canvasView.addGestureRecognizer(pencilTouchDetector)

        // Ein-Finger-Beobachter (nur relevant, wenn auch der Finger zeichnen
        // darf): liefert die Stillhalte-Erkennung für gerade Linien.
        let fingerStrokeDetector = StrokeHoldGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleFingerStroke(_:))
        )
        fingerStrokeDetector.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
        fingerStrokeDetector.cancelsTouchesInView = false
        fingerStrokeDetector.delaysTouchesBegan = false
        fingerStrokeDetector.delaysTouchesEnded = false
        fingerStrokeDetector.delegate = context.coordinator
        canvasView.addGestureRecognizer(fingerStrokeDetector)

        // Zusätzlich direkt am PencilKit-Zeichen-Recognizer hängen. Der eigene
        // Pan-Erkenner hat die Stillhalte-Geste oft nie gesehen, weil PencilKit
        // die Touches für sich behält.
        canvasView.drawingGestureRecognizer.addTarget(
            context.coordinator,
            action: #selector(Coordinator.handleDrawingGesture(_:))
        )

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
        if uiView.overrideUserInterfaceStyle != .light {
            uiView.overrideUserInterfaceStyle = .light
        }
        // Die Zeichenfläche ist während eines laufenden Strichs die einzige
        // Quelle der Wahrheit (PencilKit hält den Live-Strich; das Binding
        // wird vom Delegate gepflegt). Jetzt schreiben wir sie nur dann, wenn
        // sich der von außen gesetzte Zustand unterscheidet – und melden das
        // dem Coordinator an, damit der resultierende Delegate-Callback nicht
        // den umgekehrten Weg (Canvas → Binding → Historie) mitgeht und
        // dadurch Undo-Einträge doppelt oder fehlerhaft legt.
        let isInking = uiView.drawingGestureRecognizer.state == .began
            || uiView.drawingGestureRecognizer.state == .changed
        if !isInking,
           !context.coordinator.preservesCanvasDrawing,
           uiView.drawing != drawing {
            context.coordinator.markExternalDrawingWrite()
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
            // Dynamische Stiftdicke = PencilKit-Stift (reagiert auf Druck und
            // Tempo). Aus = Kugelschreiber (Monoline), immer gleich dick.
            let inkType: PKInkingTool.InkType = dynamicPenWidth ? .pen : .monoline
            canvasView.tool = PKInkingTool(inkType, color: resolvedColor, width: penWidth)
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

        // Gerade-Linie-Erkennung („Stillhalten am Strichende“)
        private var holdWorkItem: DispatchWorkItem?
        private var activeStrokeSources: Set<String> = []
        private var holdAnchor: CGPoint = .zero
        private var straightenRequested = false
        private var straightenUntil: Date?
        private var strokeCountAtToolBegin = 0
        private var snapFeedbackGenerator: UIImpactFeedbackGenerator?
        private var strokeToolActive = false
        private var lastSignificantMovement = Date()
        /// Strichende in Zeichenkoordinaten zum letzten beobachteten Bewegen.
        private var stillStrokeEnd: CGPoint?
        private var lastObservedPointCount = 0
        private var stillnessSampler: Timer?
        /// Beginn des gerade gezogenen Strichs in Zeichenkoordinaten.
        private var liveStrokeStart: CGPoint?
        /// Aktuelles (gehaltenes) Strichende für die Live-Vorschau.
        private var liveStrokeEnd: CGPoint?
        /// Dünne Ebene ÜBER der Zeichenfläche. Sie zeigt die gerade Linie
        /// bereits **während** des Stillhaltens. PencilKit übernimmt den Strich
        /// erst beim Loslassen – ohne diese Vorschau erschien die Linie erst
        /// danach.
        private var straightPreviewLayer: CAShapeLayer?
        private var previewClearWorkItem: DispatchWorkItem?
        /// Solange gesetzt, darf SwiftUI die gerade eingerastete Zeichnung
        /// nicht mit dem noch gekrümmten Binding überschreiben.
        var preservesCanvasDrawing: Bool {
            if let straightenUntil, straightenUntil > Date() { return true }
            return false
        }
        /// `true`, wenn die zuletzt auf `canvasView.drawing` geschriebene
        /// Änderung **nicht** vom Nutzer gezeichnet, sondern von außen
        /// gesetzt wurde (Undo/Redo/Reset/gerade Linie). Der zugehörige
        /// Delegate-Callback wird dadurch unterdrückt: Das SwiftUI-Binding
        /// und die Historie sind in dem Moment bereits aktuell, und ein
        /// Write-back würde veraltete Zustände als neue Undo-Schritte
        /// verzeichnen (das war die Ursache dafür, dass Undo-Schritte
        /// verschluckt oder „Wiederholen“ blockiert wurden).
        private var externalDrawingWrite = false

        func markExternalDrawingWrite() {
            externalDrawingWrite = true
        }

        init(_ parent: PencilKitCanvasRepresentable) {
            self.parent = parent
        }

        deinit {
            holdWorkItem?.cancel()
            stillnessSampler?.invalidate()
        }

        // MARK: - Apple Pencil erkennen & verfolgen

        /// Eine echte Stylus-Berührung: Damit ist sicher ein Apple Pencil im
        /// Spiel – die App schaltet „Nur Apple Pencil“ automatisch ein.
        @objc func handlePencilTouch(_ recognizer: UIGestureRecognizer) {
            switch recognizer.state {
            case .began, .changed:
                parent.onCanvasActivity()
                DispatchQueue.main.async { [weak self] in
                    self?.parent.onPencilInputDetected()
                }
            default:
                break
            }
            trackStrokeTouch(recognizer, source: "pencil")
        }

        /// Finger-Strich (nur wenn „Nur Apple Pencil“ aus ist): dieselbe
        /// Stillhalte-Erkennung wie beim Pencil.
        @objc func handleFingerStroke(_ recognizer: UIGestureRecognizer) {
            guard !parent.pencilOnlyDrawing else { return }
            trackStrokeTouch(recognizer, source: "finger")
        }

        /// PencilKits eigener Zeichen-Recognizer – die zuverlässigste Quelle
        /// für Beginn, Bewegung und Ende eines Strichs.
        @objc func handleDrawingGesture(_ recognizer: UIGestureRecognizer) {
            trackStrokeTouch(recognizer, source: "drawing")
        }

        // MARK: - Gerade Linie durch Stillhalten

        private var isInkingToolActive: Bool {
            switch parent.toolSelection {
            case .pen, .marker:
                return true
            case .eraser, .lasso, .text:
                return false
            }
        }

        /// Verfolgt die Bewegung einer Zeichen-Berührung. Bleibt der Stift am
        /// Ende eines Strichs ≈2 s still, wird der Strich in eine gerade Linie
        /// verwandelt (Pencil Pro vibriert zur Bestätigung).
        ///
        /// Mehrere Recognizer melden denselben Strich. Ein `.failed` eines
        /// Nebenbeobachters darf den Halt nicht abbrechen, solange PencilKit
        /// den Strich noch führt.
        private func trackStrokeTouch(_ recognizer: UIGestureRecognizer, source: String) {
            guard let canvasView else { return }
            let location = recognizer.location(in: canvasView)

            switch recognizer.state {
            case .began, .changed:
                guard isInkingToolActive else { return }
                let wasActive = !activeStrokeSources.isEmpty
                activeStrokeSources.insert(source)
                if !wasActive {
                    holdAnchor = location
                    liveStrokeStart = location
                    liveStrokeEnd = location
                    lastSignificantMovement = Date()
                    straightenRequested = false
                    straightenUntil = nil
                    scheduleHoldCheck()
                } else if hypot(location.x - holdAnchor.x, location.y - holdAnchor.y) > 12 {
                    // Kleines Stiftzittern setzt den Halt nicht zurück.
                    holdAnchor = location
                    liveStrokeEnd = location
                    stillStrokeEnd = currentStrokeEnd()
                    lastSignificantMovement = Date()
                    // Weitergezeichnet: Die Vorschau einer alten Linie muss weg.
                    clearStraightPreview()
                    straightenRequested = false
                    straightenUntil = nil
                    scheduleHoldCheck()
                } else {
                    liveStrokeEnd = location
                }
            case .ended, .cancelled, .failed:
                activeStrokeSources.remove(source)
                guard activeStrokeSources.isEmpty else { return }
                holdWorkItem?.cancel()
                holdWorkItem = nil
                if straightenRequested {
                    applyStraightLineSoon()
                }
            default:
                break
            }
        }

        /// PencilKit meldet während eines stillen Haltens oft kein `.changed`.
        /// Die Pose des Zeichen-Recognizers wird deshalb mitgelesen.
        private func startStillnessSampler() {
            stillnessSampler?.invalidate()
            let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
                self?.sampleStrokeStillness()
            }
            stillnessSampler = timer
            RunLoop.main.add(timer, forMode: .common)
        }

        private func sampleStrokeStillness() {
            guard strokeToolActive, isInkingToolActive, let canvasView else { return }
            let recognizer = canvasView.drawingGestureRecognizer
            guard recognizer.state == .began || recognizer.state == .changed else { return }
            let location = recognizer.location(in: canvasView)
            guard location.x.isFinite, location.y.isFinite else { return }
            activeStrokeSources.insert("sample")
            let moved = hypot(location.x - holdAnchor.x, location.y - holdAnchor.y) > 12
            let grew = strokeGrew()
            if moved || grew {
                holdAnchor = location
                liveStrokeEnd = location
                stillStrokeEnd = currentStrokeEnd()
                lastSignificantMovement = Date()
                // Weitergezeichnet: Vorschau verwerfen.
                clearStraightPreview()
                straightenRequested = false
                straightenUntil = nil
                scheduleHoldCheck()
            } else {
                liveStrokeEnd = location
                if holdWorkItem == nil {
                    scheduleHoldCheck()
                }
            }
        }

        private func strokeGrew() -> Bool {
            guard let canvasView else { return false }
            let drawing = canvasView.drawing
            guard drawing.strokes.count > strokeCountAtToolBegin,
                  let stroke = drawing.strokes.last else { return false }
            let count = stroke.path.count
            if count > lastObservedPointCount + 1 {
                lastObservedPointCount = count
                return true
            }
            lastObservedPointCount = count
            return false
        }

        private func currentStrokeEnd() -> CGPoint? {
            guard let canvasView else { return nil }
            let drawing = canvasView.drawing
            guard drawing.strokes.count > strokeCountAtToolBegin,
                  let stroke = drawing.strokes.last else { return nil }
            let path = stroke.path
            guard path.count >= 1 else { return nil }
            return path[path.index(before: path.endIndex)].location
        }

        private func scheduleHoldCheck() {
            holdWorkItem?.cancel()
            let item = DispatchWorkItem { [weak self] in
                guard let self, !self.activeStrokeSources.isEmpty, self.isInkingToolActive else { return }
                self.straightenRequested = true
                // PencilKit übernimmt den Strich oft erst beim Loslassen.
                // Das Fenster bleibt kurz offen, damit ein späteres Commit
                // die Gerade nicht wieder mit der Kurve überschreibt.
                self.straightenUntil = Date().addingTimeInterval(0.45)
                // Apple Pencil Pro vibriert zur Bestätigung des Einrastens.
                self.playSnapFeedback()
                // Die gerade Linie ersetzt den Strich SOFORT – noch während
                // der Stift gehalten wird. Die alte, schräge Linie wird damit
                // ausgeblendet, statt neben der geraden Linie weiterzuzeigen.
                // Falls PencilKit den live gezogenen Strich erst beim
                // Loslassen in `drawing` übernimmt, greifen die verzögerten
                // Nachführungen im `straightenUntil`-Fenster.
                self.showStraightPreview()
                self.applyStraightLineSoon()
            }
            holdWorkItem = item
            DispatchQueue.main.asyncAfter(
                deadline: .now() + PencilKitCanvasRepresentable.straightLineHoldDuration,
                execute: item
            )
        }

        // MARK: - Live-Vorschau der geraden Linie

        /// Zeichnet die gerade Linie als eigene, dünne Ebene über der
        /// Zeichenfläche – mit Farbe und Dicke des aktiven Werkzeugs.
        private func showStraightPreview() {
            guard let canvasView,
                  let start = liveStrokeStart,
                  let end = liveStrokeEnd ?? stillStrokeEnd else { return }
            let length = hypot(end.x - start.x, end.y - start.y)
            guard length.isFinite, length >= 12 else { return }

            let layer = straightPreviewLayer ?? CAShapeLayer()
            let path = UIBezierPath()
            path.move(to: start)
            path.addLine(to: end)

            layer.path = path.cgPath
            layer.strokeColor = previewStrokeColor.cgColor
            layer.fillColor = UIColor.clear.cgColor
            layer.lineWidth = previewStrokeWidth
            layer.lineCap = .round
            layer.lineJoin = .round
            layer.opacity = 1
            if layer.superlayer == nil {
                canvasView.layer.addSublayer(layer)
            }
            straightPreviewLayer = layer
        }

        private var previewStrokeColor: UIColor {
            switch parent.toolSelection {
            case .pen(let color):
                return color
            case .marker(let color):
                // Textmarker wird von PencilKit halbtransparent gezeichnet.
                return color.withAlphaComponent(0.55)
            case .eraser, .lasso, .text:
                return UIColor.black
            }
        }

        private var previewStrokeWidth: CGFloat {
            switch parent.toolSelection {
            case .pen:
                return max(2, parent.penWidth)
            case .marker:
                return max(4, parent.markerWidth)
            case .eraser, .lasso, .text:
                return max(2, parent.penWidth)
            }
        }

        /// Blendet die Vorschau aus. `delayed` überbrückt den Moment, in dem
        /// PencilKit den echten Strich erst beim Loslassen übernimmt.
        private func clearStraightPreview(delayed: Bool = false) {
            previewClearWorkItem?.cancel()
            previewClearWorkItem = nil
            guard delayed else {
                straightPreviewLayer?.removeFromSuperlayer()
                straightPreviewLayer = nil
                return
            }
            let item = DispatchWorkItem { [weak self] in
                self?.straightPreviewLayer?.removeFromSuperlayer()
                self?.straightPreviewLayer = nil
            }
            previewClearWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: item)
        }

        private func applyStraightLineSoon() {
            straightenLastStrokeIfRequested()
            DispatchQueue.main.async { [weak self] in
                self?.straightenLastStrokeIfRequested()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                self?.straightenLastStrokeIfRequested()
            }
        }

        /// Haptik: Mit `view:` erzeugt der Apple Pencil Pro die Vibration selbst
        /// (iOS 17.5+), sonst vibriert das Gerät.
        private func playSnapFeedback() {
            let generator: UIImpactFeedbackGenerator
            if let existing = snapFeedbackGenerator {
                generator = existing
            } else if #available(iOS 17.5, *), let canvasView {
                generator = UIImpactFeedbackGenerator(style: .rigid, view: canvasView)
            } else {
                generator = UIImpactFeedbackGenerator(style: .rigid)
            }
            snapFeedbackGenerator = generator
            generator.prepare()
            generator.impactOccurred(intensity: 1.0)
        }

        /// Ersetzt den zuletzt gezeichneten Strich durch eine gerade Linie von
        /// seinem ersten zu seinem letzten Punkt – gleiche Tinte, gleiche Dicke.
        private func straightenLastStrokeIfRequested() {
            let stillInWindow = straightenUntil.map { $0 > Date() } ?? false
            guard straightenRequested || stillInWindow, let canvasView else { return }

            let drawing = canvasView.drawing
            guard drawing.strokes.count > strokeCountAtToolBegin,
                  let stroke = drawing.strokes.last else { return }
            if isApproximatelyStraight(stroke) {
                straightenRequested = false
                return
            }

            let path = stroke.path
            guard path.count >= 2 else { return }
            let startPoint = path[path.startIndex]
            let endPoint = path[path.index(before: path.endIndex)]
            let start = startPoint.location
            let end = endPoint.location
            let length = hypot(end.x - start.x, end.y - start.y)
            guard length.isFinite, length >= 12 else { return }

            // Mittlere Strichbreite beibehalten, damit die Linie so dick ist
            // wie der ursprüngliche Strich.
            let widths = path.map { $0.size.width }.sorted()
            let medianWidth = widths[widths.count / 2]
            let size = CGSize(width: medianWidth, height: medianWidth)

            let segmentCount = max(2, Int(length / 4))
            var points: [PKStrokePoint] = []
            points.reserveCapacity(segmentCount + 1)
            for index in 0...segmentCount {
                let fraction = CGFloat(index) / CGFloat(segmentCount)
                let location = CGPoint(
                    x: start.x + (end.x - start.x) * fraction,
                    y: start.y + (end.y - start.y) * fraction
                )
                points.append(
                    PKStrokePoint(
                        location: location,
                        timeOffset: TimeInterval(index) * 0.01,
                        size: size,
                        opacity: startPoint.opacity,
                        force: startPoint.force,
                        azimuth: startPoint.azimuth,
                        altitude: startPoint.altitude
                    )
                )
            }

            let newPath = PKStrokePath(controlPoints: points, creationDate: path.creationDate)
            let newStroke = PKStroke(ink: stroke.ink, path: newPath, transform: stroke.transform, mask: nil)

            var strokes = drawing.strokes
            strokes[strokes.count - 1] = newStroke
            let straightened = PKDrawing(strokes: strokes)

            // Externe Änderung: Der Delegate-Callback darf diese Aktion nicht
            // zusätzlich als „Strich-Mutation“ nachtragen.
            markExternalDrawingWrite()
            canvasView.drawing = straightened

            // Die gerade Linie ist ein echter, rückgängig machbarer Schritt:
            // Über die Historie des Overlays (kein Canvas-Undo – der ist
            // deaktiviert) landet die vorherige schräge Linie auf dem
            // Undo-Stack. Ein „Rückgängig“ nach einer geraden Linie stellt
            // deshalb genau die ursprüngliche Kurve wieder her.
            parent.drawing = straightened
            parent.onStrokeMutation()
            parent.onStraightLineSnap()
        }

        private func isApproximatelyStraight(_ stroke: PKStroke?) -> Bool {
            guard let stroke else { return false }
            let path = stroke.path
            guard path.count >= 2 else { return false }
            let start = path[path.startIndex].location
            let end = path[path.index(before: path.endIndex)].location
            let length = hypot(end.x - start.x, end.y - start.y)
            guard length >= 12 else { return false }
            let samples = min(path.count, 8)
            for index in 0..<samples {
                let point = path[path.index(path.startIndex, offsetBy: index * (path.count - 1) / max(1, samples - 1))].location
                let t = ((point.x - start.x) * (end.x - start.x) + (point.y - start.y) * (end.y - start.y)) / (length * length)
                let clamped = min(1, max(0, t))
                let projected = CGPoint(
                    x: start.x + (end.x - start.x) * clamped,
                    y: start.y + (end.y - start.y) * clamped
                )
                if hypot(point.x - projected.x, point.y - projected.y) > 1.6 {
                    return false
                }
            }
            return true
        }

        /// Hover des Apple Pencil: Position und Blickrichtung merken – ganz
        /// ohne SwiftUI-State, damit die vielen Hover-Ereignisse keine
        /// Neuzeichnung auslösen.
        @objc func handlePencilHover(_ recognizer: UIHoverGestureRecognizer) {
            // Beim Hover-Ende kann UIKit eine leere/verschobene Pose liefern.
            // Für Squeeze bleibt die letzte tatsächlich aktive Position erhalten.
            guard recognizer.state == .began || recognizer.state == .changed,
                  let view = recognizer.view else { return }

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
            parent.onCanvasActivity()

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
            parent.onCanvasActivity()
            if externalDrawingWrite {
                // Externe Änderung (Undo/Redo/Reset/gerade Linie): Binding
                // und Historie sind aktuell – kein Write-back, keine
                // „Strich-Mutation“, sonst legt die Historie aus dem
                // Wiederholungs-Zustand einen neuen Eintrag an.
                externalDrawingWrite = false
                return
            }
            if straightenRequested || (straightenUntil.map { $0 > Date() } ?? false) {
                DispatchQueue.main.async { [weak self] in
                    self?.straightenLastStrokeIfRequested()
                }
            }
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
            parent.onCanvasActivity()
            strokeCountAtToolBegin = canvasView.drawing.strokes.count
            strokeToolActive = true
            lastSignificantMovement = Date()
            lastObservedPointCount = 0
            stillStrokeEnd = nil
            clearStraightPreview()
            liveStrokeStart = canvasView.drawingGestureRecognizer.location(in: canvasView)
            liveStrokeEnd = liveStrokeStart
            if isInkingToolActive {
                activeStrokeSources.insert("tool")
                holdAnchor = canvasView.drawingGestureRecognizer.location(in: canvasView)
                scheduleHoldCheck()
                startStillnessSampler()
            }
            DispatchQueue.main.async { [weak self] in
                self?.parent.onCanvasGestureBegan()
            }
        }

        /// Zeichen- oder Radier-Geste beendet (z. B. Radierer automatisch
        /// abwählen, sobald der Stift losgelassen wird).
        public func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
            parent.onCanvasActivity()
            let held = Date().timeIntervalSince(lastSignificantMovement)
            strokeToolActive = false
            activeStrokeSources.remove("tool")
            activeStrokeSources.remove("sample")
            stillnessSampler?.invalidate()
            stillnessSampler = nil
            holdWorkItem?.cancel()
            holdWorkItem = nil
            // Der echte Strich wird gleich ersetzt; die Vorschau bleibt kurz
            // darüber liegen, damit es an dieser Stelle nicht flackert.
            clearStraightPreview(delayed: true)
            liveStrokeStart = nil
            liveStrokeEnd = nil
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                // Der Strich liegt erst beim Loslassen sicher in `drawing`.
                // War der Stift davor lange genug still, wird jetzt geradegezogen.
                let endIsStill: Bool = {
                    guard let end = self.currentStrokeEnd(), let still = self.stillStrokeEnd else { return true }
                    return hypot(end.x - still.x, end.y - still.y) <= 28
                }()
                if held >= PencilKitCanvasRepresentable.straightLineHoldDuration - 0.25,
                   endIsStill,
                   self.isInkingToolActive {
                    let alreadySnapped = self.straightenRequested
                    self.straightenRequested = true
                    self.straightenUntil = Date().addingTimeInterval(0.6)
                    if !alreadySnapped {
                        self.playSnapFeedback()
                    }
                }
                self.straightenLastStrokeIfRequested()
                self.applyStraightLineSoon()
                self.parent.onCanvasGestureEnded()
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
        backgroundScale: Double = NoteBackgroundMetrics.defaultScale,
        clipRect: CGRect? = nil,
        textFontStyle: NoteTextFontStyle = .system
    ) -> UIImage? {
        var contentRect = CGRect.null

        if !drawing.strokes.isEmpty {
            contentRect = drawing.bounds
        }

        for box in textBoxes {
            let boxHeight = estimatedTextBoxHeight(box, fontStyle: textFontStyle)
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

            drawPaperBackground(style: backgroundStyle, scale: backgroundScale, in: renderBounds, context: cgContext)

            if !drawing.strokes.isEmpty {
                // Immer im hellen Erscheinungsbild rendern: Sonst würde
                // PencilKit im Dark Mode schwarze Tinte als weiß ausgeben –
                // unsichtbar auf dem weißen Papier der Vorschau.
                let drawingImage = renderInLightAppearance {
                    drawing.image(from: renderBounds, scale: UIScreen.main.scale)
                }
                drawingImage.draw(in: renderBounds)
            }

            for box in textBoxes {
                guard !box.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    continue
                }
                let font = textFontStyle.uiFont(size: CGFloat(box.fontSize))
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

            let drawingImage = renderInLightAppearance {
                contrastDrawing.image(from: canvasRect, scale: renderScale)
            }
            drawingImage.draw(in: canvasRect)
        }
    }

    /// Führt `work` mit hellem Erscheinungsbild als aktueller Trait-Sammlung
    /// aus. `PKDrawing.image(from:scale:)` richtet sich nach
    /// `UITraitCollection.current` und würde sonst im Dark Mode Farben
    /// umkehren.
    private static func renderInLightAppearance<T>(_ work: () -> T) -> T {
        var result: T?
        UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
            result = work()
        }
        return result!
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
        scale: Double,
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

        let spacing = NoteBackgroundMetrics.spacing(for: style, scale: scale)
        let alpha = NoteBackgroundMetrics.opacity(for: style)
        guard spacing > 0 else {
            context.restoreGState()
            return
        }

        switch style {
        case .blank:
            break
        case .dotted:
            let radius = NoteBackgroundMetrics.dotRadius(scale: scale)
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

/// Eigener Gesture-Recognizer, der ohne Bewegung `.began` erreicht.
/// `UIPanGestureRecognizer` wartet auf einen Translation-Schwellenwert und
/// hat die Stillhalte-Geste für gerade Linien deshalb oft nie gesehen.
///
/// Wichtig: Die Touch-Methoden der UIKit-Superklasse erwarten das Ereignis als
/// **nicht-optionales** `UIEvent`. Wird hier `UIEvent?` deklariert, lässt sich
/// der Parameter nicht mehr an `super` weitergeben („Value of optional type
/// 'UIEvent?' must be unwrapped to a value of type 'UIEvent'“). Der Parameter
/// wird deshalb – wie in `IntentionalFingerTapRecognizer` – nicht-optional
/// deklariert; UIKit liefert bei Gesten immer ein Ereignis mit.
final class StrokeHoldGestureRecognizer: UIGestureRecognizer {
    override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool {
        false
    }

    override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool {
        false
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        state = .began
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        if state == .began || state == .changed {
            state = .changed
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        state = .ended
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        state = .cancelled
    }
}
