import SwiftUI
import UIKit
import PencilKit

enum DrawingOverlaySpace {
    static let name = "planapp.drawingOverlay"
}

/// Anker der Tag-Pille. Der Anker liefert den Rahmen der Pille **immer
/// aktuell** in der Koordinatenwelt des Notiz-Overlays – auch wenn die Notiz
/// verschoben, skaliert oder in der Größe verändert wurde. Früher wurde der
/// Rahmen in einem State zwischengespeichert und beim ersten Öffnen der
/// Auswahl deshalb gelegentlich als (0,0) gelesen: Die Auswahl erschien dann
/// oben links am Bildschirmrand.
struct TagPillAnchorPreference: PreferenceKey {
    static var defaultValue: Anchor<CGRect>? = nil
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        if let next = nextValue() {
            value = next
        }
    }
}

/// Sprechblasen-Kontur für die Mini-Tag-Auswahl: abgerundetes Rechteck mit
/// einer kleinen „Zunge“, die auf die Tag-Pille zeigt. Die Zunge sitzt auf
/// der Kante, die zur Pille hin zeigt, und ist dort horizontal zentriert, wo
/// die Pille steht (`tailCenterX`). Die Zunge wird aus dem **vollen** Rahmen
/// gemalt; der eigentliche Inhalt bekommt die Zungenhöhe als Einzug
/// (`bodyRect`), damit Liste und Titel nicht unter der Zunge laufen.
struct TagPickerBubbleShape: Shape {
    var cornerRadius: CGFloat = 18
    var tailWidth: CGFloat = 22
    var tailHeight: CGFloat = 13
    /// Mittelpunkt der Zunge relativ zur Kantenbreite (0…1).
    var tailCenterX: CGFloat = 0.5
    /// `true`: Zunge an der **oberen** Kante (Panel liegt unter der Pille).
    var tailOnTop: Bool = false

    /// Innenfläche ohne Zunge – dort gehört der Content hingepasst.
    func bodyRect(in rect: CGRect) -> CGRect {
        if tailOnTop {
            return CGRect(x: rect.minX, y: rect.minY + tailHeight, width: rect.width, height: max(0, rect.height - tailHeight))
        }
        return CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: max(0, rect.height - tailHeight))
    }

    func path(in rect: CGRect) -> Path {
        let body = bodyRect(in: rect)
        let tailX = rect.minX + rect.width * min(max(tailCenterX, 0.08), 0.92)
        let halfTail = tailWidth / 2
        var path = Path()

        if tailOnTop {
            // Obere Kante mit eingebettetem Dreieck, das nach oben zeigt.
            path.move(to: CGPoint(x: body.minX + cornerRadius, y: body.minY))
            path.addLine(to: CGPoint(x: tailX - halfTail, y: body.minY))
            path.addLine(to: CGPoint(x: tailX, y: rect.minY))
            path.addLine(to: CGPoint(x: tailX + halfTail, y: body.minY))
            path.addLine(to: CGPoint(x: body.maxX - cornerRadius, y: body.minY))
            path.addQuadCurve(
                to: CGPoint(x: body.maxX, y: body.minY + cornerRadius),
                control: CGPoint(x: body.maxX, y: body.minY)
            )
            path.addLine(to: CGPoint(x: body.maxX, y: body.maxY - cornerRadius))
            path.addQuadCurve(
                to: CGPoint(x: body.maxX - cornerRadius, y: body.maxY),
                control: CGPoint(x: body.maxX, y: body.maxY)
            )
            path.addLine(to: CGPoint(x: body.minX + cornerRadius, y: body.maxY))
            path.addQuadCurve(
                to: CGPoint(x: body.minX, y: body.maxY - cornerRadius),
                control: CGPoint(x: body.minX, y: body.maxY)
            )
            path.addLine(to: CGPoint(x: body.minX, y: body.minY + cornerRadius))
            path.addQuadCurve(
                to: CGPoint(x: body.minX + cornerRadius, y: body.minY),
                control: CGPoint(x: body.minX, y: body.minY)
            )
        } else {
            // Untere Kante mit Dreieck, das nach unten zeigt.
            path.move(to: CGPoint(x: body.minX + cornerRadius, y: body.minY))
            path.addLine(to: CGPoint(x: body.maxX - cornerRadius, y: body.minY))
            path.addQuadCurve(
                to: CGPoint(x: body.maxX, y: body.minY + cornerRadius),
                control: CGPoint(x: body.maxX, y: body.minY)
            )
            path.addLine(to: CGPoint(x: body.maxX, y: body.maxY - cornerRadius))
            path.addQuadCurve(
                to: CGPoint(x: body.maxX - cornerRadius, y: body.maxY),
                control: CGPoint(x: body.maxX, y: body.maxY)
            )
            path.addLine(to: CGPoint(x: tailX + halfTail, y: body.maxY))
            path.addLine(to: CGPoint(x: tailX, y: rect.maxY))
            path.addLine(to: CGPoint(x: tailX - halfTail, y: body.maxY))
            path.addLine(to: CGPoint(x: body.minX + cornerRadius, y: body.maxY))
            path.addQuadCurve(
                to: CGPoint(x: body.minX, y: body.maxY - cornerRadius),
                control: CGPoint(x: body.minX, y: body.maxY)
            )
            path.addLine(to: CGPoint(x: body.minX, y: body.minY + cornerRadius))
            path.addQuadCurve(
                to: CGPoint(x: body.minX + cornerRadius, y: body.minY),
                control: CGPoint(x: body.minX, y: body.minY)
            )
        }
        path.closeSubpath()
        return path
    }
}

private struct DrawingViewport {
    let size: CGSize
    let safeAreaInsets: EdgeInsets

    private let margin: CGFloat = 14

