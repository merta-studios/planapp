import Foundation
import CoreGraphics
import UIKit

/// Ein frei bewegliches, skalierbares Bild auf der Zeichenfläche einer Stunden-Notiz.
///
/// Koordinaten sind in Punkt-Koordinaten der Zeichenfläche (unskaliert, d. h.
/// unabhängig vom Zoom der Notiz). Das Seitenverhältnis bleibt beim Skalieren
/// immer erhalten; `width` und `height` beschreiben den Rahmen, in dem das
/// Bild seitenrichtig liegt.
public struct NoteImageBox: Identifiable, Codable, Equatable {
    /// Größte Kantenlänge beim Import (längere Seite wird heruntergerechnet).
    public static let maximumImportEdge: CGFloat = 2048
    /// Höchstzahl an Bildern pro Notiz (schützt Sicherung & Sync vor
    /// übergroßen Dateien).
    public static let maximumImagesPerNote = 10
    /// Kleinste sinnvolle Rahmenbreite beim Skalieren.
    public static let minimumWidth: Double = 40

    public var id: UUID
    public var x: Double        // linke obere Ecke, X
    public var y: Double        // linke obere Ecke, Y
    public var width: Double    // Rahmenbreite
    public var height: Double   // Rahmenhöhe (folgt dem Seitenverhältnis)
    /// Komprimierte Bilddaten (JPEG, bzw. PNG bei Transparenz).
    public var imageData: Data
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        x: Double,
        y: Double,
        width: Double,
        height: Double,
        imageData: Data,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.imageData = imageData
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, x, y, width, height, imageData, updatedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        x = try container.decodeIfPresent(Double.self, forKey: .x) ?? 6
        y = try container.decodeIfPresent(Double.self, forKey: .y) ?? 6
        width = try container.decodeIfPresent(Double.self, forKey: .width) ?? 240
        height = try container.decodeIfPresent(Double.self, forKey: .height) ?? 160
        imageData = try container.decodeIfPresent(Data.self, forKey: .imageData) ?? Data()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }

    /// Das Bild in Original-Orientierung – `nil`, wenn die Daten kein
    /// lesbares Bild mehr enthalten (dann wird der Rahmen verworfen).
    public var uiImage: UIImage? {
        guard !imageData.isEmpty else { return nil }
        return UIImage(data: imageData)
    }

    /// Seitenverhältnis (Breite / Höhe) aus den Bilddaten; fällt auf den
    /// Rahmen zurück, wenn das Bild nicht lesbar ist.
    public var aspectRatio: CGFloat {
        if let image = uiImage, image.size.height > 0 {
            return max(0.1, min(10, image.size.width / image.size.height))
        }
        guard height > 0 else { return 4.0 / 3.0 }
        return max(0.1, min(10, CGFloat(width / height)))
    }

    /// Defensive Normalisierung für geladene oder importierte Bilder.
    /// Ungültige Zahlen (NaN/∞) führen in SwiftUI bei `frame`/`offset` zu
    /// Laufzeit-Abbrüchen; leere Bilddaten sind kein Inhalt und werden
    /// verworfen (`nil`).
    public func sanitized(in areaSize: CGSize? = nil) -> NoteImageBox? {
        guard !imageData.isEmpty, uiImage != nil else { return nil }
        let margin: Double = 6

        var sanitized = self
        sanitized.x = x.isFinite ? x : margin
        sanitized.y = y.isFinite ? y : margin
        sanitized.width = width.isFinite ? width : 240
        sanitized.height = height.isFinite ? height : sanitized.width / Double(max(0.1, aspectRatio))

        sanitized.width = min(max(NoteImageBox.minimumWidth, sanitized.width), 1600)
        sanitized.height = min(max(30, sanitized.height), 1600)

        if let areaSize,
           areaSize.width.isFinite,
           areaSize.height.isFinite,
           areaSize.width > 0,
           areaSize.height > 0 {
            let maxWidth = max(NoteImageBox.minimumWidth, Double(areaSize.width) - margin * 2)
            let maxHeight = max(30, Double(areaSize.height) - margin * 2)
            let fit = min(1, maxWidth / sanitized.width, maxHeight / sanitized.height)
            sanitized.width *= fit
            sanitized.height *= fit
            let maxX = max(margin, Double(areaSize.width) - sanitized.width - margin)
            let maxY = max(margin, Double(areaSize.height) - sanitized.height - margin)
            sanitized.x = min(max(margin, sanitized.x), maxX)
            sanitized.y = min(max(margin, sanitized.y), maxY)
        } else {
            sanitized.x = max(margin, sanitized.x)
            sanitized.y = max(margin, sanitized.y)
        }

        guard sanitized.x.isFinite,
              sanitized.y.isFinite,
              sanitized.width.isFinite,
              sanitized.height.isFinite else {
            return nil
        }
        return sanitized
    }

    /// Bereitet ein importiertes Bild für die Notiz auf: begrenzt die längere
    /// Seite auf `maximumImportEdge` und komprimiert als JPEG (mit
    /// Transparenz als PNG). Gibt `nil` zurück, wenn daraus kein Bild wird.
    public static func preparedData(from image: UIImage) -> Data? {
        let maxEdge = maximumImportEdge
        var working = image
        let longerEdge = max(image.size.width, image.size.height)
        if longerEdge > maxEdge, longerEdge > 0 {
            let factor = maxEdge / longerEdge
            let target = CGSize(
                width: max(1, floor(image.size.width * factor)),
                height: max(1, floor(image.size.height * factor))
            )
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            format.opaque = false
            working = UIGraphicsImageRenderer(size: target, format: format).image { _ in
                image.draw(in: CGRect(origin: .zero, size: target))
            }
        }

        if hasAlpha(working), let png = working.pngData() {
            return png
        }
        // Qualität stufenweise senken, bis das Bild handlich bleibt.
        for quality: CGFloat in [0.85, 0.7, 0.55, 0.4] {
            if let data = working.jpegData(compressionQuality: quality), data.count <= 3_000_000 {
                return data
            }
        }
        return working.jpegData(compressionQuality: 0.35)
    }

    private static func hasAlpha(_ image: UIImage) -> Bool {
        guard let info = image.cgImage?.alphaInfo else { return false }
        switch info {
        case .first, .last, .premultipliedFirst, .premultipliedLast:
            return true
        default:
            return false
        }
    }
}
