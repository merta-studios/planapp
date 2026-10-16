# Mitarbeiten – automatisch prüfen und mergen

Dieses Repository ist so eingerichtet, dass Änderungen **ohne manuellen Pull
Request und ohne Klick** nach `main` wandern und dabei automatisch geprüft
werden. Gedacht für die Zusammenarbeit mit KI-Sessions (Arena), aber genauso
nutzbar für eigene Branches.

## Ablauf einer Änderung

```
Push auf einen arena/*-Branch
        │
        ├─► Pull Request wird automatisch angelegt (…/auto-merge.yml)
        │
        ├─► Swift-Code-Prüfung startet (…/build-check.yml, Linux-Runner)
        │       1. Syntax      – jede .swift-Datei wird geparst
        │       2. Typ-Prüfung – UIKit-freier Teil wird übersetzt
        │       3. Regression  – Tests/run-regressions.sh
        │
        ├─► sind alle Prüfungen grün:  Merge-Commit nach main
        │   (rot? Kommentar am PR mit dem Fehler, **kein** Merge)
        │
        └─► IPA-Build auf main startet automatisch
                → Artefakt „PlanApp-IPA“ im Tab Actions zum Sideloaden
```

Nach dem Merge bleibt der Branch bestehen – eine laufende KI-Session kann
weiter darauf pushen, und der nächste Push landet wieder automatisch in `main`.

## Die Swift-Prüfung (ohne Mac)

Der Mac fehlt zum Prüfen? Genau dafür gibt es
[`.github/workflows/build-check.yml`](.github/workflows/build-check.yml). Sie
läuft auf **Linux-Runnern** in einem offiziellen Swift-Container
(`swift:6.2-noble`, überschreibbar per Repo-Variable `SWIFT_IMAGE`) und
kostet nur 1×-Aktionsminuten statt 10× wie der macOS-Build.

| Job | Was er prüft | Blockiert den Merge? |
| --- | --- | --- |
| `Syntax (alle Swift-Dateien)` | Jede der ~96 Dateien wird geparst – funktioniert auch für `import UIKit/SwiftUI/PencilKit`, weil beim Parsen keine Module aufgelöst werden | **Ja** |
| `Regressionstests (ohne iOS-SDK)` | `Tests/run-regressions.sh` – Tipp-, Layout-, Undo- und Palettenlogik | **Ja** |
| `Typ-Prüfung (Linux-taugliche Dateien)` | Alle Dateien ohne iOS-only-Import werden wirklich übersetzt (echte Typfehler wie „Cannot call value of non-function type“) | erst nach Umstellung, siehe unten |

Fehler erscheinen als Annotation direkt an der betroffenen Zeile im Pull
Request („Files changed“), zusätzlich mit Zeilennummer im Schritt-Log.

### Lokal prüfen

```sh
ci/run-swift.sh ci/swift-check.sh all      # Syntax + Typ-Prüfung
ci/run-swift.sh Tests/run-regressions.sh   # nur die Logik-Tests
ci/run-swift.sh swift --version            # nur die Toolchain anzeigen
```

Mit Docker wird das offizielle Swift-Image benutzt; ohne Docker (oder mit
`SWIFT_IMAGE=local`) läuft der Befehl direkt, dann muss Swift lokal installiert
sein. `SWIFTC=/pfad/zu/swiftc` wählt einen anderen Compiler.

### Typ-Prüfung scharf stellen

Die Typ-Prüfung darf unter Linux nicht jede Meldung ernst nehmen: Referenzen auf
`UIColor`, `UIImage`, `PKDrawing` & Co. fehlen ohne iOS-SDK und sind deshalb
kein Fehler. Das Skript überspringt solche Dateien automatisch und zählt die
restlichen „iOS-only“-Meldungen separat. Damit ein echter Typfehler den Merge
blockiert, wird die Repo-Variable

```
SWIFT_TYPECHECK_BLOCKING = true
```

gesetzt (GitHub → *Settings → Secrets and variables → Actions → Variables*).
Ohne die Variable bleibt der Job ein sichtbarer Hinweis.

