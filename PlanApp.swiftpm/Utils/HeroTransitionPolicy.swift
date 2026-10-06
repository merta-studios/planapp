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

    /// Der runde Scrubber läuft einen **vollen** Kreis. Die Stufen verteilen
    /// sich über die kompletten 360°, und das Zurückdrehen an der Startposition
    /// ist erlaubt: Damit lassen sich genau die Schritte wiederherstellen, die
    /// in derselben Scrub-Sitzung rückgängig gemacht wurden (Redo). Sprünge
    /// über die Kreismitte gibt es nicht, weil der Winkel kontinuierlich
    /// mitaddiert wird und nicht pro Position neu berechnet wird.
    public static let circularSweepAngle: Double = 2 * .pi
    /// So viele Undo-Stufen passen auf den vollen Kreis (30° je Stufe bei
    /// 12 Schritten).
    public static let circularMaxTicks = 12

    /// Winkel eines einzelnen Schritts auf dem vollen Kreis. Die Stufen
    /// füllen den Kreis immer vollständig: Weniger Undo-Schritte bedeuten
    /// größere Abstände (z. B. 4 Schritte à 90°), mehr sind auf 12 begrenzt.
    public static func circularStepAngle(undoCount: Int) -> Double {
        let ticks = max(1, circularTickCount(undoCount: undoCount))
        return circularSweepAngle / Double(ticks)
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

    /// Höchstens `circularMaxTicks` Stufen – der Scrubber macht rückgängig
    /// (und innerhalb derselben Sitzung wiederherstellen).
    public static func circularTickCount(undoCount: Int, maxTicks: Int = circularMaxTicks) -> Int {
        min(max(0, undoCount), max(0, maxTicks))
    }
}
