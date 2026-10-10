# Zeichnen, Aktualisierung und kompakte Übersichten

## Automatisierte Logiktests

```sh
Tests/run-regressions.sh
```

Benötigt einen Swift-Compiler, aber kein UIKit/iOS-SDK. Das Skript kompiliert die
**tatsächlich verwendeten** App-Dateien zusammen mit den Tests. Es prüft zuerst
die vorhandenen Tastatur-Layout-Tests, dann:

- Radius samt Messunsicherheit, Dauer und Bewegung bewusster Tipps;
- Schutz während des Zeichnens und in der kurzen Absetzphase, ohne eine dauerhaft
  klemmende `Began`/`Ended`-Sperre;
- die strikte Grenze **über 60 Minuten**, reguläres Fünf-Minuten-Intervall und
  höchstens einen dringenden Wiederholungsversuch alle 30 Sekunden;
- drei Notizenspalten auf normalen iPad-Breiten, zwei/eine in schmalen Fenstern;
- Größe und Abstände aller acht Palettenbuttons sowie den dickeren, näheren
  Squeeze-Hintergrundbogen, Randbegrenzung/Skalierung einschließlich des
  Farbbogens für verschiedene Stiftrichtungen und Fenster;
- die Scrubber-Mathematik: feste Stufen beim Halten, fester Winkel je Schritt
  (18°), kürzerer Teilbogen bei wenigen Schritten, mehrere Umdrehungen bis zum
  letzten gespeicherten Schritt und die Wiederhol-Stufen des Balkens.

Mit `TYPE_CHECK_ONLY=1 ./Tests/run-regressions.sh` werden dieselben Dateien nur
übersetzt, ohne die Tests auszuführen – gedacht für einen Build-Check in CI
(`.github/workflows/build-check.yml`, Swift auf Linux). Damit fallen
Compilerfehler in diesen App-Dateien – etwa ein falscher Argumentname in
`InteractionPolicies` – schon im Pull Request auf und nicht erst beim Start der
App.

Die Tests ersetzen keinen iOS-Build und keine Hardware-Tests. Insbesondere
Touch-Typen, UIKit-Hit-Testing, Gesture-Cancellation und Liquid Glass müssen im
App-Package auf dem Gerät geprüft werden.

## Manuell auf dem iPad

### Rand-Tipp und Handballen

1. Eine Notiz öffnen. Nach der Öffnungsanimation links, rechts, oben und unten
   auf die abgedunkelte Fläche **kurz mit einem Finger tippen**. Sie schließt und
   speichert. Mit großen Fingern und optional Trackpad wiederholen.
2. Mehrere Pencil-Striche schreiben, Handballen auch neben dem Papier ablegen.
   Die Notiz bleibt offen – auch beim Abheben des Stifts und zwischen Strichen.
3. Handballen während eines Strichs aufsetzen, Stift abheben, Hand noch kurz
   liegen lassen und dann abheben: kein Schließen durch den alten Kontakt.
4. Zwei Finger verwenden, einen Finger ziehen oder länger als etwa eine halbe
   Sekunde aufliegen lassen: keine Schließgeste. Mit Pencil auf den Rand tippen:
   ebenfalls kein Schließen.
5. Nach Schreiben, Radieren, Lasso, Zwei-Finger-Verschieben, Kopfzeilen-Ziehen
   und Größenänderung kurz warten (rund 0,6 Sekunden), dann bewusst auf den Rand
   tippen: wieder schließbar. Abgebrochene Gesten dürfen den Rand nicht sperren.
6. Text-Werkzeug öffnen und auf der Custom-Tastatur tippen: Kein Tipp darf zur
   Hintergrundfläche durchfallen. Nach dem Schließen dürfen weder ein doppelter
   Speichervorgang noch eine nachträglich geöffnete Tastatur auftreten.

### Veralteter Stundenplan

1. Mit eingerichteten WebUntis-Daten im Debugger `lastSyncDate` auf 59:59, exakt
   60:00 und dann auf mehr als 60 Minuten vor jetzt setzen. Erst im letzten Fall
   steht **„Stundenplan veraltet“** in Rot statt der Minutenzahl – in beiden
   Header-Layouts und auch während eines laufenden Abrufs.
2. Bei veralteten Daten wird sofort ein Abruf angestoßen. Im Flugmodus bleibt die
   rote Warnung erhalten; Wiederholungen kommen nicht öfter als alle 30 Sekunden
   und erzeugen nicht jedes Mal einen Fehler-Toast. Erfolgszeitpunkt bleibt alt.
3. Netz wieder aktivieren: beim nächsten Versuch wird geladen, danach wieder
   die frische grüne Anzeige. Anschließend nicht alle 15/30 Sekunden neu laden.
4. App mit altem Cache aus dem Hintergrund holen: sofortige Prüfung, nicht erst
   fünf Minuten später. Offene Zeichenfläche/Einstellungen müssen erhalten bleiben.
