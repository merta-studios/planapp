import Foundation

/// Gemeinsame, ohne UIKit testbare Regeln für die Zoom-Animation einer Notiz
/// aus einem Stundenblock (und zurück). Ein unplausibler Quellrahmen – typisch
/// beim allerersten Layout – würde die Karte sonst aus einem Punkt aufblasen
/// oder beim Schließen winzig im Block landen.
public enum HeroTransitionPolicy {
    public static let minimumWidth: Double = 28
    public static let minimumHeight: Double = 20
    public static let maximumAbsOrigin: Double = 20_000

    public static func isPlausibleSourceFrame(
        x: Double,
        y: Double,
        width: Double,
        height: Double
    ) -> Bool {
        guard x.isFinite, y.isFinite, width.isFinite, height.isFinite else { return false }
        guard width >= minimumWidth, height >= minimumHeight else { return false }
        guard abs(x) < maximumAbsOrigin, abs(y) < maximumAbsOrigin else { return false }
        return true
    }

    /// Rechnet einen Fenster-Rahmen in die lokalen Koordinaten eines Overlays um.
    public static func localFrame(
        windowX: Double,
        windowY: Double,
        width: Double,
        height: Double,
        overlayOriginX: Double,
        overlayOriginY: Double
    ) -> (x: Double, y: Double, width: Double, height: Double) {
        (
            x: windowX - overlayOriginX,
            y: windowY - overlayOriginY,
            width: width,
            height: height
        )
    }
}

/// Wann eine Notiz wirklich gespeichert werden darf. Ein Tag allein erzeugt
/// keinen Stundenblock – leere Notizen mit Tag werden verworfen.
public enum NoteContentPolicy {
    public static func shouldPersist(hasInk: Bool, hasText: Bool) -> Bool {
        hasInk || hasText
    }
}

/// Reine Regeln für die letzten drei Undo-Sitzungen und die Scrubber-Ticks.
public enum NoteUndoSessionPolicy {
    public static let maximumSessions = 3
    public static let maximumSteps = 40
    public static let linearTickSpacing: Double = 32

    /// Ein voller Kreis entspricht einer Umdrehung. Jeder Schritt hat einen
    /// **festen** Winkel: Gibt es weniger Schritte, ist der neue Kreisrand
    /// einfach kürzer (Teilbogen) statt auf 360° gestreckt. Gibt es mehr
    /// Schritte, läuft der Scrubber einfach **mehrere Umdrehungen** weiter –
    /// bis zum letzten gespeicherten Schritt.
    public static let circularSweepAngle: Double = 2 * .pi
    /// So viele Undo-Stufen passen auf eine Umdrehung (18° je Stufe).
    public static let circularMaxTicks = 20

    /// Fester Winkel eines Schritts (unabhängig von der Anzahl).
    public static func circularStepAngle(undoCount: Int = 0) -> Double {
        circularSweepAngle / Double(circularMaxTicks)
    }

    /// LRU: der neueste Schlüssel steht vorn, Duplikate entfallen, Maximum drei.
    public static func trimmedKeys(_ keys: [String], inserting newest: String) -> [String] {
        var result = [newest]
        for key in keys where key != newest {
            result.append(key)
            if result.count == maximumSessions { break }
        }
        return result
    }

    /// So viele Undo-Ticks passen in die verfügbare Höhe (oder alle, wenn weniger).
    public static func linearTickCount(
        undoCount: Int,
        availableHeight: Double,
        tickSpacing: Double = linearTickSpacing
    ) -> Int {
        guard undoCount > 0, availableHeight > 0, tickSpacing > 0 else { return 0 }
        return min(undoCount, Int(availableHeight / tickSpacing))
    }

    /// Stufen einer einzelnen Umdrehung – höchstens `circularMaxTicks`.
    public static func circularTickCount(undoCount: Int, maxTicks: Int = circularMaxTicks) -> Int {
        min(max(0, undoCount), max(0, maxTicks))
    }

    /// Wie viele Wiederhol-Stufen über den Knopf des linearen Balkens passen.
    /// Der Platz bis zur Oberkante begrenzt die Anzeige – so läuft der Balken
    /// nie aus dem Bild.
    public static func linearRedoLimit(
        originY: Double,
        spacing: Double = linearTickSpacing
    ) -> Int {
        guard originY.isFinite, spacing > 0 else { return 0 }
        return max(0, Int(max(0, originY - 40) / spacing))
    }

    /// Sichtbare Stufen: die in dieser Sitzung bereits angewandten Schritte
    /// **plus** die jetzt noch möglichen. Wird bei jeder Bewegung neu
    /// berechnet, damit die Anzeige nie einen veralteten Stand zeigt.
    public static func scrubTickCount(applied: Int, available: Int, limit: Int? = nil) -> Int {
        let total = max(0, applied) + max(0, available)
        guard let limit else { return total }
        return min(total, max(0, limit))
    }

    /// Wie viele Umdrehungen der Kreis-Scrubber für so viele Schritte braucht
    /// (0 ohne Schritte).
    public static func circularRevolutionCount(
        undoCount: Int,
        maxTicks: Int = circularMaxTicks
    ) -> Int {
        guard undoCount > 0, maxTicks > 0 else { return 0 }
        return (undoCount + maxTicks - 1) / maxTicks
    }

    /// Füllstände der zusätzlichen Umdrehungen (jeder Wert in Stufen, höchstens
    /// `circularMaxTicks`). Die **laufende** Umdrehung steht nicht in dieser
    /// Liste – für sie gibt es die Ticks auf dem Ring selbst. So bleibt
    /// sichtbar, dass nach dem vollen Kreis noch weitere Schritte möglich
    /// sind (mehrere Umdrehungen bis zum letzten gespeicherten Schritt).
    public static func circularOverflowTicks(
        applied: Int,
        available: Int,
        maxTicks: Int = circularMaxTicks
    ) -> [Int] {
        guard maxTicks > 0 else { return [] }
        let openInCurrentRevolution = max(0, maxTicks - max(0, applied))
        var remaining = max(0, available) - openInCurrentRevolution
        var result: [Int] = []
        while remaining > 0 {
            result.append(min(maxTicks, remaining))
            remaining -= maxTicks
        }
        return result
    }
}
