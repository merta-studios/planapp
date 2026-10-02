# iPad-Regression: Notizrahmen und fensterweite App-Tastatur

Die App benötigt für einen vollständigen Build **Swift Playgrounds oder Xcode
mit iOS-SDK**. Die UI-Checks auf einem iPad bzw. iPad-Simulator durchführen.

## Reine Layout-Checks (kein iOS-SDK nötig)

Vom Repository-Root mit einer installierten Swift-Toolchain:

```sh
swiftc PlanApp.swiftpm/Views/Keyboard/AppKeyboardLayout.swift \
    Tests/KeyboardLayout/main.swift -o /tmp/planapp-keyboard-layout-tests
/tmp/planapp-keyboard-layout-tests
```

Geprüft werden Hoch-/Querformat, Split View, überlappende/nicht überlappende
Sheets, Safe-Area-Abstände, adaptive Tastenhöhen, native Tastatur-/Hardware-
Kurzbefehlsstreifen sowie ungültige Maße.

## Notizrahmen

1. Demostundenplan laden und eine Stunde im **Light Mode** öffnen.
2. Fachname, Lehrkraft, Raum, Stunde und Datum im aufgeklappten Rahmen müssen
   dunkel lesbar sein.
3. Bei geöffneter Notiz das iPad auf **Dark Mode** umstellen: Die Texte und
   zugehörigen Symbole müssen hell/weiß werden, der Rahmen bleibt dunkel.
4. Notiz schließen und erneut öffnen. Auch während/nach der Aufklapp-Animation
   prüfen. Die pastellfarbenen Stundenkarten behalten dunklen Text.
5. Das weiße Notizpapier bleibt weiß. Handschrift und Textfelder auf dem Papier
   behalten ihre gewählten Farben, insbesondere Schwarz.

## App-Tastatur

In Swift Playgrounds testen, wenn die Systemtastatur ausbleibt. Alternativ im
Simulator eine Hardware-Tastatur verbinden, damit keine vollständige
Systemtastatur angezeigt wird. Unter *Einstellungen → Tastatur & Eingabe*
**Automatisch** wählen.

1. *WebUntis & Sync* öffnen und nacheinander Server, Schule, Benutzername und
   Passwort bearbeiten. Es gibt **genau eine** App-Tastatur, unabhängig von
   Breite/Position des Einstellungen-Sheets: volle Breite des App-Fensters,
   untere Hälfte, bündig am unteren Fensterrand. Kein zusätzlicher schmaler
   Tastaturblock innerhalb der Einstellungen.
2. Buchstaben, Umschalten, Umlaute, `123`, Symbole, Leertaste, Cursorpfeile,
   Einfügen und gedrückt gehaltenes Löschen prüfen. Eingabe landet weiter im
   richtigen Feld; Passwort bleibt maskiert. *Tastatur & Eingabe* darf nicht
   melden, dass das eigentliche App-Fenster seinen Key-Window-Status verliert.
3. *Fächer & Farben* und *Lehrkräfte* prüfen, jeweils ein neues Element anlegen
   und ein bestehendes im **zusätzlichen Bearbeiten-Sheet** ändern. Keine
   doppelte Tastatur. Textfelder und Speichern/Abbrechen bleiben durch Scrollen
   erreichbar; der Cursor wird über der Tastatur sichtbar gehalten.
4. Im Notiz-Overlay das Text-Werkzeug aktivieren, ein Textfeld anlegen und
   schreiben. Tastatur ebenfalls fensterweit unten. Die Notiz passt sich an
   den verfügbaren Bereich oberhalb der Tastatur an.
5. Mit offener Tastatur drehen und die Fenstergröße in **Split View / Stage
   Manager** ändern. Breite, Höhe und Inhaltsabstand müssen mit dem aktuellen
   App-Fenster skalieren, nicht mit der gesamten iPad-Displaygröße.
6. Bei geöffneter Tastatur Light/Dark Mode wechseln. Tasten bleiben lesbar.
7. *Ausblenden* und *Fertig* auf der Tastatur sowie Schließen der Einstellungen
   und der Notiz testen. Die Tastatur verschwindet und blockiert keine Tipps.
   Erneutes Fokussieren eines Feldes blendet sie wieder ein. Notizen mit dem
   Pencil zeichnen/verschieben; diese Gesten bleiben ungestört.
8. **Nur Systemtastatur** wählen: Keine App-Tastatur und kein leerer unterer
   Platzhalter. In **Automatisch** mit einer tatsächlich sichtbaren
   Systemtastatur prüfen, dass die App-Tastatur zurücktritt.
9. **Immer anzeigen** mit sichtbarer Systemtastatur prüfen: Die App-Tastatur
   liegt fensterweit direkt darüber, nicht darunter und nicht im Sheet.
   Zurück zu **Automatisch** mit Hardware-Tastatur: Ein schmaler nativer
   Kurzbefehlsstreifen verhindert die App-Tastatur nicht und verdeckt auch
   nicht deren untere Tastenreihe.
10. Unter *Tastatur & Eingabe* **App-Tastatur jetzt einblenden** ohne aktives
    Textfeld antippen: Die Vorschau erscheint ebenfalls fensterweit unten.
    *Ausblenden*, Wechsel zu **Nur Systemtastatur** oder Schließen der
    Einstellungen entfernt auch diese Vorschau samt Inhaltsabstand.
