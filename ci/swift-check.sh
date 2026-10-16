#!/usr/bin/env bash
#
# ci/swift-check.sh – prüft den Swift-Code dieses Repos OHNE Mac, Xcode oder
# iOS-SDK. Gedacht für Linux (GitHub-Actions-Runner) im Docker-Image
# "swift:<Version>" – siehe ci/run-swift.sh und .github/workflows/build-check.yml.
#
# Modi:
#   parse      Alle .swift-Dateien syntaktisch parsen. Das funktioniert auch für
#              Dateien mit "import UIKit/SwiftUI/PencilKit", weil beim Parsen
#              keine Module aufgelöst werden. Findet fehlende Klammern,
#              abgebrochene Strings, kaputte Zeichenketten-Interpolationen usw.
#   typecheck  Den UIKit-freien Teil wirklich übersetzen (echte Typ-Prüfung).
#              Dateien, die iOS-only-Module importieren, werden automatisch
#              übersprungen; nicht verfügbare Module werden vorher getestet.
#   all        Beides (Standard).
#
# Umgebungsvariablen:
#   SWIFTC             Compiler (Standard: swiftc)
#   SWIFT_STRICT       0 = nur melden, 1 = Fehler zählt (Standard: 1)
#   SWIFT_SUMMARY_FILE Pfad für die Zusammenfassung (Standard: keine Datei)
#
# Rückgabewert: 0 = alles in Ordnung, 1 = Fehler gefunden.

set -uo pipefail

cd "$(dirname "$0")/.."

SWIFTC="${SWIFTC:-swiftc}"
STRICT="${SWIFT_STRICT:-1}"
SUMMARY_FILE="${SWIFT_SUMMARY_FILE:-}"
MODE="all"

case "${1:-all}" in
    parse|typecheck|all) MODE="${1:-all}" ;;
    -h|--help)
        sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'
        exit 0
        ;;
    *)
        echo "Unbekannter Modus: $1 (erwartet: parse, typecheck, all)" >&2
        exit 2
        ;;
esac

# ---------------------------------------------------------------- Hilfsmittel

log() { printf '\033[1m%s\033[0m\n' "$*"; }
ok() { printf '  \033[32m✓\033[0m %s\n' "$*"; }
note() { printf '  \033[34mi\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*"; }
err() { printf '  \033[31m✗\033[0m %s\n' "$*"; }

# GitHub-Workflow-Befehle: Zeilen erscheinen als Annotation direkt an der
# betroffenen Code-Zeile im PR. "%", ":" und Zeilenumbrüche müssen escaped
# werden, sonst zerbricht die Annotation.
escape_prop() {
    local s="$1"
    s="${s//%/%25}"
    s="${s//:/%3A}"
    s="${s//,/%2C}"
    printf '%s' "$s"
}
escape_data() {
    local s="$1"
    s="${s//%/%25}"
    s="${s//$'\r'/%0D}"
    s="${s//$'\n'/%0A}"
    printf '%s' "$s"
}
annotate() { # annotate <error|warning|notice> <datei> <zeile> <spalte> <text>
    [ "${GITHUB_ACTIONS:-}" = "true" ] || return 0
    printf '::%s file=%s,line=%s,col=%s::%s\n' \
        "$1" "$(escape_prop "$2")" "$(escape_prop "$3")" "$(escape_prop "$4")" "$(escape_data "$5")"
}

DIAG_ERRORS=0
DIAG_WARNINGS=0
DIAG_IGNORED=0

# Compiler-Ausgabe in Einzelmeldungen zerlegen und ausgeben.
report_output() { # report_output <ausgabe>
    local line level file l c message
    while IFS= read -r line; do
        [ -n "$line" ] || continue
        if [[ "$line" =~ ^(.*\.swift):([0-9]+):([0-9]+):\ (error|warning|note):\ (.*)$ ]]; then
            file="${BASH_REMATCH[1]}"
            l="${BASH_REMATCH[2]}"
            c="${BASH_REMATCH[3]}"
            level="${BASH_REMATCH[4]}"
            message="${BASH_REMATCH[5]}"
            case "$level" in
                error)   err "$file:$l:$c: $message"; DIAG_ERRORS=$((DIAG_ERRORS + 1)) ;;
                warning) warn "$file:$l:$c: $message"; DIAG_WARNINGS=$((DIAG_WARNINGS + 1)) ;;
                *)       note "$file:$l:$c: $message" ;;
            esac
            annotate "$level" "$file" "$l" "$c" "$message"
        else
            printf '%s\n' "$line"
        fi
    done <<< "$1"
}

