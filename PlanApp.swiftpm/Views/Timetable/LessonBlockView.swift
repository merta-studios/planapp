import SwiftUI

/// Block-Karte für ein Unterrichtsfach im Stundenplan
public struct LessonBlockView: View {
    @EnvironmentObject private var viewModel: TimetableViewModel

    public let lesson: Lesson
    public let blockHeight: CGFloat
    public let noteNamespace: Namespace.ID

    @State private var isHovered: Bool = false
    @State private var pinchScale: CGFloat = 1.0
    /// Aktueller Bildschirm-Rahmen dieser Karte (globale Koordinaten). Wird
    /// live nachgeführt, damit die Zoom-Animation der Zeichenfläche exakt aus
    /// der Position und Größe dieser Karte heraus starten kann.
    @State private var globalFrame: CGRect = .zero
    /// Gemessene Höhe des Text-Bereichs (Titelzeile + Zusatzinfos). Die
    /// Notiz-Vorschau darf sich bis knapp an diesen Text heran vergrößern.
    @State private var textContentHeight: CGFloat = 26
    @State private var showLessonActions = false
    @State private var showDeleteNoteConfirmation = false

    public init(lesson: Lesson, blockHeight: CGFloat, noteNamespace: Namespace.ID) {
        self.lesson = lesson
        self.blockHeight = blockHeight
        self.noteNamespace = noteNamespace
    }

    /// Modus "Notizen hervorgehoben": Blöcke ohne sichtbare Notiz werden stark
    /// aufgehellt. Während eine Notiz geöffnet ist, nie aufhellen.
    private var dimmedForNotesHighlight: Bool {
        guard viewModel.viewMode == .notesHighlighted else { return false }
        let isActive = viewModel.isDrawingOverlayPresented
            && viewModel.activeNoteLesson?.noteKey == lesson.noteKey
        guard !isActive else { return false }
        return !(viewModel.noteFor(lesson: lesson)?.hasVisibleContent ?? false)
    }

