import Foundation
import SwiftUI
import Combine

/// Anzeigename und Farben (inkl. optionalem Farbverlauf) eines Fachs.
/// Alle Farben sind bereits pastellisiert.
public struct SubjectDisplay {
    public let name: String
    public let colorHex: String
    public let color: Color
    public let gradientEndColor: Color?

    public init(name: String, colorHex: String, color: Color, gradientEndColor: Color? = nil) {
        self.name = name
        self.colorHex = colorHex
        self.color = color
        self.gradientEndColor = gradientEndColor
    }
}

/// Haupt-ViewModel zur Verwaltung von Stundenplan, Untis-Synchronisation, Einstellungen und Notizen
@MainActor
public final class TimetableViewModel: ObservableObject {
    // MARK: - Published State

    /// Ändert sich nur, wenn Stunden, Stundenzeiten oder Notizen geändert
    /// werden. Die „Nur Notizen“-Übersicht kann ihre teure Datensammlung so
    /// zwischenspeichern, statt sie bei jeder SwiftUI-Aktualisierung erneut
    /// aus allen gespeicherten Stunden aufzubauen.
    @Published public private(set) var notesOverviewRevision: UInt = 0

    /// Version der Darstellung einer Notiz-Karte. Sie wird nur bei Änderungen
    /// an den Kartendaten bzw. deren Beschriftung erhöht. So können die Karten
    /// globale ViewModel-Änderungen (z. B. das Öffnen des Zeichen-Overlays)
    /// ignorieren, statt beim Scrollen/Tippen alle Header neu aufzubauen.
    /// Die zugrunde liegenden @Published-Eigenschaften lösen das Update aus;
    /// diese Version selbst muss daher nicht noch ein zweites Mal publizieren.
    public private(set) var notesOverviewPresentationRevision: UInt = 0

    @Published public var selectedWeekStart: Date
    @Published public var periods: [Period] = [] {
        didSet {
            notesOverviewRevision &+= 1
            notesOverviewPresentationRevision &+= 1
        }
    }
    @Published public var lessons: [Lesson] = [] {
        didSet { notesOverviewRevision &+= 1 }
    }
    @Published public var subjectCustomizations: [SubjectCustomization] = [] {
        didSet { notesOverviewPresentationRevision &+= 1 }
    }
    @Published public var teacherNameCustomizations: [TeacherNameCustomization] = [] {
        didSet { notesOverviewPresentationRevision &+= 1 }
    }
    @Published public var displaySettings: BlockDisplaySettings = .default {
        didSet { notesOverviewPresentationRevision &+= 1 }
    }
    @Published public var drawingSettings: DrawingSettings = .default
    @Published public var untisCredentials: UntisCredentials = UntisCredentials()
    @Published public var lessonNotes: [String: LessonNote] = [:] {
        didSet { notesOverviewRevision &+= 1 }
    }
    /// Aktueller Ansichts-Modus (Standard / Notizen hervorgehoben / Nur Notizen).
    /// Wird persistent gespeichert und beim Start wiederhergestellt.
    @Published public var viewMode: TimetableViewMode = .standard

    /// Tag-System (Einstellungen → „Tag-System“). Änderungen an Tags
    /// (Name/Farbe) müssen die Notiz-Karten neu beschriften.
    @Published public var tagSettings: NoteTagSettings = NoteTagSettings() {
        didSet { notesOverviewPresentationRevision &+= 1 }
    }

    /// Ausgewählte Tag-Filter der „Nur Notizen“-Übersicht. Leer = alle Notizen.
    @Published public var activeTagFilter: Set<UUID> = []

    /// Interne „Zwischenablage“ für Notizen (Kontextmenü → Kopieren/Einfügen).
    /// Enthält die komplette Notiz inkl. Zeichnung, Textfeldern, Hintergrund
    /// und Tag. Bleibt für die Dauer der Sitzung erhalten.
    @Published public private(set) var copiedNote: LessonNote? = nil

    /// Höchstzahl manuell angelegter Fächer bzw. Lehrkräfte.
    public static let maximumSubjectCustomizations = 50
    public static let maximumTeacherNameCustomizations = 50

    /// Modellhinweis aus tatsächlich beobachtetem Pencil-Input. Ein Squeeze
    /// identifiziert den Pro; die Akkuanzeige bleibt leer, solange CoreBluetooth
    /// keinen tatsächlichen Pencil-Batteriewert liefert. Der letzte Stand wird
    /// gespeichert und beim Start wiederhergestellt.
    @Published public private(set) var detectedApplePencilName: String? = nil
    @Published public private(set) var applePencilBatteryLevel: Int? = nil
    /// Ob ein Squeeze in dieser Installation den Pencil Pro bestätigt hat.
    private var applePencilKnownAsPro = false

    /// Erscheinungsbild der App. Standard ist **hell** (siehe ``AppAppearance``),
    /// damit weißes Papier niemals weiße Schrift bekommt.
    @Published public var appearance: AppAppearance = .fallback

    /// Wochen (Schlüssel `yyyy-MM-dd` des Montags), die gerade von der API
    /// geladen werden. Solange eine noch nie geladene Woche lädt, zeigt der
    /// Stundenplan ein drehendes Lade-Symbol in der Mitte.
    @Published public var loadingWeekKeys: Set<String> = []

    /// Fehlermeldung des letzten API-Abgleichs (`nil` = kein Fehler). Wird für
    /// den Einrichtungs-Guide ausgewertet, wenn die Daten offenbar ungültig sind.
    @Published public var lastSyncFailure: String? = nil

    /// Kategorie, die beim nächsten Öffnen der Einstellungen direkt angezeigt
    /// wird (z. B. „WebUntis & Sync“ aus dem Einrichtungs-Guide).
    @Published var settingsLaunchCategory: SettingsCategory? = nil

    // Letzter Synchronisationszeitpunkt für die Statusanzeige
    @Published public var lastSyncDate: Date? = nil

    // Aktive Notiz-Ansicht (Zeichnen-Overlay)
    private struct ActiveNotePresentation {
        let lesson: Lesson
        let sourceFrame: CGRect
    }

    @Published private var activeNotePresentation: ActiveNotePresentation? = nil

    public var activeNoteLesson: Lesson? { activeNotePresentation?.lesson }
    public var isDrawingOverlayPresented: Bool { activeNotePresentation != nil }
    /// Bildschirm-Rahmen der Karte, aus der die Zeichenfläche geöffnet wurde.
    public var activeNoteSourceFrame: CGRect { activeNotePresentation?.sourceFrame ?? .zero }

    // Navigation & UI State
    @Published public var isSettingsPresented: Bool = false
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String? = nil
    @Published public var successMessage: String? = nil
    /// -1 = ältere Woche gleitet von links herein, 1 = neuere Woche von rechts.
    @Published public private(set) var weekNavigationDirection: Int = 1
    /// Wird vom "Heute"-Button gesetzt: Der Stundenplan soll animiert (per
    /// Rutsch-Animation, nicht Überblendung) zu dieser Woche wechseln.
    @Published public var weekJumpRequest: Date? = nil

