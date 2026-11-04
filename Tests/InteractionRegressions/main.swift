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

// MARK: - Zeichenfläche verkleinern: Inhalt blockiert den Griff

let canvasContent = [
    InteractionPolicies.CanvasContentItem(offsetY: 40, height: 60),
    InteractionPolicies.CanvasContentItem(offsetY: 200, height: 120)
]
expect(
    InteractionPolicies.requiredContentHeight(for: canvasContent, minimum: 216) == 326,
    "Das tiefste Element begrenzt die Zeichenfläche (200 + 120 + 6 Rand)"
)
expect(
    InteractionPolicies.requiredContentHeight(for: [], minimum: 216) == 216,
    "Ohne Inhalt gilt das absolute Minimum der Zeichenfläche"
)
expect(
    InteractionPolicies.requiredContentHeight(
        for: [
            InteractionPolicies.CanvasContentItem(offsetY: .nan, height: 40),
            InteractionPolicies.CanvasContentItem(offsetY: 30, height: .infinity)
        ],
        minimum: 216
    ) == 216,
    "Ungültige Maße blockieren den Griff nicht dauerhaft"
)
expect(
    InteractionPolicies.resizedCanvasHeight(
        requestedHeight: 300, lowerLimit: 390, upperLimit: 656
    ) == 390,
    "Nach oben ziehen stoppt am Bild/Textfeld, statt es zu verschieben"
)
expect(
    InteractionPolicies.resizedCanvasHeight(
        requestedHeight: 500, lowerLimit: 390, upperLimit: 656
    ) == 500,
    "Innerhalb der Grenzen folgt der Griff dem Finger"
)
expect(
    InteractionPolicies.resizedCanvasHeight(
        requestedHeight: 900, lowerLimit: 390, upperLimit: 656
    ) == 656,
    "Wachsen endet an der Bildschirmgrenze"
)
expect(
    InteractionPolicies.resizedCanvasHeight(
        requestedHeight: 100, lowerLimit: 280, upperLimit: 200
    ) == 280,
    "Der Inhalt gewinnt gegen eine zu kleine Obergrenze"
)
expect(
    InteractionPolicies.resizedCanvasHeight(
        requestedHeight: .nan, lowerLimit: 280, upperLimit: 656
    ) == 280,
    "Ungültige Anfrage fällt auf die Untergrenze zurück"
)
expect(
    InteractionPolicies.resizeBlockedByContent(requestedHeight: 300, lowerLimit: 390),
    "Anstoßen am Inhalt wird als Blockade gemeldet"
)
expect(
    !InteractionPolicies.resizeBlockedByContent(requestedHeight: 390, lowerLimit: 390),
    "Genau an der Inhaltsgrenze ist nichts blockiert"
)
expect(
    !InteractionPolicies.resizeBlockedByContent(requestedHeight: .nan, lowerLimit: 390),
    "Ungültige Werte lösen keine Rückmeldung aus"
)

// MARK: - Gehaltener Rückgängig-Knopf der Squeeze-Palette

expect(
    InteractionPolicies.dismissesSqueezePaletteAfterUndoScrub(isCircularScrub: true),
    "Loslassen des gehaltenen Kreis-Knopfs lässt die Squeeze-Bar verschwinden"
)
expect(
    !InteractionPolicies.dismissesSqueezePaletteAfterUndoScrub(isCircularScrub: false),
    "Der Balken der Werkzeugleiste taucht danach nicht ab"
)

// MARK: - Größenbudget der gespeicherten Rückgängig-Sitzung

expect(
    NoteUndoSessionPolicy.persistedStepCount(byteSizes: [100, 200, 300], budget: 1000) == 3,
    "Kleine Schritte bleiben vollständig erhalten"
)
expect(
    NoteUndoSessionPolicy.persistedStepCount(
        byteSizes: [1_000_000, 1_000_000, 1_000_000, 1_000_000]
    ) == 3,
    "Das Standard-Budget behält die drei neuesten Schritte"
)
expect(
    NoteUndoSessionPolicy.persistedStepCount(
        byteSizes: [1_000_000, 1_000_000, 5_000_000], budget: 3_000_000
    ) == 1,
    "Nur der neueste Schritt passt ins Budget"
)
expect(
    NoteUndoSessionPolicy.persistedStepCount(
        byteSizes: [1, 2, 4_000_000, 3], budget: 3_000_000
    ) == 1,
    "Ein übergroßer Schritt bläht die Datei nicht auf"
)
expect(
    NoteUndoSessionPolicy.persistedStepCount(byteSizes: [], budget: 1000) == 0,
    "Leerer Stapel bleibt leer"
)
expect(
    NoteUndoSessionPolicy.persistedStepCount(byteSizes: [10, 20], budget: 0) == 0,
    "Ohne Budget wird nichts gespeichert"
)
expect(
    NoteUndoSessionPolicy.persistedStepCount(byteSizes: [10, -1, 20], budget: 1000) == 1,
    "Ungültige Größen beenden das Zählen"
)

