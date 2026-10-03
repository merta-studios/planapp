import Foundation

// Verwendet die echten Policy-/Layout-Dateien der App, ohne UIKit/SwiftUI.
// Ausführen über Tests/run-regressions.sh (Mac oder Linux mit Swift).
private var checks = 0

private func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    precondition(condition(), message)
    checks += 1
}

private func acceptsTap(
    radius: CGFloat = 28,
    tolerance: CGFloat = 3,
    elapsed: TimeInterval = 0.12,
    movement: CGFloat = 2
) -> Bool {
    IntentionalTapPolicy.acceptsSample(
        elapsed: elapsed, movement: movement,
        majorRadius: radius, radiusTolerance: tolerance
    )
}

// MARK: - Bewusster Tipp statt Handballen

expect(acceptsTap(), "Normaler Finger über der alten 22-pt-Grenze")
expect(acceptsTap(radius: 38), "Große Finger bleiben bedienbar")
expect(acceptsTap(radius: 46, tolerance: 5), "UIKit-Messunsicherheit berücksichtigen")
expect(acceptsTap(radius: 0, tolerance: 0), "Trackpad / fehlende Radiusmessung")
expect(!acceptsTap(radius: 56, tolerance: 4), "Großer direkter Kontakt ist kein Fingertipp")
expect(!acceptsTap(radius: 85, tolerance: 100), "Unsicherheit darf einen Handballen nicht legitimieren")
expect(!acceptsTap(radius: .infinity), "Ungültiger Radius")
expect(!acceptsTap(radius: .nan), "NaN-Radius")
expect(!acceptsTap(radius: -1), "Negativer Radius")
expect(acceptsTap(radius: 28, tolerance: .nan), "Fehlende Toleranz verhindert keinen normalen Tipp")
expect(acceptsTap(elapsed: 0.03), "Schneller bewusster Tipp")
expect(acceptsTap(elapsed: IntentionalTapPolicy.maximumDuration), "Tipp an der Zeitgrenze")
expect(!acceptsTap(elapsed: IntentionalTapPolicy.maximumDuration + 0.01), "Langes Aufliegen schließt nicht")
expect(!acceptsTap(elapsed: -0.1), "Ungültige Touch-Zeit")
expect(!acceptsTap(elapsed: .infinity), "Unendliche Touch-Zeit")
expect(acceptsTap(movement: IntentionalTapPolicy.maximumMovement), "Kleine Fingerbewegung")
expect(!acceptsTap(movement: IntentionalTapPolicy.maximumMovement + 1), "Ziehen ist kein Tipp")
expect(!acceptsTap(movement: .nan), "Ungültige Touch-Position")

let inputActivity = DrawingInputActivity()
expect(inputActivity.permitsBackdropTap(at: 100, toolIsActive: false), "Ohne vorherigen Strich sofort schließbar")
expect(!inputActivity.permitsBackdropTap(at: 100, toolIsActive: true), "Aktiver Pencil-/Fingerstrich sperrt")
inputActivity.record(at: 100)
expect(!inputActivity.permitsBackdropTap(at: 100.3, toolIsActive: false), "Handballen beim Absetzen geschützt")
expect(inputActivity.permitsBackdropTap(at: 100.7, toolIsActive: false), "Kurze Sperre endet automatisch")
expect(!inputActivity.permitsBackdropTap(at: 120, toolIsActive: true), "Langer Strich bleibt geschützt")
// Ein weiterer Strich beginnt während des Rand-Tipps: die Endprüfung muss ihn ablehnen.
inputActivity.record(at: 121)
expect(!inputActivity.permitsBackdropTap(at: 121.1, toolIsActive: false), "Strich während eines begonnenen Tipps")
expect(inputActivity.permitsBackdropTap(at: 122, toolIsActive: false), "Kein klemmendes Began/Ended-Bool")

// MARK: - Sync-Grenze und begrenzte dringende Wiederholung

