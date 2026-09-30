import Foundation
import PencilKit

/// Undo/Redo-Verwaltung für die Textfelder einer Notiz. Die PencilKit-Zeichnung
/// hat ihren eigenen Undo-Stack im `PKCanvasView` – dieser Controller ergänzt
/// einen zweiten Stack für alle Textfeld-Änderungen (Erstellen, Verschieben,
/// Breite ändern, Schriftgröße, Farbe, Textänderungen, Löschen), sodass
/// Rückgängig/Wiederholen auch Textfelder einschließt.
///
/// Aktionen, die Zeichnung UND Textfelder gleichzeitig betreffen („Handschrift
/// in Text umwandeln", „Seite leeren"), werden als kombinierter Schritt mit
/// optionalen Zeichnungs-Snapshots registriert: Ein einziger Druck auf
/// Rückgängig stellt dann beides zusammen wieder her.
///
/// Alle Methoden werden ausschließlich auf dem Haupt-Thread aufgerufen
/// (SwiftUI-Events), daher bewusst KEINE @MainActor-Annotation – deren
/// Isolations-Checks würden sich mit den UndoManager-Handlern beißen.
public final class TextFieldUndoController: ObservableObject {
    public let undoManager = UndoManager()

    /// Liefert den aktuellen Textfeld-Zustand (wird von der View gesetzt).
    public var getter: () -> [NoteTextBox] = { [] }
    /// Setzt den Textfeld-Zustand (wird von der View gesetzt).
    public var setter: ([NoteTextBox]) -> Void = { _ in }
    /// Optionaler Setter für die PencilKit-Zeichnung. Wird nur bei kombinierten
    /// Aktionen (mit `drawingBefore`/`drawingAfter`) benötigt und stellt dann
    /// den zugehörigen Zeichnungs-Snapshot gemeinsam mit den Textfeldern wieder her.
    public var drawingSetter: ((PKDrawing) -> Void)? = nil

    /// Zeitpunkt der letzten registrierten Änderung – wird genutzt, um bei
    /// kombiniertem Undo (Zeichnung + Text) die jeweils jüngste Aktion
    /// zuerst rückgängig zu machen.
    public private(set) var lastChangeDate: Date = .distantPast

    public init() {
        undoManager.levelsOfUndo = 40
        undoManager.groupsByEvent = true
    }

    /// Registriert eine bereits angewendete Änderung. `before`/`after` sind
    /// vollständige Snapshots des Textfeld-Arrays. Zusätzlich können
    /// `drawingBefore`/`drawingAfter` Snapshots der Zeichnung mitgegeben
    /// werden, wenn die Aktion auch die Zeichnung ersetzt hat – Undo stellt
    /// dann `drawingBefore` wieder her, Redo `drawingAfter`.
    public func push(
        before: [NoteTextBox],
        after: [NoteTextBox],
        drawingBefore: PKDrawing? = nil,
        drawingAfter: PKDrawing? = nil
    ) {
        guard before != after || drawingBefore != nil || drawingAfter != nil else { return }
        lastChangeDate = Date()
        undoManager.registerUndo(withTarget: self) { target in
            target.setter(before)
            if let drawingBefore {
                target.drawingSetter?(drawingBefore)
            }
            target.pushInverted(
                before: before,
                after: after,
                drawingBefore: drawingBefore,
                drawingAfter: drawingAfter
            )
        }
    }

    /// Registriert die Umkehrung (Redo) – nach Ausführung wird wieder der
    /// normale Undo-Eintrag gelegt, sodass Undo/Redo beliebig wechseln können.
    private func pushInverted(
        before: [NoteTextBox],
        after: [NoteTextBox],
        drawingBefore: PKDrawing?,
        drawingAfter: PKDrawing?
    ) {
        undoManager.registerUndo(withTarget: self) { target in
            target.setter(after)
            if let drawingAfter {
                target.drawingSetter?(drawingAfter)
            }
            target.push(
                before: before,
                after: after,
                drawingBefore: drawingBefore,
                drawingAfter: drawingAfter
            )
        }
    }

    public var canUndo: Bool { undoManager.canUndo }
    public var canRedo: Bool { undoManager.canRedo }

    public func undo() { undoManager.undo() }
    public func redo() { undoManager.redo() }

    public func removeAllActions() {
        undoManager.removeAllActions()
    }
}
