import Foundation
import SwiftUI

/// Benutzerdefinierte Fächer-Einstellung (Fach-Ersetzung und Farbe)
public struct SubjectCustomization: Identifiable, Codable, Equatable, Hashable {
    public var id: UUID
    public var originalSubject: String // Name von WebUntis (z.B. "M", "D", "ENG")
    public var customName: String      // Neuer schöner Name (z.B. "Mathematik")
    public var colorHex: String        // Hex-Farbcode (z.B. "#3B82F6") – obere Anfangs-Farbe
    public var gradientEndHex: String? // Optionale untere End-Farbe für einen Farbverlauf

    public init(
        id: UUID = UUID(),
        originalSubject: String,
        customName: String,
        colorHex: String,
        gradientEndHex: String? = nil
    ) {
        self.id = id
        self.originalSubject = originalSubject.trimmingCharacters(in: .whitespacesAndNewlines)
        self.customName = customName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.colorHex = colorHex
        self.gradientEndHex = gradientEndHex
    }

    /// Schnelle Standard-Vorlagen für gängige Schulfächer
    public static var defaultPresets: [SubjectCustomization] {
        [
            SubjectCustomization(originalSubject: "M", customName: "Mathematik", colorHex: "#3B82F6"), // Blau
            SubjectCustomization(originalSubject: "D", customName: "Deutsch", colorHex: "#EF4444"),    // Rot
            SubjectCustomization(originalSubject: "E", customName: "Englisch", colorHex: "#10B981"),   // Grün
            SubjectCustomization(originalSubject: "ENG", customName: "Englisch", colorHex: "#10B981"),
            SubjectCustomization(originalSubject: "PH", customName: "Physik", colorHex: "#8B5CF6"),    // Lila
            SubjectCustomization(originalSubject: "CH", customName: "Chemie", colorHex: "#F59E0B"),    // Gelb/Orange
            SubjectCustomization(originalSubject: "BIO", customName: "Biologie", colorHex: "#059669"), // Dunkelgrün
            SubjectCustomization(originalSubject: "GE", customName: "Geschichte", colorHex: "#B45309"),// Braun/Bronze
            SubjectCustomization(originalSubject: "GEO", customName: "Geografie", colorHex: "#06B6D4"),// Cyan
            SubjectCustomization(originalSubject: "EK", customName: "Erdkunde", colorHex: "#06B6D4"),
            SubjectCustomization(originalSubject: "KU", customName: "Kunst", colorHex: "#EC4899"),     // Pink
            SubjectCustomization(originalSubject: "MU", customName: "Musik", colorHex: "#6366F1"),     // Indigo
            SubjectCustomization(originalSubject: "SP", customName: "Sport", colorHex: "#14B8A6"),     // Mint/Teal
            SubjectCustomization(originalSubject: "INF", customName: "Informatik", colorHex: "#4F46E5"),
            SubjectCustomization(originalSubject: "IF", customName: "Informatik", colorHex: "#4F46E5"),
            SubjectCustomization(originalSubject: "REL", customName: "Religion", colorHex: "#F97316"),
            SubjectCustomization(originalSubject: "ETH", customName: "Ethik", colorHex: "#64748B"),
            SubjectCustomization(originalSubject: "F", customName: "Französisch", colorHex: "#0284C7"),
            SubjectCustomization(originalSubject: "L", customName: "Latein", colorHex: "#78716C"),
            SubjectCustomization(originalSubject: "SPA", customName: "Spanisch", colorHex: "#EA580C")
        ]
    }
}
