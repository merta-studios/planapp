import Foundation

/// Vollständige Sicherung aller in der App gespeicherten Daten:
/// Zugangsdaten, Fächer, Lehrkräfte, Block-Darstellung, Zeichen-Einstellungen,
/// Stundenraster, Stundenplan, **alle Notizen** (inkl. Zeichnung, Vorschaubild,
/// Textfeldern, Hintergrund und Tag), Ansichts-Modus, Erscheinungsbild und
/// das Tag-System.
public struct AppBackup: Codable {
    public static let currentFormatVersion = 1
    public static let identifier = "planapp.backup"

    public var identifier: String
    public var formatVersion: Int
    public var createdAt: Date
    public var credentials: UntisCredentials
    public var subjectCustomizations: [SubjectCustomization]
    public var teacherNameCustomizations: [TeacherNameCustomization]
    public var displaySettings: BlockDisplaySettings
    public var drawingSettings: DrawingSettings
    public var periods: [Period]
    public var lessons: [Lesson]
    public var notes: [LessonNote]
    public var viewMode: String
    public var appearance: String
    public var tagSettings: NoteTagSettings

    public init(
        createdAt: Date,
        credentials: UntisCredentials,
        subjectCustomizations: [SubjectCustomization],
        teacherNameCustomizations: [TeacherNameCustomization],
        displaySettings: BlockDisplaySettings,
        drawingSettings: DrawingSettings,
        periods: [Period],
        lessons: [Lesson],
        notes: [LessonNote],
        viewMode: String,
        appearance: String,
        tagSettings: NoteTagSettings
    ) {
        self.identifier = AppBackup.identifier
        self.formatVersion = AppBackup.currentFormatVersion
        self.createdAt = createdAt
        self.credentials = credentials
        self.subjectCustomizations = subjectCustomizations
        self.teacherNameCustomizations = teacherNameCustomizations
        self.displaySettings = displaySettings
        self.drawingSettings = drawingSettings
        self.periods = periods
        self.lessons = lessons
        self.notes = notes
        self.viewMode = viewMode
        self.appearance = appearance
        self.tagSettings = tagSettings
    }

    private enum CodingKeys: String, CodingKey {
        case identifier, formatVersion, createdAt, credentials
        case subjectCustomizations, teacherNameCustomizations
        case displaySettings, drawingSettings, periods, lessons, notes
        case viewMode, appearance, tagSettings
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.identifier = try container.decodeIfPresent(String.self, forKey: .identifier) ?? ""
        self.formatVersion = try container.decodeIfPresent(Int.self, forKey: .formatVersion) ?? 1
        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        self.credentials = try container.decodeIfPresent(UntisCredentials.self, forKey: .credentials) ?? UntisCredentials()
        self.subjectCustomizations = try container.decodeIfPresent([SubjectCustomization].self, forKey: .subjectCustomizations) ?? []
        self.teacherNameCustomizations = try container.decodeIfPresent([TeacherNameCustomization].self, forKey: .teacherNameCustomizations) ?? []
        self.displaySettings = try container.decodeIfPresent(BlockDisplaySettings.self, forKey: .displaySettings) ?? BlockDisplaySettings.default
        self.drawingSettings = try container.decodeIfPresent(DrawingSettings.self, forKey: .drawingSettings) ?? DrawingSettings.default
        self.periods = try container.decodeIfPresent([Period].self, forKey: .periods) ?? []
        self.lessons = try container.decodeIfPresent([Lesson].self, forKey: .lessons) ?? []
        self.notes = try container.decodeIfPresent([LessonNote].self, forKey: .notes) ?? []
        self.viewMode = try container.decodeIfPresent(String.self, forKey: .viewMode) ?? ""
        self.appearance = try container.decodeIfPresent(String.self, forKey: .appearance) ?? ""
        self.tagSettings = try container.decodeIfPresent(NoteTagSettings.self, forKey: .tagSettings) ?? NoteTagSettings()
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(identifier, forKey: .identifier)
        try container.encode(formatVersion, forKey: .formatVersion)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(credentials, forKey: .credentials)
        try container.encode(subjectCustomizations, forKey: .subjectCustomizations)
        try container.encode(teacherNameCustomizations, forKey: .teacherNameCustomizations)
        try container.encode(displaySettings, forKey: .displaySettings)
        try container.encode(drawingSettings, forKey: .drawingSettings)
        try container.encode(periods, forKey: .periods)
        try container.encode(lessons, forKey: .lessons)
        try container.encode(notes, forKey: .notes)
        try container.encode(viewMode, forKey: .viewMode)
        try container.encode(appearance, forKey: .appearance)
        try container.encode(tagSettings, forKey: .tagSettings)
    }

    /// Kurze Zusammenfassung für den Bestätigungs-Dialog vor dem Import.
    public var summary: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let visibleNotes = notes.filter { $0.hasVisibleContent }.count
        return "Sicherung vom \(formatter.string(from: createdAt))\n"
            + "\(visibleNotes) Notizen · \(lessons.count) Stunden · \(subjectCustomizations.count) Fächer · "
            + "\(teacherNameCustomizations.count) Lehrkräfte · \(tagSettings.tags.count) Tags"
    }
}

public enum AppBackupError: LocalizedError {
    case invalidText
    case notABackup
    case unsupportedVersion(Int)

    public var errorDescription: String? {
        switch self {
        case .invalidText:
            return "Der Text ist keine gültige PlanApp-Sicherung."
        case .notABackup:
            return "Der Text enthält keine PlanApp-Daten."
        case .unsupportedVersion(let version):
            return "Diese Sicherung (Version \(version)) stammt aus einer neueren App-Version."
        }
    }
}

/// Wandelt eine Sicherung in einen teilbaren Base64-Text um und zurück.
///
/// Aufbau: `PLANAPP1:` + Base64(LZFSE(JSON)). Das Präfix erlaubt eine schnelle
/// Gültigkeitsprüfung der Zwischenablage, die Kompression hält den Text trotz
/// eingebetteter Zeichnungen und Vorschaubilder klein. Zur Sicherheit wird
/// beim Lesen auch unkomprimiertes JSON akzeptiert.
public enum AppBackupCodec {
    public static let prefix = "PLANAPP1:"

    public static func encode(_ backup: AppBackup) throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let json = try encoder.encode(backup)
        let payload: Data
        if let compressed = try? (json as NSData).compressed(using: .lzfse) as Data {
            payload = compressed
        } else {
            payload = json
        }
        return prefix + payload.base64EncodedString()
    }

    /// Prüft nur, ob der Text wie eine Sicherung aussieht (schnell, ohne Decodieren).
    public static func looksLikeBackup(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix(prefix)
    }

    public static func decode(_ text: String) throws -> AppBackup {
        var body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard body.hasPrefix(prefix) else { throw AppBackupError.notABackup }
        body.removeFirst(prefix.count)
        // Zeilenumbrüche/Leerzeichen, die z. B. Messenger einfügen, entfernen.
        body = body.filter { !$0.isWhitespace }
        guard let payload = Data(base64Encoded: body) else { throw AppBackupError.invalidText }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let json: Data
        if let decompressed = try? (payload as NSData).decompressed(using: .lzfse) as Data {
            json = decompressed
        } else {
            json = payload
        }

        guard let backup = try? decoder.decode(AppBackup.self, from: json) else {
            throw AppBackupError.invalidText
        }
        guard backup.identifier == AppBackup.identifier else { throw AppBackupError.notABackup }
        guard backup.formatVersion <= AppBackup.currentFormatVersion else {
            throw AppBackupError.unsupportedVersion(backup.formatVersion)
        }
        return backup
    }
}
