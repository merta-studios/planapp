# Fixes Summary - PlanApp Verbesserungen

## 1. Bild-Zuschneide-Logik (Image Crop Handles) ✅

**Problem:** Beim Zuschneiden eines Bildes konnte man die Randpunkte nicht ziehen, sondern musste irgendwo in der Mitte anfangen zu ziehen, und dann ging dort der untere rechte Punkt hin.

**Lösung:**
- **Gesture-Priorität:** Die Handle-Gesten verwenden jetzt `.highPriorityGesture` statt `.gesture`, damit sie Vorrang vor der Move-Geste des Rechtecks haben
- **Stabiler Start-Zustand:** Die Handle-Geste speichert jetzt den Crop-Zustand beim Start (`handleStartCrop`) und berechnet alle Ecken-Positionen relativ zu diesem stabilen Ausgangspunkt
- **Korrekte Eck-Berechnung:** Jede Ecke wird jetzt korrekt berechnet, sodass die gegenüberliegende Ecke fixiert bleibt

**Geänderte Datei:** `Views/Drawing/NoteImageCropView.swift`

---

## 2. Zeichenfläche verkleinern: Inhalt blockiert den Griff ✅

**Problem:** Beim Ziehen des runden Griffs nach oben (Zeichenfläche kleiner machen) wurden Bilder und Textfelder, die im Weg lagen, nach oben geschoben. Der Inhalt wanderte dadurch unerwartet durch die Notiz.

**Gewünschtes Verhalten:** Die Zeichenfläche darf **nicht** über ein Bild oder Textfeld hinweg verkleinert werden. Der Griff stoppt an der Unterkante des tiefsten Elements; kleiner geht es erst, nachdem man das Element zur Seite geräumt hat.

**Lösung:**
- `clampContentToCanvasHeight()` (das Hochschieben des Inhalts) ist ersatzlos entfernt – Inhalt wird beim Verkleinern nie mehr bewegt
- Neue berechnete Eigenschaft `canvasContentFloorHeight`: tiefste Unterkante aller Textfelder (inkl. geschätzter Texthöhe) und Bilder plus 6 pt Rand, mindestens die Inhaltshöhe des absoluten Minimums
- Beim Verkleinern gilt `lowerLimit = min(max(minimumCanvasHeight, canvasContentFloorHeight), canvasHeight)`; beim Wachsen bleibt das bisherige Minimum (die Messung der Texthöhen entfällt dann)
- Die Grenze vergrößert den Zettel nie von selbst: Ist er beim Laden aus der Zeilenzahl kleiner gerundet worden, als sein Inhalt erlaubt, bleibt er stehen, statt aufzuspringen
- Neue, testbare Regeln in `InteractionPolicies`: `requiredContentHeight(for:margin:minimum:)`, `resizedCanvasHeight(requestedHeight:lowerLimit:upperLimit:)`, `resizeBlockedByContent(requestedHeight:lowerLimit:tolerance:)`
- Ungültige Maße (NaN/∞) werden übersprungen, damit ein einzelner kaputter Rahmen den Griff nicht dauerhaft blockiert
- Rückmeldung statt stiller Blockade: Steht der Griff am Inhalt an, gibt es **einmal pro Zieh-Geste** `Haptics.warning()`

**Geänderte Dateien:** `Utils/InteractionPolicies.swift`, `Views/Drawing/LessonDrawingOverlayView.swift`, `Tests/InteractionRegressions/main.swift`

---

## 3. Notiz-Schließen: kein Einfrieren mehr nach dem Rückflug ✅

**Problem:** Beim Schließen einer Notiz glitt sie zum Fach-Block zurück und blieb dort rund zwei Sekunden liegen, in denen die ganze App nicht bedienbar war (Wochen wischen, Stunden antippen – nichts ging).

**Ursache:** Vor dem Abbauen des Overlays lief das komplette Speichern auf dem Main Thread:
1. `persistEditingHistory()` → `saveNoteUndoSessions`: JSON-Encoding **aller** Rückgängig-Vollstände (bis zu 40 Schritte × 3 Notizen, jeder mit Zeichnung, Textfeldern und Bildern bis 3 MB) – bei bildreichen Notizen schnell zweistellige Megabyte, base64-kodiert ein Vielfaches davon
2. erst danach das animierte `closeNoteOverlay()`
3. danach `persistNote` → vier atomare Dateischreiben, kompletter Metadaten-Neuaufbau in `UserDefaults` plus `synchronize()` und zweimaliges Dekodieren der PencilKit-Daten für die Inhaltsprüfung

Solange das Overlay hängt, nimmt diese Vollbild-Ebene jede Berührung an – die Bedienung war also genau während dieser Arbeit blockiert.