### Grenzen

Der Linux-Check **ersetzt keinen iOS-Build**: UIKit-Hit-Testing, Liquid Glass,
Apple-Pencil-Hardware, Gesten-Abbruch und die Darstellung auf dem iPad lassen
sich dort nicht prüfen. Solche Änderungen weiterhin im Simulator/auf dem Gerät
testen – siehe [`Tests/InteractionRegressions/README.md`](Tests/InteractionRegressions/README.md).
Der macOS-Build (`Build IPA (Sideload)`) ist die zweite Absicherung und läuft
nach jedem Merge auf `main`.

## Auto-Merge

[`.github/workflows/auto-merge.yml`](.github/workflows/auto-merge.yml) ruft
[`ci/auto-merge.sh`](ci/auto-merge.sh) auf. Der Workflow reagiert auf:

| Auslöser | Verhalten |
| --- | --- |
| Push auf `arena/*`, `ai/*`, `agent/*` | Pull Request anlegen (falls keiner da ist) und nach grünen Prüfungen mergen |
| Pull Request geöffnet/aktualisiert/labeled | Prüfungen abwarten, dann mergen |
| Prüfung fertig (`workflow_run`) | erneut auswerten – falls die Prüfung der letzte offene Punkt war |
| Kommentar `/automerge` (nur Owner/Member/Collaborator) | sofort mergen, **ohne** auf Prüfungen zu warten |
| Manuell (*Run workflow*, mit PR-Nummer oder Branch) | derselbe Ablauf zum Nachschauen |

**Welche Pull Requests werden automatisch gemergt?**

* Branches `arena/*`, `ai/*`, `agent/*` (siehe `AUTOMERGE_BRANCHES`), oder
* jeder Pull Request mit dem Label **`automerge`**.

Bewusst **nicht** gemergt werden: Entwürfe (Drafts), Pull Requests mit dem Label
**`no-automerge`**, andere Zielbranches als `main`, Pull Requests mit Konflikten
(`DIRTY`) und alles, was andere Prüfungen als `main` verlangt.

**Bei roten Prüfungen** passiert nichts Gefährliches: Der PR bekommt einen
Kommentar mit den fehlgeschlagenen Prüfungen, der Job wird rot und `main` bleibt
unberührt. Nach dem nächsten Fix-Push läuft alles wieder automatisch.

**Merge-Art:** Merge-Commit (wie bisher). Das ist Absicht – nur so bleiben
mehrere PRs nacheinander von demselben Branch sauber und ohne Altlasten
darstellbar. Der Branch wird **nicht** gelöscht, damit die KI-Session weiter
pushen kann.

### Nach dem Merge

Wird mit dem normalen `GITHUB_TOKEN` gemergt, löst das – eine Eigenheit von
GitHub – selbst keine Workflows aus. Deshalb startet das Skript in diesem Fall
explizit **zwei** Läufe auf `main`: die Swift-Code-Prüfung (`build-check.yml`)
und den IPA-Build (`build-ipa.yml`). Ohne den ersten bliebe `main` ungeprüft –
die Prüfungen im Pull Request gelten für den Branch, und der macOS-Build
übersetzt danach nur. Mit einem eigenen Token (`AUTOMERGE_TOKEN`) läuft alles
über die normalen Push-Events.

## Optionale Einrichtung (empfohlen)

