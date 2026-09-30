import SwiftUI
import UIKit

/// Ansichts-Modus "Nur Notizen": chronologische, scrollbare Übersicht aller
/// Stunden, die eine Notiz enthalten (Hausaufgaben, Tests, ...). Der Titel
/// jeder Zeile sieht exakt so aus wie die Kopfzeile über der Zeichenfläche;
/// darunter steht die Notiz selbst. Antippen öffnet die Notiz zum Bearbeiten
/// – genau wie im Stundenplan. Tage/Stunden ohne Notiz erscheinen hier nicht
/// und können auch nicht neu befüllt werden: Die Liste ist eine reine
/// Übersicht. Eine grüne Linie markiert den aktuellen Moment (davor liegen
/// die abgelaufenen Einträge).
public struct NotesOverviewListView: View {
    @EnvironmentObject private var viewModel: TimetableViewModel

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
        /// Liegt der Eintrag bezogen auf den Betrachtungszeitpunkt in der Vergangenheit?
        let isPast: Bool

        var id: String { lesson.noteKey }
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
                let items = buildListItems(relativeTo: timeline.date)
                let usesTwoColumnGrid = shouldUseTwoColumnGrid(in: geometry.size)

                ScrollView(.vertical, showsIndicators: true) {
                    if items.isEmpty {
                        emptyState
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                    } else if usesTwoColumnGrid {
                        twoColumnOverview(items: items, relativeTo: timeline.date)
                    } else {
                        listOverview(items: items, relativeTo: timeline.date)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemBackground))
    }

    private func shouldUseTwoColumnGrid(in size: CGSize) -> Bool {
        UIDevice.current.userInterfaceIdiom == .pad && size.width > size.height && size.width >= 760
    }

    private func listOverview(items: [ListItem], relativeTo date: Date) -> some View {
        LazyVStack(alignment: .leading, spacing: 12) {
            ForEach(items) { item in
                switch item {
                case .nowLine:
                    nowLine(relativeTo: date)
                        .padding(.vertical, 4)
                case .dayHeader(let date):
                    dayHeader(for: date)
                        .padding(.top, 8)
                case .row(let entry):
                    noteRow(entry: entry, compact: true)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
    }

    private func twoColumnOverview(items: [ListItem], relativeTo date: Date) -> some View {
        LazyVStack(alignment: .leading, spacing: 12) {
            ForEach(buildOverviewRows(from: items)) { row in
                switch row {
                case .full(let item):
                    switch item {
                    case .nowLine:
                        nowLine(relativeTo: date)
                            .padding(.vertical, 4)
                    case .dayHeader(let headerDate):
                        dayHeader(for: headerDate)
                            .padding(.top, 8)
                    case .row(let entry):
                        noteRow(entry: entry, compact: true)
                    }
                case .cards(let entries):
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(entries) { entry in
                            noteRow(entry: entry, compact: true)
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                        }
                        if entries.count == 1 {
                            Spacer(minLength: 0)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
    }

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
                if pendingCards.count == 2 {
                    flushPendingCards()
                }
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
    private func buildListItems(relativeTo now: Date) -> [ListItem] {
        let entries = collectEntries(relativeTo: now)
        guard !entries.isEmpty else { return [] }

        var items: [ListItem] = []
        var lastDateString: String? = nil
        var insertedNowLine = false

        for entry in entries {
            if !insertedNowLine, !entry.isPast {
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

    /// Alle Stunden mit sichtbarer Notiz, aufsteigend nach Datum und
    /// Startzeit sortiert (Doppelstunden bleiben ein Eintrag).
    private func collectEntries(relativeTo now: Date) -> [NotedLesson] {
        let dateStrings = Set(viewModel.lessons.map { $0.dateString })
        let sortedPeriods = viewModel.periods.sorted { $0.periodNumber < $1.periodNumber }
        let nowMinutes = minutesOfDay(at: now)

        var entries: [NotedLesson] = []

        for dateString in dateStrings {
            guard let date = Date.fromYyyyMMdd(dateString) else { continue }
            for lesson in viewModel.lessonsFor(day: date) {
                guard let note = viewModel.noteFor(lesson: lesson), note.hasVisibleContent else { continue }

                let startMinutes = sortedPeriods
                    .first(where: { $0.periodNumber == lesson.periodNumber })?
                    .startMinutes ?? lesson.periodNumber * 60
                let endPeriodNumber = lesson.periodNumber + max(1, lesson.durationPeriods) - 1
                let endMinutes = sortedPeriods
                    .first(where: { $0.periodNumber == endPeriodNumber })?
                    .endMinutes ?? (startMinutes + 45)

                let isPast: Bool
                if Calendar.germanCalendar.isDate(date, inSameDayAs: now) {
                    isPast = endMinutes <= nowMinutes
                } else {
                    isPast = date < now
                }

                entries.append(
                    NotedLesson(
                        lesson: lesson,
                        note: note,
                        date: date,
                        startMinutes: startMinutes,
                        endMinutes: endMinutes,
                        isPast: isPast
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Aktueller Zeitpunkt")
    }

    private func nowLabel(relativeTo date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "HH:mm"
        return "Jetzt • \(formatter.string(from: date)) Uhr"
    }

    /// Eine Zeile: Titel exakt wie über der Zeichenfläche, darunter die Notiz.
    private func noteRow(entry: NotedLesson, compact: Bool) -> some View {
        let display = viewModel.resolveSubjectDisplay(for: entry.lesson)

        return VStack(alignment: .leading, spacing: compact ? 8 : 10) {
            NoteHeaderContent(
                lesson: entry.lesson,
                display: display,
                displaySettings: viewModel.displaySettings,
                periods: viewModel.periods,
                primaryColor: .primary
            )

            noteContent(for: entry.note, compact: compact)
        }
        .padding(.horizontal, compact ? 11 : 14)
        .padding(.vertical, compact ? 8 : 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlassCard(cornerRadius: 14, strokeOpacity: 0.2)
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .hoverEffect(.lift)
        .onTapGesture {
            Haptics.tap()
            viewModel.openNote(for: entry.lesson, sourceFrame: .zero)
        }
    }

    /// Die eigentliche Notiz: gerenderte Vorschau (Handschrift + Textfelder),
    /// mit Text-Fallback, falls kein Vorschaubild existiert.
    @ViewBuilder
    private func noteContent(for note: LessonNote, compact: Bool) -> some View {
        if let imageData = note.croppedImageData, let image = UIImage(data: imageData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(
                    maxWidth: compact ? 360 : 460,
                    maxHeight: compact ? 150 : 190,
                    alignment: .leading
                )
                .padding(compact ? 4 : 6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.7))
                )
        } else {
            let texts = note.textBoxes
                .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            if !texts.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(texts.enumerated()), id: \.offset) { _, text in
                        Text(text)
                            .font(.system(size: compact ? 14 : 15, weight: .regular, design: .default))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                    }
                }
            }
        }
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
