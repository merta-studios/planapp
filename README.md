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
  - **Rückgängig & Vorwärts (Undo/Redo)**.
- **Apple Pencil Pro Squeeze-Unterstützung**: Durch leichtes Zusammendrücken des Apple Pencil Pro wird der letzte Strich sofort rückgängig gemacht (`UIPencilInteraction`).
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
│   │   ├── Keyboard/
│   │   │   ├── TextInputHub.swift            # Eingabe-Hub, Tastatur-Erkennung & Diagnose
│   │   │   ├── AppKeyboardView.swift         # App-eigene Bildschirmtastatur
│   │   │   ├── AppKeyboardWindow.swift       # Gemeinsame Tastaturebene über allen Sheets
│   │   │   ├── AppKeyboardLayout.swift       # Fensterbezogene Größe & Überlappung
│   │   │   └── AppKeyboardHost.swift         # App-Root-Einbindung, Inhaltsabstand & Tipp-Überwachung
│   │   ├── Settings/
│   │   │   ├── SettingsView.swift            # Einstellungen-Übersicht (Kategorien)
│   │   │   ├── SettingsCategory.swift        # Kategorien & Detailseiten
│   │   │   ├── KeyboardSettingsSection.swift # Tastatur-Modus & Live-Status
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

Die Tastatur liegt **fensterweit über allen Ansichten und Sheets**, nicht im
Einstellungen-Formular. Sie füllt die **untere Hälfte des aktuellen App-Fensters
über die volle Breite** aus und bleibt unten angedockt. Bei Rotation, Split View
und Stage Manager richtet sie sich nach der App-Fenstergröße. Die zusätzliche
Tastaturebene wird nicht zum Key-Window; das bearbeitete Feld behält den Fokus.
Einstellungen und Notiz halten nur den tatsächlich verdeckten Inhaltsbereich
frei, auch bei einem weiteren Fach-/Lehrer-Bearbeiten-Sheet. Falls ein nativer
Hardware-Kurzbefehlsstreifen oder im Modus **Immer anzeigen** zusätzlich die
Systemtastatur erscheint, dockt die App-Tastatur direkt darüber im verbleibenden
Fensterbereich an, damit keine Tasten verdeckt werden.

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

**Einstellbar** unter *Einstellungen → Tastatur & Eingabe*:

| Modus | Verhalten |
| --- | --- |
| **Automatisch** (Standard) | App-Tastatur nur, wenn das System keine vollständige Tastatur zeigt |
| **Immer anzeigen** | App-Tastatur bei jedem Textfeld, auch zusätzlich zur Systemtastatur |
| **Nur Systemtastatur** | App-Tastatur aus |

Dort gibt es außerdem eine **Live-Statusanzeige** (Systemtastatur sichtbar?,
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

- `appKeyboardHost()` wird einmal am App-Root installiert. Eingabeansichten
  verwenden nur `appKeyboardAvoidance()` für den benötigten Inhaltsabstand –
  dadurch entstehen auch in verschachtelten Sheets keine weiteren Tastaturen.
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
