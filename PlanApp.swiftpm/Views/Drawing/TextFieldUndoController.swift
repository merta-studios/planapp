import Foundation

/// Ein vollständiger Zustands-Schnappschuss der Notiz für Rückgängig/Wiederholen.
///
/// `drawingData` ist optional: Ist es `nil`, betrifft der Schritt ausschließlich
/// die Textfelder und die PencilKit-Zeichnung bleibt unangetastet. Aktionen,
/// die Text **und** Striche gleichzeitig verändern (z. B. „Handschrift in Text
/// umwandeln" oder „Seite leeren"), legen hier zusätzlich die serialisierte
/// Zeichnung ab, damit ein einziges Rückgängig beides zurückholt.
public struct NoteUndoSnapshot: Equatable {
    public var textBoxes: [NoteTextBox]
    public var drawingData: Data?

    public init(textBoxes: [NoteTextBox], drawingData: Data? = nil) {
        self.textBoxes = textBoxes
        self.drawingData = drawingData
    }
}

/// Undo/Redo-Verwaltung für die Textfelder einer Notiz. Die PencilKit-Zeichnung
/// hat ihren eigenen Undo-Stack im `PKCanvasView` – dieser Controller ergänzt
/// einen zweiten Stack für alle Textfeld-Änderungen (Erstellen, Verschieben,
/// Breite ändern, Schriftgröße, Farbe, Textänderungen, Löschen), sodass
/// Rückgängig/Wiederholen auch Textfelder einschließt.
///
/// Zusätzlich kann ein Schritt die komplette Zeichnung mit-sichern. Das ist
/// nötig für Aktionen, die Striche in Textfelder verwandeln – dort reicht der
/// Canvas-eigene Undo-Stack nicht aus.
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
    /// Setzt die PencilKit-Zeichnung aus ihrer Datenrepräsentation
    /// (wird von der View gesetzt).
    public var drawingSetter: (Data) -> Void = { _ in }

    /// Zeitpunkt der letzten registrierten Änderung – wird genutzt, um bei
    /// kombiniertem Undo (Zeichnung + Text) die jeweils jüngste Aktion
    /// zuerst rückgängig zu machen.
    public private(set) var lastChangeDate: Date = .distantPast

    public init() {
        undoManager.levelsOfUndo = 40
        undoManager.groupsByEvent = true
    }

    /// Registriert eine bereits angewendete Textfeld-Änderung. `before`/`after`
    /// sind vollständige Snapshots des Textfeld-Arrays.
    public func push(before: [NoteTextBox], after: [NoteTextBox]) {
        push(
            before: NoteUndoSnapshot(textBoxes: before),
            after: NoteUndoSnapshot(textBoxes: after)
        )
    }

    /// Registriert eine bereits angewendete Änderung an Textfeldern und/oder
    /// der Zeichnung.
    public func push(before: NoteUndoSnapshot, after: NoteUndoSnapshot) {
        guard before != after else { return }
        lastChangeDate = Date()
        undoManager.registerUndo(withTarget: self) { target in
            target.apply(before)
            target.lastChangeDate = Date()
            target.pushInverted(before: before, after: after)
        }
    }

    /// Registriert die Umkehrung (Redo) – nach Ausführung wird wieder der
    /// normale Undo-Eintrag gelegt, sodass Undo/Redo beliebig wechseln können.
    private func pushInverted(before: NoteUndoSnapshot, after: NoteUndoSnapshot) {
        undoManager.registerUndo(withTarget: self) { target in
            target.apply(after)
            target.lastChangeDate = Date()
            target.push(before: before, after: after)
        }
    }

    private func apply(_ snapshot: NoteUndoSnapshot) {
        setter(snapshot.textBoxes)
        if let data = snapshot.drawingData {
            drawingSetter(data)
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
