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
- **Schließen & Speichern**: Ein einfacher Tipp in den abgedunkelten Hintergrund schließt und speichert die Notiz automatisch.
- **Linierter Zettel**: Authentisches Notizpapier mit roter Randlinie und horizontalen Schreiblinien.
- **Zeilen erweitern**: Über den Button „＋ Zeile hinzufügen (Erweitern)“ können flexibel bis zu **maximal 10 Zeilen** hinzugefügt werden.
- **Gesten auf dem Zettel**:
  - **Zettelkopf ziehen**: Verschiebt den Zettel frei über den Bildschirm.
  - **2 Finger**: Stufenloses Zoomen und Verschieben gleichzeitig.
  - **Apple Pencil**: Schreibt und zeichnet direkt.
  - **1 Finger**: Zeichnet ebenfalls – solange die Einstellung „Apple Pencil“ aus ist (Standard). Ist sie an, bleibt der Finger außen vor.
- **Werkzeuge**:
  - **Stift / Textmarker / Radierer / Lasso / Text** – mit frei wählbaren Farben aus den Farb-Slots und eigener Dicke je Werkzeug.
  - **Rückgängig & Vorwärts (Undo/Redo)** über die Werkzeugleiste, die Text-Werkzeuge und den **Doppeltipp** des Apple Pencil.
- **Squeeze-Werkzeugpalette im Viertelkreis**: Ein Zusammendrücken des Apple Pencil Pro öffnet an der **letzten Hover-Position** einen Viertelkreis **in Blickrichtung des Stifts**. Darin ist alles einstellbar: Werkzeug, Farbe und Dicke (Bogen-Regler am äußeren Rand) sowie Rückgängig, Wiederholen und Schließen. Sobald wieder geschrieben wird, verschwindet die Palette von selbst.
- **Radierer mit automatischer Rückkehr**: Nach dem Radieren und Loslassen wechselt das Werkzeug automatisch zum zuletzt benutzten Werkzeug zurück (Fallback: Stift). Der Schalter *„Radierer automatisch abwählen“* (Standard: an) sitzt unter *Zeichnen & Apple Pencil*.
- **Apple-Pencil-Einstellung**: Standardmäßig **aus**, das heißt Finger und Pencil dürfen zeichnen. Sobald die App irgendwo einen echten Apple Pencil bemerkt (Hover, Strich oder Squeeze), schaltet sie „Nur Apple Pencil“ automatisch ein und merkt sich das.
- **Apple Pencil Hover**: Alle Buttons und Karten unterstützen iPadOS Pointer- & Hover-Effekte (`.hoverEffect(.lift)`).
- **Automatischer Rand-Zuschnitt**: Beim Schließen wird die Zeichnung exakt an den Rändern der geschriebenen Striche zugeschnitten und als gestochen scharfe Vorschau direkt im Stundenplan-Block angezeigt!
- **Tastatur ändert die Notiz nicht**: Das Text-Werkzeug öffnet die app-eigene Tastatur **schwebend über** dem Zettel. Der Zettel behält beim Tippen seine Größe und seine Position – nichts rutscht nach oben und nichts wird klein gerechnet. Nur wenn das bearbeitete Textfeld sonst hinter der Tastatur läge, rückt der Zettel gerade so weit hoch, dass das Feld sichtbar bleibt (ohne Zoom).

### 🗒️ 6. Ansichts-Modus „Nur Notizen“ als Raster

- **Raster statt Liste**: Die Notiz-Übersicht ist ein echtes Raster. Auf dem iPad stehen die Notizen **zweispaltig** nebeneinander – **quer und hoch**, sobald beide Spalten breit genug sind. Nur in sehr schmalen Fenstern (Split View) bleibt es einspaltig, damit jede Karte lesbar bleibt.
- **„Im Standard-Modus anzeigen“**: Karte gedrückt halten und die Option wählen – die App wechselt in den Standard-Modus **und** wischt automatisch zu der Woche, in der die Stunde liegt.
- **Gleiche Kartenbreiten**: Alle Karten eines Abschnitts haben dieselbe Breite, und die Karten einer Zeile dieselbe Höhe – die Übersicht wirkt wie eine Tafel, nicht wie eine lose Liste.
- **Volle Breite für Struktur**: Tagesüberschriften und die grüne „Jetzt“-Linie laufen über die volle Breite und trennen die Rasterabschnitte.
- **Chronologie bleibt**: Gelesen wird zeilenweise von links nach rechts – vergangene Einträge oben, kommende unterhalb der grünen Linie.

