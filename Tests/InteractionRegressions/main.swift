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
do {
    expect(NotesOverviewLayout.columnCount(for: 1366, isPhone: true) == 1, "iPhone zeigt immer eine Spalte")
}
// Flaches Zeilen-Layout der Nur-Notizen-Übersicht: keine Zeile hat mehr Karten
// als Spalten, die Jetzt-Linie trennt Vergangenes von Kommendem und liegt genau
// einmal in der Liste – auch bei leeren Daten oder nur vergangenen Einträgen.
for columnCount in [0, 1, 2, 3] {
    let entries = Array(0..<11)
    let plan = NotesOverviewLayout.rowPlan(entries: entries, columnCount: columnCount) { $0 < 4 }
    expect(plan.filter { $0.isNowLine }.count == 1, "Genau eine Jetzt-Linie bei \(columnCount) Spalten")
    expect(plan.allSatisfy { $0.cardCount <= max(1, columnCount) }, "Keine Zeile breiter als das Raster bei \(columnCount) Spalten")
    expect(plan.reduce(0) { $0 + $1.cardCount } == entries.count, "Keine Karte geht verloren bei \(columnCount) Spalten")
    if let nowIndex = plan.firstIndex(where: { $0.isNowLine }) {
        let before = plan[..<nowIndex].reduce(0) { $0 + $1.cardCount }
        expect(before == 4, "Vier abgelaufene Karten liegen über der Linie bei \(columnCount) Spalten")
    }
}
let onlyPast = NotesOverviewLayout.rowPlan(entries: [1, 2, 3], columnCount: 3) { _ in true }
expect(onlyPast.last?.isNowLine == true, "Nur Vergangenes: Linie am Ende")
let onlyFuture = NotesOverviewLayout.rowPlan(entries: [1, 2, 3], columnCount: 3) { _ in false }
expect(onlyFuture.first?.isNowLine == true, "Nur Kommendes: Linie am Anfang")
expect(NotesOverviewLayout.rowPlan(entries: [Int](), columnCount: 3) { _ in true }.count == 1, "Leere Liste enthält nur die Linie")
for width in stride(from: CGFloat(320), through: 1400, by: 8) {
    let count = NotesOverviewLayout.columnCount(for: width)
    let cardWidth = (width - 2 * NotesOverviewLayout.horizontalPadding
        - CGFloat(count - 1) * NotesOverviewLayout.columnSpacing) / CGFloat(count)
    expect(cardWidth >= NotesOverviewLayout.minimumCardWidth, "Keine abgeschnittenen Karten bei \(width)")
}

// MARK: - Dichtere Squeeze-Bar, dickere Ringfläche, kein Überlappen/Abschneiden

expect(SqueezePaletteLayout.arcRadius < 210, "Kürzerer Weg von der Hover-Position")
expect(SqueezePaletteLayout.arcBandWidth > 44, "Dickerer Glas-Hintergrundring")
expect(SqueezePaletteLayout.buttonSize == 44, "Kompakte Bedienelemente behalten ein 44-pt-Touch-Ziel")
let lastIndex = SqueezePaletteLayout.elementCount - 1
expect(abs(SqueezePaletteLayout.angle(at: lastIndex, openingAngle: 0)
    - SqueezePaletteLayout.angle(at: 0, openingAngle: 0) - 2 * .pi / 3) < 0.0001,
       "Breiterer Bogen hält die acht Tasten trotz kleinerem Radius getrennt")

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

// MARK: - Hero-Rahmen, leere Notizen, Pencil-Gesten, Undo-Sitzungen

expect(!HeroTransitionPolicy.isPlausibleSourceFrame(x: 0, y: 0, width: 0, height: 0), "Nullrahmen ist unplausibel")
expect(!HeroTransitionPolicy.isPlausibleSourceFrame(x: 10, y: 10, width: 8, height: 8), "Mini-Rahmen ist unplausibel")
expect(HeroTransitionPolicy.isPlausibleSourceFrame(x: 120, y: 240, width: 160, height: 90), "Normaler Stundenblock")
expect(!HeroTransitionPolicy.isPlausibleSourceFrame(x: .nan, y: 0, width: 80, height: 40), "NaN-Rahmen")
let local = HeroTransitionPolicy.localFrame(
    windowX: 200, windowY: 300, width: 160, height: 90,
    overlayOriginX: 40, overlayOriginY: 50
)
expect(local.x == 160 && local.y == 250, "Fenster- zu Overlay-Koordinaten")

