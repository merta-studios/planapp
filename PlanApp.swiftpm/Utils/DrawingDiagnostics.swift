import Foundation
import os

/// Diagnose-Ausgaben für Hit-Test und Strich-Pipeline der Notiz.
///
/// Zweck: On-Device-Debugging der Zeichen-/Auswahl-Bugs über die macOS-Konsole
/// (Console.app) oder die Xcode-Konsole. Subsystem: `com.planapp.stundenplan`.
///
/// * `note-hit`     – Hit-Test-Entscheidungen der Ebenen-Hülle und des
///                    Schließen-Backdrops (warum landet eine Berührung auf dem
///                    Canvas, auf einem Bild – oder gar nicht?).
/// * `note-stroke`  – Strich-Pipeline (PencilKit → Binding → Historie).
/// * `note-dismiss` – bewusstes Schließen der Notiz (Rand-Tipp-Bug).
///
/// Die Ausgaben laufen als `Logger` auf `os_log`-Basis: `.debug`-Einträge sind
/// nicht persistent und werden nur beim Streamen sichtbar – sie kosten in
/// Release-Builds praktisch nichts. Wichtige Dismiss-/Speicher-Ereignisse
/// laufen auf `.info`.
enum DrawingDiagnostics {
    static let hit = Logger(subsystem: "com.planapp.stundenplan", category: "note-hit")
    static let stroke = Logger(subsystem: "com.planapp.stundenplan", category: "note-stroke")
    static let dismiss = Logger(subsystem: "com.planapp.stundenplan", category: "note-dismiss")
}
