import SwiftUI
import PencilKit

/// Vollbild-Overlay mit vergrößerter transparenter Zeichenfläche über abgedunkeltem Stundenplan
public struct LessonDrawingOverlayView: View {
    @EnvironmentObject private var viewModel: TimetableViewModel

    public let lesson: Lesson
    public let noteNamespace: Namespace.ID

    @State private var drawing: PKDrawing = PKDrawing()
    @State private var lineCount: Int = 6
    @State private var toolSelection: DrawingToolSelection = .pen(color: .black) // Schwarz als Standard
    @State private var canvasView: PKCanvasView? = nil

    // Zoom & Pan Transformationen
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private let paperWidth: CGFloat = 620
    private let lineHeight: CGFloat = 52
    private let headerHeight: CGFloat = 68

    public init(lesson: Lesson, noteNamespace: Namespace.ID) {
        self.lesson = lesson
        self.noteNamespace = noteNamespace
    }

    private var paperHeight: CGFloat {
        headerHeight + CGFloat(lineCount) * lineHeight + 60
    }

    public var body: some View {
        let (displayName, _, _) = viewModel.resolveSubjectDisplay(for: lesson)

        ZStack {
            // 1. ABGEDUNKELTER HINTERGRUND
            Color.black.opacity(0.60)
                .background(.ultraThinMaterial)
                .ignoresSafeArea()
                .onTapGesture {
                    saveAndDismiss()
                }

            // 2. INTERAKTIVER NOTIZZETTEL (Zoombar & Verschiebbar)
            VStack(spacing: 0) {
                ZStack(alignment: .topLeading) {
                    // Transparenter, linienloser Hintergrund
                    LinedPaperBackground(
                        lineCount: lineCount,
                        lineHeight: lineHeight,
                        headerHeight: headerHeight,
                        subjectName: displayName,
                        dateText: "\(lesson.dateString) • \(lesson.periodNumber). Stunde"
                    )

                    // PencilKit Zeichenebene
                    PencilKitCanvasRepresentable(
                        drawing: $drawing,
                        toolSelection: toolSelection,
                        onCanvasCreated: { cv in
                            self.canvasView = cv
                        }
                    )
                    .frame(width: paperWidth, height: paperHeight - 50)
                    .padding(.top, 10)
                }
                .frame(width: paperWidth, height: paperHeight - 50)

                // UNTERER BEREICH: "Erweitern" (+ Zeile hinzufügen)
                HStack {
                    Button(action: {
                        if lineCount < 10 {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                lineCount += 1
                            }
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: lineCount < 10 ? "plus.circle.fill" : "checkmark.circle.fill")
                                .font(.system(size: 15, weight: .bold))
                            Text(lineCount < 10 ? "＋ Zeile hinzufügen (Erweitern)" : "Maximal 10 Zeilen erreicht")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                            Text("(\(lineCount)/10)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(Color(UIColor.secondarySystemBackground))
                                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                        )
                        .foregroundColor(lineCount < 10 ? .blue : .secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .hoverEffect(.lift)
                    .disabled(lineCount >= 10)
                }
                .frame(width: paperWidth, height: 50)
                .background(Color.white.opacity(0.12))
                .clipShape(
                    CustomCornersShape(corners: [.bottomLeft, .bottomRight], radius: 16)
                )
            }
            .frame(width: paperWidth, height: paperHeight)
            // Öffnet aus dem angetippten Fachblock und gleitet beim Schließen
            // exakt dorthin zurück.
            .matchedGeometryEffect(
                id: "note_\(lesson.noteKey)",
                in: noteNamespace,
                properties: .frame,
                anchor: .center,
                isSource: false
            )
            .scaleEffect(scale)
            .offset(offset)
            // Zoom & Verschiebegesten
            .gesture(
                SimultaneousGesture(
                    // 2-Finger Zoom & Pinch
                    MagnificationGesture()
                        .onChanged { value in
                            let delta = value / lastScale
                            lastScale = value
                            scale = min(max(scale * delta, 0.7), 2.8)
                        }
                        .onEnded { _ in
                            lastScale = 1.0
                        },
                    // 1-Finger oder 2-Finger Verschiebung
                    DragGesture()
                        .onChanged { value in
                            offset = CGSize(
                                width: lastOffset.width + value.translation.width,
                                height: lastOffset.height + value.translation.height
                            )
                        }
                        .onEnded { _ in
                            lastOffset = offset
                        }
                )
            )

            // 3. TOP FLOATING WERKZEUGLEISTE & SCHLIESSEN-BUTTON
            VStack {
                HStack {
                    // Schließen & Speichern Button
                    Button(action: {
                        saveAndDismiss()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                            Text("Fertig & Speichern")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                        .shadow(color: Color.blue.opacity(0.3), radius: 6, x: 0, y: 3)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .hoverEffect(.lift)

                    Spacer()

                    // Werkzeugleiste
                    DrawingToolbarView(
                        toolSelection: $toolSelection,
                        onUndo: { canvasView?.undoManager?.undo() },
                        onRedo: { canvasView?.undoManager?.redo() },
                        onClear: {
                            drawing = PKDrawing()
                            canvasView?.drawing = PKDrawing()
                        }
                    )

                    Spacer()

                    // Hinweis-Info
                    Text("Tippe ins Dunkle zum Schließen")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.4))
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)

                Spacer()
            }
        }
        .onAppear {
            loadExistingNote()
        }
    }

    private func loadExistingNote() {
        if let note = viewModel.noteFor(lesson: lesson) {
            self.lineCount = note.lineCount
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

        viewModel.saveNote(
            for: lesson,
            drawingData: drawingData,
            croppedImageData: pngData,
            lineCount: lineCount
        )
    }
}

/// Benutzerdefinierte Ecken-Rundung für das Papier-Ende
struct CustomCornersShape: Shape {
    var corners: UIRectCorner
    var radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