let now = Date(timeIntervalSince1970: 1_800_000_000)
func secondsAgo(_ seconds: TimeInterval) -> Date { now.addingTimeInterval(-seconds) }
func shouldRefresh(age: TimeInterval?, attemptAge: TimeInterval?) -> Bool {
    TimetableRefreshPolicy.shouldRefresh(
        lastSuccess: age.map(secondsAgo), lastAttempt: attemptAge.map(secondsAgo), now: now
    )
}

expect(!TimetableRefreshPolicy.isStale(lastSuccess: nil, now: now), "Unbekannt ist nicht fälschlich frisch oder veraltet")
expect(!TimetableRefreshPolicy.isStale(lastSuccess: secondsAgo(3599), now: now), "59:59 noch normale Anzeige")
expect(!TimetableRefreshPolicy.isStale(lastSuccess: secondsAgo(3600), now: now), "Exakt 60 Minuten")
expect(TimetableRefreshPolicy.isStale(lastSuccess: secondsAgo(3600.01), now: now), "Über 60 Minuten: rote Warnung")
expect(TimetableRefreshPolicy.isStale(lastSuccess: secondsAgo(24 * 3600), now: now), "Alter Cache nach App-Rückkehr")
expect(!TimetableRefreshPolicy.isStale(lastSuccess: secondsAgo(-60), now: now), "Uhrkorrektur erzeugt kein negatives Alter")
expect(shouldRefresh(age: nil, attemptAge: nil), "Noch nie geladen: ersten Abruf erlauben")
expect(!shouldRefresh(age: nil, attemptAge: 10), "Fehlgeschlagener erster Abruf wird gedrosselt")
expect(shouldRefresh(age: nil, attemptAge: 30), "Ersten Abruf erneut versuchen")
expect(!shouldRefresh(age: 299, attemptAge: nil), "Kein API-Abruf alle 15 Sekunden bei frischen Daten")
expect(shouldRefresh(age: 300, attemptAge: 300), "Normales Fünf-Minuten-Intervall")
expect(!shouldRefresh(age: 500, attemptAge: 30), "Noch frischer Cache: normaler Fehler-Retry")
expect(shouldRefresh(age: 3601, attemptAge: 40), "Beim Überschreiten sofort statt erst nach fünf Minuten")
expect(!shouldRefresh(age: 3700, attemptAge: 29.9), "Keine Anfrage-Schleife bei veraltetem Cache")
expect(shouldRefresh(age: 3700, attemptAge: 30), "Dringender Retry nach 30 Sekunden")
expect(!shouldRefresh(age: 1, attemptAge: 31), "Erfolg beendet die dringenden Wiederholungen")
expect(!shouldRefresh(age: -60, attemptAge: nil), "Keine Anfrage durch zukünftigen Zeitstempel")

// MARK: - Drei kompakte Notizen-Spalten

for width in [CGFloat(1366), 1194, 1024, 834, 820, 810, 768, 744, 712] {
    expect(NotesOverviewLayout.columnCount(for: width) == 3, "Drei Spalten bei \(width) pt")
}
for width in [CGFloat(711), 600, 507, 480] {
    expect(NotesOverviewLayout.columnCount(for: width) == 2, "Zwei Spalten im Split View bei \(width) pt")
}
for width in [CGFloat(375), 320, 0, -10, .infinity, .nan] {
    expect(NotesOverviewLayout.columnCount(for: width) == 1, "Sicherer einspaltiger Fallback für \(width)")
}
for width in stride(from: CGFloat(320), through: 1400, by: 8) {
    let count = NotesOverviewLayout.columnCount(for: width)
    let cardWidth = (width - 2 * NotesOverviewLayout.horizontalPadding
        - CGFloat(count - 1) * NotesOverviewLayout.columnSpacing) / CGFloat(count)
    expect(cardWidth >= NotesOverviewLayout.minimumCardWidth, "Keine abgeschnittenen Karten bei \(width)")
}

// MARK: - Kleinere Palette, größere Buttons, kein Überlappen/Abschneiden

