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

/// Reine Regeln für die letzten drei Undo-Sitzungen und die Scrubber-Anzeige.
///
/// Wichtig für die Ruhe der Anzeige: Die **Vorräte** einer Scrubber-Sitzung
/// stehen beim Halten fest. Während des Ziehens wächst nichts nach – der Balken
/// und der Ring zeigen also immer dieselbe Länge, egal wie weit man zieht.
public enum NoteUndoSessionPolicy {
    public static let maximumSessions = 3
    public static let maximumSteps = 40
    public static let linearTickSpacing: Double = 32

    /// Ein voller Kreis entspricht einer Umdrehung. Jeder Schritt hat einen
    /// **festen** Winkel: Gibt es weniger Schritte, ist der Ring ein kürzerer
    /// Teilbogen statt auf 360° gestreckt. Gibt es mehr Schritte als Stufen,
    /// dreht man einfach weiter – bis zum letzten gespeicherten Schritt.
    public static let circularSweepAngle: Double = 2 * .pi
    /// So viele Rückgängig-Stufen passen auf eine Umdrehung (18° je Stufe).
    public static let circularMaxTicks = 20

    /// Fester Winkel eines Schritts (unabhängig von der Anzahl).
    public static func circularStepAngle() -> Double {
        circularSweepAngle / Double(circularMaxTicks)
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

    /// Die hervorgehobene Stufe des Rings nach `applied` rückgängig gemachten
    /// Schritten. `0` heißt: noch nichts angewandt, der Knopf steht auf der
    /// Startposition. Nach einer **vollen Umdrehung** gehört die Hervorhebung
    /// auf die letzte Stufe – sonst sähe es aus, als wäre nichts passiert.
    public static func circularHighlightedTick(
        applied: Int,
        maxTicks: Int = circularMaxTicks
    ) -> Int {
        guard applied > 0, maxTicks > 0 else { return 0 }
        let inRevolution = applied % maxTicks
        return inRevolution == 0 ? maxTicks : inRevolution
    }

    /// Sichtbare Stufen des linearen Balkens: die grauen Rückgängig-Stufen
    /// unter dem Knopf und die blauen Wiederhol-Stufen darüber. Beide Vorräte
    /// stehen beim Halten fest; lediglich die Wiederhol-Stufen, die man sich
    /// durch das Rückgängigmachen selbst verdient hat, kommen hinzu.
    public static func linearScrubTicks(
        undoCapacity: Int,
        redoCapacity: Int,
        appliedOffset: Int,
        availableHeight: Double,
        originY: Double
    ) -> (undo: Int, redo: Int) {
        let undo = linearTickCount(undoCount: undoCapacity, availableHeight: availableHeight)
        let redoReach = max(0, redoCapacity) + max(0, appliedOffset)
        return (undo, min(redoReach, linearRedoLimit(originY: originY)))
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
}
