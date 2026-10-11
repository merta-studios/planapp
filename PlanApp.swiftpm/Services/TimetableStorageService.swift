import Foundation

/// Lokaler Speicher-Service für Einstellungen, Stundenplandaten und Zeichnungen
public final class TimetableStorageService {
    public static let shared = TimetableStorageService()

    private let defaults = UserDefaults.standard
    private let fileManager = FileManager.default

    /// Serieller Hintergrund-Queue für **alle** Schreibvorgänge.
    ///
    /// JSON-Encoding großer Daten (alle Stunden, Notizen inkl. Zeichnungen und
    /// Bildern, Undo-Sitzungen mit bis zu 40 Vollständen je Notiz) plus das
    /// Schreiben in UserDefaults und in die Sicherungsdatei dauern leicht
    /// mehrere hundert Millisekunden. Lief das auf dem Main Thread, fror die
    /// App genau in dem Moment ein, in dem die Notiz zurück in den Stundenblock
    /// glitt bzw. eine neue Woche hereinkam. Die Reihenfolge bleibt über die
    /// serielle Queue erhalten (Speichern → Löschen → Speichern wirkt wie
    /// bisher), und gelesen wird ausschließlich aus dem Speicher bzw. aus
    /// Dateien, die dieser Queue selbst geschrieben hat.
    private let writeQueue = DispatchQueue(label: "planapp.storage.writes", qos: .userInitiated)

    /// Schloss für `cachedNotesMetadata`: Notizen werden auch aus
    /// Hintergrund-Queues geladen (Batch-Preload), die Metadaten also von
    /// mehreren Threads gelesen.
    private let metadataLock = NSLock()
    /// Zwischengespeicherte Notiz-Metadaten. `UserDefaults.dictionary(forKey:)`
    /// baut bei jedem Aufruf ein neues `[String: Any]` mit einem eigenen
    /// Wörterbuch je Notiz auf. Beim Rendern des Drei-Wochen-Karussells wurde
    /// das für **jede** Notiz wiederholt – ein wesentlicher Teil der
    /// Verzögerung beim Wochenwechsel.
    private var cachedNotesMetadata: [String: Any]? = nil

