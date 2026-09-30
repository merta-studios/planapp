import SwiftUI
import PencilKit

/// Vollbild-Overlay mit zentrierter transparenter Zeichenfläche über abgedunkeltem Stundenplan
public struct LessonDrawingOverlayView: View {
    @EnvironmentObject private var viewModel: TimetableViewModel
    @Environment(\.colorScheme) private var colorScheme

    public let lesson: Lesson
    public let noteNamespace: Namespace.ID

    @State private var drawing: PKDrawing = PKDrawing()
    @State private var canvasHeight: CGFloat = 460
    @State private var dragStartHeight: CGFloat = 460
    @State private var toolSelection: DrawingToolSelection = .pen(color: .black)
    @State private var penWidth: CGFloat = 3.5
    @State private var canvasView: PKCanvasView? = nil

    // Butterweiche Zoom- & Pan-Transformationen in Echtzeit
    @State private var scale: CGFloat = 1.0
    @State private var baseScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var baseOffset: CGSize = .zero

    // Status für nahtlose Farbübergangs-Animation
    @State private var isFullyAppeared: Bool = false

    private let paperWidth: CGFloat = 640
    private let headerHeight: CGFloat = 56

    public init(lesson: Lesson, noteNamespace: Namespace.ID) {
        self.lesson = lesson
        self.noteNamespace = noteNamespace
    }