expect(SqueezePaletteLayout.arcRadius < 244, "Kürzerer Weg von der Hover-Position")
expect(SqueezePaletteLayout.arcBandWidth < 76, "Schmalerer Glasbogen")
expect(SqueezePaletteLayout.buttonSize > 40, "Größere Bedienelemente")
expect(SqueezePaletteLayout.buttonSize >= 44, "Komfortables Standard-Touch-Ziel")
let lastIndex = SqueezePaletteLayout.elementCount - 1
expect(abs(SqueezePaletteLayout.angle(at: lastIndex, openingAngle: 0)
    - SqueezePaletteLayout.angle(at: 0, openingAngle: 0) - .pi / 2) < 0.0001, "Weiterhin genau ein Viertelkreis")

for index in 0..<lastIndex {
    let first = SqueezePaletteLayout.offset(
        radius: SqueezePaletteLayout.arcRadius,
        angle: SqueezePaletteLayout.angle(at: index, openingAngle: 0)
    )
    let second = SqueezePaletteLayout.offset(
        radius: SqueezePaletteLayout.arcRadius,
        angle: SqueezePaletteLayout.angle(at: index + 1, openingAngle: 0)
    )
    expect(hypot(first.x - second.x, first.y - second.y) >= SqueezePaletteLayout.buttonSize + 2,
           "Runde Buttons \(index)/\(index + 1) überlappen sich nicht")
}

for count in [4, 5, 8] {
    let step = 2 * SqueezePaletteLayout.colorHalfAngle(for: count) / CGFloat(count - 1)
    let distance = 2 * SqueezePaletteLayout.colorArcRadius * sin(step / 2)
    expect(distance >= SqueezePaletteLayout.buttonSize + 5.99, "Farb-Slots bei \(count) Farben getrennt")
}

let sizes = [CGSize(width: 1366, height: 1024), CGSize(width: 768, height: 1024),
             CGSize(width: 507, height: 720), CGSize(width: 320, height: 300)]
for size in sizes {
    let anchors = [CGPoint.zero, CGPoint(x: size.width, y: 0),
                   CGPoint(x: 0, y: size.height), CGPoint(x: size.width, y: size.height),
                   CGPoint(x: size.width / 2, y: size.height / 2)]
    for anchor in anchors {
        for step in 0..<16 {
            let openingAngle = CGFloat(step) * .pi / 8
            let layout = SqueezePaletteLayout(
                hoverAnchor: anchor, containerSize: size, openingAngle: openingAngle, colorCount: 5
            )
            let epsilon: CGFloat = 0.01
            expect(layout.scale > 0 && layout.scale <= 1, "Sinnvoller Paletten-Maßstab")
            expect(layout.anchor.x + layout.bounds.minX * layout.scale >= SqueezePaletteLayout.margin - epsilon,
                   "Palette/Farben nicht links abgeschnitten")
            expect(layout.anchor.y + layout.bounds.minY * layout.scale >= SqueezePaletteLayout.margin - epsilon,
                   "Palette/Farben nicht oben abgeschnitten")
            expect(layout.anchor.x + layout.bounds.maxX * layout.scale <= size.width - SqueezePaletteLayout.margin + epsilon,
                   "Palette/Farben nicht rechts abgeschnitten")
            expect(layout.anchor.y + layout.bounds.maxY * layout.scale <= size.height - SqueezePaletteLayout.margin + epsilon,
                   "Palette/Farben nicht unten abgeschnitten")
        }
    }
}

let center = CGPoint(x: 512, y: 512)
let centeredLayout = SqueezePaletteLayout(
    hoverAnchor: center, containerSize: CGSize(width: 1024, height: 1024),
    openingAngle: -.pi / 2, colorCount: 5
)
expect(centeredLayout.anchor == center, "Letzte Hover-Position bleibt erhalten, wenn genug Platz ist")
expect(centeredLayout.scale == 1, "Keine unnötig verkleinerten Buttons auf dem iPad")

print("\(checks) Interaktions-/Sync-/Layout-Checks erfolgreich.")
