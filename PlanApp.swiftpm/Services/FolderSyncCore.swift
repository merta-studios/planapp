import Foundation

/// Ein einzelner Datensatz im Sync-Ordner.
///
/// Der Ordner enthält **viele kleine Dateien** statt einer riesigen
/// Textdatei: `settings.json` für Stundenplan und Einstellungen sowie
/// `notes/<noteKey>.json` für jede Notiz. Jede Datei trägt eine
/// `updatedAt`-Zeitmarke, sodass beim Zusammenführen **pro Datensatz** der
/// neuere Stand gewinnt – genau so arbeiten professionelle Apps
/// (ein Dokument/Objekt pro Datei, keine gemeinsame Monolith-Datei).
///
/// Der Schlüssel ist die Notiz-ID (bzw. `settings`) und enthält keine
/// Sonderzeichen mehr, damit er gefahrlos als Dateiname dient.
public struct FolderSyncDocument: Equatable, Sendable {
    /// Fester Schlüssel des Einstellungs-/Stundenplan-Dokuments.
    public static let settingsKey = "settings"

    public let key: String
    public var updatedAt: Date
    public var data: Data

    public init(key: String, updatedAt: Date, data: Data) {
        self.key = key
        self.updatedAt = updatedAt
        self.data = data
    }

    /// Dateiname im Sync-Ordner. Notiz-Schlüssel werden zu einem sicheren
    /// Namen normalisiert (nur `A–Z a–z 0–9 _ -`; alles andere wird `_`).
    public var fileName: String {
        let safe = FolderSyncDocument.safeFileName(for: key)
        return safe == FolderSyncDocument.settingsKey ? "settings.json" : "notes/\(safe).json"
    }

    /// Ob dieser Datensatz das Einstellungs-Dokument ist.
    public var isSettings: Bool {
        key == FolderSyncDocument.settingsKey
    }

    public static func safeFileName(for key: String) -> String {
        var result = ""
        for character in key.unicodeScalars {
            let isPlain = CharacterSet.alphanumerics.contains(character)
                || character == "_" || character == "-"
            result.append(isPlain ? Character(String(character)) : "_")
        }
        if result.isEmpty { result = "_" }
        // Sehr lange Schlüssel kürzen – der Hash hält sie eindeutig.
        if result.count > 80 {
            let prefix = String(result.prefix(60))
            result = prefix + "-" + shortHash(key)
        }
        return result
    }

    public static func shortHash(_ text: String) -> String {
        var hash: UInt64 = 1469598103934665603
        for byte in Data(text.utf8) {
            hash ^= UInt64(byte)
            hash = hash &* 1099511628211
        }
        return String(format: "%08llx", UInt32(truncatingIfNeeded: hash))
    }
}

/// Zustand eines Sync-Ordners nach einem Lese-/Schreibvorgang.
public struct FolderSyncDirectoryState: Equatable, Sendable {
    /// Alle gelesenen Dokumente, nach Schlüssel.
    public var documents: [String: FolderSyncDocument]
    /// Inhalts-Hash des Ordners (stabil, unabhängig vom Erstellungszeitpunkt
    /// der App-Sicherung). Nur zur Diagnose/Anzeige.
    public var contentHash: String

    public init(documents: [String: FolderSyncDocument], contentHash: String) {
        self.documents = documents
        self.contentHash = contentHash
    }
}

/// Ergebnis eines Zusammenführungs-Laufs zwischen lokalem Stand und Ordner.
public struct FolderSyncMergeResult: Equatable, Sendable {
    /// Dokumente, die in den Ordner geschrieben werden müssen.
    public var documentsToWrite: [FolderSyncDocument]
    /// Dokumente aus dem Ordner, die lokal übernommen werden müssen.
    public var incomingDocuments: [FolderSyncDocument]
    /// Notiz-Schlüssel, die lokal gelöscht werden müssen (im Ordner gelöscht,
    /// seither lokal unverändert).
    public var documentsToDeleteLocally: [String]
    /// Notiz-Schlüssel, deren Datei im Ordner gelöscht werden muss (lokal
    /// gelöscht – der Grabstein ist neuer als die Datei).
    public var documentsToDeleteRemotely: [String]

