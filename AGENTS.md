# Hinweise für automatisch arbeitende Assistenten (Arena, Copilot, …)

Diese Datei ist kurz und praktisch: Sie beschreibt, wie Änderungen in diesem
Repository ankommen. Ausführlich: [`CONTRIBUTING.md`](CONTRIBUTING.md).

## Grundregeln

1. **Branches:** `arena/<session-id>-planapp` (oder `ai/*`, `agent/*`) ist der
   Standardweg – nur auf den eigenen Branch pushen.
   **Ausnahme:** Gibt der Mensch der Session den Repo-Zugriff ausdrücklich
   frei, darf direkt auf `main` gepusht werden (siehe „Direkt auf `main`
   arbeiten“ weiter unten). `main` dabei nie umschreiben: kein Force-Push,
   kein Rebase von `main`.
2. **Kein manueller Pull Request nötig.** Ein Push auf `arena/*` legt den PR
   automatisch an und mergt ihn nach grünen Prüfungen in `main`
   (`.github/workflows/auto-merge.yml` → `ci/auto-merge.sh`).
3. **Branch nicht löschen und `main` nicht umschreiben** – die laufende Session
   arbeitet auf dem Branch weiter.
4. Kein `--admin`, kein Force-Merge über rote Prüfungen. Wenn eine Prüfung rot
   ist: Ursache im Log beheben und erneut pushen.

## Prüfungen, die den Merge blockieren

| Workflow / Job | Inhalt | Blockiert |
| --- | --- | --- |
| `Swift-Code-Prüfung` → `Syntax (alle Swift-Dateien)` | `swiftc -frontend -parse` über alle `.swift`-Dateien (auch UIKit/SwiftUI/PencilKit) | ja |
| `Swift-Code-Prüfung` → `Regressionstests (ohne iOS-SDK)` | `Tests/run-regressions.sh` | ja |
| `Swift-Code-Prüfung` → `Typ-Prüfung (Linux-taugliche Dateien)` | echte Typprüfung der Dateien ohne iOS-only-Import | nur mit Repo-Variable `SWIFT_TYPECHECK_BLOCKING=true` |
| `Build IPA (Sideload)` | macOS-Build (läuft auf `main`, nicht auf PRs) | nein |

## Vor jedem Push lokal prüfen

```sh
ci/run-swift.sh ci/swift-check.sh all      # Syntax + Typ-Prüfung im Swift-Container
ci/run-swift.sh Tests/run-regressions.sh   # Logik-Tests
```

Beide Befehle brauchen Docker (oder lokal installiertes Swift,
`SWIFT_IMAGE=local`). Beim Push passiert genau dasselbe auf dem Linux-Runner –
was hier grün ist, ist dort auch grün.

Fehlt in der Sandbox beides (kein Docker, keine Swift-Toolchain), ist GitHub
Actions die Prüfinstanz – siehe den nächsten Abschnitt.

## Direkt auf `main` arbeiten (nur mit ausdrücklicher Freigabe)

Gibt der Mensch der Session den Repo-Zugriff frei, geht es auch ohne Pull
Request:

```sh
git push origin HEAD:main     # Fast-Forward, niemals --force
gh run list --limit 5         # Swift-Code-Prüfung + Build IPA starten von selbst
```

Ein Push auf `main` löst `build-check.yml` **und** `build-ipa.yml` aus (beide
haben `push: [main]`) – genau die beiden Prüfungen, die lokal fehlen. Der
Auto-Merge bleibt dabei außen vor, weil er nur auf `arena/**`, `ai/**`,
`agent/**` reagiert.

**Prüfschleife – so lange wiederholen, bis alles grün ist:**

1. `gh run watch <id>` (oder `gh run list --limit 5`): warten, bis beide
   Workflows abgeschlossen sind.
2. Rot? Job-Schritte und Check-Run-Annotationen lesen (Befehle unten), Ursache
   im Code beheben, erneut pushen. Jeder Push prüft wieder alles.
3. Fertig ist der Stand erst, wenn **beide** Läufe grün sind:
   `Swift-Code-Prüfung` *und* `Build IPA (Sideload)`.

Keinen roten Lauf stehen lassen, nichts forcieren, kein `--admin`.

## Wenn GitHub Actions gerade keine Jobs startet

Symptom: Der Lauf ist nach wenigen Sekunden rot, **jeder** Job hat 0 Schritte und die
Annotation lautet „The job was not started because recent account payments have failed or your
spending limit needs to be increased“ – GitHub drosselt den Account (Aktionsminuten /
Abrechnung, privates Repo). Dann startet auch der IPA-Build nicht.

Prüfen mit:

```sh
gh api repos/<owner>/<repo>/actions/runs/<id>/jobs --jq '.jobs[] | [.name, (.steps|length)] | @tsv'
gh api repos/<owner>/<repo>/check-runs/<job-check-run-id>/annotations --jq '.[].message'
```

In diesem Fall **nicht** endlos warten: den Pull Request direkt mergen
(`gh pr merge <nr> --merge --repo <owner>/<repo>`) und dem Menschen im Ergebnis sagen, dass
das Actions-Kontingent bzw. die Abrechnung unter <https://github.com/settings/billing> geprüft
werden muss. Der Workflow `Auto-Merge → main` wartet sonst bis zu 15 Minuten auf Prüfungen,
die nie starten.

## Wenn die Prüfung rot ist

1. `gh run list --branch <branch>` und `gh run view <id> --log-failed` lesen.
2. Fehler beheben, erneut pushen – der laufende PR wird automatisch
   weiterverfolgt.
3. Erst wenn alles grün ist, landet der Stand in `main`; danach baut Actions
   automatisch ein neues `PlanApp.ipa`.

## Nützliche Befehle

```sh
gh run list --limit 10                     # letzte Läufe
gh run watch <id>                          # Lauf live verfolgen
gh pr list --state open                    # offene Pull Requests
gh pr view <nr> --json statusCheckRollup   # Prüfungsstand
```

`/automerge` als Kommentar im Pull Request erzwingt einen Merge ohne Warten
(nur Owner/Member/Collaborator). Das Label `no-automerge` schaltet die
Automatik für einen PR bewusst ab.
