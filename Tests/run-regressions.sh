#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

compiler="${SWIFTC:-swiftc}"
if ! command -v "$compiler" >/dev/null 2>&1; then
    echo "Swift-Compiler fehlt. Mit installiertem Swift erneut starten (oder SWIFTC setzen)." >&2
    exit 127
fi

test_dir="$(mktemp -d "${TMPDIR:-/tmp}/planapp-regressions.XXXXXX")"
trap 'rm -rf "$test_dir"' EXIT

"$compiler" \
    PlanApp.swiftpm/Utils/IntentionalTapPolicy.swift \
    PlanApp.swiftpm/Utils/HeroTransitionPolicy.swift \
    PlanApp.swiftpm/Models/PencilGestureAction.swift \
    PlanApp.swiftpm/Services/TimetableRefreshPolicy.swift \
    PlanApp.swiftpm/Views/Timetable/NotesOverviewLayout.swift \
    PlanApp.swiftpm/Views/Drawing/SqueezePaletteLayout.swift \
    PlanApp.swiftpm/Utils/InteractionPolicies.swift \
    Tests/InteractionRegressions/main.swift \
    -o "$test_dir/interaction-regressions"
"$test_dir/interaction-regressions"
