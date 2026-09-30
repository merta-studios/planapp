import Foundation

/// Einstellungen für die im Stundenplan-Block angezeigten Elemente
public struct BlockDisplaySettings: Codable, Equatable {
    // Der fette Fachname ist IMMER standardmäßig sichtbar und kann nicht entfernt werden
    public var showTeacher: Bool             // Lehrer anzeigen (anpassbar)
    public var showRoom: Bool                // Raum anzeigen (anpassbar)
    public var showNotesPreview: Bool        // Zeichnungs-/Notizenvorschau anzeigen
    public var showTimes: Bool               // Beginn- und Endzeit im Block anzeigen
    public var showSubstitutionDetails: Bool // Vertretungsdetails anzeigen
    public var showKlasse: Bool              // Klassenbezeichnung anzeigen

    public init(
        showTeacher: Bool = true,
        showRoom: Bool = true,
        showNotesPreview: Bool = true,
        showTimes: Bool = false,
        showSubstitutionDetails: Bool = true,
        showKlasse: Bool = false
    ) {
        self.showTeacher = showTeacher
        self.showRoom = showRoom
        self.showNotesPreview = showNotesPreview
        self.showTimes = showTimes
        self.showSubstitutionDetails = showSubstitutionDetails
        self.showKlasse = showKlasse
    }

    public static var `default`: BlockDisplaySettings {
        BlockDisplaySettings()
    }
}
