#! /usr/bin/env bash
# harness-gardener.sh — Entropy control: list dormant capabilities under the
# rule "no capability may exist without evidence of use" (Constitution Article II).
#
# This script only PRINTS recommendations. The human operator must approve
# any removal (Article VI: only humans may edit the constitution or remove
# capabilities that affect user behavior).

set -euo pipefail

HERMES_HOME="${HERMES_HOME:-$HOME/hermes-harness}"
HARNESS_DIR="${HERMES_HOME}/harness"
SKILLS_DIR="${HARNESS_DIR}/skills"
LAST_N_DAYS="${GARDENER_DORMANT_DAYS:-30}"
CUTOFF_EPOCH=$(($(date +%s) - LAST_N_DAYS * 86400))

echo "Gardener — dormant capability scan (last ${LAST_N_DAYS} days)"
echo ""

if [[ ! -d "${SKILLS_DIR}" ]]; then
    echo "ERROR: ${SKILLS_DIR} not found." >&2
    exit 1
fi

# Each skill file: list those whose mtime is older than the cutoff.
# The actual "use" stat would require execution-log cross-reference;
# for v1 we use mtime as a coarse proxy. If a skill file has been
# touched within the window, treat as "in use".

declare -a dormant=()
declare -a active=()

shopt -s nullglob
for f in "${SKILLS_DIR}"/*.md "${SKILLS_DIR}"/*.sh; do
    [[ -f "$f" ]] || continue
    mtime=$(stat -c %Y "$f" 2>/dev/null || stat -f %m "$f")
    if [[ "$mtime" -lt "$CUTOFF_EPOCH" ]]; then
        dormant+=("$f")
    else
        active+=("$f")
    fi
done

echo "DORMANT (>= ${LAST_N_DAYS} days untouched, candidate for archive):"
for f in "${dormant[@]:-}"; do
    [[ -z "$f" ]] && continue
    printf "  %s  (last touched: %s)\n" "$f" \
        "$(date -d @"$(stat -c %Y "$f")" '+%Y-%m-%d' 2>/dev/null || stat -f %Sm "$f")"
done
echo ""

echo "ACTIVE (recently used):"
for f in "${active[@]:-}"; do
    [[ -z "$f" ]] && continue
    printf "  %s\n" "$f"
done
echo ""

# Cross-check: any skill invocation in execution-log.md that's NOT
# mapped to a current skill file?
if [[ -f "${HARNESS_DIR}/facts/execution-log.md" ]]; then
    echo "Cross-reference (last 5 executions vs current skill set):"
    grep -E '^## ' "${HARNESS_DIR}/facts/execution-log.md" | tail -5 || true
fi