// MARK: - Schultage, Wochenende und Schulwoche

if let monday, let friday, let saturday,
   let sunday = germanCalendar.date(byAdding: .day, value: 1, to: saturday),
   let nextMonday = germanCalendar.date(byAdding: .day, value: 7, to: monday),
   let previousFriday = germanCalendar.date(byAdding: .day, value: -3, to: monday) {
    expect(SchoolWeekPolicy.isSchoolDay(monday, calendar: germanCalendar), "Montag ist ein Schultag")
    expect(SchoolWeekPolicy.isSchoolDay(friday, calendar: germanCalendar), "Freitag ist ein Schultag")
    expect(!SchoolWeekPolicy.isSchoolDay(saturday, calendar: germanCalendar), "Samstag ist kein Schultag")
    expect(!SchoolWeekPolicy.isSchoolDay(sunday, calendar: germanCalendar), "Sonntag ist kein Schultag")

    let afterFriday = SchoolWeekPolicy.nextSchoolDay(after: friday, calendar: germanCalendar)
    expect(germanCalendar.isDate(afterFriday, inSameDayAs: nextMonday), "Nach dem Freitag folgt der Montag")
    let afterSaturday = SchoolWeekPolicy.nextSchoolDay(after: saturday, calendar: germanCalendar)
    expect(germanCalendar.isDate(afterSaturday, inSameDayAs: nextMonday), "Nach dem Samstag folgt der Montag")
    let afterSunday = SchoolWeekPolicy.nextSchoolDay(after: sunday, calendar: germanCalendar)
    expect(germanCalendar.isDate(afterSunday, inSameDayAs: nextMonday), "Nach dem Sonntag folgt der Montag")
    let afterMonday = SchoolWeekPolicy.nextSchoolDay(after: monday, calendar: germanCalendar)
    expect(
        germanCalendar.isDate(afterMonday, inSameDayAs: germanCalendar.date(byAdding: .day, value: 1, to: monday)!),
        "Unter der Woche folgt der nächste Tag"
    )

    let beforeMonday = SchoolWeekPolicy.previousSchoolDay(before: monday, calendar: germanCalendar)
    expect(germanCalendar.isDate(beforeMonday, inSameDayAs: previousFriday), "Vor dem Montag kommt der Freitag")
    let beforeSaturday = SchoolWeekPolicy.previousSchoolDay(before: saturday, calendar: germanCalendar)
    expect(germanCalendar.isDate(beforeSaturday, inSameDayAs: friday), "Vor dem Samstag kommt der Freitag")

    let week = SchoolWeekPolicy.schoolDays(inWeekOf: saturday, calendar: germanCalendar)
    expect(week.count == 5, "Eine Schulwoche hat fünf Tage")
    if week.count == 5 {
        expect(germanCalendar.isDate(week[0], inSameDayAs: monday), "Die Schulwoche beginnt am Montag")
        expect(germanCalendar.isDate(week[4], inSameDayAs: friday), "Die Schulwoche endet am Freitag")
        var weekendInside = false
        for day in week where !SchoolWeekPolicy.isSchoolDay(day, calendar: germanCalendar) {
            weekendInside = true
        }
        expect(!weekendInside, "Die Schulwoche enthält kein Wochenende")
    }

    // `Date.schoolWeekDays` benutzt dieselbe Regel – auch am Wochenende.
    let weekFromDate = saturday.schoolWeekDays(using: germanCalendar)
    expect(weekFromDate.count == 5, "Date.schoolWeekDays nutzt dieselbe Regel")
    if let firstSchoolDay = weekFromDate.first {
        expect(
            firstSchoolDay == monday.startOfWeek(using: germanCalendar),
            "Am Wochenende bleibt der Wochenanfang der Montag"
        )
    }
}

// MARK: - Laufende Stunde im Stundenraster

let grid = Period.defaultPeriods
func slotAt(_ minutes: Int) -> CurrentPeriodSlot? {
    CurrentPeriodPolicy.slot(atMinutes: minutes, in: grid)
}