# Für die Typ-Prüfung: Ist die Meldung nur die Folge davon, dass eine
# iOS-only-API unter Linux fehlt? Solche Meldungen dürfen den Lauf nicht
# rot machen, echte Typfehler ("Cannot call value of non-function type")
# dagegen schon.
is_dependency_error() {
    case "$1" in
        *"no such module"*) return 0 ;;
        *"cannot find type"*"in scope"*) return 0 ;;
        *"cannot find '*'"*"in scope"*) return 0 ;;
        *"cannot find operator"*) return 0 ;;
        *"use of unresolved identifier"*) return 0 ;;
        *"binary operator cannot be applied"*) return 0 ;;
        *) return 1 ;;
    esac
}

# Alle Swift-Dateien des Repos (ohne Build-Artefakte).
source_files() {
    find . -name '*.swift' \
        -not -path './.build/*' \
        -not -path './DerivedData/*' \
        -not -path '*/DerivedData/*' \
        -not -path '*/.build/*' \
        | sort
}

require_compiler() {
    if ! command -v "$SWIFTC" >/dev/null 2>&1; then
        echo "Swift-Compiler '$SWIFTC' nicht gefunden." >&2
        echo "Lokal: ci/run-swift.sh <befehl>  – oder SWIFTC=/pfad/zu/swiftc setzen." >&2
        exit 127
    fi
}

summary_append() { # summary_append <zeile>
    [ -n "$SUMMARY_FILE" ] || return 0
    printf '%s\n' "$1" >> "$SUMMARY_FILE"
}

# ------------------------------------------------------- Modus: parse (Syntax)

run_parse() {
    log "Syntax-Prüfung aller Swift-Dateien"
    local -a files=()
    mapfile -t files < <(source_files)
    local total="${#files[@]}"
    if [ "$total" -eq 0 ]; then
        err "Keine Swift-Dateien gefunden."
        return 1
    fi
    note "$total Dateien, Compiler: $("$SWIFTC" --version 2>/dev/null | head -n 1)"

    local before_errors="$DIAG_ERRORS"
    local batch_size=8
    local i=0 out f
    # Bewusst in Blöcken: schnell, und bei Fehlern wird der Block einzeln
    # aufgelöst, damit jede Meldung an der richtigen Datei landet.
    while [ "$i" -lt "$total" ]; do
        local -a block=("${files[@]:i:batch_size}")
        i=$((i + batch_size))

        if out=$("$SWIFTC" -frontend -parse "${block[@]}" 2>&1); then
            # Auch im Erfolgsfall können Warnungen im Text stehen.
            [ -n "$out" ] && report_output "$out"
            continue
        fi

        for f in "${block[@]}"; do
            if out=$("$SWIFTC" -frontend -parse "$f" 2>&1); then
                [ -n "$out" ] && report_output "$out"
            else
                err "Syntaxfehler in $f"
                report_output "$out"
            fi
        done
    done

    local found=$((DIAG_ERRORS - before_errors))
    if [ "$found" -eq 0 ]; then
        ok "Alle $total Dateien sind syntaktisch in Ordnung."
        summary_append "- ✅ Syntax: $total Dateien geprüft, keine Fehler"
        return 0
    fi
    err "$found Syntaxfehler gefunden."
    summary_append "- ❌ Syntax: $found Fehler in $total Dateien"
    return 1
}

# ------------------------------------------- Modus: typecheck (echte Typen)

MODULES_AVAILABLE=()
MODULES_MISSING=()

probe_module() { # probe_module <modulname>
    local module="$1" dir
    dir="$(mktemp -d "${TMPDIR:-/tmp}/swift-probe.XXXXXX")"
    printf 'import %s\n' "$module" > "$dir/probe.swift"
    if "$SWIFTC" -typecheck "$dir/probe.swift" >/dev/null 2>&1; then
        rm -rf "$dir"
        MODULES_AVAILABLE+=("$module")
        return 0
    fi
    rm -rf "$dir"
    MODULES_MISSING+=("$module")
    return 1
}

module_available() {
    local m
    for m in ${MODULES_AVAILABLE[@]+"${MODULES_AVAILABLE[@]}"}; do
        [ "$m" = "$1" ] && return 0
    done
    return 1
}

# Dateien, deren sämtliche Imports unter Linux verfügbar sind.
portable_files() {
    local f imports
    while IFS= read -r f; do
        # Foundation-only imports do not imply a portable dependency graph:
        # DrawingSettings uses NoteTextFontStyle (UIKit/SwiftUI), NoteTextBox
        # (CoreGraphics), and NoteBackgroundMetrics (CoreGraphics). Without
        # those definitions Swift also emits misleading Equatable/inference
        # errors. Keep this model covered by syntax and the real iOS build.
        case "$f" in
            ./PlanApp.swiftpm/Models/DrawingSettings.swift) continue ;;
        esac
        imports=$(grep -E '^[[:space:]]*(@preconcurrency[[:space:]]+)?import[[:space:]]+' "$f" \
            | sed -E 's/^[[:space:]]*(@preconcurrency[[:space:]]+)?import[[:space:]]+//; s/[[:space:]].*$//')
        local skip=0 m
        for m in $imports; do
            case "$m" in
                Foundation|Dispatch|Darwin|Glibc|Swift|SwiftOnoneSupport) continue ;;
            esac
            module_available "$m" || { skip=1; break; }
        done
        [ "$skip" -eq 0 ] && printf '%s\n' "$f"
    done < <(source_files)
}

