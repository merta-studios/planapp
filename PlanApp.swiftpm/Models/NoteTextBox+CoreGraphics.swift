import Foundation
import CoreGraphics

/// Die CoreGraphics-Brücke für ``NoteTextBox``.
///
/// `NoteTextBox.swift` selbst bleibt frei von CoreGraphics, damit seine reinen
/// Regeln (automatisches Mitwachsen, Umbruch-Prüfung) auf Linux in den
/// Regressions-Tests übersetzen. Die App arbeitet überall mit `CGSize`; diese
/// Datei übersetzt nur.
extension NoteTextBox {
    /// Wie ``sanitized(in:)``, aber mit einer `CGSize` der Zeichenfläche.
    public func sanitized(in coreGraphicsArea: CGSize?) -> NoteTextBox? {
        guard let coreGraphicsArea else { return sanitized(in: TextAreaSize?.none) }
        return sanitized(in: TextAreaSize(
            width: Double(coreGraphicsArea.width),
            height: Double(coreGraphicsArea.height)
        ))
    }
}