**Lösung (neue Reihenfolge):**
- Der Rückgängig-Verlauf wird **als Wert** gesichert, bevor das Overlay abgebaut wird (danach lebt der `@State`-Speicher dieser Ansicht nicht mehr)
- `closeNoteOverlay()` kommt zuerst und läuft ohne Animation (`Transaction(disablesAnimations: true)`): Die Notiz ist in dem Moment im Block angekommen, in dem das Overlay verschwindet
- `persistNote` bekommt den Strich-Inhalt direkt aus der Zeichnung im Speicher (`hasInkContent: !croppedDrawing.strokes.isEmpty`) statt die serialisierten Daten erneut zu dekodieren
- Das bisherige Vorschaubild bleibt als Platzhalter stehen, bis Phase 2 (Vorschau rendern) im Hintergrund fertig ist und `updateNotePreview` einspielt
- `TimetableStorageService` schreibt **alles** auf einer seriellen Hintergrund-Queue (`planapp.storage.writes`) und ohne `synchronize()`; die Reihenfolge der Schreibvorgänge bleibt erhalten
- `NoteCacheService.saveNote(_:hasVisibleContent:)` übernimmt den bekannten Inhalt und spart so das PencilKit-Decoding
- Größenbudget für die gespeicherte Sitzung: `NoteUndoSessionPolicy.maximumPersistedStackBytes` (3 MB) bzw. `maximumPersistedStepBytes` (8 MB) plus `persistedStepCount(byteSizes:budget:stepCeiling:)` und `NoteHistorySnapshot.approximateByteSize`. Gespeichert wird das zusammenhängende Ende jedes Stapels, das ins Budget passt – der pathologische Riesen-Schreibvorgang ist damit ausgeschlossen
- `saveAndDismiss` hält eine feste Referenz (`let model = viewModel`): Teile des Schließens laufen erst, nachdem das Overlay die Hierarchie verlassen hat, und dürfen nicht mehr über die Umgebung danach fragen

**Geänderte Dateien:** `Views/Drawing/LessonDrawingOverlayView.swift`, `ViewModels/TimetableViewModel.swift`, `Services/TimetableStorageService.swift`, `Services/NoteCacheService.swift`, `Models/NoteUndoHistory.swift`, `Utils/HeroTransitionPolicy.swift`

---

## 4. Mobile Design Verbesserungen ✅

**Problem:** Auf dem Handy ist alles zu groß und nicht optimal für die kleine Bildschirmgröße designed.

**Lösung - Umfangreiche Kompakt-Optimierungen:**

### DeviceLayout.swift
- Neue Mobile-spezifische Konstanten hinzugefügt:
  - `fontSizeScale`: 0.85 für iPhone (15% kleinere Schriften)
  - `compactSpacing` / `regularSpacing`: kompaktere Abstände
  - `iconSize` / `smallIconSize`: kleinere Icons
  - `buttonHeight` / `compactButtonHeight`: kompaktere Buttons
- Perioden-Spalte schmaler: 38pt → 34pt
- Header-Höhe kompakter: 40pt → 36pt
- Minimale Zeilenhöhe reduziert: 58pt → 54pt
- Tagesspalten-Berechnung optimiert für mehr Platz

### LessonBlockView.swift
- Content-Padding reduziert: 5pt → 4pt (iPhone)
- Titel-Schriftgröße: 11pt → 10pt (iPhone)
- Detail-Schriftgröße: 9pt → 8pt (iPhone)

### NoteHeaderContent.swift
- Kompakter Header für iPhone optimiert:
  - Titel: 15pt → 14pt
  - Stunde: 11pt → 10pt
  - Datum: 10pt → 9pt
  - Spacing: 3pt → 2pt
  - Min-Height: 44pt → 40pt

### DrawingToolbarView.swift
- Toolbar-Höhe reduziert: 28-32pt → 26-30pt (iPhone)

### DayColumnView.swift
- Wochentag-Schrift: 12pt → 11pt (iPhone)
- Datums-Schrift: 9pt → 8pt (iPhone)

### PeriodColumnView.swift
- Clock-Icon: 12pt → 10pt (iPhone)
- Perioden-Nummer: 13pt → 12pt (iPhone)
- Startzeit: 8pt → 7pt (iPhone)
- Spacing: 1pt → 0pt
- Padding: 2pt → 1pt

### TimetableView.swift
- Horizontal-Padding: 4pt → 3pt (iPhone)
- Vertical-Padding: 8pt → 6pt (iPhone)
- Spalten-Spacing: 2pt → 1pt (iPhone)

---

## 5. Wochenwechsel ohne Verzögerung ✅

**Problem:** Beim Wechsel der Woche ruckelte die App deutlich.

