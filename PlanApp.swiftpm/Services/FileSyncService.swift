import Foundation
import Combine
import CryptoKit

/// Konfiguration der Datei-Synchronisation über iCloud Drive.
///
/// Die App besitzt (Swift Playgrounds / Sideloadly) keine iCloud-Berechtigung
/// und kann deshalb kein CloudKit nutzen. Stattdessen wählt man einmalig eine
/// Textdatei in iCloud Drive (oder einen Ordner dafür) über die
/// Dateien-Auswahl. iCloud Drive hält diese Datei auf allen Geräten aktuell;
/// diese Klasse schreibt den lokalen Stand hinein und übernimmt fremde
/// Stände – zusammengeführt, nicht überschrieben, sodass keine Daten
/// verloren gehen.
public struct FileSyncConfiguration: Codable, Equatable {
    /// Ob die Synchronisation aktiv ist (Standard: aus).
    public var isEnabled: Bool
    /// Sicherheits-B Bookmark (mit Zugriffsrecht) auf die Sync-Datei oder –
    /// bei „neue Datei anlegen“ – auf den gewählten Ordner.
    public var locationBookmark: Data?
    /// `true`, wenn das Bookmark einen Ordner (statt der Datei direkt) meint.
    public var locationIsDirectory: Bool
    /// Dateiname der Sync-Datei.
    public var fileName: String
    /// Stabile Kennung dieses Geräts (für Diagnose-Zwecke).
    public var deviceID: String
    /// Semantischer Hash des zuletzt synchronisierten Stands (ohne
    /// Erstelldatum). Verhindert sinnlose Schreib-/Lese-Schleifen.
    public var lastSyncedHash: String?
    /// Zeitpunkt der letzten erfolgreichen Synchronisation.
    public var lastSyncDate: Date?
    /// Gelöschte Notizen (Notiz-ID → Löschdatum). Ohne diese „Grabsteine“
    /// würde eine anderswo noch vorhandene Notiz eine lokale Löschung beim
    /// Zusammenführen wieder auferstehen lassen.
    public var deletedNoteIDs: [String: Date]

    public init(
        isEnabled: Bool = false,
        locationBookmark: Data? = nil,
        locationIsDirectory: Bool = false,
        fileName: String = FileSyncService.defaultFileName,
        deviceID: String = UUID().uuidString,
        lastSyncedHash: String? = nil,
        lastSyncDate: Date? = nil,
        deletedNoteIDs: [String: Date] = [:]
    ) {
        self.isEnabled = isEnabled
        self.locationBookmark = locationBookmark
        self.locationIsDirectory = locationIsDirectory
        self.fileName = fileName
        self.deviceID = deviceID
        self.lastSyncedHash = lastSyncedHash
        self.lastSyncDate = lastSyncDate
        self.deletedNoteIDs = deletedNoteIDs
    }

