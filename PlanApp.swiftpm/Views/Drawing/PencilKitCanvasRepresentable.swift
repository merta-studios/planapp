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
    /// Mehrere Zeichen-Zustände nacheinander als eigene Rückgängig-Schritte
    /// verzeichnen (gerade Linie: erst die schräge Linie, dann das Geradeziehen).
    public let onCommitDrawingSteps: ([PKDrawing]) -> Void

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
        onStraightLineSnap: @escaping () -> Void = {},
        onCommitDrawingSteps: @escaping ([PKDrawing]) -> Void = { _ in }
    ) {
        self.onCommitDrawingSteps = onCommitDrawingSteps
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
            context.coordinator.applyExternalDrawing(drawing)
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
        private var strokeToolActive = false
        private var lastSignificantMovement = Date()
        private var stillnessSampler: Timer?
        /// Beginn des gerade gezogenen Strichs in Zeichenkoordinaten.
        private var liveStrokeStart: CGPoint?
        /// Aktuelles (gehaltenes) Strichende.
        private var liveStrokeEnd: CGPoint?
        /// Erkenner, der die Punkte des aktuellen Strichs mitschreibt.
        private weak var sampleRecognizer: StrokeHoldGestureRecognizer?

        /// Laufende „Gerade Linie“-Sitzung: Ab dem Einrasten ist der schräge
        /// Live-Strich ausgeblendet, die gerade Linie folgt dem Stift, bis er
        /// abgehoben wird.
        private struct StraightSession {
            /// Zeichnung vor dem Strich (ohne den schrägen Live-Strich).
            var base: PKDrawing
            /// Echter PencilKit-Strich, sobald verfügbar. Er bringt die
            /// tatsächlichen Stiftdaten mit (Punktdicken, Neigung, Kraft,
            /// Deckkraft) und ist damit die einzige verlässliche Quelle für
            /// die richtige Strichdicke der geraden Linie.
            var realStroke: PKStroke? = nil
            /// Ersatz aus den Berührungs-Samples, falls PencilKit den
            /// Live-Strich nicht herausgibt – nur für den Rückgängig-Schritt.
            var slanted: PKStroke? = nil
            /// Werkzeugdaten als Rückfall, wenn kein echter Strich vorliegt.
            var ink: PKInk
            var width: CGFloat
            /// Mittlerer Stiftdruck des Strichs: Der nachgebaute Strich soll
            /// so dick sein wie der gezeichnete, und die Dicke hängt (je nach
            /// Tinte) auch am Druck.
            var force: CGFloat = 1
            var start: CGPoint
            var end: CGPoint
            /// Gerade Linie, die gerade in der Zeichenfläche steht.
            var straight: PKStroke? = nil
            /// Zeitpunkt des letzten Aufbaus der geraden Linie.
            var lastStraightBuild: Date = .distantPast
        }
        private var straightSession: StraightSession?

        /// Mindestabstand zwischen zwei Neuaufbauten der geraden Linie. Die
        /// Zeichnung neu zu setzen lässt PencilKit die Fläche neu rendern –
        /// während der Stift noch aufliegt reicht ein ruhiger Takt.
        private static let straightLineRebuildInterval: TimeInterval = 0.05

        /// Solange eine gerade Linie gezogen wird, darf SwiftUI die
        /// Zeichenfläche nicht überschreiben.
        var preservesCanvasDrawing: Bool { straightSession != nil }

        /// Zuletzt **von außen** gesetzte Zeichnung (Undo/Redo/Reset/gerade
        /// Linie). Callbacks, die genau diesen Stand melden, sind kein neuer
        /// Strich und dürfen weder zurückgeschrieben noch als Schritt
        /// verzeichnet werden. Anders als ein einmaliges Flag kann dieser
        /// Vergleich nicht „hängen bleiben“ und den nächsten echten Strich
        /// verschlucken.
        private var lastExternalDrawing: PKDrawing?
        /// Striche, die ein externer Stand (Undo/Redo/„Seite leeren“/Text-
        /// Umwandlung) gerade **entfernt** hat. PencilKit liefert den alten
        /// Stand gelegentlich asynchron nach; dann tauchten rückgängig
        /// gemachte Striche beim nächsten Zeichnen wieder auf. Solche
        /// Rückläufer werden am Canvas verworfen (siehe
        /// `sanitizedAgainstResurrectedStrokes`).
        private var removedByExternalApply: [PKStroke] = []
        /// Anzahl der Striche auf der Zeichenfläche beim Beginn eines Stift-/
        /// Marker-Strichs. Damit lässt sich prüfen, ob PencilKit den neuen
        /// Strich auf einen veralteten Stand (mit rückgängig gemachten
        /// Strichen) gesetzt hat.
        private var pendingInkBeginCount: Int?

        /// Setzt eine Zeichnung von außen – ohne Write-back in die Historie.
        ///
        /// Dabei wird gemerkt, welche Striche dieser Stand **entfernt** hat.
        /// PencilKit kann einen älteren Stand (z. B. den gerade beendeten
        /// Strich über der alten Zeichnung) asynchron nachliefern – ohne diese
        /// Liste tauchten rückgängig gemachte Striche beim nächsten Zeichnen
        /// wieder auf. Ein späteres Redo setzt die Liste passend neu, weil es
        /// gerade nichts entfernt.
        func applyExternalDrawing(_ newDrawing: PKDrawing) {
            // Ein neuer, externer Stand entscheidet selbst über den Inhalt:
            // eine eventuell noch offene Strich-Reparatur ist damit erledigt.
            pendingInkBeginCount = nil
            guard let canvasView else {
                lastExternalDrawing = newDrawing
                return
            }
            let previous = canvasView.drawing
            guard previous != newDrawing else {
                lastExternalDrawing = newDrawing
                return
            }
            lastExternalDrawing = newDrawing
            // Liste der entfernten Striche fortschreiben: neu entfernte kommen
            // hinzu, **bewusst wiederhergestellte** (Redo) fallen heraus. Ohne
            // diese Pflege würde ein per Redo zurückgeholter Strich bei der
            // nächsten Rückläufer-Prüfung fälschlich wieder verworfen.
            var retired = removedByExternalApply.filter { old in
                !newDrawing.strokes.contains { Self.sameStroke($0, old) }
            }
            for removedNow in Self.strokes(in: previous, missingFrom: newDrawing)
            where !retired.contains(where: { Self.sameStroke($0, removedNow) }) {
                retired.append(removedNow)
            }
            removedByExternalApply = retired
            // Läuft gerade das Geradeziehen, wird dessen Basis der neue Stand:
            // Sonst brächte das Abheben des Stifts die eben rückgängig
            // gemachten Striche zurück.
            let needsRebase = straightSession != nil
            canvasView.drawing = newDrawing
            if needsRebase {
                rebaseStraightSession(to: newDrawing)
            }
        }

        /// Schreibt eine Zeichnung in die Fläche, ohne die Undo-Buchhaltung
        /// (entfernte Striche, Sitzungs-Basis) anzufassen. Nur für den
        /// eigenen Neuaufbau der geraden Linie.
        private func writeCanvasDrawingWithoutBookkeeping(_ newDrawing: PKDrawing) {
            lastExternalDrawing = newDrawing
            guard let canvasView else { return }
            if canvasView.drawing != newDrawing {
                canvasView.drawing = newDrawing
            }
        }

        /// Striche aus `drawing`, die in `other` fehlen. Der Vergleich läuft
        /// über eine inhaltliche Signatur (`sameStroke`) statt über
        /// Objektidentität: `PKStroke`-Werte, die PencilKit erneut aus seinem
        /// internen Stand liefert, sind nicht dieselben Instanzen.
        static func strokes(in drawing: PKDrawing, missingFrom other: PKDrawing) -> [PKStroke] {
            guard !drawing.strokes.isEmpty, drawing.strokes.count > other.strokes.count else {
                return []
            }
            return drawing.strokes.filter { candidate in
                !other.strokes.contains { sameStroke($0, candidate) }
            }
        }

        /// Inhaltliche Gleichheit zweier Striche (Tinte, Punktzahl, Endpunkte).
        /// Reicht völlig, um einen Rückläufer desselben Strichs zu erkennen –
        /// und kann einen neu gezeichneten Strich nicht zufällig verschlucken,
        /// weil dessen Punkte nie exakt auf denselben Werten liegen.
        static func sameStroke(_ lhs: PKStroke, _ rhs: PKStroke) -> Bool {
            guard lhs.ink.inkType == rhs.ink.inkType,
                  lhs.ink.color == rhs.ink.color else {
                return false
            }
            let leftPoints = points(of: lhs)
            let rightPoints = points(of: rhs)
            guard leftPoints.count == rightPoints.count, leftPoints.count > 1 else {
                return false
            }
            let tolerance: CGFloat = 0.5
            let sampleIndices = [0, leftPoints.count / 2, leftPoints.count - 1]
            for index in sampleIndices {
                let left = leftPoints[index].location
                let right = rightPoints[index].location
                guard abs(left.x - right.x) <= tolerance,
                      abs(left.y - right.y) <= tolerance else {
                    return false
                }
            }
            return true
        }

        /// Alle Punkte eines PencilKit-Strichs in Reihenfolge.
        static func points(of stroke: PKStroke) -> [PKStrokePoint] {
            var points: [PKStrokePoint] = []
            points.reserveCapacity(stroke.path.count)
            stroke.path.forEach { points.append($0) }
            return points
        }

        /// Der extern gesetzte Stand wird zur neuen Basis einer laufenden
        /// Gerade-Linie-Sitzung. Die gerade Linie selbst bleibt dabei stehen,
        /// die rückgängig gemachten Striche bleiben verschwunden.
        private func rebaseStraightSession(to drawing: PKDrawing) {
            guard var session = straightSession else { return }
            session.base = drawing
            session.realStroke = nil
            session.slanted = nil
            session.straight = nil
            straightSession = session
            rebuildStraightLine(force: true)
        }

        /// Verwirft Striche, die ein externer Stand entfernt hat, aus einem
        /// Canvas-Rückläufer. Alles, was darüber hinaus neu ist (z. B. der
        /// gerade gezeichnete Strich), bleibt erhalten.
        private func sanitizedAgainstResurrectedStrokes(_ drawing: PKDrawing) -> PKDrawing? {
            guard !removedByExternalApply.isEmpty else { return nil }
            let resurrected = drawing.strokes.filter { candidate in
                removedByExternalApply.contains { Self.sameStroke($0, candidate) }
            }
            guard !resurrected.isEmpty else { return nil }
            let kept = drawing.strokes.filter { candidate in
                !removedByExternalApply.contains { Self.sameStroke($0, candidate) }
            }
            guard kept.count != drawing.strokes.count else { return nil }
            return PKDrawing(strokes: kept)
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

        /// PencilKits eigener Zeichen-Recognizer.
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
        /// Ende eines Strichs still, rastet der Strich sofort zur geraden
        /// Linie ein (Pencil Pro vibriert); die Linie folgt dem Stift bis zum
        /// Abheben.
        private func trackStrokeTouch(_ recognizer: UIGestureRecognizer, source: String) {
            guard let canvasView else { return }
            let location = recognizer.location(in: canvasView)
            let isSampleSource = source == "pencil" || source == "finger"

            if var session = straightSession {
                // Während der Vorschau: nur die echten Stift-/Finger-Erkenner
                // zählen. Der abgebrochene PencilKit-Erkenner meldet
                // `.cancelled` – das darf die Linie nicht beenden.
                guard isSampleSource, recognizer === sampleRecognizer else { return }
                switch recognizer.state {
                case .began, .changed:
                    if location.x.isFinite, location.y.isFinite {
                        session.end = location
                        straightSession = session
                        rebuildStraightLine()
                    }
                case .ended, .cancelled, .failed:
                    commitStraightSession()
                default:
                    break
                }
                return
            }

            switch recognizer.state {
            case .began, .changed:
                guard isInkingToolActive else { return }
                if isSampleSource, recognizer.state == .began,
                   let sampler = recognizer as? StrokeHoldGestureRecognizer {
                    sampleRecognizer = sampler
                }
                let wasActive = !activeStrokeSources.isEmpty
                activeStrokeSources.insert(source)
                if !wasActive {
                    holdAnchor = location
                    liveStrokeStart = location
                    liveStrokeEnd = location
                    lastSignificantMovement = Date()
                    scheduleHoldCheck()
                } else if hypot(location.x - holdAnchor.x, location.y - holdAnchor.y) > 12 {
                    // Kleines Stiftzittern setzt den Halt nicht zurück.
                    holdAnchor = location
                    liveStrokeEnd = location
                    lastSignificantMovement = Date()
                    scheduleHoldCheck()
                } else {
                    liveStrokeEnd = location
                }
            case .ended, .cancelled, .failed:
                activeStrokeSources.remove(source)
                guard activeStrokeSources.isEmpty else { return }
                holdWorkItem?.cancel()
                holdWorkItem = nil
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
            guard straightSession == nil, strokeToolActive, isInkingToolActive, let canvasView else { return }
            let recognizer = canvasView.drawingGestureRecognizer
            guard recognizer.state == .began || recognizer.state == .changed else { return }
            let location = recognizer.location(in: canvasView)
            guard location.x.isFinite, location.y.isFinite else { return }
            activeStrokeSources.insert("sample")
            if hypot(location.x - holdAnchor.x, location.y - holdAnchor.y) > 12 {
                holdAnchor = location
                liveStrokeEnd = location
                lastSignificantMovement = Date()
                scheduleHoldCheck()
            } else {
                liveStrokeEnd = location
                if holdWorkItem == nil {
                    scheduleHoldCheck()
                }
            }
        }

        private func scheduleHoldCheck() {
            holdWorkItem?.cancel()
            let item = DispatchWorkItem { [weak self] in
                guard let self, !self.activeStrokeSources.isEmpty, self.isInkingToolActive else { return }
                self.holdWorkItem = nil
                self.beginStraightSession()
            }
            holdWorkItem = item
            DispatchQueue.main.asyncAfter(
                deadline: .now() + PencilKitCanvasRepresentable.straightLineHoldDuration,
                execute: item
            )
        }

        /// Das Einrasten: Haptik am Stift, schräger Live-Strich weg, die
        /// gerade Linie steht sofort in der Zeichenfläche und folgt dem Stift.
        private func beginStraightSession() {
            guard straightSession == nil, let canvasView,
                  let sampler = sampleRecognizer,
                  sampler.state == .began || sampler.state == .changed else { return }
            let samples = sampler.samples
            guard let start = samples.first?.location ?? liveStrokeStart,
                  let end = liveStrokeEnd ?? samples.last?.location else { return }
            let length = hypot(end.x - start.x, end.y - start.y)
            guard length.isFinite, length >= 12 else { return }

            // Wichtig: **vor** dem Verwerfen des Live-Strichs lesen. Solange
            // PencilKit den Strich noch führt, liefert er die echten
            // Stiftdaten (Punktdicken, Neigung, Kraft) – nur damit bekommt
            // die gerade Linie exakt die Dicke eines normalen Strichs.
            let base = parent.drawing
            let realStroke = inProgressStroke(on: canvasView, base: base)
            let (ink, width) = currentInkAndWidth()
            straightSession = StraightSession(
                base: base,
                realStroke: realStroke,
                slanted: realStroke == nil ? makeStroke(from: samples, ink: ink, width: width) : nil,
                ink: ink,
                width: width,
                force: meanForce(of: samples),
                start: start,
                end: end
            )

            // Apple Pencil Pro vibriert zur Bestätigung des Einrastens.
            playSnapFeedback(at: end)

            // Den laufenden PencilKit-Strich verwerfen: Ein kurzes Abschalten
            // des Zeichen-Erkenners bricht ihn ab – die schräge Linie ist
            // sofort weg, nur noch die gerade Linie ist zu sehen. (Läuft
            // aus einem Timer, nicht mitten in einem Touch-Callback.)
            let drawingRecognizer = canvasView.drawingGestureRecognizer
            drawingRecognizer.isEnabled = false
            DispatchQueue.main.async {
                drawingRecognizer.isEnabled = true
            }
            // Falls PencilKit den Strich beim Abbruch doch übernommen hat,
            // verschwindet er mit dem Setzen der geraden Linie. Das Setzen
            // läuft nach demselben Runloop, damit der Abbruch sicher durch ist.
            DispatchQueue.main.async { [weak self] in
                guard let self, self.straightSession != nil else { return }
                self.rebuildStraightLine(force: true)
            }
        }

        /// Stift abgehoben: Zwei echte Rückgängig-Schritte verzeichnen –
        /// erst die komplette (schräge) Linie, dann das Geradeziehen.
        private func commitStraightSession() {
            guard let session = straightSession else { return }
            activeStrokeSources.removeAll()
            holdWorkItem?.cancel()
            holdWorkItem = nil
            liveStrokeStart = nil
            liveStrokeEnd = nil

            // Letzter Aufbau mit dem endgültigen Ende, damit die Linie exakt
            // dort endet, wo der Stift abgehoben wurde.
            rebuildStraightLine(force: true)
            guard let straight = straightSession?.straight else {
                straightSession = nil
                return
            }

            var steps: [PKDrawing] = []
            if let slanted = session.realStroke ?? session.slanted {
                steps.append(PKDrawing(strokes: session.base.strokes + [slanted]))
            }
            let final = PKDrawing(strokes: session.base.strokes + [straight])
            steps.append(final)

            straightSession = nil
            applyExternalDrawing(final)
            parent.onCommitDrawingSteps(steps)
            parent.onStraightLineSnap()
        }

        /// Baut die gerade Linie auf und schreibt sie in die Zeichenfläche.
        ///
        /// Liegt ein echter PencilKit-Strich vor, werden dessen Punkte
        /// übernommen und nur ihre **Position** auf die Gerade gelegt –
        /// Punktdicke, Neigung, Kraft und Deckkraft bleiben unverändert.
        /// PencilKit zeichnet die Linie dadurch genau so dick wie einen
        /// normalen Strich desselben Werkzeugs.
        private func rebuildStraightLine(force: Bool = false) {
            guard let session = straightSession else { return }
            let now = Date()
            if !force,
               now.timeIntervalSince(session.lastStraightBuild) < Self.straightLineRebuildInterval {
                return
            }

            var straight: PKStroke?
            if let realStroke = session.realStroke {
                straight = straightStroke(from: realStroke, start: session.start, end: session.end)
            }
            // Rückfall (auch wenn der echte Strich zu wenige Punkte hat): mit
            // der umgerechneten Punktdicke in der richtigen Strichbreite.
            if straight == nil {
                straight = makeStraightStroke(
                    from: session.start,
                    to: session.end,
                    ink: session.ink,
                    width: session.width,
                    force: session.force
                )
            }

            straightSession?.straight = straight
            straightSession?.lastStraightBuild = now
            guard let straight else { return }
            writeCanvasDrawingWithoutBookkeeping(
                PKDrawing(strokes: session.base.strokes + [straight])
            )
        }

        /// Der Strich, den PencilKit gerade zeichnet – falls die Zeichenfläche
        /// ihn schon führt. Geprüft wird, dass genau ein Strich mehr als im
        /// gespeicherten Stand vorliegt und dass er dort beginnt, wo der
        /// aktuelle Strich begonnen hat.
        private func inProgressStroke(on canvasView: PKCanvasView, base: PKDrawing) -> PKStroke? {
            let strokes = canvasView.drawing.strokes
            guard strokes.count == base.strokes.count + 1,
                  let candidate = strokes.last,
                  let first = strokePoints(of: candidate).first?.location else {
                return nil
            }
            guard let start = liveStrokeStart else { return candidate }
            return hypot(first.x - start.x, first.y - start.y) <= 24 ? candidate : nil
        }

        /// Alle Punkte eines PencilKit-Strichs in Reihenfolge.
        private func strokePoints(of stroke: PKStroke) -> [PKStrokePoint] {
            Self.points(of: stroke)
        }

        /// Legt die Punkte eines echten Strichs auf die Gerade `start` → `end`.
        /// Die Punkte werden dabei gleichmäßig über die Strecke verteilt;
        /// ihre Stiftdaten bleiben erhalten, damit die Linie genau so aussieht
        /// wie der gezeichnete Strich.
        private func straightStroke(from stroke: PKStroke, start: CGPoint, end: CGPoint) -> PKStroke? {
            let points = strokePoints(of: stroke)
            guard points.count >= 2 else { return nil }
            let lastIndex = points.count - 1
            var linePoints: [PKStrokePoint] = []
            linePoints.reserveCapacity(points.count)
            for (index, point) in points.enumerated() {
                let fraction = CGFloat(index) / CGFloat(lastIndex)
                linePoints.append(
                    PKStrokePoint(
                        location: CGPoint(
                            x: start.x + (end.x - start.x) * fraction,
                            y: start.y + (end.y - start.y) * fraction
                        ),
                        timeOffset: point.timeOffset,
                        size: point.size,
                        opacity: point.opacity,
                        force: point.force,
                        azimuth: point.azimuth,
                        altitude: point.altitude
                    )
                )
            }
            let path = PKStrokePath(controlPoints: linePoints, creationDate: Date())
            return PKStroke(ink: stroke.ink, path: path)
        }

        private func currentInkAndWidth() -> (PKInk, CGFloat) {
            if let tool = canvasView?.tool as? PKInkingTool {
                return (PKInk(tool.inkType, color: tool.color), tool.width)
            }
            return (PKInk(.pen, color: .black), max(2, parent.penWidth))
        }

        /// Punktdicke für einen **selbst gebauten** Strich.
        ///
        /// PencilKit zeichnet einen Strichpunkt nicht mit seiner `size`: Stift
        /// und Monoline zeichnen rund `2 × size − 4` breit, der Textmarker
        /// skaliert die beiden Achsen unterschiedlich. Ein nachgebauter Strich
        /// mit `size = Breite` wäre deshalb deutlich zu dünn – vor allem beim
        /// Textmarker. Diese Umkehrung liefert die Punktgröße, die PencilKit
        /// so dick zeichnet wie die eingestellte Breite.
        ///
        /// Zusätzlich gilt das gemessene Verhältnis aus
        /// `DrawingStrokeMetrics.inkWidthMatchFactor`: Ein PencilKit-Strich ist
        /// rund doppelt so dick wie ein aus der Werkzeugbreite berechneter –
        /// die gerade Linie war sonst exakt 50 % zu dünn.
        ///
        /// (Nur der Rückfall, wenn kein echter PencilKit-Strich vorliegt.)
        private func syntheticPointSize(for ink: PKInk, width: CGFloat) -> CGSize {
            let isMarker = ink.inkType == .marker
            let w = max(
                0.5,
                DrawingStrokeMetrics.targetInkWidth(width: width, isMarker: isMarker)
            )
            if isMarker {
                // Breite × 0.4375 und Höhe × 1.225 ergeben die eingezeichnete
                // Dicke – die Umkehrung gleicht das aus.
                return CGSize(width: w / 0.4375, height: w / 1.225)
            }
            // Stift, Monoline und die übrigen Tinten: `size = w/2 + 2`.
            return CGSize(width: w / 2 + 2, height: w / 2 + 2)
        }

        /// Mittlerer Stiftdruck der Samples in der PencilKit-Skala (0 … 2).
        private func meanForce(of samples: [StrokeHoldGestureRecognizer.Sample]) -> CGFloat {
            let forces = samples.map(\.force).filter { $0.isFinite && $0 > 0 }
            guard !forces.isEmpty else { return 1 }
            return min(2, max(0.1, forces.reduce(0, +) / CGFloat(forces.count)))
        }

        private func makeStroke(
            from samples: [StrokeHoldGestureRecognizer.Sample],
            ink: PKInk,
            width: CGFloat
        ) -> PKStroke? {
            guard samples.count >= 2, let firstTime = samples.first?.timestamp else { return nil }
            // Die Dicke kommt aus der eingestellten Werkzeugbreite (siehe
            // `syntheticPointSize`): So dick zeichnet PencilKit einen Strich
            // dieses Werkzeugs. Der Druck wird mit übernommen, damit die
            // nachgebaute Linie genauso dick ist wie die gezeichnete.
            let size = syntheticPointSize(for: ink, width: width)
            let points = samples.map { sample -> PKStrokePoint in
                let force = sample.force.isFinite ? min(2, max(0.1, sample.force)) : 1
                return PKStrokePoint(
                    location: sample.location,
                    timeOffset: max(0, sample.timestamp - firstTime),
                    size: size,
                    opacity: 1,
                    force: force,
                    azimuth: 0,
                    altitude: .pi / 2
                )
            }
            let path = PKStrokePath(controlPoints: points, creationDate: Date())
            return PKStroke(ink: ink, path: path)
        }

        private func makeStraightStroke(
            from start: CGPoint,
            to end: CGPoint,
            ink: PKInk,
            width: CGFloat,
            force: CGFloat = 1
        ) -> PKStroke {
            let length = hypot(end.x - start.x, end.y - start.y)
            let segmentCount = max(2, Int(length / 4))
            let size = syntheticPointSize(for: ink, width: width)
            let strokeForce = force.isFinite ? min(2, max(0.1, force)) : 1
            var points: [PKStrokePoint] = []
            points.reserveCapacity(segmentCount + 1)
            for index in 0...segmentCount {
                let fraction = CGFloat(index) / CGFloat(segmentCount)
                points.append(
                    PKStrokePoint(
                        location: CGPoint(
                            x: start.x + (end.x - start.x) * fraction,
                            y: start.y + (end.y - start.y) * fraction
                        ),
                        timeOffset: TimeInterval(index) * 0.01,
                        size: size,
                        opacity: 1,
                        force: strokeForce,
                        azimuth: 0,
                        altitude: .pi / 2
                    )
                )
            }
            let path = PKStrokePath(controlPoints: points, creationDate: Date())
            return PKStroke(ink: ink, path: path)
        }

        /// Haptik beim Einrasten. Der Apple Pencil Pro vibriert nur über
        /// `UICanvasFeedbackGenerator` (iOS 17.5+) an der Stiftposition –
        /// ein `UIImpactFeedbackGenerator` kommt am Stift nicht an.
        private func playSnapFeedback(at point: CGPoint) {
            guard let canvasView else { return }
            Haptics.pencilFeedback(in: canvasView, at: point)
            let generator = UIImpactFeedbackGenerator(style: .rigid)
            generator.impactOccurred(intensity: 1.0)
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
            if let external = lastExternalDrawing, canvasView.drawing == external {
                // Externe Änderung (Undo/Redo/Reset/gerade Linie): Binding
                // und Historie sind bereits aktuell – kein Write-back.
                return
            }
            if straightSession != nil {
                // Während der geraden Linie entscheidet allein die Sitzung.
                // PencilKit hat den abgebrochenen Strich eventuell doch
                // übernommen: Dann liefert er jetzt die echten Stiftdaten für
                // die gerade Linie und wird anschließend durch sie ersetzt.
                adoptCommittedStroke(from: canvasView)
                return
            }
            // Rückläufer eines älteren Stands (PencilKit liefert den vor dem
            // Undo begonnenen Strich nachträglich über die ganze alte
            // Zeichnung): Die eben rückgängig gemachten Striche werden
            // verworfen, alles wirklich Neue bleibt. Ohne diese Prüfung
            // wanderten sie über das Binding zurück in die Zeichenfläche und
            // tauchten beim nächsten Zeichnen wieder auf.
            if let sanitized = sanitizedAgainstResurrectedStrokes(canvasView.drawing) {
                applyExternalDrawing(sanitized)
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.parent.drawing = sanitized
                    self.parent.onStrokeMutation()
                }
                return
            }
            lastExternalDrawing = nil

            // Hat PencilKit den neuen Strich auf einen veralteten Stand
            // gesetzt (mit bereits rückgängig gemachten Strichen), wird er
            // hier auf den echten Stand (Binding) umgesetzt. Sonst tauchten
            // rückgängig gemachte Striche beim nächsten Zeichnen wieder auf.
            if let begin = pendingInkBeginCount {
                let current = canvasView.drawing
                let added = current.strokes.count - begin
                if added > 0 {
                    pendingInkBeginCount = nil
                    let base = parent.drawing
                    if current.strokes.count != base.strokes.count + added {
                        let repaired = PKDrawing(strokes: base.strokes + current.strokes.suffix(added))
                        applyExternalDrawing(repaired)
                    }
                }
            }

            DispatchQueue.main.async {
                self.parent.drawing = canvasView.drawing
                self.parent.onStrokeMutation()
                self.parent.onUndoAvailable(false)
                self.parent.onRedoAvailable(false)
            }
        }

        /// Übernimmt den von PencilKit abgelegten (schrägen) Strich als echte
        /// Datenquelle für die gerade Linie: Er bleibt der erste
        /// Rückgängig-Schritt und liefert die Punktdicken, mit denen PencilKit
        /// den Strich gezeichnet hat.
        private func adoptCommittedStroke(from canvasView: PKCanvasView) {
            guard let session = straightSession, session.realStroke == nil else { return }
            guard let real = inProgressStroke(on: canvasView, base: session.base) else {
                // Fremder Stand (z. B. die eigene gerade Linie): nichts tun.
                return
            }
            straightSession?.realStroke = real
            straightSession?.slanted = nil
            rebuildStraightLine(force: true)
        }

        /// Zeichen- oder Radier-Geste begonnen. Wird u. a. genutzt, um die
        /// Squeeze-Palette zu schließen, sobald wieder geschrieben wird.
        public func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
            parent.onCanvasActivity()
            if straightSession != nil { return }
            strokeToolActive = true
            lastSignificantMovement = Date()
            // Falls die Fläche (noch) nicht dem echten Stand entspricht, merkt
            // sich die Reparatur oben die Ausgangslage dieses Strichs.
            pendingInkBeginCount = isInkingToolActive ? canvasView.drawing.strokes.count : nil
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
            strokeToolActive = false
            activeStrokeSources.remove("tool")
            activeStrokeSources.remove("sample")
            stillnessSampler?.invalidate()
            stillnessSampler = nil
            if straightSession != nil {
                // Der PencilKit-Strich wurde fürs Geradeziehen abgebrochen;
                // die Linie wird erst beim Abheben des Stifts übernommen.
                return
            }
            holdWorkItem?.cancel()
            holdWorkItem = nil
            liveStrokeStart = nil
            liveStrokeEnd = nil
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
    struct Sample {
        var location: CGPoint
        var force: CGFloat
        var timestamp: TimeInterval
    }

    /// Alle Punkte der aktuellen Berührung (inkl. zusammengefasster Touches),
    /// in Koordinaten der Zeichenfläche. Daraus wird der schräge Strich für
    /// den Rückgängig-Schritt der geraden Linie nachgebaut.
    private(set) var samples: [Sample] = []

    private func record(_ touches: Set<UITouch>, with event: UIEvent, reset: Bool) {
        guard let view, let touch = touches.first else { return }
        if reset { samples.removeAll(keepingCapacity: true) }
        let all = event.coalescedTouches(for: touch) ?? [touch]
        for item in all {
            let normalizedForce: CGFloat = item.maximumPossibleForce > 0
                ? item.force / item.maximumPossibleForce * 2
                : 1
            samples.append(Sample(
                location: item.location(in: view),
                force: normalizedForce,
                timestamp: item.timestamp
            ))
        }
    }

    override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool {
        false
    }

    override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool {
        false
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        record(touches, with: event, reset: true)
        state = .began
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        record(touches, with: event, reset: false)
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
