import SwiftUI
import UIKit
import ImageIO

/// Ansichts-Modus "Nur Notizen": chronologische, scrollbare **Raster**-Übersicht
/// aller Stunden, die eine Notiz enthalten (Hausaufgaben, Tests, ...). Der Titel
/// jeder Karte sieht exakt so aus wie die Kopfzeile über der Zeichenfläche;
/// darunter steht die Notiz selbst. Antippen öffnet die Notiz zum Bearbeiten
/// – genau wie im Stundenplan. Tage/Stunden ohne Notiz erscheinen hier nicht
/// und können auch nicht neu befüllt werden: Die Übersicht zeigt nur
/// vorhandene Notizen. Eine grüne Linie markiert den aktuellen Moment (davor
/// liegen die abgelaufenen Einträge).
///
/// Auf normalen iPad-Breiten stehen drei kompakte Karten nebeneinander.
/// Schmale Fenster weichen auf zwei bzw. eine Spalte aus. Die grüne Linie
/// liegt zwischen getrennten Rastern und läuft über die gesamte Fensterbreite.
///
/// Gedrückt halten öffnet die Optionen, darunter „Im Standard-Modus anzeigen“:
/// Damit wechselt die App in den Standard-Modus und wischt automatisch zur
/// Woche dieser Stunde.
public struct NotesOverviewListView: View {
    @EnvironmentObject private var viewModel: TimetableViewModel
    @State private var entrySnapshot: [NotedLesson] = []

    public let noteNamespace: Namespace.ID

    public init(noteNamespace: Namespace.ID) {
        self.noteNamespace = noteNamespace
    }

    /// Eine Stunde mit sichtbarer Notiz samt abgeleiteter Zeitinformation.
    private struct NotedLesson: Identifiable {
        let lesson: Lesson
        let note: LessonNote
        let date: Date
        let startMinutes: Int
        /// Uhrzeit (Minute des Tages), ab der der Eintrag als abgelaufen gilt
        /// (Ende der letzten Stunde des Blocks).
        let endMinutes: Int

        var id: String { lesson.noteKey }

        func isPast(relativeTo now: Date, nowMinutes: Int) -> Bool {
            if Calendar.germanCalendar.isDate(date, inSameDayAs: now) {
                return endMinutes <= nowMinutes
            }
            return date < now
        }
    }

    /// Flaches Modell der Liste: Tagesüberschriften, Notiz-Zeilen und die
    /// grüne "Jetzt"-Linie an der richtigen Position dazwischen.
    private enum ListItem: Identifiable {
        case nowLine
        case dayHeader(Date)
        case row(NotedLesson)

        var id: String {
            switch self {
            case .nowLine:
                return "planapp_now_line"
            case .dayHeader(let date):
                return "header_\(date.yyyyMMddString)"
            case .row(let entry):
                return entry.id
            }
        }
    }

    private enum OverviewLayoutRow: Identifiable {
        case full(ListItem)
        case cards([NotedLesson])

        var id: String {
            switch self {
            case .full(let item):
                return "full_\(item.id)"
            case .cards(let entries):
                return "cards_" + entries.map(\.id).joined(separator: "_")
            }
        }
    }

