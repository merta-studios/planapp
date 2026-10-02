# iPad-Regression: Notizrahmen und app-eigene Bildschirmtastatur

Die App benötigt für einen vollständigen Build **Swift Playgrounds oder Xcode
mit iOS-SDK**. Die UI-Checks auf einem iPad bzw. iPad-Simulator durchführen.

## Reine Layout-Checks (kein iOS-SDK nötig)

Vom Repository-Root mit einer installierten Swift-Toolchain:

```sh
swiftc PlanApp.swiftpm/Views/Keyboard/AppKeyboardLayout.swift \
    Tests/KeyboardLayout/main.swift -o /tmp/planapp-keyboard-layout-tests
/tmp/planapp-keyboard-layout-tests
```

Geprüft werden Hoch-/Querformat, Split View, Safe-Area-Abstände, adaptive
Tastenhöhen, die Höhe der eingebetteten Tastatur sowie native Tastatur-/
Hardware-Kurzbefehlsstreifen und ungültige Maße.

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

Die Tastatur ist Teil der normalen Ansichts-Hierarchie (`safeAreaInset` unten
an der jeweiligen Eingabeansicht) – **nicht** ein eigenes Overlay-Fenster.
Dadurch erscheint sie immer am unteren Rand der Ansicht, in der getippt wird
(Zeichenfläche: unterer Bildschirmrand; Einstellungen und Bearbeiten-Sheets:
unten im Sheet), ihre Tasten funktionieren zuverlässig, und Tipps auf die
Tastatur können keine Gesten dahinterliegender Ebenen auslösen (Notiz oder
Sheet schließen sich nicht ungewollt).

In Swift Playgrounds testen, wenn die Systemtastatur ausbleibt. Alternativ im
Simulator eine Hardware-Tastatur verbinden, damit keine vollständige
Systemtastatur angezeigt wird. Unter *Einstellungen → Tastatur & Eingabe*
**Automatisch** wählen.

1. *WebUntis & Sync* öffnen und nacheinander Server, Schule, Benutzername und
   Passwort bearbeiten. Die Tastatur erscheint unten im Einstellungen-Sheet,
   direkt unter dem Inhalt, und bleibt beim Scrollen erhalten. Es gibt
   **genau eine** App-Tastatur; Passwort bleibt maskiert. *Tastatur & Eingabe*
   darf nicht melden, dass das eigentliche App-Fenster seinen Key-Window-
   Status verliert.
2. Buchstaben, Umschalten, Umlaute, `123`, Symbole, Leertaste, Cursorpfeile,
   Einfügen und gedrückt gehaltenes Löschen prüfen. Die Eingabe landet im
   richtigen Feld.
3. *Fächer & Farben* und *Lehrkräfte* prüfen, jeweils ein neues Element
   anlegen und ein bestehendes im **zusätzlichen Bearbeiten-Sheet** ändern:
   Das Bearbeiten-Sheet zeigt seine eigene Tastatur unten im Sheet, die
   Einstellungen darunter zeigen keine zweite Tastatur. Textfelder und
   Speichern/Abbrechen bleiben durch Scrollen erreichbar; der Cursor wird über
   der Tastatur sichtbar gehalten.
4. Im Notiz-Overlay das Text-Werkzeug aktivieren, ein Textfeld anlegen und
   schreiben. Die Tastatur erscheint am unteren Bildschirmrand; die Notiz
   passt sich an den verfügbaren Bereich oberhalb der Tastatur an.
5. Mit offener Tastatur drehen und die Fenstergröße in **Split View / Stage
   Manager** ändern. Die Tastaturhöhe skaliert mit der Ansicht (höchstens
   ~42 % der Höhe, mindestens 240 pt) und bleibt am unteren Rand.
6. Bei geöffneter Tastatur Light/Dark Mode wechseln. Tasten bleiben lesbar.
7. **Wichtig:** Mit offener Tastatur mehrfach auf Tasten tippen – die Notiz
   bzw. das Einstellungen-Sheet darf sich dadurch **nicht** schließen.
   *Ausblenden* und *Fertig* auf der Tastatur sowie Schließen der
   Einstellungen und der Notiz testen: Die Tastatur verschwindet und
   blockiert keine Tipps. Erneutes Fokussieren eines Felds blendet sie wieder
   ein. Notizen mit dem Pencil zeichnen/verschieben; diese Gesten bleiben
   ungestört.
8. **Nur Systemtastatur** wählen: Keine App-Tastatur und kein leerer unterer
   Platzhalter. In **Automatisch** mit einer tatsächlich sichtbaren
   Systemtastatur prüfen, dass die App-Tastatur zurücktritt.
9. **Immer anzeigen** mit sichtbarer Systemtastatur prüfen: Die App-Tastatur
   liegt unten an der Ansicht. Zurück zu **Automatisch** mit Hardware-
   Tastatur: Ein schmaler nativer Kurzbefehlsstreifen verhindert die
   App-Tastatur nicht.
10. Unter *Tastatur & Eingabe* **App-Tastatur jetzt einblenden** ohne aktives
    Textfeld antippen: Die Tastatur erscheint unten im Einstellungen-Sheet.
    *Ausblenden*, Wechsel zu **Nur Systemtastatur** oder Schließen der
    Einstellungen entfernt sie samt Inhaltsabstand.
