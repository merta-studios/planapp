import SwiftUI
import UIKit
import ImageIO

/// Ansichts-Modus "Nur Notizen": chronologische, scrollbare **Raster**-Übersicht
/// aller Stunden, die eine Notiz enthalten (Hausaufgaben, Tests, ...). Der Titel
/// jeder Karte sieht aus wie die Kopfzeile über der Zeichenfläche; darunter
/// steht die Notiz selbst. Antippen öffnet die Notiz zum Bearbeiten – genau
/// wie im Stundenplan. Eine grüne Linie markiert den aktuellen Moment (davor
/// liegen die abgelaufenen Einträge).
///
/// ## Warum diese Ansicht bewusst „flach“ gebaut ist
///
/// Frühere Fassungen ruckelten ab etwa zehn Notizen. Ursachen waren nicht die
/// Daten, sondern die Darstellung jeder einzelnen Karte:
///
/// * Ein `.shadow` auf dem **kompletten** Karteninhalt (inkl. Vorschaubild) und
///   ein zweiter Schatten auf dem Bild selbst. Solche Schatten müssen bei jedem
///   Bildschirm-Frame aus dem gerenderten Inhalt neu geblurrt werden – bei zehn
///   sichtbaren Bildern ist das mehr, als eine flüssige Scroll-Animation
///   verträgt. Jetzt liegt der Schatten ausschließlich auf der
///   Hintergrund-**Form** (wie bei den Stundenplan-Blöcken), nie auf Bildern.
/// * Ein `GeometryReader` pro Karte, dessen `onChange(frame in .global)` bei
///   jedem Scroll-Frame für alle sichtbaren Karten feuerte. Der Rahmen für die
///   Zoom-Animation wird jetzt erst beim Antippen aus einer winzigen UIView
///   gelesen – ohne jegliche Arbeit beim Scrollen.
/// * Verschachtelte `LazyVStack → LazyVStack → LazyVGrid`-Container, zwei
///   `confirmationDialog`s, Hover-Zustand und eine eigene UIKit-Pencil-Brücke
///   **pro Karte**. Jetzt gibt es einen einzigen flachen `LazyVStack` aus
///   vorberechneten Zeilen, die Dialoge liegen einmal auf Listenebene und die
///   Squeeze-Brücke existiert genau einmal.
/// * Jede Karte trug die vollständige `LessonNote` (inkl. PKDrawing-Daten).
///   Die Karten bekommen nur noch ein leichtgewichtiges, `Equatable`
///   Eintrags-Modell.
public struct NotesOverviewListView: View {
    @EnvironmentObject private var viewModel: TimetableViewModel

    public let noteNamespace: Namespace.ID

    @State private var entrySnapshot: [NotedLesson] = []
    /// Auf volle Minuten gerundet: ändert sich nur, wenn sich die Position der
    /// „Jetzt“-Linie wirklich ändern kann.
    @State private var currentMinute: Date = NotesOverviewListView.truncatedToMinute(Date())
    /// Ziel des „Optionen“-Dialogs (Squeeze / Doppeltipp des Apple Pencil).
    @State private var optionsTarget: Lesson? = nil
    /// Ziel des Lösch-Dialogs.
    @State private var deleteTarget: Lesson? = nil
    /// Welche Karte der Apple Pencil gerade überfährt (für Squeeze).
    @State private var hoverTracker = NotesOverviewHoverTracker()
    /// Rahmen der grünen Linie im Scroll-Viewport. `nil`, wenn sie nicht mehr
    /// im aufgebauten Bereich liegt.
    @State private var nowLineFrame: CGRect? = nil
    @State private var nowJumpReady = false

    public init(noteNamespace: Namespace.ID) {
        self.noteNamespace = noteNamespace
    }

    // MARK: - Modelle