    private var activeSyncCount: Int = 0
    private var lastSyncAttemptDate: Date?
    /// Wochen, die in dieser Sitzung schon erfolgreich von der API geladen
    /// wurden – auch wenn sie (z. B. in den Ferien) keine Stunden enthalten.
    /// So erscheint das Lade-Symbol beim erneuten Hineinwischen nicht wieder.
    private var loadedWeekKeys: Set<String> = []
    /// Cache sichtbarer Notiz-Keys. Das vermeidet wiederholtes Decodieren großer
    /// PKDrawing-Daten während SwiftUI den Stundenplan neu rendert.
    private var visibleNoteKeys: Set<String> = []
    private var autoRefreshTimer: AnyCancellable? = nil
    private var applePencilBatteryMonitor: ApplePencilBatteryMonitor?
    private var applePencilBatteryObservation: AnyCancellable?
    private var applePencilNameObservation: AnyCancellable?
    /// Undo/Redo der letzten drei geöffneten Notizen.
    private var noteUndoSessions = NoteUndoSessionStore()
    private let storage = TimetableStorageService.shared
    private let untis = WebUntisService.shared
    private let demo = DemoDataService.shared

    // MARK: - Initializer

    public init() {
        self.selectedWeekStart = Date().startOfWeek()
        loadInitialData()
        setupAutoRefresh()
    }

    private func loadInitialData() {
        self.untisCredentials = storage.loadCredentials()
        self.subjectCustomizations = storage.loadCustomizations()
        self.teacherNameCustomizations = storage.loadTeacherNameCustomizations()
        self.displaySettings = storage.loadDisplaySettings()
        self.drawingSettings = storage.loadDrawingSettings()
        self.periods = storage.loadPeriods()
        self.lessons = storage.loadLessons()
        self.lessonNotes = storage.loadAllLessonNotes()
        self.viewMode = storage.loadViewMode()
        self.appearance = storage.loadAppearance()
        self.tagSettings = storage.loadTagSettings()
        self.lastSyncDate = untisCredentials.lastSyncDate
        self.noteUndoSessions = storage.loadNoteUndoSessions()
        restoreApplePencilStatus()

        // Alte, versehentlich leer gespeicherte Notizen (PKDrawing-Daten ohne
        // Strokes / leere Textfelder) direkt entfernen, damit sie nicht in
        // Optionen, Hervorhebung oder der Nur-Notizen-Übersicht auftauchen.
        cleanupEmptyNotes()
        rebuildVisibleNoteCache()

        // Optional: Notizen zu bereits vergangenen Stunden automatisch entfernen
        cleanupPastNotesIfEnabled()

        // Falls noch keine Perioden definiert sind, Standardraster laden
        if periods.isEmpty {
            self.periods = Period.defaultPeriods
            storage.savePeriods(periods)
        }

        // Falls automatische Synchronisation aktiv und Zugangsdaten vorhanden sind
        if untisCredentials.isConfigured && untisCredentials.autoSyncOnLaunch {
            Task {
                await syncWithUntis()
            }
        }
    }

    /// Häufig prüfen, aber frisch geladene Daten weiterhin nur alle fünf
    /// Minuten abrufen. Veraltete Daten werden nach Fehlern schneller erneut
    /// angefragt; dieselbe Prüfung läuft beim Zurückkehren in die App.
    private func setupAutoRefresh() {
        autoRefreshTimer = Timer.publish(every: TimetableRefreshPolicy.checkInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task(priority: .userInitiated) { @MainActor [weak self] in
                    await self?.refreshTimetableIfNeeded()
                }
            }
    }

    public func isTimetableStale(relativeTo now: Date = Date()) -> Bool {
        TimetableRefreshPolicy.isStale(
            lastSuccess: lastSyncDate ?? untisCredentials.lastSyncDate,
            now: now
        )
    }

    /// Leise automatische Aktualisierung. Ein laufender Abruf wird nicht
    /// dupliziert, und fehlende Zugangsdaten lösen keine Endlosversuche aus.
    public func refreshTimetableIfNeeded() async {
        guard untisCredentials.hasCompleteCredentials, !isLoading,
              TimetableRefreshPolicy.shouldRefresh(
                lastSuccess: lastSyncDate ?? untisCredentials.lastSyncDate,
                lastAttempt: lastSyncAttemptDate,
                now: Date()
              ) else { return }
        await syncWeek(startingAt: selectedWeekStart, showsSuccessMessage: false, reportsErrors: false)
    }

    /// Formatiert die Zeit seit der letzten Synchronisation dynamisch (Sekunden / Minuten)
    public func relativeLastSyncString(relativeTo now: Date = Date()) -> String {
        guard let date = lastSyncDate ?? untisCredentials.lastSyncDate else {
            return "Noch nicht aktualisiert"
        }
        let seconds = max(0, Int(now.timeIntervalSince(date)))
        if seconds < 5 {
            return "Gerade eben"
        } else if seconds < 60 {
            return "Vor \(seconds) Sekunden"
        } else {
            let minutes = seconds / 60
            if minutes == 1 {
                return "Vor 1 Minute"
            } else {
                return "Vor \(minutes) Minuten"
            }
        }
    }

    // MARK: - Week Navigation

    /// Gibt an, ob die aktuell angezeigte Woche der für die Navigation
    /// relevanten "aktuellen Woche" entspricht (am Wochenende bereits die
    /// Folgewoche). Wird verwendet, um den "Zur aktuellen Woche"-Button
    /// im Header ein- bzw. auszublenden.
    public func isViewingRelevantCurrentWeek(relativeTo date: Date = Date()) -> Bool {
        selectedWeekStart == Date.relevantCurrentWeekStart(from: date)
    }

    /// Springt zur aktuellen Woche zurück und lädt genau diese Woche nach.
    /// Am Wochenende (wenn kein Tag der laufenden Woche mehr "heute" sein
    /// kann) springt dies direkt zur nächsten Schulwoche.
    public func goToCurrentWeek() {
        let current = Date.relevantCurrentWeekStart()
        weekNavigationDirection = current >= selectedWeekStart ? 1 : -1
        selectWeek(current)
    }

    /// Fordert einen animierten Rutsch zur aktuellen Woche an. Die eigentliche
    /// Slide-Animation übernimmt die TimetableView (Wochen-Karussell).
    public func requestJumpToCurrentWeek() {
        let target = Date.relevantCurrentWeekStart()
        guard target != selectedWeekStart else { return }
        weekJumpRequest = target
    }

    /// Springt zur nächsten Woche. Die Navigation wird bewusst nur per Swipe aufgerufen.
    public func goToNextWeek() {
        guard let next = Calendar.germanCalendar.date(byAdding: .day, value: 7, to: selectedWeekStart) else { return }
        weekNavigationDirection = 1
        selectWeek(next)
    }