**Ursachen und Lösung:**
- **Formatter-Churn:** Jeder Datumshelfer in `Utils/DateExtensions.swift` baute pro Aufruf einen neuen `DateFormatter` (und `Calendar.germanCalendar` einen neuen `Calendar`) – bei 15 Tagesspalten × 3 Wochen mehrere hundert Instanzen pro Render-Durchlauf. Alle Formatter und der Kalender liegen jetzt einmalig in `PlanDateFormatting` (statische gespeicherte Eigenschaften sind in Extensions nicht erlaubt)
- **Stunden-Suchen:** Jede `DayColumnView` lief für `lessonsFor(day:)` zweimal über **alle** Stunden, `hasLessons(inWeekStarting:)` zusätzlich ~16×. Beides ist jetzt pro Tagesschlüssel memoisiert (`lessonsByDayCache`, `lessonDayKeysCache`), ungültig gemacht über `lessonsRevision`
- **Synchrones Lesen im Render-Pfad:** `LessonBlockView` rief `viewModel.noteFor(lesson:)` auf, das bei Bedarf vier Dateien liest und dekodiert – für bis zu ~120 Karten gleichzeitig, mitten in der Wisch-Animation. Neu: `renderedNote(for:)` liefert nur, was im Speicher liegt, und merkt Fehlendes vor; die vorgemerkten Notizen werden gebündelt (80 ms) im Hintergrund geladen und danach eingespielt. Angefordert wird nur, was wirklich angezeigt wird (eingeschaltete Vorschau + `visibleNoteKeys`)
- **Metadaten-Aufbau:** `UserDefaults.dictionary(forKey:)` baute bei jedem `loadNote` ein neues `[String: Any]` je Notiz auf. Die Metadaten sind jetzt hinter `metadataLock` zwischengespeichert
- **Schreiben auf dem Main Thread:** `syncWeek` speicherte Perioden, Stunden und Zugangsdaten synchron (JSON + `synchronize()` + atomare Sicherungskopie). Alles läuft auf der seriellen `writeQueue`

**Geänderte Dateien:** `Utils/DateExtensions.swift`, `ViewModels/TimetableViewModel.swift`, `Views/Timetable/LessonBlockView.swift`, `Services/TimetableStorageService.swift`

---

## 6. Gehaltener Rückgängig-Knopf: Squeeze-Bar verschwindet ✅

**Problem:** Wer in der Squeeze-Bar den Rückgängig-Knopf lange hielt (Scrubs-Geste) und losließ, bekam die komplette Bar mit allen Knöpfen wieder eingeblendet. Erwartet: Sie verschwindet.

**Ursache:** `endUndoScrub()` setzte nur `undoScrubSession = nil`. Damit fiel `isUndoScrubing`/`hidesNonUndoElements` weg, und die Palette blendete Farbwahl, Bogen, Hintergrund und Elemente wieder ein.

**Lösung:**
- Der gehaltene Stil wird vor dem Aufräumen erfasst (`let heldStyle = undoScrubSession?.style`)
- Bei `.circular` (Apple-Pencil-Squeeze-Palette) wird in derselben `.easeOut(0.16)`-Animation zusätzlich `isSqueezePaletteVisible = false` gesetzt, zusammen mit `isDismissingPaletteAfterUndoScrub = true` (in `hidesNonUndoElements` verodert, in `presentSqueezePalette` zurückgesetzt)
- Der lineare Balken der normalen Werkzeugleiste bleibt unverändert – er gehört zur Leiste und soll nicht abtauchen
- Regel testbar in `InteractionPolicies.dismissesSqueezePaletteAfterUndoScrub(isCircularScrub:)`

**Geänderte Dateien:** `Views/Drawing/LessonDrawingOverlayView.swift`, `Utils/InteractionPolicies.swift`

---

## Zusammenfassung

Alle gemeldeten Probleme wurden behoben:

1. ✅ **Crop-Handles** funktionieren jetzt korrekt - man kann direkt an den Ecken ziehen
2. ✅ **Zeichenfläche verkleinern** stoppt an Bildern/Textfeldern, statt sie zu verschieben
3. ✅ **Notiz-Schließen** friert die App nicht mehr ein (Overlay zuerst weg, Speichern im Hintergrund, Größenbudget für die Undo-Sitzung)
4. ✅ **Mobile Design** ist deutlich kompakter und besser für kleine Bildschirme optimiert
5. ✅ **Wochenwechsel** läuft flüssig (Formatter-Cache, memoisierte Stunden, kein synchrones Notiz-Laden im Render-Pfad, Schreiben im Hintergrund)
6. ✅ **Gehaltener Rückgängig-Knopf** lässt die Squeeze-Bar verschwinden statt wieder auftauchen

Die Änderungen sind minimal-invasiv und bewahren die bestehende Funktionalität auf iPad/Mac, während sie das iPhone-Erlebnis deutlich verbessern. Logik-Regeln (Resize-Grenzen, Squeeze-Bar, Undo-Budget) sind in `Tests/InteractionRegressions/main.swift` abgesichert.
