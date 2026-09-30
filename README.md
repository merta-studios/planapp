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

### 🔄 2. WebUntis API JSON-RPC Integration
- Vollständige Integration der offiziellen **WebUntis JSON-RPC 2.0 API** (`/WebUntis/jsonrpc.do`).
- Abruf von:
  - **Stundenzeiten (Timegrid Units)** zur automatischen Zeilen-Konfiguration.
  - **Stundenplandaten** für jede Kalenderwoche.
- **Offline- & Demo-Modus**: Enthält einen integrierten Generator für realistische Beispieldaten (Doppelstunden, Entfall, Vertretung), um alle Features ohne aktiven Schul-Account sofort testen zu können.

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
  - **1 Finger**: Verschiebt den Zettel frei über den Bildschirm.
  - **2 Finger**: Stufenloses Zoomen und Verschieben gleichzeitig.
  - **Apple Pencil**: Schreibt und zeichnet direkt.
- **Restriktive System-Werkzeuge**:
  - **Buntstift / Stift**: Schwarz (Standard), Rot, Blau, Grün.
  - **Textmarker**: Gelb, Orange, Grün, Blau, Lila.
  - **Radierer**: Einfacher Vektor-Radierer.
  - **Rückgängig & Vorwärts (Undo/Redo)**: Auch „Handschrift in Text umwandeln" und „Seite leeren" sind als kombinierter Schritt vollständig rückgängig machbar (Striche + Textfelder zusammen).
- **Apple Pencil Pro Squeeze-Unterstützung**: Durch leichtes Zusammendrücken des Apple Pencil Pro wird der letzte Strich sofort rückgängig gemacht (`UIPencilInteraction`).
- **Apple Pencil Pro Haptik**: Alle Buttons geben eine spürbare Rückmeldung im Stift (`UICanvasFeedbackGenerator`) – auch ein leichter „Tick" beim Hovern über die Werkzeugleiste.
- **Apple Pencil Hover**: Alle Buttons und Karten unterstützen iPadOS Pointer- & Hover-Effekte (`.hoverEffect(.lift)`).
- **Automatischer Rand-Zuschnitt**: Beim Schließen wird die Zeichnung exakt an den Rändern der geschriebenen Striche zugeschnitten und als gestochen scharfe Vorschau direkt im Stundenplan-Block angezeigt!

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
│   │   │   └── EmptyTimetableView.swift      # Willkommens-Ansicht bei leerem Plan
│   │   ├── Drawing/
│   │   │   ├── LessonDrawingOverlayView.swift# Fullscreen-Overlay mit Zettel & Gesten
│   │   │   ├── LinedPaperBackground.swift    # Linierter Zettel mit rotem Rand
│   │   │   ├── PencilKitCanvasRepresentable.swift # PencilKit Wrapper & Apple Pencil Pro Squeeze
│   │   │   └── DrawingToolbarView.swift      # Vorgegebene Stift-, Textmarker- & Radier-Tools
│   │   ├── Settings/
│   │   │   ├── SettingsView.swift            # Einstellungen-Hauptmenü
│   │   │   ├── UntisConfigSection.swift      # WebUntis Zugangsdaten & Sync-Test
│   │   │   ├── SubjectCustomizationSection.swift # Fächer anlegen & Farben wählen
│   │   │   ├── BlockDisplaySettingsSection.swift # Block-Inhalte anpassen
│   │   │   └── PeriodConfigSection.swift     # Stundenzeiten anzeigen & bearbeiten
│   │   └── Components/
│   │       ├── HoverButton.swift             # Apple Pencil Hover Buttons
│   │       ├── ColorPickerPresets.swift      # Farbpaletten-Auswahl
│   │       └── StatusBadge.swift             # Status-Badges (Entfall, Vertretung, Heute)
│   └── Utils/
│       ├── ColorExtensions.swift             # Hex-Konvertierung & Kontrastfarben
│       ├── DateExtensions.swift              # Kalenderwochen & Tagesberechnungen
│       └── PencilInteractions.swift          # Apple Pencil Pro Squeeze- & Hover-Handler
├── README.md
└── .gitignore
```