expect(slotAt(7 * 60 + 59) == .beforeFirstPeriod, "Vor 08:00 hat der Schultag nicht begonnen")
expect(slotAt(8 * 60) == .inPeriod(grid[0]), "08:00 beginnt die erste Stunde")
expect(slotAt(8 * 60 + 44) == .inPeriod(grid[0]), "Eine Minute vor dem Ende läuft die Stunde noch")
expect(slotAt(8 * 60 + 45) == .inBreak(next: grid[1]), "Die Endzeit gehört zur folgenden Pause")
expect(slotAt(8 * 60 + 49) == .inBreak(next: grid[1]), "Die ganze Pause verweist auf die nächste Stunde")
expect(slotAt(8 * 60 + 50) == .inPeriod(grid[1]), "08:50 beginnt die zweite Stunde")
expect(slotAt(9 * 60 + 40) == .inBreak(next: grid[2]), "Lange Pause nach der zweiten Stunde")
expect(slotAt(16 * 60 + 54) == .inPeriod(grid[9]), "Die letzte Stunde läuft bis 16:55")
expect(slotAt(16 * 60 + 55) == .afterLastPeriod, "Nach der letzten Stunde ist der Schultag vorbei")
expect(slotAt(23 * 60 + 59) == .afterLastPeriod, "Auch kurz vor Mitternacht bleibt es „danach“")
expect(CurrentPeriodPolicy.slot(atMinutes: 8 * 60, in: []) == nil, "Ein leeres Raster hat keinen Slot")

// Ungültige Stunden (Ende ≤ Beginn) werden ignoriert und verschieben die
// Auswertung nicht.
let brokenGrid = [
    Period(periodNumber: 2, startTime: "09:00", endTime: "08:00"),
    Period(periodNumber: 1, startTime: "08:00", endTime: "08:45"),
    Period(periodNumber: 3, startTime: "09:30", endTime: "09:30")
]
expect(
    CurrentPeriodPolicy.slot(atMinutes: 8 * 60 + 10, in: brokenGrid) == .inPeriod(brokenGrid[1]),
    "Auch in einem gemischten Raster wird die gültige Stunde gefunden"
)
expect(
    CurrentPeriodPolicy.slot(atMinutes: 8 * 60 + 50, in: brokenGrid) == .afterLastPeriod,
    "Nach der einzigen gültigen Stunde ist der Schultag vorbei"
)

// Überlappende Stunden werden nach Beginn aufgelöst: die früheste gewinnt.
let overlappingGrid = [
    Period(periodNumber: 2, startTime: "08:30", endTime: "09:30"),
    Period(periodNumber: 1, startTime: "08:00", endTime: "09:00")
]
expect(
    CurrentPeriodPolicy.slot(atMinutes: 8 * 60 + 45, in: overlappingGrid) == .inPeriod(overlappingGrid[1]),
    "Bei einer Überlappung gewinnt die früher beginnende Stunde"
)

// Gleiche Startzeiten in defekten Importdaten werden reproduzierbar
// aufgelöst: die kürzere Stunde steht im sortierten Raster zuerst.
let duplicateStartGrid = [
    Period(periodNumber: 1, startTime: "08:00", endTime: "09:00"),
    Period(periodNumber: 2, startTime: "08:00", endTime: "08:30")
]
expect(
    CurrentPeriodPolicy.slot(atMinutes: 8 * 60 + 15, in: duplicateStartGrid) == .inPeriod(duplicateStartGrid[1]),
    "Bei identischem Beginn gewinnt deterministisch das kürzere Intervall"
)

// Fortschritt: nur innerhalb einer Stunde und auf 0…1 begrenzt.
let runningSlot = slotAt(8 * 60 + 22)
expect(runningSlot == .inPeriod(grid[0]), "08:22 liegt in der ersten Stunde")
if let runningSlot,
   let runningProgress = CurrentPeriodPolicy.progress(of: runningSlot, atMinutes: 8 * 60 + 22) {
    expect(abs(runningProgress - 22.0 / 45.0) < 0.0001, "Der Fortschritt misst sich an der Stundenlänge")
} else {
    expect(false, "Eine laufende Stunde hat einen Fortschritt")
}
expect(
    CurrentPeriodPolicy.progress(of: .beforeFirstPeriod, atMinutes: 7 * 60) == nil,
    "Außerhalb einer Stunde gibt es keinen Fortschritt"
)

