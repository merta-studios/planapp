import Foundation
import UIKit

/// Enthält handschriftliche Notizen/Zeichnungen für eine Unterrichtsstunde
public struct LessonNote: Identifiable, Codable, Equatable {
    public var id: String             // Lesson-Schlüssel (z.B. "2026-09-30_1_M")
    public var drawingData: Data      // PKDrawing.dataRepresentation()
    public var croppedImageData: Data? // PNG-Bild der zugeschnittenen Zeichnung
    public var lineCount: Int         // Anzahl der Zeilen auf dem Zettel (max. 10)
    public var textBoxes: [NoteTextBox] // Frei bewegliche Textfelder
    public var backgroundStyle: NoteBackgroundStyle // Hintergrund der Zeichenfläche
    public var updatedAt: Date

    public init(
        id: String,
        drawingData: Data = Data(),
        croppedImageData: Data? = nil,
        lineCount: Int = 6,
        textBoxes: [NoteTextBox] = [],
        backgroundStyle: NoteBackgroundStyle = .blank,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.drawingData = drawingData
        self.croppedImageData = croppedImageData
        self.lineCount = max(3, min(10, lineCount))
        self.textBoxes = textBoxes
        self.backgroundStyle = backgroundStyle
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, drawingData, croppedImageData, lineCount, textBoxes, backgroundStyle, updatedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.drawingData = try container.decodeIfPresent(Data.self, forKey: .drawingData) ?? Data()
        self.croppedImageData = try container.decodeIfPresent(Data.self, forKey: .croppedImageData)
        let decodedLineCount = try container.decodeIfPresent(Int.self, forKey: .lineCount) ?? 6
        self.lineCount = max(3, min(10, decodedLineCount))
        self.textBoxes = try container.decodeIfPresent([NoteTextBox].self, forKey: .textBoxes) ?? []
        self.backgroundStyle = try container.decodeIfPresent(NoteBackgroundStyle.self, forKey: .backgroundStyle) ?? .blank
        self.updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(drawingData, forKey: .drawingData)
        try container.encodeIfPresent(croppedImageData, forKey: .croppedImageData)
        try container.encode(lineCount, forKey: .lineCount)
        try container.encode(textBoxes, forKey: .textBoxes)
        try container.encode(backgroundStyle, forKey: .backgroundStyle)
        try container.encode(updatedAt, forKey: .updatedAt)
    }

    /// Hilfsmethode: Prüft, ob eine Zeichnung oder Textfelder vorhanden sind
    public var hasDrawing: Bool {
        return (croppedImageData != nil && !drawingData.isEmpty) || !textBoxes.isEmpty
    }

    /// Prüft, ob die Notiz sichtbaren Inhalt hat (Striche, Textfelder oder ein
    /// bereits gerendertes Vorschaubild). Wird für die Ansichtsmodi
    /// "Notizen hervorgehoben" und "Nur Notizen" sowie die Vorschau genutzt.
    public var hasVisibleContent: Bool {
        if croppedImageData != nil { return true }
        if textBoxes.contains(where: { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) { return true }
        return !drawingData.isEmpty
    }
}
