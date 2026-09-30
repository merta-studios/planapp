import SwiftUI
import UIKit

extension Color {
    /// Initialisiert eine Color aus einem Hex-String wie "#3B82F6" oder "3B82F6"
    public init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 59, 130, 246) // Default Blau
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    /// Konvertiert Color in einen Hex-String
    public func toHex() -> String {
        let uic = UIColor(self)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        if uic.getRed(&r, green: &g, blue: &b, alpha: &a) {
            return String(format: "#%02X%02X%02X", Int(round(r * 255)), Int(round(g * 255)), Int(round(b * 255)))
        }
        return "#000000"
    }

    /// Pastell-Variante der Farbe: Für alle Fach-Farben gilt eine begrenzte
    /// Sättigung und eine Mindest-Helligkeit ("maximaler Schwarz-Anteil").
    /// Egal welche Farbe eingestellt wird, das Ergebnis bleibt immer sanft.
    public var pastel: Color {
        let uic = UIColor(self)
        var h: CGFloat = 0
        var s: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        guard uic.getHue(&h, saturation: &s, brightness: &b, alpha: &a) else {
            return self
        }
        let pastelSaturation = min(s, 0.42)
        let pastelBrightness = max(b, 0.88)
        return Color(
            hue: Double(h),
            saturation: Double(pastelSaturation),
            brightness: Double(pastelBrightness),
            opacity: Double(a)
        )
    }

    /// Gibt eine lesbare Textfarbe (Schwarz oder Weiß) passend zum Hintergrund zurück
    public var contrastingTextColor: Color {
        let uic = UIColor(self)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        guard uic.getRed(&r, green: &g, blue: &b, alpha: &a) else {
            return .white
        }
        // Helligkeitsformel nach W3C
        let luminance = 0.299 * r + 0.587 * g + 0.114 * b
        return luminance > 0.65 ? Color.black.opacity(0.88) : Color.white
    }

    /// Gedämpftere Sekundärtextfarbe passend zum Hintergrund
    public var contrastingSecondaryTextColor: Color {
        let uic = UIColor(self)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        guard uic.getRed(&r, green: &g, blue: &b, alpha: &a) else {
            return .white.opacity(0.75)
        }
        let luminance = 0.299 * r + 0.587 * g + 0.114 * b
        return luminance > 0.65 ? Color.black.opacity(0.65) : Color.white.opacity(0.75)
    }
}

extension UIColor {
    public convenience init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch cleaned.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 30, 30, 30)
        }
        self.init(
            red: CGFloat(r) / 255.0,
            green: CGFloat(g) / 255.0,
            blue: CGFloat(b) / 255.0,
            alpha: CGFloat(a) / 255.0
        )
    }

    public func toHex() -> String {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        if self.getRed(&r, green: &g, blue: &b, alpha: &a) {
            return String(format: "#%02X%02X%02X", Int(round(r * 255)), Int(round(g * 255)), Int(round(b * 255)))
        }
        return "#000000"
    }
}