expect(NoteContentPolicy.shouldPersist(hasInk: true, hasText: false), "Tinte zählt als Inhalt")
expect(NoteContentPolicy.shouldPersist(hasInk: false, hasText: true), "Text zählt als Inhalt")
expect(!NoteContentPolicy.shouldPersist(hasInk: false, hasText: false), "Leere Notiz mit Tag darf nicht bleiben")

expect(PencilGestureAction.toolbar.rawValue == "toolbar", "Squeeze-Standard ist serialisierbar")
expect(PencilGestureAction.toggleEraser.rawValue == "toggleEraser", "Doppeltipp-Standard ist serialisierbar")
expect(PencilGestureAction.allCases.count == 4, "Vier Pencil-Aktionen")

expect(NoteUndoSessionPolicy.linearTickCount(undoCount: 10, availableHeight: 96) == 3, "Balken stoppt am Bildschirmrand")
expect(NoteUndoSessionPolicy.linearTickCount(undoCount: 2, availableHeight: 400) == 2, "Weniger Schritte als Höhe")
expect(NoteUndoSessionPolicy.circularTickCount(undoCount: 80) == NoteUndoSessionPolicy.circularMaxTicks, "Maximal zwanzig Stufen auf dem vollen Kreis")
expect(NoteUndoSessionPolicy.circularTickCount(undoCount: 4) == 4, "Weniger Schritte als Stufen")

// MARK: - Scrubber: voller Kreis, kontinuierliche Drehung, Redo der Sitzung

expect(
    abs(NoteUndoSessionPolicy.circularSweepAngle - 2 * .pi) < 0.000_1,
    "Der runde Scrubber läuft einen vollen Kreis"
)
expect(
    abs(
        NoteUndoSessionPolicy.circularStepAngle() * 20
            - NoteUndoSessionPolicy.circularSweepAngle
    ) < 0.000_1,
    "Zwanzig Schritte decken genau den vollen Kreis ab"
)
expect(
    abs(
        NoteUndoSessionPolicy.circularStepAngle() * 4
            - NoteUndoSessionPolicy.circularSweepAngle * 4 / 20
    ) < 0.000_1,
    "Vier Schritte ergeben nur einen kurzen Teilbogen"
)

expect(UndoScrubMath.linearOffset(translationY: 96, undoTicks: 10) == 3, "Lineare Schritte folgen dem Finger")
expect(UndoScrubMath.linearOffset(translationY: -200, undoTicks: 10) == 0, "Ohne Sitzung-Redo-Schritte: über den Start bleibt 0")
expect(UndoScrubMath.linearOffset(translationY: 900, undoTicks: 10) == 10, "Mehr als alle Schritte wird begrenzt")
expect(UndoScrubMath.linearOffset(translationY: 40, undoTicks: 0) == 0, "Ohne Schritte kein Ausschlag")
expect(UndoScrubMath.linearOffset(translationY: -64, undoTicks: 10, redoTicks: 4) == -2, "Zurückziehen wiederholt Sitzungsschritte")
expect(UndoScrubMath.linearOffset(translationY: -400, undoTicks: 10, redoTicks: 4) == -4, "Redo stoppt am Vorrat der Sitzung")
expect(UndoScrubMath.linearOffset(translationY: -32, undoTicks: 0, redoTicks: 4) == -1, "Redo-only-Sitzung ohne Undo-Schritte")
expect(NoteUndoSessionPolicy.linearRedoLimit(originY: 200) == 5, "Platz über dem Knopf: fünf Wiederhol-Stufen")
expect(NoteUndoSessionPolicy.linearRedoLimit(originY: 30) == 0, "Oben kein Platz: kein Wiederhol-Bereich")
expect(NoteUndoSessionPolicy.linearRedoLimit(originY: .nan) == 0, "Ungültige Höhe ergibt keine Stufen")

