#! /usr/bin/env bash
# harness-verify.sh — Verifier: falsify stale predictions (Constitution Article V).
#
# Walks facts/predictions.md for entries past their DUE date and writes
# verdict hints to facts/prediction-outcomes.md. Human-in-the-loop: the script
# only PRINTS a verdict hint; the writer (Critic or human) records the outcome.

set -euo pipefail

HERMES_HOME="${HERMES_HOME:-$HOME/hermes-harness}"
HARNESS_DIR="${HERMES_HOME}/harness"
PREDS="${HARNESS_DIR}/facts/predictions.md"
OUTCOMES="${HARNESS_DIR}/facts/prediction-outcomes.md"

if [[ ! -f "${PREDS}" ]]; then
    echo "ERROR: ${PREDS} not found." >&2
    exit 1
fi

# Extract PREDICTION entries. Format:
#   ## PREDICTION #N — YYYY-MM-DDTHH:MM+TZ
# Followed by WITNESS / CHANGE / EXPECTED / METRIC / DUE blocks.

awk '
  /^## PREDICTION #/ { in_pred=1; print "==="; print $0; next }
  in_pred && /^## PREDICTION #/ { in_pred=1; print "==="; print $0; next }
  in_pred && /^---/ { in_pred=0; next }
  in_pred { print }
' "${PREDS}" | head -200 || true

echo ""
echo "== Verifier instructions =="
echo "For each PREDICTION above:"
echo "  1. Read its WITNESS / CHANGE / EXPECTED / METRIC / DUE lines"
echo "  2. Run the METRIC command"
echo "  3. Append a verdict to facts/prediction-outcomes.md in this format:"
echo ""
echo "  ## OUTCOME for PREDICTION #N — <ISO now>"
echo "  VERDICT: confirmed | failed | inconclusive"
echo "  EVIDENCE: <command run, file:line, hash>"
echo "  LESSON: <one sentence if any>"
echo ""
echo "If a prediction has been DUE for > 5 cycles, mark it 'failed'"
echo "(unmeasured predictions are confirmed losses)."
