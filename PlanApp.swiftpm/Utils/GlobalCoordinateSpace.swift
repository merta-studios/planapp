import SwiftUI

/// Eine einzige, app-weit stabile Koordinaten-Raum-Kennung für `GeometryProxy`
/// (`frame(in:)`) und `DragGesture(coordinateSpace:)`.
///
/// Sie wird für die Squeeze-Palette des Apple Pencil gebraucht: Die Hover-Pose
/// kommt in UIKit-View-Koordinaten an, die Palette liegt aber in einem
/// SwiftUI-Overlay. Mit einer gemeinsamen Kennung lassen sich beide sauber
/// ineinander umrechnen.
enum GlobalCoordinateSpace {
    static let name = "planapp.global"
}
