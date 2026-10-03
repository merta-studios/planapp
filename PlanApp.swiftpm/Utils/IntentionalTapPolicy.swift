import Foundation

/// Gemeinsame, ohne UIKit testbare Grenzen für bewusste Tipps. Die Kontaktgröße
/// allein ist kein verlässlicher Handballenfilter: iPads melden auch für normale
/// Finger mehr als 22 pt und liefern dazu eine Messunsicherheit.
enum IntentionalTapPolicy {
    static let maximumDuration: TimeInterval = 0.45
    static let maximumMovement: CGFloat = 12
    static let maximumFingerRadius: CGFloat = 42
    static let maximumRadiusTolerance: CGFloat = 8
    static let drawingCooldown: TimeInterval = 0.55

    static func acceptsSample(
        elapsed: TimeInterval,
        movement: CGFloat,
        majorRadius: CGFloat,
        radiusTolerance: CGFloat
    ) -> Bool {
        guard elapsed.isFinite, (0...maximumDuration).contains(elapsed),
              movement.isFinite, (0...maximumMovement).contains(movement),
              majorRadius.isFinite, majorRadius >= 0 else { return false }

        let tolerance = radiusTolerance.isFinite
            ? min(maximumRadiusTolerance, max(0, radiusTolerance))
            : 0
        // Radius 0 ist zulässig (z. B. Trackpad bzw. fehlende Radiusmessung).
        return max(0, majorRadius - tolerance) <= maximumFingerRadius
    }
}

/// Kein veröffentlichter SwiftUI-Zustand: UIKit aktualisiert den Zeitpunkt
/// synchron, bevor asynchrone Canvas-/SwiftUI-Callbacks verarbeitet werden.
/// Ob noch gezeichnet wird, wird direkt am Canvas-Recognizer abgefragt. Ein
/// ausgebliebener End-Callback kann das Schließen daher nicht dauerhaft sperren.
final class DrawingInputActivity {
    private var lastActivityTime: TimeInterval?

    func record(at time: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        lastActivityTime = time
    }

    func permitsBackdropTap(
        at time: TimeInterval = ProcessInfo.processInfo.systemUptime,
        toolIsActive: Bool
    ) -> Bool {
        guard !toolIsActive else { return false }
        guard let lastActivityTime else { return true }
        return time - lastActivityTime >= IntentionalTapPolicy.drawingCooldown
    }
}
