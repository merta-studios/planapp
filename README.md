# PlanApp – Stundenplan-App fürs iPad & Swift Playgrounds

Eine moderne, elegante und leistungsstarke Stundenplan-App für das **iPad**, entwickelt in **Swift & SwiftUI** mit voller Unterstützung für **Apple Pencil Pro**, **PencilKit** und die **WebUntis API**.

Das Repository enthält das fertige App-Package **`PlanApp.swiftpm`**, welches auf dem Mac oder iPad direkt mit App-Icon angezeigt wird und mit einem Klick in **Swift Playgrounds 4+** oder **Xcode** geöffnet und gestartet werden kann.

---

## 🚀 Direktstarten in Swift Playgrounds

1. **Repository herunterladen / entpacken** (z. B. als ZIP von GitHub oder auf das iPad geladen).
2. Den Ordner öffnen: Darin befindet sich direkt die Datei **`PlanApp.swiftpm`** mit App-Icon.
3. **`PlanApp.swiftpm` doppelt anklicken / antippen**:
   - Auf dem **iPad**: Öffnet sich sofort in **Swift Playgrounds** als lauffähige App.
   - Auf dem **Mac**: Öffnet sich direkt in **Swift Playgrounds** oder **Xcode**.
4. Auf **App starten** (Play-Button) tippen – fertig!

---

## 📲 Als „richtige“ App aufs iPad – kostenlos per Windows-PC (Sideload, 7 Tage)

iOS-Apps lassen sich nicht unter Windows kompilieren. Deshalb baut die GitHub-Actions-Pipeline
[`ci/build-ipa.yml`](ci/build-ipa.yml) auf einem GitHub-macOS-Runner ein unsigniertes
**`PlanApp.ipa`**, das anschließend mit **Sideloadly** und einer kostenlosen Apple-ID auf dem
iPad installiert wird. Die App erscheint dann mit eigenem Icon auf dem Home-Screen und läuft
**7 Tage** – verlängerbar per Sideloadly-Auto-Refresh oder AltStore (WLAN-Refresh).
Name und Icon der Sideload-App werden in `PlanApp.swiftpm/Package.swift` bzw.
`PlanApp.swiftpm/Assets.xcassets` konfiguriert; aktuell heißt sie **„Untis Planner PLUS“**.

**Einmalige Einrichtung:** Die Datei [`ci/build-ipa.yml`](ci/build-ipa.yml) im GitHub-Webinterface
nach `.github/workflows/build-ipa.yml` kopieren (*Add file → Create new file*, Pfad exakt so
eintippen, Dateiinhalt einfügen, committen). Danach steht der Workflow im Tab **Actions** bereit.

**IPA bauen & installieren:**

