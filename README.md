# PlanApp – Stundenplan-App fürs iPad & Swift Playgrounds

Eine moderne, elegante und leistungsstarke Stundenplan-App für das **iPad**, entwickelt in **Swift & SwiftUI** mit voller Unterstützung für **Apple Pencil Pro**, **PencilKit** und die **WebUntis API**.

Dieses Repository kann direkt auf das iPad geklont werden und öffnet sich sofort als lauffähige App in **Swift Playgrounds 4+** oder Xcode.

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
  - **Rückgängig & Vorwärts (Undo/Redo)**.
- **Apple Pencil Pro Squeeze-Unterstützung**: Durch leichtes Zusammendrücken des Apple Pencil Pro wird der letzte Strich sofort rückgängig gemacht (`UIPencilInteraction`).
- **Apple Pencil Hover**: Alle Buttons und Karten unterstützen iPadOS Pointer- & Hover-Effekte (`.hoverEffect(.lift)`).
- **Automatischer Rand-Zuschnitt**: Beim Schließen wird die Zeichnung exakt an den Rändern der geschriebenen Striche zugeschnitten und als gestochen scharfe Vorschau direkt im Stundenplan-Block angezeigt!

---

## 📂 Projektstruktur

```
planapp/
├── Package.swift                             # Swift Package App Manifest für Swift Playgrounds 4+
├── App.swift                                 # App Entry Point (@main)
├── .swiftpm/
│   └── xcode/package.xcworkspace/            # Swift Playgrounds Workspace
├── Models/
│   ├── Period.swift                          # Stundenzeiten & Perioden-Modell
│   ├── Lesson.swift                          # Unterrichtsstunden & Doppelstunden-Logik
│   ├── SubjectCustomization.swift            # Fächer-Ersetzungen & Farbkonfiguration
│   ├── BlockDisplaySettings.swift            # Sichtbare Block-Elemente
│   ├── LessonNote.swift                      # Handschriftliche Notizen & Bilddaten
│   └── UntisCredentials.swift                # WebUntis JSON-RPC Zugangsdaten
├── Services/
│   ├── WebUntisService.swift                 # WebUntis JSON-RPC 2.0 API Client
│   ├── TimetableStorageService.swift         # Lokale Speicherung (UserDefaults & Dateien)
│   └── DemoDataService.swift                 # Beispieldaten-Generator
├── ViewModels/
│   └── TimetableViewModel.swift              # Zentraler Zustand & Controller
├── Views/
│   ├── Timetable/
│   │   ├── TimetableView.swift               # Hauptansicht mit 6-Spalten-Raster & Wischgesten
│   │   ├── TimetableHeaderView.swift         # Kopfzeile mit Wochennavigation & Sync
│   │   ├── PeriodColumnView.swift            # 1. Spalte: Stundennummern & Uhrzeiten
│   │   ├── DayColumnView.swift               # Wochentagsspalten mit Zebra-Muster
│   │   ├── LessonBlockView.swift             # Stunden-Karten mit Status & Notiz-Vorschau
│   │   └── EmptyTimetableView.swift          # Willkommens-Ansicht bei leerem Plan
│   ├── Drawing/
│   │   ├── LessonDrawingOverlayView.swift    # Fullscreen-Overlay mit Zettel & Gesten
│   │   ├── LinedPaperBackground.swift        # Linierter Zettel mit rotem Rand
│   │   ├── PencilKitCanvasRepresentable.swift# PencilKit Wrapper & Apple Pencil Pro Squeeze
│   │   └── DrawingToolbarView.swift          # Vorgegebene Stift-, Textmarker- & Radier-Tools
│   ├── Settings/
│   │   ├── SettingsView.swift                # Einstellungen-Hauptmenü
│   │   ├── UntisConfigSection.swift          # WebUntis Zugangsdaten & Sync-Test
│   │   ├── SubjectCustomizationSection.swift # Fächer anlegen & Farben wählen
│   │   ├── BlockDisplaySettingsSection.swift # Block-Inhalte anpassen
│   │   └── PeriodConfigSection.swift         # Stundenzeiten anzeigen & bearbeiten
│   └── Components/
│       ├── HoverButton.swift                 # Apple Pencil Hover Buttons
│       ├── ColorPickerPresets.swift          # Farbpaletten-Auswahl
│       └── StatusBadge.swift                 # Status-Badges (Entfall, Vertretung, Heute)
└── Utils/
    ├── ColorExtensions.swift                 # Hex-Konvertierung & Kontrastfarben
    ├── DateExtensions.swift                  # Kalenderwochen & Tagesberechnungen
    └── PencilInteractions.swift              # Apple Pencil Pro Squeeze- & Hover-Handler
```

---

## 🚀 Inbetriebnahme auf dem iPad

1. Klone dieses Repository auf dein iPad (z. B. mit *Working Copy* oder erstelle einen Ordner in der *Dateien*-App).
2. Öffne **Swift Playgrounds** auf deinem iPad.
3. Wähle **App-Playground öffnen** und navigiere zum geklonten Ordner `planapp`.
4. Tippe auf **App starten** (Play-Button) – die App öffnet sich sofort im Vollbildmodus auf deinem iPad!
