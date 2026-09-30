import Foundation

/// Undo/Redo-Verwaltung für die Textfelder einer Notiz. Die PencilKit-Zeichnung
/// hat ihren eigenen Undo-Stack im `PKCanvasView` – dieser Controller ergänzt
/// einen zweiten Stack für alle Textfeld-Änderungen (Erstellen, Verschieben,
/// Breite ändern, Schriftgröße, Textänderungen, Löschen), sodass
/// Rückgängig/Wiederholen auch Textfelder einschließt.
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

    /// Zeitpunkt der letzten registrierten Änderung – wird genutzt, um bei
    /// kombiniertem Undo (Zeichnung + Text) die jeweils jüngste Aktion
    /// zuerst rückgängig zu machen.
    public private(set) var lastChangeDate: Date = .distantPast

    public init() {
        undoManager.levelsOfUndo = 40
        undoManager.groupsByEvent = false
    }

    /// Registriert eine bereits angewendete Änderung. `before`/`after` sind
    /// vollständige Snapshots des Textfeld-Arrays.
    public func push(before: [NoteTextBox], after: [NoteTextBox]) {
        guard before != after else { return }
        lastChangeDate = Date()
        undoManager.registerUndo(withTarget: self) { target in
            target.setter(before)
            target.pushInverted(before: before, after: after)
        }
    }

    /// Registriert die Umkehrung (Redo) – nach Ausführung wird wieder der
    /// normale Undo-Eintrag gelegt, sodass Undo/Redo beliebig wechseln können.
    private func pushInverted(before: [NoteTextBox], after: [NoteTextBox]) {
        undoManager.registerUndo(withTarget: self) { target in
            target.setter(after)
            target.push(before: before, after: after)
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
