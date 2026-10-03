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
3. Bei geöffneter Notiz das iPad auf **Dark Mode** umstellen: Die App bleibt
   standardmäßig **hell** (Einstellungen → Darstellung), Papier und Schrift
   ändern sich also nicht. Erst wenn dort **Automatisch** oder **Dunkel**
   gewählt wird, passen sich Rahmen, Menüs und Werkzeugleisten an – Texte auf
   dem weißen Papier bleiben aber **immer schwarz**.
4. Notiz schließen und erneut öffnen. Auch während/nach der Aufklapp-Animation
   prüfen. Die pastellfarbenen Stundenkarten behalten dunklen Text.
5. Das weiße Notizpapier bleibt weiß. Handschrift und Textfelder auf dem Papier
   behalten ihre gewählten Farben, insbesondere Schwarz.

## App-Tastatur

Die Tastatur ist Teil der normalen Ansichts-Hierarchie – **nicht** ein eigenes
Overlay-Fenster. Dadurch erscheint sie immer am unteren Rand der Ansicht, in
der getippt wird (Zeichenfläche: unterer Bildschirmrand; Einstellungen und
Bearbeiten-Sheets: unten im Sheet), ihre Tasten funktionieren zuverlässig, und
Tipps auf die Tastatur können keine Gesten dahinterliegender Ebenen auslösen
(Notiz oder Sheet schließen sich nicht ungewollt).

Sie kennt zwei Darstellungen (`AppKeyboardPresentation`):

- **Eingebettet** (`safeAreaInset`, Standards in Einstellungen und Sheets):
  Der Inhalt weicht der Tastatur aus.
- **Schwebend** (Zeichenfläche): Die Tastatur liegt als abgerundete,
  durchscheinende Fläche **über** der Notiz. Die Notiz darf dabei **weder
  verkleinert noch verschoben** werden – sie bleibt beim Tippen genau dort,
  wo sie ist. Nur wenn das bearbeitete Textfeld sonst hinter der Tastatur
  läge, rückt die Notiz so weit hoch, dass das Feld sichtbar wird (ohne
  Skalierung, ohne Zoom).

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
   schreiben. Die Tastatur erscheint **schwebend** über der Notiz.
   **Wichtig:** Die Notiz darf sich dabei weder verkleinern noch nach oben
   rutschen – sie bleibt exakt an ihrer Stelle (nur das bearbeitete Textfeld
   wird bei Bedarf ohne Zoom sichtbar gehalten, wenn es sonst hinter der
   Tastatur läge).
5. Mit offener Tastatur drehen und die Fenstergröße in **Split View / Stage
   Manager** ändern. Die Tastaturhöhe skaliert mit der Ansicht (höchstens
   ~42 % der Höhe, mindestens 240 pt) und bleibt am unteren Rand.
6. Bei geöffneter Tastatur Light/Dark Mode wechseln. Tasten bleiben lesbar.
7. **Wichtig:** Mit offener Tastatur mehrfach auf Tasten tippen – die Notiz
   bzw. das Einstellungen-Sheet darf sich dadurch **nicht** schließen.
   Die Chevron-Taste unten rechts in der Kurzbefehl-Leiste („Tastatur
   ausblenden“) sowie Schließen der Einstellungen und der Notiz testen: Die
   Tastatur verschwindet und blockiert keine Tipps. Erneutes Fokussieren eines
   Felds blendet sie wieder ein. Notizen mit dem Pencil zeichnen/verschieben;
   diese Gesten bleiben ungestört.
7a. **Tastatur im Apple-Stil prüfen:** Ebenen `123`/`#+=`/`ABC` und die
   Emoji-Taste; Umschalten (gefüllter Pfeil) und Doppeltipp auf die
   Umschalttaste (Feststelltaste `capslock.fill`); langes Drücken auf `a`,
   `o`, `s`, `.`, `0` öffnet das Akzent-Popup, seitliches Ziehen wählt aus;
   Leertaste zweimal tippen ergibt „. “ (im Passwortfeld nicht); die
   Eingabetaste zeigt die Feld-Aktion („Fertig“, „Weiter“, „Suchen“, …) oder
   ⏎ und fügt in mehrzeiligen Feldern einen Zeilenumbruch ein; die Löschtaste
   wirkt sofort und wiederholt sich beim Halten.
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

