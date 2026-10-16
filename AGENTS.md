# Hinweise für automatisch arbeitende Assistenten (Arena, Copilot, …)

Diese Datei ist kurz und praktisch: Sie beschreibt, wie Änderungen in diesem
Repository ankommen. Ausführlich: [`CONTRIBUTING.md`](CONTRIBUTING.md).

## Grundregeln

1. **Branches:** `arena/<session-id>-planapp` (oder `ai/*`, `agent/*`). Immer
   nur auf den eigenen Branch pushen – niemals direkt auf `main`.
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

## Wenn die Prüfung rot ist

1. `gh run list --branch <branch>` und `gh run view <id> --log-failed` lesen.
2. Fehler beheben, erneut pushen – der laufende PR wird automatisch
   weiterverfolgt.
3. Erst wenn alles grün ist, landet der Stand in `main`; danach baut Actions
   automatisch ein neues `PlanApp.ipa`.

## Nützliche Befehle

```sh
gh run list --limit 10                     # letzte Läufe
gh pr list --state open                    # offene Pull Requests
gh pr view <nr> --json statusCheckRollup   # Prüfungsstand
```

`/automerge` als Kommentar im Pull Request erzwingt einen Merge ohne Warten
(nur Owner/Member/Collaborator). Das Label `no-automerge` schaltet die
Automatik für einen PR bewusst ab.