// Die Date-Variante benutzt dasselbe Raster und denselben Kalender der App.
if let lessonDate = germanCalendar.date(
    from: DateComponents(calendar: germanCalendar, year: 2026, month: 10, day: 12, hour: 8, minute: 30)
) {
    expect(
        CurrentPeriodPolicy.slot(at: lessonDate, in: grid, calendar: germanCalendar) == .inPeriod(grid[0]),
        "Ein Date wird in Minuten seit Mitternacht übersetzt"
    )
}


// MARK: - Noten & Punkte (reine Rechenregeln)

// Normale Noten: 1 ist die beste, 6 die schlechteste Note.
expect(GradeMath.fraction(for: 1, unit: .grades, maximumPoints: 15, higherPointsAreBetter: true) == 1,
       "Note 1 ist der beste Wert")
expect(GradeMath.fraction(for: 6, unit: .grades, maximumPoints: 15, higherPointsAreBetter: true) == 0,
       "Note 6 ist der schlechteste Wert")
expect(abs(GradeMath.grade(forFraction: 1) - 1) < 0.0001, "Perfektes Verhältnis ergibt Note 1")
expect(abs(GradeMath.grade(forFraction: 0) - 6) < 0.0001, "Null-Verhältnis ergibt Note 6")
expect(GradeMath.gradeText(2.0) == "2", "Ganze Noten ohne Nachkommastelle")
expect(GradeMath.gradeText(2.3) == "2,3", "Noten mit deutschem Dezimalkomma")

// Punkte: Richtung und Umrechnung.
expect(abs(GradeMath.fraction(for: 15, unit: .points, maximumPoints: 15, higherPointsAreBetter: true) - 1) < 0.0001,
       "Volle Punktzahl ist bei „mehr ist besser“ der beste Wert")
expect(abs(GradeMath.fraction(for: 0, unit: .points, maximumPoints: 15, higherPointsAreBetter: false) - 1) < 0.0001,
       "0 Punkte ist bei „weniger ist besser“ der beste Wert")
expect(GradeMath.valueText(12, unit: .points, maximumPoints: 15) == "12",
       "Punkte ohne Nachkommastellen")
expect(GradeMath.valueText(85, unit: .percent, maximumPoints: 15) == "85 %",
       "Prozent mit Prozentzeichen")

// Werte werden immer in die zulässigen Grenzen gebracht.
expect(GradeMath.sanitizedValue(99, unit: .grades, maximumPoints: 15) == 6,
       "Noten werden auf 1…6 begrenzt")
expect(GradeMath.sanitizedValue(-5, unit: .percent, maximumPoints: 15) == 0,
       "Prozent werden auf 0…100 begrenzt")
expect(GradeMath.sanitizedValue(500, unit: .points, maximumPoints: 15) == 15,
       "Punkte werden auf die Höchstpunktzahl begrenzt")

// Regler: Note 1 links, 6 rechts – Startwert aus der Einstellung.
let gradeSliderValue = GradeMath.value(forSliderFraction: 0.5, unit: .grades, maximumPoints: 15)
expect(gradeSliderValue == 3.5, "Regler-Mitte ergibt bei Noten 3,5")
let pointsSliderValue = GradeMath.value(forSliderFraction: 0.5, unit: .points, maximumPoints: 15)
expect(pointsSliderValue == 8, "Regler-Mitte ergibt bei 15 Punkten 8")
let percentSliderValue = GradeMath.value(forSliderFraction: 0.5, unit: .percent, maximumPoints: 15)
expect(percentSliderValue == 50, "Regler-Mitte ergibt 50 %")

// Durchschnitt von Einträgen.
let gradeEntries = [
    GradeEntry(value: 1, unit: .grades, maximumPoints: 15, note: "Test 1"),
    GradeEntry(value: 2, unit: .grades, maximumPoints: 15, note: "Test 2")
]
expect(abs(GradeMath.grade(forFraction: GradeMath.averageFraction(for: gradeEntries) ?? 0) - 1.5) < 0.0001,
       "Durchschnitt aus 1 und 2 ist 1,5")
expect(GradeMath.averageText(for: []) == "–", "Ohne Einträge gibt es keinen Durchschnitt")
// Punkte und Noten bleiben vergleichbar: 15 Punkte (beste) und Note 1 mitteln sich zu 1,0.
let mixedEntries = [
    GradeEntry(value: 15, unit: .points, maximumPoints: 15, higherPointsAreBetter: true),
    GradeEntry(value: 1, unit: .grades, maximumPoints: 15)
]
expect(abs(GradeMath.grade(forFraction: GradeMath.averageFraction(for: mixedEntries) ?? 0) - 1) < 0.0001,
       "Punkte und Noten werden über dasselbe Verhältnis gemittelt")

