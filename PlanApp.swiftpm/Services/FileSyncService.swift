import Foundation
import Combine
import CryptoKit

/// Konfiguration des Ordner-Syncs über iCloud Drive.
///
/// Die App besitzt (Swift Playgrounds / Sideloadly) keine iCloud-Berechtigung
/// und kann kein CloudKit nutzen. Stattdessen wählt man einmalig **einen
/// Ordner** in iCloud Drive; darin legt die App viele kleine Dateien an (siehe
/// ``FolderSyncDocuments``). iCloud Drive hält diese Dateien auf allen Geräten
/// aktuell – ohne dass zwei Geräte sich gegenseitig mit einer riesigen Datei
/// überschreiben.
public struct FileSyncConfiguration: Codable, Equatable {
    /// Ob die Synchronisation aktiv ist (Standard: aus).
    public var isEnabled: Bool
    /// Sicherheits-Bookmark (mit Zugriffsrecht) auf den Sync-Ordner.
    public var locationBookmark: Data?
    /// `true`, wenn das Bookmark einen Ordner meint (immer der Fall beim
    /// Ordner-Sync; bleibt für alte Konfigurationen erhalten).
    public var locationIsDirectory: Bool
    /// Anzeigename des Ordners (nur für die Einstellungen).
    public var fileName: String
    /// Stabile Kennung dieses Geräts (für Diagnose-Zwecke).
    public var deviceID: String
    /// Zeitpunkt der letzten erfolgreichen Synchronisation.
    public var lastSyncDate: Date?
    /// Gelöschte Notizen (Notiz-ID → Löschdatum). Ohne diese „Grabsteine“
    /// würde eine anderswo noch vorhandene Datei eine lokale Löschung beim
    /// Zusammenführen wieder auferstehen lassen.
    public var deletedNoteIDs: [String: Date]
    /// Notiz-Schlüssel, die zuletzt im Ordner lagen. Fehlt einer davon später,
    /// wurde er auf einem anderen Gerät gelöscht – das ist der einzige
    /// verlässliche Weg, eine Löschung ohne Grabstein zu erkennen.
    public var knownRemoteKeys: Set<String>
    /// Ob der zuletzt benutzte Speicherort das alte Ein-Datei-Format war.
    /// Solche Verknüpfungen werden beim nächsten Sync automatisch auf den
    /// Ordner umgestellt (die alte Datei bleibt unangetastet).
    public var usesLegacyFile: Bool

    public init(
        isEnabled: Bool = false,
        locationBookmark: Data? = nil,
        locationIsDirectory: Bool = false,
        fileName: String = FileSyncService.defaultFolderName,
        deviceID: String = UUID().uuidString,
        lastSyncDate: Date? = nil,
        deletedNoteIDs: [String: Date] = [:],
        knownRemoteKeys: Set<String> = [],
        usesLegacyFile: Bool = false
    ) {
        self.isEnabled = isEnabled
        self.locationBookmark = locationBookmark
        self.locationIsDirectory = locationIsDirectory
        self.fileName = fileName
        self.deviceID = deviceID
        self.lastSyncDate = lastSyncDate
        self.deletedNoteIDs = deletedNoteIDs
        self.knownRemoteKeys = knownRemoteKeys
        self.usesLegacyFile = usesLegacyFile
    }

