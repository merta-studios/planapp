import Foundation

/// Einstellungen für die im Stundenplan-Block angezeigten Elemente
public struct BlockDisplaySettings: Codable, Equatable {
    // Der fette Fachname ist IMMER standardmäßig sichtbar und kann nicht entfernt werden
    public var showTeacher: Bool             // Lehrer anzeigen (anpassbar)
    public var showRoom: Bool                // Raum anzeigen (anpassbar)
    public var showNotesPreview: Bool        // Zeichnungs-/Notizenvorschau anzeigen
    /// Tags der Notiz anzeigen – im Stunden-Block, in der Notiz-Kopfzeile und
    /// in den Karten der „Nur Notizen“-Übersicht. Standardmäßig **an**.
    public var showTags: Bool
    public var showSubstitutionDetails: Bool // Vertretungsdetails anzeigen
    public var showKlasse: Bool              // Klassenbezeichnung anzeigen

    public init(
        showTeacher: Bool = true,
        showRoom: Bool = true,
        showNotesPreview: Bool = true,
        showTags: Bool = true,
        showSubstitutionDetails: Bool = true,
        showKlasse: Bool = false
    ) {
        self.showTeacher = showTeacher
        self.showRoom = showRoom
        self.showNotesPreview = showNotesPreview
        self.showTags = showTags
        self.showSubstitutionDetails = showSubstitutionDetails
        self.showKlasse = showKlasse
    }

    /// `showTimes` bleibt als veralteter Schlüssel erhalten: Frühere
    /// Speicherstände kannten „Uhrzeiten direkt im Block anzeigen“. Der Schalter
    /// wird nicht mehr gelesen und beim Speichern nicht mehr geschrieben.
    private enum CodingKeys: String, CodingKey {
        case showTeacher, showRoom, showNotesPreview, showTags
        case showSubstitutionDetails, showKlasse
        case showTimes
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Alle Werte mit Voreinstellung lesen: Ältere Speicherstände (und
        // Sicherungen) kennen einzelne Schlüssel noch nicht.
        self.showTeacher = try container.decodeIfPresent(Bool.self, forKey: .showTeacher) ?? true
        self.showRoom = try container.decodeIfPresent(Bool.self, forKey: .showRoom) ?? true
        self.showNotesPreview = try container.decodeIfPresent(Bool.self, forKey: .showNotesPreview) ?? true
        self.showTags = try container.decodeIfPresent(Bool.self, forKey: .showTags) ?? true
        self.showSubstitutionDetails = try container.decodeIfPresent(Bool.self, forKey: .showSubstitutionDetails) ?? true
        self.showKlasse = try container.decodeIfPresent(Bool.self, forKey: .showKlasse) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(showTeacher, forKey: .showTeacher)
        try container.encode(showRoom, forKey: .showRoom)
        try container.encode(showNotesPreview, forKey: .showNotesPreview)
        try container.encode(showTags, forKey: .showTags)
        try container.encode(showSubstitutionDetails, forKey: .showSubstitutionDetails)
        try container.encode(showKlasse, forKey: .showKlasse)
    }

    public static var `default`: BlockDisplaySettings {
        BlockDisplaySettings()
    }
}