run_typecheck() {
    log "Typ-Prüfung (nur Linux-taugliche Dateien)"
    local -a probes=(Foundation Dispatch CoreGraphics Combine CryptoKit os)
    local m
    for m in "${probes[@]}"; do
        if probe_module "$m"; then
            note "Modul verfügbar: $m"
        else
            note "Modul fehlt unter Linux: $m (Dateien damit werden übersprungen)"
        fi
    done

    local -a files=()
    mapfile -t files < <(portable_files)
    local total="${#files[@]}"
    if [ "$total" -eq 0 ]; then
        warn "Keine Datei ist ohne iOS-SDK übersetzbar – nichts zu prüfen."
        summary_append "- ⚠️ Typ-Prüfung: keine portable Datei gefunden"
        return 0
    fi
    note "$total Dateien werden übersetzt:"
    printf '      %s\n' "${files[@]}"

    local out before_errors="$DIAG_ERRORS" before_ignored="$DIAG_IGNORED"
    out=$("$SWIFTC" -typecheck "${files[@]}" 2>&1)
    local rc=$?

    if [ "$rc" -eq 0 ]; then
        [ -n "$out" ] && report_output "$out"
        ok "Alle $total Dateien übersetzen fehlerfrei (Typ-Prüfung bestanden)."
        summary_append "- ✅ Typ-Prüfung: $total Linux-taugliche Dateien übersetzen fehlerfrei"
        return 0
    fi

    # Ausgabe sortieren: fehlende iOS-APIs (ignorierbar) vs. echte Fehler.
    local line
    local -a real=() ignored=()
    while IFS= read -r line; do
        [ -n "$line" ] || continue
        if [[ "$line" =~ ^(.*\.swift):([0-9]+):([0-9]+):\ (error|warning|note):\ (.*)$ ]]; then
            if [ "${BASH_REMATCH[4]}" = "error" ] && is_dependency_error "${BASH_REMATCH[5]}"; then
                ignored+=("$line")
            else
                real+=("$line")
            fi
        else
            real+=("$line")
        fi
    done <<< "$out"

    if [ "${#ignored[@]}" -gt 0 ]; then
        DIAG_IGNORED=$((DIAG_IGNORED + ${#ignored[@]}))
        warn "${#ignored[@]} Meldungen beziehen sich auf iOS-only-Code (unter Linux nicht auflösbar):"
        printf '      %s\n' "${ignored[@]}"
    fi

    local real_errors=0 line2
    if [ "${#real[@]}" -gt 0 ]; then
        # Bewusst eine for-Schleife: in einer Pipe liefe der Zähler in einer
        # Subshell und die Fehlerzahl wäre anschließend immer 0.
        for line2 in "${real[@]}"; do
            report_output "$line2"
        done
        real_errors=$((DIAG_ERRORS - before_errors))
    fi

    if [ "$real_errors" -eq 0 ]; then
        ok "Keine echten Typfehler – übrig bleiben nur iOS-only-Referenzen."
        summary_append "- ✅ Typ-Prüfung: $total Dateien übersetzt, nur iOS-only-Referenzen offen"
        return 0
    fi

    err "$real_errors Typfehler in Dateien, die unter Linux prüfbar sind."
    summary_append "- ❌ Typ-Prüfung: $real_errors Fehler (von $total Dateien)"
    return 1
}

# ------------------------------------------------------------------ Ablauf

require_compiler
log "Swift-Code-Prüfung (Modus: $MODE)"
summary_append "### Swift-Code-Prüfung (Linux)"
summary_append ""

status=0
if [ "$MODE" = "parse" ] || [ "$MODE" = "all" ]; then
    run_parse || status=1
fi
if [ "$MODE" = "typecheck" ] || [ "$MODE" = "all" ]; then
    run_typecheck || status=1
fi

echo
log "Zusammenfassung"
note "Fehler: $DIAG_ERRORS, Warnungen: $DIAG_WARNINGS, ignorierte iOS-only-Meldungen: $DIAG_IGNORED"

if [ "$status" -ne 0 ] && [ "$STRICT" = "0" ]; then
    warn "SWIFT_STRICT=0: Fehler werden nur gemeldet, der Lauf gilt als bestanden."
    status=0
fi

if [ "$status" -ne 0 ]; then
    summary_append ""
    summary_append "**Ergebnis: Fehler gefunden.** Details stehen oben im Log."
fi

exit "$status"
