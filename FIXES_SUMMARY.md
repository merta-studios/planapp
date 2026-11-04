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

## 7. Tastatur schiebt die ganze Notiz ✅

**Problem:** Beim Tippen in einem Textfeld rutsche die Notiz nach oben, Text- und Bildobjekte blieben aber stehen.

**Ursache:** `revealEditingTextBox` lief in einem einzigen Durchlauf direkt im `keyboardWillChangeFrame`-Callback. Zu diesem Zeitpunkt war die Karten-Geometrie (`renderCenter`, Skalierung, `clampedOffset`) noch nicht fertig – der berechnete Versatz galt also nur teilweise. Da Zeichnung, Textfelder und Bilder denselben Block teilen, blieben sie zurück, sobald der Versatz zu klein ausfiel.

**Lösung:** `scheduleKeyboardReveal` stößt die (idempotente) Berechnung viermal über die UIKit-Tastatur-Animation verteilt an (0 / 0,09 / 0,22 / 0,42 s). Ein Generationszähler verwirft die Läufe beim Ausblenden. Jeder Lauf bestimmt die Lage des Feldes **jetzt** und verschiebt nur den noch fehlenden Rest. Zusätzlich löst auch ein reiner Auswahlwechsel bei offener Tastatur das Ausweichen aus.

**Geänderte Datei:** `Views/Drawing/LessonDrawingOverlayView.swift`

---

## 8. Text-Werkzeug: mitwachsen und alle Zeilen sichtbar ✅

**Problem 1:** Nach dem Tippen wuchs das Textfeld nicht nach rechts.
**Problem 2:** Beim Bearbeiten war nur die erste Zeile zu sehen.

**Lösung:** Neues Feld `NoteTextBox.autoGrowWidth` (Standard `true` für neue Felder). `NoteTextBoxesLayer.applyTextChange` verbreitert das Feld bei jeder Textänderung bis knapp vor den Rand der Zeichenfläche (`NoteTextBox.autoGrownWidth`, reine Foundation-Rechnung). Wer die Breite mit den Seiten-Griffen zieht, setzt `autoGrowWidth = false` – ab dann bleibt die eingestellte Breite. Für Problem 2 bekommt `NoteTextEditor` die Feldhöhe übergeben und setzt sie auf der `UITextView`; ein veralteter Rahmen schnitt sonst die Zeilen ab.

**Geänderte Dateien:** `Models/NoteTextBox.swift`, `Views/Drawing/NoteTextBoxesLayer.swift`, `Views/Drawing/NoteTextEditor.swift`

---

## 9. Grüner „Fertig“-Knopf auf dem iPad ✅

Die Zeichenwerkzeug-Leiste hat jetzt ganz rechts einen beschrifteten grünen „Fertig“-Knopf (`onDone`), der die Notiz speichert und schließt – derselbe Abschluss wie in der Handy-Notiz.

**Geänderte Dateien:** `Views/Drawing/DrawingToolbarView.swift`, `Views/Drawing/LessonDrawingOverlayView.swift`

---

## 10. iPhone als eigene, schlichte App ✅

Kein Zeichenbereich mehr auf dem iPhone: Eine Handy-Notiz ist ein normaler Fließtext (`PhoneNoteEditorView`) mit automatischem Umbruch, −/+-Schriftgröße in der Leiste und **nur** dem grünen „Fertig“-Knopf (kein „…“). Passt der Text nicht mehr, verkleinert `MobileNotePolicy.layout` die Schrift in 0,1-pt-Schritten; bei der kleinsten Größe wird die Eingabe blockiert. Handschriftliche (auf dem iPad erstellte) Notizen lassen sich dort **nicht** öffnen – ein Tipp zeigt die Optionen (`PhoneNoteOptionsMenu`). Beim ersten Öffnen einer Handy-Notiz auf dem iPad wird sie einmalig in ein normales, verschiebbares Textfeld des Zeichenbereichs umgewandelt; danach ist sie auf dem iPhone wieder gesperrt. In den Einstellungen gibt es auf dem iPhone nur noch die Standardschriftgröße.

**Neue Dateien:** `Views/Drawing/PhoneNoteEditorView.swift`, `Utils/MobileNotePolicy.swift`, `Utils/MobileNoteConversion.swift`, `Views/Timetable/PhoneNoteOptionsMenu.swift`

---

## 11. Standard-Tag und Löschen nach Tag ✅

Neue Einstellungen im Tag-System: ein **Standard-Tag**, das jede neue Notiz automatisch bekommt (iPad und iPhone), sowie eine Mehrfachauswahl, auf welche Tags sich „Alte Notizen automatisch löschen“ beschränkt. Ohne Auswahl gilt die Regel weiterhin für alle Notizen; ein Zähler zeigt, wie viele abgelaufene Notizen gerade betroffen wären.

**Geänderte Dateien:** `Models/NoteTag.swift`, `ViewModels/TimetableViewModel.swift`, `Views/Settings/TagSystemSettingsSection.swift`

---

## 12. Neues Modul „Noten & Punkte“ ✅