// Winkel-Addition über die ±180°-Grenze hinweg: Der Weg wird gemessen,
// nicht die Position – an der Kreismitte / Startposition springt nichts.
let wrappedDelta = UndoScrubMath.normalizedAngleDelta(from: CGFloat(.pi - 0.1), to: CGFloat(-.pi + 0.1))
expect(abs(wrappedDelta - 0.2) < 0.001, "Sprung über die 180°-Grenze zählt als kleiner Schritt")
let backwardsDelta = UndoScrubMath.normalizedAngleDelta(from: CGFloat(-.pi + 0.1), to: CGFloat(.pi - 0.1))
expect(abs(backwardsDelta + 0.2) < 0.001, "… und in die Gegenrichtung bleibt negativ")

let scrubStepAngle = Double(NoteUndoSessionPolicy.circularStepAngle())
/// Kontinuierlich mitaddierter Winkel nach `steps` Schritten;
/// `undoDirection: true` = in Bogenrichtung (undoSweepSign = −1 → negativer Winkel).
func accumulatedAngle(steps: Int, undoDirection: Bool) -> CGFloat {
    (undoDirection ? -1 : 1) * CGFloat(steps) * CGFloat(scrubStepAngle)
}
expect(
    UndoScrubMath.circularOffset(
        accumulatedAngle: accumulatedAngle(steps: 2, undoDirection: true),
        undoTicks: 8, stepAngle: CGFloat(scrubStepAngle)
    ) == 2,
    "Zwei Schritte in Bogenrichtung"
)
expect(
    UndoScrubMath.circularOffset(
        accumulatedAngle: accumulatedAngle(steps: 3, undoDirection: false),
        undoTicks: 8, stepAngle: CGFloat(scrubStepAngle)
    ) == 0,
    "Gegen die Bogenrichtung ohne Redo-Vorrat bleibt bei 0"
)
expect(
    UndoScrubMath.circularOffset(
        accumulatedAngle: accumulatedAngle(steps: 3, undoDirection: false),
        undoTicks: 8, stepAngle: CGFloat(scrubStepAngle), redoTicks: 4
    ) == -3,
    "Gegen die Bogenrichtung wiederholt genau die Sitzungsschritte"
)
expect(
    UndoScrubMath.circularOffset(
        accumulatedAngle: accumulatedAngle(steps: 9, undoDirection: false),
        undoTicks: 8, stepAngle: CGFloat(scrubStepAngle), redoTicks: 4
    ) == -4,
    "Redo stoppt am Vorrat der Sitzung"
)
expect(
    UndoScrubMath.circularOffset(
        accumulatedAngle: accumulatedAngle(steps: 8, undoDirection: true),
        undoTicks: 8, stepAngle: CGFloat(scrubStepAngle)
    ) == 8,
    "Ein voller Umlauf in Bogenrichtung erreicht die letzte Stufe"
)
expect(
    UndoScrubMath.circularOffset(
        accumulatedAngle: accumulatedAngle(steps: 14, undoDirection: true),
        undoTicks: 8, stepAngle: CGFloat(scrubStepAngle)
    ) == 8,
    "Ohne weitere Schritte endet der Umlauf am Vorrat"
)
expect(
    UndoScrubMath.circularOffset(
        accumulatedAngle: accumulatedAngle(steps: 8, undoDirection: true),
        undoTicks: 4, stepAngle: CGFloat(scrubStepAngle)
    ) == 4,
    "Umlauf endet an der letzten vorhandenen Stufe"
)

// Mehrere Umdrehungen: Ein voller Kreis ist kein Deckel mehr. Wer weiterdreht,
// macht weiter rückgängig – bis zum letzten gespeicherten Schritt.
expect(
    UndoScrubMath.circularOffset(
        accumulatedAngle: accumulatedAngle(steps: 20, undoDirection: true),
        undoTicks: 45, stepAngle: CGFloat(scrubStepAngle)
    ) == 20,
    "Ein voller Umlauf zählt weiter, wenn mehr Schritte vorhanden sind"
)
expect(
    UndoScrubMath.circularOffset(
        accumulatedAngle: accumulatedAngle(steps: 30, undoDirection: true),
        undoTicks: 45, stepAngle: CGFloat(scrubStepAngle)
    ) == 30,
    "Zweite Umdrehung macht weitere Schritte rückgängig"
)
expect(
    UndoScrubMath.circularOffset(
        accumulatedAngle: accumulatedAngle(steps: 60, undoDirection: true),
        undoTicks: 45, stepAngle: CGFloat(scrubStepAngle)
    ) == 45,
    "Der Scrubber endet erst am letzten gespeicherten Schritt"
)

