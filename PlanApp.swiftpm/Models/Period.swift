import Foundation

/// Repräsentiert eine Unterrichtsstunde / Zeiteinheit im Stundenplan
public struct Period: Identifiable, Codable, Equatable, Hashable {
    public var id: String { "\(periodNumber)" }
    public var periodNumber: Int
    public var name: String
    public var startTime: String // z.B. "08:00"
    public var endTime: String   // z.B. "08:45"
    public var startMinutes: Int // Minuten ab Mitternacht für präzise Berechnungen
    public var endMinutes: Int

    public init(periodNumber: Int, name: String? = nil, startTime: String, endTime: String) {
        self.periodNumber = periodNumber
        self.name = name ?? "\(periodNumber)"
        self.startTime = startTime
        self.endTime = endTime
        self.startMinutes = Period.parseMinutes(from: startTime)
        self.endMinutes = Period.parseMinutes(from: endTime)
    }

    /// Berechnet Minuten seit 00:00 Uhr aus Strings wie "08:00", "8:00", "0800"
    public static func parseMinutes(from timeStr: String) -> Int {
        let clean = timeStr.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.contains(":") {
            let parts = clean.split(separator: ":")
            if parts.count >= 2, let h = Int(parts[0]), let m = Int(parts[1]) {
                return h * 60 + m
            }
        }
        if let val = Int(clean) {
            let h = val / 100
            let m = val % 100
            return h * 60 + m
        }
        return 0
    }

    /// Formatiert eine WebUntis-Ganzzahl-Uhrzeit (z.B. 800 -> "08:00", 1345 -> "13:45")
    public static func formatUntisTime(_ timeInt: Int) -> String {
        let h = timeInt / 100
        let m = timeInt % 100
        return String(format: "%02d:%02d", h, m)
    }

    /// Standard-Stundenraster für Schulen (1. bis 10. Stunde)
    public static var defaultPeriods: [Period] {
        [
            Period(periodNumber: 1, startTime: "08:00", endTime: "08:45"),
            Period(periodNumber: 2, startTime: "08:50", endTime: "09:35"),
            Period(periodNumber: 3, startTime: "09:55", endTime: "10:40"),
            Period(periodNumber: 4, startTime: "10:45", endTime: "11:30"),
            Period(periodNumber: 5, startTime: "11:45", endTime: "12:30"),
            Period(periodNumber: 6, startTime: "12:35", endTime: "13:20"),
            Period(periodNumber: 7, startTime: "13:40", endTime: "14:25"),
            Period(periodNumber: 8, startTime: "14:30", endTime: "15:15"),
            Period(periodNumber: 9, startTime: "15:20", endTime: "16:05"),
            Period(periodNumber: 10, startTime: "16:10", endTime: "16:55")
        ]
    }
}
