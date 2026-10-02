import Foundation
import SwiftUI

/// Erscheinungsbild der App.
///
/// Die Zeichenflächen („Papier“) sind bewusst **immer weiß** und beschriften
/// sich immer mit schwarzer Schrift. Damit ein dunkles System-Erscheinungsbild
/// nirgends weiße Schrift auf weißem Papier erzeugen kann, lässt sich das
/// Erscheinungsbild hier fest einstellen. Standard ist **hell** – die App
/// sieht dann genau so aus, wie sie gestaltet ist, unabhängig davon, wie das
/// iPad eingestellt ist.
public enum AppAppearance: String, Codable, CaseIterable, Identifiable {
    /// Folgt dem System (Hell/Dunkel).
    case system
    /// Immer helles Erscheinungsbild (Standard).
    case light
    /// Immer dunkles Erscheinungsbild.
    case dark

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .system: return "Automatisch"
        case .light: return "Hell"
        case .dark: return "Dunkel"
        }
    }

    public var detail: String {
        switch self {
        case .system:
            return "Folgt dem iPad: hell am Tag, dunkel im Dark Mode."
        case .light:
            return "Immer hell. Weißes Papier bleibt weiß, Schrift bleibt schwarz."
        case .dark:
            return "Immer dunkel."
        }
    }

    public var systemImage: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }

    /// Wert für `.preferredColorScheme(_:)`: `nil` folgt dem System.
    public var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    /// Fallback für alte Speicherstände: Die App startet im hellen Design,
    /// damit die weißen Notizflächen niemals weiße Schrift bekommen.
    public static let fallback: AppAppearance = .light
}
