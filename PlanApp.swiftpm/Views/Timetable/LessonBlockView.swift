import SwiftUI
import UIKit

/// Block-Karte für ein Unterrichtsfach im Stundenplan
public struct LessonBlockView: View {
    @EnvironmentObject private var viewModel: TimetableViewModel

    public let lesson: Lesson
    public let blockHeight: CGFloat
    public let noteNamespace: Namespace.ID
    /// Kompakte Darstellung für schmale Spalten (iPhone): kleinere Schrift,
    /// weniger Abstand, keine Symbole vor Lehrer/Raum.
    public let isCompact: Bool

    @State private var isHovered: Bool = false
    @State private var pinchScale: CGFloat = 1.0
    /// Live-Sonde für den Fenster-Rahmen. Der GeometryReader hat beim ersten
    /// Öffnen oft 0 oder eine Mini-Größe geliefert – die UIView-Sonde liest
    /// den echten Rahmen erst beim Antippen.
    @State private var frameHolder = ViewFrameHolder()
    @State private var measuredWidth: CGFloat = 0
    /// Gemessene Höhe des Text-Bereichs (Titelzeile + Zusatzinfos). Die
    /// Notiz-Vorschau darf sich bis knapp an diesen Text heran vergrößern.
    @State private var textContentHeight: CGFloat = 26
    @State private var showDeleteNoteConfirmation = false

    public init(lesson: Lesson, blockHeight: CGFloat, noteNamespace: Namespace.ID, isCompact: Bool = false) {
        self.lesson = lesson
        self.blockHeight = blockHeight
        self.noteNamespace = noteNamespace
        self.isCompact = isCompact
    }

    private var contentPadding: CGFloat { isCompact ? 4 : 8 }
    private var titleFontSize: CGFloat { isCompact ? 10 : 15 }
    private var detailFontSize: CGFloat { isCompact ? 8 : 12 }

    /// Modus "Notizen hervorgehoben": Blöcke ohne sichtbare Notiz werden stark
    /// aufgehellt. Während eine Notiz geöffnet ist, nie aufhellen.
    private var dimmedForNotesHighlight: Bool {
        guard viewModel.viewMode == .notesHighlighted else { return false }
        let isActive = viewModel.isDrawingOverlayPresented
            && viewModel.activeNoteLesson?.noteKey == lesson.noteKey
        guard !isActive else { return false }
        return !viewModel.hasVisibleNote(for: lesson)
    }

    public var body: some View {
        let display = viewModel.resolveSubjectDisplay(for: lesson)
        let displayName = display.name
        let subjectColor = display.color
        let note = viewModel.noteFor(lesson: lesson)
        let hasVisibleNote = viewModel.hasVisibleNote(for: lesson)
        let settings = viewModel.displaySettings
        let teacherDisplayName = viewModel.resolveTeacherName(lesson.teacherRaw)
        let originalTeacherDisplayName = lesson.originalTeacher.map { viewModel.resolveTeacherName($0) }
        let isActive = viewModel.isDrawingOverlayPresented
            && viewModel.activeNoteLesson?.noteKey == lesson.noteKey
        let hasGradient = display.gradientEndColor != nil
        let noteTag = viewModel.tag(for: lesson)
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
            RoundedRectangle(cornerRadius: isCompact ? 8 : 12, style: .continuous)
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
                    RoundedRectangle(cornerRadius: isCompact ? 8 : 12, style: .continuous)
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
                            .font(.system(size: titleFontSize, weight: isCompact ? .semibold : .regular, design: .default))
                            .foregroundColor(
                                lesson.isCancelled ? .secondary : Color.black
                            )
                            .strikethrough(lesson.isCancelled, color: .red)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)

                        if settings.showTags, let noteTag {
                            NoteTagPill(tag: noteTag, size: isCompact ? .mini : .small)
                        }

                        Spacer(minLength: 0)