    /// Eine Stunde mit sichtbarer Notiz samt abgeleiteter Zeitinformation.
    /// Bewusst **ohne** Zeichnungsdaten – nur das, was die Karte anzeigt.
    struct NotedLesson: Identifiable, Equatable {
        let lesson: Lesson
        let noteKey: String
        let updatedAt: Date
        let previewData: Data?
        let texts: [String]
        let tagID: UUID?
        let date: Date
        let startMinutes: Int
        /// Minute des Tages, ab der der Eintrag als abgelaufen gilt
        /// (Ende der letzten Stunde des Blocks).
        let endMinutes: Int

        var id: String { noteKey }

        var previewCacheKey: String {
            "\(noteKey)|\(updatedAt.timeIntervalSinceReferenceDate)|\(previewData?.count ?? 0)"
        }

        func isPast(relativeTo now: Date, nowMinutes: Int) -> Bool {
            if Calendar.germanCalendar.isDate(date, inSameDayAs: now) {
                return endMinutes <= nowMinutes
            }
            return date < now
        }

        static func == (lhs: NotedLesson, rhs: NotedLesson) -> Bool {
            lhs.noteKey == rhs.noteKey
                && lhs.updatedAt == rhs.updatedAt
                && lhs.lesson == rhs.lesson
                && lhs.tagID == rhs.tagID
                && lhs.previewData?.count == rhs.previewData?.count
                && lhs.texts == rhs.texts
        }
    }

    /// Eine Zeile des flachen Rasters.
    private enum OverviewRow: Identifiable {
        case nowLine
        case dayHeader(Date)
        case cards([NotedLesson])

        var id: String {
            switch self {
            case .nowLine:
                return NotesOverviewLayout.nowLineID
            case .dayHeader(let date):
                return "header_\(date.yyyyMMddString)"
            case .cards(let entries):
                return "cards_\(entries.first?.id ?? "empty")"
            }
        }
    }

    // MARK: - Body