    public init(
        documentsToWrite: [FolderSyncDocument] = [],
        incomingDocuments: [FolderSyncDocument] = [],
        documentsToDeleteLocally: [String] = [],
        documentsToDeleteRemotely: [String] = []
    ) {
        self.documentsToWrite = documentsToWrite
        self.incomingDocuments = incomingDocuments
        self.documentsToDeleteLocally = documentsToDeleteLocally
        self.documentsToDeleteRemotely = documentsToDeleteRemotely
    }

    public var isEmpty: Bool {
        documentsToWrite.isEmpty
            && incomingDocuments.isEmpty
            && documentsToDeleteLocally.isEmpty
            && documentsToDeleteRemotely.isEmpty
    }

    /// Ob sich lokal etwas ändert.
    public var changesLocalState: Bool {
        !incomingDocuments.isEmpty || !documentsToDeleteLocally.isEmpty
    }

    /// Ob sich im Ordner etwas ändert.
    public var changesRemoteState: Bool {
        !documentsToWrite.isEmpty || !documentsToDeleteRemotely.isEmpty
    }
}

/// Reine Regeln für den Ordner-Sync – ohne Dateisystem, ohne UIKit.
///
/// Alle Funktionen sind deterministisch und ohne Seiteneffekte; damit laufen
/// sie in den Regressions-Tests und im App-Betrieb identisch.
public enum FolderSyncRules {
    /// Notiz-Dokumente werden mit dieser Zeitmarke versehen, wenn sie keine
    /// eigene (neuere) haben – sie ist der Zeitpunkt der Notiz.
    public static let tombstoneLifetime: TimeInterval = 30 * 24 * 3600

    /// Führt den lokalen Satz von Dokumenten mit dem Ordner zusammen.
    ///
    /// Entscheidungsregeln (pro Notiz, nie global – ein Konflikt betrifft
    /// deshalb höchstens eine Notiz):
    ///
    /// 1. **Grabstein vorhanden** (hier gelöscht): Ist die Datei im Ordner
    ///    neuer als die Löschung, wurde sie anderswo weiterbearbeitet – dann
    ///    gewinnt die Bearbeitung (kein Datenverlust). Sonst wird die Datei
    ///    im Ordner gelöscht.
    /// 2. **Datei im Ordner verschwunden**, die wir dort schon gesehen haben:
    ///    Wurde die Notiz hier seit dem letzten Abgleich nicht geändert, war
    ///    das eine Löschung auf dem anderen Gerät – sie wird übernommen.
    ///    Sonst gilt die lokale Bearbeitung und die Datei kommt zurück.
    /// 3. **Nur auf einer Seite vorhanden** → dorthin kopieren.
    /// 4. **Beidseitig vorhanden** → das neuere `updatedAt` gewinnt.
    ///
    /// Das Einstellungs-Dokument (`settings`) kennt keine Löschung: dort
    /// gewinnt ebenfalls der neuere Stand.
    public static func merge(
        local: [String: FolderSyncDocument],
        remote: [String: FolderSyncDocument],
        tombstones: [String: Date],
        remoteKnownKeys: Set<String>,
        lastSyncDate: Date?
    ) -> FolderSyncMergeResult {
        var result = FolderSyncMergeResult()

        var allKeys = Set(local.keys)
        allKeys.formUnion(remote.keys)
        allKeys.formUnion(remoteKnownKeys)
        allKeys.remove(FolderSyncDocument.settingsKey)

        // Toleranz für Zeitstempel: iCloud speichert Sekunden, die App
        // Bruchteile davon. Ohne Toleranz gälten Kopien als „neuer“.
        let tolerance: TimeInterval = 1

        for key in allKeys.sorted() {
            let localDocument = local[key]
            let remoteDocument = remote[key]

            // 1) Lokale Löschung (Grabstein).
            if let deletedAt = tombstones[key] {
                if let remoteDocument, remoteDocument.updatedAt > deletedAt.addingTimeInterval(tolerance) {
                    // Anderswo weiterbearbeitet → Notiz kommt zurück.
                    result.incomingDocuments.append(remoteDocument)
                } else if remoteDocument != nil {
                    result.documentsToDeleteRemotely.append(key)
                }
                continue
            }

            // 2) Datei im Ordner verschwunden.
            if remoteDocument == nil, remoteKnownKeys.contains(key) {
                if let localDocument,
                   let lastSyncDate,
                   localDocument.updatedAt <= lastSyncDate.addingTimeInterval(tolerance) {
                    // Seither lokal unverändert → die Löschung des anderen
                    // Geräts gilt.
                    result.documentsToDeleteLocally.append(key)
                } else if let localDocument {
                    // Lokal (nach dem letzten Abgleich) bearbeitet → wieder
                    // hochladen, statt die Bearbeitung zu verlieren.
                    result.documentsToWrite.append(localDocument)
                }
                continue
            }

            // 3) Nur auf einer Seite vorhanden.
            guard let localDocument else {
                if let remoteDocument { result.incomingDocuments.append(remoteDocument) }
                continue
            }
            guard let remoteDocument else {
                result.documentsToWrite.append(localDocument)
                continue
            }

            // 4) Beidseitig: der neuere Stand gewinnt.
            if localDocument.updatedAt > remoteDocument.updatedAt.addingTimeInterval(tolerance) {
                result.documentsToWrite.append(localDocument)
            } else if remoteDocument.updatedAt > localDocument.updatedAt.addingTimeInterval(tolerance) {
                result.incomingDocuments.append(remoteDocument)
            }
        }

        // Einstellungs-Dokument: gleiches Prinzip, aber ohne Löschungen.
        let localSettings = local[FolderSyncDocument.settingsKey]
        let remoteSettings = remote[FolderSyncDocument.settingsKey]
        switch (localSettings, remoteSettings) {
        case let (.some(localDocument), .some(remoteDocument)):
            if localDocument.updatedAt > remoteDocument.updatedAt.addingTimeInterval(tolerance) {
                result.documentsToWrite.append(localDocument)
            } else if remoteDocument.updatedAt > localDocument.updatedAt.addingTimeInterval(tolerance) {
                result.incomingDocuments.append(remoteDocument)
            }
        case let (.some(localDocument), .none):
            result.documentsToWrite.append(localDocument)
        case let (.none, .some(remoteDocument)):
            result.incomingDocuments.append(remoteDocument)
        case (.none, .none):
            break
        }

        return result
    }

