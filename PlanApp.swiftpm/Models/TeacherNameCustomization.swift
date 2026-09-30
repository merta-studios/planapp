import Foundation

/// Manuelle Lehrer-Namen-Ersetzung.
///
/// Beispiel: Das System liefert „DÜCK“, angezeigt werden soll aber
/// „Frau Dückerhoff“. Die Liste bleibt vollständig manuell – es wird nichts
/// aus dem Stundenplan automatisch hinzugefügt.
public struct TeacherNameCustomization: Identifiable, Codable, Equatable, Hashable {
    public var id: UUID
    /// Kürzel bzw. Name, wie er vom Stundenplan-System/WebUntis kommt.
    public var systemAbbreviation: String
    /// Anzeigename, den die App statt des Systemwerts zeigen soll.
    public var displayName: String

    public init(
        id: UUID = UUID(),
        systemAbbreviation: String,
        displayName: String
    ) {
        self.id = id
        self.systemAbbreviation = systemAbbreviation.trimmingCharacters(in: .whitespacesAndNewlines)
        self.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
