import Foundation

/// Hintergrund-Raster der Zeichenfläche einer Notiz.
public enum NoteBackgroundStyle: String, Codable, CaseIterable, Identifiable, Equatable, Hashable {
    case blank
    case dotted
    case lined
    case grid

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .blank:
            return "Leer"
        case .dotted:
            return "Gepunktet"
        case .lined:
            return "Liniert"
        case .grid:
            return "Kariert"
        }
    }

    public var systemImage: String {
        switch self {
        case .blank:
            return "rectangle"
        case .dotted:
            return "circle.grid.2x2"
        case .lined:
            return "line.3.horizontal"
        case .grid:
            return "square.grid.3x3"
        }
    }
}
