import Foundation
import UIKit
import PencilKit

/// Lazy-Loading Service für Notizen mit LRU-Cache
/// Lädt Notizen nur bei Bedarf und hält eine begrenzte Anzahl im Speicher
public final class NoteCacheService {
    public static let shared = NoteCacheService()
    
    private let storage = TimetableStorageService.shared
    private let cache = NoteValueCache<LessonNote>()
    private let metadataCache = NoteValueCache<NoteMetadata>()
    
    /// Maximale Anzahl von Notizen im Cache (basierend auf verfügbarem Speicher)
    private let maxCacheSize: Int = {
        let memoryMB = ProcessInfo.processInfo.physicalMemory / 1024 / 1024
        if memoryMB >= 4096 { return 100 }  // 4GB+ Geräte
        if memoryMB >= 2048 { return 50 }   // 2GB+ Geräte
        return 30                            // Ältere Geräte
    }()
    
    private init() {
        cache.countLimit = maxCacheSize
        cache.totalCostLimit = 100 * 1024 * 1024 // 100MB
    }
    
    // MARK: - Metadata (schnell, für Listenansichten)
    
    /// Leichte Metadaten ohne schwere Daten (drawingData, croppedImageData)
    public struct NoteMetadata {
        public let id: String
        public let lineCount: Int
        public let updatedAt: Date
        public let backgroundStyle: NoteBackgroundStyle
        public let backgroundScale: Double
        public let tagID: UUID?
        public let hasContent: Bool  // Vorgeprüft beim Speichern
        public let hasPreviewImage: Bool
        public let textBoxCount: Int
        public let imageBoxCount: Int

        public init(
            id: String,
            lineCount: Int,
            updatedAt: Date,
            backgroundStyle: NoteBackgroundStyle,
            backgroundScale: Double,
            tagID: UUID?,
            hasContent: Bool,
            hasPreviewImage: Bool,
            textBoxCount: Int,
            imageBoxCount: Int
        ) {
            self.id = id
            self.lineCount = lineCount
            self.updatedAt = updatedAt
            self.backgroundStyle = backgroundStyle
            self.backgroundScale = backgroundScale
            self.tagID = tagID
            self.hasContent = hasContent
            self.hasPreviewImage = hasPreviewImage
            self.textBoxCount = textBoxCount
            self.imageBoxCount = imageBoxCount
        }
    }
    
    /// Lädt nur Metadaten für alle Notizen (sehr schnell)
    public func loadAllMetadata() -> [String: NoteMetadata] {
        var result: [String: NoteMetadata] = [:]
        let storedMetadata = storage.loadNotesMetadata()
        
        for (key, value) in storedMetadata {
            guard let dict = value as? [String: Any] else { continue }
            let noteMetadata = NoteMetadata(
                id: key,
                lineCount: dict["lineCount"] as? Int ?? 6,
                updatedAt: Date(timeIntervalSince1970: dict["updatedAt"] as? Double ?? Date().timeIntervalSince1970),
                backgroundStyle: (dict["backgroundStyle"] as? String).flatMap(NoteBackgroundStyle.init(rawValue:)) ?? .blank,
                backgroundScale: dict["backgroundScale"] as? Double ?? NoteBackgroundMetrics.defaultScale,
                tagID: (dict["tagID"] as? String).flatMap(UUID.init(uuidString:)),
                hasContent: dict["hasContent"] as? Bool ?? true,
                hasPreviewImage: dict["hasPreviewImage"] as? Bool ?? false,
                textBoxCount: dict["textBoxCount"] as? Int ?? 0,
                imageBoxCount: dict["imageBoxCount"] as? Int ?? 0
            )
            result[key] = noteMetadata
                
            // In Metadata-Cache speichern
            metadataCache.setObject(noteMetadata, forKey: key)
        }
        
        return result
    }
    
    /// Gibt Metadaten für eine spezifische Notiz zurück
    public func metadata(for noteKey: String) -> NoteMetadata? {
        // Aus Cache holen
        if let cached = metadataCache.object(forKey: noteKey) {
            return cached
        }
        
        // Sonst laden
        let allMetadata = loadAllMetadata()
        return allMetadata[noteKey]
    }
    
    // MARK: - Full Note Loading (lazy, on-demand)
    
    /// Lädt eine vollständige Notiz (mit Cache)
    public func loadNote(for noteKey: String) -> LessonNote? {
        // Aus Cache holen
        if let cached = cache.object(forKey: noteKey) {
            return cached
        }
        
        // Von Storage laden
        guard let note = storage.loadLessonNote(for: noteKey) else {
            return nil
        }
        
        // In Cache speichern mit Cost (ungefähre Größe)
        let cost = note.drawingData.count + (note.croppedImageData?.count ?? 0)
        cache.setObject(note, forKey: noteKey, cost: cost)
        
        return note
    }
    