    /// Springt zur vorherigen Woche. Die Navigation wird bewusst nur per Swipe aufgerufen.
    public func goToPreviousWeek() {
        guard let previous = Calendar.germanCalendar.date(byAdding: .day, value: -7, to: selectedWeekStart) else { return }
        weekNavigationDirection = -1
        selectWeek(previous)
    }

    public func selectWeek(_ weekStart: Date) {
        let normalizedStart = weekStart.startOfWeek()
        guard normalizedStart != selectedWeekStart else { return }
        selectedWeekStart = normalizedStart

        guard untisCredentials.isConfigured else { return }
        Task {
            await syncWeek(startingAt: normalizedStart, showsSuccessMessage: false)
        }
    }

    /// Sets the appearance and persists it immediately.
    public func setAppearance(_ newAppearance: AppAppearance) {
        guard appearance != newAppearance else { return }
        appearance = newAppearance
        storage.saveAppearance(newAppearance)
    }

    /// Öffnet die Einstellungen – optional direkt auf einer bestimmten Seite
    /// (z. B. „WebUntis & Sync“ aus dem Einrichtungs-Guide).
    ///
    /// Bewusst `internal`: `SettingsCategory` ist ein Typ der Settings-Ansicht
    /// und soll nicht Teil der öffentlichen ViewModel-Schnittstelle sein.
    func openSettings(category: SettingsCategory? = nil) {
        settingsLaunchCategory = category
        isSettingsPresented = true
    }

    // MARK: - Ladefortschritt der API-Wochen

    /// Schlüssel einer Woche (`yyyy-MM-dd` des Montags).
    public func weekKey(for date: Date) -> String {
        return date.startOfWeek().yyyyMMddString
    }

    /// Ob überhaupt irgendeine Stunde gespeichert ist – egal in welcher Woche.
    public var hasAnyLessons: Bool { !lessons.isEmpty }

    /// Für „Nur Notizen“: Ohne jede Stunde (und damit ohne jede Notiz) sowie
    /// mit unvollständigen API-Daten zeigt auch diese Übersicht den Guide.
    public var shouldShowUntisSetupGuideWithoutData: Bool {
        !hasAnyLessons && !untisCredentials.hasCompleteCredentials && !isLoading
    }

    /// Ob es in der angegebenen Woche überhaupt gespeicherte Stunden gibt.
    public func hasLessons(inWeekStarting weekStart: Date) -> Bool {
        let dayKeys = Set(weekStart.schoolWeekDays().map { $0.yyyyMMddString })
        return lessons.contains { dayKeys.contains($0.dateString) }
    }

    /// Ob für diese Woche gerade Daten von der API geholt werden.
    public func isLoadingWeek(_ weekStart: Date) -> Bool {
        return loadingWeekKeys.contains(weekKey(for: weekStart))
    }

    /// Ob eine Woche gerade zum **ersten Mal** geladen wird: Dann bleibt das
    /// drehende Lade-Symbol so lange sichtbar, bis die API geantwortet hat.
    public func isWeekPendingInitialLoad(_ weekStart: Date) -> Bool {
        let key = weekKey(for: weekStart)
        guard loadingWeekKeys.contains(key) else { return false }
        return !loadedWeekKeys.contains(key) && !hasLessons(inWeekStarting: weekStart)
    }

    /// Ob statt des (leeren) Stundenplans der Einrichtungs-Guide erscheinen
    /// soll: Es gibt keine Stunden und die API-Daten fehlen, sind unvollständig
    /// oder der letzte Abgleich ist fehlgeschlagen.
    public func shouldShowUntisSetupGuide(for weekStart: Date) -> Bool {
        guard !isWeekPendingInitialLoad(weekStart) else { return false }
        guard !hasLessons(inWeekStarting: weekStart) else { return false }
        if !untisCredentials.hasCompleteCredentials { return true }
        return lastSyncFailure != nil
    }

    /// Zeigt eine Stunde aus der „Nur Notizen“-Übersicht im Standard-Modus:
    /// Der Ansichts-Modus wechselt und die App wischt automatisch zur Woche
    /// der Stunde (inkl. Nachladen von der API, falls nötig).
    public func revealLessonInStandardMode(_ lesson: Lesson) {
        guard let date = Date.fromYyyyMMdd(lesson.dateString) else { return }
        let targetWeek = date.startOfWeek()

        if viewMode != .standard {
            setViewMode(.standard)
        }

        guard targetWeek != selectedWeekStart else { return }
        weekNavigationDirection = targetWeek > selectedWeekStart ? 1 : -1
        selectWeek(targetWeek)
    }

    // MARK: - Apple Pencil

    /// Wird aufgerufen, sobald die App irgendwo einen echten Apple-Pencil-Input
    /// bemerkt (Hover, Strich oder Doppeltipp). Dann wird „Nur Apple Pencil“
    /// automatisch eingeschaltet und gespeichert.
    public func registerApplePencilUsage() {
        guard !drawingSettings.applePencilOnly else { return }
        drawingSettings.applePencilOnly = true
        storage.saveDrawingSettings(drawingSettings)
    }

    /// Öffentliche UIKit/PencilKit-Callbacks bestätigen aktiven Pencil-Input,
    /// aber nicht die konkrete Modellgeneration. Deshalb erscheint zunächst
    /// nur die sichere, allgemeine Bezeichnung.
    public func registerObservedApplePencilInput() {
        if detectedApplePencilName == nil {
            applyApplePencilIdentity(name: "Apple Pencil", batteryLevel: applePencilBatteryLevel)
        }
        startApplePencilBatteryMonitoring()
        registerApplePencilUsage()
    }

    /// Squeeze ist nur beim Apple Pencil Pro verfügbar und identifiziert ihn
    /// daher zuverlässig.
    public func registerApplePencilSqueeze() {
        applePencilKnownAsPro = true
        applyApplePencilIdentity(name: "Apple Pencil Pro", batteryLevel: applePencilBatteryLevel)
        startApplePencilBatteryMonitoring()
        registerApplePencilUsage()
    }

