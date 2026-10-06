import Foundation
import SwiftUI
import UIKit

/// Schriftart für die Textfelder auf der Zeichenfläche.
///
/// Die Auswahl liegt in den Einstellungen (Zeichnen & Apple Pencil →
/// „Schriftart für Textfelder“) und gilt für alle Textfelder einer Notiz –
/// vorhandene wie neue. Handschriftliche Pencil-Striche sind davon nicht
/// betroffen, nur echte Textfelder.
///
/// Neben den System-Design-Varianten gibt es mehrere konkrete, auf jedem
/// iPad installierte Fonts (z. B. Chalkboard, Marker Felt, Zapf Chancery,
/// Bradley Hand und American Typewriter).
public enum NoteTextFontStyle: String, Codable, CaseIterable, Identifiable, Equatable {
    case system
    case rounded
    case serif
    case monospaced
    case handwriting
    case chalkboard
    case markerFelt
    case zapfChancery
    case bradleyHand
    case americanTypewriter

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .system: return "System"
        case .rounded: return "Rund"
        case .serif: return "Serife"
        case .monospaced: return "Schreibmaschine"
        case .handwriting: return "Handschrift"
        case .chalkboard: return "Kreidebrett"
        case .markerFelt: return "Marker"
        case .zapfChancery: return "Kursiv"
        case .bradleyHand: return "Bradley Hand"
        case .americanTypewriter: return "Typewriter"
        }
    }

    public var subtitle: String {
        switch self {
        case .system: return "Die Standardschrift des Systems."
        case .rounded: return "Weich und rund – gut für kurze Notizen."
        case .serif: return "Mit Serifen – klassisch und gut lesbar."
        case .monospaced: return "Feste Zeichenbreite – wie auf der Schreibmaschine."
        case .handwriting: return "Eine handschriftliche Schrift für lose Einträge."
        case .chalkboard: return "Kreide-Optik – wie mit Kreide an der Tafel."
        case .markerFelt: return "Kräftige Marker-Schrift für auffällige Einträge."
        case .zapfChancery: return "Elegante Schreibschrift für Notizen im Fließtext."
        case .bradleyHand: return "Freihändige Schreibschrift – locker und verspielt."
        case .americanTypewriter: return "Klassische Druckerschrift mit Charakter."
        }
    }

    /// Beispieltext für die Vorschau in den Einstellungen.
    public var previewText: String {
        switch self {
        case .handwriting, .bradleyHand, .chalkboard: return "Mathe Hausaufgaben"
        case .monospaced, .americanTypewriter: return "S. 42, Nr. 3 – 7"
        case .serif, .zapfChancery: return "Test am Freitag"
        case .markerFelt: return "WICHTIG: Bücher mitnehmen!"
        default: return "Vokabeln wiederholen"
        }
    }

    /// Name einer konkreten installierten Schrift.
    /// Bleibt nil, wenn die Systemschrift mit passender Design-Variante
    /// verwendet wird.
    private var customFontName: String? {
        switch self {
        case .handwriting: return "Noteworthy-Light"
        case .chalkboard: return "ChalkboardSE-Regular"
        case .markerFelt: return "MarkerFelt-Wide"
        case .zapfChancery: return "ZapfChancery-MediumItalic"
        case .bradleyHand: return "BradleyHandITCTT-Bold"
        case .americanTypewriter: return "AmericanTypewriter"
        case .system, .rounded, .serif, .monospaced: return nil
        }
    }

    /// Zweite Chance, wenn der erste Font-Name nicht auflösbar ist
    /// (alle genannten Fonts sind in iOS eingebaut).
    private var customFontFallbackName: String? {
        switch self {
        case .handwriting, .bradleyHand: return "BradleyHandITCTT-Bold"
        case .chalkboard: return "ChalkboardSE-Bold"
        case .markerFelt: return "MarkerFelt-Thin"
        case .zapfChancery: return "SnellRoundhand-Bold"
        case .americanTypewriter: return "AmericanTypewriter-Semibold"
        case .system, .rounded, .serif, .monospaced: return nil
        }
    }

    private var systemDesign: UIFontDescriptor.SystemDesign? {
        switch self {
        case .rounded: return .rounded
        case .serif: return .serif
        case .monospaced: return .monospaced
        case .system, .handwriting, .chalkboard, .markerFelt, .zapfChancery, .bradleyHand, .americanTypewriter:
            return nil
        }
    }

    /// UIKit-Schrift für Textfelder (`UITextView`) und Vorschauen.
    public func uiFont(size: CGFloat) -> UIFont {
        let resolvedSize = max(1, size.isFinite ? size : NoteTextBox.defaultFontSize)

        if let name = customFontName {
            if let font = UIFont(name: name, size: resolvedSize) {
                return font
            }
            if let fallback = customFontFallbackName,
               let font = UIFont(name: fallback, size: resolvedSize) {
                return font
            }
            // Zweite Chance: eine andere, auf jedem iPad vorhandene
            // Handschrift-Schrift; sonst bleibt es bei der Systemschrift.
            if let lastResort = UIFont(name: "BradleyHandITCTT-Bold", size: resolvedSize) {
                return lastResort
            }
            return .systemFont(ofSize: resolvedSize)
        }

        let base = UIFont.systemFont(ofSize: resolvedSize)
        guard let design = systemDesign,
              let descriptor = base.fontDescriptor.withDesign(design) else {
            return base
        }
        return UIFont(descriptor: descriptor, size: resolvedSize)
    }

    /// SwiftUI-Schrift für Vorschauen (Platzhalter, Einstellungen).
    public func font(size: CGFloat) -> Font {
        if customFontName != nil {
            return Font(uiFont(size: size))
        }
        switch self {
        case .system, .handwriting:
            return .system(size: max(1, size))
        case .rounded:
            return .system(size: max(1, size), design: .rounded)
        case .serif:
            return .system(size: max(1, size), design: .serif)
        case .monospaced:
            return .system(size: max(1, size), design: .monospaced)
        case .chalkboard, .markerFelt, .zapfChancery, .bradleyHand, .americanTypewriter:
            return .system(size: max(1, size))
        }
    }

    public static var `default`: NoteTextFontStyle { .system }
}