    /// Ob ein Ordner-Dokument einen Grabstein auflöst (die Notiz wurde
    /// anderswo wieder bearbeitet) – dann darf der Grabstein weg.
    public static func tombstoneResolved(
        _ tombstone: Date,
        by document: FolderSyncDocument
    ) -> Bool {
        document.updatedAt > tombstone
    }

    /// Entfernt abgelaufene Grabsteine.
    public static func prunedTombstones(
        _ tombstones: [String: Date],
        now: Date = Date(),
        lifetime: TimeInterval = tombstoneLifetime
    ) -> [String: Date] {
        let cutoff = now.addingTimeInterval(-lifetime)
        return tombstones.filter { $0.value > cutoff }
    }

    /// Ordnet Dateinamen wieder Notiz-Schlüsseln zu. Die Datei enthält den
    /// Schlüssel selbst – so ist ein umbenannter/abgeschnittener Dateiname
    /// unproblematisch.
    public static func documentKey(
        fileName: String,
        decodedKey: String?
    ) -> String {
        if let decodedKey, !decodedKey.isEmpty { return decodedKey }
        let base = (fileName as NSString).deletingPathExtension
        return base
    }

    /// Stabiler Inhalts-Hash (FNV-1a, 64 Bit) über alle Dokumente – nur für
    /// Anzeige/Diagnose. Bewusst ohne CryptoKit, damit die Regeln auch in den
    /// Linux-Regressionstests laufen.
    public static func contentHash(of documents: [String: FolderSyncDocument]) -> String {
        var hash: UInt64 = 1469598103934665603
        for key in documents.keys.sorted() {
            guard let document = documents[key] else { continue }
            hash = fnv1a(hash, Data(key.utf8))
            hash = fnv1a(hash, Data(":\(document.updatedAt.timeIntervalSince1970):".utf8))
            hash = fnv1a(hash, document.data)
        }
        return String(format: "%016llx", hash)
    }

    /// Inhalts-Hash beliebiger Daten.
    public static func contentHash(of data: Data) -> String {
        String(format: "%016llx", fnv1a(1469598103934665603, data))
    }

    private static func fnv1a(_ seed: UInt64, _ data: Data) -> UInt64 {
        var hash = seed
        for byte in data {
            hash ^= UInt64(byte)
            hash = hash &* 1099511628211
        }
        return hash
    }
}
