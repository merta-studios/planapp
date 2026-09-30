import PencilKit
import CoreGraphics

extension PKDrawing {
    /// Schneidet alle Striche hart an den Grenzen von `rect` ab.
    /// Strich-Anteile außerhalb des Rechtecks werden wirklich aus dem
    /// Datenmodell entfernt (nicht nur beim Rendern versteckt), damit sie
    /// weder in der gespeicherten Notiz noch in der Vorschau auftauchen.
    public func cropped(to rect: CGRect) -> PKDrawing {
        guard !rect.isNull, !rect.isEmpty, rect.width > 0, rect.height > 0 else {
            return PKDrawing()
        }

        var croppedStrokes: [PKStroke] = []
        croppedStrokes.reserveCapacity(strokes.count)

        for stroke in strokes {
            croppedStrokes.append(contentsOf: stroke.segmentsClipped(to: rect))
        }

        return PKDrawing(strokes: croppedStrokes)
    }
}

extension PKStroke {
    /// Zerlegt den Strich in die Teilstücke, die innerhalb (bzw. knapp
    /// außerhalb, abhängig von der Strichbreite) von `rect` liegen. Punkte im
    /// Randbereich werden exakt auf die Kante gezogen, sodass der Strich
    /// sauber am Rand endet statt darüber hinauszulaufen.
    fileprivate func segmentsClipped(to rect: CGRect) -> [PKStroke] {
        let points = Array(path.interpolatedPoints)
        guard !points.isEmpty else { return [] }

        // Breiteste Stelle des Strichs bestimmt, wie weit Punkte außerhalb
        // liegen dürfen und trotzdem noch (auf die Kante gezogen) sichtbar sind.
        let maxStrokeWidth = points
            .map { max($0.size.width, $0.size.height) }
            .max() ?? 0
        let margin = max(1.5, maxStrokeWidth * 0.75)
        let keepZone = rect.insetBy(dx: -margin, dy: -margin)

        func clampedLocation(_ location: CGPoint) -> CGPoint {
            CGPoint(
                x: min(max(location.x, rect.minX), rect.maxX),
                y: min(max(location.y, rect.minY), rect.maxY)
            )
        }

        var segments: [[PKStrokePoint]] = []
        var current: [PKStrokePoint] = []

        for point in points {
            if keepZone.contains(point.location) {
                // Derselbe Punkt, nur auf die Karte gezogen, falls er im
                // äußeren Randstreifen liegt.
                current.append(
                    PKStrokePoint(
                        location: clampedLocation(point.location),
                        timeOffset: point.timeOffset,
                        size: point.size,
                        opacity: point.opacity,
                        force: point.force,
                        azimuth: point.azimuth,
                        altitude: point.altitude
                    )
                )
            } else if !current.isEmpty {
                segments.append(current)
                current = []
            }
        }
        if !current.isEmpty {
            segments.append(current)
        }

        return segments.map { segment in
            let newPath = PKStrokePath(controlPoints: segment, creationDate: path.creationDate)
            return PKStroke(ink: ink, path: newPath, transform: transform, mask: mask)
        }
    }
}
