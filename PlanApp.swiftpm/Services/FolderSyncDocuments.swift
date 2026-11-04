import Foundation

/// Zerlegt eine App-Sicherung in **einzelne, kleine Dokumente** und setzt sie
/// wieder zusammen – die Grundlage des Ordner-Syncs.
///
/// Warum: Eine einzige Textdatei mit allen Notizen wächst mit jedem
/// Vorschaubild in die Megabyte. Solche Dateien lassen sich weder von Hand
/// kopieren noch zuverlässig zwischen Geräten abgleichen, und beim Schreiben
/// wird bei jedem Strich alles neu übertragen. Der Ordner-Sync schreibt
/// stattdessen:
///
/// * `settings.json` – Stundenplan, Fächer, Einstellungen, Tags, Noten
/// * `notes/<notiz>.json` – genau eine Notiz pro Datei
///
/// Damit ist jeder Schreibvorgang klein, iCloud lädt nur die geänderten
/// Dateien, und ein Konflikt betrifft höchstens eine Notiz.
public enum FolderSyncDocuments {
    /// Zeitauflösung für „wer ist neuer“ – iCloud speichert Modifikationszeiten
    /// in Sekunden; feinere Unterschiede sind nicht übertragbar.
    public static let timestampGranularity: TimeInterval = 1

    /// Name der Notiz-Daten innerhalb der Sicherung (ohne die übrigen Felder).
    private struct SettingsPayload: Codable {
        var identifier: String
        var formatVersion: Int
        var credentials: UntisCredentials
        var subjectCustomizations: [SubjectCustomization]
        var teacherNameCustomizations: [TeacherNameCustomization]
        var displaySettings: BlockDisplaySettings
        var drawingSettings: DrawingSettings
        var periods: [Period]
        var lessons: [Lesson]
        var viewMode: String
        var appearance: String
        var tagSettings: NoteTagSettings
        var gradeSettings: GradeSettings
        var gradeBook: GradeBook
        var createdAt: Date

        init(_ backup: AppBackup) {
            identifier = backup.identifier
            formatVersion = backup.formatVersion
            credentials = backup.credentials
            subjectCustomizations = backup.subjectCustomizations
            teacherNameCustomizations = backup.teacherNameCustomizations
            displaySettings = backup.displaySettings
            drawingSettings = backup.drawingSettings
            periods = backup.periods
            lessons = backup.lessons
            viewMode = backup.viewMode
            appearance = backup.appearance
            tagSettings = backup.tagSettings
            gradeSettings = backup.gradeSettings
            gradeBook = backup.gradeBook
            createdAt = backup.createdAt
        }
    }

    /// Rahmen einer Notiz-Datei: Schlüssel + Notiz.
    private struct NotePayload: Codable {
        var identifier: String
        var noteKey: String
        var note: LessonNote
    }

    // MARK: - Sicherung → Dokumente

    /// Zerlegt eine Sicherung in ihre Dokumente.
    ///
    /// - Parameters:
    ///   - backup: lokaler Stand
    ///   - settingsUpdatedAt: Zeitmarke des Einstellungs-Dokuments. Sie ändert
    ///     sich nur, wenn sich Stundenplan/Einstellungen ändern – nicht bei
    ///     jedem Notizstrich.
    public static func documents(
        from backup: AppBackup,
        settingsUpdatedAt: Date
    ) -> [FolderSyncDocument] {
        var result: [FolderSyncDocument] = []
        if let data = try? encoder.encode(SettingsPayload(backup)) {
            result.append(FolderSyncDocument(
                key: FolderSyncDocument.settingsKey,
                updatedAt: settingsUpdatedAt,
                data: data
            ))
        }
        for note in backup.notes where note.hasVisibleContent {
            guard let data = try? encoder.encode(NotePayload(
                identifier: AppBackup.identifier,
                noteKey: note.id,
                note: note
            )) else { continue }
            result.append(FolderSyncDocument(
                key: note.id,
                updatedAt: note.updatedAt,
                data: data
            ))
        }
        return result
    }

