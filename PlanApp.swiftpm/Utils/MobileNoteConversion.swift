import Foundation

/// Die Notiz-bezogenen Regeln des Handy-Modus.
///
/// Getrennt von ``MobileNotePolicy``, weil hier `LessonNote` und `NoteTextBox`
/// gebraucht werden (die Datei importiert UIKit) – die reinen Layout- und
/// Schrift-Regeln bleiben dadurch in den Regressions-Tests lauffähig.
extension MobileNotePolicy {
    /// Ob eine Notiz auf dem iPhone **nur** die Optionen zeigt (nicht
    /// bearbeitbar ist).
    public static func phoneShowsOptionsInsteadOfEditor(for note: LessonNote?) -> Bool {
        guard let note else { return false }
        return !phoneAllowsEditing(note)
    }

    /// Ob eine Notiz auf dem iPhone bearbeitet werden darf.
    ///
    /// Nur Notizen, die auf dem iPhone entstanden sind (`usesPhoneTextLayout`)
    /// und seither **nicht** auf dem iPad im Zeichenbereich geändert wurden.
    /// Sobald eine iPad-Bearbeitung nach dem letzten Handy-Speichern liegt
    /// (`updatedAt` > `phoneLayoutConversionDate`), ist die Notiz auf dem
    /// iPhone wieder gesperrt – dort gibt es dann nur die Optionen.
    public static func phoneAllowsEditing(_ note: LessonNote) -> Bool {
        guard note.usesPhoneTextLayout else { return false }
        if let convertedAt = note.phoneLayoutConversionDate,
           note.updatedAt > convertedAt.addingTimeInterval(1) {
            return false
        }
        return true
    }

    /// Ob eine vorhandene Notiz beim Öffnen auf dem **iPad** in den normalen
    /// Zeichenbereich umgewandelt werden muss.
    public static func requiresIPadConversion(_ note: LessonNote?) -> Bool {
        guard let note else { return false }
        return note.usesPhoneTextLayout
    }

    // MARK: - Handy-Notiz erzeugen

    /// Baut aus Text und Schriftgröße eine neue Handy-Notiz.
    public static func makePhoneNote(
        id: String,
        text: String,
        fontSize: Double,
        tagID: UUID?,
        updatedAt: Date = Date()
    ) -> LessonNote {
        LessonNote(
            id: id,
            drawingData: Data(),
            croppedImageData: nil,
            lineCount: 6,
            textBoxes: [],
            imageBoxes: [],
            backgroundStyle: .lined,
            backgroundScale: NoteBackgroundMetrics.defaultScale,
            tagID: tagID,
            usesPhoneTextLayout: true,
            phoneText: text,
            phoneFontSize: clamped(fontSize),
            updatedAt: updatedAt
        )
    }

    /// Wandelt den Inhalt einer Handy-Notiz in ein normales Textfeld um, das
    /// im Zeichenbereich des iPads liegt und dort bearbeitet/verschoben werden
    /// kann. Das Feld ist so breit wie die Zeichenfläche und wächst beim
    /// Tippen nach rechts weiter (`autoGrowWidth`).
    public static func convertedTextBox(
        for note: LessonNote,
        areaSize: CGSize,
        fallbackFontSize: Double
    ) -> NoteTextBox? {
        let text = note.phoneText
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let size = CGSize(
            width: areaSize.width.isFinite && areaSize.width > 0 ? areaSize.width : 640,
            height: areaSize.height.isFinite && areaSize.height > 0 ? areaSize.height : 380
        )
        let margin: Double = 6
        let width = max(90, Double(size.width) - margin * 2)
        let raw = NoteTextBox(
            text: text,
            x: margin,
            y: margin,
            width: width,
            fontSize: resolvedPhoneFontSize(
                stored: note.phoneFontSize,
                fallback: fallbackFontSize
            ),
            colorHex: NoteTextBox.defaultColorHex,
            autoGrowWidth: true
        )
        return raw.sanitized(in: size)
    }
}
