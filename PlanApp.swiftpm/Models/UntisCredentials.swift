import Foundation

/// Zugangsdaten und Verbindungsstatus für die WebUntis JSON-RPC API
public struct UntisCredentials: Codable, Equatable {
    public var server: String         // z.B. "ikarus.webuntis.com" oder Schulserver
    public var school: String         // Schulname in WebUntis (z.B. "gym-musterstadt")
    public var user: String           // Benutzername
    public var password: String       // Passwort oder API-Token
    public var lastSyncDate: Date?    // Zeitpunkt der letzten erfolgreichen Synchronisierung
    public var autoSyncOnLaunch: Bool // Automatisch beim App-Start aktualisieren

    public init(
        server: String = "",
        school: String = "",
        user: String = "",
        password: String = "",
        lastSyncDate: Date? = nil,
        autoSyncOnLaunch: Bool = true
    ) {
        self.server = server
        self.school = school
        self.user = user
        self.password = password
        self.lastSyncDate = lastSyncDate
        self.autoSyncOnLaunch = autoSyncOnLaunch
    }

    /// Prüft, ob mindestens Server und Schule eingegeben wurden
    public var isConfigured: Bool {
        return !cleanServer.isEmpty && !cleanSchool.isEmpty
    }

    /// Prüft, ob die Zugangsdaten wirklich vollständig sind. Fehlt eines der
    /// vier Felder, kann die WebUntis-API nicht sinnvoll abgefragt werden – die
    /// App zeigt dann den Einrichtungs-Guide statt eines leeren Stundenplans.
    public var hasCompleteCredentials: Bool {
        return isConfigured && !cleanUser.isEmpty && !cleanPassword.isEmpty
    }

    /// Bereinigt den Server-String (entfernt https://, Schrägstriche etc.)
    public var cleanServer: String {
        var s = server.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.lowercased().hasPrefix("https://") {
            s = String(s.dropFirst(8))
        } else if s.lowercased().hasPrefix("http://") {
            s = String(s.dropFirst(7))
        }
        if let idx = s.firstIndex(of: "/") {
            s = String(s[..<idx])
        }
        if let idx = s.firstIndex(of: "?") {
            s = String(s[..<idx])
        }
        return s
    }

    /// Bereinigt den Schulnamen
    public var cleanSchool: String {
        return school.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Bereinigt den Benutzernamen
    public var cleanUser: String {
        return user.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Bereinigt das Passwort
    public var cleanPassword: String {
        return password.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Erstellt die vollständige JSON-RPC 2.0 URL
    public var rpcEndpointURL: URL? {
        guard !cleanServer.isEmpty, !cleanSchool.isEmpty else { return nil }
        var components = URLComponents()
        components.scheme = "https"
        components.host = cleanServer
        components.path = "/WebUntis/jsonrpc.do"
        components.queryItems = [URLQueryItem(name: "school", value: cleanSchool)]
        return components.url
    }
}
