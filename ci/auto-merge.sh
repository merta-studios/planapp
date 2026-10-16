#!/usr/bin/env bash
#
# ci/auto-merge.sh – merged automatisch in main, ohne dass jemand klicken muss.
#
# Gedacht für Änderungen von Arena/KI-Sessions (Branches "arena/*") und für
# Pull Requests mit dem Opt-in-Label "automerge". Der Ablauf:
#
#   1. Pull Request auflösen (Nummer, Branch oder – bei einem Push auf einen
#      arena-Branch – automatisch anlegen).
#   2. Auf alle Prüfungen warten (Syntax-/Typ-Prüfung, Regressionstests, IPA-Build).
#   3. Bei grünen Prüfungen mit einem Merge-Commit nach main mergen.
#   4. IPA-Build auf main anstoßen, falls nötig.
#
# Aufruf (siehe .github/workflows/auto-merge.yml):
#   ci/auto-merge.sh --pr 123
#   ci/auto-merge.sh --branch arena/abc-planapp [--create]
#   ci/auto-merge.sh --pr 123 --force        # Checks ignorieren (/automerge-Kommentar)
#
# Umgebungsvariablen:
#   GH_TOKEN                  Token mit pull-requests:write, contents:write, actions:write
#   REPO                      owner/name (Standard: aktuelles Repo via gh)
#   AUTOMERGE_LABEL           Opt-in-Label für andere Branches (Standard: automerge)
#   AUTOMERGE_BRANCHES        erlaubte Head-Branches, kommagetrennt (Standard: arena/*,ai/*,agent/*)
#   AUTOMERGE_TIMEOUT         Sekunden warten auf Prüfungen (Standard: 2700)
#   AUTOMERGE_POLL            Sekunden zwischen zwei Abfragen (Standard: 20)
#   AUTOMERGE_CHECK_GRACE     Wartezeit, bis überhaupt Prüfungen auftauchen (Standard: 90)
#   AUTOMERGE_NO_CHECK_TIMEOUT  Abbruch, wenn gar keine Prüfung startet (Standard: 900)
#   AUTOMERGE_FORCE           1 = Prüfungen ignorieren
#   AUTOMERGE_CREATE_PR       1 = Pull Request anlegen, wenn keiner existiert
#   AUTOMERGE_ADVISORY_CHECKS Prüfungen, deren Fehler nur gewarnt wird (kommagetrennt)
#   AUTOMERGE_SKIP_CHECKS     Prüfungen, die ignoriert werden (kommagetrennt)
#   AUTOMERGE_SELF_NAME       eigener Jobname, wird nicht als Prüfung gezählt
#   AUTOMERGE_DISPATCH_BUILD  1 = nach dem Merge den IPA-Build anstoßen
#   AUTOMERGE_DRY_RUN         1 = nur anzeigen, nichts mergen/anlegen
#
# Rückgabewert: 0 = gemergt oder nichts zu tun, 1 = nicht gemergt (Grund im Log).

set -uo pipefail

cd "$(dirname "$0")/.."

PR=""
BRANCH=""
FORCE="${AUTOMERGE_FORCE:-0}"
CREATE="${AUTOMERGE_CREATE_PR:-0}"
DRY_RUN="${AUTOMERGE_DRY_RUN:-0}"
LABEL="${AUTOMERGE_LABEL:-automerge}"
BRANCHES="${AUTOMERGE_BRANCHES:-arena/*,ai/*,agent/*}"
TIMEOUT="${AUTOMERGE_TIMEOUT:-2700}"
POLL="${AUTOMERGE_POLL:-20}"
GRACE="${AUTOMERGE_CHECK_GRACE:-90}"
NO_CHECK_TIMEOUT="${AUTOMERGE_NO_CHECK_TIMEOUT:-900}"
ADVISORY="${AUTOMERGE_ADVISORY_CHECKS:-}"
SKIP="${AUTOMERGE_SKIP_CHECKS:-}"
SELF_NAME="${AUTOMERGE_SELF_NAME:-Auto-Merge}"
DISPATCH_BUILD="${AUTOMERGE_DISPATCH_BUILD:-0}"
CHECK_WORKFLOW="${AUTOMERGE_CHECK_WORKFLOW:-build-check.yml}"
BUILD_WORKFLOW="${AUTOMERGE_BUILD_WORKFLOW:-build-ipa.yml}"

