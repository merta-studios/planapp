# iPad-Regression: Notizrahmen und Dark Mode

Die App benötigt für einen vollständigen Build **Swift Playgrounds oder Xcode
mit iOS-SDK**. Die UI-Checks auf einem iPad bzw. iPad-Simulator durchführen.

## Reine Layout-Checks (kein iOS-SDK nötig)

Vom Repository-Root mit einer installierten Swift-Toolchain:

```sh
Tests/run-regressions.sh
```

Geprüft werden u. a. die Spaltenanzahl und das Zeilen-Layout der
„Nur Notizen“-Übersicht sowie die Squeeze-Paletten-Geometrie.

## Texteingabe

Textfelder benutzen die Systemtastatur (die frühere app-eigene Tastatur
wurde entfernt). In Swift Playgrounds kann die Systemtastatur ausbleiben; in
der installierten App (Sideloadly/Xcode) erscheint sie zuverlässig.

## Notizrahmen

1. Demostundenplan laden und eine Stunde im **Light Mode** öffnen.
2. Fachname, Lehrkraft, Raum, Stunde und Datum im aufgeklappten Rahmen müssen
   dunkel lesbar sein.
3. Bei geöffneter Notiz das iPad auf **Dark Mode** umstellen: Die App bleibt
   standardmäßig **hell** (Einstellungen → Darstellung), Papier und Schrift
   ändern sich also nicht. Erst wenn dort **Automatisch** oder **Dunkel**
   gewählt wird, passen sich Rahmen, Menüs und Werkzeugleisten an – Texte auf
   dem weißen Papier bleiben aber **immer schwarz**.
4. Notiz schließen und erneut öffnen. Auch während/nach der Aufklapp-Animation
   prüfen. Die pastellfarbenen Stundenkarten behalten dunklen Text.
5. Das weiße Notizpapier bleibt weiß. Handschrift und Textfelder auf dem Papier
   behalten ihre gewählten Farben, insbesondere Schwarz.

## Dark Mode der Zeichenfläche (Tinte bleibt schwarz)

1. Gerät auf **Dark Mode** stellen, App-Darstellung auf **Automatisch**.
2. Eine Notiz mit schwarzer Handschrift öffnen: Die Striche müssen **schwarz**
   auf weißem Papier bleiben (die Zeichenfläche läuft fest im hellen
   Erscheinungsbild, `overrideUserInterfaceStyle = .light`).
3. Notiz schließen: Die Vorschau im Stundenplan und in „Nur Notizen“ zeigt
   ebenfalls schwarze Striche.

## „Nur Notizen“ (Leistung)

1. Mindestens zehn Notizen anlegen (Handschrift + Textfelder, verschiedene Tage).
2. In den Modus „Nur Notizen“ wechseln und schnell scrollen: kein Ruckeln,
   Karten erscheinen sofort (Vorschauen werden asynchron geladen und im
   Cache gehalten).
3. Zurück in den Standard-Modus und erneut in „Nur Notizen“: Vorschauen sind
   sofort da (Cache).
