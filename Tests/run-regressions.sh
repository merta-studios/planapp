#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

compiler="${SWIFTC:-swiftc}"
if ! command -v "$compiler" >/dev/null 2>&1; then
    echo "Swift-Compiler fehlt. Mit installiertem Swift erneut starten (oder SWIFTC setzen)." >&2
    exit 127
fi

# Genau die Dateien, die auch die App benutzt – plus die Tests.
sources=(
    PlanApp.swiftpm/Utils/IntentionalTapPolicy.swift
    PlanApp.swiftpm/Utils/HeroTransitionPolicy.swift
    PlanApp.swiftpm/Models/PencilGestureAction.swift
    PlanApp.swiftpm/Services/TimetableRefreshPolicy.swift
    PlanApp.swiftpm/Views/Timetable/NotesOverviewLayout.swift
    PlanApp.swiftpm/Views/Drawing/SqueezePaletteLayout.swift
    PlanApp.swiftpm/Utils/InteractionPolicies.swift
    PlanApp.swiftpm/Utils/SchoolWeekPolicy.swift
    PlanApp.swiftpm/Models/Period.swift
    PlanApp.swiftpm/Utils/CurrentPeriodPolicy.swift
    PlanApp.swiftpm/Utils/DateExtensions.swift
    PlanApp.swiftpm/Models/GradeSettings.swift
    PlanApp.swiftpm/Models/GradeEntry.swift
    PlanApp.swiftpm/Utils/MobileNotePolicy.swift
    PlanApp.swiftpm/Models/NoteTextBox.swift
    PlanApp.swiftpm/Services/FolderSyncCore.swift
    Tests/InteractionRegressions/main.swift
)

# TYPE_CHECK_ONLY=1 übersetzt nur, ohne die Tests auszuführen. Das ist der
# schnelle Build-Check in CI (siehe .github/workflows/build-check.yml) und
# findet Compilerfehler wie „Cannot call value of non-function type 'Double'“,
# bevor sie im iOS-Build auf main landen.
if [ "${TYPE_CHECK_ONLY:-0}" = "1" ]; then
    "$compiler" "${sources[@]}" -typecheck
    echo "Kompilier-Check ok: App-Dateien und Regressionstests übersetzen."
    exit 0
fi

test_dir="$(mktemp -d "${TMPDIR:-/tmp}/planapp-regressions.XXXXXX")"
trap 'rm -rf "$test_dir"' EXIT

compile_log="$test_dir/compile.log"
set +e
"$compiler" \
    "${sources[@]}" \
    -o "$test_dir/interaction-regressions" 2>&1 | tee "$compile_log"
compile_status=${PIPESTATUS[0]}
set -e
if [ "$compile_status" -ne 0 ]; then
    # Fehlertext zusätzlich in die GitHub-Zusammenfassung schreiben, damit
    # die Ursache auch ohne Log-Download sichtbar ist.
    # Einzelne Fehlerzeilen als Annotation – so ist die Ursache auch in der
    # Weboberfläche der Prüfung sichtbar, ohne das Protokoll herunterzuladen.
    if [ -n "${GITHUB_ACTIONS:-}" ] && [ -f "$compile_log" ]; then
        grep -E "error:" "$compile_log" | head -10 | while IFS= read -r line; do
            echo "::error::${line//$'\n'/ }"
        done
    fi
    if [ -n "${GITHUB_STEP_SUMMARY:-}" ] && [ -f "$compile_log" ]; then
        {
            echo "## Regressionstests: Übersetzen fehlgeschlagen"
            echo '```'
            head -80 "$compile_log"
            echo '```'
        } >> "$GITHUB_STEP_SUMMARY"
    fi
    exit "$compile_status"
fi
"$test_dir/interaction-regressions"