    public var body: some View {
        GeometryReader { geometry in
            TimelineView(.periodic(from: .now, by: 60)) { timeline in
                let items = buildListItems(from: entrySnapshot, relativeTo: timeline.date)
                let columns = NotesOverviewLayout.columnCount(for: geometry.size.width)

                ScrollView(.vertical, showsIndicators: true) {
                    if items.isEmpty {
                        emptyState
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                    } else {
                        gridOverview(
                            items: items,
                            columnCount: columns,
                            relativeTo: timeline.date
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemBackground))
        .onAppear(perform: refreshEntrySnapshot)
        .onChange(of: viewModel.notesOverviewRevision) { _, _ in
            refreshEntrySnapshot()
        }
    }

    // MARK: - Raster

    private let horizontalPadding = NotesOverviewLayout.horizontalPadding
    private let columnSpacing = NotesOverviewLayout.columnSpacing
    private let rowSpacing = NotesOverviewLayout.rowSpacing

    /// Die einspaltige Übersicht behält ihre Tagesüberschriften. Im
    /// Mehrspaltenraster stehen Datum und Stunde direkt auf jeder Karte.
    private func gridOverview(
        items: [ListItem],
        columnCount: Int,
        relativeTo date: Date
    ) -> some View {
        let columns = Array(
            repeating: GridItem(.flexible(), spacing: columnSpacing, alignment: .top),
            count: max(1, columnCount)
        )
        let visibleItems = items.filter { item in
            if columnCount > 1, case .dayHeader = item { return false }
            return true
        }

        // LazyVGrid unterstützt gridCellColumns nicht. Deshalb bekommt jede
        // Seite der Jetzt-Linie ein eigenes Grid; die Linie ist ein Geschwister-
        // Element im Stack und kann niemals eine Karten-Zelle belegen.
        return LazyVStack(alignment: .leading, spacing: rowSpacing) {
            ForEach(buildOverviewRows(from: visibleItems)) { row in
                switch row {
                case .full(let item):
                    fullWidthItem(item, relativeTo: date)
                case .cards(let entries):
                    LazyVGrid(columns: columns, alignment: .leading, spacing: rowSpacing) {
                        ForEach(entries) { entry in
                            noteRow(entry: entry, compact: columnCount > 1)
                                .frame(
                                    maxWidth: .infinity,
                                    maxHeight: .infinity,
                                    alignment: .topLeading
                                )
                        }
                    }
                    .padding(.horizontal, horizontalPadding)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }

    /// Ein Element über die volle Rasterbreite (Tagesüberschrift oder
    /// „Jetzt“-Linie).
    @ViewBuilder
    private func fullWidthItem(_ item: ListItem, relativeTo date: Date) -> some View {
        switch item {
        case .nowLine:
            nowLine(relativeTo: date)
                .padding(.vertical, 2)
        case .dayHeader(let headerDate):
            dayHeader(for: headerDate)
                .padding(.horizontal, horizontalPadding)
                .padding(.top, 6)
        case .row(let entry):
            // Kann nur auftreten, wenn Reihen nicht gruppiert wurden.
            noteRow(entry: entry, compact: false)
                .padding(.horizontal, horizontalPadding)
        }
    }

    /// Gruppiert die flache Liste in Rasterabschnitte: Die Jetzt-Linie trennt
    /// immer zwei Raster, auch mitten in einer unvollständigen Kartenzeile.
    /// Nur einspaltig trennen zusätzlich die Tagesüberschriften die Abschnitte.
    /// Die Reihenfolge bleibt chronologisch (zeilenweise von links nach rechts).
    private func buildOverviewRows(from items: [ListItem]) -> [OverviewLayoutRow] {
        var rows: [OverviewLayoutRow] = []
        var pendingCards: [NotedLesson] = []

        func flushPendingCards() {
            guard !pendingCards.isEmpty else { return }
            rows.append(.cards(pendingCards))
            pendingCards.removeAll()
        }

        for item in items {
            switch item {
            case .row(let entry):
                pendingCards.append(entry)
            case .dayHeader, .nowLine:
                flushPendingCards()
                rows.append(.full(item))
            }
        }
        flushPendingCards()

        return rows
    }

    // MARK: - Datensammlung

    /// Baut die fertige Liste inkl. Tagesüberschriften und der grünen Linie
    /// zwischen dem letzten abgelaufenen und dem ersten anstehenden Eintrag.
    private func buildListItems(from entries: [NotedLesson], relativeTo now: Date) -> [ListItem] {
        guard !entries.isEmpty else { return [] }
        let nowMinutes = minutesOfDay(at: now)

        var items: [ListItem] = []
        var lastDateString: String? = nil
        var insertedNowLine = false

        for entry in entries {
            if !insertedNowLine, !entry.isPast(relativeTo: now, nowMinutes: nowMinutes) {
                items.append(.nowLine)
                insertedNowLine = true
            }
            if lastDateString != entry.lesson.dateString {
                lastDateString = entry.lesson.dateString
                items.append(.dayHeader(entry.date))
            }
            items.append(.row(entry))
        }

        // Alles liegt in der Vergangenheit → Linie ans Ende.
        if !insertedNowLine {
            items.append(.nowLine)
        }

        return items
    }

    /// Aktualisiert den teuren Notiz-Snapshot nur bei echten Datenänderungen.
    /// Der Minutentimer darunter berechnet anschließend nur noch die Position
    /// der „Jetzt“-Linie, nicht erneut die gesamte Liste und jede Tagesgruppe.
    private func refreshEntrySnapshot() {
        entrySnapshot = collectEntries()
    }

    /// Alle Stunden mit sichtbarer Notiz, aufsteigend nach Datum und
    /// Startzeit sortiert (Doppelstunden bleiben ein Eintrag).
    ///
    /// Die Stunden werden einmal nach Datum gruppiert und dann lokal
    /// zusammengeführt. `lessonsFor(day:)` würde hier für jeden Schultag erneut
    /// die komplette Stundenliste filtern und sortieren – bei vielen
    /// gespeicherten Wochen summiert sich das unnötig.
    private func collectEntries() -> [NotedLesson] {
        let lessonsByDate = Dictionary(grouping: viewModel.lessons, by: \.dateString)
        let periodsByNumber = Dictionary(
            grouping: viewModel.periods,
            by: \.periodNumber
        ).compactMapValues(\.first)

        var entries: [NotedLesson] = []

        for dateString in lessonsByDate.keys.sorted() {
            guard let date = Date.fromYyyyMMdd(dateString),
                  let rawDayLessons = lessonsByDate[dateString] else { continue }

            let sortedLessons = rawDayLessons.sorted { $0.periodNumber < $1.periodNumber }
            var index = 0

            while index < sortedLessons.count {
                var lesson = sortedLessons[index]
                if index + 1 < sortedLessons.count,
                   lesson.canMergeWithNext(lesson: sortedLessons[index + 1]) {
                    lesson.durationPeriods = 2
                    index += 2
                } else {
                    index += 1
                }

                guard viewModel.hasVisibleNote(for: lesson),
                      let note = viewModel.noteFor(lesson: lesson) else { continue }

                let startMinutes = periodsByNumber[lesson.periodNumber]?.startMinutes
                    ?? lesson.periodNumber * 60
                let endPeriodNumber = lesson.periodNumber + max(1, lesson.durationPeriods) - 1
                let endMinutes = periodsByNumber[endPeriodNumber]?.endMinutes
                    ?? (startMinutes + 45)

                entries.append(
                    NotedLesson(
                        lesson: lesson,
                        note: note,
                        date: date,
                        startMinutes: startMinutes,
                        endMinutes: endMinutes
                    )
                )
            }
        }

        return entries.sorted {
            if $0.lesson.dateString != $1.lesson.dateString {
                return $0.lesson.dateString < $1.lesson.dateString
            }
            return $0.startMinutes < $1.startMinutes
        }
    }

    private func minutesOfDay(at date: Date) -> Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    // MARK: - Listen-Elemente

    /// Tagesüberschrift über einer Gruppe von Notiz-Einträgen.
    private func dayHeader(for date: Date) -> some View {
        let full = "\(date.weekdayLongString), \(date.germanDateString)"
        let relative = date.relativeDayDescription()
        let title: String
        switch relative {
        case "Heute", "Morgen", "Übermorgen", "Gestern", "Vorgestern":
            title = "\(relative) • \(full)"
        default:
            title = full
        }

        return HStack(spacing: 8) {
            Circle()
                .fill(date.isToday ? Color.blue : Color.secondary.opacity(0.5))
                .frame(width: 7, height: 7)
            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .default))
                .foregroundColor(date.isToday ? .blue : .secondary)
        }
        .accessibilityAddTraits(.isHeader)
    }

    /// Grüne Linie: "Hier ist jetzt" – darüber abgelaufen, darunter anstehend.
    private func nowLine(relativeTo date: Date) -> some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(Color.green.opacity(0.8))
                .frame(width: horizontalPadding, height: 2)
            Circle()
                .fill(Color.green)
                .frame(width: 9, height: 9)
            Text(nowLabel(relativeTo: date))
                .font(.system(size: 13, weight: .bold, design: .default))
                .foregroundColor(.green)
                .fixedSize()
            Rectangle()
                .fill(Color.green.opacity(0.8))
                .frame(height: 2)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Aktueller Zeitpunkt: \(nowLabel(relativeTo: date))")
    }

    private func nowLabel(relativeTo date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "HH:mm"
        return "Jetzt • \(formatter.string(from: date)) Uhr"
    }

    /// Eine Zeile: Titel exakt wie über der Zeichenfläche, darunter die Notiz.
    private func noteRow(entry: NotedLesson, compact: Bool) -> some View {
        NoteOverviewCard(lesson: entry.lesson, note: entry.note, compact: compact)
    }

    /// Leerer Zustand, wenn es noch keine Notizen gibt.
    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "note.text")
                .font(.system(size: 44, weight: .regular, design: .default))
                .foregroundColor(.blue.opacity(0.7))
            Text("Keine Notizen vorhanden")
                .font(.system(size: 19, weight: .semibold, design: .default))
                .foregroundColor(.primary)
            Text("Sobald du im Stundenplan Notizen zu Stunden hinzufügst, findest du sie hier chronologisch sortiert – vergangene oberhalb, kommende unterhalb der grünen Linie.")
                .font(.system(size: 14, weight: .regular, design: .default))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 440)
        }
        .padding(28)
    }
}