    private enum CodingKeys: String, CodingKey {
        case isEnabled, locationBookmark, locationIsDirectory, fileName
        case deviceID, lastSyncDate, deletedNoteIDs, knownRemoteKeys, usesLegacyFile
        // Alte Schlüssel – werden nur noch gelesen, nie geschrieben.
        case lastSyncedHash
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? false
        locationBookmark = try container.decodeIfPresent(Data.self, forKey: .locationBookmark)
        locationIsDirectory = try container.decodeIfPresent(Bool.self, forKey: .locationIsDirectory) ?? false
        fileName = try container.decodeIfPresent(String.self, forKey: .fileName) ?? FileSyncService.defaultFolderName
        deviceID = try container.decodeIfPresent(String.self, forKey: .deviceID) ?? UUID().uuidString
        lastSyncDate = try container.decodeIfPresent(Date.self, forKey: .lastSyncDate)
        deletedNoteIDs = try container.decodeIfPresent([String: Date].self, forKey: .deletedNoteIDs) ?? [:]
        knownRemoteKeys = try container.decodeIfPresent(Set<String>.self, forKey: .knownRemoteKeys) ?? []
        usesLegacyFile = try container.decodeIfPresent(Bool.self, forKey: .usesLegacyFile) ?? false
        // Ein alter Stand ohne `knownRemoteKeys` und ohne `usesLegacyFile`, der
        // eine Datei statt eines Ordners meint, stammt aus dem Ein-Datei-Sync.
        if !locationIsDirectory, locationBookmark != nil {
            usesLegacyFile = true
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encodeIfPresent(locationBookmark, forKey: .locationBookmark)
        try container.encode(locationIsDirectory, forKey: .locationIsDirectory)
        try container.encode(fileName, forKey: .fileName)
        try container.encode(deviceID, forKey: .deviceID)
        try container.encodeIfPresent(lastSyncDate, forKey: .lastSyncDate)
        try container.encode(deletedNoteIDs, forKey: .deletedNoteIDs)
        try container.encode(knownRemoteKeys, forKey: .knownRemoteKeys)
        try container.encode(usesLegacyFile, forKey: .usesLegacyFile)
    }
}

/// Automatische Sicherheitskopie des lokalen Stands, angelegt bevor ein
/// fremder Sync-Stand übernommen wird. Die letzten drei bleiben erhalten und
/// lassen sich in den Einstellungen wiederherstellen.
public struct FileSyncSafetyBackup: Codable, Identifiable, Equatable {
    public var id: UUID
    public var createdAt: Date
    public var text: String
    public var noteCount: Int

    public init(id: UUID = UUID(), createdAt: Date = Date(), text: String, noteCount: Int) {
        self.id = id
        self.createdAt = createdAt
        self.text = text
        self.noteCount = noteCount
    }

    public var summary: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "\(formatter.string(from: createdAt)) · \(noteCount) Notizen"
    }
}

/// Ergebnis des Verknüpfens mit einem Sync-Ordner.
public enum FileSyncLinkOutcome {
    /// Verknüpft und aktiv – mit Beschreibung dessen, was übernommen wurde.
    case linked(message: String)
    /// Abgebrochen, mit Begründung. Es wurde nichts verändert.
    case failed(message: String)
}

/// Ordner-Synchronisation über iCloud Drive.
///
/// **Warum Ordner statt einer Datei?** (Antwort auf den Absturz mit großen
/// Textdateien und die ständigen gegenseitigen Überschreibungen)
///
/// * Eine einzige Textdatei wächst mit jedem Vorschaubild auf mehrere Megabyte.
///   Beim Schreiben muss sie komplett neu entstehen – bei jedem Gerät und
///   jeder kleinen Änderung. Zwei Geräte, die das gleichzeitig tun,
///   überschreiben sich gegenseitig.
/// * Der Ordner enthält **eine Datei pro Notiz** plus ein kleines
///   `settings.json`. Geschrieben wird nur, was sich geändert hat. iCloud lädt
///   beim anderen Gerät nur diese eine Datei.
/// * Jede Datei trägt ihren eigenen Zeitstempel. Beim Zusammenführen gewinnt
///   pro Notiz der neuere Stand – ein Konflikt betrifft höchstens eine Notiz,
///   niemals den gesamten Bestand.
/// * Löschungen werden über Grabsteine und die Liste der zuletzt im Ordner
///   gesehenen Dateien erkannt, damit nichts „wieder aufersteht“.
///
/// So arbeiten auch professionelle Notiz-Apps (ein Dokument pro Notiz,
/// dateiweiser Abgleich) – genau deshalb ist die Kopie des Ordners per Hand
/// ebenfalls einfach: Es ist ein normaler Ordner mit lesbaren Dateien.
@MainActor
public final class FileSyncService: ObservableObject {
    nonisolated public static let defaultFolderName = "PlanApp-Sync"
    nonisolated public static let maximumSafetyBackups = 3
    /// Wartezeit nach der letzten lokalen Änderung, bevor geschrieben wird.
    nonisolated public static let pushDebounceInterval: TimeInterval = 1.2
    /// Wie oft der Ordner auf fremde Änderungen geprüft wird. Kurz, weil das
    /// Lesen nur die Metadaten der kleinen Dateien braucht.
    nonisolated public static let pullInterval: TimeInterval = 6
    /// Grabsteine älter als 30 Tage werden entsorgt.
    nonisolated private static let tombstoneLifetime: TimeInterval = 30 * 24 * 3600
    private static let notesSubdirectory = "notes"

