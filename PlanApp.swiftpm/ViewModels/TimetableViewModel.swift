import Foundation
import SwiftUI
import Combine

/// Haupt-ViewModel zur Verwaltung von Stundenplan, Untis-Synchronisation, Einstellungen und Notizen
@MainActor
public final class TimetableViewModel: ObservableObject {
    // MARK: - Published State

    @Published public var selectedWeekStart: Date
    @Published public var periods: [Period] = []
    @Published public var lessons: [Lesson] = []
    @Published public var subjectCustomizations: [SubjectCustomization] = []
    @Published public var displaySettings: BlockDisplaySettings = .default
    @Published public var untisCredentials: UntisCredentials = UntisCredentials()
    @Published public var lessonNotes: [String: LessonNote] = [:]

    // Aktive Notiz-Ansicht (Zeichnen-Overlay)
    @Published public var activeNoteLesson: Lesson? = nil
    @Published public var isDrawingOverlayPresented: Bool = false

    // Navigation & UI State
    @Published public var isSettingsPresented: Bool = false
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String? = nil
    @Published public var successMessage: String? = nil
    /// -1 = ältere Woche gleitet von links herein, 1 = neuere Woche von rechts.
    @Published public private(set) var weekNavigationDirection: Int = 1

    private var activeSyncCount: Int = 0
    private let storage = TimetableStorageService.shared
    private let untis = WebUntisService.shared
    private let demo = DemoDataService.shared

    // MARK: - Initializer

    public init() {
        self.selectedWeekStart = Date().startOfWeek()
        loadInitialData()
    }

