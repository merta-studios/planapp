import Foundation

/// Aktion, die ein Apple-Pencil-Squeeze bzw. ein Doppeltipp auslösen kann.
public enum PencilGestureAction: String, Codable, CaseIterable, Identifiable, Equatable {
    case toolbar
    case undo
    case toggleEraser
    case none

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .toolbar: return "Toolbar"
        case .undo: return "Rückgängig"
        case .toggleEraser: return "Radierer / letztes Werkzeug"
        case .none: return "Nichts"
        }
    }

    public var systemImage: String {
        switch self {
        case .toolbar: return "circle.grid.3x3"
        case .undo: return "arrow.uturn.backward"
        case .toggleEraser: return "eraser"
        case .none: return "minus.circle"
        }
    }

    public var shortExplanation: String {
        switch self {
        case .toolbar:
            return "Öffnet die kompakte Bogen-Werkzeugpalette an der Hover-Position."
        case .undo:
            return "Macht den letzten Schritt auf der Zeichenfläche rückgängig."
        case .toggleEraser:
            return "Wechselt zwischen Radierer und dem zuvor benutzten Werkzeug."
        case .none:
            return "Die Geste löst in der App keine Aktion aus."
        }
    }
}

/// Hinweise, welche Pencil-Modelle eine Geste überhaupt liefern.
public enum PencilGestureCompatibility {
    public static let squeezeSummary = "Squeeze ist nur beim Apple Pencil Pro (iPadOS 17.5+) verfügbar."
    public static let doubleTapSummary = "Doppeltipp gibt es beim Apple Pencil (2. Generation) und beim Apple Pencil Pro. Der USB-C-Pencil und der Lightning-Pencil der 1. Generation haben diese Geste nicht."
}
