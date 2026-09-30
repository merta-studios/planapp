import Foundation

/// Ein frei bewegliches Textfeld auf der Zeichenfläche einer Stunden-Notiz.
/// Koordinaten sind in Punkt-Koordinaten der Zeichenfläche (unskaliert).
public struct NoteTextBox: Identifiable, Codable, Equatable {
    public var id: UUID
    public var text: String
    public var x: Double        // linke obere Ecke, X
    public var y: Double        // linke obere Ecke, Y
    public var width: Double    // Breite des Feldes (Text bricht automatisch um)
    public var fontSize: Double

    public init(
        id: UUID = UUID(),
        text: String = "",
        x: Double,
        y: Double,
        width: Double = 240,
        fontSize: Double = 17
    ) {
        self.id = id
        self.text = text
        self.x = x
        self.y = y
        self.width = width
        self.fontSize = fontSize
    }
}