// Farbskala: gute Einträge pastellig-grün, schlechte kräftig-rot.
let goodColor = GradeMath.colorHex(forFraction: 1)
let badColor = GradeMath.colorHex(forFraction: 0)
expect(goodColor.hasPrefix("#"), "Farbe ist ein Hex-Wert")
expect(goodColor != badColor, "Gute und schlechte Einträge haben verschiedene Farben")
// Grün: der Grünanteil ist bei einer 1 größer als der Rotanteil.
func hexChannel(_ hex: String, _ index: Int) -> Int {
    let cleaned = hex.replacingOccurrences(of: "#", with: "")
    let start = cleaned.index(cleaned.startIndex, offsetBy: index * 2)
    let end = cleaned.index(start, offsetBy: 2)
    return Int(cleaned[start..<end], radix: 16) ?? 0
}
expect(hexChannel(goodColor, 1) > hexChannel(goodColor, 0),
       "Sehr gute Noten sind grün eingefärbt")
expect(hexChannel(badColor, 0) > hexChannel(badColor, 1),
       "Sehr schlechte Noten sind rot eingefärbt")

// Sortierung der Fächer nach Durchschnitt und Einträgen.
let subjectEntries: [String: [GradeEntry]] = [
    "M": [GradeEntry(value: 1, unit: .grades), GradeEntry(value: 1, unit: .grades)],
    "D": [GradeEntry(value: 5, unit: .grades)],
    "E": []
]
let sortedByBest = GradeMath.sortedSubjectKeys(
    ["M", "D", "E"],
    displayName: { $0 },
    entries: { subjectEntries[$0] ?? [] },
    sort: .bestAverage
)
expect(sortedByBest.first == "M", "Bester Durchschnitt steht oben")
expect(sortedByBest.last == "E", "Fächer ohne Einträge stehen unten")
let sortedByCount = GradeMath.sortedSubjectKeys(
    ["M", "D", "E"],
    displayName: { $0 },
    entries: { subjectEntries[$0] ?? [] },
    sort: .mostEntries
)
expect(sortedByCount.first == "M", "Am meisten Einträge steht oben")

// Sortierung der Einträge innerhalb eines Fachs.
let sortableEntries = [
    GradeEntry(value: 3, unit: .grades, date: Date(timeIntervalSince1970: 300)),
    GradeEntry(value: 1, unit: .grades, date: Date(timeIntervalSince1970: 100)),
    GradeEntry(value: 2, unit: .grades, date: Date(timeIntervalSince1970: 200))
]
expect(GradeMath.sortedEntries(sortableEntries, sort: .best).first?.value == 1,
       "„Beste“ sortiert die 1 nach oben")
expect(GradeMath.sortedEntries(sortableEntries, sort: .worst).first?.value == 3,
       "„Schlechteste“ sortiert die 3 nach oben")
expect(GradeMath.sortedEntries(sortableEntries, sort: .newest).first?.value == 3,
       "„Zuletzt hinzugefügt“ sortiert nach Datum absteigend")
expect(GradeMath.sortedEntries(sortableEntries, sort: .oldest).first?.value == 1,
       "„Älteste“ sortiert nach Datum aufsteigend")

// Einstellungen begrenzen ihre Werte selbst.
expect(GradeSettings(isEnabled: true, maximumPoints: 500).maximumPoints == 200,
       "Höchstpunktzahl endet bei 200")
expect(GradeSettings(isEnabled: true, maximumPoints: 0).maximumPoints == 1,
       "Höchstpunktzahl beginnt bei 1")
expect(GradeSettings(isEnabled: true, defaultSliderFraction: 4).defaultSliderFraction == 1,
       "Der Regler-Startwert bleibt zwischen 0 und 1")
expect(GradeSettings().isEnabled == false, "Das Modul ist standardmäßig aus")
expect(GradeSettings(isEnabled: true, system: .points, convertsToGrade: false).showsGradesForEntries == false,
       "Punkte ohne Umrechnung zeigen keine Note")
expect(GradeSettings(isEnabled: true, system: .points, convertsToGrade: true).showsGradesForEntries == true,
       "Punkte mit Umrechnung zeigen die Note")