                        // Badges (auf dem iPhone nur als farbiger Punkt, damit
                        // der Fachname lesbar bleibt)
                        if isCompact {
                            if lesson.isCancelled {
                                Circle().fill(Color.red).frame(width: 6, height: 6)
                            } else if lesson.isSubstitution {
                                Circle().fill(Color.orange).frame(width: 6, height: 6)
                            }
                        } else {
                            VStack(alignment: .trailing, spacing: 3) {
                                if lesson.isCancelled {
                                    StatusBadge(.cancelled)
                                } else if lesson.isSubstitution {
                                    StatusBadge(.substitution)
                                }
                            }
                        }
                    }

                    // Anpassbare Zusatz-Informationen (Lehrer, Raum, Details).
                    // Kompakt (iPhone) untereinander statt nebeneinander.
                    detailStack(spacing: isCompact ? 1 : 8) {
                        if settings.showTeacher && !lesson.teacherRaw.isEmpty {
                            HStack(spacing: 3) {
                                if !isCompact {
                                    Image(systemName: "person")
                                        .font(.system(size: 10, weight: .regular, design: .default))
                                }
                                if let orig = originalTeacherDisplayName, lesson.isSubstitution {
                                    Text(orig)
                                        .strikethrough(true, color: .red)
                                    Text("➔ \(teacherDisplayName)")
                                        .strikethrough(lesson.isCancelled, color: .red)
                                } else {
                                    Text(teacherDisplayName)
                                        .strikethrough(lesson.isCancelled, color: .red)
                                }
                            }
                            .font(.system(size: detailFontSize, weight: .regular, design: .default))
                            .foregroundColor(lesson.isCancelled ? .secondary : Color.black.opacity(0.70))
                            .lineLimit(1)
                        }

                        if settings.showRoom && !lesson.roomRaw.isEmpty {
                            HStack(spacing: 3) {
                                if !isCompact {
                                    Image(systemName: "mappin.and.ellipse")
                                        .font(.system(size: 10, weight: .regular, design: .default))
                                }
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
                            .font(.system(size: detailFontSize, weight: .regular, design: .default))
                            .foregroundColor(lesson.isCancelled ? .secondary : Color.black.opacity(0.70))
                            .lineLimit(1)
                        }
                    }

                    // Vertretungsnotiz / Grund
                    if !isCompact, settings.showSubstitutionDetails && !lesson.substitutionText.isEmpty {
                        Text(lesson.substitutionText)
                            .font(.system(size: 11, weight: .regular, design: .default))
                            .foregroundColor(lesson.isCancelled ? .red.opacity(0.9) : Color.black.opacity(0.85))
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
            .padding(contentPadding)
            .opacity(dimmedForNotesHighlight ? 0.28 : 1)
        }
        .frame(height: blockHeight)
        // Modus "Notizen hervorgehoben": Blöcke ohne Notiz stark aufhellen,
        // damit die Stunden mit Notizen sofort ins Auge springen.
        .overlay {
            if dimmedForNotesHighlight {
                RoundedRectangle(cornerRadius: isCompact ? 8 : 12, style: .continuous)
                    .fill(Color(UIColor.systemBackground).opacity(0.78))
                    .allowsHitTesting(false)
            }
        }
        // Handschriftliche Notiz-Vorschau: Als Overlay unten rechts. Sie wächst
        // von unten rechts nach oben links, bis sie das Padding des Blocks oder
        // den Text erreicht.
        .overlay(alignment: .bottomTrailing) {
            if settings.showNotesPreview,
               hasVisibleNote,
               let note,
               let imgData = note.croppedImageData {
                // Verfügbare Breite: komplette Blockbreite abzüglich der
                // Paddings (Vorschau-Kasten + Blockrand).
                let maxW = max(24, measuredWidth - 16)
                // Verfügbare Höhe: Blockhöhe abzüglich oberem Padding,
                // gemessenem Text und etwas Abstand nach unten.
                // Minimaler Extra-Abstand zum Textbereich, damit die Vorschau
                // bei kleinen Blöcken nicht direkt am letzten Text-Pixel klebt.
                let maxH = max(18, blockHeight - 8 - textContentHeight - 8 - 14)

                TimetableNotePreviewImage(
                    data: imgData,
                    cacheKey: "\(note.id)|\(note.updatedAt.timeIntervalSinceReferenceDate)|\(imgData.count)|timetable"
                )
                .frame(maxWidth: maxW, maxHeight: maxH)
                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                .padding(3)
                // Schatten nur auf der weißen Form, nicht auf dem Bild – das
                // hält das Drei-Wochen-Karussell beim Wischen flüssig.
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.10), radius: 3, x: 0, y: 1.5)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.12), lineWidth: 0.5)
                )
                .padding(5)
                .allowsHitTesting(false)
            }
        }
        .background(ViewFrameProbe(holder: frameHolder))
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear { measuredWidth = proxy.size.width }
                    .onChange(of: proxy.size.width) { _, newValue in
                        measuredWidth = newValue
                    }
            }
        )
        .contentShape(RoundedRectangle(cornerRadius: isCompact ? 8 : 12, style: .continuous))
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
        // Apple Pencil Pro: Squeeze (und Pencil-Button-Tap) beim Hovern
        // öffnet dasselbe, block-gewidmete Menü wie der lange Druck.
        .background(
            LessonBlockSqueezeMenuBridge(isSqueezeEnabled: isHovered) {
                lessonUIMenu()
            }
        )
        // EIN Weg zu den Optionen: langes Drücken (Finger, Pencil, Trackpad)
        // öffnet das systemeigene Kontextmenü – direkt am Block verankert,
        // wie in der Notiz-Übersicht. Das frühere zentrale „Optionen“-
        // confirmationDialog (Variante „Optionen oben“) ist weg; es gab zwei
        // Darstellungen desselben Menüs, jetzt nur noch die block-gewidmete.
        //
        // Stabilität: Das Menü gehört dem System (UIKit), nicht dem
        // SwiftUI-Body. Neubewertungen der Karte (Hover-Effekt,
        // Vorschau-Refresh) bauen es nicht ab und neu auf – die Optionen
        // bleiben stabil stehen. VoiceOver bekommt die Inhalte automatisch
        // als Aktionsmenü vom `.contextMenu`.
        .contextMenu {
            lessonContextMenuContent
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
                        viewModel.openNote(for: lesson, sourceFrame: sourceFrameForAnimation())
                    }
                    pinchScale = 1.0
                }
        )
        // Klick öffnet Notiz-Bereich (mit haptischem Feedback, auch beim
        // Antippen mit dem Apple Pencil)
        .onTapGesture {
            handleBlockTap()
        }
    }

    /// Inhalt des block-gewidmeten Kontextmenüs (langer Druck). Die
    /// „Tag“-Auswahl ist jetzt Untermenü – es gibt kein separates
    /// „Tag“-confirmationDialog mehr.
    @ViewBuilder
    private var lessonContextMenuContent: some View {
        let hasVisibleNote = viewModel.hasVisibleNote(for: lesson)

        Button {
            openCurrentNote()
        } label: {
            Label(
                hasVisibleNote ? "Notiz bearbeiten" : "Notiz erstellen",
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

        if hasVisibleNote {
            Button {
                Haptics.tap()
                viewModel.copyNote(for: lesson)
            } label: {
                Label("Kopieren", systemImage: "doc.on.doc")
            }
        }

        if hasVisibleNote, viewModel.tagSettings.isEnabled {
            Menu {
                if viewModel.tagSettings.tags.isEmpty {
                    Button("Keine Tags angelegt") {}
                        .disabled(true)
                } else {
                    ForEach(viewModel.tagSettings.tags) { tag in
                        Button {
                            Haptics.select()
                            viewModel.setTag(tag.id, for: lesson)
                        } label: {
                            if viewModel.tag(for: lesson)?.id == tag.id {
                                Label(tag.displayName, systemImage: "checkmark")
                            } else {
                                Text(tag.displayName)
                            }
                        }
                    }
                }
                if viewModel.tag(for: lesson) != nil {
                    Divider()
                    Button(role: .destructive) {
                        Haptics.tap()
                        viewModel.setTag(nil, for: lesson)
                    } label: {
                        Label("Tag entfernen", systemImage: "xmark.circle")
                    }
                }
            } label: {
                Label("Tag", systemImage: "tag")
            }
        }

        if viewModel.hasCopiedNote {
            Button {
                Haptics.tap()
                viewModel.pasteCopiedNote(into: lesson)
            } label: {
                Label(hasVisibleNote ? "Einfügen (ersetzt Notiz)" : "Einfügen", systemImage: "doc.on.clipboard")
            }
        }

        if hasVisibleNote {
            Button(role: .destructive) {
                requestDeleteConfirmation()
            } label: {
                Label("Notiz löschen", systemImage: "trash")
            }
        }
    }

    /// Dasselbe Menü als UIKit-`UIMenu` – für den Apple-Pencil-Pro-Squeeze,
    /// der das SwiftUI-Kontextmenü nicht programmatisch öffnen kann. Der
    /// Builder liest immer den aktuellen ViewModel-Zustand (wird bei jedem
    /// Render neu übergeben).
    private func lessonUIMenu() -> UIMenu {
        let hasVisibleNote = viewModel.hasVisibleNote(for: lesson)
        var elements: [UIMenuElement] = []

        elements.append(UIAction(
            title: hasVisibleNote ? "Notiz bearbeiten" : "Notiz erstellen",
            image: UIImage(systemName: "square.and.pencil")
        ) { _ in
            openCurrentNote()
        })
        elements.append(UIAction(
            title: "Notiz für die nächste Stunde erstellen",
            image: UIImage(systemName: "calendar.badge.plus")
        ) { _ in
            Haptics.tap()
            let target = lesson
            Task { await viewModel.openNoteForNextOccurrence(after: target) }
        })
        if hasVisibleNote {
            elements.append(UIAction(title: "Kopieren", image: UIImage(systemName: "doc.on.doc")) { _ in
                Haptics.tap()
                viewModel.copyNote(for: lesson)
            })
        }
        if hasVisibleNote, viewModel.tagSettings.isEnabled {
            var tagElements: [UIMenuElement] = []
            for tag in viewModel.tagSettings.tags {
                let isSelected = viewModel.tag(for: lesson)?.id == tag.id
                tagElements.append(UIAction(
                    title: tag.displayName,
                    image: isSelected ? UIImage(systemName: "checkmark") : nil
                ) { _ in
                    Haptics.select()
                    viewModel.setTag(tag.id, for: lesson)
                })
            }
            if viewModel.tag(for: lesson) != nil {
                tagElements.append(UIMenu(
                    title: "",
                    options: .displayInline,
                    children: [
                        UIAction(
                            title: "Tag entfernen",
                            image: UIImage(systemName: "xmark.circle"),
                            attributes: .destructive
                        ) { _ in
                            Haptics.tap()
                            viewModel.setTag(nil, for: lesson)
                        }
                    ]
                ))
            }
            elements.append(UIMenu(title: "Tag", image: UIImage(systemName: "tag"), children: tagElements))
        }
        if viewModel.hasCopiedNote {
            elements.append(UIAction(
                title: hasVisibleNote ? "Einfügen (ersetzt Notiz)" : "Einfügen",
                image: UIImage(systemName: "doc.on.clipboard")
            ) { _ in
                Haptics.tap()
                viewModel.pasteCopiedNote(into: lesson)
            })
        }
        if hasVisibleNote {
            elements.append(UIAction(
                title: "Notiz löschen",
                image: UIImage(systemName: "trash"),
                attributes: .destructive
            ) { _ in
                requestDeleteConfirmation()
            })
        }
        return UIMenu(title: "Optionen", children: elements)
    }

    /// Lehrer/Raum nebeneinander (iPad) bzw. untereinander (iPhone).
    @ViewBuilder
    private func detailStack<Content: View>(spacing: CGFloat, @ViewBuilder content: () -> Content) -> some View {
        if isCompact {
            VStack(alignment: .leading, spacing: spacing) { content() }
        } else {
            HStack(spacing: spacing) { content() }
        }
    }

    private func sourceFrameForAnimation() -> CGRect {
        frameHolder.plausibleWindowFrame
    }

    /// Tipp auf den Block: öffnet die Notiz. Nach einem langen Druck
    /// (Kontextmenü) verschlingt das System die Berührung – es gibt keinen
    /// zusätzlichen Tipp mehr zu filtern.
    private func handleBlockTap() {
        openCurrentNote()
    }

    private func openCurrentNote() {
        Haptics.tap()
        viewModel.openNote(for: lesson, sourceFrame: sourceFrameForAnimation())
    }

    private func requestDeleteConfirmation() {
        Haptics.warning()
        DispatchQueue.main.async {
            showDeleteNoteConfirmation = true
        }
    }
}

/// Unsichtbare UIKit-Brücke für das block-gewidmete „Optionen“-Menü:
/// Apple-Pencil-Pro-Squeeze (und der Pencil-Button-Tap) präsentieren das
/// Menü programmatisch über `UIEditMenuInteraction`. Ein langer Druck läuft
/// weiterhin über das SwiftUI-`.contextMenu` des Blocks; beide Wege zeigen
/// dasselbe Menü.
///
/// Der `buildMenu`-Closure wird bei jedem SwiftUI-Render aktualisiert, damit
/// das Menü stets den aktuellen ViewModel-Zustand verwendet.
private struct LessonBlockSqueezeMenuBridge: UIViewRepresentable {
    /// Nur beim Hovern über den Block (dasselbe Verhalten wie bisher).
    var isSqueezeEnabled: Bool
    var buildMenu: () -> UIMenu

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = true

        let squeeze = UIPencilInteraction()
        squeeze.delegate = context.coordinator
        view.addInteraction(squeeze)
        context.coordinator.pencilInteraction = squeeze

        let editMenu = UIEditMenuInteraction(delegate: context.coordinator)
        view.addInteraction(editMenu)
        context.coordinator.editMenuInteraction = editMenu
        context.coordinator.anchorView = view

        context.coordinator.update(from: self)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.update(from: self)
        context.coordinator.anchorView = uiView
    }

    final class Coordinator: NSObject, UIPencilInteractionDelegate, UIEditMenuInteractionDelegate {
        var isSqueezeEnabled = false
        var buildMenu: () -> UIMenu = { UIMenu(title: "") }
        weak var pencilInteraction: UIPencilInteraction?
        weak var editMenuInteraction: UIEditMenuInteraction?
        weak var anchorView: UIView?

        func update(from parent: LessonBlockSqueezeMenuBridge) {
            isSqueezeEnabled = parent.isSqueezeEnabled
            buildMenu = parent.buildMenu
        }

        @available(iOS 17.5, *)
        func pencilInteraction(
            _ interaction: UIPencilInteraction,
            didReceiveSqueeze squeeze: UIPencilInteraction.Squeeze
        ) {
            guard squeeze.phase == .ended else { return }
            presentMenuIfEnabled()
        }

        func pencilInteractionDidTap(_ interaction: UIPencilInteraction) {
            presentMenuIfEnabled()
        }

        private func presentMenuIfEnabled() {
            guard isSqueezeEnabled,
                  let editMenuInteraction,
                  let anchorView else { return }

            Haptics.tap()
            let configuration = UIEditMenuConfiguration(
                identifier: nil,
                sourcePoint: CGPoint(x: anchorView.bounds.midX, y: anchorView.bounds.midY)
            )
            editMenuInteraction.presentEditMenu(with: configuration)
        }

        func editMenuInteraction(
            _ interaction: UIEditMenuInteraction,
            menuFor configuration: UIEditMenuConfiguration,
            suggestedActions: [UIMenuElement]
        ) -> UIMenu? {
            buildMenu()
        }
    }
}

/// Stundenblöcke werden beim Drei-Wochen-Karussell gleichzeitig aufgebaut.
/// Ein direktes `UIImage(data:)` hätte dabei jede große PNG auf dem Main Thread
/// decodiert. Diese kleine Ansicht lädt eine passende Vorschau im Hintergrund
/// und teilt sich den Cache mit der Notizenübersicht.
private struct TimetableNotePreviewImage: View {
    let data: Data
    let cacheKey: String

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Color.clear
            }
        }
        .task(id: cacheKey) {
            if let cached = NotePreviewImageCache.image(for: cacheKey) {
                image = cached
                return
            }

            let imageData = data
            let key = cacheKey
            let loadedImage = await Task.detached(priority: .utility) {
                NotePreviewImageCache.load(
                    data: imageData,
                    for: key,
                    maximumPixelSize: 480
                )
            }.value

            guard !Task.isCancelled else { return }
            image = loadedImage
        }
    }
}