    /// Speichert eine Notiz und aktualisiert den Cache.
    ///
    /// - Parameter hasVisibleContent: Bekannter Inhalt (Striche/Text/Bilder).
    ///   Die eigene Prüfung dekodiert die PencilKit-Daten und ist teuer; wer das
    ///   Ergebnis schon kennt, gibt es mit.
    public func saveNote(_ note: LessonNote, hasVisibleContent: Bool? = nil) {
        storage.saveLessonNote(note, hasVisibleContent: hasVisibleContent)

        // Cache aktualisieren
        let cost = note.drawingData.count + (note.croppedImageData?.count ?? 0)
        cache.setObject(note, forKey: note.id, cost: cost)

        // Metadata aktualisieren
        let metadata = NoteMetadata(
            id: note.id,
            lineCount: note.lineCount,
            updatedAt: note.updatedAt,
            backgroundStyle: note.backgroundStyle,
            backgroundScale: note.backgroundScale,
            tagID: note.tagID,
            hasContent: hasVisibleContent ?? note.hasVisibleContent,
            hasPreviewImage: note.croppedImageData != nil,
            textBoxCount: note.textBoxes.count,
            imageBoxCount: note.imageBoxes.count
        )
        metadataCache.setObject(metadata, forKey: note.id)
    }
    
    /// Löscht eine Notiz aus Storage und Cache
    public func deleteNote(for noteKey: String) {
        storage.deleteLessonNote(for: noteKey)
        
        cache.removeObject(forKey: noteKey)
        metadataCache.removeObject(forKey: noteKey)
    }
    
    /// Gibt eine Notiz aus dem Cache zurück (ohne zu laden)
    public func cachedNote(for noteKey: String) -> LessonNote? {
        return cache.object(forKey: noteKey)
    }
    
    /// Entfernt eine Notiz aus dem Cache (bleibt auf Storage)
    public func evictFromCache(_ noteKey: String) {
        cache.removeObject(forKey: noteKey)
    }
    
    /// Leert den gesamten Cache
    public func clearCache() {
        cache.removeAllObjects()
        metadataCache.removeAllObjects()
    }
    
    // MARK: - Preview Image Loading (separat, lazy)
    
    /// Lädt nur das Preview-Bild einer Notiz (ohne vollständige Notiz)
    public func loadPreviewImage(for noteKey: String) -> Data? {
        return storage.loadPreviewImage(for: noteKey)
    }
    
    // MARK: - Batch Operations
    
    /// Lädt mehrere Notizen parallel (für sichtbare Bereiche)
    public func loadNotes(for noteKeys: [String], completion: @escaping ([String: LessonNote]) -> Void) {
        let group = DispatchGroup()
        var results: [String: LessonNote] = [:]
        let lock = NSLock()
        
        for key in noteKeys {
            group.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                if let note = self.loadNote(for: key) {
                    lock.lock()
                    results[key] = note
                    lock.unlock()
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            completion(results)
        }
    }
}

// MARK: - NSCache Helper

/// `NSCache` kann ausschließlich Klassen speichern (`ObjectType: AnyObject`).
/// `LessonNote` und `NoteCacheService.NoteMetadata` sind jedoch Structs.
/// Diese Box verpackt einen beliebigen Werttyp in ein leichtgewichtiges
/// Klassenobjekt, ohne den Wert zu kopieren.
private final class NoteCacheBox<Value> {
    let value: Value
    
    init(_ value: Value) {
        self.value = value
    }
}

/// Typsicherer Wrapper um `NSCache` für Werttypen.
///
/// Nach außen bleibt die API typisiert (`Value` statt `AnyObject`), intern
/// kommt weiterhin `NSCache` zum Einsatz – inklusive `countLimit`,
/// `totalCostLimit` und der automatischen Eviction bei Speicherdruck.
private final class NoteValueCache<Value> {
    private let storage = NSCache<NSString, NoteCacheBox<Value>>()
    
    var countLimit: Int {
        get { storage.countLimit }
        set { storage.countLimit = newValue }
    }
    
    var totalCostLimit: Int {
        get { storage.totalCostLimit }
        set { storage.totalCostLimit = newValue }
    }
    
    func object(forKey key: String) -> Value? {
        storage.object(forKey: key as NSString)?.value
    }
    
    func setObject(_ value: Value, forKey key: String, cost: Int = 0) {
        storage.setObject(NoteCacheBox(value), forKey: key as NSString, cost: cost)
    }
    
    func removeObject(forKey key: String) {
        storage.removeObject(forKey: key as NSString)
    }
    
    func removeAllObjects() {
        storage.removeAllObjects()
    }
}