### 🌙 7. Darstellung & Dark Mode (Schrift bleibt schwarz)

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
│   │   │   ├── PencilSqueezePaletteView.swift# Viertelkreis-Werkzeugpalette (Dicke, Tool, Farbe)
│   │   │   └── DrawingToolbarView.swift      # Vorgegebene Stift-, Textmarker- & Radier-Tools
│   │   ├── Keyboard/
│   │   │   ├── TextInputHub.swift            # Eingabe-Hub, Tastatur-Erkennung & Diagnose
│   │   │   ├── AppKeyboardView.swift         # App-eigene Tastatur im Apple-Stil (Ebenen, Akzente, Emoji)
│   │   │   ├── AppKeyboardLayout.swift       # Adaptive Tastaturmaße & Safe-Area-Abstände
│   │   │   └── AppKeyboardHost.swift         # Einbindung pro Eingabeansicht (eingebettet/schwebend)
│   │   ├── Settings/
│   │   │   ├── SettingsView.swift            # Einstellungen-Übersicht (Kategorien)
│   │   │   ├── SettingsCategory.swift        # Kategorien & Detailseiten
│   │   │   ├── KeyboardSettingsSection.swift # Tastatur-Modus, Tipp-Feedback & Live-Status
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
│       ├── KeyboardFeedback.swift            # Klang & Haptik bei jedem Tastendruck
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

## ⌨️ Bildschirmtastatur: warum es so lange nicht ging – und wie es jetzt läuft

### Das eigentliche Problem

**In Apps, die in Swift Playgrounds auf dem iPad laufen, liefert iPadOS die
Texteingabe nicht an die App.** Ein Tippen setzt den Cursor, aber:

- die Bildschirmtastatur erscheint nicht,
- es kommt auch kein Zeichen einer angeschlossenen Hardware-Tastatur an,
- nur „Einsetzen“ aus der Zwischenablage funktioniert.