5. Während des Abrufs mehrfach auf den Status tippen, parallel in eine Woche
   wechseln: keine doppelten Requests für dieselbe Woche. Manuelles Antippen des
   Status kann weiterhin einen neuen Versuch starten, sobald keiner läuft.
6. Ohne konfigurierte Zugangsdaten keine Request-Schleife; ohne bisherigen
   Erfolgszeitpunkt keine erfundene „Gerade eben“-Anzeige.

### Rückgängig, „Seite leeren“ & Lasso

1. Zehn Striche schreiben, dann **fünfmal** Rückgängig tippen und sofort einen
   neuen Strich zeichnen: Die fünf sichtbaren Striche bleiben stehen, der neue
   kommt dazu – nichts verschwindet, und die Striche tauchen nicht wieder auf.
2. Nach dem Rückgängigmachen **Wiederholen** tippen: exakt die zuletzt
   rückgängig gemachten Striche kommen zurück, nicht mehr und nicht weniger.
   Mehrfach hin und her wechseln – die Anzeige darf nie Schritte zeigen, die es
   nicht gibt.
3. Rückgängig in der Werkzeugleiste **einen Schritt** tippen und danach erneut
   Rückgängig halten: Die Historie hat genau die Schritte, die man selbst
   gemacht hat. Zweimal Rückgängig hintereinander macht also zwei *eigene*
   Schritte rückgängig – niemals die Undo-Aktion selbst.
4. Im „…“-Menü **„Seite leeren“** wählen: Der Zettel ist leer, und **Rückgängig
   bringt nichts zurück** – auch nicht nach dem Schließen und erneuten Öffnen
   der Notiz.
5. Frisch geöffnete (oder komplett leer geräumte) Notiz: **Rückgängig** und
   **Wiederholen** in der Werkzeugleiste sind **sehr transparent und ohne
   Wirkung** – ein Tippen und ein Halten (Scrubber) dürfen nichts auslösen.
   Nach dem ersten Strich bzw. nach einmal Rückgängig werden sie wieder normal
   und bedienbar. Dasselbe für den Rückgängig-Knopf der **Squeeze-Palette**
   (Kreis) prüfen.
6. **Gerade Linie**: Einen schrägen Strich zeichnen und am Ende still halten,
   bis er einrastet. Danach **einmal** Rückgängig: Die **schräge** Linie steht
   wieder da (nicht die gerade). Ein **zweites** Rückgängig entfernt den Strich
   vollständig; **zweimal Wiederholen** baut beide Schritte wieder auf. Auch
   über den gehaltenen Rückgängig-Knopf (Balken) und den Kreis-Scrubber
   prüfen – keine Geisterstriche, keine geraden Linien an der Stelle der
   schrägen.
7. **Lasso**: Mehrere Striche schreiben, Lasso wählen und einen oder mehrere
   Striche verschieben (auch schnell, mehrfach hin und her, mit Pausen). Der
   Inhalt darf **nie verschwinden** – weder während des Ziehens noch danach.
   **Einmal Rückgängig**: Die Striche liegen wieder an der alten Stelle. Eine
   weitere Verschiebung ist ein eigener Schritt (Werkzeugwechsel oder
   Schließen/Öffnen dazwischen ändert daran nichts).
8. Rückgängig per **Doppeltipp** des Apple Pencil und per **Squeeze-Palette**
   testen: Beide nutzen dieselbe Historie wie der Toolbar-Knopf.

### Nur Notizen

1. Notizen für mehrere Tage erstellen, mindestens vier vergangene und vier
   kommende. Bei voller iPad-Breite (hoch/quer) sind **drei** Karten pro Zeile zu
   sehen, mit kompakter Kopfzeile und kleinerer, vollständig sichtbarer Vorschau.
2. Die **Jetzt-Linie läuft von links bis rechts über die Ansichtsbreite**, nicht
   nur durch eine Zelle. Bei 1, 2, 4 oder 5 vergangenen Karten endet erst deren
   Raster; kommende Karten beginnen unter der Linie wieder ganz links.
3. Nur vergangene / nur kommende Notizen: Linie genau einmal am Ende / Anfang.
   Einspaltig bleiben Tagesüberschriften sichtbar; mehrspaltig stehen die Daten
   in den Karten, ohne unnötige leere Zeilen pro Tag.
4. Split View verkleinern: unter 712 pt zwei Spalten, unter 480 pt eine. Rotation,
   chronologische Reihenfolge, Öffnen und Kontextmenü weiterhin prüfen.
5. Mit einer langen Liste (mindestens 100 Karten) mehrfach über die Übergänge
   zwischen Karten-Batches scrollen und währenddessen Karten öffnen. Reihenfolge,
   Zeilenabstände und Jetzt-Linie bleiben korrekt; Scrollen und Öffnen dürfen
   keine sichtbaren Hänger verursachen. Änderungen an Fach-/Lehrkraftnamen und
   Anzeigeoptionen müssen weiterhin direkt in den Karten erscheinen.

### Custom-Tastatur