    @Published public private(set) var configuration = FileSyncConfiguration()
    /// Kurze Erfolgs-/Statusmeldung für die Einstellungen.
    @Published public private(set) var statusMessage: String? = nil
    /// Aktuelle Fehlermeldung (`nil` = alles in Ordnung).
    @Published public private(set) var errorMessage: String? = nil
    /// Ob gerade gelesen oder geschrieben wird.
    @Published public private(set) var isWorking = false
    @Published public private(set) var safetyBackups: [FileSyncSafetyBackup] = []
    /// Anzahl der Notiz-Dateien im Ordner (für die Anzeige).
    @Published public private(set) var remoteNoteCount: Int = 0

    /// Erzeugt die aktuelle lokale Sicherung (vom ViewModel gesetzt).
    public var makeLocalBackup: (() -> AppBackup?)?
    /// Übernimmt eine Sicherung (vom ViewModel gesetzt).
    public var applyBackup: ((AppBackup) -> Void)?

    public var isEnabled: Bool { configuration.isEnabled }

    /// Anzeigename des Sync-Ordners.
    public var syncFileDisplayName: String {
        let name = configuration.fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? Self.defaultFolderName : name
    }

    public var lastSyncDescription: String? {
        guard let date = configuration.lastSyncDate else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    /// Zeitmarke des Einstellungs-Dokuments. Sie ändert sich nur, wenn sich
    /// Stundenplan/Einstellungen ändern – nicht bei jedem Notizstrich.
    private var settingsUpdatedAt: Date {
        get {
            if let stored = UserDefaults.standard.object(forKey: Self.settingsTimestampKey) as? Double {
                return Date(timeIntervalSince1970: stored)
            }
            return .distantPast
        }
        set {
            UserDefaults.standard.set(newValue.timeIntervalSince1970, forKey: Self.settingsTimestampKey)
        }
    }
    private static let settingsTimestampKey = "planapp_folder_sync_settings_updated_at"

    private let storage = TimetableStorageService.shared
    private var pullTimer: AnyCancellable? = nil
    private var pushWorkItem: DispatchWorkItem? = nil
    private var hasUnpushedLocalChanges = false
    private var statusClearWorkItem: DispatchWorkItem? = nil
    /// Verhindert, dass Push und Pull gleichzeitig laufen.
    private var isSyncing = false

    public init() {
        self.configuration = storage.loadFileSyncConfiguration()
        // Ohne gespeicherten Ort kann die Sync nicht aktiv sein (z. B. nach
        // einem Import, der die Konfiguration nicht mitnahm).
        if configuration.isEnabled, configuration.locationBookmark == nil {
            configuration.isEnabled = false
            storage.saveFileSyncConfiguration(configuration)
        }
        self.safetyBackups = storage.loadFileSyncSafetyBackups()
        if configuration.isEnabled, !configuration.usesLegacyFile {
            startTimers()
        }
    }

    // MARK: - Lebenszyklus

    private func startTimers() {
        stopTimers()
        pullTimer = Timer.publish(every: Self.pullInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.pullNow()
                }
            }
    }

    private func stopTimers() {
        pullTimer?.cancel()
        pullTimer = nil
        pushWorkItem?.cancel()
        pushWorkItem = nil
    }

    private func saveConfiguration() {
        configuration.deletedNoteIDs = FolderSyncRules.prunedTombstones(
            configuration.deletedNoteIDs,
            lifetime: Self.tombstoneLifetime
        )
        storage.saveFileSyncConfiguration(configuration)
    }

    // MARK: - Lokale Änderungen melden

    /// Das ViewModel ruft das nach jeder lokalen Datenänderung auf. Der
    /// Schreibvorgang läuft entprellt, damit z. B. schnelles Notieren nicht
    /// bei jedem Strich in den Ordner schreibt.
    public func markLocalDirty() {
        guard configuration.isEnabled else { return }
        hasUnpushedLocalChanges = true
        schedulePush()
    }

    /// Meldet, dass sich Stundenplan/Einstellungen geändert haben. Nur dann
    /// bekommt `settings.json` eine neue Zeitmarke – Notizänderungen lassen
    /// das Einstellungs-Dokument unberührt.
    public func markSettingsChanged() {
        guard configuration.isEnabled else { return }
        settingsUpdatedAt = Date()
        markLocalDirty()
    }

