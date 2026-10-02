import Foundation

/// Fensterbezogene Maße der App-Tastatur. Nicht von der Größe eines Sheets
/// oder von UIScreen.main abhängig (Rotation, Split View und Stage Manager).
enum AppKeyboardLayout {
    static let topBarHeight: CGFloat = 32
    static let rowSpacing: CGFloat = 6
    static let topPadding: CGFloat = 6
    static let bottomPadding: CGFloat = 8

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
