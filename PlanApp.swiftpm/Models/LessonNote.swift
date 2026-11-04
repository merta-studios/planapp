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
    /// Frei bewegliche, skalierbare Bilder auf der Zeichenfläche.
    public var imageBoxes: [NoteImageBox]
    public var backgroundStyle: NoteBackgroundStyle // Hintergrund der Zeichenfläche
    /// Skalierung des Hintergrund-Musters (1 = Standardgröße, 0.5–2).
    public var backgroundScale: Double
    /// Zugewiesener Tag (siehe `NoteTag`); `nil` = kein Tag.
    public var tagID: UUID?
    /// Wie die Notiz entstanden ist: `false` = normaler Zeichenbereich
    /// (iPad), `true` = schlichte Textnotiz vom iPhone.
    ///
    /// Solche „Handy-Notizen“ haben keinen Zeichenbereich, keine Bilder und
    /// keine freien Textfelder – nur einen Fließtext. Sie lassen sich auf dem
    /// iPhone nicht mehr öffnen (dort gibt es nur noch die Optionen), sondern
    /// werden beim ersten Bearbeiten auf dem iPad in den normalen
    /// Zeichenbereich umgewandelt (siehe Editor).
    public var usesPhoneTextLayout: Bool
    /// Fließtext einer Handy-Notiz (nur gültig bei `usesPhoneTextLayout`).
    public var phoneText: String
    /// Schriftgröße des Fließtexts einer Handy-Notiz.
    public var phoneFontSize: Double?
    /// Zeitpunkt, zu dem die Notiz zuletzt als Handy-Notiz gespeichert wurde.
    /// Ist `updatedAt` **neuer**, wurde sie seither auf dem iPad im
    /// Zeichenbereich bearbeitet – auf dem iPhone ist sie dann wieder gesperrt
    /// (nur noch Optionen, kein Öffnen).
    public var phoneLayoutConversionDate: Date?
    public var updatedAt: Date

    public init(
        id: String,
        drawingData: Data = Data(),
        croppedImageData: Data? = nil,
        lineCount: Int = 6,
        textBoxes: [NoteTextBox] = [],
        imageBoxes: [NoteImageBox] = [],
        backgroundStyle: NoteBackgroundStyle = .blank,
        backgroundScale: Double = 1,
        tagID: UUID? = nil,
        usesPhoneTextLayout: Bool = false,
        phoneText: String = "",
        phoneFontSize: Double? = nil,
        phoneLayoutConversionDate: Date? = nil,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.drawingData = drawingData
        self.croppedImageData = croppedImageData
        self.lineCount = max(3, min(10, lineCount))
        self.textBoxes = textBoxes
        self.imageBoxes = imageBoxes
        self.backgroundStyle = backgroundStyle
        self.backgroundScale = NoteBackgroundMetrics.clampedScale(backgroundScale)
        self.tagID = tagID
        self.usesPhoneTextLayout = usesPhoneTextLayout
        self.phoneText = phoneText
        self.phoneFontSize = phoneFontSize.map(NoteTextBox.clampedPhoneFontSize)
        self.phoneLayoutConversionDate = phoneLayoutConversionDate
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, drawingData, croppedImageData, lineCount, textBoxes, imageBoxes
        case backgroundStyle, backgroundScale, tagID
        case usesPhoneTextLayout, phoneText, phoneFontSize, phoneLayoutConversionDate
        case updatedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.drawingData = try container.decodeIfPresent(Data.self, forKey: .drawingData) ?? Data()
        self.croppedImageData = try container.decodeIfPresent(Data.self, forKey: .croppedImageData)
        let decodedLineCount = try container.decodeIfPresent(Int.self, forKey: .lineCount) ?? 6
        self.lineCount = max(3, min(10, decodedLineCount))
        self.textBoxes = try container.decodeIfPresent([NoteTextBox].self, forKey: .textBoxes) ?? []
        // Ältere Speicherstände kennen noch keine Bilder – sie laden
        // selbstverständlich weiterhin (einfach ohne Bilder).
        self.imageBoxes = try container.decodeIfPresent([NoteImageBox].self, forKey: .imageBoxes) ?? []
        self.backgroundStyle = try container.decodeIfPresent(NoteBackgroundStyle.self, forKey: .backgroundStyle) ?? .blank
        let decodedScale = try container.decodeIfPresent(Double.self, forKey: .backgroundScale) ?? 1
        self.backgroundScale = NoteBackgroundMetrics.clampedScale(decodedScale)
        self.tagID = try container.decodeIfPresent(UUID.self, forKey: .tagID)
        // Ältere Speicherstände sind immer klassische Zeichen-Notizen.
        self.usesPhoneTextLayout = try container.decodeIfPresent(Bool.self, forKey: .usesPhoneTextLayout) ?? false
        self.phoneText = try container.decodeIfPresent(String.self, forKey: .phoneText) ?? ""
        self.phoneFontSize = try container
            .decodeIfPresent(Double.self, forKey: .phoneFontSize)
            .map(NoteTextBox.clampedPhoneFontSize)
        self.phoneLayoutConversionDate = try container
            .decodeIfPresent(Date.self, forKey: .phoneLayoutConversionDate)
        self.updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(drawingData, forKey: .drawingData)
        try container.encodeIfPresent(croppedImageData, forKey: .croppedImageData)
        try container.encode(lineCount, forKey: .lineCount)
        try container.encode(textBoxes, forKey: .textBoxes)
        try container.encode(imageBoxes, forKey: .imageBoxes)
        try container.encode(backgroundStyle, forKey: .backgroundStyle)
        try container.encode(backgroundScale, forKey: .backgroundScale)
        try container.encodeIfPresent(tagID, forKey: .tagID)
        try container.encode(usesPhoneTextLayout, forKey: .usesPhoneTextLayout)
        try container.encode(phoneText, forKey: .phoneText)
        try container.encodeIfPresent(phoneFontSize, forKey: .phoneFontSize)
        try container.encodeIfPresent(phoneLayoutConversionDate, forKey: .phoneLayoutConversionDate)
        try container.encode(updatedAt, forKey: .updatedAt)
    }

    /// Prüft, ob mindestens ein Textfeld (oder der Fließtext einer
    /// Handy-Notiz) wirklich Text enthält.
    public var hasTextContent: Bool {
        if usesPhoneTextLayout,
           !phoneText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true
        }
        return textBoxes.contains { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
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

    /// Prüft, ob mindestens ein Bild mit lesbaren Bilddaten vorhanden ist.
    public var hasImageContent: Bool {
        if usesPhoneTextLayout { return false }
        return imageBoxes.contains { $0.uiImage != nil }
    }

    /// Hilfsmethode: Prüft, ob eine Zeichnung oder nicht-leere Textfelder vorhanden sind
    public var hasDrawing: Bool {
        hasInkContent || hasTextContent
    }

    /// Prüft, ob die Notiz sichtbaren Inhalt hat (Striche, Textfelder oder
    /// Bilder). Ein Tag allein zählt bewusst nicht: Stundenblöcke dürfen
    /// nicht nur wegen eines Tags ohne Notiz existieren. Das Vorschaubild
    /// ist nur Cache.
    public var hasVisibleContent: Bool {
        NoteContentPolicy.shouldPersist(hasInk: hasInkContent, hasText: hasTextContent)
            || hasImageContent
    }
}