Das ist **kein Fehler dieser App** und auch kein Fokus-Problem. Es ist ein seit
**iPadOS 16.1** dokumentierter Fehler von Swift Playgrounds (Apple Developer
Forums, [Thread 715614 – „iPad OS 16.1, Playgrounds and input fields“](https://developer.apple.com/forums/thread/715614)),
der in Berichten bis **iPadOS 18** und **iPadOS 26** (Playgrounds 4.6.4)
auftritt. Genau deshalb konnten alle früheren Versuche nichts bewirken:
`becomeFirstResponder()`, `@FocusState`, Wartezeiten, `reloadInputViews()`,
Key-Window-Prüfungen oder Diagnose-Logs kommen alle nicht dagegen an – sie
reparieren den Fokusablauf einer Umgebung, die die Tastatur gar nicht erst
herausgibt.

### Die Lösung in dieser App

Die App bringt eine **eigene Bildschirmtastatur** mit (`Views/Keyboard/`).
Sie ist eine normale SwiftUI-Ansicht innerhalb der App, braucht also weder die
Systemtastatur noch Tastenereignisse von iPadOS – sie funktioniert immer, weil
sie nur Tipps benötigt.

Die Tastatur wird **unten an die jeweilige Eingabeansicht angebunden** und ist
Teil der normalen Ansichts-Hierarchie – ihre Tasten funktionieren auf echten
Geräten zuverlässig, und Tipps auf die Tastatur können keine Gesten
dahinterliegender Ebenen auslösen (kein ungewolltes Schließen von Notiz oder
Einstellungen). Der oberste sichtbare Host zeigt die Tastatur, darunterliegende
Hosts bleiben leer – es gibt also nie zwei Tastaturen gleichzeitig. Bei
Rotation, Split View und Stage Manager skaliert die Höhe mit der Ansicht
(höchstens ~42 % der Ansichtshöhe, mindestens 240 pt); die unterste Tastenreihe
bleibt oberhalb des Home-Indikators.

Dafür gibt es **zwei Darstellungen** (`AppKeyboardPresentation`):

| Darstellung | Verhalten | Verwendet in |
| --- | --- | --- |
| **Eingebettet** (`safeAreaInset`, Standard) | Der Inhalt weicht der Tastatur aus, das aktive Feld bleibt sichtbar | Einstellungen und Bearbeiten-Sheets |
| **Schwebend** (Overlay, abgerundet, mit Schatten) | Die Tastatur liegt **über** dem Inhalt, dessen Layout sich nicht ändert | Zeichenfläche (Notiz) |

Auf der Zeichenfläche ist das entscheidend: Die Notiz behält beim Tippen Größe
und Position. Früher hat die eingebettete Tastatur die Safe Area verändert –
die Notiz wurde dadurch klein gerechnet und nach oben geschoben. Jetzt
schwebt die Tastatur über dem Zettel (leicht durchscheinend, damit die Notiz
darunter sichtbar bleibt), und nur das gerade bearbeitete Textfeld holt die
Notiz bei Bedarf ohne Skalierung ein Stück nach oben.

Der Ablauf:

1. `TextInputHub` beobachtet die Bearbeitung aller Textfelder
   (`UITextField`/`UITextView`-Benachrichtigungen, dazu gehört auch das
   SwiftUI-`TextField`) und zusätzlich das First-Responder-Feld nach jedem Tipp.
2. Bleibt die Systemtastatur aus (oder zeigt iPadOS nur den ca. 44 pt hohen
   Kurzbefehl-Streifen einer Hardware-Tastatur), blendet die App ihre eigene
   Tastatur ein (`Views/Keyboard/AppKeyboardView.swift`).
3. Getippt wird über die öffentliche `UIKeyInput`-Schnittstelle
   (`insertText(_:)` / `deleteBackward()`) direkt in das fokussierte Feld –
   also über denselben Weg, den auch die echte Tastatur nimmt. Cursorposition,
   Sicherheitsfeld (Passwort) und die SwiftUI-Bindungen bleiben dadurch
   korrekt; anschließend wird das Feld zusätzlich über die Textänderung
   informiert.

Erscheint die Systemtastatur doch (z. B. in Xcode oder wenn keine
Hardware-Tastatur gekoppelt ist), tritt die App-Tastatur automatisch zurück.

### ⌨️ Aufbau der App-Tastatur (Apple-Stil)

Die Tastatur ist bewusst **wie die Tastatur von iPadOS** aufgebaut – im Layout,
in den Farben und in der Bedienung:

- **Ebenen**: Buchstaben (QWERTZ mit `Ü Ö Ä ß`) → `123` (Zahlen) → `#+=`
  (Sonderzeichen) → Emoji. Die Ebenen-Tasten sitzen wie bei Apple unten links
  (`123`, `#+=`, `ABC`) und in der dritten Reihe.
- **Untere Reihe wie bei Apple**: Ebenen-Taste, Emoji-Taste (öffnet die
  Emoji-Ebene), breite Leertaste, Punkt mit kleinem **`?!,`**-Hinweis,
  Eingabetaste.
- **Eingabetaste mit Aktion**: Sie zeigt die Aktion des Felds („Fertig“,
  „Weiter“, „Suchen“, „Senden“ …) bzw. das ⏎-Symbol. In mehrzeiligen Feldern
  fügt sie einen Zeilenumbruch ein, in einzeiligen Feldern beendet sie die
  Bearbeitung – genau wie bei Apple.
- **Akzent-Popup**: Langes Drücken auf eine Taste zeigt die Alternativen
  (`a` → `à á â ä æ …`, `o` → `ò ó ô ö œ ø …`, `s` → `ß ś š`, `.` → `, ? ! …`,
  `0` → `°`). Seitliches Ziehen wählt aus; das gewählte Zeichen ist im Popup
  hervorgehoben.
- **Umschalten wie bei Apple**: Die Umschalttaste zeigt den gefüllten Pfeil
  (Shift) und wird beim **Doppeltipp** zur Feststelltaste (`capslock.fill`).
  Nach einem Satzende schaltet die Tastatur im Satzmodus automatisch wieder
  groß. „ß“ bleibt „ß“ – daraus wird kein „SS“.
- **Doppelter Leertipp wird zu „. “** – in Sicherheitsfeldern (Passwort)
  bewusst nicht.
- **Tasten lösen beim Loslassen aus**; die Löschtaste wirkt sofort und
  wiederholt sich beim Halten (mit fester Obergrenze, damit nichts
  „durchläuft“).
- **Feedback beim Tippen wie bei Apple**: Jeder Tastendruck gibt ein leises
  Klickgeräusch und eine feine Haptik aus. Weil das iPad (außer dem Apple
  Pencil Pro) keinen Taptic Engine hat, ist dort der **Klang** das
  eigentliche Feedback – genau wie bei der iPad-Tastatur, deren Lautstärke
  und Stummschalter mitgelten.
- **Aussehen**: helle Tasten auf grauem Grund im Light Mode, graue Tasten auf
  dunklem Grund im Dark Mode, flache Tasten mit 1 pt Schattenkante, abgerundete
  Ecken – dazu eine schmale Kurzbefehl-Leiste mit Cursor-Pfeilen, Einfügen und
  Ausblenden.

**Einstellbar** unter *Einstellungen → Tastatur & Eingabe*:

| Modus | Verhalten |
| --- | --- |
| **Automatisch** (Standard) | App-Tastatur nur, wenn das System keine vollständige Tastatur zeigt |
| **Immer anzeigen** | App-Tastatur bei jedem Textfeld, auch zusätzlich zur Systemtastatur |
| **Nur Systemtastatur** | App-Tastatur aus |

Dort gibt es außerdem den Schalter **Feedback beim Tippen** („Klang & Haptik“,
Standard: an, mit Hörprobe) und eine **Live-Statusanzeige** (Systemtastatur sichtbar?,
App-Tastatur aktiv?, Textfeld erkannt?, Hardware-Tastatur erkannt?,
Key-Window?, letztes Ereignis). Damit ist sofort sichtbar, was iPadOS gerade
tut – statt nur zu vermuten, dass etwas „repariert“ sei.

### Wenn zusätzlich die Systemtastatur erscheinen soll

1. Hardware-Tastatur (Magic Keyboard, Bluetooth) abtrennen.
2. Swift Playgrounds vollständig schließen und **mit abgetrennter Tastatur**
   neu öffnen (der Fehler tritt danach oft wieder auf, sobald der
   Playgrounds-Editor den Fokus hatte).
3. Ggf. den iPad neu starten.
4. Hilfreich sein kann: *Einstellungen → Bedienungshilfen → Tippen →
   AssistiveTouch → „Bildschirmtastatur einblenden“*.

### Technische Randnotizen

- `appKeyboardHost()` wird auf jeder Eingabeansicht installiert (Einstellungen,
  Fach-/Lehrer-Bearbeiten-Sheets, Zeichenfläche). Der `TextInputHub` merkt sich
  die Host-Reihenfolge; nur der oberste Host blendet die Tastatur ein, dadurch
  entstehen auch in verschachtelten Sheets nie zwei Tastaturen. Auf ein
  eigenes Overlay-Fenster wird bewusst verzichtet: Es erhielt auf echten
  Geräten keine zuverlässigen Tipps und ließ Sheets/Notizen beim Tippen auf
  die Tastatur ungewollt schließen.
- `appKeyboardHost(presentation:)` bestimmt die Darstellung: `.embedded`
  (Standard, `safeAreaInset`) für Einstellungen und Sheets, `.floating`
  (Overlay über dem Inhalt) für die Zeichenfläche. Die Notiz berechnet ihre
  Skalierung ausschließlich aus `geometry.size`; auf einen Wechsel der Safe
  Area reagiert sie nicht mehr, und `.ignoresSafeArea(.keyboard)` verhindert
  auch bei der Systemtastatur, dass die Zeichenfläche verkleinert wird.
- Die Tastenhöhe (`AppKeyboardLayout.keyHeight`) reserviert fest die 32 pt
  hohe Kurzbefehl-Leiste und den Home-Indikator-Abstand; dadurch füllen die
  vier Reihen exakt die Tastaturhöhe, ohne dass etwas verrutscht. Die
  schwebende Variante verwendet `AppKeyboardLayout.floatingHeight` – dieselbe
  Höhe, nur über den Inhalt gelegt.
- Die Kopfzeile der geöffneten Notiz verwendet die adaptive System-Textfarbe:
  **weiß im Dark Mode, dunkel im Light Mode**. Das weiße Papier und die dort
  gewählten Text-/Stiftfarben ändern sich dadurch nicht.
- Layout-Checks und die iPad-Testschritte stehen unter
  [`Tests/KeyboardAndDarkMode.md`](Tests/KeyboardAndDarkMode.md).
- Die Zeichenflächen-Textfelder (`NoteTextEditor`/`CustomNoteTextView`) melden
  sich zusätzlich ausdrücklich beim Hub an – so funktioniert das Text-Werkzeug
  auch dann, wenn der programmatische Fokus in der Playgrounds-Umgebung nicht
  greift.
- Es gibt weiterhin keine `reloadInputViews()`-Aufrufe: Sie können laufende
  Tastaturübergänge abbrechen.
- Eine Key-Window-Reparatur (`window.makeKey()`) läuft höchstens einmal pro
  App-Start und nur, wenn kein Systemfenster (z. B. ein Alert) oberhalb liegt.
  Sie kann in manchen Konfigurationen die Systemtastatur zurückholen, ist aber
  nicht die eigentliche Lösung – das ist die App-Tastatur.