    public var body: some View {
        let display = viewModel.resolveSubjectDisplay(for: lesson)
        let displayName = display.name
        let subjectColor = display.color
        let note = viewModel.noteFor(lesson: lesson)
        let settings = viewModel.displaySettings
        let isActive = viewModel.isDrawingOverlayPresented
            && viewModel.activeNoteLesson?.noteKey == lesson.noteKey
        let hasGradient = display.gradientEndColor != nil
        let cardColors: [Color] = {
            if isActive {
                return [
                    Color(UIColor.systemGray4),
                    Color(UIColor.systemGray3)
                ]
            }
            if lesson.isCancelled {
                return [Color.gray.opacity(0.35), Color.gray.opacity(0.45)]
            }
            if let endColor = display.gradientEndColor {
                return [subjectColor, endColor]
            }
            return [subjectColor, subjectColor.opacity(0.88)]
        }()

        ZStack(alignment: .topLeading) {
            // The active card turns grey before matched geometry grows and moves
            // it into the center of the drawing overlay.
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: cardColors,
                        // Benutzerdefinierte Farbverläufe laufen von der
                        // oberen Anfangs- zur unteren End-Farbe.
                        startPoint: hasGradient ? .top : .topLeading,
                        endPoint: hasGradient ? .bottom : .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(
                            lesson.isCancelled
                                ? Color.red.opacity(0.6)
                                : (lesson.isSubstitution ? Color.orange.opacity(0.8) : Color.white.opacity(0.2)),
                            lineWidth: lesson.isCancelled || lesson.isSubstitution ? 1.5 : 1.0
                        )
                )
                .shadow(
                    color: lesson.isCancelled ? Color.clear : subjectColor.opacity(0.25),
                    radius: isHovered ? 8 : 4,
                    x: 0,
                    y: isHovered ? 4 : 2
                )

            // Block-Inhalte
            VStack(alignment: .leading, spacing: 0) {
                // Messbarer Text-Bereich: Die Notiz-Vorschau darf sich bis
                // knapp an diesen Text heran vergrößern (nach oben links).
                VStack(alignment: .leading, spacing: 4) {
                    // Obere Zeile: Fachname + Status-Badges
                    HStack(alignment: .top, spacing: 6) {
                        Text(displayName)
                            .font(.system(size: 15, weight: .regular, design: .default))
                            .foregroundColor(
                                isActive
                                    ? .primary
                                    : (lesson.isCancelled ? .secondary : subjectColor.contrastingTextColor)
                            )
                            .strikethrough(lesson.isCancelled, color: .red)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)

                        Spacer(minLength: 0)

                        // Badges
                        VStack(alignment: .trailing, spacing: 3) {
                            if lesson.isCancelled {
                                StatusBadge(.cancelled)
                            } else if lesson.isSubstitution {
                                StatusBadge(.substitution)
                            }
                        }
                    }

                    // Anpassbare Zusatz-Informationen (Lehrer, Raum, Details)
                    HStack(spacing: 8) {
                        if settings.showTeacher && !lesson.teacherRaw.isEmpty {
                            HStack(spacing: 3) {
                                Image(systemName: "person")
                                    .font(.system(size: 10, weight: .regular, design: .default))
                                if let orig = lesson.originalTeacher, lesson.isSubstitution {
                                    Text(orig)
                                        .strikethrough(true, color: .red)
                                    Text("➔ \(lesson.teacherRaw)")
                                        .strikethrough(lesson.isCancelled, color: .red)
                                } else {
                                    Text(lesson.teacherRaw)
                                        .strikethrough(lesson.isCancelled, color: .red)
                                }
                            }
                            .font(.system(size: 12, weight: .regular, design: .default))
                            .foregroundColor(lesson.isCancelled ? .secondary : subjectColor.contrastingSecondaryTextColor)
                        }

                        if settings.showRoom && !lesson.roomRaw.isEmpty {
                            HStack(spacing: 3) {
                                Image(systemName: "mappin.and.ellipse")
                                    .font(.system(size: 10, weight: .regular, design: .default))
                                if let orig = lesson.originalRoom, lesson.isSubstitution {
                                    Text(orig)
                                        .strikethrough(true, color: .red)
                                    Text("➔ \(lesson.roomRaw)")
                                        .strikethrough(lesson.isCancelled, color: .red)
                                } else {
                                    Text(lesson.roomRaw)
                                        .strikethrough(lesson.isCancelled, color: .red)
                                }
                            }
                            .font(.system(size: 12, weight: .regular, design: .default))
                            .foregroundColor(lesson.isCancelled ? .secondary : subjectColor.contrastingSecondaryTextColor)
                        }
                    }

                    // Vertretungsnotiz / Grund
                    if settings.showSubstitutionDetails && !lesson.substitutionText.isEmpty {
                        Text(lesson.substitutionText)
                            .font(.system(size: 11, weight: .regular, design: .default))
                            .foregroundColor(lesson.isCancelled ? .red.opacity(0.9) : subjectColor.contrastingTextColor)
                            .strikethrough(lesson.isCancelled, color: .red)
                            .lineLimit(2)
                            .padding(.top, 1)
                    }
                }
                .background(
                    GeometryReader { proxy in
                        Color.clear
                            .onAppear { textContentHeight = proxy.size.height }
                            .onChange(of: proxy.size.height) { _, newValue in
                                textContentHeight = newValue
                            }
                    }
                )

                Spacer(minLength: 0)
            }
            .padding(8)
            .opacity(dimmedForNotesHighlight ? 0.28 : 1)
        }
        .frame(height: blockHeight)
        // Modus "Notizen hervorgehoben": Blöcke ohne Notiz stark aufhellen,
        // damit die Stunden mit Notizen sofort ins Auge springen.
        .overlay {
            if dimmedForNotesHighlight {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(UIColor.systemBackground).opacity(0.78))
                    .allowsHitTesting(false)
            }
        }
        // Handschriftliche Notiz-Vorschau: Als Overlay unten rechts. Sie wächst
        // von unten rechts nach oben links, bis sie das Padding des Blocks oder
        // den Text erreicht.
        .overlay(alignment: .bottomTrailing) {
            if settings.showNotesPreview,
               let imgData = note?.croppedImageData,
               let uiImg = UIImage(data: imgData) {
                // Verfügbare Breite: komplette Blockbreite abzüglich der
                // Paddings (Vorschau-Kasten + Blockrand).
                let maxW = max(24, globalFrame.width - 16)
                // Verfügbare Höhe: Blockhöhe abzüglich oberem Padding,
                // gemessenem Text und etwas Abstand nach unten.
                // Minimaler Extra-Abstand zum Textbereich, damit die Vorschau
                // bei kleinen Blöcken nicht direkt am letzten Text-Pixel klebt.
                let maxH = max(18, blockHeight - 8 - textContentHeight - 8 - 14)

                Image(uiImage: uiImg)
                    .resizable()
                    .scaledToFit()
                    .frame(
                        maxWidth: maxW,
                        maxHeight: maxH
                    )
                    .padding(3)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.white.opacity(0.55))
                    )
                    .padding(5)
                    .allowsHitTesting(false)
            }
        }
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear { globalFrame = proxy.frame(in: .global) }
                    .onChange(of: proxy.frame(in: .global)) { _, newValue in
                        globalFrame = newValue
                    }
            }
        )
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .hoverEffect(.lift)
        .onHover { hovering in
            isHovered = hovering
        }
        .onContinuousHover { phase in
            switch phase {
            case .active(_):
                isHovered = true
            case .ended:
                isHovered = false
            }
        }
        .background(
            PencilSqueezeActionAttachment {
                guard isHovered else { return }
                Haptics.tap()
                showLessonActions = true
            }
        )
        .contextMenu {
            lessonActionButtons
        }
        .confirmationDialog(
            "Optionen",
            isPresented: $showLessonActions,
            titleVisibility: .visible
        ) {
            lessonActionButtons
            Button("Abbrechen", role: .cancel) {}
        }
        .confirmationDialog(
            "Notiz löschen?",
            isPresented: $showDeleteNoteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Notiz löschen", role: .destructive) {
                Haptics.warning()
                viewModel.deleteNote(for: lesson)
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Diese Notiz wird dauerhaft entfernt.")
        }
        // Zoom-Geste mit zwei Fingern öffnet Notiz-Bereich
        .simultaneousGesture(
            MagnificationGesture()
                .onChanged { scale in
                    pinchScale = scale
                }
                .onEnded { scale in
                    if scale > 1.15 {
                        Haptics.tap()
                        viewModel.openNote(for: lesson, sourceFrame: globalFrame)
                    }
                    pinchScale = 1.0
                }
        )
        // Klick öffnet Notiz-Bereich (mit haptischem Feedback, auch beim
        // Antippen mit dem Apple Pencil)
        .onTapGesture {
            openCurrentNote()
        }
    }

    @ViewBuilder
    private var lessonActionButtons: some View {
        Button {
            openCurrentNote()
        } label: {
            Label(
                viewModel.noteFor(lesson: lesson) == nil ? "Notiz erstellen" : "Notiz bearbeiten",
                systemImage: "square.and.pencil"
            )
        }

        Button {
            Haptics.tap()
            Task {
                await viewModel.openNoteForNextOccurrence(after: lesson)
            }
        } label: {
            Label("Notiz für die nächste Stunde erstellen", systemImage: "calendar.badge.plus")
        }

        if viewModel.noteFor(lesson: lesson) != nil {
            Button(role: .destructive) {
                requestDeleteConfirmation()
            } label: {
                Label("Notiz löschen", systemImage: "trash")
            }
        }
    }

    private func openCurrentNote() {
        Haptics.tap()
        viewModel.openNote(for: lesson, sourceFrame: globalFrame)
    }

    private func requestDeleteConfirmation() {
        Haptics.warning()
        DispatchQueue.main.async {
            showDeleteNoteConfirmation = true
        }
    }
}
