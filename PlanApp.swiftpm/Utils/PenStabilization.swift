import Foundation

/// Einstellung „Stift-Stabilisierung“ (0–100 %).
///
/// Der Wert wird als **Prozent** gespeichert (0 = aus, Standard) und hier in
/// eine Stärke 0…1 umgerechnet. Die Glättung selbst liegt in
/// `smoothedLocations` und ist bewusst reine Mathematik: kein UIKit, keine
/// PencilKit-Typen – so lässt sie sich ohne Gerät testen
/// (`Tests/InteractionRegressions`).
public enum PenStabilization {
    public static let minimumPercent: Double = 0
    public static let maximumPercent: Double = 100
    /// Standard: **0 %** – die Schrift bleibt unverändert (niemand bekommt
    /// ungefragt eine weichere Linie).
    public static let defaultPercent: Double = 0

    /// Halbe Fensterbreite in Punkten, über die ein Punkt gemittelt wird.
    /// Bei 0 % gibt es kein Fenster (keine Glättung), bei 100 % werden die
    /// Nachbarpunkte bis rund 12 pt Abstand einbezogen.
    public static let minimumRadius: Double = 3
    public static let maximumRadius: Double = 12
    /// So viele Nachbarpunkte werden je Richtung höchstens gemittelt – eine
    /// reine Kostengrenze für sehr dichte Striche.
    public static let maximumNeighboursPerDirection = 40

    public static func clampedPercent(_ value: Double) -> Double {
        guard value.isFinite else { return defaultPercent }
        return min(maximumPercent, max(minimumPercent, value))
    }

    /// Stärke 0…1 aus dem Prozentwert der Einstellung.
    public static func strength(percent: Double) -> Double {
        guard percent.isFinite else { return 0 }
        return strength(fromClamped: clampedPercent(percent) / maximumPercent)
    }

    /// Prozentwert für die Oberfläche.
    public static func percent(strength: Double) -> Double {
        strength(fromClamped: strength) * maximumPercent
    }

    public static func strength(fromClamped value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(1, max(0, value))
    }

    /// Halbe Fensterbreite (in Punkten) für eine Stärke 0…1. Bei Stärke 0
    /// ist sie 0 – dann wird nichts geglättet.
    public static func smoothingRadius(strength: Double) -> Double {
        let amount = strength(fromClamped: strength)
        guard amount > 0 else { return 0 }
        return minimumRadius + amount * (maximumRadius - minimumRadius)
    }

    /// Das **tatsächlich benutzte** Fenster für einen Strich dieser Länge:
    /// höchstens ein Sechstel des Wegs. Dadurch bleiben kurze Buchstaben
    /// („e“, „s“) auch bei 100 % ihre Form – geglättet wird nur das Zittern.
    public static func smoothingRadius(strength: Double, pathLength: Double) -> Double {
        let base = smoothingRadius(strength: strength)
        guard base > 0, pathLength.isFinite, pathLength > 0 else { return base }
        return min(base, max(minimumRadius * 0.5, pathLength / 6))
    }

    /// Glättet die **Positionen** eines Strichs, ohne seine Punkte zu
    /// verschieben oder zu ergänzen: Jeder Punkt wandert zu einem mit
    /// Dreiecks-Gewicht gemittelten Wert seiner Nachbarschaft (je näher, desto
    /// stärker). Hohe Frequenzen – das typische Zittern der Handschrift –
    /// verschwinden dadurch, die Form der Buchstaben bleibt erhalten.
    ///
    /// Der **erste und der letzte Punkt bleiben exakt stehen**: Der Strich
    /// beginnt und endet dort, wo der Stift aufgesetzt und abgehoben wurde.
    /// Bei Stärke 0 (Standard) wird die Eingabe unverändert zurückgegeben.
    public static func smoothedLocations(_ locations: [CGPoint], strength: Double) -> [CGPoint] {
        let amount = strength(fromClamped: strength)
        guard amount > 0, locations.count > 2 else { return locations }
        guard locations.allSatisfy({ $0.x.isFinite && $0.y.isFinite }) else { return locations }
        let radius = smoothingRadius(strength: amount, pathLength: pathLength(of: locations))
        guard radius > 0 else { return locations }

        let window = CGFloat(radius)
        let blend = CGFloat(amount)
        var result = locations
        let lastIndex = locations.count - 1
        for index in 1..<lastIndex {
            let center = locations[index]
            var sumX = center.x
            var sumY = center.y
            var weightSum: CGFloat = 1

            var cursor = index - 1
            var visited = 0
            while cursor > 0, visited < maximumNeighboursPerDirection {
                let candidate = locations[cursor]
                let distance = hypot(candidate.x - center.x, candidate.y - center.y)
                if distance > window { break }
                let weight = 1 - distance / window
                sumX += candidate.x * weight
                sumY += candidate.y * weight
                weightSum += weight
                cursor -= 1
                visited += 1
            }

            cursor = index + 1
            visited = 0
            while cursor < lastIndex, visited < maximumNeighboursPerDirection {
                let candidate = locations[cursor]
                let distance = hypot(candidate.x - center.x, candidate.y - center.y)
                if distance > window { break }
                let weight = 1 - distance / window
                sumX += candidate.x * weight
                sumY += candidate.y * weight
                weightSum += weight
                cursor += 1
                visited += 1
            }

            let averageX = sumX / weightSum
            let averageY = sumY / weightSum
            result[index] = CGPoint(
                x: center.x + (averageX - center.x) * blend,
                y: center.y + (averageY - center.y) * blend
            )
        }
        return result
    }

    /// Länge des Wegs durch alle Punkte (in Punkten).
    public static func pathLength(of locations: [CGPoint]) -> Double {
        guard locations.count > 1 else { return 0 }
        var total = 0.0
        for index in 1..<locations.count {
            let previous = locations[index - 1]
            let current = locations[index]
            total += hypot(current.x - previous.x, current.y - previous.y)
        }
        return total.isFinite ? total : 0
    }
}
