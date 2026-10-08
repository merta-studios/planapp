import Foundation
import PencilKit

/// Ein Zustand der Zeichenfläche, der sich rückgängig machen bzw. wiederholen lässt.
public struct NoteHistorySnapshot: Codable, Equatable {
    public var drawingData: Data
    public var textBoxes: [NoteTextBox]
    /// Bilder der Notiz. Ältere Sitzungen kennen sie noch nicht – beim
    /// Laden fallen sie dann einfach auf „keine Bilder“ zurück, statt die
    /// Sitzung zu verwerfen.
    public var images: [NoteImageBox]

    public init(drawingData: Data, textBoxes: [NoteTextBox], images: [NoteImageBox] = []) {
        self.drawingData = drawingData
        self.textBoxes = textBoxes
        self.images = images
    }

    private enum CodingKeys: String, CodingKey {
        case drawingData, textBoxes, images
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        drawingData = try container.decodeIfPresent(Data.self, forKey: .drawingData) ?? Data()
        textBoxes = try container.decodeIfPresent([NoteTextBox].self, forKey: .textBoxes) ?? []
        images = try container.decodeIfPresent([NoteImageBox].self, forKey: .images) ?? []
    }

    /// Die gespeicherte Zeichnung – `nil`, wenn kein gültiger Stand vorliegt.
    ///
    /// Leere Daten sind **kein** leerer Zettel, sondern ein fehlender Stand
    /// (z. B. der Startwert, bevor eine Notiz geladen wurde). Ein solcher Wert
    /// darf die Zeichenfläche niemals leeren – ein leerer Zettel wird dagegen
    /// als gültige, wenn auch winzige Zeichnung gespeichert.
    public func drawing() -> PKDrawing? {
        guard !drawingData.isEmpty, let drawing = try? PKDrawing(data: drawingData) else {
            return nil
        }
        return drawing
    }
}

/// Persistierte Undo/Redo-Sitzung einer Notiz.
public struct PersistedNoteUndoSession: Codable, Equatable {
    public var noteKey: String
    public var undoStack: [NoteHistorySnapshot]
    public var redoStack: [NoteHistorySnapshot]
    public var current: NoteHistorySnapshot
    public var updatedAt: Date

    public init(
        noteKey: String,
        undoStack: [NoteHistorySnapshot],
        redoStack: [NoteHistorySnapshot],
        current: NoteHistorySnapshot,
        updatedAt: Date = Date()
    ) {
        self.noteKey = noteKey
        self.undoStack = undoStack
        self.redoStack = redoStack
        self.current = current
        self.updatedAt = updatedAt
    }
}

extension NoteUndoSessionPolicy {
    public static func cappedStacks(
        undo: [NoteHistorySnapshot],
        redo: [NoteHistorySnapshot]
    ) -> (undo: [NoteHistorySnapshot], redo: [NoteHistorySnapshot]) {
        (
            undo: Array(undo.suffix(maximumSteps)),
            redo: Array(redo.suffix(maximumSteps))
        )
    }
}

/// In-Memory-Undo/Redo für eine geöffnete Notiz (Zeichnung + Textfelder + Bilder).
public final class NoteEditingHistory {
    public private(set) var undoStack: [NoteHistorySnapshot] = []
    public private(set) var redoStack: [NoteHistorySnapshot] = []
    public private(set) var current: NoteHistorySnapshot

    public init(current: NoteHistorySnapshot) {
        self.current = current
    }

    public var undoCount: Int { undoStack.count }
    public var redoCount: Int { redoStack.count }
    public var canUndo: Bool { !undoStack.isEmpty }
    public var canRedo: Bool { !redoStack.isEmpty }

    public func bootstrap(_ snapshot: NoteHistorySnapshot) {
        current = snapshot
        undoStack.removeAll()
        redoStack.removeAll()
    }

    public func restore(_ session: PersistedNoteUndoSession) {
        let capped = NoteUndoSessionPolicy.cappedStacks(undo: session.undoStack, redo: session.redoStack)
        current = session.current
        undoStack = capped.undo
        redoStack = capped.redo
    }

    public func record(_ snapshot: NoteHistorySnapshot) {
        record(before: current, after: snapshot)
    }

    /// Verzeichnet einen Schritt **von** einem bekannten Zustand **nach** dem
    /// neuen Zustand. Beides kommt vom Aufrufer (Zeichenfläche bzw.
    /// Textfelder) – dadurch entsteht ein Schritt nie aus einem veralteten
    /// Zwischenstand, und das Rückgängigmachen selbst kann nicht als eigener
    /// Schritt in der Historie landen.
    public func record(before: NoteHistorySnapshot, after: NoteHistorySnapshot) {
        guard before != after else { return }
        undoStack.append(before)
        if undoStack.count > NoteUndoSessionPolicy.maximumSteps {
            undoStack.removeFirst(undoStack.count - NoteUndoSessionPolicy.maximumSteps)
        }
        redoStack.removeAll()
        current = after
    }

    @discardableResult
    public func undo() -> NoteHistorySnapshot? {
        guard let previous = undoStack.popLast() else { return nil }
        redoStack.append(current)
        current = previous
        return previous
    }

    @discardableResult
    public func redo() -> NoteHistorySnapshot? {
        guard let next = redoStack.popLast() else { return nil }
        undoStack.append(current)
        current = next
        return next
    }

    public func persistedSession(for noteKey: String) -> PersistedNoteUndoSession {
        let capped = NoteUndoSessionPolicy.cappedStacks(undo: undoStack, redo: redoStack)
        return PersistedNoteUndoSession(
            noteKey: noteKey,
            undoStack: capped.undo,
            redoStack: capped.redo,
            current: current,
            updatedAt: Date()
        )
    }
}

/// Die letzten drei Undo-Sitzungen, die beim erneuten Öffnen einer Notiz
/// Rückgängig/Wiederholen wiederherstellen.
public struct NoteUndoSessionStore: Codable, Equatable {
    public var sessions: [PersistedNoteUndoSession]

    public init(sessions: [PersistedNoteUndoSession] = []) {
        self.sessions = Array(sessions.prefix(NoteUndoSessionPolicy.maximumSessions))
    }

    public mutating func save(_ session: PersistedNoteUndoSession) {
        sessions.removeAll { $0.noteKey == session.noteKey }
        sessions.insert(session, at: 0)
        if sessions.count > NoteUndoSessionPolicy.maximumSessions {
            sessions = Array(sessions.prefix(NoteUndoSessionPolicy.maximumSessions))
        }
    }

    public func session(for noteKey: String) -> PersistedNoteUndoSession? {
        sessions.first { $0.noteKey == noteKey }
    }

    public mutating func removeSession(for noteKey: String) {
        sessions.removeAll { $0.noteKey == noteKey }
    }
}