    // UserDefaults kann bei einem unerwarteten Beenden noch nicht auf die
    // Plist geschrieben sein. Eine zweite, atomare Kopie verhindert dadurch
    // den Eindruck eines "Reset" beim nächsten Start.
    private var backupDirectory: URL {
        let url = documentsDirectory.appendingPathComponent("PlanAppState", isDirectory: true)
        try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func persist<T: Encodable>(_ value: T, key: String) {
        writeQueue.async { [weak self] in
            guard let self else { return }
            guard let data = try? JSONEncoder().encode(value) else { return }
            self.defaults.set(data, forKey: key)
            let url = self.backupDirectory.appendingPathComponent(key).appendingPathExtension("json")
            try? data.write(to: url, options: .atomic)
        }
    }

    private func restore<T: Decodable>(_ type: T.Type, key: String) -> T? {
        let data = defaults.data(forKey: key)
            ?? (try? Data(contentsOf: backupDirectory.appendingPathComponent(key).appendingPathExtension("json")))
        guard let data, let value = try? JSONDecoder().decode(type, from: data) else { return nil }
        return value
    }

    private enum Keys {
        static let credentials = "planapp_untis_credentials"
        static let customizations = "planapp_subject_customizations"
        static let teacherNameCustomizations = "planapp_teacher_name_customizations"
        static let displaySettings = "planapp_block_display_settings"
        static let periods = "planapp_periods"
        static let lessons = "planapp_lessons"
        static let notesMetadata = "planapp_notes_metadata"
        static let drawingSettings = "planapp_drawing_settings"
        static let viewMode = "planapp_timetable_view_mode"
        static let appearance = "planapp_app_appearance"
        static let tagSettings = "planapp_note_tag_settings"
        static let applePencilStatus = "planapp_apple_pencil_status"
        static let noteUndoSessions = "planapp_note_undo_sessions"
        static let fileSyncConfiguration = "planapp_file_sync_configuration"
        static let fileSyncSafetyBackups = "planapp_file_sync_safety_backups"
    }

    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private var notesDirectory: URL {
        let url = documentsDirectory.appendingPathComponent("PlanAppNotes", isDirectory: true)
        if !fileManager.fileExists(atPath: url.path) {
            try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }

    // MARK: - Credentials

    public func saveCredentials(_ creds: UntisCredentials) {
        persist(creds, key: Keys.credentials)
    }

    public func loadCredentials() -> UntisCredentials {
        return restore(UntisCredentials.self, key: Keys.credentials) ?? UntisCredentials()
    }

    // MARK: - Subject Customizations

    public func saveCustomizations(_ list: [SubjectCustomization]) {
        persist(list, key: Keys.customizations)
    }

    public func loadCustomizations() -> [SubjectCustomization] {
        return restore([SubjectCustomization].self, key: Keys.customizations) ?? []
    }

    // MARK: - Teacher Name Customizations

    public func saveTeacherNameCustomizations(_ list: [TeacherNameCustomization]) {
        persist(list, key: Keys.teacherNameCustomizations)
    }

    public func loadTeacherNameCustomizations() -> [TeacherNameCustomization] {
        return restore([TeacherNameCustomization].self, key: Keys.teacherNameCustomizations) ?? []
    }

    // MARK: - Display Settings

    public func saveDisplaySettings(_ settings: BlockDisplaySettings) {
        persist(settings, key: Keys.displaySettings)
    }

    public func loadDisplaySettings() -> BlockDisplaySettings {
        return restore(BlockDisplaySettings.self, key: Keys.displaySettings) ?? BlockDisplaySettings.default
    }

    // MARK: - Drawing Settings

    public func saveDrawingSettings(_ settings: DrawingSettings) {
        persist(settings, key: Keys.drawingSettings)
    }

    public func loadDrawingSettings() -> DrawingSettings {
        return restore(DrawingSettings.self, key: Keys.drawingSettings) ?? DrawingSettings.default
    }

    // MARK: - Ansichts-Modus

    public func saveViewMode(_ mode: TimetableViewMode) {
        persist(mode.rawValue, key: Keys.viewMode)
    }

    public func loadViewMode() -> TimetableViewMode {
        guard let raw = defaults.string(forKey: Keys.viewMode),
              let mode = TimetableViewMode(rawValue: raw) else {
            return .fallback
        }
        return mode
    }

    // MARK: - Erscheinungsbild

    public func saveAppearance(_ appearance: AppAppearance) {
        persist(appearance.rawValue, key: Keys.appearance)
    }

    public func loadAppearance() -> AppAppearance {
        guard let raw = restore(String.self, key: Keys.appearance),
              let appearance = AppAppearance(rawValue: raw) else {
            return .fallback
        }
        return appearance
    }

    // MARK: - Tag-System

    public func saveTagSettings(_ settings: NoteTagSettings) {
        persist(settings, key: Keys.tagSettings)
    }

    public func loadTagSettings() -> NoteTagSettings {
        return restore(NoteTagSettings.self, key: Keys.tagSettings) ?? NoteTagSettings()
    }

    // MARK: - Apple Pencil Status

    public func saveApplePencilStatus(_ snapshot: ApplePencilStatusSnapshot) {
        persist(snapshot, key: Keys.applePencilStatus)
    }

    public func loadApplePencilStatus() -> ApplePencilStatusSnapshot? {
        restore(ApplePencilStatusSnapshot.self, key: Keys.applePencilStatus)
    }

    // MARK: - Undo-Sitzungen der letzten Notizen

    public func saveNoteUndoSessions(_ store: NoteUndoSessionStore) {
        persist(store, key: Keys.noteUndoSessions)
    }

    public func loadNoteUndoSessions() -> NoteUndoSessionStore {
        restore(NoteUndoSessionStore.self, key: Keys.noteUndoSessions) ?? NoteUndoSessionStore()
    }

    // MARK: - Datei-Synchronisation (iCloud Drive)

    public func saveFileSyncConfiguration(_ configuration: FileSyncConfiguration) {
        persist(configuration, key: Keys.fileSyncConfiguration)
    }

    public func loadFileSyncConfiguration() -> FileSyncConfiguration {
        restore(FileSyncConfiguration.self, key: Keys.fileSyncConfiguration) ?? FileSyncConfiguration()
    }

    public func saveFileSyncSafetyBackups(_ backups: [FileSyncSafetyBackup]) {
        persist(Array(backups.prefix(FileSyncService.maximumSafetyBackups)), key: Keys.fileSyncSafetyBackups)
    }

    public func loadFileSyncSafetyBackups() -> [FileSyncSafetyBackup] {
        restore([FileSyncSafetyBackup].self, key: Keys.fileSyncSafetyBackups) ?? []
    }

    // MARK: - Periods

    public func savePeriods(_ periods: [Period]) {
        persist(periods, key: Keys.periods)
    }

    public func loadPeriods() -> [Period] {
        return restore([Period].self, key: Keys.periods) ?? Period.defaultPeriods
    }

    // MARK: - Lessons

    public func saveLessons(_ lessons: [Lesson]) {
        persist(lessons, key: Keys.lessons)
    }

    public func loadLessons() -> [Lesson] {
        return restore([Lesson].self, key: Keys.lessons) ?? []
    }

    // MARK: - Lesson Notes (PencilKit Drawings & Images)

    /// Speichert eine Notiz (Zeichnung, Vorschau, Textfelder, Bilder).
    ///
    /// - Parameter hasVisibleContent: Bekannter Inhalt (Striche/Text/Bilder).
    ///   Die eigene Prüfung dekodiert die PencilKit-Daten und ist entsprechend
    ///   teuer; Aufrufer, die das Ergebnis schon kennen (z. B. der Editor beim
    ///   Schließen), geben es deshalb mit.
    public func saveLessonNote(_ note: LessonNote, hasVisibleContent: Bool? = nil) {
        // Metadaten und Pfade speichern
        let noteFile = notesDirectory.appendingPathComponent("\(note.id).note")
        let imageFile = notesDirectory.appendingPathComponent("\(note.id).png")
        let textFile = notesDirectory.appendingPathComponent("\(note.id).text.json")
        let boxesFile = notesDirectory.appendingPathComponent("\(note.id).images.json")

        let visibleContent = hasVisibleContent ?? note.hasVisibleContent

        // Alle Dateioperationen (inkl. JSON-Encoding der Textfelder und
        // Bildrahmen) laufen im Hintergrund – bei Notizen mit Bildern sind das
        // schnell mehrere Megabyte.
        writeQueue.async { [weak self] in
            guard let self else { return }
            let fileManager = self.fileManager

            try? note.drawingData.write(to: noteFile, options: .atomic)
            if let imgData = note.croppedImageData {
                try? imgData.write(to: imageFile, options: .atomic)
            } else {
                try? fileManager.removeItem(at: imageFile)
            }

            if !note.textBoxes.isEmpty, let textData = try? JSONEncoder().encode(note.textBoxes) {
                try? textData.write(to: textFile, options: .atomic)
            } else {
                try? fileManager.removeItem(at: textFile)
            }

            // Bilder (Rahmen + komprimierte Bilddaten) liegen in einer eigenen
            // Datei, damit Textfelder und Zeichnung unabhängig davon lesbar
            // bleiben – selbst wenn ein Bild einmal beschädigt wäre.
            if !note.imageBoxes.isEmpty, let boxesData = try? JSONEncoder().encode(note.imageBoxes) {
                try? boxesData.write(to: boxesFile, options: .atomic)
            } else {
                try? fileManager.removeItem(at: boxesFile)
            }
        }

        var metadata = loadNotesMetadata()
        var entry: [String: Any] = [
            "lineCount": note.lineCount,
            "updatedAt": note.updatedAt.timeIntervalSince1970,
            "hasDrawing": visibleContent,
            "hasContent": visibleContent,
            "hasPreviewImage": note.croppedImageData != nil,
            "textBoxCount": note.textBoxes.count,
            "imageBoxCount": note.imageBoxes.count,
            "backgroundStyle": note.backgroundStyle.rawValue,
            "backgroundScale": note.backgroundScale
        ]
        if let tagID = note.tagID {
            entry["tagID"] = tagID.uuidString
        }
        metadata[note.id] = entry
        storeNotesMetadata(metadata)
    }

    /// Ersetzt sämtliche Notizen auf einen Schlag (Import einer Sicherung).
    public func replaceAllLessonNotes(with notes: [LessonNote]) {
        deleteAllLessonNotes()
        for note in notes {
            saveLessonNote(note)
        }
    }

    public func loadLessonNote(for noteKey: String) -> LessonNote? {
        let noteFile = notesDirectory.appendingPathComponent("\(noteKey).note")
        let imageFile = notesDirectory.appendingPathComponent("\(noteKey).png")
        let textFile = notesDirectory.appendingPathComponent("\(noteKey).text.json")
        let boxesFile = notesDirectory.appendingPathComponent("\(noteKey).images.json")

        guard fileManager.fileExists(atPath: noteFile.path),
              let drawingData = try? Data(contentsOf: noteFile) else {
            return nil
        }

        let imageData = try? Data(contentsOf: imageFile)

        var textBoxes: [NoteTextBox] = []
        if let textData = try? Data(contentsOf: textFile),
           let decoded = try? JSONDecoder().decode([NoteTextBox].self, from: textData) {
            textBoxes = decoded
        }

        // Bilder werden defensiv geladen: Unlesbare Rahmen fallen heraus,
        // der Rest der Notiz bleibt in jedem Fall erhalten.
        var imageBoxes: [NoteImageBox] = []
        if let boxesData = try? Data(contentsOf: boxesFile),
           let decoded = try? JSONDecoder().decode([NoteImageBox].self, from: boxesData) {
            imageBoxes = decoded.compactMap { $0.sanitized() }
        }

        let metadata = loadNotesMetadata()[noteKey] as? [String: Any]
        let lineCount = metadata?["lineCount"] as? Int ?? 6
        let timeInterval = metadata?["updatedAt"] as? Double ?? Date().timeIntervalSince1970
        let date = Date(timeIntervalSince1970: timeInterval)
        let backgroundRaw = metadata?["backgroundStyle"] as? String
        let backgroundStyle = backgroundRaw.flatMap(NoteBackgroundStyle.init(rawValue:)) ?? .blank
        let backgroundScale = metadata?["backgroundScale"] as? Double ?? NoteBackgroundMetrics.defaultScale
        let tagID = (metadata?["tagID"] as? String).flatMap(UUID.init(uuidString:))

        return LessonNote(
            id: noteKey,
            drawingData: drawingData,
            croppedImageData: imageData,
            lineCount: lineCount,
            textBoxes: textBoxes,
            imageBoxes: imageBoxes,
            backgroundStyle: backgroundStyle,
            backgroundScale: backgroundScale,
            tagID: tagID,
            updatedAt: date
        )
    }

    public func loadAllLessonNotes() -> [String: LessonNote] {
        var result: [String: LessonNote] = [:]
        let metadata = loadNotesMetadata()
        for (key, _) in metadata {
            if let note = loadLessonNote(for: key) {
                result[key] = note
            }
        }
        return result
    }

    public func deleteLessonNote(for noteKey: String) {
        let noteFile = notesDirectory.appendingPathComponent("\(noteKey).note")
        let imageFile = notesDirectory.appendingPathComponent("\(noteKey).png")
        let textFile = notesDirectory.appendingPathComponent("\(noteKey).text.json")
        let boxesFile = notesDirectory.appendingPathComponent("\(noteKey).images.json")
        // Dieselbe Queue wie das Speichern: Ein Löschen nach einem Speichern
        // löscht wirklich den zuletzt geschriebenen Stand.
        writeQueue.async { [weak self] in
            guard let fileManager = self?.fileManager else { return }
            try? fileManager.removeItem(at: noteFile)
            try? fileManager.removeItem(at: imageFile)
            try? fileManager.removeItem(at: textFile)
            try? fileManager.removeItem(at: boxesFile)
        }

        var metadata = loadNotesMetadata()
        metadata.removeValue(forKey: noteKey)
        storeNotesMetadata(metadata)
    }

    /// Löscht sämtliche gespeicherten Notizen (Zeichnungen, Vorschaubilder
    /// und Textfelder) unwiderruflich.
    public func deleteAllLessonNotes() {
        let directory = notesDirectory
        writeQueue.async { [weak self] in
            guard let fileManager = self?.fileManager else { return }
            if let files = try? fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil
            ) {
                for file in files {
                    try? fileManager.removeItem(at: file)
                }
            }
        }
        storeNotesMetadata([String: Any]())
    }

    public func loadNotesMetadata() -> [String: Any] {
        metadataLock.lock()
        if let cached = cachedNotesMetadata {
            metadataLock.unlock()
            return cached
        }
        metadataLock.unlock()

        let loaded = defaults.dictionary(forKey: Keys.notesMetadata) ?? [:]
        metadataLock.lock()
        cachedNotesMetadata = loaded
        metadataLock.unlock()
        return loaded
    }

    /// Überschreibt die Notiz-Metadaten: Der Zwischenspeicher wird **sofort**
    /// aktualisiert (damit direkt folgende Ladevorgänge den neuen Stand sehen),
    /// das Schreiben selbst läuft im Hintergrund.
    private func storeNotesMetadata(_ metadata: [String: Any]) {
        metadataLock.lock()
        cachedNotesMetadata = metadata
        metadataLock.unlock()
        writeQueue.async { [weak self] in
            self?.defaults.set(metadata, forKey: Keys.notesMetadata)
        }
    }

    /// Lädt nur das Preview-Bild einer Notiz (ohne vollständige Notiz zu laden)
    public func loadPreviewImage(for noteKey: String) -> Data? {
        let imageFile = notesDirectory.appendingPathComponent("\(noteKey).png")
        return try? Data(contentsOf: imageFile)
    }

    /// Speichert nur das Preview-Bild einer Notiz (für Background-Updates)
    public func savePreviewImage(_ imageData: Data, for noteKey: String) {
        let imageFile = notesDirectory.appendingPathComponent("\(noteKey).png")
        writeQueue.async {
            try? imageData.write(to: imageFile, options: .atomic)
        }

        // Metadata aktualisieren
        var metadata = loadNotesMetadata()
        if var entry = metadata[noteKey] as? [String: Any] {
            entry["hasPreviewImage"] = true
            metadata[noteKey] = entry
            storeNotesMetadata(metadata)
        }
    }
}
