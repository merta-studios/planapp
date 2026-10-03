import Foundation

/// Ein gemeinsamer Zeitmaßstab für Statusanzeige, Vordergrund-Prüfung und Timer.
/// Fehler ändern niemals den Zeitpunkt des letzten erfolgreichen Abrufs.
enum TimetableRefreshPolicy {
    static let staleInterval: TimeInterval = 60 * 60
    static let regularInterval: TimeInterval = 5 * 60
    static let urgentRetryInterval: TimeInterval = 30
    static let checkInterval: TimeInterval = 15

    static func isStale(lastSuccess: Date?, now: Date) -> Bool {
        guard let lastSuccess else { return false }
        return now.timeIntervalSince(lastSuccess) > staleInterval
    }

    static func shouldRefresh(lastSuccess: Date?, lastAttempt: Date?, now: Date) -> Bool {
        let urgent = lastSuccess == nil || isStale(lastSuccess: lastSuccess, now: now)
        let retryInterval = urgent ? urgentRetryInterval : regularInterval

        // Timeline, Timer und App-Aktivierung dürfen keine Anfrage-Schleife
        // starten. Nach einem Fehler wird höchstens alle 30 Sekunden versucht.
        if let lastAttempt, now.timeIntervalSince(lastAttempt) < retryInterval {
            return false
        }
        guard let lastSuccess else { return true }
        return urgent || now.timeIntervalSince(lastSuccess) >= regularInterval
    }
}
