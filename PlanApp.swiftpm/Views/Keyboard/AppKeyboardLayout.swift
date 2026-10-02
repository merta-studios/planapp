import Foundation

/// Fensterbezogene Maße der App-Tastatur. Nicht von der Größe eines Sheets
/// oder von UIScreen.main abhängig (Rotation, Split View und Stage Manager).
enum AppKeyboardLayout {
    static let topBarHeight: CGFloat = 32
    static let rowSpacing: CGFloat = 6
    static let topPadding: CGFloat = 6
    static let bottomPadding: CGFloat = 8

    /// Abstand der schwebenden Tastatur zum Rand der Ansicht, über der sie
    /// liegt (Zeichenfläche). Der untere Abstand kommt zum Home-Indikator dazu.
    static let floatingHorizontalMargin: CGFloat = 10
    static let floatingBottomMargin: CGFloat = 8
    static let floatingCornerRadius: CGFloat = 16

    /// Die Tastatur belegt die untere Hälfte des aktuellen App-Fensters.
    /// Bei einem Hardware-Kurzbefehlsstreifen bzw. einer zusätzlich sichtbaren
    /// Systemtastatur („Immer anzeigen“) im verbleibenden Bereich andocken.
    static func frame(in bounds: CGRect, systemKeyboardFrame: CGRect = .zero) -> CGRect {
        guard isValid(bounds) else { return .zero }
        var availableBounds = bounds
        if isValid(systemKeyboardFrame) {
            let overlap = bounds.intersection(systemKeyboardFrame)
            // Eine schwebende iPad-Tastatur verkleinert das Fenster nicht.
            if !overlap.isNull, !overlap.isEmpty,
               overlap.width >= bounds.width * 0.9,
               overlap.maxY >= bounds.maxY - 1 {
                availableBounds.size.height = max(0, overlap.minY - bounds.minY)
            }
        }
        let height = availableBounds.height / 2
        return CGRect(
            x: availableBounds.minX,
            y: availableBounds.maxY - height,
            width: availableBounds.width,
            height: height
        )
    }

    /// Nur den tatsächlich verdeckten Teil einer Ansicht freihalten. Ein
    /// kleines Einstellungen-Sheet braucht nicht die komplette Tastaturhöhe
    /// als Innenabstand; ein Sheet oberhalb der Tastatur braucht gar keinen.
    static func bottomOverlap(keyboardFrame: CGRect, viewport: CGRect) -> CGFloat {
        guard isValid(keyboardFrame), isValid(viewport) else { return 0 }
        let intersection = viewport.intersection(keyboardFrame)
        guard !intersection.isNull, !intersection.isEmpty else { return 0 }
        return intersection.height
    }

    /// Höhe der in die Ansicht eingebetteten Tastatur.
    ///
    /// Vier komfortable Tastenreihen (~58 pt), auf kleinen Fenstern
    /// (iPhone-Querformat) begrenzt auf höchstens 42 % der Fensterhöhe,
    /// mindestens aber 240 pt. Der untere Safe-Area-Abstand (Home-Indikator)
    /// kommt hinzu, damit die Tasten darüber liegen und nur der Hintergrund
    /// bis an den Bildschirmrand reicht.
    static func embeddedHeight(windowHeight: CGFloat, bottomInset: CGFloat) -> CGFloat {
        let inset = max(0, bottomInset)
        let preferred = topBarHeight + topPadding + bottomPadding
            + CGFloat(4) * rowSpacing + 4 * 58 + inset
        guard windowHeight.isFinite, windowHeight > 0 else { return preferred }
        return min(preferred, max(240, windowHeight * 0.42))
    }

    /// Höhe der **schwebenden** Tastatur (Zeichenfläche). Sie ist genauso
    /// groß wie die eingebettete Variante und reserviert denselben
    /// Home-Indikator-Abstand – sie wird nur über den Inhalt gelegt, statt
    /// ihn zu verschieben. Dadurch behält die Notiz Größe und Position.
    static func floatingHeight(windowHeight: CGFloat, bottomInset: CGFloat) -> CGFloat {
        embeddedHeight(windowHeight: windowHeight, bottomInset: bottomInset)
    }

    /// Vier Tastenreihen füllen den verfügbaren Bereich bis oberhalb des
    /// Home-Indikators, statt auf großen iPads nur einen schmalen Streifen
    /// mit festen 50-pt-Tasten zu ergeben.
    static func keyHeight(totalHeight: CGFloat, bottomInset: CGFloat, rowCount: Int) -> CGFloat {
        guard totalHeight.isFinite, bottomInset.isFinite, rowCount > 0 else { return 0 }
        let reservedHeight = topBarHeight + topPadding + bottomPadding
            + max(0, bottomInset) + CGFloat(rowCount) * rowSpacing
        return max(0, (totalHeight - reservedHeight) / CGFloat(rowCount))
    }

    private static func isValid(_ rect: CGRect) -> Bool {
        rect.origin.x.isFinite && rect.origin.y.isFinite
            && rect.width.isFinite && rect.height.isFinite
            && rect.width > 0 && rect.height > 0
    }
}