// Die hervorgehobene Ring-Stufe: Sie wandert mit den angewandten Schritten und
// liegt nach einer **vollen** Umdrehung auf der letzten Stufe – sonst sähe es
// aus, als wäre nichts passiert.
expect(
    NoteUndoSessionPolicy.circularHighlightedTick(applied: 0) == 0,
    "Ohne angewandten Schritt ist keine Stufe hervorgehoben"
)
expect(
    NoteUndoSessionPolicy.circularHighlightedTick(applied: 5) == 5,
    "Fünf Schritte: die fünfte Stufe ist hervorgehoben"
)
expect(
    NoteUndoSessionPolicy.circularHighlightedTick(applied: 20) == 20,
    "Ein voller Umlauf endet auf der letzten Stufe des Rings"
)
expect(
    NoteUndoSessionPolicy.circularHighlightedTick(applied: 25) == 5,
    "Die zweite Umdrehung beginnt wieder bei der ersten Stufe"
)
expect(
    NoteUndoSessionPolicy.circularHighlightedTick(applied: -3) == 0,
    "Wiederholen erzeugt keine Hervorhebung"
)

// Die sichtbaren Stufen eines Haltens stehen beim Halten fest: Der Balken
// wächst nicht nach, während man zieht. Nur die Wiederhol-Stufen, die man sich
// durch das Rückgängigmachen selbst verdient, kommen hinzu – begrenzt durch
// den Platz über dem Knopf.
do {
    let ticks = NoteUndoSessionPolicy.linearScrubTicks(
        undoCapacity: 10, redoCapacity: 0, appliedOffset: 0,
        availableHeight: 400, originY: 200
    )
    expect(ticks.undo == 10 && ticks.redo == 0, "Zehn Rückgängig-Stufen, keine Wiederhol-Stufen")
}
do {
    let ticks = NoteUndoSessionPolicy.linearScrubTicks(
        undoCapacity: 10, redoCapacity: 2, appliedOffset: 0,
        availableHeight: 400, originY: 200
    )
    expect(ticks.undo == 10 && ticks.redo == 2, "Der Wiederhol-Vorrat beim Halten ist sichtbar")
}
do {
    let ticks = NoteUndoSessionPolicy.linearScrubTicks(
        undoCapacity: 4, redoCapacity: 2, appliedOffset: 4,
        availableHeight: 400, originY: 200
    )
    expect(ticks.undo == 4 && ticks.redo == 5, "Jeder rückgängig gemachte Schritt ist wiederholbar")
}
do {
    let ticks = NoteUndoSessionPolicy.linearScrubTicks(
        undoCapacity: 4, redoCapacity: 0, appliedOffset: 4,
        availableHeight: 400, originY: 30
    )
    expect(ticks.undo == 4 && ticks.redo == 0, "Ohne Platz über dem Knopf gibt es keinen Wiederhol-Bereich")
}
expect(
    NoteUndoSessionPolicy.linearScrubTicks(
        undoCapacity: 10, redoCapacity: 0, appliedOffset: 0,
        availableHeight: 96, originY: 200
    ).undo == 3,
    "Der Balken stoppt am Bildschirmrand"
)
expect(
    NoteUndoSessionPolicy.circularTickCount(undoCount: 0) == 0,
    "Ohne Schritte kein Ring"
)
expect(
    NoteUndoSessionPolicy.circularHighlightedTick(applied: 3, maxTicks: 0) == 0,
    "Ungültige Ringgröße ergibt keine Hervorhebung"
)

// MARK: - Stiftdicke: gemessenes Verhältnis (gerade Linien & Vorschauen)

expect(
    InteractionPolicies.strokeWidthMatchFactor == 2,
    "Gemessenes Verhältnis: selbst berechnete Striche waren 50 % zu dünn"
)
expect(
    InteractionPolicies.matchedStrokeWidth(3.5) == 7,
    "Eine 3,5-pt-Werkzeugbreite ergibt 7 pt für gerade Linie und Vorschau"
)
expect(
    InteractionPolicies.matchedStrokeWidth(16, isMarker: true) == 16,
    "Der Textmarker behält seine eigene, bereits passende Umrechnung"
)
expect(
    InteractionPolicies.matchedStrokeWidth(24, isEraser: true) == 24,
    "Der Radierer radiert mit der eingestellten Breite"
)
expect(
    InteractionPolicies.matchedStrokeWidth(0) == 0.1,
    "Ungültige Breiten fallen auf den Mindestwert zurück"
)

