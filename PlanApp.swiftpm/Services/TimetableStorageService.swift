import Foundation

/// Lokaler Speicher-Service für Einstellungen, Stundenplandaten und Zeichnungen
public final class TimetableStorageService {
    public static let shared = TimetableStorageService()

    private let defaults = UserDefaults.standard
    private let fileManager = FileManager.default

    // UserDefaults kann bei einem unerwarteten Beenden noch nicht auf die
    // Plist geschrieben sein. Eine zweite, atomare Kopie verhindert dadurch
    // den Eindruck eines "Reset" beim nächsten Start.
    private var backupDirectory: URL {
        let url = documentsDirectory.appendingPathComponent("PlanAppState", isDirectory: true)
        try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func persist<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
        defaults.synchronize()
        let url = backupDirectory.appendingPathComponent(key).appendingPathExtension("json")
        try? data.write(to: url, options: .atomic)
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

    public func saveLessonNote(_ note: LessonNote) {
        // Metadaten und Pfade speichern
        let noteFile = notesDirectory.appendingPathComponent("\(note.id).note")
        let imageFile = notesDirectory.appendingPathComponent("\(note.id).png")
        let textFile = notesDirectory.appendingPathComponent("\(note.id).text.json")

        try? note.drawingData.write(to: noteFile)
        if let imgData = note.croppedImageData {
            try? imgData.write(to: imageFile)
        } else {
            try? fileManager.removeItem(at: imageFile)
        }

        if !note.textBoxes.isEmpty, let textData = try? JSONEncoder().encode(note.textBoxes) {
            try? textData.write(to: textFile)
        } else {
            try? fileManager.removeItem(at: textFile)
        }

        var metadata = loadNotesMetadata()
        metadata[note.id] = [
            "lineCount": note.lineCount,
            "updatedAt": note.updatedAt.timeIntervalSince1970,
            "hasDrawing": note.hasVisibleContent,
            "backgroundStyle": note.backgroundStyle.rawValue
        ]
        defaults.set(metadata, forKey: Keys.notesMetadata)
    }

    public func loadLessonNote(for noteKey: String) -> LessonNote? {
        let noteFile = notesDirectory.appendingPathComponent("\(noteKey).note")
        let imageFile = notesDirectory.appendingPathComponent("\(noteKey).png")
        let textFile = notesDirectory.appendingPathComponent("\(noteKey).text.json")

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

        let metadata = loadNotesMetadata()[noteKey] as? [String: Any]
        let lineCount = metadata?["lineCount"] as? Int ?? 6
        let timeInterval = metadata?["updatedAt"] as? Double ?? Date().timeIntervalSince1970
        let date = Date(timeIntervalSince1970: timeInterval)
        let backgroundRaw = metadata?["backgroundStyle"] as? String
        let backgroundStyle = backgroundRaw.flatMap(NoteBackgroundStyle.init(rawValue:)) ?? .blank

        return LessonNote(
            id: noteKey,
            drawingData: drawingData,
            croppedImageData: imageData,
            lineCount: lineCount,
            textBoxes: textBoxes,
            backgroundStyle: backgroundStyle,
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
        try? fileManager.removeItem(at: noteFile)
        try? fileManager.removeItem(at: imageFile)
        try? fileManager.removeItem(at: textFile)

        var metadata = loadNotesMetadata()
        metadata.removeValue(forKey: noteKey)
        defaults.set(metadata, forKey: Keys.notesMetadata)
    }

    /// Löscht sämtliche gespeicherten Notizen (Zeichnungen, Vorschaubilder
    /// und Textfelder) unwiderruflich.
    public func deleteAllLessonNotes() {
        if let files = try? fileManager.contentsOfDirectory(
            at: notesDirectory,
            includingPropertiesForKeys: nil
        ) {
            for file in files {
                try? fileManager.removeItem(at: file)
            }
        }
        defaults.set([String: Any](), forKey: Keys.notesMetadata)
    }

    private func loadNotesMetadata() -> [String: Any] {
        return defaults.dictionary(forKey: Keys.notesMetadata) ?? [:]
    }
}