    /// Startet die BLE-Abfrage erst, sobald echter Pencil-Input erkannt wurde.
    /// Das verhindert eine Bluetooth-Berechtigungsabfrage direkt beim Start.
    private func startApplePencilBatteryMonitoring() {
        guard applePencilBatteryMonitor == nil else {
            applePencilBatteryMonitor?.startMonitoring()
            return
        }

        let monitor = ApplePencilBatteryMonitor()
        applePencilBatteryMonitor = monitor
        applePencilBatteryObservation = monitor.$batteryLevel
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] level in
                guard let self else { return }
                if let level {
                    self.applyApplePencilIdentity(
                        name: self.detectedApplePencilName ?? "Apple Pencil",
                        batteryLevel: level
                    )
                }
            }
        applePencilNameObservation = monitor.$pencilName
            .compactMap { $0 }
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] peripheralName in
                guard let self else { return }
                let resolved = ApplePencilStatusSnapshot.resolvedName(
                    fromPeripheralName: peripheralName,
                    knownPro: self.applePencilKnownAsPro
                )
                if resolved.localizedCaseInsensitiveContains("Pro") {
                    self.applePencilKnownAsPro = true
                }
                self.applyApplePencilIdentity(name: resolved, batteryLevel: self.applePencilBatteryLevel)
            }
        monitor.startMonitoring()
    }

    private func restoreApplePencilStatus() {
        guard let snapshot = storage.loadApplePencilStatus() else { return }
        detectedApplePencilName = snapshot.name
        applePencilBatteryLevel = snapshot.batteryLevel
        applePencilKnownAsPro = snapshot.name.localizedCaseInsensitiveContains("Pro")
    }

    private func applyApplePencilIdentity(name: String, batteryLevel: Int?) {
        let resolved = ApplePencilStatusSnapshot.resolvedName(
            fromPeripheralName: name,
            knownPro: applePencilKnownAsPro
        )
        let changed = detectedApplePencilName != resolved || applePencilBatteryLevel != batteryLevel
        detectedApplePencilName = resolved
        applePencilBatteryLevel = batteryLevel
        guard changed else { return }
        storage.saveApplePencilStatus(
            ApplePencilStatusSnapshot(name: resolved, batteryLevel: batteryLevel)
        )
    }

    public func persistedUndoSession(for noteKey: String) -> PersistedNoteUndoSession? {
        noteUndoSessions.session(for: noteKey)
    }

    public func saveUndoSession(_ session: PersistedNoteUndoSession) {
        guard !session.undoStack.isEmpty || !session.redoStack.isEmpty else {
            noteUndoSessions.removeSession(for: session.noteKey)
            storage.saveNoteUndoSessions(noteUndoSessions)
            return
        }
        noteUndoSessions.save(session)
        storage.saveNoteUndoSessions(noteUndoSessions)
    }

    public func discardUndoSession(for noteKey: String) {
        noteUndoSessions.removeSession(for: noteKey)
        storage.saveNoteUndoSessions(noteUndoSessions)
    }

    /// Merkt sich, dass der letzte API-Abgleich fehlgeschlagen ist.
    private func noteSyncFailure(_ message: String) {
        lastSyncFailure = message
    }

    // MARK: - Timetable Queries & Lesson Merging

    /// Gibt alle Unterrichtsstunden für einen bestimmten Tag zurück, zusammengefasst zu Doppelstunden
    public func lessonsFor(day: Date) -> [Lesson] {
        let dateStr = day.yyyyMMddString
        let dayLessons = lessons.filter { $0.dateString == dateStr }
        let sorted = dayLessons.sorted { $0.periodNumber < $1.periodNumber }

        var merged: [Lesson] = []
        var i = 0
        while i < sorted.count {
            var current = sorted[i]
            if i + 1 < sorted.count {
                let next = sorted[i + 1]
                if current.canMergeWithNext(lesson: next) {
                    current.durationPeriods = 2
                    merged.append(current)
                    i += 2
                    continue
                }
            }
            merged.append(current)
            i += 1
        }

        return merged
    }

    /// Findet eine Stunde für einen bestimmten Tag und Stundennummer
    public func lessonAt(day: Date, periodNumber: Int) -> Lesson? {
        let dayList = lessonsFor(day: day)
        for l in dayList {
            if l.periodNumber == periodNumber || (l.durationPeriods == 2 && l.periodNumber + 1 == periodNumber) {
                return l
            }
        }
        return nil
    }

    /// Ermittelt den Anzeigennamen und die Farben für ein Fach. Alle Farben
    /// werden pastellisiert – egal was eingestellt ist, es gibt einen
    /// maximalen Schwarz-Anteil.
    public func resolveSubjectDisplay(for lesson: Lesson) -> SubjectDisplay {
        let raw = lesson.subjectRaw.trimmingCharacters(in: .whitespacesAndNewlines)

        func display(for custom: SubjectCustomization) -> SubjectDisplay {
            let name = custom.customName.isEmpty ? raw : custom.customName
            let endColor = custom.gradientEndHex.map { Color(hex: $0).pastel }
            return SubjectDisplay(
                name: name,
                colorHex: custom.colorHex,
                color: Color(hex: custom.colorHex).pastel,
                gradientEndColor: endColor
            )
        }

        // 1. Suche in benutzerdefinierten Fächereinstellungen
        if let custom = subjectCustomizations.first(where: {
            $0.originalSubject.caseInsensitiveCompare(raw) == .orderedSame ||
            $0.originalSubject.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == raw.lowercased()
        }) {
            return display(for: custom)
        }

        // 2. Suche nach Teilübereinstimmung (z.B. "M-LK" matcht "M")
        for custom in subjectCustomizations {
            if raw.lowercased().hasPrefix(custom.originalSubject.lowercased()) && !custom.originalSubject.isEmpty {
                return display(for: custom)
            }
        }

        // 3. Fallback: Dynamische Farbgenerierung basierend auf Fachname
        let fallbackColors = [
            "#3B82F6", "#10B981", "#8B5CF6", "#F59E0B", "#EC4899",
            "#06B6D4", "#6366F1", "#14B8A6", "#EF4444", "#84CC16"
        ]
        let hash = abs(raw.hashValue)
        let colorHex = fallbackColors[hash % fallbackColors.count]
        return SubjectDisplay(
            name: raw,
            colorHex: colorHex,
            color: Color(hex: colorHex).pastel,
            gradientEndColor: nil
        )
    }

    /// Ersetzt ein Lehrer-Kürzel durch den manuell hinterlegten Anzeigenamen.
    /// Die Liste wird absichtlich nie automatisch gefüllt: Nur Einträge aus den
    /// Einstellungen werden hier berücksichtigt.
    public func resolveTeacherName(_ rawTeacher: String) -> String {
        let trimmed = rawTeacher.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }

        let normalizedRaw = normalizedTeacherKey(trimmed)
        guard let custom = teacherNameCustomizations.first(where: {
            normalizedTeacherKey($0.systemAbbreviation) == normalizedRaw
        }) else {
            return trimmed
        }

        let displayName = custom.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return displayName.isEmpty ? trimmed : displayName
    }

    private func normalizedTeacherKey(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
    }

    // MARK: - Ansichts-Modus

    /// Wechselt den Ansichts-Modus und speichert ihn sofort, damit er beim
    /// nächsten App-Start wieder aktiv ist.
    public func setViewMode(_ mode: TimetableViewMode) {
        guard viewMode != mode else { return }

        // Der Wechsel zu „Nur Notizen“ kann viele heruntergerechnete
        // Vorschauen einhängen. Eine implizite Animation hält gleichzeitig
        // noch das komplette Drei-Wochen-Raster im Compositor und lässt beide
        // aufwändigen Hierarchien über mehrere Frames rendern. Der Moduswechsel
        // selbst ist deshalb bewusst unmittelbar; die Karten laden danach
        // lazy und ohne einen UI-Frame zu blockieren.
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            viewMode = mode
        }
        storage.saveViewMode(mode)
    }

    /// Prüft, ob eine Stunde eine Notiz mit sichtbarem Inhalt hat.
    public func hasVisibleNote(for lesson: Lesson) -> Bool {
        visibleNoteKeys.contains(lesson.noteKey)
    }

    // MARK: - Drawing & Notes Handling

    /// Öffnet die Zeichnen-Notiz-Ansicht für eine Stunde. `sourceFrame` ist der
    /// Bildschirm-Rahmen der angetippten Fach-Karte (globale Koordinaten) und
    /// wird als Startpunkt der Zoom-Animation verwendet.
    public func openNote(for lesson: Lesson, sourceFrame: CGRect = .zero) {
        let presentation = ActiveNotePresentation(lesson: lesson, sourceFrame: sourceFrame)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
            activeNotePresentation = presentation
        }
    }

    /// Schließt und speichert die Notiz
    public func saveNote(
        for lesson: Lesson,
        drawingData: Data,
        croppedImageData: Data?,
        lineCount: Int,
        textBoxes: [NoteTextBox] = [],
        backgroundStyle: NoteBackgroundStyle = .blank,
        backgroundScale: Double = NoteBackgroundMetrics.defaultScale,
        tagID: UUID? = nil
    ) {
        let key = lesson.noteKey
        // Ein Tag zählt nur, solange er im Tag-System noch existiert.
        let resolvedTagID = tagSettings.tag(withID: tagID)?.id
        let note = LessonNote(
            id: key,
            drawingData: drawingData,
            croppedImageData: croppedImageData,
            lineCount: lineCount,
            textBoxes: textBoxes,
            backgroundStyle: backgroundStyle,
            backgroundScale: backgroundScale,
            tagID: resolvedTagID,
            updatedAt: Date()
        )

        if note.hasVisibleContent {
            self.lessonNotes[key] = note
            visibleNoteKeys.insert(key)
            storage.saveLessonNote(note)
        } else {
            // Eine nur geöffnete, komplett geleerte oder nur mit Tag versehene
            // Seite bleibt wirklich "keine Notiz". Ein Tag ohne Inhalt wird
            // verworfen, damit keine leeren Stundenblöcke mit Tag entstehen.
            self.lessonNotes.removeValue(forKey: key)
            visibleNoteKeys.remove(key)
            storage.deleteLessonNote(for: key)
            discardUndoSession(for: key)
        }

        withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
            activeNotePresentation = nil
        }
    }

    /// Gibt die Notiz für eine bestimmte Stunde zurück
    public func noteFor(lesson: Lesson) -> LessonNote? {
        return lessonNotes[lesson.noteKey]
    }

    /// Löscht die Notiz einer einzelnen Stunde.
    public func deleteNote(for lesson: Lesson) {
        let key = lesson.noteKey
        guard lessonNotes[key] != nil else { return }
        lessonNotes.removeValue(forKey: key)
        visibleNoteKeys.remove(key)
        storage.deleteLessonNote(for: key)
        discardUndoSession(for: key)
        successMessage = "Notiz gelöscht."
    }

    // MARK: - Notizen kopieren & einfügen

    /// Ob eine gültige kopierte Notiz zum Einfügen bereitliegt.
    public var hasCopiedNote: Bool {
        guard let copiedNote else { return false }
        return copiedNote.hasVisibleContent
    }

    /// Kopiert die komplette Notiz einer Stunde (Zeichnung, Textfelder,
    /// Hintergrund, Tag) in die interne Zwischenablage.
    public func copyNote(for lesson: Lesson) {
        guard let note = lessonNotes[lesson.noteKey], note.hasVisibleContent else { return }
        copyNote(note)
    }

    /// Kopiert einen beliebigen Notiz-Zustand (z. B. den aktuell geöffneten
    /// Editor-Zustand) in die interne Zwischenablage.
    public func copyNote(_ note: LessonNote) {
        guard note.hasVisibleContent else { return }
        copiedNote = note
        successMessage = "Notiz kopiert."
    }

    /// Fügt die kopierte Notiz in die Stunde ein. Eine vorhandene Notiz wird
    /// vollständig ersetzt.
    public func pasteCopiedNote(into lesson: Lesson) {
        guard let copiedNote, copiedNote.hasVisibleContent else { return }
        let key = lesson.noteKey
        let pasted = LessonNote(
            id: key,
            drawingData: copiedNote.drawingData,
            croppedImageData: copiedNote.croppedImageData,
            lineCount: copiedNote.lineCount,
            textBoxes: copiedNote.textBoxes,
            backgroundStyle: copiedNote.backgroundStyle,
            backgroundScale: copiedNote.backgroundScale,
            tagID: tagSettings.tag(withID: copiedNote.tagID)?.id,
            updatedAt: Date()
        )
        lessonNotes[key] = pasted
        visibleNoteKeys.insert(key)
        storage.saveLessonNote(pasted)
        successMessage = "Notiz eingefügt."
    }

    // MARK: - Tag-System

    public func saveTagSettings() {
        storage.saveTagSettings(tagSettings)
    }

    /// Tag einer Stunde (nur wenn das Tag-System aktiv ist und der Tag noch existiert).
    public func tag(for lesson: Lesson) -> NoteTag? {
        guard tagSettings.isEnabled else { return nil }
        return tagSettings.tag(withID: lessonNotes[lesson.noteKey]?.tagID)
    }

    /// Tag zu einer Notiz-ID (nur wenn das Tag-System aktiv ist).
    public func tag(forNoteKey key: String) -> NoteTag? {
        guard tagSettings.isEnabled else { return nil }
        return tagSettings.tag(withID: lessonNotes[key]?.tagID)
    }

    /// Setzt oder entfernt den Tag einer vorhandenen Notiz direkt (ohne den
    /// Editor zu öffnen).
    public func setTag(_ tagID: UUID?, for lesson: Lesson) {
        let key = lesson.noteKey
        guard var note = lessonNotes[key] else { return }
        note.tagID = tagSettings.tag(withID: tagID)?.id
        note.updatedAt = Date()
        if note.hasVisibleContent {
            lessonNotes[key] = note
            visibleNoteKeys.insert(key)
            storage.saveLessonNote(note)
        } else {
            lessonNotes.removeValue(forKey: key)
            visibleNoteKeys.remove(key)
            storage.deleteLessonNote(for: key)
        }
    }

    public func setTagSystemEnabled(_ isEnabled: Bool) {
        guard tagSettings.isEnabled != isEnabled else { return }
        tagSettings.isEnabled = isEnabled
        if !isEnabled { activeTagFilter.removeAll() }
        saveTagSettings()
    }

    /// Legt einen neuen Tag an. Gibt `false` zurück, wenn das Limit erreicht ist.
    @discardableResult
    public func addTag(name: String, colorHex: String) -> Bool {
        guard tagSettings.canAddTag else {
            errorMessage = "Maximal \(NoteTagSettings.maximumTagCount) Tags möglich."
            return false
        }
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        tagSettings.tags.append(NoteTag(name: cleanName.isEmpty ? "Tag \(tagSettings.tags.count + 1)" : cleanName, colorHex: colorHex))
        saveTagSettings()
        return true
    }

    public func updateTag(_ tag: NoteTag) {
        guard let index = tagSettings.tags.firstIndex(where: { $0.id == tag.id }) else { return }
        tagSettings.tags[index] = tag
        saveTagSettings()
    }

    /// Entfernt einen Tag und löst ihn von allen Notizen.
    public func deleteTag(id: UUID) {
        tagSettings.tags.removeAll(where: { $0.id == id })
        activeTagFilter.remove(id)
        saveTagSettings()

        let affectedKeys = lessonNotes.compactMap { entry -> String? in
            entry.value.tagID == id ? entry.key : nil
        }
        for key in affectedKeys {
            guard var note = lessonNotes[key] else { continue }
            note.tagID = nil
            if note.hasVisibleContent {
                lessonNotes[key] = note
                storage.saveLessonNote(note)
            } else {
                lessonNotes.removeValue(forKey: key)
                visibleNoteKeys.remove(key)
                storage.deleteLessonNote(for: key)
            }
        }
    }

    public func moveTags(fromOffsets source: IndexSet, toOffset destination: Int) {
        tagSettings.tags.move(fromOffsets: source, toOffset: destination)
        saveTagSettings()
    }

    /// Verschiebt einen Tag um eine Position nach oben (-1) oder unten (+1).
    public func moveTag(id: UUID, by delta: Int) {
        guard let index = tagSettings.tags.firstIndex(where: { $0.id == id }) else { return }
        let target = index + delta
        guard target >= 0, target < tagSettings.tags.count else { return }
        tagSettings.tags.swapAt(index, target)
        saveTagSettings()
    }

    public func toggleTagFilter(_ id: UUID) {
        if activeTagFilter.contains(id) {
            activeTagFilter.remove(id)
        } else {
            activeTagFilter.insert(id)
        }
    }

    /// Öffnet das nächste Vorkommen desselben Fachs innerhalb der nächsten drei Wochen.
    /// Falls die Zielstunde in einer anderen Woche liegt, wird zuerst zu dieser Woche gewechselt.
    public func openNoteForNextOccurrence(after lesson: Lesson, sourceFrame: CGRect = .zero) async {
        guard let startDate = Date.fromYyyyMMdd(lesson.dateString) else {
            errorMessage = "Datum der Stunde konnte nicht gelesen werden."
            return
        }

        let calendar = Calendar.germanCalendar
        let searchEndDate = calendar.date(byAdding: .day, value: 21, to: startDate) ?? startDate

        // Falls Untis eingerichtet ist, laden wir alle betroffenen Wochen nach,
        // damit auch ein Vorkommen in einer noch nicht geöffneten Woche gefunden wird.
        if untisCredentials.isConfigured {
            var week = startDate.startOfWeek(using: calendar)
            let endWeek = searchEndDate.startOfWeek(using: calendar)
            while week <= endWeek {
                await syncWeek(startingAt: week, showsSuccessMessage: false)
                guard let nextWeek = calendar.date(byAdding: .day, value: 7, to: week) else { break }
                week = nextWeek
            }
        }

        let normalizedSubject = lesson.subjectRaw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let startDay = calendar.startOfDay(for: startDate)
        let endDay = calendar.startOfDay(for: searchEndDate)

        var candidates: [Lesson] = []
        var day = startDay
        while day <= endDay {
            for candidate in lessonsFor(day: day) {
                let subjectMatches = candidate.subjectRaw
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased() == normalizedSubject
                guard subjectMatches else { continue }

                let currentBlockEndPeriod = lesson.periodNumber + max(1, lesson.durationPeriods) - 1
                if calendar.isDate(day, inSameDayAs: startDate), candidate.periodNumber <= currentBlockEndPeriod {
                    continue
                }
                candidates.append(candidate)
            }

            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = nextDay
        }

        guard let target = candidates.sorted(by: {
            if $0.dateString != $1.dateString { return $0.dateString < $1.dateString }
            return $0.periodNumber < $1.periodNumber
        }).first,
        let targetDate = Date.fromYyyyMMdd(target.dateString) else {
            errorMessage = "Dieses Fach wurde in den nächsten 3 Wochen nicht nochmal gefunden."
            return
        }

        let targetWeek = targetDate.startOfWeek(using: calendar)
        if targetWeek != selectedWeekStart {
            weekNavigationDirection = targetWeek > selectedWeekStart ? 1 : -1
            selectedWeekStart = targetWeek
        }

        // Einen kurzen Layout-Pass abwarten, damit die Woche sichtbar gewechselt ist,
        // bevor die Notiz geöffnet wird.
        try? await Task.sleep(nanoseconds: 180_000_000)
        openNote(for: target, sourceFrame: sourceFrame)
    }

    /// Löscht ALLE gespeicherten Notizen zu Stunden-Blöcken.
    public func deleteAllNotes() {
        lessonNotes.removeAll()
        visibleNoteKeys.removeAll()
        storage.deleteAllLessonNotes()
        noteUndoSessions = NoteUndoSessionStore()
        storage.saveNoteUndoSessions(noteUndoSessions)
        successMessage = "Alle Notizen wurden gelöscht."
    }

    /// Entfernt Notiz-Datensätze ohne sichtbaren Inhalt. Solche Datensätze
    /// entstanden früher schon beim bloßen Öffnen/Schließen einer Zeichenfläche.
    public func cleanupEmptyNotes() {
        let emptyKeys = lessonNotes.compactMap { entry -> String? in
            let (key, note) = entry
            return note.hasVisibleContent ? nil : key
        }
        guard !emptyKeys.isEmpty else { return }

        for key in emptyKeys {
            lessonNotes.removeValue(forKey: key)
            visibleNoteKeys.remove(key)
            storage.deleteLessonNote(for: key)
            noteUndoSessions.removeSession(for: key)
        }
        if !emptyKeys.isEmpty {
            storage.saveNoteUndoSessions(noteUndoSessions)
        }
    }

    private func rebuildVisibleNoteCache() {
        visibleNoteKeys = Set(lessonNotes.compactMap { entry -> String? in
            let (key, note) = entry
            return note.hasVisibleContent ? key : nil
        })
    }

    /// Entfernt Notizen zu Stunden, die bereits in der Vergangenheit liegen –
    /// sofern die entsprechende Einstellung aktiviert ist.
    public func cleanupPastNotesIfEnabled() {
        guard drawingSettings.autoDeletePastNotes else { return }

        let todayStart = Calendar.germanCalendar.startOfDay(for: Date())
        let keys = Array(lessonNotes.keys)
        for key in keys {
            let datePrefix = String(key.prefix(10))
            if let date = Date.fromYyyyMMdd(datePrefix), date < todayStart {
                lessonNotes.removeValue(forKey: key)
                visibleNoteKeys.remove(key)
                storage.deleteLessonNote(for: key)
            }
        }
    }

    // MARK: - Settings & Customization Management

    public func saveSubjectCustomizations() {
        storage.saveCustomizations(subjectCustomizations)
    }

    /// Ob noch ein weiteres Fach angelegt werden darf (max. 50).
    public var canAddSubjectCustomization: Bool {
        subjectCustomizations.count < TimetableViewModel.maximumSubjectCustomizations
    }

    /// Ob noch eine weitere Lehrkraft angelegt werden darf (max. 50).
    public var canAddTeacherNameCustomization: Bool {
        teacherNameCustomizations.count < TimetableViewModel.maximumTeacherNameCustomizations
    }

    /// Fügt ein Fach hinzu oder aktualisiert es. Neue Fächer werden ab dem
    /// Limit von 50 abgelehnt (Rückgabe `false`), Änderungen bestehender
    /// Fächer sind immer erlaubt.
    @discardableResult
    public func addOrUpdateCustomization(_ item: SubjectCustomization) -> Bool {
        if let idx = subjectCustomizations.firstIndex(where: { $0.id == item.id }) {
            subjectCustomizations[idx] = item
        } else {
            guard canAddSubjectCustomization else {
                errorMessage = "Maximal \(TimetableViewModel.maximumSubjectCustomizations) Fächer möglich. Bitte zuerst ein Fach löschen."
                return false
            }
            subjectCustomizations.append(item)
        }
        saveSubjectCustomizations()
        return true
    }

    public func deleteCustomization(at offsets: IndexSet) {
        subjectCustomizations.remove(atOffsets: offsets)
        saveSubjectCustomizations()
    }

    public func deleteCustomization(id: UUID) {
        subjectCustomizations.removeAll(where: { $0.id == id })
        saveSubjectCustomizations()
    }

    public func deleteAllCustomizations() {
        subjectCustomizations.removeAll()
        saveSubjectCustomizations()
        self.successMessage = "Alle manuell eingestellten Fächer wurden gelöscht."
    }

    public func saveTeacherNameCustomizations() {
        storage.saveTeacherNameCustomizations(teacherNameCustomizations)
    }

    /// Fügt eine Lehrkraft hinzu oder aktualisiert sie. Neue Einträge werden
    /// ab dem Limit von 50 abgelehnt (Rückgabe `false`).
    @discardableResult
    public func addOrUpdateTeacherNameCustomization(_ item: TeacherNameCustomization) -> Bool {
        let normalizedNew = normalizedTeacherKey(item.systemAbbreviation)
        if let idx = teacherNameCustomizations.firstIndex(where: { $0.id == item.id }) {
            teacherNameCustomizations[idx] = item
        } else if let existingIndex = teacherNameCustomizations.firstIndex(where: {
            normalizedTeacherKey($0.systemAbbreviation) == normalizedNew
        }) {
            teacherNameCustomizations[existingIndex] = TeacherNameCustomization(
                id: teacherNameCustomizations[existingIndex].id,
                systemAbbreviation: item.systemAbbreviation,
                displayName: item.displayName
            )
        } else {
            guard canAddTeacherNameCustomization else {
                errorMessage = "Maximal \(TimetableViewModel.maximumTeacherNameCustomizations) Lehrkräfte möglich. Bitte zuerst einen Eintrag löschen."
                return false
            }
            teacherNameCustomizations.append(item)
        }
        saveTeacherNameCustomizations()
        return true
    }

    public func deleteTeacherNameCustomization(id: UUID) {
        teacherNameCustomizations.removeAll(where: { $0.id == id })
        saveTeacherNameCustomizations()
    }

    public func deleteAllTeacherNameCustomizations() {
        teacherNameCustomizations.removeAll()
        saveTeacherNameCustomizations()
        self.successMessage = "Alle manuell eingestellten Lehrer-Namen wurden gelöscht."
    }

    public func saveDisplaySettings() {
        storage.saveDisplaySettings(displaySettings)
    }

    public func saveDrawingSettings() {
        storage.saveDrawingSettings(drawingSettings)
    }

    public func saveCredentials() {
        storage.saveCredentials(untisCredentials)
    }

    public func savePeriods() {
        storage.savePeriods(periods)
    }

    /// Liest alle Fächer aus dem aktuellen Stundenplan aus und fügt neue Fächer
    /// der Liste hinzu – bis zum Limit von 50 Fächern.
    public func importDiscoveredSubjects() {
        var addedCount = 0
        var skippedByLimit = 0
        var existingOriginals = Set(subjectCustomizations.map { $0.originalSubject.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })

        for lesson in lessons {
            let original = lesson.subjectRaw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !original.isEmpty, !existingOriginals.contains(original.lowercased()) else { continue }
            guard canAddSubjectCustomization else {
                skippedByLimit += 1
                continue
            }
            existingOriginals.insert(original.lowercased())

            let customName: String
            if let preset = SubjectCustomization.defaultPresets.first(where: { $0.originalSubject.caseInsensitiveCompare(original) == .orderedSame }) {
                customName = preset.customName
            } else {
                customName = original
            }

            let fallbackColors = ["#3B82F6", "#10B981", "#8B5CF6", "#F59E0B", "#EC4899", "#06B6D4"]
            let colorHex = fallbackColors[abs(original.hashValue) % fallbackColors.count]

            subjectCustomizations.append(SubjectCustomization(originalSubject: original, customName: customName, colorHex: colorHex))
            addedCount += 1
        }

        saveSubjectCustomizations()
        if skippedByLimit > 0 {
            self.errorMessage = "\(addedCount) Fächer importiert – \(skippedByLimit) weitere passen nicht mehr (max. \(TimetableViewModel.maximumSubjectCustomizations) Fächer)."
        } else if addedCount > 0 {
            self.successMessage = "\(addedCount) Fächer aus Stundenplan importiert!"
        } else {
            self.successMessage = "Keine neuen Fächer zum Importieren gefunden."
        }
    }

    // MARK: - Export & Import (komplette Sicherung)

    /// Erstellt eine vollständige Sicherung aller gespeicherten Daten als
    /// Base64-Text (siehe `AppBackupCodec`).
    public func exportBackupString() -> String? {
        let backup = AppBackup(
            createdAt: Date(),
            credentials: untisCredentials,
            subjectCustomizations: subjectCustomizations,
            teacherNameCustomizations: teacherNameCustomizations,
            displaySettings: displaySettings,
            drawingSettings: drawingSettings,
            periods: periods,
            lessons: lessons,
            notes: Array(lessonNotes.values).sorted { $0.id < $1.id },
            viewMode: viewMode.rawValue,
            appearance: appearance.rawValue,
            tagSettings: tagSettings
        )
        do {
            return try AppBackupCodec.encode(backup)
        } catch {
            errorMessage = "Export fehlgeschlagen: \(error.localizedDescription)"
            return nil
        }
    }

    /// Liest eine Sicherung aus Text ein, ohne sie anzuwenden (Vorschau für
    /// die Bestätigung). `nil`, wenn der Text keine gültige Sicherung ist.
    public func decodeBackup(from text: String) -> AppBackup? {
        try? AppBackupCodec.decode(text)
    }

    /// Ersetzt sämtliche Daten der App durch die Sicherung.
    public func applyBackup(_ backup: AppBackup) {
        untisCredentials = backup.credentials
        subjectCustomizations = Array(backup.subjectCustomizations.prefix(TimetableViewModel.maximumSubjectCustomizations))
        teacherNameCustomizations = Array(backup.teacherNameCustomizations.prefix(TimetableViewModel.maximumTeacherNameCustomizations))
        displaySettings = backup.displaySettings
        drawingSettings = backup.drawingSettings
        periods = backup.periods.isEmpty ? Period.defaultPeriods : backup.periods
        lessons = backup.lessons
        tagSettings = backup.tagSettings
        activeTagFilter.removeAll()
        if let mode = TimetableViewMode(rawValue: backup.viewMode) {
            viewMode = mode
        }
        if let restoredAppearance = AppAppearance(rawValue: backup.appearance) {
            appearance = restoredAppearance
        }
        lastSyncDate = untisCredentials.lastSyncDate
        lastSyncFailure = nil
        loadedWeekKeys.removeAll()

        var restoredNotes: [String: LessonNote] = [:]
        for note in backup.notes where note.hasVisibleContent {
            restoredNotes[note.id] = note
        }
        lessonNotes = restoredNotes
        rebuildVisibleNoteCache()

        storage.saveCredentials(untisCredentials)
        storage.saveCustomizations(subjectCustomizations)
        storage.saveTeacherNameCustomizations(teacherNameCustomizations)
        storage.saveDisplaySettings(displaySettings)
        storage.saveDrawingSettings(drawingSettings)
        storage.savePeriods(periods)
        storage.saveLessons(lessons)
        storage.saveViewMode(viewMode)
        storage.saveAppearance(appearance)
        storage.saveTagSettings(tagSettings)
        storage.replaceAllLessonNotes(with: Array(restoredNotes.values))

        successMessage = "Import abgeschlossen: \(restoredNotes.count) Notizen, \(lessons.count) Stunden."
    }

    // MARK: - Untis API Sync & Demo Data

    /// Synchronisiert die aktuell angezeigte Woche mit WebUntis.
    public func syncWithUntis() async {
        await syncWeek(startingAt: selectedWeekStart, showsSuccessMessage: true)
    }

    /// Lädt eine konkrete Woche. Der explizite Parameter verhindert, dass ein
    /// schneller zweiter Swipe die noch laufende Anfrage der ersten Woche auf
    /// ein falsches Datum umbiegt.
    private func syncWeek(
        startingAt weekStart: Date,
        showsSuccessMessage: Bool,
        reportsErrors: Bool = true
    ) async {
        guard untisCredentials.isConfigured else {
            if showsSuccessMessage {
                self.errorMessage = "Bitte zuerst WebUntis Server und Schulnamen in den Einstellungen angeben."
            }
            return
        }

        let normalizedWeekStart = weekStart.startOfWeek()
        let weekKey = normalizedWeekStart.yyyyMMddString
        guard !loadingWeekKeys.contains(weekKey) else { return }
        lastSyncAttemptDate = Date()
        activeSyncCount += 1
        loadingWeekKeys.insert(weekKey)
        self.isLoading = true
        if reportsErrors { self.errorMessage = nil }
        if showsSuccessMessage { self.successMessage = nil }
        defer {
            activeSyncCount -= 1
            self.isLoading = activeSyncCount > 0
            self.loadingWeekKeys.remove(weekKey)
        }

        do {
            let auth = try await untis.authenticate(credentials: untisCredentials)

            let fetchedPeriods = try await untis.fetchTimegrid(credentials: untisCredentials, sessionId: auth.sessionId)
            if !fetchedPeriods.isEmpty {
                self.periods = fetchedPeriods
                storage.savePeriods(fetchedPeriods)
            }

            let weekDays = normalizedWeekStart.schoolWeekDays()
            guard let startDay = weekDays.first, let endDay = weekDays.last else { return }

            let fetchedLessons = try await untis.fetchTimetable(
                credentials: untisCredentials,
                sessionId: auth.sessionId,
                startDate: startDay,
                endDate: endDay,
                personId: auth.personId,
                personType: auth.personType,
                periods: self.periods
            )

            let weekDateStrings = Set(weekDays.map { $0.yyyyMMddString })
            var updatedLessons = lessons.filter { !weekDateStrings.contains($0.dateString) }
            updatedLessons.append(contentsOf: fetchedLessons)
            self.lessons = updatedLessons
            storage.saveLessons(updatedLessons)

            let now = Date()
            self.lastSyncDate = now
            self.untisCredentials.lastSyncDate = now
            storage.saveCredentials(untisCredentials)
            await untis.logout(credentials: untisCredentials, sessionId: auth.sessionId)

            // Die Woche gilt jetzt als geladen – auch wenn sie keine Stunden
            // enthält (z. B. Ferien). Dadurch verschwindet das Lade-Symbol und
            // erscheint beim erneuten Hineinwischen nicht wieder.
            loadedWeekKeys.insert(weekKey)
            lastSyncFailure = nil

            // Bewusst keine "synchronisiert"-Erfolgsmeldung mehr – die
            // Live-Anzeige im Header zeigt den Sync-Status bereits an.
        } catch {
            if reportsErrors { self.errorMessage = error.localizedDescription }
            noteSyncFailure(error.localizedDescription)
        }
    }

    /// Lädt realistische Beispieldaten für die aktuelle Woche
    public func loadDemoData() {
        let demoLessons = demo.generateDemoWeek(for: selectedWeekStart)
        let weekDays = selectedWeekStart.schoolWeekDays()
        let weekDateStrings = Set(weekDays.map { $0.yyyyMMddString })

        var updated = lessons.filter { !weekDateStrings.contains($0.dateString) }
        updated.append(contentsOf: demoLessons)

        self.lessons = updated
        storage.saveLessons(updated)
        let now = Date()
        self.lastSyncDate = now
        self.untisCredentials.lastSyncDate = now
        storage.saveCredentials(untisCredentials)
        // Demo-Daten gelten als "geladen": kein Lade-Symbol und kein
        // Einrichtungs-Guide mehr für diese Woche.
        loadedWeekKeys.insert(selectedWeekStart.startOfWeek().yyyyMMddString)
        lastSyncFailure = nil
        self.successMessage = "Beispiel-Stundenplan für die Woche geladen!"
    }

    /// Leert den aktuellen Stundenplan
    public func clearTimetable() {
        self.lessons = []
        storage.saveLessons([])
        self.successMessage = "Stundenplan zurückgesetzt."
    }
}