| Was | Wo | Warum |
| --- | --- | --- |
| ✅ „Allow GitHub Actions to create and approve pull requests“ | Settings → Actions → General → Workflow permissions | Damit der Workflow selbst den PR anlegen darf. Ohne diese Option legt die Arena-Session den PR an – der Merge passiert trotzdem automatisch. |
| 🔑 Secret `AUTOMERGE_TOKEN` (PAT mit `contents:write`, `pull-requests:write`, `actions:write`) | Settings → Secrets and variables → Actions | Falls der Branch-Schutz eine Review verlangt oder kein PR per Workflow angelegt werden darf. |
| 🧪 Variable `SWIFT_TYPECHECK_BLOCKING=true` | Settings → … → Variables | Typ-Prüfung wird zum Merge-Kriterium. |
| 🐳 Variable `SWIFT_IMAGE` (z. B. `swift:6.3-noble`) | Settings → … → Variables | Neuere Swift-Version oder schnelleres Image. |
| 🚫 Variable `AUTOMERGE_BRANCHES` (z. B. `arena/*`) | Settings → … → Variables | Nur Arena-Branches automatisch mergen. |
| 🔔 Variable `AUTOMERGE_DISPATCH_BUILD=0` | Settings → … → Variables | Keinen IPA-Build nach dem Merge starten (spart macOS-Minuten). |
| 🔍 Variable `AUTOMERGE_DISPATCH_CHECK=0` | Settings → … → Variables | Keine Swift-Prüfung nach dem Merge auf `main` starten (spart Linux-Minuten). |

Alle Schalter, die `ci/auto-merge.sh` kennt, stehen im Kopf der Datei.

## Wenn mal etwas klemmt

| Symptom | Ursache / Lösung |
| --- | --- |
| PR wird nicht automatisch gemergt, Job ist rot mit „Rote Prüfung(en)“ | Der Code ist fehlerhaft – Log öffnen, Fehler beheben, erneut pushen. Kein Handgriff nötig. |
| **Jobs starten gar nicht**: Lauf ist nach Sekunden rot, alle Jobs haben 0 Schritte, als Annotation steht „The job was not started because recent account payments have failed or your spending limit needs to be increased“ | Das ist kein Codefehler: GitHub blockiert die **Actions-Minuten des Accounts** (privates Repo). Unter <https://github.com/settings/billing> → *Billing & plans* Zahlungsart/Spending Limit prüfen. Betrifft **alle** GitHub-Runner – auch den IPA-Build. Übergangsweise direkt mergen: `gh pr merge <nr> --merge` (die Arena-Session macht das auf Wunsch auch selbst). |
| „Nach 900s ist keine einzige Prüfung aufgetaucht“ | Wie oben (Actions blockiert), oder `.github/workflows/build-check.yml` fehlt im Branch. |
| „Konflikt mit main“ | Der Branch ist veraltet. In der Arena-Session neu aufsetzen lassen (Rebase) – dann wieder automatisch. |
| „Branch-Schutz verhindert den Merge“ | Review-Pflicht aktiv: Entweder die Regel unter Settings → Branches lockern oder `AUTOMERGE_TOKEN` hinterlegen. |
| „Pull Request konnte nicht angelegt werden“ | PR einmal selbst anlegen (oder die Workflow-Permissions-Option oben aktivieren) – der Rest bleibt automatisch. |
| Build läuft doppelt | Beide Trigger (Push auf `main` und Auto-Merge) haben den Build gestartet; bei `AUTOMERGE_TOKEN` passiert das nicht. |
| Prüfung scheint „hängen“ zu bleiben | Der Auto-Merge wartet bewusst bis zu 45 Minuten (Variable `AUTOMERGE_TIMEOUT`). Abbrechen kann man ihn über *Actions → Lauf → Cancel*. |

## Für KI-Sessions (Arena, Copilot, …)

* Branches heißen `arena/<session>-planapp`; Push dorthin genügt.
* **Keinen** Pull Request von Hand anlegen – das übernimmt
  `.github/workflows/auto-merge.yml`. Ausnahme: Wenn die Meldung „Pull Request
  konnte nicht angelegt werden“ erscheint, einmal `gh pr create --base main`
  ausführen.
* **Nie** direkt auf `main` pushen und **nicht** den eigenen Branch löschen –
  die Session pusht dort weiter.
* Vor dem Push lokal prüfen: `ci/run-swift.sh ci/swift-check.sh all` und
  `ci/run-swift.sh Tests/run-regressions.sh`.
* Passende Kurzfassung für Agenten: [`AGENTS.md`](AGENTS.md).
