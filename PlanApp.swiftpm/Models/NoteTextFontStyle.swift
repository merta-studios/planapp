import Foundation
import SwiftUI
import UIKit

/// Schriftart für die Textfelder auf der Zeichenfläche.
///
/// Die Auswahl liegt in den Einstellungen (Zeichnen & Apple Pencil →
/// „Schriftart für Textfelder“) und gilt für alle Textfelder einer Notiz –
/// vorhandene wie neue. Handschriftliche Pencil-Striche sind davon nicht
/// betroffen, nur echte Textfelder.
public enum NoteTextFontStyle: String, Codable, CaseIterable, Identifiable, Equatable {
    case system
    case rounded
    case serif
    case monospaced
    case handwriting

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .system: return "System"
        case .rounded: return "Rund"
        case .serif: return "Serife"
        case .monospaced: return "Schreibmaschine"
        case .handwriting: return "Handschrift"
        }
    }

    public var subtitle: String {
        switch self {
        case .system: return "Die Standardschrift des Systems."
        case .rounded: return "Weich und rund – gut für kurze Notizen."
        case .serif: return "Mit Serifen – klassisch und gut lesbar."
        case .monospaced: return "Feste Zeichenbreite – wie auf der Schreibmaschine."
        case .handwriting: return "Eine handschriftliche Schrift für lose Einträge."
        }
    }

    /// Beispieltext für die Vorschau in den Einstellungen.
    public var previewText: String {
        switch self {
        case .handwriting: return "Mathe Hausaufgaben"
        case .monospaced: return "S. 42, Nr. 3 – 7"
        case .serif: return "Test am Freitag"
        default: return "Vokabeln wiederholen"
        }
    }

    /// Name einer konkreten installierten Schrift (nur „Handschrift“).
    /// Bleibt nil, wenn die Systemschrift mit passender Design-Variante
    /// verwendet wird.
    private var customFontName: String? {
        switch self {
        case .handwriting: return "Noteworthy-Light"
        case .system, .rounded, .serif, .monospaced: return nil
        }
    }

    private var systemDesign: UIFontDescriptor.SystemDesign? {
        switch self {
        case .rounded: return .rounded
        case .serif: return .serif
        case .monospaced: return .monospaced
        case .system, .handwriting: return nil
        }
    }

    /// UIKit-Schrift für Textfelder (`UITextView`) und Vorschauen.
    public func uiFont(size: CGFloat) -> UIFont {
        let resolvedSize = max(1, size.isFinite ? size : NoteTextBox.defaultFontSize)

        if let name = customFontName {
            if let font = UIFont(name: name, size: resolvedSize) {
                return font
            }
            // Zweite Chance: eine andere, auf jedem iPad vorhandene
            // Handschrift-Schrift; sonst bleibt es bei der Systemschrift.
            if let fallback = UIFont(name: "BradleyHandITCTT-Bold", size: resolvedSize) {
                return fallback
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
        if let name = customFontName, UIFont(name: name, size: max(1, size)) != nil {
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
        }
    }

    public static var `default`: NoteTextFontStyle { .system }
}
