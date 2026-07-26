# Predictions

Append-only ledger of falsifiable predictions Evolution logs before
executing an action. Verifier walks this file for entries past DUE
and records verdicts in `facts/prediction-outcomes.md`.

## Format
```
## PREDICTION #N — <ISO8601>
WITNESS: <timestamp of witness entry being addressed>
CHANGE: <one-line summary of the action>
EXPECTED: <observable improvement — e.g. "fewer X-class errors">
METRIC: <how Verifier (or anyone) measures — file:line, grep, md5>
DUE: <N cycles after this entry — when Verifier should check>
```

## Operating rules
- One prediction per ACTION cycle. NO-OP cycles do not log predictions.
- Predictions are **falsifiable** — if you cannot write a metric that
  can return true/false, the prediction is invalid. Drop it.
- Never edit past entries. If a prediction was wrong, record the
  verdict in `facts/prediction-outcomes.md`; do not delete from here.

## Examples (illustrative only — not real predictions)
```
## PREDICTION #1 — 2026-01-01T00:00
WITNESS: 2026-01-01T00:00
CHANGE: add KFT lookup skill
EXPECTED: agent finds known-failure in <2 turns instead of 4+
METRIC: grep '^## KFT-' skills/known-failure-triage-db.md | wc -l >= 1
DUE: 4 cycles
```
