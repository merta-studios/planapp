import Foundation
import UIKit
import PencilKit

/// Lazy-Loading Service für Notizen mit LRU-Cache
/// Lädt Notizen nur bei Bedarf und hält eine begrenzte Anzahl im Speicher
public final class NoteCacheService {
    public static let shared = NoteCacheService()
    
    private let storage = TimetableStorageService.shared
    private let cache = NSCache<NSString, LessonNote>()
    private let metadataCache = NSCache<NSString, NoteMetadata>()
    
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
    }
    
    /// Lädt nur Metadaten für alle Notizen (sehr schnell)
    public func loadAllMetadata() -> [String: NoteMetadata] {
        var result: [String: NoteMetadata] = [:]
        let metadata = storage.loadNotesMetadata()
        
        for (key, meta) in metadata {
            if let dict = meta as? [String: Any] {
                let metadata = NoteMetadata(
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
                result[key] = metadata
                
                // In Metadata-Cache speichern
                let cacheKey = key as NSString
                metadataCache.setObject(metadata as AnyObject, forKey: cacheKey)
            }
        }
        
        return result
    }
    
    /// Gibt Metadaten für eine spezifische Notiz zurück
    public func metadata(for noteKey: String) -> NoteMetadata? {
        let cacheKey = noteKey as NSString
        
        // Aus Cache holen
        if let cached = metadataCache.object(forKey: cacheKey) as? NoteMetadata {
            return cached
        }
        
        // Sonst laden
        let allMetadata = loadAllMetadata()
        return allMetadata[noteKey]
    }
    
    // MARK: - Full Note Loading (lazy, on-demand)
    
    /// Lädt eine vollständige Notiz (mit Cache)
    public func loadNote(for noteKey: String) -> LessonNote? {
        let cacheKey = noteKey as NSString
        
        // Aus Cache holen
        if let cached = cache.object(forKey: cacheKey) {
            return cached
        }
        
        // Von Storage laden
        guard let note = storage.loadLessonNote(for: noteKey) else {
            return nil
        }
        
        // In Cache speichern mit Cost (ungefähre Größe)
        let cost = note.drawingData.count + (note.croppedImageData?.count ?? 0)
        cache.setObject(note, forKey: cacheKey, cost: cost)
        
        return note
    }
    
    /// Speichert eine Notiz und aktualisiert den Cache
    public func saveNote(_ note: LessonNote) {
        storage.saveLessonNote(note)
        
        // Cache aktualisieren
        let cacheKey = note.id as NSString
        let cost = note.drawingData.count + (note.croppedImageData?.count ?? 0)
        cache.setObject(note, forKey: cacheKey, cost: cost)
        
        // Metadata aktualisieren
        let metadata = NoteMetadata(
            id: note.id,
            lineCount: note.lineCount,
            updatedAt: note.updatedAt,
            backgroundStyle: note.backgroundStyle,
            backgroundScale: note.backgroundScale,
            tagID: note.tagID,
            hasContent: note.hasVisibleContent,
            hasPreviewImage: note.croppedImageData != nil,
            textBoxCount: note.textBoxes.count,
            imageBoxCount: note.imageBoxes.count
        )
        metadataCache.setObject(metadata as AnyObject, forKey: cacheKey)
    }
    
    /// Löscht eine Notiz aus Storage und Cache
    public func deleteNote(for noteKey: String) {
        storage.deleteLessonNote(for: noteKey)
        
        let cacheKey = noteKey as NSString
        cache.removeObject(forKey: cacheKey)
        metadataCache.removeObject(forKey: cacheKey)
    }
    
    /// Gibt eine Notiz aus dem Cache zurück (ohne zu laden)
    public func cachedNote(for noteKey: String) -> LessonNote? {
        let cacheKey = noteKey as NSString
        return cache.object(forKey: cacheKey)
    }
    
    /// Entfernt eine Notiz aus dem Cache (bleibt auf Storage)
    public func evictFromCache(_ noteKey: String) {
        let cacheKey = noteKey as NSString
        cache.removeObject(forKey: cacheKey)
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

extension NoteCacheService.NoteMetadata: AnyObject {}
