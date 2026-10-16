#!/usr/bin/env bash
#
# ci/run-swift.sh – führt einen Befehl in einem Linux-Container mit
# installiertem Swift aus. Damit lassen sich Syntax- und Typ-Prüfungen auch
# ohne Mac/Xcode fahren (lokal wie in GitHub Actions).
#
#   ci/run-swift.sh swift --version
#   ci/run-swift.sh ci/swift-check.sh all
#   ci/run-swift.sh Tests/run-regressions.sh
#
# Ist Docker nicht vorhanden (oder wird SWIFT_IMAGE=local gesetzt), wird der
# Befehl direkt ausgeführt – dann muss "swift"/"swiftc" lokal installiert sein.
#
# Umgebungsvariablen:
#   SWIFT_IMAGE        Docker-Image (Standard: swift:6.2-noble)

set -euo pipefail

cd "$(dirname "$0")/.."

if [ "$#" -eq 0 ]; then
    echo "Aufruf: ci/run-swift.sh <befehl> [argumente...]" >&2
    exit 2
fi

image="${SWIFT_IMAGE:-swift:6.2-noble}"
summary=".swift-check-summary.md"
rm -f "$summary"

finish() { # Schritt-Zusammenfassung aus dem Container nach oben reichen
    local rc="$1"
    if [ -n "${GITHUB_STEP_SUMMARY:-}" ] && [ -f "$summary" ]; then
        cat "$summary" >> "$GITHUB_STEP_SUMMARY"
    fi
    rm -f "$summary"
    return "$rc"
}

if [ "$image" = "local" ] || ! command -v docker >/dev/null 2>&1; then
    if ! command -v swift >/dev/null 2>&1 && ! command -v swiftc >/dev/null 2>&1 && ! command -v "$1" >/dev/null 2>&1; then
        echo "Weder Docker noch ein lokales Swift gefunden." >&2
        echo "Entweder Docker starten oder SWIFT_IMAGE mit einem erreichbaren Image setzen." >&2
        exit 127
    fi
    echo "→ Ohne Container (lokales Swift): $*"
    rc=0
    "$@" || rc=$?
    finish "$rc"
    exit "$rc"
fi

echo "→ Container $image: $*"
rc=0
docker run --rm \
    --user "$(id -u):$(id -g)" \
    -e HOME=/tmp \
    -e GITHUB_ACTIONS="${GITHUB_ACTIONS:-}" \
    -e SWIFT_STRICT="${SWIFT_STRICT:-1}" \
    -e SWIFT_SUMMARY_FILE="/src/$summary" \
    -v "$PWD:/src" \
    -w /src \
    "$image" "$@" || rc=$?

# Die Schritt-Zusammenfassung entsteht im Container und wird hier angehängt.
finish "$rc"
exit "$rc"
