import Foundation

/// Drei kompakte Karten auf normalen iPad-Breiten, zwei bzw. eine im schmalen
/// Split View und auf dem iPhone. Fensterbreite statt Geräteausrichtung ist
/// ausschlaggebend.
enum NotesOverviewLayout {
    static let nowLineID = "planapp_now_line"
    static let scrollSpace = "notesOverviewScroll"
    static let horizontalPadding: CGFloat = 14
    static let columnSpacing: CGFloat = 12
    static let rowSpacing: CGFloat = 12
    static let minimumCardWidth: CGFloat = 220

    /// iPhone: immer eine Karte pro Zeile – die Notiz-Vorschauen sind sonst
    /// zu klein, um etwas zu erkennen. Breitere Fenster (iPad) füllen bis zu
    /// drei Spalten.
    static func columnCount(for width: CGFloat, isPhone: Bool = false) -> Int {
        guard width.isFinite, width > 0 else { return 1 }
        if isPhone { return 1 }
        let available = max(0, width - 2 * horizontalPadding)
        let count = (available + columnSpacing) / (minimumCardWidth + columnSpacing)
        return Int(min(3, max(1, count.rounded(.down))))
    }

    /// Zerlegt eine chronologische Folge von Einträgen in Kartenzeilen mit
    /// höchstens `columnCount` Karten. `isPast` entscheidet, vor welchem Eintrag
    /// die „Jetzt“-Linie liegt; sie trennt immer zwei Zeilen – auch mitten in
    /// einer unvollständigen Kartenzeile. Reine Layout-Logik ohne SwiftUI,
    /// damit sie in den Regressions-Tests geprüft werden kann.
    static func rowPlan<Entry>(
        entries: [Entry],
        columnCount: Int,
        isPast: (Entry) -> Bool
    ) -> [RowPlanItem<Entry>] {
        let columns = max(1, columnCount)
        var rows: [RowPlanItem<Entry>] = []
        var pending: [Entry] = []
        var insertedNowLine = false

        func flush() {
            guard !pending.isEmpty else { return }
            rows.append(.cards(pending))
            pending.removeAll(keepingCapacity: true)
        }

        for entry in entries {
            if !insertedNowLine, !isPast(entry) {
                flush()
                rows.append(.nowLine)
                insertedNowLine = true
            }
            pending.append(entry)
            if pending.count == columns { flush() }
        }
        flush()
        if !insertedNowLine { rows.append(.nowLine) }
        return rows
    }

    enum RowPlanItem<Entry> {
        case nowLine
        case cards([Entry])

        var cardCount: Int {
            if case .cards(let entries) = self { return entries.count }
            return 0
        }

        var isNowLine: Bool {
            if case .nowLine = self { return true }
            return false
        }
    }
}