    // MARK: - Dokumente → Sicherung

    /// Baut aus den Dokumenten eines Ordners wieder eine vollständige
    /// Sicherung. Unlesbare Notiz-Dateien werden übersprungen – ein einzelner
    /// beschädigter Datensatz darf nicht alles blockieren.
    public static func backup(
        settingsData: Data?,
        notes: [FolderSyncDocument],
        fallbackCreatedAt: Date = Date()
    ) -> AppBackup? {
        guard let settingsData,
              let payload = try? decoder.decode(SettingsPayload.self, from: settingsData),
              payload.identifier == AppBackup.identifier else { return nil }

        let decodedNotes: [LessonNote] = notes.compactMap { document in
            guard let notePayload = try? decoder.decode(NotePayload.self, from: document.data),
                  notePayload.identifier == AppBackup.identifier else { return nil }
            var note = notePayload.note
            // Der Dateiname ist nur eine Ablagehilfe – maßgeblich ist der
            // Schlüssel im Inhalt. So bleiben auch Notizen erreichbar, deren
            // Name im Ordner normalisiert wurde.
            if !notePayload.noteKey.isEmpty {
                note.id = notePayload.noteKey
            }
            return note
        }

        return AppBackup(
            createdAt: payload.createdAt == .distantPast ? fallbackCreatedAt : payload.createdAt,
            credentials: payload.credentials,
            subjectCustomizations: payload.subjectCustomizations,
            teacherNameCustomizations: payload.teacherNameCustomizations,
            displaySettings: payload.displaySettings,
            drawingSettings: payload.drawingSettings,
            periods: payload.periods,
            lessons: payload.lessons,
            notes: decodedNotes.sorted { $0.id < $1.id },
            viewMode: payload.viewMode,
            appearance: payload.appearance,
            tagSettings: payload.tagSettings,
            gradeSettings: payload.gradeSettings,
            gradeBook: payload.gradeBook
        )
    }

    /// Ein einzelnes Notiz-Dokument aus einer Notiz.
    public static func document(for note: LessonNote) -> FolderSyncDocument? {
        guard let data = try? encoder.encode(NotePayload(
            identifier: AppBackup.identifier,
            noteKey: note.id,
            note: note
        )) else { return nil }
        return FolderSyncDocument(key: note.id, updatedAt: note.updatedAt, data: data)
    }

    /// Zeitmarke eines Dokuments aus seinem Inhalt (Notizen tragen ihr
    /// `updatedAt` selbst; das Einstellungs-Dokument sein `createdAt`).
    public static func updatedAt(forData data: Data) -> Date? {
        if let note = try? decoder.decode(NotePayload.self, from: data) {
            return note.note.updatedAt
        }
        if let settings = try? decoder.decode(SettingsPayload.self, from: data) {
            return settings.createdAt
        }
        return nil
    }

    /// Eine einzelne Notiz aus ihrem Dokument.
    public static func note(from document: FolderSyncDocument) -> LessonNote? {
        guard let payload = try? decoder.decode(NotePayload.self, from: document.data),
              payload.identifier == AppBackup.identifier else { return nil }
        var note = payload.note
        if !payload.noteKey.isEmpty {
            note.id = payload.noteKey
        }
        return note
    }

    /// Notiz-Schlüssel direkt aus einer Notiz-Datei (ohne vollständiges
    /// Dekodieren der Notiz).
    public static func noteKey(fromData data: Data) -> String? {
        guard let payload = try? decoder.decode(NotePayload.self, from: data),
              !payload.noteKey.isEmpty else { return nil }
        return payload.noteKey
    }

    // MARK: - Codierung

    /// JSON statt des alten `PLANAPP1:`-Base64-Formats: einzelne Dateien sind
    /// klein genug, und JSON lässt sich notfalls von Hand lesen.
    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