    private func schedulePush() {
        pushWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in
                await self?.pushNow()
            }
        }
        pushWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.pushDebounceInterval, execute: item)
    }

    // MARK: - Verknüpfen & Trennen

    /// Legt den Sync-Ordner im gewählten Ordner an (bzw. benutzt ihn) und
    /// aktiviert die Synchronisation. Der Ordner muss in iCloud Drive liegen.
    public func linkNewFile(in folderURL: URL) async -> FileSyncLinkOutcome {
        clearMessages()
        guard Self.isICloudDriveURL(folderURL) else {
            return .failed(message: "Bitte wähle einen Ordner in iCloud Drive (z. B. unter „iCloud Drive“ in der Dateien-App), damit alle Geräte dieselben Dateien sehen.")
        }
        guard let local = makeLocalBackup?() else {
            return .failed(message: "Die lokalen Daten konnten nicht gelesen werden.")
        }
        isWorking = true
        defer { isWorking = false }

        let accessing = folderURL.startAccessingSecurityScopedResource()
        defer { if accessing { folderURL.stopAccessingSecurityScopedResource() } }

        do {
            guard let bookmark = try? folderURL.bookmarkData() else {
                return .failed(message: "Auf diesen Ordner konnte kein dauerhafter Zugriff gespeichert werden. Bitte wähle ihn erneut.")
            }

            // Neuen Unterordner anlegen, damit ein bereits vorhandener
            // Sync-Ordner nicht ungefragt überschrieben wird.
            let manager = FileManager.default
            let baseName = Self.defaultFolderName
            var candidate = folderURL.appendingPathComponent(baseName, isDirectory: true)
            var counter = 2
            while manager.fileExists(atPath: candidate.path) {
                candidate = folderURL.appendingPathComponent("\(baseName) \(counter)", isDirectory: true)
                counter += 1
                if counter > 50 { break }
            }
            try manager.createDirectory(at: candidate, withIntermediateDirectories: true)
            try manager.createDirectory(
                at: candidate.appendingPathComponent(Self.notesSubdirectory, isDirectory: true),
                withIntermediateDirectories: true
            )

            activation(at: candidate, name: candidate.lastPathComponent)
            await writeLocalDocuments(local)
            configuration.lastSyncDate = Date()
            saveConfiguration()

            let message = "Sync-Ordner „\(candidate.lastPathComponent)“ in iCloud Drive angelegt und aktiviert."
            showStatus(message)
            return .linked(message: message)
        } catch {
            return .failed(message: "Der Ordner konnte nicht angelegt werden: \(error.localizedDescription)")
        }
    }

    /// Verknüpft einen bestehenden Sync-Ordner und führt ihn mit dem lokalen
    /// Stand zusammen. Es wird nichts überschrieben; pro Notiz gewinnt der
    /// neuere Stand, Sicherheitskopie inklusive.
    public func linkExistingFolder(at folderURL: URL) async -> FileSyncLinkOutcome {
        clearMessages()
        guard Self.isICloudDriveURL(folderURL) else {
            return .failed(message: "Bitte wähle den Sync-Ordner in iCloud Drive (z. B. unter „iCloud Drive“ in der Dateien-App), damit alle Geräte dieselben Dateien sehen.")
        }
        guard makeLocalBackup?() != nil else {
            return .failed(message: "Die lokalen Daten konnten nicht gelesen werden.")
        }
        isWorking = true
        defer { isWorking = false }

        let accessing = folderURL.startAccessingSecurityScopedResource()
        defer { if accessing { folderURL.stopAccessingSecurityScopedResource() } }

        do {
            guard let bookmark = try? folderURL.bookmarkData() else {
                return .failed(message: "Auf diesen Ordner konnte kein dauerhafter Zugriff gespeichert werden. Bitte wähle ihn erneut.")
            }
            let manager = FileManager.default
            try manager.createDirectory(
                at: folderURL.appendingPathComponent(Self.notesSubdirectory, isDirectory: true),
                withIntermediateDirectories: true
            )
            activation(at: folderURL, name: folderURL.lastPathComponent)
            let before = configuration.knownRemoteKeys.count
            await synchronize(forcePull: true)
            let message = before == 0
                ? "Sync-Ordner „\(folderURL.lastPathComponent)“ verbunden und mit deinen Daten gefüllt."
                : "Sync-Ordner „\(folderURL.lastPathComponent)“ verbunden und zusammengeführt. Es geht nichts verloren."
            showStatus(message)
            return .linked(message: message)
        } catch {
            return .failed(message: "Der Ordner konnte nicht gelesen werden: \(error.localizedDescription)")
        }
    }

    /// Übernimmt einen Ordner aus dem **alten** Ein-Datei-Sync: Der Ordner
    /// wird umgestellt und die alte Datei dabei einmalig eingelesen, damit
    /// nichts verloren geht.
    public func migrateLegacyFile(at fileURL: URL) async -> FileSyncLinkOutcome {
        clearMessages()
        guard let local = makeLocalBackup?() else {
            return .failed(message: "Die lokalen Daten konnten nicht gelesen werden.")
        }
        isWorking = true
        defer { isWorking = false }

        let accessing = fileURL.startAccessingSecurityScopedResource()
        defer { if accessing { fileURL.stopAccessingSecurityScopedResource() } }

        let existingText = try? String(contentsOf: fileURL, encoding: .utf8)
        if let text = existingText,
               AppBackupCodec.looksLikeBackup(text),
               let legacy = try? AppBackupCodec.decode(text) {
            // Alten Stand einmalig übernehmen – pro Notiz der neuere.
            var notes = Dictionary(uniqueKeysWithValues: local.notes.map { ($0.id, $0) })
            for note in legacy.notes where note.hasVisibleContent {
                if let existing = notes[note.id] {
                    if note.updatedAt > existing.updatedAt {
                        notes[note.id] = note
                    }
                } else {
                    notes[note.id] = note
                }
            }
            let merged = AppBackup(
                createdAt: Date(),
                credentials: legacy.createdAt > local.createdAt ? legacy.credentials : local.credentials,
                subjectCustomizations: legacy.createdAt > local.createdAt ? legacy.subjectCustomizations : local.subjectCustomizations,
                teacherNameCustomizations: legacy.createdAt > local.createdAt ? legacy.teacherNameCustomizations : local.teacherNameCustomizations,
                displaySettings: legacy.createdAt > local.createdAt ? legacy.displaySettings : local.displaySettings,
                drawingSettings: legacy.createdAt > local.createdAt ? legacy.drawingSettings : local.drawingSettings,
                periods: legacy.createdAt > local.createdAt ? legacy.periods : local.periods,
                lessons: legacy.createdAt > local.createdAt ? legacy.lessons : local.lessons,
                notes: Array(notes.values).sorted { $0.id < $1.id },
                viewMode: legacy.createdAt > local.createdAt ? legacy.viewMode : local.viewMode,
                appearance: legacy.createdAt > local.createdAt ? legacy.appearance : local.appearance,
                tagSettings: legacy.createdAt > local.createdAt ? legacy.tagSettings : local.tagSettings,
                gradeSettings: legacy.createdAt > local.createdAt ? legacy.gradeSettings : local.gradeSettings,
                gradeBook: legacy.createdAt > local.createdAt ? legacy.gradeBook : local.gradeBook
            )
            storeSafetyBackup(for: local)
            applyBackup?(merged)
        }

        // Ordner neben der alten Datei anlegen und dort weitermachen.
        let parent = fileURL.deletingLastPathComponent()
        return await linkNewFile(in: parent)
    }

    private func activation(at folderURL: URL, name: String) {
        configuration.isEnabled = true
        configuration.locationIsDirectory = true
        configuration.fileName = name
        configuration.usesLegacyFile = false
        configuration.lastSyncDate = Date()
        settingsUpdatedAt = Date()
        hasUnpushedLocalChanges = false
        errorMessage = nil
        persistBookmark(for: folderURL)
        saveConfiguration()
        startTimers()
    }

    private func persistBookmark(for folderURL: URL) {
        guard let bookmark = try? folderURL.bookmarkData() else { return }
        configuration.locationBookmark = bookmark
    }

    /// Trennt die Verknüpfung. Lokale Daten und der Ordner bleiben erhalten –
    /// es wird danach nur nicht mehr automatisch synchronisiert.
    public func unlink() {
        stopTimers()
        pushWorkItem?.cancel()
        pushWorkItem = nil
        configuration.isEnabled = false
        configuration.locationBookmark = nil
        configuration.lastSyncDate = nil
        configuration.knownRemoteKeys = []
        configuration.usesLegacyFile = false
        hasUnpushedLocalChanges = false
        saveConfiguration()
        showStatus("Synchronisation getrennt. Deine Daten und die Dateien im Ordner bleiben erhalten.")
    }

    // MARK: - Schreiben (Push)

    /// Schreibt den lokalen Stand in den Ordner – aber nur die Dateien, die
    /// sich geändert haben.
    public func pushNow() async {
        guard configuration.isEnabled, !isWorking, !isSyncing else { return }
        guard hasUnpushedLocalChanges else { return }
        await synchronize(forcePull: false)
    }

    // MARK: - Lesen (Pull)

    /// Liest den Ordner und führt ihn mit dem lokalen Stand zusammen.
    public func pullNow() async {
        guard configuration.isEnabled, !isWorking, !isSyncing else { return }
        await synchronize(forcePull: true)
    }

    // MARK: - Der eigentliche Abgleich

    /// Ein vollständiger Durchlauf: Ordner lesen, zusammenführen, Änderungen
    /// in beide Richtungen schreiben.
    private func synchronize(forcePull: Bool) async {
        guard configuration.isEnabled, !isSyncing else { return }
        guard let local = makeLocalBackup?() else { return }

        isSyncing = true
        isWorking = true
        defer {
            isSyncing = false
            isWorking = false
        }

        do {
            let folder = try resolveSyncFolder()
            let accessing = folder.startAccessingSecurityScopedResource()
            defer { if accessing { folder.stopAccessingSecurityScopedResource() } }

            let remote = try readRemoteDocuments(from: folder)
            let localDocuments = FolderSyncDocuments.documents(
                from: local,
                settingsUpdatedAt: settingsUpdatedAt
            )
            let localByKey = Dictionary(uniqueKeysWithValues: localDocuments.map { ($0.key, $0) })

            // Notiz-Dateien, die im Ordner liegen (ohne Einstellungs-Dokument).
            let remoteByKey = remote.filter { !$0.value.isSettings }

            let plan = FolderSyncRules.merge(
                local: localByKey,
                remote: remoteByKey,
                tombstones: configuration.deletedNoteIDs,
                remoteKnownKeys: configuration.knownRemoteKeys,
                lastSyncDate: configuration.lastSyncDate
            )

            // 1) Fremde Stände übernehmen (mit Sicherheitskopie).
            if plan.changesLocalState {
                var notes = local.notes
                var changed = false

                if !plan.incomingDocuments.isEmpty {
                    var byID = Dictionary(uniqueKeysWithValues: notes.map { ($0.id, $0) })
                    for document in plan.incomingDocuments where !document.isSettings {
                        guard let incoming = FolderSyncDocuments.note(from: document) else { continue }
                        if let existing = byID[incoming.id], existing.updatedAt >= incoming.updatedAt {
                            continue
                        }
                        byID[incoming.id] = incoming
                        changed = true
                    }
                    notes = Array(byID.values)
                }

                if !plan.documentsToDeleteLocally.isEmpty {
                    let remove = Set(plan.documentsToDeleteLocally)
                    notes.removeAll { remove.contains($0.id) }
                    changed = true
                }

                // Einstellungs-Dokument getrennt behandeln: es ersetzt nur
                // Stundenplan & Einstellungen, nie die Notizen.
                var updatedBackup = local
                if let settingsDocument = plan.incomingDocuments.first(where: { $0.isSettings }),
                   let settingsBackup = FolderSyncDocuments.backup(
                        settingsData: settingsDocument.data,
                        notes: [],
                        fallbackCreatedAt: local.createdAt
                   ) {
                    var merged = settingsBackup
                    merged.notes = notes
                    merged.createdAt = local.createdAt
                    updatedBackup = merged
                    changed = true
                } else if changed {
                    updatedBackup.notes = notes
                }

                if changed {
                    storeSafetyBackup(for: local)
                    applyBackup?(updatedBackup)
                    resolveTombstones(with: plan)
                }

                if let settingsDocument = plan.incomingDocuments.first(where: { $0.isSettings }) {
                    settingsUpdatedAt = settingsDocument.updatedAt
                }
            }

            // 2) Eigene Änderungen schreiben.
            if plan.changesRemoteState || forcePull {
                try writeDocuments(
                    plan.documentsToWrite,
                    deleting: plan.documentsToDeleteRemotely,
                    in: folder
                )
            }

            // 3) Ordner-Inhalt merken (Grundlage für Löschungserkennung).
            let after = try readRemoteKeys(from: folder)
            configuration.knownRemoteKeys = after
            remoteNoteCount = after.count
            configuration.lastSyncDate = Date()
            hasUnpushedLocalChanges = false
            errorMessage = nil
            saveConfiguration()
        } catch let error as FileSyncAccessError {
            handleAccessError(error)
        } catch {
            errorMessage = "Synchronisation fehlgeschlagen: \(error.localizedDescription)"
        }
    }

    /// Räumt Grabsteine auf, deren Notiz durch eine neuere Bearbeitung wieder
    /// existiert.
    private func resolveTombstones(with plan: FolderSyncMergeResult) {
        for document in plan.incomingDocuments where !document.isSettings {
            if let deletedAt = configuration.deletedNoteIDs[document.key],
               FolderSyncRules.tombstoneResolved(deletedAt, by: document) {
                configuration.deletedNoteIDs.removeValue(forKey: document.key)
            }
        }
        for key in plan.documentsToDeleteRemotely {
            configuration.deletedNoteIDs.removeValue(forKey: key)
        }
    }

    // MARK: - Ordner-Zugriff

    private enum FileSyncAccessError: Error {
        case noBookmark
        case bookmarkInvalid
    }

    private func resolveSyncFolder() throws -> URL {
        guard let bookmark = configuration.locationBookmark else {
            throw FileSyncAccessError.noBookmark
        }
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: bookmark,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            throw FileSyncAccessError.bookmarkInvalid
        }
        if isStale {
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            if let fresh = try? url.bookmarkData() {
                configuration.locationBookmark = fresh
                saveConfiguration()
            }
        }
        return url
    }

    private func handleAccessError(_ error: FileSyncAccessError) {
        switch error {
        case .noBookmark, .bookmarkInvalid:
            // Zugriff verloren (Ordner verschoben oder Berechtigung entzogen):
            // Sync anhalten, lokale Daten bleiben unangetastet.
            configuration.isEnabled = false
            configuration.locationBookmark = nil
            hasUnpushedLocalChanges = false
            saveConfiguration()
            stopTimers()
            errorMessage = "Der Zugriff auf den Sync-Ordner ist verloren gegangen (verschoben oder gelöscht?). Die Synchronisation wurde angehalten – deine Daten sind unverändert. Verknüpfe den Ordner einfach erneut."
        }
    }

    /// Liest alle Dokumente des Ordners (kleine JSON-Dateien).
    private func readRemoteDocuments(from folder: URL) throws -> [String: FolderSyncDocument] {
        let manager = FileManager.default
        var result: [String: FolderSyncDocument] = [:]

        let settingsURL = folder.appendingPathComponent("settings.json")
        if let data = try? Data(contentsOf: settingsURL) {
            let modified = (try? settingsURL.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate ?? Date()
            let stamp = FolderSyncDocuments.updatedAt(forData: data) ?? modified
            result[FolderSyncDocument.settingsKey] = FolderSyncDocument(
                key: FolderSyncDocument.settingsKey,
                updatedAt: stamp,
                data: data
            )
        }

        let notesFolder = folder.appendingPathComponent(Self.notesSubdirectory, isDirectory: true)
        guard let files = try? manager.contentsOfDirectory(
            at: notesFolder,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return result
        }

        for fileURL in files where fileURL.pathExtension.lowercased() == "json" {
            guard let data = try? Data(contentsOf: fileURL),
                  let stamp = FolderSyncDocuments.updatedAt(forData: data) else { continue }
            // Der Schlüssel steckt im Dokument; der Dateiname ist nur Ablage.
            guard let noteKey = FolderSyncDocuments.noteKey(fromData: data) else { continue }
            result[noteKey] = FolderSyncDocument(key: noteKey, updatedAt: stamp, data: data)
        }
        return result
    }

    /// Liest nur die Schlüssel der Notiz-Dateien.
    private func readRemoteKeys(from folder: URL) throws -> Set<String> {
        let documents = try readRemoteDocuments(from: folder)
        return Set(documents.keys.filter { $0 != FolderSyncDocument.settingsKey })
    }

    /// Schreibt geänderte Dokumente und entfernt gelöschte Dateien.
    private func writeDocuments(
        _ documents: [FolderSyncDocument],
        deleting: [String],
        in folder: URL
    ) throws {
        let manager = FileManager.default
        let notesFolder = folder.appendingPathComponent(Self.notesSubdirectory, isDirectory: true)
        try manager.createDirectory(at: notesFolder, withIntermediateDirectories: true)

        for document in documents {
            let url: URL
            if document.isSettings {
                url = folder.appendingPathComponent("settings.json")
            } else {
                url = notesFolder.appendingPathComponent(
                    "\(FolderSyncDocument.safeFileName(for: document.key)).json"
                )
            }
            try document.data.write(to: url, options: .atomic)
        }

        for key in deleting {
            let url = notesFolder.appendingPathComponent(
                "\(FolderSyncDocument.safeFileName(for: key)).json"
            )
            try? manager.removeItem(at: url)
        }
    }

    /// Schreibt den kompletten lokalen Stand in den Ordner (Ersteinrichtung).
    private func writeLocalDocuments(_ backup: AppBackup) async {
        guard let folder = try? resolveSyncFolder() else { return }
        let accessing = folder.startAccessingSecurityScopedResource()
        defer { if accessing { folder.stopAccessingSecurityScopedResource() } }
        let documents = FolderSyncDocuments.documents(
            from: backup,
            settingsUpdatedAt: Date()
        )
        settingsUpdatedAt = Date()
        try? writeDocuments(documents, deleting: [], in: folder)
        configuration.knownRemoteKeys = Set(documents.map(\.key).filter { $0 != FolderSyncDocument.settingsKey })
        remoteNoteCount = configuration.knownRemoteKeys.count
    }

    // MARK: - Grabsteine (gelöschte Notizen)

    public func recordDeletedNote(id: String) {
        guard configuration.isEnabled else { return }
        configuration.deletedNoteIDs[id] = Date()
        saveConfiguration()
        markLocalDirty()
    }

    public func recordDeletedNotes(ids: [String]) {
        guard configuration.isEnabled, !ids.isEmpty else { return }
        let now = Date()
        for id in ids {
            configuration.deletedNoteIDs[id] = now
        }
        saveConfiguration()
        markLocalDirty()
    }

    /// Vergisst alle gelöschten Notizen. Wird nach einem manuellen Import
    /// aufgerufen: Der Import ist die neue Wahrheit, alte Löschungen dürfen
    /// importierte Notizen nicht wieder entfernen.
    public func clearTombstones() {
        configuration.deletedNoteIDs.removeAll()
        saveConfiguration()
    }

    // MARK: - Sicherheitskopien

    private func storeSafetyBackup(for local: AppBackup) {
        guard let text = try? AppBackupCodec.encode(local) else { return }
        let backup = FileSyncSafetyBackup(
            text: text,
            noteCount: local.notes.filter(\.hasVisibleContent).count
        )
        var all = [backup] + safetyBackups
        all = Array(all.prefix(Self.maximumSafetyBackups))
        safetyBackups = all
        storage.saveFileSyncSafetyBackups(all)
    }

    /// Stellt eine Sicherheitskopie wieder her und sendet sie in den Ordner.
    public func restoreSafetyBackup(_ backup: FileSyncSafetyBackup) -> String {
        guard let decoded = try? AppBackupCodec.decode(backup.text) else {
            return "Diese Sicherheitskopie ist beschädigt und konnte nicht wiederhergestellt werden."
        }
        // Vor dem Wiederherstellen den aktuellen Stand sichern – auch das
        // Zurückholen darf nichts vernichten.
        if let local = makeLocalBackup?() {
            storeSafetyBackup(for: local)
        }
        applyBackup?(decoded)
        settingsUpdatedAt = Date()
        hasUnpushedLocalChanges = true
        saveConfiguration()
        schedulePush()
        return "Sicherheitskopie wiederhergestellt (\(decoded.notes.filter(\.hasVisibleContent).count) Notizen)."
    }

    public func deleteSafetyBackup(id: UUID) {
        safetyBackups.removeAll { $0.id == id }
        storage.saveFileSyncSafetyBackups(safetyBackups)
    }

    // MARK: - iCloud-Prüfung

    /// Prüft bestmöglich, ob eine URL in iCloud Drive liegt. Der Pfad-Test
    /// greift immer; `isUbiquitousItem` bestätigt zusätzlich, wo verfügbar.
    public static func isICloudDriveURL(_ url: URL) -> Bool {
        let path = url.path
        if path.contains("com~apple~CloudDocs") || path.contains("Mobile Documents") {
            return true
        }
        return FileManager.default.isUbiquitousItem(at: url)
    }

    // MARK: - Meldungen

    private func showStatus(_ message: String) {
        statusMessage = message
        statusClearWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in
                self?.statusMessage = nil
            }
        }
        statusClearWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 8, execute: item)
    }

    public func clearMessages() {
        statusMessage = nil
        errorMessage = nil
    }
}