// MARK: - „Nächste Woche“ am Wochenende und nach der letzten Stunde am Freitag

let germanCalendar = Calendar.germanCalendar
let friday = germanCalendar.date(from: DateComponents(
    calendar: germanCalendar, year: 2026, month: 10, day: 9, hour: 15, minute: 0
))
let monday = germanCalendar.date(from: DateComponents(
    calendar: germanCalendar, year: 2026, month: 10, day: 5, hour: 9, minute: 0
))
let saturday = germanCalendar.date(from: DateComponents(
    calendar: germanCalendar, year: 2026, month: 10, day: 10, hour: 11, minute: 0
))
expect(friday != nil && monday != nil && saturday != nil, "Testdaten lassen sich bauen")

if let friday, let monday, let saturday {
    // `startOfWeek()` liefert Montag 00:00 – genau das ist der Wochen-Schlüssel.
    let mondayStart = monday.startOfWeek(using: germanCalendar)
    let nextMondayStart = germanCalendar.date(byAdding: .day, value: 7, to: mondayStart)

    expect(
        Date.relevantCurrentWeekStart(from: friday, lastLessonEndMinutes: 16 * 60) == mondayStart,
        "Freitag vor der letzten Stunde bleibt die laufende Woche"
    )
    expect(
        Date.relevantCurrentWeekStart(from: friday, lastLessonEndMinutes: 13 * 60) == nextMondayStart,
        "Freitag nach der letzten Stunde zeigt auf die kommende Woche"
    )
    expect(
        Date.upcomingWeekHighlightDay(from: friday, lastLessonEndMinutes: 13 * 60) == nextMondayStart,
        "Der kommende Montag wird hellgelb hervorgehoben"
    )
    expect(
        Date.upcomingWeekHighlightDay(from: friday, lastLessonEndMinutes: 16 * 60) == nil,
        "Vor der letzten Stunde am Freitag gibt es keinen Extra-Hinweis"
    )
    expect(
        Date.relevantCurrentWeekStart(from: saturday) == nextMondayStart,
        "Am Wochenende gilt bereits die kommende Woche"
    )
    expect(
        Date.upcomingWeekHighlightDay(from: saturday) == nextMondayStart,
        "Am Wochenende wird der Montag der kommenden Woche markiert"
    )
    expect(
        Date.upcomingWeekHighlightDay(from: monday) == nil,
        "Unter der Woche wird kein kommender Montag markiert"
    )
    expect(
        Date.relevantCurrentWeekStart(from: monday) == mondayStart,
        "Montag ist die laufende Woche"
    )
}

// MARK: - Undo-Kreis, schmale Leiste, Tag-Popover, Jetzt-Sprung, Filter

let ringStart = 0.8
expect(
    InteractionPolicies.circularRingStartsAtButton(buttonAngle: ringStart, ringStartAngle: ringStart),
    "Runder Undo-Balken beginnt am Rückgängig-Knopf"
)
expect(
    !InteractionPolicies.circularRingStartsAtButton(buttonAngle: ringStart, ringStartAngle: ringStart - .pi / 2),
    "Ein Vierteldreh daneben ist zu weit links"
)
let outsideTick = InteractionPolicies.circularTickAngle(startAngle: ringStart, step: 3, stepAngle: 0.2)
expect(outsideTick < ringStart, "Graue Striche laufen links von der Bar, nicht rechts hinein")
expect(InteractionPolicies.circularRingLineWidth > 60, "Runder Undo-Balken ist dicker als die Kreis-Bar")

expect(
    InteractionPolicies.usesCompactScrollingToolbar(availableWidth: 507, contentWidth: 980),
    "Split View: Leiste wird dünner und scrollt"
)
expect(
    !InteractionPolicies.usesCompactScrollingToolbar(availableWidth: 1366, contentWidth: 980),
    "Breites iPad behält die normale Leiste"
)
expect(
    InteractionPolicies.estimatedToolbarContentWidth(penSlots: 4, markerSlots: 5, isPhone: false) > 700,
    "iPad-Leiste ist breiter als ein schmales Fenster"
)