while [ "$#" -gt 0 ]; do
    case "$1" in
        --pr) PR="${2:-}"; shift 2 ;;
        --branch) BRANCH="${2:-}"; shift 2 ;;
        --create) CREATE=1; shift ;;
        --force) FORCE=1; shift ;;
        --timeout) TIMEOUT="${2:-}"; shift 2 ;;
        -h|--help)
            sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *) echo "Unbekanntes Argument: $1" >&2; exit 2 ;;
    esac
done

log() { printf '\033[1m%s\033[0m\n' "$*"; }
note() { printf '  \033[34mi\033[0m %s\n' "$*"; }
ok() { printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*"; }
err() { printf '  \033[31m✗\033[0m %s\n' "$*"; }

gh_quiet() { gh "$@" 2>/dev/null; }

# Ein Name kommt als kommagetrennte Liste vor?
list_contains() { # list_contains <liste> <name>
    local list="$1" needle="$2" item
    [ -n "$list" ] || return 1
    IFS=',' read -r -a _items <<< "$list"
    for item in "${_items[@]}"; do
        item="${item#"${item%%[![:space:]]*}"}"
        item="${item%"${item##*[![:space:]]}"}"
        [ -n "$item" ] || continue
        [ "$item" = "$needle" ] && return 0
    done
    return 1
}

branch_allowed() { # branch_allowed <branch>
    local b="$1" pattern
    IFS=',' read -r -a _patterns <<< "$BRANCHES"
    for pattern in "${_patterns[@]}"; do
        pattern="${pattern// /}"
        [ -n "$pattern" ] || continue
        # shellcheck disable=SC2254 # Muster soll als Muster wirken
        case "$b" in $pattern) return 0 ;; esac
    done
    return 1
}

# ------------------------------------------------------------ Repo & PR finden

if [ -z "${REPO:-}" ]; then
    REPO="$(gh_quiet repo view --json nameWithOwner --jq .nameWithOwner)"
fi
if [ -z "$REPO" ]; then
    err "Repository unbekannt. REPO=owner/name setzen oder mit gh angemeldet sein."
    exit 1
fi

BASE_BRANCH="$(gh_quiet repo view "$REPO" --json defaultBranchRef --jq .defaultBranchRef.name)"
BASE_BRANCH="${BASE_BRANCH:-main}"

log "Auto-Merge für $REPO (Zielbranch: $BASE_BRANCH)"

if [ -n "$PR" ]; then
    note "Pull Request #$PR vorgegeben."
elif [ -n "$BRANCH" ]; then
    PR="$(gh_quiet pr list --repo "$REPO" --state open --head "$BRANCH" --json number --jq '.[0].number')"
    if [ -n "$PR" ]; then
        note "Offener Pull Request für $BRANCH: #$PR"
    elif [ "$CREATE" = "1" ]; then
        if [ "$DRY_RUN" = "1" ]; then
            note "[Dry-Run] würde einen Pull Request für $BRANCH anlegen."
            exit 0
        fi
        subject="$(gh_quiet api "repos/$REPO/commits/$BRANCH" --jq '.commit.message | split("\n")[0]')"
        subject="${subject:-Änderungen von $BRANCH}"
        subject="${subject:0:120}"
        body="$(gh_quiet api "repos/$REPO/compare/$BASE_BRANCH...$BRANCH" \
            --jq '[.commits[].commit.message | split("\n")[0]] | map("- " + .) | join("\n")')"
        body="${body:-Automatisch angelegter Pull Request.}
---
🤖 Dieser Pull Request wurde automatisch von \`.github/workflows/auto-merge.yml\` angelegt und wird nach grünen Prüfungen automatisch nach \`$BASE_BRANCH\` gemergt."
        if ! create_out=$(gh pr create --repo "$REPO" --base "$BASE_BRANCH" --head "$BRANCH" \
                --title "$subject" --body "$body" 2>&1); then
            if grep -qi "already exists" <<< "$create_out"; then
                PR="$(gh_quiet pr list --repo "$REPO" --state open --head "$BRANCH" --json number --jq '.[0].number')"
                note "Pull Request existierte bereits: #$PR"
            elif grep -qiE "no commits between|nothing to compare" <<< "$create_out"; then
                note "Kein Unterschied zu $BASE_BRANCH – es gibt nichts zu mergen."
                exit 0
            else
                err "Pull Request konnte nicht angelegt werden:"
                printf '%s\n' "$create_out"
                if grep -qiE "not permitted|resource not accessible|createPullRequest" <<< "$create_out"; then
                    warn "Dafür muss in den Repo-Einstellungen unter „Actions → General → Workflow permissions“"
                    warn "„Allow GitHub Actions to create and approve pull requests“ aktiviert sein,"
                    warn "oder das Secret AUTOMERGE_TOKEN (PAT mit pull-requests:write) hinterlegt werden."
                    warn "Alternativ legt die Arena-Session selbst einen Pull Request an."
                fi
                exit 1
            fi
        else
            PR="$(grep -oE '/pull/[0-9]+' <<< "$create_out" | head -n 1 | tr -d -c '0-9')"
            ok "Pull Request #${PR:-?} angelegt."
        fi
    else
        note "Kein offener Pull Request für $BRANCH – nichts zu tun."
        exit 0
    fi
fi

if [ -z "$PR" ]; then
    note "Kein Pull Request zu bearbeiten."
    exit 0
fi

# ------------------------------------------------------------- PR-Zustand lesen

pr_field() { gh_quiet pr view "$PR" --repo "$REPO" --json "$1" --jq "$2"; }

STATE="$(pr_field state '.state')"
if [ -z "$STATE" ]; then
    err "Pull Request #$PR konnte nicht gelesen werden (Token-Rechte?)."
    exit 1
fi

HEAD_BRANCH="$(pr_field headRefName '.headRefName')"
HEAD_SHA="$(pr_field headRefOid '.headRefOid')"
IS_DRAFT="$(pr_field isDraft '.isDraft')"
TITLE="$(pr_field title '.title')"
URL="$(pr_field url '.url')"
PR_BASE="$(pr_field baseRefName '.baseRefName')"
LABELS="$(gh_quiet pr view "$PR" --repo "$REPO" --json labels --jq '[.labels[].name] | join(",")')"

log "Pull Request #$PR: $TITLE"
note "Branch: $HEAD_BRANCH → $PR_BASE   (Commit ${HEAD_SHA:0:8})"

case "$STATE" in
    MERGED) ok "Bereits gemergt – nichts zu tun."; exit 0 ;;
    CLOSED) note "Pull Request ist geschlossen (nicht gemergt) – nichts zu tun."; exit 0 ;;
esac

if [ "$PR_BASE" != "$BASE_BRANCH" ]; then
    note "Zielbranch ist $PR_BASE (nicht $BASE_BRANCH) – Auto-Merge ist nur für $BASE_BRANCH gedacht."
    exit 0
fi

if list_contains "$LABELS" "no-automerge"; then
    note "Label „no-automerge“ gesetzt – dieser Pull Request wird nicht automatisch gemergt."
    exit 0
fi

IS_OUR_BRANCH=0
branch_allowed "$HEAD_BRANCH" && IS_OUR_BRANCH=1
HAS_LABEL=0
list_contains "$LABELS" "$LABEL" && HAS_LABEL=1

if [ "$IS_OUR_BRANCH" -eq 0 ] && [ "$HAS_LABEL" -eq 0 ]; then
    note "Branch „$HEAD_BRANCH“ fällt nicht unter AUTOMERGE_BRANCHES ($BRANCHES) und das Label „$LABEL“ fehlt."
    note "Auto-Merge überspringt diesen Pull Request bewusst."
    exit 0
fi

if [ "$IS_DRAFT" = "true" ]; then
    note "Pull Request ist noch ein Entwurf – Auto-Merge wartet auf „Ready for review“."
    exit 0
fi

# ------------------------------------------------------------- Auf Checks warten

pending_checks() { # pending_checks <sha>  →  "id<TAB>status<TAB>name<TAB>conclusion"
    gh api --paginate "repos/$REPO/commits/$1/check-runs?per_page=100" \
        --jq '.check_runs[] | [(.id|tostring), .status, .name, (.conclusion // "pending")] | @tsv' 2>/dev/null
    gh api "repos/$REPO/commits/$1/status" \
        --jq '.statuses[] | ["", (if .state == "pending" then "in_progress" else "completed" end), .context, (if .state == "success" then "success" else "failure" end)] | @tsv' 2>/dev/null
    return 0
}

# Startet ein Job gar nicht (z. B. weil das Actions-Kontingent oder die
# Abrechnung des Accounts nicht in Ordnung ist), steht der Grund in den
# Annotationen der Prüfung. Das ist die einzige Stelle, an der GitHub das
# erklärt – deshalb wird sie hier mit ausgegeben.
explain_failures() {
    local id message
    for id in $CHECKS_FAILED_IDS; do
        while IFS= read -r message; do
            [ -n "$message" ] || continue
            warn "GitHub zu „$id“: $message"
            case "$message" in
                *"spending limit"*|*"payments have failed"*|*"Billing"*|*"not started because"*)
                    err "Die Actions-Jobs starten nicht! GitHub nennt das Kontingent bzw. die Abrechnung:"
                    err "https://github.com/settings/billing  („Billing & plans“) prüfen."
                    warn "Bis das geklärt ist, startet auch der IPA-Build nicht. Der Pull Request kann in"
                    warn "der Zwischenzeit direkt gemergt werden: gh pr merge $PR --merge --repo $REPO"
                    BILLING_PROBLEM=1
                    ;;
            esac
        done < <(gh api "repos/$REPO/check-runs/$id/annotations" \
                    --jq '.[].message' 2>/dev/null)
    done
}

check_state_for() { # check_state_for <sha> → setzt globale Zähler
    local sha="$1"
    CHECKS_PENDING=0
    CHECKS_PASSED=0
    CHECKS_FAILED=""
    CHECKS_FAILED_IDS=""
    CHECKS_ADVISORY=""
    CHECKS_SEEN=0

    local id status name conclusion
    while IFS=$'\t' read -r id status name conclusion; do
        [ -n "${name:-}" ] || continue
        case "$name" in *"$SELF_NAME"*) note "eigene Prüfung übersprungen: $name"; continue ;; esac
        list_contains "$SKIP" "$name" && { note "Prüfung übersprungen (AUTOMERGE_SKIP_CHECKS): $name"; continue; }
        CHECKS_SEEN=$((CHECKS_SEEN + 1))

        if list_contains "$ADVISORY" "$name"; then
            if [ "$status" = "completed" ] && [ "$conclusion" != "success" ] && [ "$conclusion" != "neutral" ] && [ "$conclusion" != "skipped" ]; then
                CHECKS_ADVISORY="$CHECKS_ADVISORY $name($conclusion)"
            fi
            continue
        fi

        case "$status" in
            completed)
                case "$conclusion" in
                    success|neutral|skipped) CHECKS_PASSED=$((CHECKS_PASSED + 1)) ;;
                    cancelled) CHECKS_PASSED=$((CHECKS_PASSED + 1)); note "Prüfung „$name“ wurde abgebrochen (gilt als neutral)." ;;
                    *)
                        CHECKS_FAILED="$CHECKS_FAILED $name($conclusion)"
                        [ -n "$id" ] && CHECKS_FAILED_IDS="$CHECKS_FAILED_IDS $id"
                        ;;
                esac
                ;;
            *) CHECKS_PENDING=$((CHECKS_PENDING + 1)) ;;
        esac
    done < <(pending_checks "$sha")
}

comment_once() { # comment_once <marker> <text>
    local marker="$1" text="$2"
    if gh_quiet pr view "$PR" --repo "$REPO" --json comments \
        --jq '[.comments[].body] | join("\n")' | grep -qF "$marker"; then
        return 0
    fi
    if [ "$DRY_RUN" = "1" ]; then
        note "[Dry-Run] Kommentar: $text"
        return 0
    fi
    gh pr comment "$PR" --repo "$REPO" --body "$text" >/dev/null
}

if [ "$FORCE" = "1" ]; then
    warn "AUTOMERGE_FORCE=1: Prüfungen werden nicht abgewartet (/automerge)."
else
    log "Warte auf die Prüfungen von ${HEAD_SHA:0:8} (max. ${TIMEOUT}s)"
    started=$SECONDS
    dispatched=0
    while :; do
        check_state_for "$HEAD_SHA"
        elapsed=$((SECONDS - started))

        if [ -n "$CHECKS_FAILED" ]; then
            err "Rote Prüfung(en):$CHECKS_FAILED"
            explain_failures
            comment_once "<!-- automerge-rot -->" "### 🤖 Auto-Merge: nicht gemergt

Die Prüfungen sind rot:$CHECKS_FAILED
$( [ "${BILLING_PROBLEM:-0}" = "1" ] && printf '\n**Achtung:** GitHub startet die Jobs nicht – laut Annotation ist das Actions-Kontingent bzw. die Abrechnung des Accounts das Problem (https://github.com/settings/billing). Solange das so ist, startet auch der IPA-Build nicht.\n' )

Details im Tab **Actions** – [Lauf öffnen]($URL/checks). Nach einem Fix wird automatisch erneut geprüft.

Erzwingen (ohne Prüfungen): Kommentar \`/automerge\`."
            exit 1
        fi

        if [ "$CHECKS_PENDING" -eq 0 ] && [ "$CHECKS_SEEN" -gt 0 ]; then
            ok "$CHECKS_PASSED Prüfung(en) grün."
            if [ -n "$CHECKS_ADVISORY" ]; then
                warn "Hinweis-Prüfungen mit Fehlern (nicht blockierend):$CHECKS_ADVISORY"
            fi
            break
        fi

        if [ "$CHECKS_SEEN" -eq 0 ] && [ "$elapsed" -ge "$GRACE" ] && [ "$dispatched" -eq 0 ]; then
            dispatched=1
            warn "Bisher keine Prüfung gefunden – starte „$CHECK_WORKFLOW“ für $HEAD_BRANCH neu."
            if gh_quiet workflow run "$CHECK_WORKFLOW" --repo "$REPO" --ref "$HEAD_BRANCH" >/dev/null; then
                ok "Prüf-Workflow angestoßen."
            else
                warn "Workflow konnte nicht gestartet werden (Rechte? Datei vorhanden?)."
                warn "Ein Pull Request, den die Arena-Session selbst anlegt, startet die Prüfungen automatisch."
            fi
        fi

        if [ "$elapsed" -ge "$TIMEOUT" ]; then
            err "Zeitüberschreitung: Prüfungen sind nach ${TIMEOUT}s nicht fertig geworden."
            comment_once "<!-- automerge-timeout -->" "### 🤖 Auto-Merge: Zeitüberschreitung

Nach ${TIMEOUT}s waren die Prüfungen noch nicht fertig – es wurde **nicht** gemergt. Der nächste Push startet einen neuen Versuch."
            exit 1
        fi

        # Es taucht überhaupt keine Prüfung auf: dann läuft die CI nicht
        # (Actions blockiert, Workflow fehlt, Kontingent aufgebraucht).
        # Nicht die volle Zeit absitzen, sondern klar melden.
        if [ "$CHECKS_SEEN" -eq 0 ] && [ "$elapsed" -ge "$NO_CHECK_TIMEOUT" ]; then
            err "Nach ${NO_CHECK_TIMEOUT}s ist keine einzige Prüfung aufgetaucht – es wurde nicht gemergt."
            warn "Meistens: Actions startet keine Jobs (Abrechnung/Kontingent: https://github.com/settings/billing),"
            warn "fehlender Workflow oder fehlende Rechte für $CHECK_WORKFLOW."
            warn "Direkt mergen (überspringt die Prüfungen): gh pr merge $PR --merge --repo $REPO"
            comment_once "<!-- automerge-keine-checks -->" "### 🤖 Auto-Merge: keine Prüfungen gefunden

Auf diesem Commit ist nach ${NO_CHECK_TIMEOUT}s keine Prüfung gestartet – deshalb wurde **nicht** gemergt. Häufigste Ursache: GitHub Actions startet keine Jobs (Abrechnung/Aktionskontingent, siehe *Billing & plans* im GitHub-Account) oder der Workflow „Swift-Code-Prüfung“ fehlt.

Ohne Prüfungen mergen: \`/automerge\` als Kommentar."
            exit 1
        fi

        sleep "$POLL"
    done
fi

# ------------------------------------------------------------------- Mergen

MERGEABLE="$(pr_field mergeable '.mergeable')"
MERGE_STATE="$(pr_field mergeStateStatus '.mergeStateStatus')"
if [ "$MERGE_STATE" = "DIRTY" ]; then
    err "Konflikt mit $BASE_BRANCH (mergeStateStatus=DIRTY) – es wurde nicht gemergt."
    warn "Der Branch muss neu auf $BASE_BRANCH aufgesetzt werden (Arena: Rebase/Fix anfordern)."
    exit 1
fi
if [ "$MERGE_STATE" = "BLOCKED" ] || [ "$MERGE_STATE" = "UNSTABLE" ]; then
    warn "GitHub meldet mergeStateStatus=$MERGE_STATE – es wird trotzdem ein Merge versucht."
fi

if [ "$DRY_RUN" = "1" ]; then
    note "[Dry-Run] würde #$PR mit Merge-Commit nach $BASE_BRANCH mergen."
    exit 0
fi

log "Merge #$PR nach $BASE_BRANCH"
if merge_out=$(gh pr merge "$PR" --repo "$REPO" --merge 2>&1); then
    ok "Gemergt."
else
    if grep -qiE "already merged|merged" <<< "$merge_out"; then
        ok "War bereits gemergt."
    else
        err "Merge fehlgeschlagen:"
        printf '%s\n' "$merge_out"
        if grep -qiE "protected branch|required status check|review required|not authorized|must have" <<< "$merge_out"; then
            warn "Der Branch-Schutz von $BASE_BRANCH verhindert den automatischen Merge."
            warn "Entweder die Regel lockern oder AUTOMERGE_TOKEN (PAT) als Secret hinterlegen."
        fi
        exit 1
    fi
fi

MERGE_SHA="$(pr_field mergeCommit '.mergeCommit.oid')"
comment_once "<!-- automerge-gruen -->" "### 🤖 Auto-Merge: in \`$BASE_BRANCH\` gemergt

- Merge-Commit: \`${MERGE_SHA:0:8}\`
- Geprüft mit: Swift-Syntax-/Typ-Prüfung und Regressionstests

Der nächste Push auf diesen Branch landet wieder automatisch hier."
ok "Merge-Commit: ${MERGE_SHA:0:8}"

# ------------------------------------------------------- Folge-Build anstoßen

if [ "$DISPATCH_BUILD" = "1" ]; then
    log "IPA-Build auf $BASE_BRANCH anstoßen"
    if gh_quiet workflow run "$BUILD_WORKFLOW" --repo "$REPO" --ref "$BASE_BRANCH" >/dev/null; then
        ok "Build-Workflow gestartet (Artefakt nach ein paar Minuten im Tab Actions)."
    else
        warn "Build-Workflow konnte nicht gestartet werden – ggf. manuell über Actions starten."
    fi
fi

exit 0