## Ansichts-Modus „Nur Notizen“ (Raster)

Die Übersicht ist ein Raster: Tage und die grüne „Jetzt“-Linie laufen über die
volle Breite, die Notizen stehen als gleich breite Karten darunter.

1. Demostundenplan laden und über die Modus-Taste in der Kopfzeile
   **Nur Notizen** wählen. Mehrere Stunden mit Notizen befüllen
   (auch über mehrere Tage).
2. Auf normaler iPad-Breite (quer oder hoch) stehen **drei kompakte Spalten**
   mit gleich breiten Karten. Datum und Stunde stehen in jeder Karte;
   mehrspaltig können verschiedene Tage eine Zeile gemeinsam nutzen.
3. Im schmalen Split View wechseln die Karten auf zwei bzw. eine Spalte. Die
   grüne Jetzt-Linie liegt **zwischen** getrennten Rastern und reicht über die
   volle Fensterbreite, auch bei unvollständiger letzter Kartenzeile darüber.
4. Bei Rotation (quer ↔ hoch) muss das Raster sofort mitwechseln, ohne dass
   Einträge verschwinden oder doppelt erscheinen.
5. Eine Karte antippen: Die Notiz öffnet sich zum Bearbeiten wie im
   Stundenplan. Zurück – die Karte steht weiter an derselben Stelle.
6. Dark Mode prüfen: Karten, Überschriften und die grüne Linie bleiben lesbar.
7. Eine Karte gedrückt halten → **„Im Standard-Modus anzeigen“**. Die App
   wechselt in den Standard-Modus **und** wischt automatisch zu der Woche, in
   der die Stunde liegt (Woche in der Kopfzeile prüfen). Bei einer Stunde aus
   einer anderen Woche muss zuerst die richtige Woche erscheinen, danach erst
   die Karte.

## Darstellung (Hell/Dunkel/Automatisch)

1. *Einstellungen → Darstellung* öffnen. Standard ist **Hell**; das iPad auf
   **Dark Mode** stellen: Die App bleibt hell, die Schrift auf dem weißen
   Papier bleibt schwarz (Stundenblöcke, Notizkarten, Notizrahmen, Textfelder,
   gerenderte Notizbilder).
2. **Dunkel** wählen: Umgebung (Menüs, Kopfzeile, Werkzeugleisten) wird
   dunkel. Werkzeugleisten-Symbole und Beschriftungen bleiben auf ihren
   Glas-/Materialflächen lesbar; Texte **auf dem weißen Papier** bleiben
   weiterhin schwarz.
3. **Automatisch** wählen und das iPad zwischen Hell und Dunkel umschalten:
   Die App folgt, das Papier bleibt weiß.
4. App beenden und neu starten: Die gewählte Darstellung ist erhalten.

## Lade-Anzeige beim Wischen (Punkt 6)

1. WebUntis-Zugangsdaten (Server, Schule, Benutzer, Passwort) eintragen.
2. Zu einer Woche wischen, für die noch nichts geladen wurde (z. B. mehrere
   Wochen voraus). In der Bildschirmmitte muss ein drehendes Lade-Symbol
   erscheinen und **so lange sichtbar bleiben, bis die API-Antwort da ist**.
3. Ohne Netz/Flugmodus: Das Symbol verschwindet nach dem Fehler, die
   Fehlermeldung erscheint.
4. Zurück zu einer bereits geladenen Woche wischen: kein Lade-Symbol.
5. Eine Woche mit Ferien (keine Stunden, aber erfolgreich geladen): kein
   dauerhaftes Symbol, aber „Kein Unterricht“ in jeder Spalte.

## Einrichtungs-Guide statt leerem Stundenplan (Punkt 7)

1. *Einstellungen → Daten & Zurücksetzen* → Stundenplan löschen und die
   WebUntis-Zugangsdaten leeren (oder unvollständig lassen: z. B. nur Server
   und Schule).
2. Zum Stundenplan zurückkehren: Statt einer leeren Woche steht in der Mitte
   ein Guide-Fenster („Stundenplan automatisch laden“, Schritt 1 und 2).
