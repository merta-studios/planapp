import Foundation

/// Reine, ohne UIKit testbare Regeln für Gesten, Layout und Filter.
public enum InteractionPolicies {
    /// Der runde Undo-Scrubber läuft vom Rückgängig-Knopf weg von den anderen
    /// Werkzeugen (negativer Winkel). Bei der üblichen, nach oben geöffneten
    /// Kreis-Bar liegt der Knopf links – die grauen Striche beginnen damit
    /// links von der Bar und nicht rechts in die anderen Tasten hinein.
    public static let circularUndoSweepSign: Double = -1

    /// Der neue runde Balken ist deutlich dicker als die früheren 44 pt.
    public static let circularRingLineWidth: Double = 72

    public static func circularTickAngle(
        startAngle: Double,
        step: Int,
        stepAngle: Double,
        sweepSign: Double = circularUndoSweepSign
    ) -> Double {
        startAngle + Double(step) * stepAngle * sweepSign
    }

    /// Der Balken beginnt im Winkel des Rückgängig-Knopfs, nicht einen
    /// Vierteldreh daneben.
    public static func circularRingStartsAtButton(buttonAngle: Double, ringStartAngle: Double) -> Bool {
        guard buttonAngle.isFinite, ringStartAngle.isFinite else { return false }
        var delta = buttonAngle - ringStartAngle
        while delta > .pi { delta -= 2 * .pi }
        while delta < -.pi { delta += 2 * .pi }
        return abs(delta) < 0.000_1
    }

    /// Ob die obere Werkzeugleiste zu breit für den Bildschirm ist und deshalb
    /// dünner plus seitlich scrollbar werden muss.
    public static func usesCompactScrollingToolbar(availableWidth: Double, contentWidth: Double) -> Bool {
        guard availableWidth.isFinite, contentWidth.isFinite, availableWidth > 0, contentWidth > 0 else {
            return false
        }
        return availableWidth + 0.5 < contentWidth
    }

    /// Geschätzte Breite der normalen (nicht verdichteten) Zeichenleiste.
    public static func estimatedToolbarContentWidth(
        penSlots: Int,
        markerSlots: Int,
        isPhone: Bool
    ) -> Double {
        let slots = Double(max(0, penSlots))
        if isPhone {
            // Lieber etwas zu breit schätzen, damit schmale iPhones scrollen
            // statt die Leiste abzuschneiden.
            return 420 + slots * 44
        }
        let pen = 56 + slots * 42
        let marker = 56 + Double(max(0, markerSlots)) * 42
        // Text, Radierer, Lasso, Dicke, Rückgängig, Wiederholen, Mehr, Abstände.
        return pen + marker + 430
    }

    /// Mini-Tag-Auswahl: nach unten, sobald über dem Knopf nicht genug Platz ist.
    public static let tagPickerMinimumComfortableHeight: Double = 240

    public static func tagPickerPlacesBelow(spaceAbove: Double, spaceBelow: Double) -> Bool {
        guard spaceAbove.isFinite, spaceBelow.isFinite else { return false }
        if spaceAbove >= tagPickerMinimumComfortableHeight { return false }
        return spaceBelow + 0.5 >= spaceAbove
    }

    /// Rahmen der Mini-Auswahl. Titel und „Tag entfernen“ bleiben außerhalb
    /// der scrollenden Liste, deshalb ist die Höhe nach oben begrenzt.
    public static func tagPickerFrame(
        buttonMinX: Double,
        buttonMaxX: Double,
        buttonMinY: Double,
        buttonMaxY: Double,
        containerWidth: Double,
        containerHeight: Double,
        contentHeight: Double
    ) -> (x: Double, y: Double, width: Double, height: Double, placesBelow: Bool) {
        let margin = 12.0
        let gap = 8.0
        let width = min(332, max(200, containerWidth - margin * 2))
        let spaceAbove = max(0, buttonMinY - margin)
        let spaceBelow = max(0, containerHeight - buttonMaxY - margin)
        let below = tagPickerPlacesBelow(spaceAbove: spaceAbove, spaceBelow: spaceBelow)
        let available = max(140, (below ? spaceBelow : spaceAbove) - gap)
        let height = min(max(160, contentHeight), available)
        let rawY = below ? buttonMaxY + gap : buttonMinY - gap - height
        let y = min(max(margin, rawY), max(margin, containerHeight - margin - height))
        let midX = (buttonMinX + buttonMaxX) / 2
        let rawX = midX - width / 2
        let x = min(max(margin, rawX), max(margin, containerWidth - margin - width))
        return (x, y, width, height, below)
    }