    var bounds: CGRect {
        // Auch bei der auf die obere Bildschirmhälfte verkleinerten Notiz
        // bleibt die Kopfzeile unter der Werkzeugleiste (40 pt + 2 × 8 pt).
        let top = max(12, safeAreaInsets.top + 8) + 56 + margin
        return CGRect(
            x: safeAreaInsets.leading + margin,
            y: top,
            width: max(1, size.width - safeAreaInsets.leading - safeAreaInsets.trailing - (margin * 2)),
            height: max(1, size.height - top - safeAreaInsets.bottom - margin)
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
    /// Die zuletzt gewählten Tintenfarben gehören zum gemeinsamen Zustand der
    /// normalen Toolbar und der Apple-Pencil-Squeeze-Bar. Ein Werkzeugwechsel
    /// darf diese Auswahl nicht wieder auf den ersten Slot zurücksetzen.
    @State private var preferredPenColorHex = "#1E1E1E"
    @State private var preferredMarkerColorHex = "#FFE633"
    @State private var penWidth: CGFloat = 3.5
    @State private var markerWidth: CGFloat = 16
    @State private var eraserWidth: CGFloat = 24
    @State private var canvasView: PKCanvasView?
    @State private var noteBackgroundStyle: NoteBackgroundStyle = .blank
    /// Größe des Hintergrund-Musters dieser Notiz (1 = Standard).
    @State private var noteBackgroundScale: Double = NoteBackgroundMetrics.defaultScale
    /// Tag dieser Notiz (nur mit aktivem Tag-System).
    @State private var noteTagID: UUID? = nil
    @State private var isTagPickerPresented = false
    /// Größen-Animation der Mini-Tag-Auswahl: Das Fenster wächst aus der
    /// Tag-Pille heraus und schrumpft wieder dorthin – statt ein-/auszublenden.
    @State private var isTagPickerExpanded = false
    @State private var tagPickerCloseWorkItem: DispatchWorkItem? = nil
    /// Farbe neuer Textfelder (iPhone: die Farb-Slots sind Textfarben).
    @State private var preferredTextColorHex = NoteTextBox.defaultColorHex
    /// Bestätigung vor dem Einfügen einer kopierten Notiz.
    @State private var showPasteConfirmation = false

    /// iPhone: keine Apple-Pencil-Werkzeuge, nur Lasso/Text/Radierer per Finger.
    private let isPhoneLayout = DeviceLayout.isPhone

    // Squeeze-Palette (Apple Pencil Pro): abgerundete Bogen-Werkzeugleiste
    // an der letzten Hover-Position des Stifts.
    @State private var isSqueezePaletteVisible = false
    @State private var squeezeAnchor: CGPoint? = nil
    @State private var squeezeDirection = CGVector(dx: 0, dy: -1)
    @State private var drawingInputActivity = DrawingInputActivity()
    /// Zuletzt benutztes Werkzeug außer dem Radierer – dorthin wechselt die
    /// App nach dem Radieren automatisch zurück (Fallback: Stift).
    @State private var lastInkingTool: DrawingToolSelection? = nil
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
    /// Eigene History, damit Undo/Redo die Auto-Schließung überlebt und der
    /// Scrubber die Schrittzahl kennt.
    @State private var editingHistory = NoteEditingHistory(
        current: NoteHistorySnapshot(drawingData: Data(), textBoxes: [])
    )
    @State private var isApplyingHistory = false
    /// Löscht das `isApplyingHistory`-Fenster. Bewusst länger als ein
    /// Runloop: Der Canvas-Delegate-Callback auf ein von außen gesetztes
    /// `canvasView.drawing` kann asynchron ankommen und würde andernfalls
    /// den wiederhergestellten Zustand als „neuen Strich“ in die Historie
    /// legen – das leerte unter anderem den Redo-Stack und machte
    /// „Wiederholen“ (auch im Scrubber) unmöglich.
    @State private var historyApplyWindowWorkItem: DispatchWorkItem?
    @State private var historyRevision: Int = 0
    @State private var undoScrubSession: UndoScrubSession? = nil
    /// Mitaddierte Drehung des runden Scrubbers. Bewusst als Referenz (kein
    /// Neuzeichnen bei jeder Bewegung) und außerhalb der Session, damit der
    /// Winkel auch dann erhalten bleibt, wenn ein Sample noch keinen neuen
    /// Schritt auslöst – sonst ließe sich der Knopf der Kreis-Bar nicht ziehen.
    @State private var undoScrubRotation = UndoScrubRotationTracker()
    /// Taktgeber für die einzeln angewandten Scrub-Schritte. Während der Knopf
    /// zum Finger gleitet, wandert die Anwendung Schritt für Schritt hinterher.
    @State private var scrubStepWorkItem: DispatchWorkItem? = nil
    @State private var overlayWindowOrigin: CGPoint = .zero
    @State private var overlaySize: CGSize = .zero

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
    /// Eigener Zustand nur für die Abdunkelung des Hintergrunds. Sie wird beim
    /// Schließen **sofort** und in einer eigenen, kurzen Animation ausgelassen
    /// – unabhängig davon, wie lange der Hero-Morph zurück zum Block dauert.
    @State private var isBackdropVisible = false
    @State private var showsEditor = false
    @State private var didInitialize = false
    /// Aktuell von der Systemtastatur verdeckte Höhe am unteren Rand.
    @State private var systemKeyboardCoveredHeight: CGFloat = 0

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

    private var isUndoScrubbing: Bool { undoScrubSession != nil }

    public var body: some View {
        let display = viewModel.resolveSubjectDisplay(for: lesson)

        GeometryReader { geometry in
            let viewport = DrawingViewport(
                size: geometry.size,
                safeAreaInsets: geometry.safeAreaInsets
            )

            // Ein Tipp, der bei offener Palette beginnt, schließt nur diese –
            // selbst wenn ein weiterer Observer sie im selben Event ausblendet.
            let dismissesPaletteOnly = isSqueezePaletteVisible

            ZStack {
                // Nur ein gezielter Ein-Finger-Tipp auf den abgedunkelten
                // Hintergrund schließt die Notiz. Große Handballen-Kontakte,
                // mehrere Finger und Pencil-Touches werden vom UIKit-Recognizer
                // verworfen; während eines Strichs ist das Schließen gesperrt.
                ZStack {
                    // Die Abdunkelung besteht aus zwei Ebenen:
                    // * eine reine Schwarz-Ebene (ganz normal animierbar), und
                    // * das Blur-Material als **eigene** Ansicht, die nur
                    //   existiert, solange abgedunkelt wird.
                    //
                    // Früher lag das Material als `.ultraThinMaterial.opacity(…)`
                    // im Hintergrund derselben Farbe. Ein Material ist aber
                    // keine animierbare Schicht: Beim Schließen der Notiz blieb
                    // der milchige Schleier über der ganzen App stehen – im
                    // Modus „Nur Notizen“ sah der Bildschirm danach leer aus,
                    // obwohl die Notizen längst zurückgeglitten waren.
                    Color.black
                        .opacity(isBackdropVisible ? 0.58 : 0)
                        .allowsHitTesting(false)

                    if isBackdropVisible {
                        Rectangle()
                            .fill(.ultraThinMaterial)
                            .transition(.opacity)
                            .allowsHitTesting(false)
                    }

                    PalmSafeBackdropDismissView(
                        isEnabled: isExpanded && showsEditor && !isMovingFromHeader && !isResizing,
                        // Auch ein bewusster Apple-Pencil-Tipp an der Seite
                        // schließt die Notiz – die Handballenerkennung bleibt
                        // unverändert streng (Radius, Dauer, Bewegung,
                        // Mehrfachkontakte, Zeichen-Cooldown).
                        allowsPencilTap: true,
                        canDismiss: {
                            let state = canvasView?.drawingGestureRecognizer.state
                            return drawingInputActivity.permitsBackdropTap(
                                toolIsActive: state == .began || state == .changed
                            )
                        },
                        onDismiss: {
                            if dismissesPaletteOnly {
                                dismissSqueezePalette()
                            } else {
                                saveAndDismiss()
                            }
                        }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .ignoresSafeArea()

                editorPanel(
                    display: display,
                    viewport: viewport
                )
                .zIndex(10)

                editorToolbar(viewport: viewport)
                    .opacity(showsEditor ? 1 : 0)
                    // Hit-Testing nicht während des Scrubs abschalten: sonst bricht
                    // UIKit den Kontakt ab, sobald der Finger die Taste verlässt.
                    .allowsHitTesting(showsEditor)
                    .zIndex(20)

                // Squeeze des Apple Pencil Pro: abgerundete Bogen-Palette an
                // der letzten Hover-Position des Stifts.
                if let undoScrubSession {
                    UndoScrubOverlay(session: undoScrubSession, appliedOffset: undoScrubSession.currentOffset)
                        .zIndex(40)
                        .transition(.opacity)
                }

                if isSqueezePaletteVisible, let anchor = squeezeAnchor {
                    PencilSqueezePaletteView(
                        anchor: anchor,
                        direction: squeezeDirection,
                        containerSize: geometry.size,
                        containerOrigin: geometry.frame(in: .named(GlobalCoordinateSpace.name)).origin,
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
                        preferredPenColorHex: preferredPenColorHex,
                        preferredMarkerColorHex: preferredMarkerColorHex,
                        selectedTextColorHex: activeTextBoxColorHex,
                        onApplyColorToSelectedText: { hex in
                            applyColorToSelectedTextBox(hex)
                        },
                        onUndo: { performUndo() },
                        undoCount: editingHistory.undoCount,
                        redoCount: editingHistory.redoCount,
                        historyRevision: historyRevision,
                        onUndoScrubBegan: { buttonCenter, circleCenter, intendedRadius in
                            beginCircularUndoScrub(
                                buttonWindowOrigin: buttonCenter,
                                circleCenterInGlobal: circleCenter,
                                intendedRadius: intendedRadius
                            )
                        },
                        onUndoScrubChanged: { _, windowLocation in
                            updateCircularUndoScrub(windowLocation: windowLocation)
                        },
                        onUndoScrubEnded: { endUndoScrub() },
                        hidesNonUndoElements: isUndoScrubbing
                    )
                    .zIndex(30)
                    .transition(.opacity)
                }
            }
            .coordinateSpace(name: DrawingOverlaySpace.name)
            // Die Tag-Auswahl hängt direkt am echten Rahmen der Tag-Pille:
            // Sie taucht dort auf, wo der Tag steht, und wird beim Öffnen und
            // Schließen von genau diesem Punkt aus skaliert.
            .overlayPreferenceValue(TagPillAnchorPreference.self) { anchor in
                GeometryReader { proxy in
                    if isTagPickerPresented, let anchor {
                        tagPickerOverlay(
                            containerSize: proxy.size,
                            pillFrame: proxy[anchor]
                        )
                    }
                }
            }
            .background {
                ZStack {
                    DrawingFingerTapObserver(isEnabled: isSqueezePaletteVisible) {
                        dismissSqueezePalette()
                    }
                    // Merkt sich die Stiftposition im ganzen Fenster: Nur so kann
                    // die Werkzeugwahl in der Leiste und in der Kreis-Bar an der
                    // Stiftspitze vibrieren (Apple Pencil Pro).
                    PencilHoverLocationObserver(isEnabled: true)
                }
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)
            }
            .onAppear {
                configureTextUndo()
                applyDrawingDefaults()
                loadExistingNote()
                overlayWindowOrigin = geometry.frame(in: .global).origin
                heroSourceFrame = localizedHeroFrame(
                    windowFrame: viewModel.activeNoteSourceFrame,
                    overlayOrigin: overlayWindowOrigin
                )

                // Wait one layout pass so saved height and safe-area dimensions
                // are both present before calculating the initial fit.
                DispatchQueue.main.async {
                    overlayWindowOrigin = geometry.frame(in: .global).origin
                    heroSourceFrame = localizedHeroFrame(
                        windowFrame: viewModel.activeNoteSourceFrame,
                        overlayOrigin: overlayWindowOrigin
                    )
                    initializeTransform(in: viewport)
                    didInitialize = true

                    let canMorph = HeroTransitionPolicy.isPlausibleSourceFrame(
                        x: heroSourceFrame.minX,
                        y: heroSourceFrame.minY,
                        width: heroSourceFrame.width,
                        height: heroSourceFrame.height
                    )

                    // isExpanded fades the card to grey while heroBlend morphs
                    // the panel's size and position from the tapped card to the
                    // centered, fully expanded note in the very same animation.
                    if canMorph {
                        heroBlend = 0
                        withAnimation(.spring(response: 0.48, dampingFraction: 0.85)) {
                            isExpanded = true
                            isBackdropVisible = true
                            heroBlend = 1
                        }
                    } else {
                        heroBlend = 1
                        withAnimation(.spring(response: 0.48, dampingFraction: 0.85)) {
                            isExpanded = true
                            isBackdropVisible = true
                        }
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.36) {
                        withAnimation(.easeOut(duration: 0.18)) {
                            showsEditor = true
                        }
                    }
                }
            }
            .onChange(of: geometry.size) { _, newSize in
                overlayWindowOrigin = geometry.frame(in: .global).origin
                overlaySize = newSize
                guard didInitialize else { return }
                normalizeTransform(in: viewport)
            }
            .onAppear {
                overlaySize = geometry.size
            }
            // Die Systemtastatur verändert weder Safe Area noch Größe der
            // Zeichenfläche (`ignoresSafeArea(.keyboard)`). Die Notiz behält
            // beim Tippen Größe und Position. Einzige Ausnahme: Steht das
            // gerade bearbeitete Textfeld hinter der Tastatur, wird die Notiz
            // so weit nach oben geschoben, dass das Feld sichtbar ist – ohne
            // Skalierung.
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { notification in
                systemKeyboardCoveredHeight = Self.keyboardCoveredHeight(from: notification)
                guard systemKeyboardCoveredHeight > 0, didInitialize else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    revealEditingTextBox(in: viewport)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                systemKeyboardCoveredHeight = 0
            }
            .onChange(of: editingTextBoxID) { _, _ in
                revealEditingTextBox(in: viewport)
            }
            .onChange(of: toolSelection) { _, newTool in
                // Die Farbquelle ist nicht mehr lokal in einer Toolbar
                // dupliziert. Jeder Weg (normale Toolbar, Squeeze-Bar,
                // Auto-Rückkehr vom Radierer) schreibt hier in denselben
                // bevorzugten Farbzustand.
                switch newTool {
                case .pen(let color):
                    preferredPenColorHex = color.toHex()
                case .marker(let color):
                    preferredMarkerColorHex = color.toHex()
                case .eraser, .lasso, .text:
                    break
                }

                // Letztes Nicht-Radierer-Werkzeug merken – dorthin wechselt die
                // App nach dem Radieren automatisch zurück.
                if case .eraser = newTool {
                    // Radierer selbst ist kein „Rückkehr-Werkzeug“.
                } else {
                    lastInkingTool = newTool
                }
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
        // Kein Platz für die Systemtastatur reservieren: Sie darf die
        // Zeichenfläche nicht verkleinern oder verschieben.
        .ignoresSafeArea(.keyboard, edges: .bottom)
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
                DrawingCanvasBackgroundView(style: noteBackgroundStyle, scale: noteBackgroundScale)
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
                    // iPhone: Es wird mit dem Finger radiert/ausgewählt – die
                    // Pencil-Beschränkung ist dort nie aktiv.
                    pencilOnlyDrawing: isPhoneLayout ? false : viewModel.drawingSettings.applePencilOnly,
                    dynamicPenWidth: viewModel.drawingSettings.dynamicPenWidth,
                    onCanvasCreated: { createdCanvas in
                        canvasView = createdCanvas
                    },
                    onFingerPan: { delta in
                        applyFingerPan(delta, in: viewport)
                    },
                    onStrokeMutation: {
                        lastStrokeMutation = Date()
                        recordHistorySnapshot()
                    },
                    onRequestUndo: {
                        performPencilGesture(viewModel.drawingSettings.doubleTapAction)
                    },
                    onPencilInputDetected: {
                        // Sobald echter Pencil-Input ankommt, wird die allgemeine
                        // Bezeichnung gemerkt und „Nur Apple Pencil“ aktiviert.
                        // (Auf dem iPhone gibt es keinen Apple Pencil.)
                        guard !isPhoneLayout else { return }
                        viewModel.registerObservedApplePencilInput()
                    },
                    onPencilSqueeze: { anchor, direction in
                        viewModel.registerApplePencilSqueeze()
                        performPencilGesture(
                            viewModel.drawingSettings.squeezeAction,
                            paletteAnchor: anchor,
                            paletteDirection: direction
                        )
                    },
                    onCanvasActivity: {
                        drawingInputActivity.record()
                    },
                    onCanvasGestureBegan: {
                        // Sobald wieder geschrieben wird, verschwindet die
                        // Palette – wie bei Apples eigener Kontext-Palette.
                        if isSqueezePaletteVisible {
                            dismissSqueezePalette()
                        }
                    },
                    onCanvasGestureEnded: {
                        handleCanvasGestureEnded()
                    },
                    onCommitDrawingSteps: { steps in
                        commitDrawingSteps(steps)
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
                        recordHistorySnapshot()
                    },
                    newTextColorHex: preferredTextColorHex,
                    newTextFontSize: viewModel.drawingSettings.defaultTextFontSize,
                    textFontStyle: viewModel.drawingSettings.textFontStyle
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
        guard heroBlend < 0.999, isPlausibleHeroFrame(heroSourceFrame), panelHeight > 0 else {
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
        guard heroBlend < 0.999, isPlausibleHeroFrame(heroSourceFrame) else { return target }
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
            // Der aufgeklappte Rahmen verwendet secondarySystemBackground:
            // weißer Text im Dark Mode, schwarzer im Light Mode. Während der
            // Karten-Animation bleibt der Text auf der Fach-Farbe schwarz.
            primaryColor: isExpanded ? .primary : display.color.contrastingTextColor,
            teacherDisplayName: viewModel.resolveTeacherName(lesson.teacherRaw),
            originalTeacherDisplayName: lesson.originalTeacher.map { viewModel.resolveTeacherName($0) },
            accessory: {
                if viewModel.tagSettings.isEnabled && showsEditor {
                    tagAccessory
                }
            }
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
                backgroundScale: $noteBackgroundScale,
                textColorHex: $preferredTextColorHex,
                isPhoneLayout: isPhoneLayout,
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
                undoCount: editingHistory.undoCount,
                redoCount: editingHistory.redoCount,
                historyRevision: historyRevision,
                onUndoScrubBegan: { buttonCenter, _, _ in
                    beginLinearUndoScrub(buttonWindowOrigin: buttonCenter)
                },
                onUndoScrubChanged: { translation, _ in
                    updateLinearUndoScrub(translationY: translation.height)
                },
                onUndoScrubEnded: { endUndoScrub() },
                hidesUndoGlyph: isUndoScrubbing && undoScrubSession?.style == .linear,
                availableWidth: max(
                    1,
                    viewport.size.width - 2 * max(16, viewport.safeAreaInsets.leading + 12)
                ),
                onClear: { clearPage() },
                canCopyNote: hasCopyableContent,
                canPasteNote: viewModel.hasCopiedNote,
                onCopyNote: { copyCurrentNote() },
                onPasteNote: { pasteCopiedNote() }
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

    // MARK: - Textfeld über der Systemtastatur sichtbar halten

    /// Höhe, die die Systemtastatur am unteren Bildschirmrand verdeckt
    /// (0, wenn sie ausgeblendet ist oder frei schwebt). Sie wird nur benutzt,
    /// um ein Textfeld sichtbar zu halten – die Notiz selbst wird dadurch
    /// nicht skaliert.
    private static func keyboardCoveredHeight(from notification: Notification) -> CGFloat {
        guard let frameValue = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else {
            return 0
        }
        let frame = frameValue.cgRectValue
        let screenBounds = UIScreen.main.bounds
        guard frame.width >= screenBounds.width * 0.8 else {
            // Schwebende oder geteilte iPad-Tastatur: verdeckt nichts
            // Vorhersagbares, die Notiz bleibt wo sie ist.
            return 0
        }
        return max(0, screenBounds.maxY - frame.minY)
    }

    private func keyboardCoveredHeight(in viewport: DrawingViewport) -> CGFloat {
        systemKeyboardCoveredHeight
    }

    /// Schiebt die Notiz so weit nach oben, dass das bearbeitete Textfeld
    /// oberhalb der schwebenden Tastatur liegt – ohne Zoom, ohne Skalierung.
    ///
    /// Die Notiz behält damit ihre Größe und ihre Position; nur wenn das
    /// beschriebene Feld sonst hinter der Tastatur läge, rückt sie gerade so
    /// weit hoch, bis das Feld sichtbar ist.
    private func revealEditingTextBox(in viewport: DrawingViewport) {
        guard showsEditor else { return }
        guard let id = editingTextBoxID ?? selectedTextBoxID,
              let box = textBoxes.first(where: { $0.id == id }) else { return }

        let covered = keyboardCoveredHeight(in: viewport)
        guard covered > 0 else { return }

        let keyboardTop = viewport.size.height - covered
        let panelTop = renderCenter(in: viewport).y - (panelHeight * scale / 2)
        let canvasTop = panelTop + headerHeight * scale
        let boxBottom = canvasTop + (CGFloat(box.y) + estimatedTextBoxHeight(box, fontStyle: viewModel.drawingSettings.textFontStyle)) * scale

        let limit = keyboardTop - 16
        guard boxBottom > limit else { return }

        var candidate = offset
        candidate.height = offset.height - (boxBottom - limit)
        offset = clampedOffset(candidate, scale: scale, height: canvasHeight, in: viewport)
    }

    // MARK: - Kombiniertes Undo/Redo (Zeichnung + Textfelder)

    private func configureTextUndo() {
        textUndo.getter = { textBoxes }
        textUndo.drawingSetter = { data in
            let restoredDrawing = (try? PKDrawing(data: data)) ?? PKDrawing()
            // Nur den SwiftUI-Zustand setzen: Die Zeichenfläche übernimmt
            // den Wert über `updateUIView` (einseitiger Schreibweg).
            drawing = restoredDrawing
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
        guard let snapshot = editingHistory.undo() else { return }
        Haptics.tap()
        applyHistorySnapshot(snapshot)
        historyRevision += 1
    }

    private func performRedo() {
        guard let snapshot = editingHistory.redo() else { return }
        Haptics.tap()
        applyHistorySnapshot(snapshot)
        historyRevision += 1
    }

    private func currentHistorySnapshot() -> NoteHistorySnapshot {
        // Bewusst das SwiftUI-`drawing`-Binding statt `canvasView.drawing`:
        // Bei Strichen pflegt der Delegate-Callback das Binding IMMER zuerst
        // und ruft `onStrokeMutation` erst danach auf – das Binding ist hier
        // also immer aktuell. Die Canvas-View dagegen kann asynchron einen
        // Zwischenzustand liefern; ein solcher Wert hätte veraltete
        // Undo-Schritte in die Historie geschrieben (und den Redo-Stack
        // geleert).
        NoteHistorySnapshot(
            drawingData: drawing.dataRepresentation(),
            textBoxes: textBoxes
        )
    }

    private func recordHistorySnapshot() {
        guard !isApplyingHistory, showsEditor else { return }
        editingHistory.record(currentHistorySnapshot())
        historyRevision += 1
    }

    private func applyHistorySnapshot(_ snapshot: NoteHistorySnapshot) {
        isApplyingHistory = true
        historyApplyWindowWorkItem?.cancel()
        // `self` ist ein Struct: normaler Capture, @State-Writer bleibt gültig.
        let window = DispatchWorkItem { [self] in
            isApplyingHistory = false
        }
        historyApplyWindowWorkItem = window
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: window)

        let restoredDrawing = (try? PKDrawing(data: snapshot.drawingData)) ?? PKDrawing()
        drawing = restoredDrawing
        setCanvasDrawing(restoredDrawing)
        // Der Canvas-eigene Undo-Stack ist deaktiviert (siehe
        // `PencilKitCanvasRepresentable`); diese Aufrufe bleiben als
        // Sicherheitsnetz für ältere PencilKit-Versionen.
        canvasView?.undoManager?.removeAllActions()
        textBoxes = snapshot.textBoxes
        if let sel = selectedTextBoxID, !snapshot.textBoxes.contains(where: { $0.id == sel }) {
            selectedTextBoxID = nil
        }
        if let edit = editingTextBoxID, !snapshot.textBoxes.contains(where: { $0.id == edit }) {
            editingTextBoxID = nil
        }
        lastStrokeMutation = Date()
    }

    /// Schreibt eine Zeichnung von außen auf die Zeichenfläche. Über den
    /// Coordinator, damit der folgende Delegate-Callback nicht als neuer
    /// Strich (mit veraltetem Stand) in die Historie zurückläuft.
    private func setCanvasDrawing(_ newDrawing: PKDrawing) {
        if let coordinator = canvasView?.delegate as? PencilKitCanvasRepresentable.Coordinator {
            coordinator.applyExternalDrawing(newDrawing)
        } else {
            canvasView?.drawing = newDrawing
        }
    }

    /// Verzeichnet jeden Zustand als eigenen Rückgängig-Schritt (gerade
    /// Linie: 1. komplette schräge Linie, 2. Geradeziehen).
    private func commitDrawingSteps(_ steps: [PKDrawing]) {
        guard !steps.isEmpty else { return }
        for step in steps {
            drawing = step
            if !isApplyingHistory, showsEditor {
                editingHistory.record(
                    NoteHistorySnapshot(drawingData: step.dataRepresentation(), textBoxes: textBoxes)
                )
            }
        }
        lastStrokeMutation = Date()
        historyRevision += 1
    }

    private func persistEditingHistory() {
        viewModel.saveUndoSession(editingHistory.persistedSession(for: lesson.noteKey))
    }

    private func clearPage() {
        let beforeBoxes = textBoxes
        let beforeDrawing = (canvasView?.drawing ?? drawing).dataRepresentation()

        selectedTextBoxID = nil
        editingTextBoxID = nil
        textBoxes = []

        let emptyDrawing = PKDrawing()
        drawing = emptyDrawing
        setCanvasDrawing(emptyDrawing)
        canvasView?.undoManager?.removeAllActions()
        lastStrokeMutation = .distantPast

        // Ein einziger Undo-Schritt holt Textfelder UND Striche zurück.
        textUndo.push(
            before: NoteUndoSnapshot(textBoxes: beforeBoxes, drawingData: beforeDrawing),
            after: NoteUndoSnapshot(textBoxes: [], drawingData: emptyDrawing.dataRepresentation())
        )
        // Explizit in die Historie – nicht vom asynchronen Delegate-Event
        // abhängen (der doppelte Record wird per Äquivalenz geprüft verworfen).
        recordHistorySnapshot()
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
        recordHistorySnapshot()
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
                backgroundScale: noteBackgroundScale,
                clipRect: canvasRect,
                textFontStyle: viewModel.drawingSettings.textFontStyle
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
        setCanvasDrawing(emptyDrawing)
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
        // Explizit in die Historie (wie bei „Seite leeren“).
        recordHistorySnapshot()
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
        let initialMarkerHex = settings.markerColorSlots.first ?? "#FFE633"
        preferredPenColorHex = initialHex
        preferredMarkerColorHex = initialMarkerHex
        toolSelection = .pen(color: UIColor(hex: initialHex))
        lastInkingTool = toolSelection
        noteBackgroundStyle = settings.defaultBackgroundStyle
        noteBackgroundScale = NoteBackgroundMetrics.clampedScale(settings.defaultBackgroundScale)
        preferredTextColorHex = initialHex

        if isPhoneLayout {
            // iPhone: ohne Apple Pencil startet die Notiz direkt im
            // Text-Werkzeug; Stift und Textmarker gibt es dort nicht.
            toolSelection = .text
            lastInkingTool = .text
        }

        // Entspricht die System-Einstellung „Nur mit Apple Pencil zeichnen“,
        // gilt das als bemerkener Pencil-Input und der Schalter wird – wie vom
        // Nutzer gewünscht – automatisch aktiviert.
        if !isPhoneLayout, UIPencilInteraction.prefersPencilOnlyDrawing {
            viewModel.registerApplePencilUsage()
            toolSelection = .pen(color: UIColor(hex: initialHex))
            lastInkingTool = toolSelection
        }

        canvasHeight = min(
            maximumCanvasHeight,
            max(minimumCanvasHeight, CGFloat(settings.defaultCanvasHeight))
        )
        resizeStartHeight = canvasHeight
    }

    // MARK: - Squeeze-Palette & Radierer-Verhalten

    /// Öffnet die Bogen-Palette an der letzten Hover-Position. Ein erneuter
    /// Squeeze blendet sie wieder aus, statt sie lediglich neu zu positionieren.
    private func presentSqueezePalette(anchor: CGPoint?, direction: CGVector) {
        if isSqueezePaletteVisible {
            dismissSqueezePalette()
            return
        }

        var resolvedAnchor = anchor

        if resolvedAnchor == nil, let canvasView {
            // Keine Hover-Pose verfügbar (älterer Pencil): Bezugspunkt ist der
            // Mittelpunkt der Zeichenfläche.
            let center = CGPoint(x: canvasView.bounds.midX, y: canvasView.bounds.midY)
            resolvedAnchor = canvasView.convert(center, to: nil)
        }

        guard let resolvedAnchor else { return }

        squeezeAnchor = resolvedAnchor
        squeezeDirection = direction
        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
            isSqueezePaletteVisible = true
        }
        Haptics.tap()
    }

    private func dismissSqueezePalette() {
        withAnimation(.easeOut(duration: 0.16)) {
            isSqueezePaletteVisible = false
        }
    }

    /// Nach dem Loslassen des Stifts: Ist der Radierer aktiv und die Einstellung
    /// eingeschaltet, wechselt die App automatisch zurück zum zuletzt benutzten
    /// Werkzeug (Fallback: Stift).
    private func handleCanvasGestureEnded() {
        // Nach dem Zeichnen/Radieren ist die Palette nicht mehr nötig.
        if isSqueezePaletteVisible {
            dismissSqueezePalette()
        }

        guard viewModel.drawingSettings.autoDeselectEraser else { return }
        guard case .eraser = toolSelection else { return }

        let fallbackHex = viewModel.drawingSettings.penColorSlots.first ?? "#1E1E1E"
        toolSelection = lastInkingTool ?? .pen(color: UIColor(hex: fallbackHex))
    }

    private func loadExistingNote() {
        guard let note = viewModel.noteFor(lesson: lesson) else {
            restoreOrBootstrapHistory()
            return
        }

        canvasHeight = max(
            minimumCanvasHeight,
            min(maximumCanvasHeight, CGFloat(note.lineCount) * 56 + headerHeight + 40)
        )
        resizeStartHeight = canvasHeight
        noteBackgroundStyle = note.backgroundStyle
        noteBackgroundScale = NoteBackgroundMetrics.clampedScale(note.backgroundScale)
        noteTagID = viewModel.tagSettings.tag(withID: note.tagID)?.id

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

        restoreOrBootstrapHistory()
    }

    private func restoreOrBootstrapHistory() {
        let current = currentHistorySnapshot()
        if let session = viewModel.persistedUndoSession(for: lesson.noteKey) {
            editingHistory.restore(
                PersistedNoteUndoSession(
                    noteKey: session.noteKey,
                    undoStack: session.undoStack,
                    redoStack: session.redoStack,
                    current: current,
                    updatedAt: session.updatedAt
                )
            )
        } else {
            editingHistory.bootstrap(current)
        }
        historyRevision += 1
    }

    private func saveAndDismiss() {
        guard viewModel.isDrawingOverlayPresented, isExpanded else { return }
        dismissSqueezePalette()

        // Erst die Bearbeitung beenden: Dadurch gibt das UIKit-Textfeld den
        // First Responder ab und verwirft eine evtl. offene Fokus-Anfrage,
        // bevor die Overlay-Hierarchie abgebaut wird. Sonst könnte nach dem
        // Schließen noch eine Tastatur aufspringen.
        selectedTextBoxID = nil
        editingTextBoxID = nil

        persistEditingHistory()

        let currentDrawing = canvasView?.drawing ?? drawing
        // Immer die bekannte Papiergröße verwenden – `PKCanvasView.bounds`
        // kann beim ersten Öffnen noch winzig oder 0 sein und hat dann die
        // Vorschau im Stundenblock komisch klein gerendert.
        let canvasSize = CGSize(
            width: paperWidth,
            height: max(180, canvasHeight - headerHeight)
        )
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
            backgroundScale: noteBackgroundScale,
            clipRect: canvasRect,
            textFontStyle: viewModel.drawingSettings.textFontStyle
        )
        let drawingData = croppedDrawing.dataRepresentation()
        let calculatedLines = max(3, min(10, Int((canvasHeight - headerHeight) / 56)))
        let backgroundScale = noteBackgroundScale
        let tagID = noteTagID

        withAnimation(.easeOut(duration: 0.12)) {
            showsEditor = false
        }
        // Erst die Abdunkelung – in einer eigenen, kurzen Animation. So kann
        // sie nicht als Schleier stehen bleiben, falls der Hero-Morph
        // (Abbrechen, App-Wechsel, Moduswechsel) nicht zu Ende läuft.
        withAnimation(.easeOut(duration: 0.18)) {
            isBackdropVisible = false
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
                backgroundStyle: noteBackgroundStyle,
                backgroundScale: backgroundScale,
                tagID: tagID
            )
        }
    }

    // MARK: - Tag der Notiz

    /// Pille neben dem Fachnamen: „+ Tag hinzufügen“ oder der gesetzte Tag.
    /// Ein Tipp öffnet die kleine Auswahl; dort lässt sich der Tag wechseln
    /// oder entfernen.
    private var tagAccessory: some View {
        Button {
            Haptics.tap()
            presentTagPicker()
        } label: {
            if let tag = viewModel.tagSettings.tag(withID: noteTagID) {
                NoteTagPill(tag: tag, size: .regular)
            } else {
                AddTagPill(size: .regular)
            }
        }
        .buttonStyle(.plain)
        .anchorPreference(key: TagPillAnchorPreference.self, value: .bounds) { $0 }
    }

    private func presentTagPicker() {
        tagPickerCloseWorkItem?.cancel()
        tagPickerCloseWorkItem = nil
        if isTagPickerPresented {
            // Das Fenster hängt noch (gerade am Schrumpfen): direkt aus dem
            // aktuellen Zustand wieder aufwachsen. `onAppear` käme hier nicht
            // erneut, das Fenster bliebe sonst winzig stehen.
            withAnimation(.spring(response: 0.34, dampingFraction: 0.80)) {
                isTagPickerExpanded = true
            }
            return
        }
        // Erst winzig an der Pille einhängen; das Aufwachsen übernimmt
        // `onAppear` des Panels (siehe `tagPickerOverlay`). So ist es wirklich
        // eine Größen-Animation aus der Pille heraus – kein Ein-/Ausblenden.
        isTagPickerPresented = true
        isTagPickerExpanded = false
    }

    private func dismissTagPicker() {
        guard isTagPickerPresented else { return }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
            isTagPickerExpanded = false
        }
        tagPickerCloseWorkItem?.cancel()
        let item = DispatchWorkItem {
            guard !isTagPickerExpanded else { return }
            isTagPickerPresented = false
        }
        tagPickerCloseWorkItem = item
        // Nach der Schrumpf-Animation wird das Fenster abgebaut.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24, execute: item)
    }

    /// Kleine Tag-Auswahl direkt an der Tag-Pille. `pillFrame` kommt aus dem
    /// Anker der Pille und ist damit immer korrekt – auch nach Verschieben
    /// oder Skalieren der Notiz. Öffnen und Schließen skalieren von der Pille
    /// aus (Rein- und Raus-Animation), statt einfach zu überblenden.
    @ViewBuilder
    private func tagPickerOverlay(containerSize: CGSize, pillFrame: CGRect) -> some View {
        let contentHeight = 120 + CGFloat(max(1, viewModel.tagSettings.tags.count)) * 62
            + (noteTagID == nil ? 0 : 56)
        // Extra-Zeile für die Sprechblasen-Zunge, damit der Panel-Rahmen
        // Inhalt UND Zunge fasst.
        let tailHeight: CGFloat = 13
        let frame = InteractionPolicies.tagPickerFrame(
            buttonMinX: Double(pillFrame.minX),
            buttonMaxX: Double(pillFrame.maxX),
            buttonMinY: Double(pillFrame.minY),
            buttonMaxY: Double(pillFrame.maxY),
            containerWidth: Double(containerSize.width),
            containerHeight: Double(containerSize.height),
            contentHeight: Double(contentHeight) + Double(tailHeight)
        )
        let panel = CGRect(x: frame.x, y: frame.y, width: frame.width, height: frame.height)
        // `placesBelow` = Panel liegt UNTER der Pille → Zunge zeigt nach oben.
        let tailOnTop = frame.placesBelow
        let tailCenterX = panel.width > 0
            ? min(max((pillFrame.midX - panel.minX) / panel.width, 0.08), 0.92)
            : 0.5
        let bubble = TagPickerBubbleShape(
            cornerRadius: 18,
            tailWidth: 22,
            tailHeight: tailHeight,
            tailCenterX: tailCenterX,
            tailOnTop: tailOnTop
        )
        // Innenfläche in den LOKALEN Koordinaten des Panels: Das Panel wird
        // selbst schon per `.offset` platziert. Mit `bodyRect(in: panel)`
        // wurde der Inhalt doppelt verschoben – Tags und „Tag entfernen“
        // rutschten dadurch aus dem Fenster.
        let bodyRect = bubble.bodyRect(in: CGRect(origin: .zero, size: panel.size))

        ZStack(alignment: .topLeading) {
            Color.black.opacity(0.001)
                .contentShape(Rectangle())
                .allowsHitTesting(isTagPickerExpanded)
                .onTapGesture {
                    dismissTagPicker()
                }

            // Panel = Sprechblase (Kontur inkl. Zunge) mit Inhalt in der
            // Zungenfreien Innenfläche.
            ZStack(alignment: .topLeading) {
                bubble
                    .fill(.regularMaterial)
                    .shadow(color: Color.black.opacity(0.18), radius: 16, x: 0, y: 8)

                bubble
                    .stroke(Color.primary.opacity(0.10), lineWidth: 1)

                NoteTagPickerView(
                    tags: viewModel.tagSettings.tags,
                    selectedTagID: noteTagID,
                    maxPanelHeight: bodyRect.height,
                    onSelect: { newID in
                        noteTagID = newID
                        dismissTagPicker()
                    }
                )
                .frame(width: bodyRect.width, height: bodyRect.height, alignment: .top)
                .offset(x: bodyRect.minX, y: bodyRect.minY)
            }
            .frame(width: panel.width, height: panel.height, alignment: .topLeading)
            // Größen-Animation aus der Tag-Pille heraus: Der Skalierungs-Anker
            // liegt auf der Zungenspitze – also exakt dort, wo die Pille steht.
            // Das `.scaleEffect` sitzt VOR dem `.offset`, damit der Anker
            // eindeutig in der eigenen Rahmenfläche liegt (die Verschiebung
            // wird danach angewendet).
            .scaleEffect(
                isTagPickerExpanded ? 1 : 0.02,
                anchor: UnitPoint(x: tailCenterX, y: tailOnTop ? 0 : 1)
            )
            .offset(x: panel.minX, y: panel.minY)
            .allowsHitTesting(isTagPickerExpanded)
            .onAppear {
                // Direkt nach dem Einhängen aus der Pille heraus aufwachsen.
                withAnimation(.spring(response: 0.34, dampingFraction: 0.80)) {
                    isTagPickerExpanded = true
                }
            }
        }
    }

    // MARK: - Notiz kopieren & einfügen

    /// Aktueller Editor-Zustand als speicherbare Notiz (zugeschnitten auf die
    /// Zeichenfläche) – Grundlage fürs Kopieren.
    private func currentNoteSnapshot() -> LessonNote {
        let currentDrawing = canvasView?.drawing ?? drawing
        let canvasRect = CGRect(origin: .zero, size: recognitionCanvasSize)
        let croppedDrawing = currentDrawing.cropped(to: canvasRect)
        let cleanedTextBoxes = textBoxes.compactMap { box -> NoteTextBox? in
            guard !box.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return box.sanitized(in: canvasRect.size)
        }
        let image = PencilKitCanvasRepresentable.renderNotePreview(
            drawing: croppedDrawing,
            textBoxes: cleanedTextBoxes,
            backgroundStyle: noteBackgroundStyle,
            backgroundScale: noteBackgroundScale,
            clipRect: canvasRect,
            textFontStyle: viewModel.drawingSettings.textFontStyle
        )
        return LessonNote(
            id: lesson.noteKey,
            drawingData: croppedDrawing.dataRepresentation(),
            croppedImageData: image?.pngData(),
            lineCount: max(3, min(10, Int((canvasHeight - headerHeight) / 56))),
            textBoxes: cleanedTextBoxes,
            backgroundStyle: noteBackgroundStyle,
            backgroundScale: noteBackgroundScale,
            tagID: noteTagID,
            updatedAt: Date()
        )
    }

    private var hasCopyableContent: Bool {
        let currentDrawing = canvasView?.drawing ?? drawing
        if !currentDrawing.strokes.isEmpty { return true }
        return textBoxes.contains { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private func copyCurrentNote() {
        selectedTextBoxID = nil
        editingTextBoxID = nil
        let snapshot = currentNoteSnapshot()
        guard snapshot.hasVisibleContent else {
            Haptics.warning()
            showToast("Diese Notiz ist noch leer.")
            return
        }
        viewModel.copyNote(snapshot)
        Haptics.success()
        showToast("Notiz kopiert.")
    }

    /// Ersetzt den kompletten Inhalt dieser Notiz durch die kopierte Notiz
    /// (Zeichnung, Textfelder, Hintergrund, Mustergröße, Tag). Ein einziger
    /// Rückgängig-Schritt stellt den vorherigen Zustand wieder her.
    private func pasteCopiedNote() {
        guard let copied = viewModel.copiedNote, copied.hasVisibleContent else {
            Haptics.warning()
            showToast("Keine kopierte Notiz vorhanden.")
            return
        }

        selectedTextBoxID = nil
        editingTextBoxID = nil

        let beforeBoxes = textBoxes
        let beforeDrawing = (canvasView?.drawing ?? drawing).dataRepresentation()

        canvasHeight = max(
            minimumCanvasHeight,
            min(maximumCanvasHeight, CGFloat(copied.lineCount) * 56 + headerHeight + 40)
        )
        resizeStartHeight = canvasHeight
        noteBackgroundStyle = copied.backgroundStyle
        noteBackgroundScale = NoteBackgroundMetrics.clampedScale(copied.backgroundScale)
        noteTagID = viewModel.tagSettings.tag(withID: copied.tagID)?.id

        let canvasSize = recognitionCanvasSize
        var seenIDs = Set<UUID>()
        textBoxes = copied.textBoxes.compactMap { box in
            // Neue IDs: Dieselbe Notiz kann mehrfach eingefügt werden, ohne
            // dass sich Textfeld-IDs doppeln.
            var copy = box
            copy.id = UUID()
            guard seenIDs.insert(copy.id).inserted else { return nil }
            return copy.sanitized(in: canvasSize)
        }

        let pastedDrawing = (try? PKDrawing(data: copied.drawingData)) ?? PKDrawing()
        drawing = pastedDrawing
        setCanvasDrawing(pastedDrawing)
        canvasView?.undoManager?.removeAllActions()
        lastStrokeMutation = .distantPast

        textUndo.push(
            before: NoteUndoSnapshot(textBoxes: beforeBoxes, drawingData: beforeDrawing),
            after: NoteUndoSnapshot(textBoxes: textBoxes, drawingData: pastedDrawing.dataRepresentation())
        )

        Haptics.success()
        showToast("Notiz eingefügt.")
        recordHistorySnapshot()
    }

    // MARK: - Pencil-Gesten

    private func performPencilGesture(
        _ action: PencilGestureAction,
        paletteAnchor: CGPoint? = nil,
        paletteDirection: CGVector = CGVector(dx: 0, dy: -1)
    ) {
        switch action {
        case .toolbar:
            presentSqueezePalette(anchor: paletteAnchor, direction: paletteDirection)
        case .undo:
            performUndo()
        case .toggleEraser:
            toggleEraserAndLastTool()
        case .none:
            break
        }
    }

    private func toggleEraserAndLastTool() {
        Haptics.select()
        if case .eraser = toolSelection {
            let fallbackHex = viewModel.drawingSettings.penColorSlots.first ?? "#1E1E1E"
            toolSelection = lastInkingTool ?? .pen(color: UIColor(hex: fallbackHex))
        } else {
            lastInkingTool = toolSelection
            toolSelection = .eraser
        }
    }

    // MARK: - Hero-Rahmen

    private func isPlausibleHeroFrame(_ frame: CGRect) -> Bool {
        HeroTransitionPolicy.isPlausibleSourceFrame(
            x: frame.minX,
            y: frame.minY,
            width: frame.width,
            height: frame.height
        )
    }

    private func localizedHeroFrame(windowFrame: CGRect, overlayOrigin: CGPoint) -> CGRect {
        guard isPlausibleHeroFrame(windowFrame) else { return .zero }
        let local = HeroTransitionPolicy.localFrame(
            windowX: windowFrame.minX,
            windowY: windowFrame.minY,
            width: windowFrame.width,
            height: windowFrame.height,
            overlayOriginX: overlayOrigin.x,
            overlayOriginY: overlayOrigin.y
        )
        return CGRect(x: local.x, y: local.y, width: local.width, height: local.height)
    }

    // MARK: - Undo-Scrubber

    private func beginLinearUndoScrub(buttonWindowOrigin: CGPoint) {
        // Ein noch laufender Takt einer früheren Sitzung darf die neue nicht
        // mehr verändern.
        scrubStepWorkItem?.cancel()
        scrubStepWorkItem = nil
        let origin = overlayPoint(fromGlobal: buttonWindowOrigin)
        // Wiederholbare Schritte nach OBEN (über den Knopf) begrenzen: Der
        // verfügbare Platz bis zur Oberkante bestimmt, wie weit der Scrubber
        // in die Redo-Richtung laufen darf.
        let redoTicks = min(
            editingHistory.redoCount,
            NoteUndoSessionPolicy.linearRedoLimit(originY: Double(origin.y))
        )
        // Die möglichen Schritte werden **beim Halten** frisch gezählt – nicht
        // beim Einblenden irgendeiner Bar und nicht aus einem alten Stand.
        undoScrubSession = UndoScrubSession(
            origin: origin,
            style: .linear,
            undoCapacity: editingHistory.undoCount,
            redoCapacity: redoTicks,
            availableUndoCount: editingHistory.undoCount,
            availableRedoCount: editingHistory.redoCount,
            currentOffset: 0,
            targetOffset: 0,
            circleStartAngle: 0,
            circleRadius: 0,
            circleCenter: .zero,
            containerHeight: max(overlaySize.height, 1)
        )
    }

    private func updateLinearUndoScrub(translationY: CGFloat) {
        guard var session = undoScrubSession, session.style == .linear else { return }
        refreshScrubAvailability(&session)
        let available = max(0, session.containerHeight - session.origin.y - 28)
        let undoTicks = NoteUndoSessionPolicy.linearTickCount(
            undoCount: NoteUndoSessionPolicy.scrubTickCount(
                applied: session.currentOffset,
                available: session.availableUndoCount
            ),
            availableHeight: available
        )
        // Die Grenze bleibt der Vorrat der Sitzung: Er wächst mit jedem
        // rückgängig gemachten Schritt mit, sodass man genau dorthin zurück
        // kann, wo die Sitzung begann – begrenzt durch den Platz über dem
        // Knopf, damit der Balken im Bild bleibt.
        let redoTicks = min(
            max(0, session.availableRedoCount),
            NoteUndoSessionPolicy.linearRedoLimit(originY: Double(session.origin.y))
        )
        let offset = UndoScrubMath.linearOffset(
            translationY: translationY,
            undoTicks: undoTicks,
            redoTicks: redoTicks
        )
        applyScrubOffset(offset, to: &session)
    }

    /// Liest die möglichen Schritte immer **wieder neu** aus der echten
    /// Historie. Das ist der Unterschied zwischen „beim Halten aktuell“ und
    /// „beim Einblenden eingefroren“: Nach dem Loslassen und erneutem Halten
    /// (und während des Haltens) zeigt die Bar damit nie zu viele oder zu
    /// wenige Stufen – auch keine blauen Redo-Stufen dort, wo nichts mehr
    /// geht.
    private func refreshScrubAvailability(_ session: inout UndoScrubSession) {
        session.availableUndoCount = min(
            max(0, editingHistory.undoCount),
            session.maximumUndoOffset
        )
        session.availableRedoCount = min(
            max(0, editingHistory.redoCount),
            max(0, session.redoCapacity + session.currentOffset)
        )
    }

    private func beginCircularUndoScrub(
        buttonWindowOrigin: CGPoint,
        circleCenterInGlobal: CGPoint,
        intendedRadius: CGFloat? = nil
    ) {
        let button = overlayPoint(fromGlobal: buttonWindowOrigin)
        let center: CGPoint
        if circleCenterInGlobal != .zero {
            center = overlayPoint(fromGlobal: circleCenterInGlobal)
        } else if let squeezeAnchor {
            center = overlayPoint(fromGlobal: squeezeAnchor)
        } else {
            center = button
        }
        // Radius: bevorzugt den von der Palette gemeldeten on-screen-Bogen
        // (exakt so groß wie die Kreis-Bar). Nur wenn der nicht verfügbar
        // ist, entsteht er aus dem Abstand Knopf → Mitte; die Fallback-Mitte
        // (Hover-Punkt) kann sonst zu großen Kreisen führen.
        var radius = hypot(button.x - center.x, button.y - center.y)
        if let intended = intendedRadius, intended > 8 {
            radius = intended
        }
        let startAngle = atan2(button.y - center.y, button.x - center.x)
        undoScrubRotation.reset()
        // Ein noch laufender Takt einer früheren Sitzung darf die neue nicht
        // mehr verändern.
        scrubStepWorkItem?.cancel()
        scrubStepWorkItem = nil
        // Die möglichen Schritte werden **beim Halten** frisch gezählt (nicht
        // beim Einblenden der Kreis-Bar): Nach einem vorherigen Scrub stimmen
        // Undo- und Redo-Vorrat damit wieder exakt.
        undoScrubSession = UndoScrubSession(
            origin: button,
            style: .circular,
            undoCapacity: editingHistory.undoCount,
            // Undo- und Redo-Bereich teilen sich höchstens einen vollen Kreis.
            redoCapacity: min(
                editingHistory.redoCount,
                max(0, NoteUndoSessionPolicy.circularMaxTicks
                    - NoteUndoSessionPolicy.circularTickCount(undoCount: editingHistory.undoCount))
            ),
            availableUndoCount: editingHistory.undoCount,
            availableRedoCount: editingHistory.redoCount,
            currentOffset: 0,
            targetOffset: 0,
            circleStartAngle: startAngle,
            circleRadius: radius,
            circleCenter: center,
            containerHeight: max(overlaySize.height, 1)
        )
    }

    private func overlayPoint(fromGlobal point: CGPoint) -> CGPoint {
        CGPoint(
            x: point.x - overlayWindowOrigin.x,
            y: point.y - overlayWindowOrigin.y
        )
    }

    private func updateCircularUndoScrub(windowLocation: CGPoint) {
        guard var session = undoScrubSession, session.style == .circular else { return }
        let local = CGPoint(
            x: windowLocation.x - overlayWindowOrigin.x,
            y: windowLocation.y - overlayWindowOrigin.y
        )
        // Direkt an der Kreismitte ist `atan2` nicht mehr stabil. Solche
        // Samples werden ignoriert, statt den Scrubber springen zu lassen.
        let distanceToCenter = hypot(
            local.x - session.circleCenter.x,
            local.y - session.circleCenter.y
        )
        guard distanceToCenter > 12 else { return }

        let current = atan2(local.y - session.circleCenter.y, local.x - session.circleCenter.x)
        // Die Drehung wird Schritt für Schritt **mitaddiert** und nie aus
        // der absoluten Position neu berechnet. So bleiben auch ein
        // voller Umlauf (360°) und das Zurückdrehen zur Startposition
        // stabil – an der Startposition selbst springt nichts um.
        //
        // Der Winkel-Zustand liegt bewusst außerhalb der Session (und damit
        // außerhalb des SwiftUI-States): `applyScrubOffset` verwirft seinen
        // `inout`-Parameter, sobald ein Sample noch keinen neuen Schritt
        // auslöst – ein Winkel in der Session ginge dabei nach jedem Sample
        // verloren und der Knopf ließe sich nicht über den Bogen ziehen.
        if let last = undoScrubRotation.lastAngle {
            undoScrubRotation.accumulatedAngle += UndoScrubMath.normalizedAngleDelta(
                from: last,
                to: current
            )
        }
        undoScrubRotation.lastAngle = current

        // Vor jeder Auswertung den echten Stand der Historie übernehmen: Die
        // Anzeige folgt damit den tatsächlich möglichen Schritten, nicht einem
        // Stand vom Einblenden der Bar.
        refreshScrubAvailability(&session)

        // `undoTicks` ist bewusst die **Gesamtzahl** der Schritte, nicht nur
        // eine Umdrehung: Nach einem vollen Kreis läuft der Scrubber weiter
        // (mehrere Umdrehungen) – bis zum letzten gespeicherten Schritt.
        let undoTicks = max(0, session.undoCapacity)
        let stepAngle = CGFloat(NoteUndoSessionPolicy.circularStepAngle(undoCount: 0))
        let offset = UndoScrubMath.circularOffset(
            accumulatedAngle: undoScrubRotation.accumulatedAngle,
            undoTicks: undoTicks,
            stepAngle: stepAngle,
            redoTicks: max(0, session.redoCapacity)
        )
        applyScrubOffset(offset, to: &session)
    }

    private func applyScrubOffset(_ offset: Int, to session: inout UndoScrubSession) {
        // Vorwärts (0 … Undo-Schritte): Rückgängig – bis zum letzten
        // gespeicherten Schritt, notfalls über mehrere Umdrehungen. Rückwärts
        // (-Redo-Schritte … -1): Wiederholen.
        let clamped = min(max(offset, -session.redoCapacity), session.undoCapacity)
        guard clamped != session.targetOffset else { return }

        // Der Finger bestimmt das **Ziel**, nicht den sofort angewandten
        // Schritt: Der Knopf gleitet animiert dorthin, die Schritte wandern
        // einzeln hinterher (siehe `driveScrubSteps`). So springt die Anzeige
        // nicht mehr mit einem Ruck mehrere Schritte auf einmal zurück.
        session.targetOffset = clamped
        // Die möglichen Schritte werden bei **jeder** Bewegung neu gezählt.
        refreshScrubAvailability(&session)
        withAnimation(.spring(response: 0.22, dampingFraction: 0.82)) {
            undoScrubSession = session
        }
        driveScrubSteps(towards: session)
    }

    /// Wendet die Scrub-Schritte einzeln und im festen Takt an – immer genau
    /// so viele, wie der Knopf auf dem Bogen bereits passiert hat. Der
    /// angewandte Stand ist damit immer korrekt, auch wenn der Finger schnell
    /// über mehrere Stufen zieht.
    private func driveScrubSteps(towards session: UndoScrubSession) {
        scrubStepWorkItem?.cancel()
        let item = DispatchWorkItem { [self] in stepScrub(towards: session) }
        scrubStepWorkItem = item
        stepScrub(towards: session)
    }

    private func stepScrub(towards session: UndoScrubSession) {
        // Die Sitzungs-Kennung verhindert, dass ein noch laufender Takt einer
        // alten Sitzung Sprünge in einer neuen verursacht (seltene, aber
        // sichtbare Fehlanzeige der Kreis-Bar).
        guard let live = undoScrubSession,
              live.id == session.id,
              live.style == session.style else { return }
        let delta = session.targetOffset - live.currentOffset
        guard delta != 0 else { return }

        let applied = delta > 0 ? performSilentUndo() : performSilentRedo()
        guard applied else {
            // Kein Schritt mehr verfügbar (z. B. Historie erschöpft): Ziel
            // korrigieren, damit die Anzeige nicht über den Vorrat hinausläuft.
            guard var corrected = undoScrubSession, corrected.id == session.id else { return }
            corrected.targetOffset = live.currentOffset
            refreshScrubAvailability(&corrected)
            undoScrubSession = corrected
            return
        }

        var updated = live
        updated.currentOffset += delta > 0 ? 1 : -1
        // Die hervorgehobene Stufe wandert kurz hinterher – der Knopf selbst
        // gleitet bereits zum Finger.
        refreshScrubAvailability(&updated)
        withAnimation(.easeOut(duration: 0.12)) {
            undoScrubSession = updated
        }
        // Einrast-Feedback pro Schritt – der Apple Pencil Pro vibriert selbst.
        Haptics.pencilSnap(intensity: 0.9)

        guard updated.currentOffset != session.targetOffset else { return }
        // Ein Schritt pro Takt: Der Knopf wandert sichtbar über den Bogen.
        let item = DispatchWorkItem { [self] in
            guard let next = undoScrubSession, next.id == session.id else { return }
            stepScrub(towards: next)
        }
        scrubStepWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.07, execute: item)
    }

    private func performSilentUndo() -> Bool {
        guard let snapshot = editingHistory.undo() else { return false }
        applyHistorySnapshot(snapshot)
        historyRevision += 1
        return true
    }

    private func performSilentRedo() -> Bool {
        guard let snapshot = editingHistory.redo() else { return false }
        applyHistorySnapshot(snapshot)
        historyRevision += 1
        return true
    }

    private func endUndoScrub() {
        // Beim Loslassen sofort aufholen: Alle noch offenen Schritte werden
        // ohne Takt angewandt, damit der Zustand exakt dem Ziel entspricht.
        scrubStepWorkItem?.cancel()
        scrubStepWorkItem = nil
        if let live = undoScrubSession {
            let delta = live.targetOffset - live.currentOffset
            if delta > 0 {
                for _ in 0..<delta { _ = performSilentUndo() }
            } else if delta < 0 {
                for _ in 0..<(-delta) { _ = performSilentRedo() }
            }
        }
        // Die Drehung gehört zur Sitzung: Die nächste beginnt wieder bei 0°.
        undoScrubRotation.reset()
        withAnimation(.easeOut(duration: 0.16)) {
            undoScrubSession = nil
        }
    }
}