// Ein Fach behält höchstens 500 Einträge; Löschen räumt leere Fächer auf.
var gradeBook = GradeBook()
let noteEntry = GradeEntry(value: 2, unit: .grades)
expect(gradeBook.upsert(noteEntry, subjectKey: "deutsch"), "Eintrag wird gespeichert")
expect(gradeBook.entries(forSubjectKey: "deutsch").count == 1, "Eintrag liegt beim Fach")
gradeBook.remove(entryID: noteEntry.id, subjectKey: "deutsch")
expect(gradeBook.entries(forSubjectKey: "deutsch").isEmpty, "Löschen entfernt den Eintrag")
expect(gradeBook.entriesBySubject["deutsch"] == nil, "Leere Fächer werden nicht behalten")
var renamedBook = GradeBook()
renamedBook.upsert(noteEntry, subjectKey: "m")
renamedBook.renameSubject(from: "m", to: "mathe")
expect(renamedBook.entries(forSubjectKey: "mathe").count == 1,
       "Beim Umbenennen wandern die Einträge mit")

// MARK: - Handy-Notizen (Layout-Regeln ohne UIKit)

expect(MobileNotePolicy.resolvedPhoneFontSize(stored: 200, fallback: 17) == 40,
       "Zu große Schrift wird auf das Maximum begrenzt")
expect(MobileNotePolicy.resolvedPhoneFontSize(stored: 2, fallback: 17) == 10,
       "Zu kleine Schrift wird auf das Minimum begrenzt")
expect(MobileNotePolicy.resolvedPhoneFontSize(stored: nil, fallback: 17) == 17,
       "Ohne gespeicherten Wert gilt der Standard")
expect(MobileNotePolicy.shrunk(fontSize: 10) == 10, "Kleiner als das Minimum geht nicht")
expect(MobileNotePolicy.grown(fontSize: 40) == 40, "Größer als das Maximum geht nicht")

// Text bricht um, statt über den Rand zu laufen: Zeichen pro Zeile begrenzt.
func referenceCharacter(_ size: Double) -> MobileNotePolicy.TextSize {
    MobileNotePolicy.TextSize(width: size * 0.55, height: size * 1.25)
}
let shortLayout = MobileNotePolicy.layout(
    text: "Hallo",
    fontSize: 17,
    availableWidth: 300,
    availableHeight: 400,
    characterSize: referenceCharacter
)
expect(shortLayout.fits, "Kurzer Text passt ohne Verkleinern")
expect(!shortLayout.isBlocked, "Kurzer Text blockiert keine Eingabe")

// Sehr langer Text in niedrigem Bereich: die Schrift wird kleiner.
let longText = String(repeating: "Wort ", count: 400)
let shrunkLayout = MobileNotePolicy.layout(
    text: longText,
    fontSize: 30,
    availableWidth: 300,
    availableHeight: 200,
    characterSize: referenceCharacter
)
expect(!shrunkLayout.fits, "Langer Text passt nicht in der Ausgangsgröße")
expect(shrunkLayout.requiredFontSize < 30, "Die Schrift wird dafür verkleinert")
expect(shrunkLayout.requiredFontSize >= MobileNotePolicy.minimumPhoneFontSize,
       "Die Schrift wird nie unter das Minimum verkleinert")

// Wenn selbst das Minimum nicht reicht, wird die Eingabe blockiert.
let blockedLayout = MobileNotePolicy.layout(
    text: longText,
    fontSize: 30,
    availableWidth: 120,
    availableHeight: 40,
    characterSize: referenceCharacter
)
expect(blockedLayout.isBlocked, "Passt der Text auch klein nicht, wird die Eingabe blockiert")
expect(blockedLayout.requiredFontSize == MobileNotePolicy.minimumPhoneFontSize,
       "Blockiert wird bei der kleinsten Schriftgröße")

// Zeilenumbruch: harte Umbrüche und lange Wörter werden korrekt gezählt.
expect(MobileNotePolicy.wrappedLineCount(text: "a\nb", charactersPerLine: 10) == 2,
       "Harte Zeilenumbrüche zählen als eigene Zeile")
expect(MobileNotePolicy.wrappedLineCount(text: "ein zwei drei", charactersPerLine: 10) == 2,
       "Volle Zeile bricht vor dem nächsten Wort um")
expect(MobileNotePolicy.wrappedLineCount(text: "aaaaaaaaaaaa", charactersPerLine: 4) == 3,
       "Überlange Wörter werden hart umbrochen")

// MARK: - iPad-Textfeld: mitwachsen, aber nur bis zum Rand

expect(NoteTextBox(text: "Hallo", x: 10, y: 10, width: 120).autoGrowWidth,
       "Neue Textfelder wachsen automatisch mit")