3. **„Zu den Einstellungen“** antippen: Die Einstellungen öffnen sich **direkt
   auf der Seite „WebUntis & Sync“**, nicht auf der Kategorien-Übersicht.
4. „Beispieldaten laden“ antippen: Der Guide verschwindet, der
   Demo-Stundenplan erscheint.
5. Mit gültigen Zugangsdaten synchronisieren: Guide bleibt verschwunden, auch
   nachdem die App neu gestartet wurde.

## Freie Tage: „Kein Unterricht“ (Punkt 5)

1. Eine Woche mit mindestens einem freien Tag anzeigen (z. B. Ferien oder
   unterrichtsfreier Tag).
2. In der Spalte des freien Tages steht mittig ein um **90° gedrehter, grauer**
   Text „Kein Unterricht“ – in **Standard** und in **Notizen hervorgehoben**.
3. Tage mit mindestens einer Stunde zeigen den Hinweis nicht.
4. In „Nur Notizen“ gibt es den Hinweis nicht (die Übersicht zeigt nur
   Notizen).

## Apple-Pencil-Einstellungen (Punkte 8 & 9)

1. *Einstellungen → Zeichnen & Apple Pencil*: „Apple Pencil“ ist **aus**,
   „Radierer automatisch abwählen“ ist **an**.
2. Bei ausgeschaltetem „Apple Pencil“ im Notiz-Overlay mit **einem Finger**
   zeichnen: Es entsteht ein Strich.
3. Den Apple Pencil benutzen: Danach muss „Apple Pencil“ automatisch **an**
   sein (Einstellungen prüfen). Mit dem Finger zeichnen geht jetzt nicht mehr;
   Zwei-Finger-Zoom/Verschieben und der Kopf-Griff funktionieren weiter.
4. „Radierer automatisch abwählen“ einschalten, Radierer wählen, radieren und
   den Stift loslassen: Das Werkzeug wechselt automatisch zurück zum zuletzt
   benutzten Werkzeug (bzw. zum Stift, wenn vorher keins aktiv war).
5. Schalter ausschalten und wiederholen: Der Radierer bleibt aktiv.

## Squeeze-Werkzeugpalette (Punkt 10)

Nur mit Apple Pencil Pro (iOS/iPadOS 17.5+) prüfbar.

1. Notiz öffnen, den Stift in der Nähe des Zettels schweben lassen und
   **zusammendrücken**. An der letzten Hover-Position öffnet sich ein
   **Viertelkreis** – in der Richtung, in die der Stift zeigt.
2. Die acht runden Buttons (Rückgängig, Lasso, Stift, Textmarker, Radierer,
   Text, Farbe und Dicke) sind größer, der Bogen schmaler und näher am Hover.
   Über Farbe hovern öffnet den äußeren Farbbogen; Dicke halten und radial ziehen.
3. Erneuter Squeeze oder Fingertipp schließt die Palette. Bei einem Tipp auf
   den abgedunkelten Hintergrund bleibt die Notiz selbst zunächst offen.
4. Mit dem Stift schreiben: Die Palette verschwindet automatisch.
5. Der alte Undo-auf-Squeeze darf **nicht** mehr passieren; der Doppeltipp des
   Pencil löst weiterhin Rückgängig aus.
6. Palette nahe am Bildschirmrand öffnen: Sie wird so verschoben/verkleinert,
   dass der komplette Viertelkreis sichtbar bleibt.

## Tipp-Feedback der App-Tastatur (Punkt 3)

1. *Einstellungen → Tastatur & Eingabe → Feedback beim Tippen*: Schalter auf
   **an** (Standard). „Feedback ausprobieren“ und Tippen auf der App-Tastatur
   müssen ein leises Klickgeräusch geben (Lautstärke aufdrehen, Stummschalter
   aus).
2. Schalter **aus**: Tippen bleibt stumm.
3. Beim Einschalten ertönt automatisch eine Hörprobe.


## Erweiterte Regressionsprüfung

Die detaillierten aktuellen Prüfungen für Rand-/Handballenerkennung, veraltete
Stundenpläne, drei Notizenspalten, Druck-Feedback aller Tasten und native
Liquid-Glass-Palettenbuttons stehen in
[InteractionRegressions/README.md](InteractionRegressions/README.md).
