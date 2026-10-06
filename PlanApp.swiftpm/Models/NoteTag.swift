import Foundation

/// Ein farbiger Tag, der einer Notiz zugewiesen werden kann
/// (z. B. „Hausaufgabe“, „Test“, „Wichtig“).
public struct NoteTag: Identifiable, Codable, Equatable, Hashable {
    public var id: UUID
    public var name: String
    public var colorHex: String

    public init(id: UUID = UUID(), name: String, colorHex: String) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
    }

    /// Anzeigename ohne führende/abschließende Leerzeichen; leere Namen
    /// werden als „Tag“ dargestellt, damit nie eine leere Pille entsteht.
    public var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Tag" : trimmed
    }

    /// Weiße Schrift auf dunklen Tag-Farben, dunkle Schrift auf hellen.
    public var usesLightText: Bool {
        NoteTagColor.isDark(hex: colorHex)
    }

    /// Vorschläge für neue Tags (Farbe wird reihum vergeben).
    public static let suggestedColors: [String] = [
        "#FF4D4D", "#FF8C24", "#FFD000", "#4CD948", "#4CA6FF",
        "#B388FF", "#F062B2", "#2B58BA", "#0B7A1C", "#A32020",
        "#00627C", "#6531A3", "#9E9E9E", "#1E1E1E"
    ]
}

/// Einstellungen des Tag-Systems (Einstellungen → „Tag-System“).
public struct NoteTagSettings: Codable, Equatable {
    /// Maximale Anzahl an Tags.
    public static let maximumTagCount = 20

    /// Standardmäßig **aus**: Ohne aktives Tag-System erscheinen weder die
    /// „+ Tag hinzufügen“-Pille in Notizen noch Filter oder Vorschau-Tags.
    public var isEnabled: Bool
    /// Reihenfolge = Anzeigereihenfolge (Auswahl in der Notiz, Filterleiste).
    public var tags: [NoteTag]

    public init(isEnabled: Bool = false, tags: [NoteTag] = []) {
        self.isEnabled = isEnabled
        self.tags = Array(tags.prefix(NoteTagSettings.maximumTagCount))
    }

    private enum CodingKeys: String, CodingKey {
        case isEnabled, tags
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? false
        let decodedTags = try container.decodeIfPresent([NoteTag].self, forKey: .tags) ?? []
        self.tags = Array(decodedTags.prefix(NoteTagSettings.maximumTagCount))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(tags, forKey: .tags)
    }

    public var canAddTag: Bool {
        tags.count < NoteTagSettings.maximumTagCount
    }

    public func tag(withID id: UUID?) -> NoteTag? {
        guard let id else { return nil }
        return tags.first(where: { $0.id == id })
    }

    /// Nächste noch nicht verwendete Vorschlagsfarbe.
    public var nextSuggestedColorHex: String {
        let used = Set(tags.map { $0.colorHex.uppercased() })
        if let free = NoteTag.suggestedColors.first(where: { !used.contains($0.uppercased()) }) {
            return free
        }
        return NoteTag.suggestedColors[tags.count % NoteTag.suggestedColors.count]
    }
}

/// Reine Farb-Mathematik für Tags – ohne UIKit, damit sie auch in den
/// Regressions-Tests (Linux/`swiftc`) läuft.
public enum NoteTagColor {
    /// Relative Luminanz (sRGB) eines Hex-Farbwerts; `nil` bei ungültigem Format.
    public static func luminance(hex: String) -> Double? {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("#") { cleaned.removeFirst() }
        guard cleaned.count == 6, let value = UInt32(cleaned, radix: 16) else { return nil }
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        func linear(_ c: Double) -> Double {
            c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
    }

    /// Dunkle Farben bekommen weiße Schrift. Die Grenze liegt bewusst etwas
    /// über dem WCAG-Mittelwert, damit kräftige Mitteltöne (Königsblau,
    /// Waldgrün) noch weiße Schrift erhalten.
    public static func isDark(hex: String) -> Bool {
        guard let luminance = luminance(hex: hex) else { return true }
        return luminance < 0.45
    }
}
