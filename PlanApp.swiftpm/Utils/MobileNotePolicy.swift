import Foundation

/// Wie eine Notiz auf den **zwei Geräteklassen** behandelt wird.
///
/// Auf dem iPad gibt es wie gewohnt den vollen Zeichenbereich (Handschrift,
/// Textfelder, Bilder). Auf dem iPhone gibt es ihn nicht mehr:
///
/// * Eine **Handy-Notiz** (`usesPhoneTextLayout`) ist ein schlichter Fließtext.
///   Sie lässt sich auf dem iPhone weiterhin öffnen und bearbeiten.
/// * Eine **Zeichen-Notiz** (Handschrift oder mit dem iPad erstellt) lässt sich
///   auf dem iPhone **nicht** öffnen. Ein Tipp zeigt nur die Optionen, wie sie
///   sonst beim gedrückt Halten erscheinen (Kopieren, Einfügen, Tag, Löschen …).
///   Sobald sie auf dem iPad geändert wurde, `updatedAt` also **neuer** ist als
///   der Zeitpunkt, an dem sie zuletzt eine Handy-Notiz war, bleibt sie
///   gesperrt (siehe `LessonNote.phoneLayoutConversionDate`).
///
/// Diese Datei bleibt bewusst **frei von UIKit/SwiftUI und von App-Modellen**,
/// damit sie in den Regressions-Tests (Linux/`swiftc`) mitläuft. Die Regeln,
/// die eine `LessonNote` brauchen, stehen in `MobileNoteConversion.swift`.
public enum MobileNotePolicy {
    /// Höchste bzw. kleinste Schriftgröße einer Handy-Notiz.
    public static let minimumPhoneFontSize: Double = 10
    public static let maximumPhoneFontSize: Double = 40

    /// Standard-Innenabstand des Textbereichs auf dem iPhone (pt).
    public static let phoneTextPadding: Double = 16

    /// Schriftgröße, mit der der Text einer Handy-Notiz angezeigt wird.
    public static func resolvedPhoneFontSize(
        stored: Double?,
        fallback: Double
    ) -> Double {
        let value = stored ?? fallback
        guard value.isFinite else { return thresholdFontSize }
        return min(maximumPhoneFontSize, max(minimumPhoneFontSize, value))
    }

    /// Kleinste Schriftgröße einer Handy-Notiz – ist sie erreicht, passen
    /// weitere Zeichen nicht mehr und die Eingabe stoppt.
    public static let thresholdFontSize: Double = minimumPhoneFontSize

    /// Schrittweite der Schriftgrößen-Knöpfe in der Handy-Leiste.
    public static let fontSizeStep: Double = 1

    /// Ob sich die Schriftgröße noch verkleinern lässt.
    public static func canShrink(fontSize: Double) -> Bool {
        guard fontSize.isFinite else { return false }
        return fontSize > minimumPhoneFontSize + 0.001
    }

    /// Ob sich die Schriftgröße noch vergrößern lässt.
    public static func canGrow(fontSize: Double) -> Bool {
        guard fontSize.isFinite else { return false }
        return fontSize < maximumPhoneFontSize - 0.001
    }

    /// Nächste kleinere Schriftgröße (nie unter das Minimum).
    public static func shrunk(fontSize: Double) -> Double {
        let current = fontSize.isFinite ? fontSize : thresholdFontSize
        return min(maximumPhoneFontSize, max(minimumPhoneFontSize, current - fontSizeStep))
    }

    /// Nächste größere Schriftgröße (nie über das Maximum).
    public static func grown(fontSize: Double) -> Double {
        let current = fontSize.isFinite ? fontSize : thresholdFontSize
        return min(maximumPhoneFontSize, max(minimumPhoneFontSize, current + fontSizeStep))
    }

    // MARK: - Zeilenumbruch & automatisches Verkleinern

    /// Einfache Größe in Punkten – bewusst ohne CoreGraphics, damit diese
    /// Regeln auf Linux (Regressions-Tests) übersetzen.
    public struct TextSize: Equatable {
        public let width: Double
        public let height: Double

        public init(width: Double, height: Double) {
            self.width = width
            self.height = height
        }
    }

    /// Ergebnis einer Layout-Prüfung des Handy-Textes.
    public struct Layout: Equatable {
        /// Ob der Text mit dieser Schriftgröße vollständig in den Bereich passt.
        public let fits: Bool
        /// Kleinste Schriftgröße, mit der der Text gerade noch passt.
        public let requiredFontSize: Double
        /// Ob selbst die kleinste Schriftgröße nicht reicht.
        public let isBlocked: Bool

        public init(fits: Bool, requiredFontSize: Double, isBlocked: Bool) {
            self.fits = fits
            self.requiredFontSize = requiredFontSize
            self.isBlocked = isBlocked
        }
    }