    public var body: some View {
        let (displayName, _, subjectColor) = viewModel.resolveSubjectDisplay(for: lesson)

        GeometryReader { geometry in
            ZStack(alignment: .center) {
                // 1. ABGEDUNKELTER LIQUID-HINTERGRUND
                Color.black.opacity(isFullyAppeared ? 0.60 : 0.0)
                    .background(.ultraThinMaterial.opacity(isFullyAppeared ? 1.0 : 0.0))
                    .ignoresSafeArea()
                    .onTapGesture {
                        saveAndDismiss()
                    }

                // 2. ZENTRIERTER INTERAKTIVER NOTIZZETTEL
                VStack(spacing: 8) {
                    ZStack(alignment: .topLeading) {
                        // Nahtloser Farb- und Formübergang vom Stundenplan-Block zur Zeichenfläche
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(
                                isFullyAppeared
                                    ? AnyShapeStyle(.ultraThinMaterial)
                                    : AnyShapeStyle(subjectColor)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [
                                                (isFullyAppeared ? Color.white : subjectColor).opacity(0.35),
                                                Color.white.opacity(0.10)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                            .shadow(color: Color.black.opacity(0.22), radius: 20, x: 0, y: 10)

                        // Kopfzeile mit Fachname und Datum
                        HStack(alignment: .center) {
                            Text(displayName)
                                .font(.system(size: 18, weight: .regular, design: .default))
                                .foregroundColor(.white)

                            Spacer()

                            Text("\(lesson.dateString) • \(lesson.periodNumber). Stunde")
                                .font(.system(size: 13, weight: .regular, design: .default))
                                .foregroundColor(.white.opacity(0.80))
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 14)
                        .frame(height: headerHeight)

                        // PencilKit Zeichenebene (nur mit Apple Pencil beschreibbar)
                        PencilKitCanvasRepresentable(
                            drawing: $drawing,
                            toolSelection: toolSelection,
                            penWidth: penWidth,
                            colorScheme: colorScheme,
                            onCanvasCreated: { cv in
                                self.canvasView = cv
                            }
                        )
                        .frame(width: paperWidth, height: max(180, canvasHeight - headerHeight - 10))
                        .padding(.top, headerHeight)
                    }
                    .frame(width: paperWidth, height: canvasHeight)

                    // Runder Zieh-Button zum flexiblen Ändern der Höhe
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 36, height: 36)
                        .overlay(
                            Image(systemName: "arrow.up.and.down")
                                .font(.system(size: 14, weight: .regular, design: .default))
                                .foregroundColor(.white)
                        )
                        .overlay(
                            Circle()
                                .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.18), radius: 4, x: 0, y: 2)
                        .contentShape(Circle())
                        .hoverEffect(.lift)
                        .gesture(
                            DragGesture(minimumDistance: 1)
                                .onChanged { value in
                                    let newH = dragStartHeight + value.translation.height
                                    canvasHeight = max(260, min(1000, newH))
                                }
                                .onEnded { _ in
                                    dragStartHeight = canvasHeight
                                }
                        )
                }
                .matchedGeometryEffect(
                    id: "lesson_card_\(lesson.noteKey)",
                    in: noteNamespace,
                    properties: .frame,
                    anchor: .center,
                    isSource: false
                )
                .scaleEffect(scale)
                .offset(offset)
                // Exakt zentriert auf dem Bildschirm
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                // Stufenlose, kontinuierliche 2-Finger Zoom- & Verschiebegeste
                .gesture(
                    SimultaneousGesture(
                        MagnificationGesture()
                            .onChanged { value in
                                scale = max(0.6, min(3.0, baseScale * value))
                            }
                            .onEnded { _ in
                                baseScale = scale
                            },
                        DragGesture()
                            .onChanged { value in
                                offset = CGSize(
                                    width: baseOffset.width + value.translation.width,
                                    height: baseOffset.height + value.translation.height
                                )
                            }
                            .onEnded { _ in
                                baseOffset = offset
                            }
                    )
                )

                // 3. TOP FLOATING WERKZEUGLEISTE & SCHLIESSEN-BUTTON
                VStack {
                    HStack(spacing: 12) {
                        // Schließen & Speichern Liquid Glass Button
                        Button(action: saveAndDismiss) {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 13, weight: .regular, design: .default))
                                Text("Fertig & Speichern")
                                    .font(.system(size: 13, weight: .regular, design: .default))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                        }
                        .liquidGlassButton(cornerRadius: 18, tint: .blue, isFilled: true)
                        .foregroundColor(.white)

                        Spacer()

                        // Werkzeugleiste (Stift, Marker, Radierer, Dicke-Slider, Undo/Redo)
                        DrawingToolbarView(
                            toolSelection: $toolSelection,
                            penWidth: $penWidth,
                            onUndo: { canvasView?.undoManager?.undo() },
                            onRedo: { canvasView?.undoManager?.redo() },
                            onClear: {
                                drawing = PKDrawing()
                                canvasView?.drawing = PKDrawing()
                            }
                        )

                        Spacer()

                        // Schließen-Hinweis
                        Text("Tippe ins Dunkle zum Schließen")
                            .font(.system(size: 12, weight: .regular, design: .default))
                            .foregroundColor(.white.opacity(0.85))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(.ultraThinMaterial)
                            )
                            .overlay(
                                Capsule()
                                    .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                    Spacer()
                }
            }
        }
        .onAppear {
            loadExistingNote()
            withAnimation(.easeInOut(duration: 0.35)) {
                isFullyAppeared = true
            }
        }
    }

    private func loadExistingNote() {
        if let note = viewModel.noteFor(lesson: lesson) {
            // Zeilenanzahl aus bestehender Notiz in Höhe übersetzen
            self.canvasHeight = max(320, CGFloat(note.lineCount) * 56 + headerHeight + 40)
            self.dragStartHeight = self.canvasHeight
            if let pkDrawing = try? PKDrawing(data: note.drawingData) {
                self.drawing = pkDrawing
            }
        }
    }

    private func saveAndDismiss() {
        let currentDrawing = canvasView?.drawing ?? drawing
        let croppedImage = PencilKitCanvasRepresentable.cropDrawingToContent(currentDrawing)
        let pngData = croppedImage?.pngData()
        let drawingData = currentDrawing.dataRepresentation()
        let calculatedLines = max(3, min(10, Int((canvasHeight - headerHeight) / 56)))

        withAnimation(.easeInOut(duration: 0.25)) {
            isFullyAppeared = false
        }

        viewModel.saveNote(
            for: lesson,
            drawingData: drawingData,
            croppedImageData: pngData,
            lineCount: calculatedLines
        )
    }
}