    private enum CodingKeys: String, CodingKey {
        case isEnabled, locationBookmark, locationIsDirectory, fileName
        case deviceID, lastSyncedHash, lastSyncDate, deletedNoteIDs
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? false
        locationBookmark = try container.decodeIfPresent(Data.self, forKey: .locationBookmark)
        locationIsDirectory = try container.decodeIfPresent(Bool.self, forKey: .locationIsDirectory) ?? false
        fileName = try container.decodeIfPresent(String.self, forKey: .fileName) ?? FileSyncService.defaultFileName
        deviceID = try container.decodeIfPresent(String.self, forKey: .deviceID) ?? UUID().uuidString
        lastSyncedHash = try container.decodeIfPresent(String.self, forKey: .lastSyncedHash)
        lastSyncDate = try container.decodeIfPresent(Date.self, forKey: .lastSyncDate)
        deletedNoteIDs = try container.decodeIfPresent([String: Date].self, forKey: .deletedNoteIDs) ?? [:]
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

/// Ergebnis des Verknüpfens mit einer Sync-Datei.
public enum FileSyncLinkOutcome {
    /// Verknüpft und aktiv – mit Beschreibung dessen, was übernommen wurde.
    case linked(message: String)
    /// Abgebrochen, mit Begründung. Es wurde nichts verändert.
    case failed(message: String)
}

/// Reine Zusammenführungs-Logik zweier Sicherungen (lokal + Datei).
///
/// *Notizen* werden pro Notiz zusammengeführt (neuer gewinnt, beide Seiten
/// bleiben erhalten); alles andere (Stundenplan, Einstellungen, Tags, …)
/// übernimmt den neueren Gesamtstand. Gelöschte Notizen (Grabsteine) stehen
/// nicht wieder auf – außer sie wurden nach dem Löschen anderswo bearbeitet,
/// dann gewinnt die Bearbeitung (kein Datenverlust).
public enum FileSyncMerge {
    public static func merge(
        local: AppBackup,
        remote: AppBackup,
        deletedNoteIDs: [String: Date]
    ) -> AppBackup {
        let remoteIsNewer = remote.createdAt > local.createdAt

        var notesByID: [String: LessonNote] = [:]
        for note in local.notes {
            notesByID[note.id] = note
        }
        for note in remote.notes {
            if let existing = notesByID[note.id] {
                notesByID[note.id] = note.updatedAt > existing.updatedAt ? note : existing
            } else {
                notesByID[note.id] = note
            }
        }
        // Grabsteine anwenden: Eine Notiz, die nach ihrer letzten Änderung
        // gelöscht wurde, bleibt gelöscht.
        let mergedNotes = notesByID.values.filter { note in
            guard let deletedAt = deletedNoteIDs[note.id] else { return true }
            return note.updatedAt > deletedAt
        }

        let base = remoteIsNewer ? remote : local
        return AppBackup(
            createdAt: Date(),
            credentials: base.credentials,
            subjectCustomizations: base.subjectCustomizations,
            teacherNameCustomizations: base.teacherNameCustomizations,
            displaySettings: base.displaySettings,
            drawingSettings: base.drawingSettings,
            periods: base.periods,
            lessons: base.lessons,
            notes: mergedNotes.sorted { $0.id < $1.id },
            viewMode: base.viewMode,
            appearance: base.appearance,
            tagSettings: base.tagSettings
        )
    }

    /// Stabiler Hash über den *inhaltlichen* Stand (ohne Erstelldatum).
    /// Zwei Sicherungen mit gleichem Hash sind inhaltlich identisch – egal
    /// auf welchem Gerät und wann sie erzeugt wurden.
    public static func semanticHash(_ backup: AppBackup) -> String {
        var copy = backup
        copy.createdAt = Date(timeIntervalSince1970: 0)
        copy.notes.sort { $0.id < $1.id }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(copy) else { return UUID().uuidString }
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    public static func backupsSemanticallyEqual(_ lhs: AppBackup, _ rhs: AppBackup) -> Bool {
        semanticHash(lhs) == semanticHash(rhs)
    }
}

/// Datei-Synchronisation über eine vom Nutzer gewählte Textdatei in
/// iCloud Drive.
///
/// Robustheit im Überblick:
/// - Es wird nie blind überschrieben: Fremde Stände werden **zusammengeführt**.
/// - Vor jeder Übernahme wird der lokale Stand als Sicherheitskopie behalten.
/// - Ungültige oder fremde Datei-Inhalte werden nie übernommen und nie
///   stillschweigend überschrieben.
/// - Verschwindet die Datei, wird sie aus dem lokalen Stand neu erstellt.
/// - Zugriffsprobleme melden sich als Fehler; lokale Daten bleiben immer unangetastet.
@MainActor
public final class FileSyncService: ObservableObject {
    // Diese Konstanten sind bewusst `nonisolated`: Sie werden auch aus
    // nicht-isolierten Zusammenhängen gelesen (Standardwerte im Decoder von
    // `FileSyncConfiguration` und der Speicher-Service). Ohne das wären sie
    // im Swift-6-Sprachmodus von Swift Playgrounds nicht erreichbar.
    nonisolated public static let defaultFileName = "PlanApp-Sync.txt"
    nonisolated public static let maximumSafetyBackups = 3
    /// Wartezeit nach der letzten lokalen Änderung, bevor geschrieben wird.
    nonisolated public static let pushDebounceInterval: TimeInterval = 2.5
    /// Wie oft die Datei auf fremde Änderungen geprüft wird.
    nonisolated public static let pullInterval: TimeInterval = 15
    /// Grabsteine älter als 30 Tage werden entsorgt.
    nonisolated private static let tombstoneLifetime: TimeInterval = 30 * 24 * 3600