1. In Hell und Dunkel jeweils Buchstaben, Leerzeichen, Shift (auch aktiviert und
   Caps Lock), Löschen, `123`, `#+=`, Emoji, Eingabe, Cursor- und Ausblenden-Taste
   drücken. **Beim Aufsetzen** wird die Taste deutlich dunkler und beim Loslassen
   wieder normal, unabhängig vom Klang/Haptik-Schalter.
2. Kurze schnelle Tipps, Löschen halten, Akzent-Popup und Ebenenwechsel prüfen:
   keine doppelten Zeichen, Popup unverändert, Löschen stoppt beim Loslassen.
3. Während einer gehaltenen Taste App unterbrechen oder Tastatur schließen:
   weder dauerhaft dunkle Taste noch weiterlaufendes Löschen nach Rückkehr.

### Pencil-Pro-Squeeze

1. An verschiedenen Stellen hovern, auch Hover beenden und erst dann squeezen:
   kompakter, dicker Bogen nahe der **letzten aktiven Hover-Position**, keine
   Sprünge zu einer leeren End-Pose. Alle acht runden Buttons sind 44 pt groß,
   solange das Fenster keine Skalierung erfordert; keine Überlappung.
2. Auf iPadOS 26 mit aktuellem SDK: natives interaktives Liquid Glass ähnlich dem
   systemeigenen Zurück-Button. Auf älteren Versionen: runder Material-Fallback
   mit Reflexen, Lichtkante und Druckreaktion. Beide Farbmodi prüfen.
3. Mit dem Pencil alle Werkzeuge, Undo, Farb-Hover/Farbauswahl und Dicken-Ziehen
   bedienen. Squeeze erneut bzw. weiterzeichnen: Palette verschwindet wie bisher.
   Nach jeder Auswahl müssen Werkzeug, Farbrahmen und Dicken-Vorschau der normalen
   Toolbar sofort denselben Zustand zeigen. Umgekehrt darf ein Farb-Slot der
   normalen Toolbar beim nächsten Squeeze nicht auf den ersten Standard-Slot
   zurückspringen. Bei ausgewähltem Textfeld färben beide Paletten dieses Feld,
   statt unbemerkt zum Stift zu wechseln.
4. Mit dem Finger auf Papier, Kopfzeile, Toolbar, Textfeld oder Tastatur tippen:
   Palette wird geschlossen, eigentliche Bedienung bleibt möglich. Finger auf
   einen Palettenbutton: Aktion wird noch ausgeführt, anschließend schließen.
5. Bei sichtbarer Palette einmal auf den abgedunkelten Hintergrund tippen:
   **nur Palette** schließen, Notiz behalten. Erst ein weiterer bewusster Tipp
   schließt und speichert die Notiz. Pencil-Tipp auf ein Werkzeug darf die
   Palette dagegen nicht wie ein Fingertipp ausblenden.
6. In jeder Ecke und im schmalen Fenster öffnen; auch aufgeklappte Farben bleiben
   erreichbar. Nach mehrfachem Öffnen/Schließen keine übrig gebliebenen Observer
   oder unsichtbaren Vollbild-Trefferflächen über Papier/Toolbar.

### Bilder & Textfelder: Auswahl, Griffe und Zoom

1. Notiz öffnen, Text-Werkzeug wählen, ein Bild einfügen. Es ist sofort
   ausgewählt. Verschieben (Mitte ziehen), an einer Ecke skalieren, über den
   roten Knopf löschen und über den blauen Knopf zuschneiden – auch dann, wenn
   das Bild am oberen, linken oder rechten Papierrand liegt und die Knöpfe über
   den Rand ragen.
2. Ein weiteres Bild einfügen und das erste antippen: Es wird ausgewählt, das
   zuvor gewählte verliert die Auswahl. Ein überlappendes Bild oder Textfeld
   liegt **unter** dem ausgewählten Element; die Griffe liegen immer vorn.
3. Bei ausgewähltem Bild ein Textfeld antippen (oder umgekehrt): Immer nur ein
   Element ist ausgewählt. Der Griff des ausgewählten Textfelds liegt vor einem
   darüberliegenden Bild.
4. Im Text-Werkzeug auf die leere Fläche tippen: neues Textfeld. Auf die leere
   Fläche tippen, während etwas ausgewählt ist: nur Auswahl aufheben (kein neues
   Feld, kein Bild wandert).
5. Im Zeichen-Modus mit Apple Pencil über ein ausgewähltes Bild und durch seine
   Halo-Zone zeichnen: Striche entstehen dort, wo keine Griffe oder Knöpfe liegen.
6. Zwei-Finger-Pinch auf die Notiz mehrmals hin- und herzoomen: Schrift und
   Striche bleiben scharf (keine Pixelung). Zeichnung, Text und Bilder bleiben
   beim Zoomen deckungsgleich, auch bei kleinem Zoom (Herauszoomen).
7. Notiz schließen: Der Rückflug in den Stundenblock läuft in einem Zug zu Ende.
   Die Notiz verschwindet erst am Ziel, ohne Sprung oder abgeschnittene Bewegung.
   Danach zeigt der Block die aktuelle Vorschau.