if let grown = NoteTextBox.autoGrownWidth(text: "Ein längerer Text", currentWidth: 120, maxWidth: 600, fontSize: 17) {
    expect(grown > 120, "Längerer Text macht das Feld breiter")
} else {
    expect(false, "Längerer Text muss das Feld verbreitern")
}
expect(NoteTextBox.autoGrownWidth(text: "Hallo", currentWidth: 600, maxWidth: 300, fontSize: 17) == nil,
       "Über dem Rand wächst nichts mehr (der Text bricht um)")
expect(NoteTextBox.autoGrownWidth(text: "Hi", currentWidth: 400, maxWidth: 600, fontSize: 17) == nil,
       "Kurzer Text verkleinert das Feld nicht")
expect(NoteTextBox.autoGrownWidth(text: "Text", currentWidth: 300, maxWidth: 200, fontSize: 17) == nil,
       "Ein ungültiger Bereich ändert nichts")
expect(NoteTextBox.wraps("Ein sehr langer Text über mehrere Wörter", width: 60, fontSize: 17),
       "Zu breiter Text würde umbrechen")
expect(!NoteTextBox.wraps("Hi", width: 400, fontSize: 17),
       "Schmaler Text bricht nicht um")

// MARK: - Ordner-Sync (Zusammenführen ohne Dateisystem)

let syncBaseDate = Date(timeIntervalSince1970: 1_800_000_000)

func syncDocument(_ key: String, _ offset: TimeInterval = 0, _ payload: String = "x") -> FolderSyncDocument {
    FolderSyncDocument(
        key: key,
        updatedAt: syncBaseDate.addingTimeInterval(offset),
        data: Data(payload.utf8)
    )
}

// 1) Nur lokal vorhanden → in den Ordner schreiben.
let localOnlyPlan = FolderSyncRules.merge(
    local: ["a": syncDocument("a")],
    remote: [:],
    tombstones: [:],
    remoteKnownKeys: [],
    lastSyncDate: nil
)
expect(localOnlyPlan.documentsToWrite.map(\.key) == ["a"], "Neue lokale Notiz wird hochgeladen")
expect(localOnlyPlan.incomingDocuments.isEmpty, "Es kommt nichts Fremdes zurück")

// 2) Nur im Ordner vorhanden → lokal übernehmen.
let remoteOnlyPlan = FolderSyncRules.merge(
    local: [:],
    remote: ["b": syncDocument("b")],
    tombstones: [:],
    remoteKnownKeys: [],
    lastSyncDate: nil
)
expect(remoteOnlyPlan.incomingDocuments.map(\.key) == ["b"], "Fremde Notiz wird übernommen")

// 3) Beidseitig: der neuere Stand gewinnt – beide Richtungen.
let newerLocalPlan = FolderSyncRules.merge(
    local: ["c": syncDocument("c", 100)],
    remote: ["c": syncDocument("c", 0)],
    tombstones: [:],
    remoteKnownKeys: ["c"],
    lastSyncDate: syncBaseDate
)
expect(newerLocalPlan.documentsToWrite.map(\.key) == ["c"], "Die neuere lokale Fassung wird geschrieben")
expect(newerLocalPlan.incomingDocuments.isEmpty, "Die ältere Fassung wird nicht übernommen")

let newerRemotePlan = FolderSyncRules.merge(
    local: ["c": syncDocument("c", 0)],
    remote: ["c": syncDocument("c", 100)],
    tombstones: [:],
    remoteKnownKeys: ["c"],
    lastSyncDate: syncBaseDate
)
expect(newerRemotePlan.incomingDocuments.map(\.key) == ["c"], "Die neuere Fassung aus dem Ordner gewinnt")

// Zeitstempel-Toleranz: gleiche Sekunde gilt als gleich (kein Hin- und Herschreiben).
let equalStampPlan = FolderSyncRules.merge(
    local: ["d": syncDocument("d", 0)],
    remote: ["d": syncDocument("d", 0.4)],
    tombstones: [:],
    remoteKnownKeys: ["d"],
    lastSyncDate: syncBaseDate
)
expect(equalStampPlan.isEmpty, "Fast gleiche Zeitstempel lösen keinen Schreibvorgang aus")