/// Leichtgewichtiger Rahmen-Speicher: Scroll-Layout-Änderungen aktualisieren
/// die Zoom-Quelle, ohne pro Kartenbewegung den SwiftUI-View-Tree neu zu rendern.
private final class NoteOverviewCardFrameTracker {
    var globalFrame: CGRect = .zero
}

/// Eine Notiz-Karte in der Übersicht „Nur Notizen“.
///
/// Sie bietet exakt dieselben Optionen wie ein Stunden-Block im Stundenplan:
/// - **Gedrückt halten** (Finger oder Apple Pencil) öffnet das Kontextmenü.
/// - **Apple Pencil Pro**: beim Hovern über der Karte einmal *squeezen*
///   (oder beim Pencil 2 doppeltippen) öffnet dieselben Optionen.
/// - Antippen öffnet die Notiz direkt zum Bearbeiten.
private struct NoteOverviewCard: View {
    @EnvironmentObject private var viewModel: TimetableViewModel

    let lesson: Lesson
    let note: LessonNote
    let compact: Bool

    @State private var isHovered = false
    @State private var frameTracker = NoteOverviewCardFrameTracker()
    @State private var showActions = false
    @State private var showDeleteNoteConfirmation = false

    var body: some View {
        let display = viewModel.resolveSubjectDisplay(for: lesson)
        let hasGradient = display.gradientEndColor != nil
        let backgroundColors = lesson.isCancelled
            ? [Color.gray.opacity(0.35), Color.gray.opacity(0.45)]
            : [display.color, display.gradientEndColor ?? display.color.opacity(0.88)]
        let textColor = lesson.isCancelled ? Color.secondary : display.color.contrastingTextColor

        return VStack(alignment: .leading, spacing: compact ? 6 : 10) {
            NoteHeaderContent(
                lesson: lesson,
                display: display,
                displaySettings: viewModel.displaySettings,
                periods: viewModel.periods,
                primaryColor: textColor,
                showsColorCircle: false,
                isCompact: compact,
                teacherDisplayName: viewModel.resolveTeacherName(lesson.teacherRaw),
                originalTeacherDisplayName: lesson.originalTeacher.map { viewModel.resolveTeacherName($0) }
            )

            noteContent(textColor: textColor)
        }
        .padding(.horizontal, compact ? 10 : 14)
        .padding(.vertical, compact ? 8 : 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: backgroundColors,
                        startPoint: hasGradient ? .top : .topLeading,
                        endPoint: hasGradient ? .bottom : .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(isHovered ? 0.45 : 0.24), lineWidth: 1)
        )
        .shadow(
            color: display.color.opacity(lesson.isCancelled ? 0 : (isHovered ? 0.30 : 0.18)),
            radius: isHovered ? 10 : 6,
            x: 0,
            y: isHovered ? 4 : 2
        )
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear { updateGlobalFrameIfNeeded(proxy.frame(in: .global)) }
                    .onChange(of: proxy.frame(in: .global)) { _, newFrame in
                        updateGlobalFrameIfNeeded(newFrame)
                    }
            }
        )
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .hoverEffect(.lift)
        .onHover { hovering in
            guard isHovered != hovering else { return }
            isHovered = hovering
        }
        .onContinuousHover { phase in
            switch phase {
            case .active(_):
                guard !isHovered else { return }
                isHovered = true
            case .ended:
                guard isHovered else { return }
                isHovered = false
            }
        }
        // Apple Pencil Pro: Squeeze beim Hovern öffnet dieselben Optionen
        // wie langes Drücken.
        .background(
            PencilSqueezeActionAttachment {
                guard isHovered else { return }
                Haptics.tap()
                showActions = true
            }
        )
        // Gedrückt halten (Finger oder Apple Pencil) → Kontextmenü.
        .contextMenu {
            noteActionButtons
        }
        .confirmationDialog(
            "Optionen",
            isPresented: $showActions,
            titleVisibility: .visible
        ) {
            noteActionButtons
            Button("Abbrechen", role: .cancel) {}
        }
        .confirmationDialog(
            "Notiz löschen?",
            isPresented: $showDeleteNoteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Notiz löschen", role: .destructive) {
                Haptics.warning()
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.deleteNote(for: lesson)
                }
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Diese Notiz wird dauerhaft entfernt.")
        }
        .onTapGesture {
            openNote()
        }
    }

    // MARK: - Optionen

    @ViewBuilder
    private var noteActionButtons: some View {
        Button {
            showInStandardMode()
        } label: {
            Label("Im Standard-Modus anzeigen", systemImage: "rectangle.grid.3x2")
        }

        Button {
            openNote()
        } label: {
            Label("Notiz bearbeiten", systemImage: "square.and.pencil")
        }

        Button {
            Haptics.tap()
            Task {
                await viewModel.openNoteForNextOccurrence(after: lesson)
            }
        } label: {
            Label("Notiz für die nächste Stunde erstellen", systemImage: "calendar.badge.plus")
        }

        Button(role: .destructive) {
            requestDeleteConfirmation()
        } label: {
            Label("Notiz löschen", systemImage: "trash")
        }
    }

    private func updateGlobalFrameIfNeeded(_ newFrame: CGRect) {
        // Während Settings oder des Zeichen-Overlays wird die Karte nicht als
        // Animationsquelle verwendet. Beim Scrollen ignorieren wir außerdem
        // winzige Geometrieänderungen, genau wie in der Standardübersicht.
        guard !viewModel.isSettingsPresented, !viewModel.isDrawingOverlayPresented else { return }
        let previousFrame = frameTracker.globalFrame
        let threshold: CGFloat = 2
        guard abs(previousFrame.origin.x - newFrame.origin.x) > threshold
            || abs(previousFrame.origin.y - newFrame.origin.y) > threshold
            || abs(previousFrame.size.width - newFrame.size.width) > threshold
            || abs(previousFrame.size.height - newFrame.size.height) > threshold else {
            return
        }
        // Kein @Published/@State-Rect: Die reine Geometrie-Aktualisierung beim
        // Scrollen darf nicht jede sichtbare Karten-View erneut invalidieren.
        frameTracker.globalFrame = newFrame
    }

    private func openNote() {
        Haptics.tap()
        viewModel.openNote(for: lesson, sourceFrame: frameTracker.globalFrame)
    }

    /// Wechselt in den Standard-Modus und wischt automatisch zu der Woche,
    /// in der diese Stunde liegt.
    ///
    /// Der `confirmationDialog`/das Kontextmenü schließt sich dabei von selbst,
    /// weil der Ansichts-Modus gewechselt wird.
    private func showInStandardMode() {
        Haptics.tap()
        viewModel.revealLessonInStandardMode(lesson)
    }

    private func requestDeleteConfirmation() {
        Haptics.warning()
        DispatchQueue.main.async {
            showDeleteNoteConfirmation = true
        }
    }

    // MARK: - Inhalt

    /// Die eigentliche Notiz: Das Vorschaubild wird außerhalb des Main-Threads
    /// heruntergerechnet und gecacht. In der Übersicht muss SwiftUI daher nicht
    /// bei jedem Karten-Render große PNGs erneut dekodieren.
    @ViewBuilder
    private func noteContent(textColor: Color) -> some View {
        if let imageData = note.croppedImageData {
            NotePreviewImage(
                data: imageData,
                cacheKey: "\(note.id)|\(note.updatedAt.timeIntervalSinceReferenceDate)|\(imageData.count)",
                compact: compact
            ) {
                noteTextContent(textColor: textColor)
            }
        } else {
            noteTextContent(textColor: textColor)
        }
    }

    @ViewBuilder
    private func noteTextContent(textColor: Color) -> some View {
        let texts = note.textBoxes
            .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if !texts.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(texts.enumerated()), id: \.offset) { _, text in
                    Text(text)
                        .font(.system(size: compact ? 12 : 15, weight: .regular, design: .default))
                        .foregroundColor(textColor)
                        .multilineTextAlignment(.leading)
                }
            }
        }
    }
}

