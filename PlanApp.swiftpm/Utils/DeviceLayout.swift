import UIKit

/// Geräteklasse und daraus abgeleitete Layout-Entscheidungen.
///
/// Das iPad behält seine gewohnte Darstellung. Das iPhone bekommt einen
/// kompakten Stundenplan (schmalere Spalten, kleinere Schrift) und eine
/// reduzierte Zeichenfläche ohne Apple-Pencil-Werkzeuge: Dort gibt es nur
/// Lasso, Text und Radierer (per Finger); die Farben wirken als Textfarben.
public enum DeviceLayout {
    /// `true` auf dem iPhone (und iPod touch), `false` auf iPad/Mac.
    public static let isPhone: Bool = UIDevice.current.userInterfaceIdiom == .phone

    /// Breite, ab der der Stundenplan in die kompakte Darstellung wechselt
    /// (schmaler iPad-Split-View verhält sich wie ein iPhone).
    public static let compactTimetableWidthThreshold: CGFloat = 600

    /// Kompakter Stundenplan: immer auf dem iPhone, sonst nur bei sehr
    /// schmalen Fenstern.
    public static func usesCompactTimetable(width: CGFloat) -> Bool {
        guard width.isFinite, width > 0 else { return isPhone }
        return isPhone || width < compactTimetableWidthThreshold
    }

    /// Breite der Stundenspalte (Nummer + Uhrzeiten) links im Stundenplan.
    public static func periodColumnWidth(compact: Bool) -> CGFloat {
        compact ? 34 : 76
    }

    /// Höhe der Tages-Kopfzeile im Stundenplan.
    public static func timetableHeaderHeight(compact: Bool) -> CGFloat {
        compact ? 36 : 54
    }

    /// Mindesthöhe einer Stundenzeile.
    public static func minimumRowHeight(compact: Bool) -> CGFloat {
        compact ? 54 : 80
    }

    // MARK: - Kompakte Abstände & Radien (iPhone)

    /// Auf dem iPhone ist alles bewusst kleiner und enger, damit wirklich
    /// Platz für alles ist: kleinere Karten-Abstände und kleinere Rundungen.
    public static var settingsOuterPadding: CGFloat { isPhone ? 10 : 16 }
    public static var settingsInnerPadding: CGFloat { isPhone ? 8 : 14 }

    /// Karten-Rundung: auf dem iPhone 5 pt kleiner (mindestens 8).
    public static func cardCornerRadius(_ regular: CGFloat) -> CGFloat {
        isPhone ? max(8, regular - 5) : regular
    }

    /// Button-Rundung: auf dem iPhone 4 pt kleiner (mindestens 6).
    public static func buttonCornerRadius(_ regular: CGFloat) -> CGFloat {
        isPhone ? max(6, regular - 4) : regular
    }

    // MARK: - Mobile-spezifische Größen

    /// Schriftgrößen-Skalierung für das iPhone (alles 15% kleiner).
    public static var fontSizeScale: CGFloat { isPhone ? 0.85 : 1.0 }

    /// Kompaktere Abstände auf dem iPhone.
    public static var compactSpacing: CGFloat { isPhone ? 4 : 8 }
    public static var regularSpacing: CGFloat { isPhone ? 6 : 12 }

    /// Kleinere Icon-Größen auf dem iPhone.
    public static var iconSize: CGFloat { isPhone ? 14 : 18 }
    public static var smallIconSize: CGFloat { isPhone ? 11 : 14 }

    /// Kompaktere Button-Größen auf dem iPhone.
    public static var buttonHeight: CGFloat { isPhone ? 36 : 44 }
    public static var compactButtonHeight: CGFloat { isPhone ? 30 : 36 }

    /// Breite einer Tagesspalte. Kompakt füllen die fünf Tage die verfügbare
    /// Breite immer vollständig aus (kein horizontales Abschneiden mehr).
    public static func dayColumnWidth(availableWidth: CGFloat, compact: Bool) -> CGFloat {
        let periodWidth = periodColumnWidth(compact: compact)
        if compact {
            let horizontalPadding: CGFloat = 6     // 3 pt links + rechts
            let totalColumnSpacing: CGFloat = 4    // 4 Lücken à 1 pt
            return max(38, (availableWidth - horizontalPadding - periodWidth - totalColumnSpacing) / 5)
        }
        let horizontalPadding: CGFloat = 32
        let totalColumnSpacing: CGFloat = 20
        return max(120, (availableWidth - horizontalPadding - periodWidth - totalColumnSpacing) / 5)
    }
}