// 4) Lokal gelöscht (Grabstein) → Datei im Ordner wird entfernt.
let tombstonePlan = FolderSyncRules.merge(
    local: [:],
    remote: ["e": syncDocument("e", 0)],
    tombstones: ["e": syncBaseDate.addingTimeInterval(10)],
    remoteKnownKeys: ["e"],
    lastSyncDate: syncBaseDate
)
expect(tombstonePlan.documentsToDeleteRemotely == ["e"], "Eine lokale Löschung entfernt die Datei im Ordner")
expect(tombstonePlan.incomingDocuments.isEmpty, "Eine gelöschte Notiz kommt nicht zurück")

// 5) Anderswo gelöscht, hier unverändert → lokal löschen.
let remoteDeletePlan = FolderSyncRules.merge(
    local: ["f": syncDocument("f", -100)],
    remote: [:],
    tombstones: [:],
    remoteKnownKeys: ["f"],
    lastSyncDate: syncBaseDate
)
expect(remoteDeletePlan.documentsToDeleteLocally == ["f"], "Die Löschung des anderen Geräts wird übernommen")

// 6) Anderswo gelöscht, hier aber seither bearbeitet → Bearbeitung gewinnt.
let localEditWinsPlan = FolderSyncRules.merge(
    local: ["g": syncDocument("g", 100)],
    remote: [:],
    tombstones: [:],
    remoteKnownKeys: ["g"],
    lastSyncDate: syncBaseDate
)
expect(localEditWinsPlan.documentsToWrite.map(\.key) == ["g"],
       "Eine neuere lokale Bearbeitung wird nicht durch eine fremde Löschung verworfen")

// 7) Gelöscht UND anderswo neuer bearbeitet → die Bearbeitung kommt zurück.
let revivedPlan = FolderSyncRules.merge(
    local: [:],
    remote: ["h": syncDocument("h", 100)],
    tombstones: ["h": syncBaseDate],
    remoteKnownKeys: ["h"],
    lastSyncDate: syncBaseDate
)
expect(revivedPlan.incomingDocuments.map(\.key) == ["h"],
       "Eine nach der Löschung bearbeitete Notiz kommt zurück")

// Das Einstellungs-Dokument wird nie gelöscht und immer nach Zeitstempel gewählt.
let settingsPlan = FolderSyncRules.merge(
    local: [FolderSyncDocument.settingsKey: syncDocument(FolderSyncDocument.settingsKey, 100)],
    remote: [FolderSyncDocument.settingsKey: syncDocument(FolderSyncDocument.settingsKey, 0)],
    tombstones: [:],
    remoteKnownKeys: [],
    lastSyncDate: nil
)
expect(settingsPlan.documentsToWrite.map(\.key) == [FolderSyncDocument.settingsKey],
       "Das neuere Einstellungs-Dokument wird geschrieben")
expect(settingsPlan.documentsToDeleteRemotely.isEmpty,
       "Das Einstellungs-Dokument wird nie als Löschung behandelt")

// Dateinamen sind gefahrlos – auch bei Schlüsseln mit Sonderzeichen.
let unsafeKey = "2026-09-30_1/Deutsch:Test"
let safeName = FolderSyncDocument.safeFileName(for: unsafeKey)
expect(!safeName.contains("/") && !safeName.contains(":"), "Dateinamen enthalten keine Sonderzeichen")
expect(safeName == FolderSyncDocument.safeFileName(for: unsafeKey),
       "Derselbe Schlüssel ergibt immer denselben Dateinamen")
expect(FolderSyncDocument.safeFileName(for: "kurz") == "kurz", "Unproblematische Schlüssel bleiben erhalten")

// Grabsteine verfallen nach 30 Tagen.
let pruned = FolderSyncRules.prunedTombstones(
    [
        "alt": syncBaseDate.addingTimeInterval(-40 * 24 * 3600),
        "neu": syncBaseDate.addingTimeInterval(-1 * 24 * 3600)
    ],
    now: syncBaseDate
)
expect(pruned["alt"] == nil, "Alte Grabsteine werden entsorgt")
expect(pruned["neu"] != nil, "Frische Grabsteine bleiben erhalten")

// Der Inhalts-Hash ist stabil und erkennt Änderungen.
let hashA = FolderSyncRules.contentHash(of: ["a": syncDocument("a")])
let hashB = FolderSyncRules.contentHash(of: ["a": syncDocument("a")])
expect(hashA == hashB, "Gleicher Inhalt ergibt denselben Hash")
let hashC = FolderSyncRules.contentHash(of: ["a": syncDocument("a", 5)])
expect(hashA != hashC, "Ein neuerer Zeitstempel ändert den Hash")

print("\(checks) Interaktions-/Sync-/Layout-Checks erfolgreich.")
