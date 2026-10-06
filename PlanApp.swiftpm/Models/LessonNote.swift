import Foundation
import UIKit
import PencilKit

/// Enthält handschriftliche Notizen/Zeichnungen für eine Unterrichtsstunde
public struct LessonNote: Identifiable, Codable, Equatable {
    public var id: String             // Lesson-Schlüssel (z.B. "2026-09-30_1_M")
    public var drawingData: Data      // PKDrawing.dataRepresentation()
    public var croppedImageData: Data? // PNG-Bild der zugeschnittenen Zeichnung
    public var lineCount: Int         // Anzahl der Zeilen auf dem Zettel (max. 10)
    public var textBoxes: [NoteTextBox] // Frei bewegliche Textfelder
    public var backgroundStyle: NoteBackgroundStyle // Hintergrund der Zeichenfläche
    /// Skalierung des Hintergrund-Musters (1 = Standardgröße, 0.5–2).
    public var backgroundScale: Double
    /// Zugewiesener Tag (siehe `NoteTag`); `nil` = kein Tag.
    public var tagID: UUID?
    public var updatedAt: Date

    public init(
        id: String,
        drawingData: Data = Data(),
        croppedImageData: Data? = nil,
        lineCount: Int = 6,
        textBoxes: [NoteTextBox] = [],
        backgroundStyle: NoteBackgroundStyle = .blank,
        backgroundScale: Double = 1,
        tagID: UUID? = nil,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.drawingData = drawingData
        self.croppedImageData = croppedImageData
        self.lineCount = max(3, min(10, lineCount))
        self.textBoxes = textBoxes
        self.backgroundStyle = backgroundStyle
        self.backgroundScale = NoteBackgroundMetrics.clampedScale(backgroundScale)
        self.tagID = tagID
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, drawingData, croppedImageData, lineCount, textBoxes, backgroundStyle, backgroundScale, tagID, updatedAt
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
        let decodedScale = try container.decodeIfPresent(Double.self, forKey: .backgroundScale) ?? 1
        self.backgroundScale = NoteBackgroundMetrics.clampedScale(decodedScale)
        self.tagID = try container.decodeIfPresent(UUID.self, forKey: .tagID)
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
        try container.encode(backgroundScale, forKey: .backgroundScale)
        try container.encodeIfPresent(tagID, forKey: .tagID)
        try container.encode(updatedAt, forKey: .updatedAt)
    }

    /// Prüft, ob mindestens ein Textfeld wirklich Text enthält.
    public var hasTextContent: Bool {
        textBoxes.contains { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    /// Prüft die eigentliche PencilKit-Zeichnung auf sichtbare Striche.
    ///
    /// Wichtig: `PKDrawing().dataRepresentation()` ist nicht leer. Eine reine
    /// Datenlängen-Prüfung markiert deshalb schon eine gerade geöffnete, aber
    /// komplett leere Notiz als "vorhanden". Für Hervorhebung, Optionen und
    /// die "Nur Notizen"-Liste zählen daher nur echte Strokes.
    public var hasInkContent: Bool {
        guard !drawingData.isEmpty else { return false }
        guard let drawing = try? PKDrawing(data: drawingData) else {
            // Fallback für sehr alte/unerwartete Daten: lieber erhalten als
            // versehentlich eine tatsächlich beschriebene Notiz ausblenden.
            return true
        }
        return !drawing.strokes.isEmpty
    }

    /// Hilfsmethode: Prüft, ob eine Zeichnung oder nicht-leere Textfelder vorhanden sind
    public var hasDrawing: Bool {
        hasInkContent || hasTextContent
    }

    /// Prüft, ob die Notiz sichtbaren Inhalt hat (Striche oder Textfelder).
    /// Ein Tag allein zählt bewusst nicht: Stundenblöcke dürfen nicht nur
    /// wegen eines Tags ohne Notiz existieren. Das Vorschaubild ist nur Cache.
    public var hasVisibleContent: Bool {
        NoteContentPolicy.shouldPersist(hasInk: hasInkContent, hasText: hasTextContent)
    }
}