1. GitHub → **Actions → „Build IPA (Sideload)“ → Run workflow** (nach dem Merge läuft er auch automatisch bei jedem Push auf `main`).
2. Nach ca. 3–5 Minuten das Artefakt **`PlanApp-IPA`** herunterladen, entpacken → `PlanApp.ipa`.
3. Am Windows-PC [Sideloadly](https://sideloadly.io) und iTunes (liefert die USB-Treiber) installieren.
4. iPad per USB verbinden („Diesem Computer vertrauen“ bestätigen) und `PlanApp.ipa` per Drag & Drop in Sideloadly ziehen.
5. Eine kostenlose Apple-ID eingeben (am besten eine Zweit-ID) → **Start**.

> **Hinweise:** Mit einer Gratis-Apple-ID sind maximal 3 sideloaded Apps gleichzeitig möglich.
> Beim Löschen einer abgelaufenen App gehen lokal gespeicherte Stundenpläne und Notizen verloren –
> also rechtzeitig refreshen statt neu installieren. Auf privaten Repos kostet jeder Build
> Actions-Minuten (macOS zählt 10×, ein Build ≈ 30–60 der 2.000 Gratis-Minuten pro Monat).

---

## ✨ Features im Überblick

### 📅 1. Linienloser 6-Spalten-Stundenplan (Hauptmenü)
- **Borderloses Design**: Der Stundenplan wird nicht durch harte Gitterlinien strukturiert, sondern durch ein modernes, abwechselndes **Zebra-Muster** (jede 2. Spalte und jede 2. Zeile erhält eine dezente Grauschattierung).
- **1. Spalte (Zeiten & Perioden)**: Zeigt oben klein die Anfangszeit, in der Mitte die fette Stundennummer (1, 2, 3...) und unten klein die Endzeit.
- **Spalten 1 bis 5 (Montag – Freitag)**: Zeigen Wochentag und Datum.
- **Hervorhebung des aktuellen Tages**: Der heutige Tag wird automatisch mit einem blauen „HEUTE“-Badge, kräftiger Schrift und Akzentlinien hervorgehoben.
- **Dynamische Zeilenhöhe**: Passt sich automatisch der Bildschirmgröße und der Anzahl der Schulstunden an.
- **Wochen-Navigation**: Startet standardmäßig in der aktuellen Kalenderwoche. Durch **Wischen nach links oder rechts** wechselt man flüssig zwischen den Wochen.
- **Lade-Anzeige beim Wischen**: Wird eine Woche geöffnet, für die noch keine Daten vom Server geladen wurden, dreht sich in der Bildschirmmitte ein Lade-Symbol – es bleibt sichtbar, bis die API-Antwort (oder ein Fehler) da ist.
- **„Kein Unterricht“**: Tage ganz ohne Stunde werden in der Spalte mit einem um 90° gedrehten, grauen Hinweis markiert – im Standard- und im Notizen-hervorgehoben-Modus.

### 🔄 2. WebUntis API JSON-RPC Integration
- Vollständige Integration der offiziellen **WebUntis JSON-RPC 2.0 API** (`/WebUntis/jsonrpc.do`).
- Abruf von:
  - **Stundenzeiten (Timegrid Units)** zur automatischen Zeilen-Konfiguration.
  - **Stundenplandaten** für jede Kalenderwoche.
- **Frische-Warnung**: Liegt der letzte erfolgreiche Abruf mehr als **60 Minuten** zurück, steht oben rechts rot **„Stundenplan veraltet“**. Die App versucht sofort zu aktualisieren und bei Fehlern höchstens alle 30 Sekunden erneut; auch beim Zurückkehren in die App wird geprüft. Ein Tipp auf die Statusanzeige startet einen manuellen Abruf.
- **Offline- & Demo-Modus**: Enthält einen integrierten Generator für realistische Beispieldaten (Doppelstunden, Entfall, Vertretung), um alle Features ohne aktiven Schul-Account sofort testen zu können.
- **Einrichtungs-Guide statt leerem Stundenplan**: Fehlen die API-Daten (oder sind sie unvollständig/ungültig), steht in der Bildschirmmitte ein Guide-Fenster: Der Plan lässt sich automatisch von Untis laden – dafür ist nur **ein Schritt in den Einstellungen** nötig. Der Knopf **„Zu den Einstellungen“** springt direkt auf die Seite *WebUntis & Sync* mit den API-Feldern.

### 🎨 3. Fach-Ersetzungen & Farb-Anpassungen
- **Automatische Farberkennung**: Sobald der Fachname von der API mit einer eingestellten Regel übereinstimmt, färbt sich der Stundenblock in der konfigurierten Wunschfarbe.
- **Namen-Ersetzung**: Untis-Kürzel wie `M`, `D`, `ENG` werden automatisch durch verständliche Namen wie `Mathematik`, `Deutsch`, `Englisch` ersetzt.
- **1-Klick-Import**: Erkennt alle im Stundenplan vorkommenden Fächer automatisch.
- **Farbpalette**: Schnellauswahl aus harmonischen Schulfach-Farben plus nativer Farbwähler.

### 👥 4. Doppelstunden-Zusammenlegung & Block-Anpassung
- **Intelligente Zusammenlegung**: Zwei aufeinanderfolgende gleiche Stunden (gleiches Fach, Lehrer, Raum) werden nahtlos zu einer **Doppelstunde** zusammengezogen, die über beide Zeilen reicht.
- **Entfallende Stunden**: Werden mit kräftigem **roten Strich durchgestrichen** und mit einem „ENTFÄLLT“-Badge markiert.
- **Vertretungsstunden**: Werden mit einem „VERTRETUNG“-Badge markiert; geänderte Lehrer oder Räume werden übersichtlich dargestellt.
- **Anpassbare Block-Infos**:
  - *Fachname (Fett)*: Standardmäßig fest verankert.
  - *Lehrer*: Ein-/Ausschaltbar.
  - *Raum*: Ein-/Ausschaltbar.
  - *Notizen-Vorschau*: Ein-/Ausschaltbar.
  - *Vertretungsgründe*: Ein-/Ausschaltbar.
  - *Uhrzeiten im Block*: Ein-/Ausschaltbar.

### ✏️ 5. Apple Pencil Pro & PencilKit Notizzettel
- **Öffnen**: Durch Antippen eines Fachs oder mit einer **2-Finger-Zoom-Geste**.
- **Fokus-Ansicht**: Der Stundenplan bleibt im Hintergrund abgedunkelt und geblurrt sichtbar.
- **Schließen & Speichern**: Ein bewusster kurzer Tipp in den abgedunkelten Hintergrund – **mit dem Finger oder mit dem Apple Pencil** – schließt und speichert die Notiz automatisch. Kontaktgröße samt Messunsicherheit, Bewegung und Dauer werden über den gesamten Tipp geprüft. Laufende Striche und eine kurze Absetzphase sind geschützt; Handballen, große Kontakte und Mehrfinger-Gesten schließen die Notiz nicht. Ein Pencil-Tipp darf dabei mit aufliegendem Handballen erfolgen (die Hand blockiert das Schließen nicht), ein zweiter Stiftkontakt oder ein zweiter Finger dagegen schon.
- **Linierter Zettel**: Authentisches Notizpapier mit roter Randlinie und horizontalen Schreiblinien.
- **Zeilen erweitern**: Über den Button „＋ Zeile hinzufügen (Erweitern)“ können flexibel bis zu **maximal 10 Zeilen** hinzugefügt werden.
- **Gesten auf dem Zettel**:
  - **Zettelkopf ziehen**: Verschiebt den Zettel frei über den Bildschirm.
  - **2 Finger**: Stufenloses Zoomen und Verschieben gleichzeitig.
  - **Apple Pencil**: Schreibt und zeichnet direkt.
  - **1 Finger**: Zeichnet ebenfalls – solange die Einstellung „Apple Pencil“ aus ist (Standard). Ist sie an, bleibt der Finger außen vor.
- **Werkzeuge**:
  - **Stift / Textmarker / Radierer / Lasso / Text** – mit frei wählbaren Farben aus den Farb-Slots und eigener Dicke je Werkzeug.
  - **Rückgängig & Vorwärts (Undo/Redo)** über die Werkzeugleiste. Eine Sekunde auf **Rückgängig** halten öffnet einen Scrubber: in der oberen Leiste einen Balken nach unten (auch mit dem Finger), in der Squeeze-Palette einen Kreis. Der Kreis läuft nicht mehr nur einmal herum: Nach einer vollen Umdrehung dreht man einfach weiter und macht weitere Schritte rückgängig – bis zum letzten gespeicherten Schritt (weitere Umdrehungen erscheinen als dünne Innenringe). Die Stufen werden bei **jeder** Bewegung frisch aus der Historie gezählt, damit die Anzeige nie Schritte zeigt, die es nicht (mehr) gibt. Rückschritte sind weiterhin als dünne blaue Stufen in die Gegenrichtung markiert. Die Schritte der letzten drei Notizen bleiben erhalten, auch wenn eine Notiz automatisch geschlossen wurde.
  - **Squeeze** und **Doppeltipp** sind unter *Zeichnen & Apple Pencil* frei belegbar (Toolbar, Rückgängig, Radierer/letztes Werkzeug, Nichts). Standard: Squeeze öffnet die Toolbar, Doppeltipp wechselt Radierer und letztes Werkzeug.
- **Kompakte Squeeze-Werkzeugpalette**: Ein Zusammendrücken des Apple Pencil Pro öffnet nahe der **letzten aktiven Hover-Position** einen kompakten, dicken Bogen. Acht runde **44-pt-Buttons** enthalten Rückgängig, Lasso, Stift, Textmarker, Radierer, Text, die Farbe (Farb-Slots erscheinen beim Hovern außen) und die Stiftdicke (durch Halten und radiales Ziehen). Unter iPadOS 26 mit aktuellem SDK wird natives interaktives Liquid Glass verwendet; ältere Versionen erhalten einen reflektierenden Material-Fallback. Erneuter Squeeze, Weiterzeichnen oder ein Fingertipp schließen die Palette. Ein Rand-Tipp schließt zunächst nur die offene Palette, nicht gleichzeitig die Notiz.
- **Radierer mit automatischer Rückkehr**: Nach dem Radieren und Loslassen wechselt das Werkzeug automatisch zum zuletzt benutzten Werkzeug zurück (Fallback: Stift). Der Schalter *„Radierer automatisch abwählen“* (Standard: an) sitzt unter *Zeichnen & Apple Pencil*.
- **Apple-Pencil-Einstellung**: Standardmäßig **aus**, das heißt Finger und Pencil dürfen zeichnen. Sobald die App irgendwo einen echten Apple Pencil bemerkt (Hover, Strich oder Squeeze), schaltet sie „Nur Apple Pencil“ automatisch ein und merkt sich das.
- **Apple Pencil Hover**: Alle Buttons und Karten unterstützen iPadOS Pointer- & Hover-Effekte (`.hoverEffect(.lift)`).
- **Automatischer Rand-Zuschnitt**: Beim Schließen wird die Zeichnung exakt an den Rändern der geschriebenen Striche zugeschnitten und als gestochen scharfe Vorschau direkt im Stundenplan-Block angezeigt!
- **Tastatur ändert die Notiz nicht**: Das Text-Werkzeug nutzt die Systemtastatur. Der Zettel behält beim Tippen seine Größe und seine Position – nichts rutscht nach oben und nichts wird klein gerechnet. Nur wenn das bearbeitete Textfeld sonst hinter der Tastatur läge, rückt der Zettel gerade so weit hoch, dass das Feld sichtbar bleibt (ohne Zoom).
- **Gerade Linien**: Stift oder Textmarker am Ende eines Strichs etwa **2 Sekunden still halten** – der Strich rastet als gerade Linie ein, der Apple Pencil Pro bestätigt das mit einer kurzen Vibration. Weiterziehen hebt das Einrasten wieder auf. Die gerade Linie hat **exakt die Dicke des echten Strichs**: Der gemessene Vergleich (die selbst gerechnete Linie war bei Stift/Monoline 50 % zu dünn) wird überall angewandt, wo die App eine Breite selbst zeichnet – gerade Linien und die Vorschau-Punkte in der Werkzeugleiste ebenso wie der Dicke-Regler (`InteractionPolicies.strokeWidthMatchFactor`). Textmarker und Radierer behalten ihre eigene, bereits passende Umrechnung.
- **Dynamische Stiftdicke**: Unter *Zeichnen & Apple Pencil* schaltbar (Standard an). Aus = Kugelschreiber (Monoline) mit konstanter Dicke.
- **Mustergröße**: Im „…“-Menü der Zeichenfläche regelt ein Schieberegler die Größe von Linien, Kästchen und Punkten (Mitte = Standard, bis halb so klein / doppelt so groß). Der Standardwert für neue Notizen steht in den Einstellungen.
- **Notiz kopieren & einfügen**: Stunden-Block (oder Karte in „Nur Notizen“) gedrückt halten → *Kopieren* (wenn eine Notiz existiert) bzw. *Einfügen* (ersetzt die Zielnotiz komplett). Dieselben Optionen gibt es im „…“-Menü der geöffneten Notiz.
- **Dark Mode**: Die Zeichenfläche läuft fest im hellen Erscheinungsbild – schwarze Tinte bleibt beim Öffnen einer Notiz schwarz, auch wenn das Gerät im Dark Mode ist.

### 🗒️ 6. Ansichts-Modus „Nur Notizen“ als Raster

- **Drei kompakte Spalten**: Auf normalen iPad-Fensterbreiten (hoch und quer) stehen **drei** kleinere Notizkarten nebeneinander. Kopfzeile, Vorschau und Abstände sind kompakter. Im Split View wechselt die Übersicht abhängig von der verfügbaren Breite auf zwei oder eine Spalte.
- **„Im Standard-Modus anzeigen“**: Karte gedrückt halten und die Option wählen – die App wechselt in den Standard-Modus **und** wischt automatisch zu der Woche, in der die Stunde liegt.
- **Gleiche Kartenbreiten**: Alle Karten eines Abschnitts haben dieselbe Breite, und die Karten einer Zeile dieselbe Höhe – die Übersicht wirkt wie eine Tafel, nicht wie eine lose Liste.
- **Chronologie im Raster**: Die grüne „Jetzt“-Linie liegt **zwischen** dem vergangenen und kommenden Kartenraster und läuft von Rand zu Rand – sie belegt niemals eine Rasterzelle. Im Mehrspaltenraster stehen Datum und Stunde direkt im Header jeder Karte, sodass Notizen verschiedener Tage eine Zeile gemeinsam füllen können.
- **Chronologie bleibt**: Gelesen wird zeilenweise von links nach rechts – vergangene Einträge oben, kommende unterhalb der grünen Linie.
- **Flüssig auch mit vielen Notizen**: Die Übersicht ist eine flache Liste aus Kartenzeilen (`NotesOverviewLayout.rowPlan`), Vorschaubilder werden **asynchron verkleinert geladen** und in einem Cache gehalten, Schatten liegen nur auf der Kartenform, und die Minuten-Aktualisierung läuft über einen einzigen `.task`-Timer. Dadurch ruckelt der Modus auch mit zehn und mehr Notizen nicht mehr.
- **Tag-Filter**: Ist das Tag-System aktiv, erscheint im Modus-Menü unter den drei Ansichten die Option **Filter** (Mehrfachauswahl mit Häkchen; nichts ausgewählt = alle Notizen).

### 🏷️ 7. Tag-System (optional)

- *Einstellungen → Tag-System*: Schalter **„Tag System aktivieren“** (Standard aus), darunter die Liste der Tags (Name + Farbe, maximal 20). Bearbeiten über das Stift-Symbol, Reihenfolge per Ziehen an den drei Strichen rechts.
- In der Notiz steht neben dem Fachnamen eine gestrichelte graue Pille **„+ Tag hinzufügen“**; ein Tipp öffnet die kleine Tag-Auswahl direkt an der Pille. Das Mini-Fenster **wächst als Größen-Animation aus der Pille heraus** und schrumpft beim Schließen wieder dorthin – es wird nicht ein-/ausgeblendet. Ein gesetzter Tag füllt die Pille in seiner Farbe (weiße Schrift bei dunklen Farben); erneutes Tippen wechselt oder entfernt ihn.
- Im Stundenplan erscheint der Tag neben dem Fachnamen. Eine leere Notiz mit Tag wird nicht gespeichert – der Tag entfällt.

### 💾 8. Sichern, Übertragen & mehrere Geräte

- *Einstellungen → Daten & Zurücksetzen*: **„Export alles“** erzeugt einen Base64-Text (`PLANAPP1:` + komprimiertes JSON) mit **allem** – Notizen, Stundenplan, Zugangsdaten, Fächer, Lehrkräfte, Tags und sämtlichen Einstellungen – zum Teilen oder Kopieren. **„Import“** liest eine solche Sicherung aus der Zwischenablage, zeigt vorher eine Zusammenfassung und ersetzt nach Bestätigung alle Daten.
- **iCloud**: Eine automatische iCloud-/CloudKit-Synchronisation ist ohne Apple-Entwicklerkonto (Swift Playgrounds, Sideloadly) nicht möglich – die App bekommt keine iCloud-Berechtigung. Export & Import über AirDrop, Dateien-App (iCloud Drive) oder Universal-Zwischenablage ist der verlässliche Weg.
- **Limits**: maximal **50** eigene Fächer und **50** Lehrkraft-Einträge (Zähler und Hinweis in den Einstellungen).

### 📱 9. iPhone

- Der Stundenplan wird auf dem iPhone **kompakt** dargestellt: schmale Stundenspalte, zweibuchstabige Wochentage, kleinere Blöcke – alle fünf Tage passen auf den Bildschirm. Die Kopfzeile schrumpft auf Symbole. „Nur Notizen“ zeigt eine Karte pro Zeile.
- In der Notiz gibt es ohne Apple Pencil nur **Lasso, Text und Radierer** (per Finger); die Farb-Slots wirken als **Textfarben**. Rückgängig/Wiederholen und das „…“-Menü bleiben. Pencil-spezifische Einstellungen sind auf dem iPhone ausgeblendet. Das iPad bleibt unverändert.

### 🌙 10. Darstellung & Dark Mode (Schrift bleibt schwarz)

- **Papier bleibt Papier**: Alle Notiz- und Zeichenflächen sind – wie ein echter Notizblock – **immer weiß**, und die Schrift darauf ist und bleibt **schwarz**. Das gilt für Blockschrift, Textfelder, Vorschauen und gerenderte Notizbilder.
- **Einstellbare Darstellung**: Unter *Einstellungen → Darstellung* lässt sich **Hell** (Standard), **Dunkel** oder **Automatisch** (folgt dem iPad) wählen. Standard ist **Hell**, damit ein dunkles System-Design nirgends weiße Schrift auf weißem Papier erzeugen kann.
- **Umgebung folgt der Wahl**: Menüs, Werkzeugleisten und Glasflächen passen sich an das gewählte Erscheinungsbild an – das Papier nie.

---

## 📂 Projektstruktur

```
planapp/
├── PlanApp.swiftpm/                          # Swift Playgrounds App Paket (direkt startbar)
│   ├── Package.swift                         # Swift Package App Manifest mit iOSApplication Produkt
│   ├── App.swift                             # App Entry Point (@main)
│   ├── .swiftpm/
│   │   └── xcode/package.xcworkspace/        # Playgrounds Workspace Konfiguration
│   ├── Models/
│   │   ├── Period.swift                      # Stundenzeiten & Perioden-Modell
│   │   ├── Lesson.swift                      # Unterrichtsstunden & Doppelstunden-Logik
│   │   ├── SubjectCustomization.swift        # Fächer-Ersetzungen & Farbkonfiguration
│   │   ├── BlockDisplaySettings.swift        # Sichtbare Block-Elemente
│   │   ├── LessonNote.swift                  # Handschriftliche Notizen & Bilddaten
│   │   ├── DrawingSettings.swift             # Pencil-Einstellungen (u. a. Nur-Pencil, Radierer-Rückkehr)
│   │   ├── AppAppearance.swift               # Erscheinungsbild (hell/dunkel/automatisch)
│   │   └── UntisCredentials.swift            # WebUntis JSON-RPC Zugangsdaten
│   ├── Services/
│   │   ├── WebUntisService.swift             # WebUntis JSON-RPC 2.0 API Client
│   │   ├── TimetableStorageService.swift     # Lokale Speicherung (UserDefaults & Notiz-Dateien)
│   │   └── DemoDataService.swift             # Beispieldaten-Generator
│   ├── ViewModels/
│   │   └── TimetableViewModel.swift          # Zentraler Zustand & Controller
│   ├── Views/
│   │   ├── Timetable/
│   │   │   ├── TimetableView.swift           # Hauptansicht mit 6-Spalten-Raster & Wischgesten
│   │   │   ├── TimetableHeaderView.swift     # Kopfzeile mit Wochennavigation & Sync
│   │   │   ├── PeriodColumnView.swift        # 1. Spalte: Stundennummern & Uhrzeiten
│   │   │   ├── DayColumnView.swift           # Wochentagsspalten mit Zebra-Muster
│   │   │   ├── LessonBlockView.swift         # Stunden-Karten mit Status & Notiz-Vorschau
│   │   │   ├── NotesOverviewListView.swift   # „Nur Notizen“-Raster mit Kontext-Optionen
│   │   │   ├── UntisSetupGuideView.swift     # Guide-Fenster für fehlende API-Daten
│   │   │   └── EmptyTimetableView.swift      # Willkommens-Ansicht bei leerem Plan
│   │   ├── Drawing/
│   │   │   ├── LessonDrawingOverlayView.swift# Fullscreen-Overlay mit Zettel & Gesten
│   │   │   ├── LinedPaperBackground.swift    # Linierter Zettel mit rotem Rand
│   │   │   ├── PencilKitCanvasRepresentable.swift # PencilKit Wrapper, Pencil-Erkennung & Squeeze
│   │   │   ├── PencilSqueezePaletteView.swift# Abgerundete Squeeze-Bogenpalette
│   │   │   └── DrawingToolbarView.swift      # Vorgegebene Stift-, Textmarker- & Radier-Tools
│   │   ├── Settings/
│   │   │   ├── SettingsView.swift            # Einstellungen-Übersicht (Kategorien)
│   │   │   ├── SettingsCategory.swift        # Kategorien & Detailseiten
│   │   │   ├── TagSystemSettingsSection.swift # Tag-System: Schalter, Tags (Name + Farbe), Reihenfolge
│   │   │   ├── DataTransferSection.swift     # Export alles / Import (Base64-Text, Zwischenablage)
│   │   │   ├── AppearanceSettingsSection.swift # Hell/Dunkel/Automatisch
│   │   │   ├── DrawingSettingsSection.swift  # Stiftdicken, Pencil-Einstellungen & Radierer
│   │   │   ├── PencilGesturesSection.swift   # Bedienhinweise (Pencil & Gesten)
│   │   │   ├── UntisConfigSection.swift      # WebUntis Zugangsdaten & Sync-Test
│   │   │   ├── SubjectCustomizationSection.swift # Fächer anlegen & Farben wählen
│   │   │   ├── BlockDisplaySettingsSection.swift # Block-Inhalte anpassen
│   │   │   └── PeriodConfigSection.swift     # Stundenzeiten anzeigen & bearbeiten
│   │   └── Components/
│   │       ├── HoverButton.swift             # Apple Pencil Hover Buttons
│   │       ├── KeyboardTextField.swift       # Einheitliches Eingabefeld der Einstellungen
│   │       ├── ColorPickerPresets.swift      # Farbpaletten-Auswahl
│   │       └── StatusBadge.swift             # Status-Badges (Entfall, Vertretung, Heute)
│   └── Utils/
│       ├── AppResources.swift                # Bundle-/Ressourcen-Suche (Playgrounds-kompatibel)
│       ├── ColorExtensions.swift             # Hex-Konvertierung & Kontrastfarben
│       ├── DateExtensions.swift              # Kalenderwochen & Tagesberechnungen
│       ├── GlobalCoordinateSpace.swift       # Gemeinsamer Koordinatenraum für Hover-Positionen
│       ├── DeviceLayout.swift                # iPhone/iPad-Erkennung & kompakte Stundenplan-Maße
│       ├── Haptics.swift                     # Zentrale Haptik-Helfer
│       └── PencilInteractions.swift          # Apple Pencil Pro Squeeze- & Hover-Handler
├── README.md
└── .gitignore
```

---

## 🛠 Hinweise zu Ressourcen (`Resources/`)

Bilder und andere Dateien aus dem Ordner `Resources/` **niemals über `Bundle.module`** laden.
`Bundle.module` wird ausschließlich von SwiftPM generiert (`resource_bundle_accessor.swift`).
Swift Playgrounds baut das App-Modul selbst und kopiert die Ressourcen direkt in das
App-Bundle – der Accessor entsteht dort nie. Die Folge wäre der Compilerfehler
`Type 'Bundle' has no member 'module'` und damit ein fehlgeschlagener Start („Build failed“).

Stattdessen den Helfer `AppResources` verwenden, der das passende Bundle zur Laufzeit ermittelt
und sowohl in Swift Playgrounds als auch in Xcode funktioniert:

```swift
let logo = AppResources.image(named: "AppLogo")
let url  = AppResources.url(forResource: "AppLogo", withExtensions: ["png"])
```

---

## ⌨️ Texteingabe: Systemtastatur

Textfelder auf der Zeichenfläche und alle Eingabefelder der Einstellungen
benutzen die **normale Systemtastatur** von iPadOS/iOS. Eine frühere
app-eigene Bildschirmtastatur wurde vollständig entfernt.

Hinweis: In **Swift Playgrounds** kann die Systemtastatur gelegentlich
ausbleiben (eine Eigenheit der Playgrounds-Laufzeit, kein Fehler der App). In
der installierten App – z. B. per Sideloadly oder Xcode – funktioniert sie
zuverlässig.

---


## 🧪 Regressionstests für Interaktion und Layout

`Tests/run-regressions.sh` kompiliert mit einem installierten Swift-Compiler die
UIKit-freien Tastatur-, Tipp-, Sync- und Paletten-/Notizlayout-Tests direkt gegen
die App-Dateien. Hardware- und Sichtprüfungen für Handballen, Pencil Pro,
Liquid Glass, Tastendruck-Feedback und die Jetzt-Linie stehen unter
[`Tests/InteractionRegressions/README.md`](Tests/InteractionRegressions/README.md).
Ein vollständiger App-Build benötigt weiterhin Xcode oder Swift Playgrounds.