    public var body: some View {
        GeometryReader { geometry in
            let columnCount = NotesOverviewLayout.columnCount(for: geometry.size.width, isPhone: DeviceLayout.isPhone)
            let filteredEntries = applyTagFilter(to: entrySnapshot)
            let rows = buildRows(from: filteredEntries, relativeTo: currentMinute, columnCount: columnCount)
            let relativeDay = Calendar.germanCalendar.startOfDay(for: currentMinute)

            let showsNowJump = nowJumpReady && !filteredEntries.isEmpty && InteractionPolicies.shouldShowNowJumpButton(
                lineMinY: nowLineFrame?.minY,
                lineMaxY: nowLineFrame?.maxY,
                viewportHeight: geometry.size.height
            )
            let jumpPointsDown = InteractionPolicies.nowJumpPointsDown(
                lineMidY: nowLineFrame.map { $0.midY },
                viewportHeight: geometry.size.height
            )

            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ZStack(alignment: .topTrailing) {
                        ScrollView(.vertical, showsIndicators: true) {
                            if rows.isEmpty {
                                emptyState(isFiltered: !entrySnapshot.isEmpty)
                                    .frame(maxWidth: .infinity)
                                    .padding(.top, 60)
                            } else {
                                LazyVStack(alignment: .leading, spacing: NotesOverviewLayout.rowSpacing) {
                                    ForEach(rows) { row in
                                        rowView(row, columnCount: columnCount, relativeDay: relativeDay)
                                            .id(row.id)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                // Apple Pencil Pro: genau EINE Squeeze-Brücke für die
                                // gesamte Liste. Welche Karte gemeint ist, weiß der
                                // Hover-Tracker.
                                .background(
                                    PencilSqueezeActionAttachment {
                                        guard let lesson = hoverTracker.hoveredLesson else { return }
                                        Haptics.tap()
                                        optionsTarget = lesson
                                    }
                                )
                            }
                        }
                        .coordinateSpace(name: NotesOverviewLayout.scrollSpace)

                        if showsNowJump {
                            jumpToNowButton(pointsDown: jumpPointsDown) {
                                withAnimation(.easeInOut(duration: 0.35)) {
                                    proxy.scrollTo(NotesOverviewLayout.nowLineID, anchor: .center)
                                }
                            }
                            .padding(.top, 12)
                            .padding(.trailing, 16)
                            .transition(.scale(scale: 0.86).combined(with: .opacity))
                        }
                    }
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.82), value: showsNowJump)
            .onPreferenceChange(NowLineFramePreference.self) { frame in
                let height = geometry.size.height
                let show = InteractionPolicies.shouldShowNowJumpButton(
                    lineMinY: frame?.minY,
                    lineMaxY: frame?.maxY,
                    viewportHeight: height
                )
                let previousShow = InteractionPolicies.shouldShowNowJumpButton(
                    lineMinY: nowLineFrame?.minY,
                    lineMaxY: nowLineFrame?.maxY,
                    viewportHeight: height
                )
                let down = InteractionPolicies.nowJumpPointsDown(lineMidY: frame?.midY, viewportHeight: height)
                let previousDown = InteractionPolicies.nowJumpPointsDown(
                    lineMidY: nowLineFrame?.midY,
                    viewportHeight: height
                )
                guard show != previousShow || down != previousDown || (frame == nil) != (nowLineFrame == nil) else {
                    return
                }
                nowLineFrame = frame
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    nowJumpReady = true
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemBackground))
        .onAppear(perform: refreshEntrySnapshot)
        .onChange(of: viewModel.notesOverviewRevision) { _, _ in
            refreshEntrySnapshot()
        }
        .task {
            // Minutentakt für die „Jetzt“-Linie – ohne TimelineView, damit kein
            // Zeitplan bei jeder Neubewertung des Bodys neu startet.
            while !Task.isCancelled {
                let now = Date()
                let next = NotesOverviewListView.truncatedToMinute(now).addingTimeInterval(60)
                let delay = max(1, next.timeIntervalSince(now))
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                guard !Task.isCancelled else { break }
                let minute = NotesOverviewListView.truncatedToMinute(Date())
                if minute != currentMinute {
                    currentMinute = minute
                }
            }
        }
        .confirmationDialog(
            "Optionen",
            isPresented: Binding(
                get: { optionsTarget != nil },
                set: { if !$0 { optionsTarget = nil } }
            ),
            titleVisibility: .visible,
            presenting: optionsTarget
        ) { lesson in
            NoteOverviewActions(
                viewModel: viewModel,
                lesson: lesson,
                sourceFrame: { hoverTracker.frame(for: lesson) },
                requestDelete: { deleteTarget = lesson }
            )
            Button("Abbrechen", role: .cancel) {}
        }
        .confirmationDialog(
            "Notiz löschen?",
            isPresented: Binding(
                get: { deleteTarget != nil },
                set: { if !$0 { deleteTarget = nil } }
            ),
            titleVisibility: .visible,
            presenting: deleteTarget
        ) { lesson in
            Button("Notiz löschen", role: .destructive) {
                Haptics.warning()
                viewModel.deleteNote(for: lesson)
            }
            Button("Abbrechen", role: .cancel) {}
        } message: { _ in
            Text("Diese Notiz wird dauerhaft entfernt.")
        }
    }

    // MARK: - Zeilen