expect(
    !InteractionPolicies.tagPickerPlacesBelow(spaceAbove: 360, spaceBelow: 80),
    "Genug Platz über dem Knopf: Auswahl bleibt oben"
)
expect(
    InteractionPolicies.tagPickerPlacesBelow(spaceAbove: 70, spaceBelow: 520),
    "Zeichenfenster zu weit oben: Mini-Auswahl nach unten"
)
let cramped = InteractionPolicies.tagPickerFrame(
    buttonMinX: 40, buttonMaxX: 120, buttonMinY: 28, buttonMaxY: 52,
    containerWidth: 744, containerHeight: 700, contentHeight: 480
)
expect(cramped.placesBelow, "Wenig Platz oben öffnet nach unten")
expect(cramped.y >= 52, "Panel beginnt unter dem Knopf")
expect(cramped.y + cramped.height <= 700, "Panel bleibt im Bild")
expect(cramped.height <= 480, "Panel wird nicht höher als der Inhalt")
let tightBelow = InteractionPolicies.tagPickerFrame(
    buttonMinX: 40, buttonMaxX: 120, buttonMinY: 180, buttonMaxY: 210,
    containerWidth: 744, containerHeight: 400, contentHeight: 480
)
expect(tightBelow.placesBelow, "Knappes Fenster öffnet nach unten")
expect(tightBelow.height < 480, "Zu wenig Platz kürzt die Liste, schneidet sie nicht ab")
expect(tightBelow.y + tightBelow.height <= 400, "Gekürztes Panel bleibt im Bild")

expect(
    InteractionPolicies.shouldShowNowJumpButton(lineMinY: -30, lineMaxY: -2, viewportHeight: 640),
    "Linie oberhalb: Jetzt-Knopf"
)
expect(
    !InteractionPolicies.shouldShowNowJumpButton(lineMinY: 20, lineMaxY: 36, viewportHeight: 640),
    "Sichtbare Linie: kein Jetzt-Knopf"
)
expect(
    InteractionPolicies.shouldShowNowJumpButton(lineMinY: nil, lineMaxY: nil, viewportHeight: 640),
    "Linie nicht mehr im Lazy-Bereich"
)
expect(
    InteractionPolicies.nowJumpPointsDown(lineMidY: 900, viewportHeight: 640),
    "Linie unterhalb: Pfeil nach unten"
)
expect(
    !InteractionPolicies.nowJumpPointsDown(lineMidY: -20, viewportHeight: 640),
    "Linie oberhalb: Pfeil nach oben"
)

expect(
    InteractionPolicies.shouldResetFiltersWhenEnteringNotesOnly(previousMode: "standard", newMode: "notesOnly"),
    "Wechsel zu Nur Notizen setzt Filter zurück"
)
expect(
    !InteractionPolicies.shouldResetFiltersWhenEnteringNotesOnly(previousMode: "notesOnly", newMode: "notesOnly"),
    "Erneutes Setzen desselben Modus löscht keine frischen Filter"
)

// MARK: - Stift-Stabilisierung (0–100 %)

expect(
    PenStabilization.defaultPercent == 0,
    "Standard ist 0 % – ohne Einstellung bleibt die Schrift unverändert"
)
expect(
    PenStabilization.clampedPercent(-20) == 0 && PenStabilization.clampedPercent(180) == 100,
    "Der Prozentwert wird auf 0…100 begrenzt"
)
expect(
    PenStabilization.clampedPercent(.nan) == PenStabilization.defaultPercent,
    "Ungültige Werte fallen auf den Standard zurück"
)
expect(
    PenStabilization.strength(percent: 0) == 0 && PenStabilization.strength(percent: 100) == 1,
    "Prozent werden auf die Stärke 0…1 abgebildet"
)
expect(
    abs(PenStabilization.strength(percent: 50) - 0.5) < 0.000_1,
    "50 % ist die halbe Stärke"
)
expect(
    PenStabilization.smoothingRadius(strength: 0) == 0,
    "Ohne Stärke gibt es kein Glättungsfenster"
)
expect(
    PenStabilization.smoothingRadius(strength: 1) > PenStabilization.smoothingRadius(strength: 0.2),
    "Mehr Stärke bedeutet ein größeres Fenster"
)
expect(
    PenStabilization.smoothingRadius(strength: 1) == PenStabilization.maximumRadius,
    "Bei 100 % ist das Fenster maximal groß"
)

