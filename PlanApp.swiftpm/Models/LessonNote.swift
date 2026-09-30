import Foundation
import UIKit

/// Enthält handschriftliche Notizen/Zeichnungen für eine Unterrichtsstunde
public struct LessonNote: Identifiable, Codable, Equatable {
    public var id: String             // Lesson-Schlüssel (z.B. "2026-09-30_1_M")
    public var drawingData: Data      // PKDrawing.dataRepresentation()
    public var croppedImageData: Data? // PNG-Bild der zugeschnittenen Zeichnung
    public var lineCount: Int         // Anzahl der Zeilen auf dem Zettel (max. 10)
    public var updatedAt: Date

    public init(
        id: String,
        drawingData: Data = Data(),
        croppedImageData: Data? = nil,
        lineCount: Int = 6,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.drawingData = drawingData
        self.croppedImageData = croppedImageData
        self.lineCount = max(3, min(10, lineCount))
        self.updatedAt = updatedAt
    }

    /// Hilfsmethode: Prüft, ob eine Zeichnung vorhanden ist
    public var hasDrawing: Bool {
        return croppedImageData != nil && !drawingData.isEmpty
    }
}