    /// Prüft, ob `text` mit `fontSize` in `available` passt und welche
    /// Schriftgröße sonst nötig wäre.
    ///
    /// Der Text bricht automatisch um – er läuft also nie über den Rand,
    /// sondern wird nur nach unten höher. Wächst der Bereich nicht mehr
    /// (Maximalhöhe erreicht), wird die Schriftgröße in 0,1-pt-Schritten
    /// verkleinert, bis der Text gerade so hineinpasst. Ist bereits das
    /// Minimum erreicht, meldet das Ergebnis `isBlocked`.
    public static func layout(
        text: String,
        fontSize: Double,
        availableWidth: Double,
        availableHeight: Double,
        characterSize: (Double) -> TextSize
    ) -> Layout {
        let size = measuredSize(
            text: text,
            fontSize: fontSize,
            availableWidth: availableWidth,
            characterSize: characterSize
        )
        let fits = size.height <= availableHeight + 0.5 && size.width <= availableWidth + 0.5
        if fits {
            return Layout(fits: true, requiredFontSize: clamped(fontSize), isBlocked: false)
        }

        // In 0,1-pt-Schritten verkleinern, bis der Text gerade passt.
        var candidate = clamped(fontSize)
        var steps = 0
        while candidate > minimumPhoneFontSize + 0.001, steps < 600 {
            let stepSize = measuredSize(
                text: text,
                fontSize: candidate,
                availableWidth: availableWidth,
                characterSize: characterSize
            )
            if stepSize.height <= availableHeight + 0.5 && stepSize.width <= availableWidth + 0.5 {
                return Layout(fits: false, requiredFontSize: roundToTenth(candidate), isBlocked: false)
            }
            candidate = roundToTenth(candidate - 0.1)
            steps += 1
        }
        // Selbst die kleinste Schriftgröße reicht nicht.
        return Layout(fits: false, requiredFontSize: minimumPhoneFontSize, isBlocked: true)
    }

    /// Misst die Textgröße bei fester Breite (Zeilenumbruch) in Punkten.
    /// `characterSize` liefert die Größe eines einzelnen Referenzzeichens der
    /// jeweiligen Schriftgröße – so bleibt die Rechnung frei von UIKit und
    /// damit testbar.
    public static func measuredSize(
        text: String,
        fontSize: Double,
        availableWidth: Double,
        characterSize: (Double) -> TextSize
    ) -> TextSize {
        let size = clamped(fontSize)
        let width = availableWidth.isFinite ? max(1, availableWidth) : 1
        let reference = characterSize(size)
        let referenceWidth = reference.width.isFinite && reference.width > 0
            ? reference.width
            : size * 0.55
        let lineHeightValue = reference.height.isFinite && reference.height > 0
            ? reference.height
            : size * 1.25
        guard !text.isEmpty else {
            return TextSize(width: 0, height: lineHeightValue)
        }
        let charactersPerLine = max(1, Int(width / referenceWidth))
        let lineCount = wrappedLineCount(text: text, charactersPerLine: charactersPerLine)
        return TextSize(
            width: min(width, Double(charactersPerLine) * referenceWidth),
            height: Double(lineCount) * lineHeightValue
        )
    }

    /// Zählt die Zeilen, die ein Text bei `charactersPerLine` Zeichen pro
    /// Zeile braucht. Harte Zeilenumbrüche zählen immer; Wörter werden – wie
    /// in UIKit – nicht mitten im Wort getrennt, solange sie allein in eine
    /// Zeile passen.
    public static func wrappedLineCount(text: String, charactersPerLine: Int) -> Int {
        let limit = max(1, charactersPerLine)
        var lines = 0
        for hardLine in text.components(separatedBy: .newlines) {
            if hardLine.isEmpty {
                lines += 1
                continue
            }
            var countInLine = 0
            var lineCount = 1
            for word in hardLine.split(separator: " ", omittingEmptySubsequences: false) {
                let wordLength = word.count
                if wordLength == 0 {
                    // Doppelte Leerzeichen belegen ein Zeichen.
                    if countInLine + 1 <= limit {
                        countInLine += 1
                    } else {
                        lineCount += 1
                        countInLine = 0
                    }
                    continue
                }
                if countInLine == 0 {
                    // Das Wort beginnt die Zeile – notfalls hart umbrechen.
                    let chunks = (wordLength + limit - 1) / limit
                    lineCount += chunks - 1
                    countInLine = wordLength - (chunks - 1) * limit
                } else if countInLine + 1 + wordLength <= limit {
                    countInLine += 1 + wordLength
                } else {
                    lineCount += 1
                    let chunks = (wordLength + limit - 1) / limit
                    lineCount += chunks - 1
                    countInLine = wordLength - (chunks - 1) * limit
                }
            }
            lines += lineCount
        }
        return max(1, lines)
    }

    public static func clamped(_ value: Double) -> Double {
        guard value.isFinite else { return thresholdFontSize }
        return min(maximumPhoneFontSize, max(minimumPhoneFontSize, value))
    }

    public static func roundToTenth(_ value: Double) -> Double {
        guard value.isFinite else { return thresholdFontSize }
        return (value * 10).rounded() / 10
    }

}
