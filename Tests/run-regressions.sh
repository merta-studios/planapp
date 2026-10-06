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
    PlanApp.swiftpm/Utils/DateExtensions.swift
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

"$compiler" \
    "${sources[@]}" \
    -o "$test_dir/interaction-regressions"
"$test_dir/interaction-regressions"