    @Published public private(set) var configuration = FileSyncConfiguration()
    /// Kurze Erfolgs-/Statusmeldung für die Einstellungen.
    @Published public private(set) var statusMessage: String? = nil
    /// Aktuelle Fehlermeldung (`nil` = alles in Ordnung).
    @Published public private(set) var errorMessage: String? = nil
    /// Ob gerade gelesen oder geschrieben wird.
    @Published public private(set) var isWorking = false
    @Published public private(set) var safetyBackups: [FileSyncSafetyBackup] = []

    /// Erzeugt die aktuelle lokale Sicherung (vom ViewModel gesetzt).
    public var makeLocalBackup: (() -> AppBackup?)?
    /// Übernimmt eine Sicherung (vom ViewModel gesetzt).
    public var applyBackup: ((AppBackup) -> Void)?

    public var isEnabled: Bool { configuration.isEnabled }

    public var syncFileDisplayName: String {
        configuration.fileName.isEmpty ? Self.defaultFileName : configuration.fileName
    }

    public var lastSyncDescription: String? {
        guard let date = configuration.lastSyncDate else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private let storage = TimetableStorageService.shared
    private var pullTimer: AnyCancellable? = nil
    private var pushWorkItem: DispatchWorkItem? = nil
    private var hasUnpushedLocalChanges = false
    private var statusClearWorkItem: DispatchWorkItem? = nil

    public init() {
        self.configuration = storage.loadFileSyncConfiguration()
        // Ohne gespeicherten Ort kann die Sync nicht aktiv sein (z. B. nach
        // einem Import, der die Konfiguration nicht mitnahm).
        if configuration.isEnabled, configuration.locationBookmark == nil {
            configuration.isEnabled = false
            storage.saveFileSyncConfiguration(configuration)
        }
        self.safetyBackups = storage.loadFileSyncSafetyBackups()
        if configuration.isEnabled {
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
        pruneTombstones()
        storage.saveFileSyncConfiguration(configuration)
    }

    private func pruneTombstones() {
        let cutoff = Date().addingTimeInterval(-Self.tombstoneLifetime)
        configuration.deletedNoteIDs = configuration.deletedNoteIDs.filter { $0.value > cutoff }
    }

    // MARK: - Lokale Änderungen melden

    /// Das ViewModel ruft das nach jeder lokalen Datenänderung auf. Der
    /// Schreibvorgang läuft entprellt, damit z. B. schnelles Notieren nicht
    /// bei jedem Strich in die Datei schreibt.
    public func markLocalDirty() {
        guard configuration.isEnabled else { return }
        hasUnpushedLocalChanges = true
        schedulePush()
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

    /// Legt eine neue Sync-Datei im gewählten Ordner an und aktiviert die
    /// Synchronisation. Der Ordner muss in iCloud Drive liegen.
    public func linkNewFile(in folderURL: URL) async -> FileSyncLinkOutcome {
        clearMessages()
        guard Self.isICloudDriveURL(folderURL) else {
            return .failed(message: "Bitte wähle einen Ordner in iCloud Drive (z. B. unter „iCloud Drive“ in der Dateien-App), damit alle Geräte dieselbe Datei sehen.")
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

            let fileName = try await uniqueFileName(in: folderURL, base: Self.defaultFileName)
            let fileURL = folderURL.appendingPathComponent(fileName)
            let text = try AppBackupCodec.encode(local)
            try await writeText(text, to: fileURL)

            configuration.isEnabled = true
            configuration.locationBookmark = bookmark
            configuration.locationIsDirectory = true
            configuration.fileName = fileName
            configuration.lastSyncedHash = FileSyncMerge.semanticHash(local)
            configuration.lastSyncDate = Date()
            hasUnpushedLocalChanges = false
            saveConfiguration()
            startTimers()

            let message = "Sync-Datei „\(fileName)“ in iCloud Drive angelegt und aktiviert."
            showStatus(message)
            return .linked(message: message)
        } catch {
            return .failed(message: "Die Datei konnte nicht angelegt werden: \(error.localizedDescription)")
        }
    }

    /// Verknüpft eine bestehende Sync-Datei und aktiviert die Synchronisation.
    /// Leere Dateien werden mit dem lokalen Stand initialisiert; gültige
    /// Sicherungen werden mit dem lokalen Stand **zusammengeführt**. Fremde
    /// Inhalte werden nie angerührt.
    public func linkExistingFile(at fileURL: URL) async -> FileSyncLinkOutcome {
        clearMessages()
        guard Self.isICloudDriveURL(fileURL) else {
            return .failed(message: "Bitte wähle eine Textdatei in iCloud Drive (z. B. unter „iCloud Drive“ in der Dateien-App), damit alle Geräte dieselbe Datei sehen.")
        }
        guard let local = makeLocalBackup?() else {
            return .failed(message: "Die lokalen Daten konnten nicht gelesen werden.")
        }
        isWorking = true
        defer { isWorking = false }

        let accessing = fileURL.startAccessingSecurityScopedResource()
        defer { if accessing { fileURL.stopAccessingSecurityScopedResource() } }

        do {
            guard let bookmark = try? fileURL.bookmarkData() else {
                return .failed(message: "Auf diese Datei konnte kein dauerhafter Zugriff gespeichert werden. Bitte wähle sie erneut.")
            }

            let existingText = try await readText(from: fileURL)
            let trimmed = (existingText ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmed.isEmpty {
                // Leere Datei: mit dem lokalen Stand initialisieren.
                let text = try AppBackupCodec.encode(local)
                try await writeText(text, to: fileURL)
                activateWithBookmark(
                    bookmark,
                    isDirectory: false,
                    fileName: fileURL.lastPathComponent,
                    syncedHash: FileSyncMerge.semanticHash(local)
                )
                let message = "Datei war leer und wurde mit deinen aktuellen Daten gefüllt. Synchronisation ist aktiv."
                showStatus(message)
                return .linked(message: message)
            }

            guard AppBackupCodec.looksLikeBackup(trimmed) else {
                return .failed(message: "Diese Datei enthält keine PlanApp-Sicherung und wurde nicht verändert. Bitte wähle die Sync-Datei („\(Self.defaultFileName)“) oder lege eine neue an.")
            }
            guard let remote = try? AppBackupCodec.decode(trimmed) else {
                return .failed(message: "Diese Datei konnte nicht gelesen werden (evtl. unvollständig synchronisiert). Bitte warte kurz, bis iCloud Drive sie vollständig geladen hat, und versuche es erneut.")
            }

            // Zusammenführen statt überschreiben – mit Sicherheitskopie.
            let merged = FileSyncMerge.merge(
                local: local,
                remote: remote,
                deletedNoteIDs: configuration.deletedNoteIDs
            )
            storeSafetyBackup(for: local)
            let mergedText = try AppBackupCodec.encode(merged)
            try await writeText(mergedText, to: fileURL)
            applyBackup?(merged)
            pruneTombstonesAgainstMergedNotes(merged.notes)
            activateWithBookmark(
                bookmark,
                isDirectory: false,
                fileName: fileURL.lastPathComponent,
                syncedHash: FileSyncMerge.semanticHash(merged)
            )

            let localNotes = local.notes.filter(\.hasVisibleContent).count
            let remoteNotes = remote.notes.filter(\.hasVisibleContent).count
            let mergedNotes = merged.notes.filter(\.hasVisibleContent).count
            let message = "Verbunden und zusammengeführt: \(localNotes) eigene + \(remoteNotes) aus der Datei = \(mergedNotes) Notizen. Es geht nichts verloren."
            showStatus(message)
            return .linked(message: message)
        } catch {
            return .failed(message: "Die Datei konnte nicht gelesen werden: \(error.localizedDescription)")
        }
    }

    private func activateWithBookmark(
        _ bookmark: Data,
        isDirectory: Bool,
        fileName: String,
        syncedHash: String
    ) {
        configuration.isEnabled = true
        configuration.locationBookmark = bookmark
        configuration.locationIsDirectory = isDirectory
        configuration.fileName = fileName
        configuration.lastSyncedHash = syncedHash
        configuration.lastSyncDate = Date()
        hasUnpushedLocalChanges = false
        errorMessage = nil
        saveConfiguration()
        startTimers()
    }

    /// Trennt die Verknüpfung. Lokale Daten und die Datei bleiben erhalten –
    /// es wird danach nur nicht mehr automatisch synchronisiert.
    public func unlink() {
        stopTimers()
        pushWorkItem?.cancel()
        pushWorkItem = nil
        configuration.isEnabled = false
        configuration.locationBookmark = nil
        configuration.lastSyncedHash = nil
        configuration.lastSyncDate = nil
        hasUnpushedLocalChanges = false
        saveConfiguration()
        showStatus("Synchronisation getrennt. Deine Daten und die Datei bleiben erhalten.")
    }

    // MARK: - Schreiben (Push)

    /// Schreibt den lokalen Stand in die Datei – aber nur, wenn er sich
    /// inhaltlich vom zuletzt synchronisierten Stand unterscheidet.
    public func pushNow() async {
        guard configuration.isEnabled, !isWorking else { return }
        guard hasUnpushedLocalChanges else { return }
        guard let local = makeLocalBackup?() else { return }

        let hash = FileSyncMerge.semanticHash(local)
        if hash == configuration.lastSyncedHash {
            hasUnpushedLocalChanges = false
            return
        }

        isWorking = true
        defer { isWorking = false }
        do {
            let fileURL = try resolveSyncFileURL(allowingDirectory: true)
            let accessing = fileURL.base.startAccessingSecurityScopedResource()
            defer { if accessing { fileURL.base.stopAccessingSecurityScopedResource() } }
            let text = try AppBackupCodec.encode(local)
            try await writeText(text, to: fileURL.file)
            configuration.lastSyncedHash = hash
            configuration.lastSyncDate = Date()
            hasUnpushedLocalChanges = false
            errorMessage = nil
            saveConfiguration()
        } catch let error as FileSyncAccessError {
            handleAccessError(error)
        } catch {
            errorMessage = "Schreiben fehlgeschlagen: \(error.localizedDescription)"
        }
    }

    // MARK: - Lesen (Pull)

    /// Holt den Stand aus der Datei und führt ihn mit dem lokalen Stand
    /// zusammen. Wird regelmäßig automatisch sowie beim Öffnen der App
    /// aufgerufen.
    public func pullNow() async {
        guard configuration.isEnabled, !isWorking else { return }
        guard let local = makeLocalBackup?() else { return }

        isWorking = true
        defer { isWorking = false }
        do {
            let fileURL = try resolveSyncFileURL(allowingDirectory: true)
            let accessing = fileURL.base.startAccessingSecurityScopedResource()
            defer { if accessing { fileURL.base.stopAccessingSecurityScopedResource() } }

            resolveVersionConflictsIfNeeded(at: fileURL.file)

            guard let text = try await readText(from: fileURL.file) else {
                // Datei verschwunden (gelöscht/verschoben): aus dem lokalen
                // Stand neu erstellen – nichts geht verloren.
                let fresh = try AppBackupCodec.encode(local)
                try await writeText(fresh, to: fileURL.file)
                configuration.lastSyncedHash = FileSyncMerge.semanticHash(local)
                configuration.lastSyncDate = Date()
                hasUnpushedLocalChanges = false
                errorMessage = nil
                saveConfiguration()
                return
            }

            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            guard AppBackupCodec.looksLikeBackup(trimmed),
                  let remote = try? AppBackupCodec.decode(trimmed) else {
                // Fremder/ungültiger Inhalt: Datei in Ruhe lassen, lokalen
                // Stand behalten und nur melden.
                errorMessage = "Die Sync-Datei enthält zurzeit keine gültige Sicherung und wurde nicht übernommen. Sie wird beim nächsten Schreiben repariert."
                return
            }

            let remoteHash = FileSyncMerge.semanticHash(remote)
            if remoteHash == configuration.lastSyncedHash {
                // Kein fremder Stand – aber evtl. eigene, noch ungesendete
                // Änderungen nachholen.
                errorMessage = nil
                if hasUnpushedLocalChanges {
                    let localHash = FileSyncMerge.semanticHash(local)
                    if localHash != configuration.lastSyncedHash {
                        let fresh = try AppBackupCodec.encode(local)
                        try await writeText(fresh, to: fileURL.file)
                        configuration.lastSyncedHash = localHash
                        configuration.lastSyncDate = Date()
                        hasUnpushedLocalChanges = false
                        saveConfiguration()
                    } else {
                        hasUnpushedLocalChanges = false
                    }
                }
                return
            }

            // Fremder Stand vorhanden → zusammenführen, Sicherheitskopie
            // anlegen, übernehmen und zurückschreiben (damit alle Geräte
            // konvergieren).
            let merged = FileSyncMerge.merge(
                local: local,
                remote: remote,
                deletedNoteIDs: configuration.deletedNoteIDs
            )
            let mergedHash = FileSyncMerge.semanticHash(merged)
            let localHash = FileSyncMerge.semanticHash(local)
            if mergedHash == localHash {
                // Die Zusammenführung ändert lokal nichts (z. B. nur ältere
                // Stände) – dann nur den Hash merken.
                configuration.lastSyncedHash = mergedHash
                configuration.lastSyncDate = Date()
                saveConfiguration()
                return
            }

            storeSafetyBackup(for: local)
            applyBackup?(merged)
            pruneTombstonesAgainstMergedNotes(merged.notes)
            let mergedText = try AppBackupCodec.encode(merged)
            try await writeText(mergedText, to: fileURL.file)
            configuration.lastSyncedHash = mergedHash
            configuration.lastSyncDate = Date()
            hasUnpushedLocalChanges = false
            errorMessage = nil
            saveConfiguration()
        } catch let error as FileSyncAccessError {
            handleAccessError(error)
        } catch {
            errorMessage = "Lesen fehlgeschlagen: \(error.localizedDescription)"
        }
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

    /// Grabsteine entsorgen, deren Notiz in der Zusammenführung mit neuerer
    /// Änderung wieder da ist (Bearbeitung gewinnt über Löschung).
    private func pruneTombstonesAgainstMergedNotes(_ notes: [LessonNote]) {
        for note in notes {
            if let deletedAt = configuration.deletedNoteIDs[note.id], note.updatedAt > deletedAt {
                configuration.deletedNoteIDs.removeValue(forKey: note.id)
            }
        }
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

    /// Stellt eine Sicherheitskopie wieder her und sendet sie an die Datei.
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
        configuration.lastSyncedHash = nil
        hasUnpushedLocalChanges = true
        saveConfiguration()
        schedulePush()
        return "Sicherheitskopie wiederhergestellt (\(decoded.notes.filter(\.hasVisibleContent).count) Notizen)."
    }

    public func deleteSafetyBackup(id: UUID) {
        safetyBackups.removeAll { $0.id == id }
        storage.saveFileSyncSafetyBackups(safetyBackups)
    }

    // MARK: - Datei-Zugriff

    private struct ResolvedSyncFile {
        /// URL, auf die der Sicherheits-Zugriff gestartet wurde.
        let base: URL
        /// Eigentliche Sync-Datei.
        let file: URL
    }

    private enum FileSyncAccessError: Error {
        case noBookmark
        case bookmarkInvalid
    }

    private func resolveSyncFileURL(allowingDirectory: Bool) throws -> ResolvedSyncFile {
        guard let bookmark = configuration.locationBookmark else {
            throw FileSyncAccessError.noBookmark
        }
        var isStale = false
        // iOS liefert den Sicherheits-Zugriff bereits über das Bookmark selbst;
        // die Option `.withSecurityScope` ist nur auf dem Mac verfügbar.
        guard let url = try? URL(
            resolvingBookmarkData: bookmark,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            throw FileSyncAccessError.bookmarkInvalid
        }
        if isStale {
            // Abgelaufenes Bookmark auffrischen, damit der Zugriff erhalten bleibt.
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            if let fresh = try? url.bookmarkData() {
                configuration.locationBookmark = fresh
                saveConfiguration()
            }
        }
        if configuration.locationIsDirectory, allowingDirectory {
            let file = url.appendingPathComponent(syncFileDisplayName)
            return ResolvedSyncFile(base: url, file: file)
        }
        return ResolvedSyncFile(base: url, file: url)
    }

    private func handleAccessError(_ error: FileSyncAccessError) {
        switch error {
        case .noBookmark, .bookmarkInvalid:
            // Zugriff verloren (Datei/Ordner verschoben oder Berechtigung
            // entzogen): Sync anhalten, lokale Daten bleiben unangetastet.
            configuration.isEnabled = false
            configuration.locationBookmark = nil
            configuration.lastSyncedHash = nil
            hasUnpushedLocalChanges = false
            saveConfiguration()
            stopTimers()
            errorMessage = "Der Zugriff auf die Sync-Datei ist verloren gegangen (verschoben oder gelöscht?). Die Synchronisation wurde angehalten – deine Daten sind unverändert. Verknüpfe die Datei einfach erneut."
        }
    }

    private func uniqueFileName(in folder: URL, base: String) async throws -> String {
        try await performIO {
            let manager = FileManager.default
            let stem = (base as NSString).deletingPathExtension
            let ext = (base as NSString).pathExtension
            var candidate = base
            var counter = 2
            while manager.fileExists(atPath: folder.appendingPathComponent(candidate).path) {
                candidate = "\(stem) \(counter).\(ext)"
                counter += 1
                if counter > 100 { break }
            }
            return candidate
        }
    }

    private func readText(from url: URL) async throws -> String? {
        try await performIO {
            let coordinator = NSFileCoordinator()
            var coordinationError: NSError?
            var result: String?
            var readError: Error?
            var didRead = false
            coordinator.coordinate(readingItemAt: url, options: .withoutChanges, error: &coordinationError) { readURL in
                do {
                    let data = try Data(contentsOf: readURL)
                    result = String(data: data, encoding: .utf8)
                    didRead = true
                } catch {
                    let code = (error as NSError).code
                    if code == NSFileReadNoSuchFileError {
                        result = nil
                        didRead = true
                    } else {
                        readError = error
                    }
                }
            }
            if let coordinationError {
                // Datei existiert schlicht nicht → als „verschwunden“ melden.
                if (coordinationError as NSError).code == NSFileReadNoSuchFileError, !didRead {
                    return nil
                }
                throw coordinationError
            }
            if let readError { throw readError }
            return result
        }
    }

    private func writeText(_ text: String, to url: URL) async throws {
        guard let data = text.data(using: .utf8) else {
            throw CocoaError(.fileWriteInapplicableStringEncoding)
        }
        try await performIO {
            let coordinator = NSFileCoordinator()
            var coordinationError: NSError?
            var writeError: Error?
            let exists = FileManager.default.fileExists(atPath: url.path)
            coordinator.coordinate(
                writingItemAt: url,
                options: exists ? .forReplacing : [],
                error: &coordinationError
            ) { writeURL in
                do {
                    try data.write(to: writeURL, options: .atomic)
                } catch {
                    writeError = error
                }
            }
            if let coordinationError { throw coordinationError }
            if let writeError { throw writeError }
        }
    }

    /// iCloud Drive hat bei gleichzeitigem Schreiben zwei Fassungen angelegt:
    /// alle Fassungen einsammeln und zu einer zusammenführen. Schlägt das
    /// fehl, läuft die normale Zusammenführung weiter – es geht nie etwas still verloren.
    private func resolveVersionConflictsIfNeeded(at url: URL) {
        guard let conflicts = try? NSFileVersion.unresolvedConflictVersionsOfItem(at: url),
              !conflicts.isEmpty,
              let local = makeLocalBackup?() else {
            return
        }
        var merged = local
        var mergedAnything = false
        for version in conflicts {
            guard let data = try? Data(contentsOf: version.url),
                  let text = String(data: data, encoding: .utf8),
                  let backup = try? AppBackupCodec.decode(text.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                continue
            }
            merged = FileSyncMerge.merge(local: merged, remote: backup, deletedNoteIDs: configuration.deletedNoteIDs)
            mergedAnything = true
        }
        guard mergedAnything else { return }
        storeSafetyBackup(for: local)
        applyBackup?(merged)
        pruneTombstonesAgainstMergedNotes(merged.notes)
        if let text = try? AppBackupCodec.encode(merged) {
            try? text.data(using: .utf8)?.write(to: url, options: .atomic)
        }
        for version in conflicts {
            version.isResolved = true
        }
        do {
            try NSFileVersion.removeOtherVersionsOfItem(at: url)
        } catch {
            // Harmlos: Die Konfliktfassung bleibt dann als Datei bestehen.
        }
        configuration.lastSyncedHash = FileSyncMerge.semanticHash(merged)
        configuration.lastSyncDate = Date()
        saveConfiguration()
    }

    /// Führt Datei-Arbeit nebenläufig aus. Die Abschluss-Bedingungen
    /// (`Sendable`) sind nötig, weil `Task.detached` eine `@Sendable`-Closure
    /// verlangt – ohne sie würde der Swift-6-Sprachmodus den Aufruf ablehnen.
    private func performIO<T: Sendable>(_ work: @escaping @Sendable () throws -> T) async throws -> T {
        try await Task.detached(priority: .userInitiated) {
            try work()
        }.value
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