    @ViewBuilder
    private func rowView(_ row: OverviewRow, columnCount: Int, relativeDay: Date) -> some View {
        switch row {
        case .nowLine:
            nowLine(relativeTo: currentMinute)
                .padding(.vertical, 2)
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: NowLineFramePreference.self,
                            value: proxy.frame(in: .named(NotesOverviewLayout.scrollSpace))
                        )
                    }
                )
                .onDisappear {
                    nowLineFrame = nil
                }
        case .dayHeader(let date):
            dayHeader(for: date)
                .padding(.horizontal, NotesOverviewLayout.horizontalPadding)
                .padding(.top, 6)
        case .cards(let entries):
            HStack(alignment: .top, spacing: NotesOverviewLayout.columnSpacing) {
                ForEach(entries) { entry in
                    NoteOverviewCard(
                        viewModel: viewModel,
                        entry: entry,
                        tag: viewModel.tag(forNoteKey: entry.noteKey),
                        compact: columnCount > 1,
                        presentationRevision: viewModel.notesOverviewPresentationRevision,
                        relativeDay: relativeDay,
                        hoverTracker: hoverTracker,
                        optionsTarget: $optionsTarget,
                        deleteTarget: $deleteTarget
                    )
                    .equatable()
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                // Unvollständige Zeilen behalten die Spaltenbreite.
                if entries.count < columnCount {
                    ForEach(0..<(columnCount - entries.count), id: \.self) { _ in
                        Color.clear.frame(maxWidth: .infinity, maxHeight: 1)
                    }
                }
            }
            .padding(.horizontal, NotesOverviewLayout.horizontalPadding)
        }
    }

    /// Baut die flachen Zeilen: Karten in Zeilen zu `columnCount` Stück, die
    /// grüne Linie zwischen dem letzten abgelaufenen und dem ersten anstehenden
    /// Eintrag (auch mitten in einer unvollständigen Kartenzeile) sowie – nur
    /// einspaltig – Tagesüberschriften. Die Zeilenlogik selbst steckt in
    /// `NotesOverviewLayout.rowPlan` und wird in den Regressions-Tests geprüft.
    private func buildRows(
        from entries: [NotedLesson],
        relativeTo now: Date,
        columnCount: Int
    ) -> [OverviewRow] {
        guard !entries.isEmpty else { return [] }
        let columns = max(1, columnCount)
        let nowMinutes = minutesOfDay(at: now)
        let plan = NotesOverviewLayout.rowPlan(entries: entries, columnCount: columns) { entry in
            entry.isPast(relativeTo: now, nowMinutes: nowMinutes)
        }

        var rows: [OverviewRow] = []
        rows.reserveCapacity(plan.count + 8)
        var lastDateString: String? = nil

        for item in plan {
            switch item {
            case .nowLine:
                rows.append(.nowLine)
            case .cards(let cards):
                // Einspaltig enthält jede Zeile genau eine Karte – davor steht
                // bei einem Datumswechsel die Tagesüberschrift.
                if columns == 1, let entry = cards.first, lastDateString != entry.lesson.dateString {
                    lastDateString = entry.lesson.dateString
                    rows.append(.dayHeader(entry.date))
                }
                rows.append(.cards(cards))
            }
        }
        return rows
    }

    // MARK: - Tag-Filter

    private func applyTagFilter(to entries: [NotedLesson]) -> [NotedLesson] {
        guard viewModel.tagSettings.isEnabled, !viewModel.activeTagFilter.isEmpty else {
            return entries
        }
        let filter = viewModel.activeTagFilter
        return entries.filter { entry in
            guard let tagID = entry.tagID else { return false }
            return filter.contains(tagID)
        }
    }

    // MARK: - Datensammlung

    /// Aktualisiert den Notiz-Snapshot nur bei echten Datenänderungen. Kein
    /// Animations-Kontext: Beim ersten Öffnen würden sonst alle sichtbaren
    /// Bildflächen gleichzeitig interpoliert.
    private func refreshEntrySnapshot() {
        let snapshot = collectEntries()
        guard snapshot != entrySnapshot else { return }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            entrySnapshot = snapshot
        }
    }

    /// Alle Stunden mit sichtbarer Notiz, aufsteigend nach Datum und
    /// Startzeit sortiert (Doppelstunden bleiben ein Eintrag).
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

                let texts = note.textBoxes
                    .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }

                entries.append(
                    NotedLesson(
                        lesson: lesson,
                        noteKey: note.id,
                        updatedAt: note.updatedAt,
                        previewData: note.croppedImageData,
                        texts: texts,
                        tagID: note.tagID,
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

    private static func truncatedToMinute(_ date: Date) -> Date {
        let interval = date.timeIntervalSinceReferenceDate
        return Date(timeIntervalSinceReferenceDate: (interval / 60).rounded(.down) * 60)
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
                .frame(width: NotesOverviewLayout.horizontalPadding, height: 2)
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

    private func jumpToNowButton(pointsDown: Bool, action: @escaping () -> Void) -> some View {
        let green = Color(red: 0.10, green: 0.62, blue: 0.28)
        return Button {
            Haptics.tap()
            action()
        } label: {
            HStack(spacing: 7) {
                Image(systemName: pointsDown ? "arrow.down" : "arrow.up")
                    .font(.system(size: 14, weight: .semibold))
                Text("Jetzt")
                    .font(.system(size: 16, weight: .semibold))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .liquidGlassButton(cornerRadius: 16, tint: green, isFilled: true)
        .foregroundColor(.white)
        .fixedSize()
        .accessibilityLabel("Zur aktuellen Zeit springen")
    }

    private func nowLabel(relativeTo date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "HH:mm"
        return "Jetzt • \(formatter.string(from: date)) Uhr"
    }

    /// Leerer Zustand, wenn es (passende) Notizen nicht gibt.
    private func emptyState(isFiltered: Bool) -> some View {
        VStack(spacing: 14) {
            Image(systemName: isFiltered ? "tag.slash" : "note.text")
                .font(.system(size: 44, weight: .regular, design: .default))
                .foregroundColor(.blue.opacity(0.7))
            Text(isFiltered ? "Keine Notizen mit diesen Tags" : "Keine Notizen vorhanden")
                .font(.system(size: 19, weight: .semibold, design: .default))
                .foregroundColor(.primary)
                Text(isFiltered
                 ? "Öffne den Filter im Modus-Menü und wähle andere Tags, oder hebe die Auswahl auf, um wieder alle Notizen zu sehen."
                 : "Sobald du im Stundenplan Notizen zu Stunden hinzufügst, findest du sie hier chronologisch sortiert – vergangene oberhalb, kommende unterhalb der grünen Linie.")
                .font(.system(size: 14, weight: .regular, design: .default))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 440)
        }
        .padding(28)
    }
}

// MARK: - Hover-Tracker & Rahmen-Sonde

struct NowLineFramePreference: PreferenceKey {
    static var defaultValue: CGRect? = nil
    static func reduce(value: inout CGRect?, nextValue: () -> CGRect?) {
        value = nextValue() ?? value
    }
}

/// Merkt sich (ohne SwiftUI-Invalidierung), welche Karte der Apple Pencil
/// gerade überfährt und wo sie auf dem Bildschirm liegt.
final class NotesOverviewHoverTracker {
    var hoveredLesson: Lesson? = nil
    private var frameHolders: [String: NoteCardFrameHolder] = [:]

    func register(_ holder: NoteCardFrameHolder, for noteKey: String) {
        frameHolders[noteKey] = holder
    }

    func frame(for lesson: Lesson) -> CGRect {
        frameHolders[lesson.noteKey]?.currentFrame ?? .zero
    }
}

/// Hält eine schwache Referenz auf eine unsichtbare UIView in der Karte. Der
/// Bildschirm-Rahmen wird erst beim Antippen berechnet – beim Scrollen
/// entsteht dadurch keinerlei Arbeit.
final class NoteCardFrameHolder {
    weak var view: UIView?

    var currentFrame: CGRect {
        guard let view, let window = view.window else { return .zero }
        return view.convert(view.bounds, to: window)
    }
}

private struct NoteCardFrameProbe: UIViewRepresentable {
    let holder: NoteCardFrameHolder

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        holder.view = view
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        holder.view = uiView
    }
}

// MARK: - Aktionen

/// Die Optionen einer Notiz-Karte – identisch im Kontextmenü (gedrückt
/// halten) und im „Optionen“-Dialog (Apple Pencil Squeeze / Doppeltipp).
private struct NoteOverviewActions: View {
    let viewModel: TimetableViewModel
    let lesson: Lesson
    let sourceFrame: () -> CGRect
    let requestDelete: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            viewModel.revealLessonInStandardMode(lesson)
        } label: {
            Label("Im Standard-Modus anzeigen", systemImage: "rectangle.grid.3x2")
        }

        Button {
            Haptics.tap()
            viewModel.openNote(for: lesson, sourceFrame: sourceFrame())
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

        Button {
            Haptics.tap()
            viewModel.copyNote(for: lesson)
        } label: {
            Label("Kopieren", systemImage: "doc.on.doc")
        }

        if viewModel.hasCopiedNote {
            Button {
                Haptics.tap()
                viewModel.pasteCopiedNote(into: lesson)
            } label: {
                Label("Einfügen", systemImage: "doc.on.clipboard")
            }
        }

        Button(role: .destructive) {
            Haptics.warning()
            // Erst nach dem Schließen des Menüs/Dialogs präsentieren.
            DispatchQueue.main.async {
                requestDelete()
            }
        } label: {
            Label("Notiz löschen", systemImage: "trash")
        }
    }
}

// MARK: - Karte

/// Eine Notiz-Karte in der Übersicht „Nur Notizen“.
///
/// - **Antippen** öffnet die Notiz direkt zum Bearbeiten.
/// - **Gedrückt halten** (Finger oder Apple Pencil) öffnet das Kontextmenü.
/// - **Apple Pencil Pro**: beim Hovern über der Karte einmal *squeezen*
///   (oder beim Pencil 2 doppeltippen) öffnet dieselben Optionen.
private struct NoteOverviewCard: View, Equatable {
    /// Absichtlich kein `@EnvironmentObject`: Das gesamte ViewModel publiziert
    /// auch für Overlay-, Timer- und Navigationsänderungen. Die Karte wird über
    /// ihr Eintrags-Modell und die Darstellungs-Version aktualisiert und durch
    /// `.equatable()` vor diesen globalen Invalidierungen geschützt.
    let viewModel: TimetableViewModel
    let entry: NotesOverviewListView.NotedLesson
    let tag: NoteTag?
    let compact: Bool
    let presentationRevision: UInt
    let relativeDay: Date
    let hoverTracker: NotesOverviewHoverTracker
    @Binding var optionsTarget: Lesson?
    @Binding var deleteTarget: Lesson?

    @State private var frameHolder = NoteCardFrameHolder()

    static func == (lhs: NoteOverviewCard, rhs: NoteOverviewCard) -> Bool {
        lhs.entry == rhs.entry
            && lhs.tag == rhs.tag
            && lhs.compact == rhs.compact
            && lhs.presentationRevision == rhs.presentationRevision
            && lhs.relativeDay == rhs.relativeDay
    }

    private var lesson: Lesson { entry.lesson }

    var body: some View {
        let display = viewModel.resolveSubjectDisplay(for: lesson)
        let hasGradient = display.gradientEndColor != nil
        let backgroundColors = lesson.isCancelled
            ? [Color.gray.opacity(0.35), Color.gray.opacity(0.45)]
            : [display.color, display.gradientEndColor ?? display.color.opacity(0.88)]
        let textColor = lesson.isCancelled ? Color.secondary : display.color.contrastingTextColor

        VStack(alignment: .leading, spacing: compact ? 6 : 10) {
            NoteHeaderContent(
                lesson: lesson,
                display: display,
                displaySettings: viewModel.displaySettings,
                periods: viewModel.periods,
                primaryColor: textColor,
                showsColorCircle: false,
                isCompact: compact,
                teacherDisplayName: viewModel.resolveTeacherName(lesson.teacherRaw),
                originalTeacherDisplayName: lesson.originalTeacher.map { viewModel.resolveTeacherName($0) },
                relativeTo: relativeDay
            ) {
                if let tag {
                    NoteTagPill(tag: tag, size: .small)
                }
            }

            noteContent(textColor: textColor)
        }
        .padding(.horizontal, compact ? 10 : 14)
        .padding(.vertical, compact ? 8 : 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            // Schatten NUR auf der Form – nie auf Text oder Vorschaubild.
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: backgroundColors,
                        startPoint: hasGradient ? .top : .topLeading,
                        endPoint: hasGradient ? .bottom : .bottomTrailing
                    )
                )
                .shadow(
                    color: display.color.opacity(lesson.isCancelled ? 0 : 0.18),
                    radius: 5,
                    x: 0,
                    y: 2
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.24), lineWidth: 1)
        )
        .background(NoteCardFrameProbe(holder: frameHolder))
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .hoverEffect(.lift)
        .onHover { hovering in
            if hovering {
                hoverTracker.hoveredLesson = lesson
            } else if hoverTracker.hoveredLesson?.noteKey == entry.noteKey {
                hoverTracker.hoveredLesson = nil
            }
        }
        .onAppear {
            hoverTracker.register(frameHolder, for: entry.noteKey)
        }
        // Gedrückt halten (Finger oder Apple Pencil) → Kontextmenü.
        .contextMenu {
            NoteOverviewActions(
                viewModel: viewModel,
                lesson: lesson,
                sourceFrame: { frameHolder.currentFrame },
                requestDelete: { deleteTarget = lesson }
            )
        }
        .onTapGesture {
            Haptics.tap()
            viewModel.openNote(for: lesson, sourceFrame: frameHolder.currentFrame)
        }
    }

    // MARK: - Inhalt

    /// Die eigentliche Notiz: Das Vorschaubild wird außerhalb des Main-Threads
    /// heruntergerechnet und gecacht.
    @ViewBuilder
    private func noteContent(textColor: Color) -> some View {
        if let imageData = entry.previewData {
            NotePreviewImage(
                data: imageData,
                cacheKey: entry.previewCacheKey,
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
        if !entry.texts.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(entry.texts.enumerated()), id: \.offset) { _, text in
                    Text(text)
                        .font(.system(size: compact ? 12 : 15, weight: .regular, design: .default))
                        .foregroundColor(textColor)
                        .multilineTextAlignment(.leading)
                }
            }
        } else if entry.previewData == nil {
            // Notiz besteht nur aus einem Tag.
            Text("Keine Inhalte – nur Tag")
                .font(.system(size: compact ? 11 : 13, weight: .regular))
                .foregroundColor(textColor.opacity(0.7))
        }
    }
}