    /// „Jetzt“-Sprung, sobald die grüne Linie den sichtbaren Bereich verlassen hat.
    public static func shouldShowNowJumpButton(
        lineMinY: Double?,
        lineMaxY: Double?,
        viewportHeight: Double
    ) -> Bool {
        guard viewportHeight.isFinite, viewportHeight > 0 else { return false }
        guard let lineMinY, let lineMaxY, lineMinY.isFinite, lineMaxY.isFinite else {
            // Nicht im sichtbaren Lazy-Bereich: die Linie ist weg.
            return true
        }
        return lineMaxY < 1 || lineMinY > viewportHeight - 1
    }

    public static func nowJumpPointsDown(lineMidY: Double?, viewportHeight: Double) -> Bool {
        guard let lineMidY, lineMidY.isFinite, viewportHeight.isFinite else { return true }
        return lineMidY >= viewportHeight / 2
    }

    /// Beim Wechsel in „Nur Notizen“ gelten keine Filter aus der vorherigen Sitzung.
    public static func shouldResetFiltersWhenEnteringNotesOnly(previousMode: String, newMode: String) -> Bool {
        newMode == "notesOnly" && previousMode != "notesOnly"
    }
}

// MARK: - Scrubber-Mathematik

public enum UndoScrubMath {
    /// Der lineare Scrubber kennt rückgängige Schritte (`0 ... undoTicks`)
    /// und, über den Startpunkt hinaus, Wiederholungen
    /// (`-redoTicks ... -1`): Zieht man den Finger zurück, werden die in
    /// dieser Sitzung rückgängig gemachten Schritte wiederhergestellt.
    public static func linearOffset(
        translationY: CGFloat,
        undoTicks: Int,
        redoTicks: Int = 0,
        spacing: CGFloat = CGFloat(NoteUndoSessionPolicy.linearTickSpacing)
    ) -> Int {
        guard spacing > 0, undoTicks > 0 || redoTicks > 0 else { return 0 }
        let raw = Int((translationY / spacing).rounded())
        return min(max(raw, -max(0, redoTicks)), max(0, undoTicks))
    }

    /// Kontinuierlicher Winkel-Zuwachs zwischen zwei aufeinanderfolgenden
    /// Positionen, in den Bereich (-π, π] gefaltet. So bleibt auch ein voller
    /// Umlauf stabil: Es wird der *Weg* gemessen, nicht die Position, und an
    /// der Kreismitte / der Startposition springt nichts um.
    public static func normalizedAngleDelta(from last: CGFloat, to current: CGFloat) -> CGFloat {
        guard last.isFinite, current.isFinite else { return 0 }
        var delta = current - last
        while delta > .pi { delta -= 2 * .pi }
        while delta <= -.pi { delta += 2 * .pi }
        return delta
    }

    /// Winkelgeste auf dem vollen Kreis. `accumulatedAngle` ist die
    /// kontinuierlich mitaddierte Gesamtdrehung seit Scrub-Start (vorzeichen-
    /// getreu in Kreis-Koordinaten, UIKit-Convention: positiv = im
    /// Uhrzeigersinn). In Bogenrichtung drehen macht rückgängig
    /// (`0 ... undoTicks`), gegen die Bogenrichtung drehen stellt die in
    /// dieser Sitzung rückgängig gemachten Schritte wieder her
    /// (`-redoTicks ... -1`). Die Kreisticks laufen über genau einen vollen
    /// Umlauf, deshalb laufen beide Richtungen über denselben Bogen – der
    /// Knopf wandert nur spiegelbildlich.
    public static func circularOffset(
        accumulatedAngle: CGFloat,
        undoTicks: Int,
        stepAngle: CGFloat,
        redoTicks: Int = 0,
        undoSweepSign: CGFloat = CGFloat(InteractionPolicies.circularUndoSweepSign)
    ) -> Int {
        guard stepAngle > 0, undoSweepSign != 0, accumulatedAngle.isFinite,
              undoTicks > 0 || redoTicks > 0 else {
            return 0
        }
        let sweep = CGFloat(max(0, undoTicks)) * stepAngle
        let redoSweep = CGFloat(max(0, redoTicks)) * stepAngle
        // In Bogenrichtung positiv drehen.
        let signed = accumulatedAngle * undoSweepSign
        let clamped = min(max(signed, -redoSweep), sweep)
        let raw = Int((clamped / stepAngle).rounded())
        return min(max(raw, -max(0, redoTicks)), max(0, undoTicks))
    }
}