/// Kleine, speicherschonende Vorschauansicht für eine Notizkarte.
private struct NotePreviewImage<Placeholder: View>: View {
    let data: Data
    let cacheKey: String
    let compact: Bool
    let placeholder: () -> Placeholder

    @State private var image: UIImage?
    @State private var didFinishLoading = false

    init(
        data: Data,
        cacheKey: String,
        compact: Bool,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.data = data
        self.cacheKey = cacheKey
        self.compact = compact
        self.placeholder = placeholder
        _image = State(initialValue: NotePreviewImageCache.image(for: cacheKey))
        _didFinishLoading = State(initialValue: NotePreviewImageCache.image(for: cacheKey) != nil)
    }

    private var maximumHeight: CGFloat { compact ? 140 : 200 }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: maximumHeight, alignment: .leading)
                    .padding(compact ? 4 : 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.white)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.black.opacity(0.10), lineWidth: 0.5)
                    )
                    .shadow(color: Color.black.opacity(0.08), radius: 3, x: 0, y: 1.5)
            } else if didFinishLoading {
                placeholder()
            } else {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.8))
                    .frame(maxWidth: .infinity)
                    .frame(height: compact ? 92 : 132)
                    .overlay {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.secondary)
                    }
            }
        }
        .task(id: cacheKey) {
            if let cached = NotePreviewImageCache.image(for: cacheKey) {
                image = cached
                didFinishLoading = true
                return
            }

            didFinishLoading = false
            let imageData = data
            let key = cacheKey
            let loadedImage = await Task.detached(priority: .utility) {
                NotePreviewImageCache.load(data: imageData, for: key)
            }.value

            guard !Task.isCancelled else { return }
            image = loadedImage
            didFinishLoading = true
        }
    }
}

/// NSCache is thread-safe; ImageIO downsampling keeps previews cheap to retain
/// and to composite while the lazy grid scrolls.
private enum NotePreviewImageCache {
    private static let images: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.totalCostLimit = 64 * 1024 * 1024
        return cache
    }()

    static func image(for key: String) -> UIImage? {
        images.object(forKey: key as NSString)
    }

    static func load(data: Data, for key: String) -> UIImage? {
        if let cached = image(for: key) { return cached }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: 1_200,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }

        let preview = UIImage(cgImage: thumbnail, scale: 1, orientation: .up)
        images.setObject(
            preview,
            forKey: key as NSString,
            cost: thumbnail.bytesPerRow * thumbnail.height
        )
        return preview
    }
}