// MARK: - Vorschaubild

/// Kleine, speicherschonende Vorschauansicht für eine Notizkarte – ohne
/// Schatten, damit das Bild beim Scrollen nicht in jedem Frame neu
/// gefiltert werden muss.
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
        let resolvedCacheKey = "\(cacheKey)|\(compact ? 640 : 900)"
        let cached = NotePreviewImageCache.image(for: resolvedCacheKey)
        _image = State(initialValue: cached)
        _didFinishLoading = State(initialValue: cached != nil)
    }

    private var maximumHeight: CGFloat { compact ? 140 : 200 }
    private var maximumPixelSize: Int { compact ? 640 : 900 }
    private var resolvedCacheKey: String { "\(cacheKey)|\(maximumPixelSize)" }

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
            } else if didFinishLoading {
                placeholder()
            } else {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.8))
                    .frame(maxWidth: .infinity)
                    .frame(height: compact ? 92 : 132)
            }
        }
        .task(id: resolvedCacheKey) {
            if let cached = NotePreviewImageCache.image(for: resolvedCacheKey) {
                image = cached
                didFinishLoading = true
                return
            }

            didFinishLoading = false
            let imageData = data
            let key = resolvedCacheKey
            let pixelSize = maximumPixelSize
            // Karten sind deutlich kleiner als die gespeicherte Zeichenfläche –
            // die Vorschau wird daher nicht in voller Größe decodiert.
            let loadedImage = await Task.detached(priority: .utility) {
                NotePreviewImageCache.load(
                    data: imageData,
                    for: key,
                    maximumPixelSize: pixelSize
                )
            }.value

            guard !Task.isCancelled else { return }
            image = loadedImage
            didFinishLoading = true
        }
    }
}

/// NSCache is thread-safe; ImageIO downsampling keeps previews cheap to retain
/// and to composite while the list scrolls.
enum NotePreviewImageCache {
    private static let images: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.totalCostLimit = 64 * 1024 * 1024
        return cache
    }()

    static func image(for key: String) -> UIImage? {
        images.object(forKey: key as NSString)
    }

    static func load(
        data: Data,
        for key: String,
        maximumPixelSize: Int = 960
    ) -> UIImage? {
        if let cached = image(for: key) { return cached }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, maximumPixelSize),
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
