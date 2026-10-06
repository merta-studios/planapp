import Foundation

/// Zuletzt bekannter Apple-Pencil-Stand (Modellname + Akku). Wird gespeichert,
/// damit die Kopfzeile beim nächsten App-Start nicht leer ist und nicht erst
/// nach einem Squeeze „Apple Pencil Pro“ anzeigt.
public struct ApplePencilStatusSnapshot: Codable, Equatable {
    public var name: String
    public var batteryLevel: Int?
    public var updatedAt: Date

    public init(name: String, batteryLevel: Int? = nil, updatedAt: Date = Date()) {
        self.name = name
        self.batteryLevel = batteryLevel
        self.updatedAt = updatedAt
    }

    /// „Apple Pencil Pro“, wenn der BLE-Name oder ein Squeeze das Modell bestätigt.
    public static func resolvedName(fromPeripheralName peripheralName: String?, knownPro: Bool) -> String {
        if knownPro { return "Apple Pencil Pro" }
        guard let peripheralName, !peripheralName.isEmpty else { return "Apple Pencil" }
        if peripheralName.localizedCaseInsensitiveContains("Pro") {
            return "Apple Pencil Pro"
        }
        return peripheralName
    }
}