Neue Einstellungs-Kategorie mit Hauptschalter (Standard: aus). Ist es an, erscheint im Ansichts-Modus-Menü „Noten & Punkte“ zwischen „Nur Notizen“ und dem Filter; anstelle der Tag-Filterung gibt es dort „Sortieren nach“ (Alphabet, umgekehrt, Zufällig, bester/schlechtester Durchschnitt, meiste/wenigste Einträge, letzte Änderung ±). Die Fächer-Karten tragen die Farbe aus „Fächer & Farben“ und zeigen den Durchschnitt im Kreis. Die Fach-Ansicht ist ein Kachel-Raster: gestrichelte graue Kachel mit Plus zum Anlegen, farbige Kacheln (pastellgrün → gelb → orange → rot nach Leistung) mit Datum oben, großem Wert in der Mitte und Anmerkung unten. Eingabe: sechs Noten-Knöpfe oder Regler für Punkte/Prozent (Startwert einstellbar), optionale Notiz, wahlweise Umrechnung in eine Zensur. Tippen ändert, langes Drücken bietet nur „Löschen“.

**Neue Dateien:** `Models/GradeSettings.swift`, `Models/GradeEntry.swift`, `Views/Settings/GradeSettingsSection.swift`, `Views/Grades/GradesOverviewView.swift`, `Views/Grades/GradeSubjectDetailView.swift`, `Views/Grades/GradeEntryEditorSheet.swift`

---

## 13. iCloud-Sync: Ordner statt einer Riesendatei ✅

**Problem:** Große Textdateien brachten Geräte zum Absturz, ließen sich nicht kopieren, und zwei Geräte überschrieben sich beim ersten Abgleich gegenseitig; Aktualisierungen kamen viel zu selten.

**Lösung:** Der Sync ist jetzt ein **Ordner** mit einer Datei pro Notiz (`notes/<schlüssel>.json`) plus einem kleinen `settings.json`. Geschrieben wird nur, was sich geändert hat; jede Datei trägt ihren eigenen Zeitstempel, sodass beim Zusammenführen pro Notiz der neuere Stand gewinnt (`FolderSyncRules.merge`). Löschungen werden über Grabsteine und die Liste der zuletzt im Ordner gesehenen Dateien erkannt – nichts steht wieder auf, nichts geht verloren. Geprüft wird alle 6 s, geschrieben 1,2 s nach der letzten Änderung. Vor jeder Übernahme entsteht eine Sicherheitskopie; eine alte Ein-Datei-Verknüpfung wird einmalig übernommen (`migrateLegacyFile`) und danach auf den Ordner umgestellt. Der Ordner ist ein normaler Ordner mit lesbaren Dateien und lässt sich weiterhin von Hand kopieren.

**Neue Dateien:** `Services/FolderSyncCore.swift`, `Services/FolderSyncDocuments.swift`
**Geänderte Dateien:** `Services/FileSyncService.swift`, `Views/Settings/DataTransferSection.swift`, `Views/Settings/FileSyncPickers.swift`, `ViewModels/TimetableViewModel.swift`

---

## Zusammenfassung

Alle gemeldeten Probleme wurden behoben:

1. ✅ **Crop-Handles** funktionieren jetzt korrekt - man kann direkt an den Ecken ziehen
2. ✅ **Zeichenfläche verkleinern** stoppt an Bildern/Textfeldern, statt sie zu verschieben
3. ✅ **Notiz-Schließen** friert die App nicht mehr ein (Overlay zuerst weg, Speichern im Hintergrund, Größenbudget für die Undo-Sitzung)
4. ✅ **Mobile Design** ist deutlich kompakter und besser für kleine Bildschirme optimiert
5. ✅ **Wochenwechsel** läuft flüssig (Formatter-Cache, memoisierte Stunden, kein synchrones Notiz-Laden im Render-Pfad, Schreiben im Hintergrund)
6. ✅ **Gehaltener Rückgängig-Knopf** lässt die Squeeze-Bar verschwinden statt wieder auftauchen
7. ✅ **Tastatur** verschiebt die ganze Notiz samt Text- und Bildobjekten
8. ✅ **Text-Werkzeug** wächst nach rechts mit und zeigt beim Bearbeiten alle Zeilen
9. ✅ **Grüner „Fertig“-Knopf** auch in der iPad-Werkzeugleiste
10. ✅ **iPhone** ist eine eigene, schlichte App (Fließtext statt Zeichenfläche)
11. ✅ **Standard-Tag** und **Löschen nach Tag**
12. ✅ **Noten & Punkte** als neues Modul mit Kachel-Ansicht
13. ✅ **iCloud-Sync** über einen Ordner mit kleinen Dateien statt einer Riesendatei

Die Änderungen sind minimal-invasiv und bewahren die bestehende Funktionalität auf iPad/Mac, während sie das iPhone-Erlebnis deutlich verbessern. Logik-Regeln (Resize-Grenzen, Squeeze-Bar, Undo-Budget) sind in `Tests/InteractionRegressions/main.swift` abgesichert.