    private func loadInitialData() {
        self.untisCredentials = storage.loadCredentials()
        self.subjectCustomizations = storage.loadCustomizations()
        self.displaySettings = storage.loadDisplaySettings()
        self.periods = storage.loadPeriods()
        self.lessons = storage.loadLessons()
        self.lessonNotes = storage.loadAllLessonNotes()

        // Falls noch keine Fächer-Einstellungen vorhanden sind, Presets laden
        if subjectCustomizations.isEmpty {
            self.subjectCustomizations = SubjectCustomization.defaultPresets
            storage.saveCustomizations(subjectCustomizations)
        }

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

    // MARK: - Week Navigation

    /// Springt zur aktuellen Woche zurück und lädt genau diese Woche nach.
    public func goToCurrentWeek() {
        let current = Date().startOfWeek()
        weekNavigationDirection = current >= selectedWeekStart ? 1 : -1
        selectWeek(current)
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

    private func selectWeek(_ weekStart: Date) {
        let normalizedStart = weekStart.startOfWeek()
        guard normalizedStart != selectedWeekStart else { return }
        selectedWeekStart = normalizedStart

        // Bisher wurde ausschließlich die beim manuellen Sync ausgewählte Woche
        // geladen. Nun wird jede angeswipte Woche automatisch bei Untis angefragt.
        guard untisCredentials.isConfigured else { return }
        Task {
            await syncWeek(startingAt: normalizedStart, showsSuccessMessage: false)
        }
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

    /// Ermittelt den Anzeigennamen und die Hintergrundfarbe für ein Fach
    public func resolveSubjectDisplay(for lesson: Lesson) -> (name: String, colorHex: String, color: Color) {
        let raw = lesson.subjectRaw.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. Suche in benutzerdefinierten Fächereinstellungen
        if let custom = subjectCustomizations.first(where: {
            $0.originalSubject.caseInsensitiveCompare(raw) == .orderedSame ||
            $0.originalSubject.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == raw.lowercased()
        }) {
            let name = custom.customName.isEmpty ? raw : custom.customName
            return (name, custom.colorHex, Color(hex: custom.colorHex))
        }

        // 2. Suche nach Teilübereinstimmung (z.B. "M-LK" matcht "M")
        for custom in subjectCustomizations {
            if raw.lowercased().hasPrefix(custom.originalSubject.lowercased()) && !custom.originalSubject.isEmpty {
                let name = custom.customName.isEmpty ? raw : custom.customName
                return (name, custom.colorHex, Color(hex: custom.colorHex))
            }
        }

        // 3. Fallback: Dynamische Farbgenerierung basierend auf Fachname
        let fallbackColors = [
            "#3B82F6", "#10B981", "#8B5CF6", "#F59E0B", "#EC4899",
            "#06B6D4", "#6366F1", "#14B8A6", "#EF4444", "#84CC16"
        ]
        let hash = abs(raw.hashValue)
        let colorHex = fallbackColors[hash % fallbackColors.count]
        return (raw, colorHex, Color(hex: colorHex))
    }

    // MARK: - Drawing & Notes Handling

    /// Öffnet die Zeichnen-Notiz-Ansicht für eine Stunde
    public func openNote(for lesson: Lesson) {
        withAnimation(.spring(response: 0.48, dampingFraction: 0.84)) {
            self.activeNoteLesson = lesson
            self.isDrawingOverlayPresented = true
        }
    }

    /// Schließt und speichert die Notiz
    public func saveNote(for lesson: Lesson, drawingData: Data, croppedImageData: Data?, lineCount: Int) {
        let key = lesson.noteKey
        let note = LessonNote(
            id: key,
            drawingData: drawingData,
            croppedImageData: croppedImageData,
            lineCount: lineCount,
            updatedAt: Date()
        )
        self.lessonNotes[key] = note
        storage.saveLessonNote(note)
        withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
            self.isDrawingOverlayPresented = false
            self.activeNoteLesson = nil
        }
    }

    /// Gibt die Notiz für eine bestimmte Stunde zurück
    public func noteFor(lesson: Lesson) -> LessonNote? {
        return lessonNotes[lesson.noteKey]
    }

    // MARK: - Settings & Customization Management

    public func saveSubjectCustomizations() {
        storage.saveCustomizations(subjectCustomizations)
    }

    public func addOrUpdateCustomization(_ item: SubjectCustomization) {
        if let idx = subjectCustomizations.firstIndex(where: { $0.id == item.id }) {
            subjectCustomizations[idx] = item
        } else {
            subjectCustomizations.append(item)
        }
        saveSubjectCustomizations()
    }

    public func deleteCustomization(at offsets: IndexSet) {
        subjectCustomizations.remove(atOffsets: offsets)
        saveSubjectCustomizations()
    }

    public func deleteCustomization(id: UUID) {
        subjectCustomizations.removeAll(where: { $0.id == id })
        saveSubjectCustomizations()
    }

    public func saveDisplaySettings() {
        storage.saveDisplaySettings(displaySettings)
    }

    public func saveCredentials() {
        storage.saveCredentials(untisCredentials)
    }

    public func savePeriods() {
        storage.savePeriods(periods)
    }

    /// Liest alle Fächer aus dem aktuellen Stundenplan aus und fügt neue Fächer der Liste hinzu
    public func importDiscoveredSubjects() {
        var addedCount = 0
        let existingOriginals = Set(subjectCustomizations.map { $0.originalSubject.lowercased() })

        for lesson in lessons {
            let original = lesson.subjectRaw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !original.isEmpty, !existingOriginals.contains(original.lowercased()) else { continue }

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
        if addedCount > 0 {
            self.successMessage = "\(addedCount) neue Fächer aus Stundenplan importiert!"
        }
    }

    // MARK: - Untis API Sync & Demo Data

    /// Synchronisiert die aktuell angezeigte Woche mit WebUntis.
    public func syncWithUntis() async {
        await syncWeek(startingAt: selectedWeekStart, showsSuccessMessage: true)
    }

    /// Lädt eine konkrete Woche. Der explizite Parameter verhindert, dass ein
    /// schneller zweiter Swipe die noch laufende Anfrage der ersten Woche auf
    /// ein falsches Datum umbiegt.
    private func syncWeek(startingAt weekStart: Date, showsSuccessMessage: Bool) async {
        guard untisCredentials.isConfigured else {
            if showsSuccessMessage {
                self.errorMessage = "Bitte zuerst WebUntis Server und Schulnamen in den Einstellungen angeben."
            }
            return
        }

        activeSyncCount += 1
        self.isLoading = true
        self.errorMessage = nil
        if showsSuccessMessage { self.successMessage = nil }
        defer {
            activeSyncCount -= 1
            self.isLoading = activeSyncCount > 0
        }

        do {
            let auth = try await untis.authenticate(credentials: untisCredentials)

            let fetchedPeriods = try await untis.fetchTimegrid(credentials: untisCredentials, sessionId: auth.sessionId)
            if !fetchedPeriods.isEmpty {
                self.periods = fetchedPeriods
                storage.savePeriods(fetchedPeriods)
            }

            let weekDays = weekStart.schoolWeekDays()
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

            self.untisCredentials.lastSyncDate = Date()
            storage.saveCredentials(untisCredentials)
            await untis.logout(credentials: untisCredentials, sessionId: auth.sessionId)

            if showsSuccessMessage {
                self.successMessage = "Stundenplan erfolgreich synchronisiert!"
            }
        } catch {
            self.errorMessage = error.localizedDescription
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
        self.successMessage = "Beispiel-Stundenplan für die Woche geladen!"
    }

    /// Leert den aktuellen Stundenplan
    public func clearTimetable() {
        self.lessons = []
        storage.saveLessons([])
        self.successMessage = "Stundenplan zurückgesetzt."
    }
}