let zitterPoints: [CGPoint] = (0...40).map { index in
    let x = CGFloat(index)
    let jitter: CGFloat = index % 2 == 0 ? 0.9 : -0.9
    return CGPoint(x: x, y: 10 + jitter)
}
expect(
    PenStabilization.smoothedLocations(zitterPoints, strength: 0) == zitterPoints,
    "Bei 0 % bleiben alle Punkte exakt stehen"
)
expect(
    PenStabilization.smoothedLocations(zitterPoints, strength: 0)[0] == zitterPoints[0],
    "Der erste Punkt bleibt unangetastet"
)

let smoothedZitter = PenStabilization.smoothedLocations(zitterPoints, strength: 1)
expect(smoothedZitter.count == zitterPoints.count, "Die Glättung verschiebt nur Punkte")
expect(smoothedZitter.first == zitterPoints.first, "Der Strich beginnt, wo der Stift aufgesetzt hat")
expect(smoothedZitter.last == zitterPoints.last, "Der Strich endet, wo der Stift abgehoben hat")
let wobbleBefore = zitterPoints.reduce(CGFloat(0)) { $0 + abs($1.y - 10) }
let wobbleAfter = smoothedZitter.reduce(CGFloat(0)) { $0 + abs($1.y - 10) }
expect(wobbleAfter < wobbleBefore * 0.5, "Das Zittern wird deutlich reduziert")

// Eine gerade Linie darf die Glättung nicht verbiegen: Punkte auf der Geraden
// bleiben (bis auf die festen Endpunkte) auf der Geraden.
let linePoints: [CGPoint] = (0...20).map { CGPoint(x: CGFloat($0) * 3, y: CGFloat($0) * 6) }
let smoothedLine = PenStabilization.smoothedLocations(linePoints, strength: 1)
expect(
    smoothedLine.allSatisfy { abs($0.y - ($0.x * 2)) < 0.000_1 },
    "Eine gerade Linie bleibt gerade"
)
do {
    let invalid = [CGPoint(x: .nan, y: 0), CGPoint(x: 1, y: 1), CGPoint(x: 2, y: 2)]
    let untouched = PenStabilization.smoothedLocations(invalid, strength: 1)
    expect(
        untouched.count == invalid.count && untouched[0].x.isNaN && untouched[1] == invalid[1],
        "Ungültige Koordinaten werden nicht angefasst"
    )
}
expect(
    PenStabilization.smoothedLocations([CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 1)], strength: 1).count == 2,
    "Zu kurze Striche (Punkt/Tipp) bleiben unverändert"
)

expect(
    PenStabilization.pathLength(of: [CGPoint(x: 0, y: 0), CGPoint(x: 3, y: 4)]) == 5,
    "Die Weglänge summiert die Abstände der Punkte"
)
expect(
    PenStabilization.smoothingRadius(strength: 1, pathLength: 22)
        < PenStabilization.smoothingRadius(strength: 1),
    "Kurze Striche werden nur mit einem kleinen Fenster geglättet"
)
do {
    // Ein kleines „e“: Bei 100 % darf es seine Form behalten, nur das Zittern
    // geht weg – sonst würde die Stabilisierung kurze Buchstaben zerdrücken.
    let smallLoop: [CGPoint] = [
        CGPoint(x: 0, y: 0), CGPoint(x: 2, y: 1), CGPoint(x: 4, y: 3),
        CGPoint(x: 5, y: 6), CGPoint(x: 4, y: 8), CGPoint(x: 2, y: 9),
        CGPoint(x: 1, y: 7), CGPoint(x: 1, y: 4), CGPoint(x: 0, y: 0)
    ]
    let smoothedLoop = PenStabilization.smoothedLocations(smallLoop, strength: 1)
    var largestShift: CGFloat = 0
    for (index, point) in smoothedLoop.enumerated() {
        let shift = hypot(point.x - smallLoop[index].x, point.y - smallLoop[index].y)
        largestShift = max(largestShift, shift)
    }
    expect(largestShift < 1.5, "Kleine Buchstaben behalten bei 100 % ihre Form")
}

print("\(checks) Interaktions-/Sync-/Layout-Checks erfolgreich.")
