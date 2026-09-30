import Foundation

/// Lokaler Speicher-Service für Einstellungen, Stundenplandaten und Zeichnungen
public final class TimetableStorageService {
    public static let shared = TimetableStorageService()

    private let defaults = UserDefaults.standard
    private let fileManager = FileManager.default

    private enum Keys {
        static let credentials = "planapp_untis_credentials"
        static let customizations = "planapp_subject_customizations"
        static let displaySettings = "planapp_block_display_settings"
        static let periods = "planapp_periods"
        static let lessons = "planapp_lessons"
        static let notesMetadata = "planapp_notes_metadata"
        static let drawingSettings = "planapp_drawing_settings"
        static let viewMode = "planapp_timetable_view_mode"
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
        if let data = try? JSONEncoder().encode(creds) {
            defaults.set(data, forKey: Keys.credentials)
        }
    }

    public func loadCredentials() -> UntisCredentials {
        guard let data = defaults.data(forKey: Keys.credentials),
              let creds = try? JSONDecoder().decode(UntisCredentials.self, from: data) else {
            return UntisCredentials()
        }
        return creds
    }

    // MARK: - Subject Customizations

    public func saveCustomizations(_ list: [SubjectCustomization]) {
        if let data = try? JSONEncoder().encode(list) {
            defaults.set(data, forKey: Keys.customizations)
        }
    }

    public func loadCustomizations() -> [SubjectCustomization] {
        guard let data = defaults.data(forKey: Keys.customizations),
              let list = try? JSONDecoder().decode([SubjectCustomization].self, from: data) else {
            return []
        }
        return list
    }

    // MARK: - Display Settings

    public func saveDisplaySettings(_ settings: BlockDisplaySettings) {
        if let data = try? JSONEncoder().encode(settings) {
            defaults.set(data, forKey: Keys.displaySettings)
        }
    }

    public func loadDisplaySettings() -> BlockDisplaySettings {
        guard let data = defaults.data(forKey: Keys.displaySettings),
              let settings = try? JSONDecoder().decode(BlockDisplaySettings.self, from: data) else {
            return BlockDisplaySettings.default
        }
        return settings
    }

    // MARK: - Drawing Settings

    public func saveDrawingSettings(_ settings: DrawingSettings) {
        if let data = try? JSONEncoder().encode(settings) {
            defaults.set(data, forKey: Keys.drawingSettings)
        }
    }

    public func loadDrawingSettings() -> DrawingSettings {
        guard let data = defaults.data(forKey: Keys.drawingSettings),
              let settings = try? JSONDecoder().decode(DrawingSettings.self, from: data) else {
            return DrawingSettings.default
        }
        return settings
    }

    // MARK: - Ansichts-Modus

    public func saveViewMode(_ mode: TimetableViewMode) {
        defaults.set(mode.rawValue, forKey: Keys.viewMode)
    }

    public func loadViewMode() -> TimetableViewMode {
        guard let raw = defaults.string(forKey: Keys.viewMode),
              let mode = TimetableViewMode(rawValue: raw) else {
            return .fallback
        }
        return mode
    }

    // MARK: - Periods

    public func savePeriods(_ periods: [Period]) {
        if let data = try? JSONEncoder().encode(periods) {
            defaults.set(data, forKey: Keys.periods)
        }
    }

    public func loadPeriods() -> [Period] {
        guard let data = defaults.data(forKey: Keys.periods),
              let periods = try? JSONDecoder().decode([Period].self, from: data) else {
            return Period.defaultPeriods
        }
        return periods
    }

    // MARK: - Lessons

    public func saveLessons(_ lessons: [Lesson]) {
        if let data = try? JSONEncoder().encode(lessons) {
            defaults.set(data, forKey: Keys.lessons)
        }
    }

    public func loadLessons() -> [Lesson] {
        guard let data = defaults.data(forKey: Keys.lessons),
              let lessons = try? JSONDecoder().decode([Lesson].self, from: data) else {
            return []
        }
        return lessons
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
            "hasDrawing": !note.drawingData.isEmpty || !note.textBoxes.isEmpty,
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
