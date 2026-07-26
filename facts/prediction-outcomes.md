# Prediction Outcomes

Append-only ledger of verdicts recorded by the Verifier for each
prediction past its DUE date.

## Format
```
## OUTCOME for PREDICTION #N — <ISO8601>
VERDICT: confirmed | failed | inconclusive
EVIDENCE: <command run, file:line, hash, observed value>
LESSON: <one sentence if any>
```

## Operating rules
- One outcome per prediction. If the prediction was never logged in
  `facts/predictions.md`, do not invent an outcome for it here.
- Stale predictions (past DUE by 5+ cycles without an outcome) are
  auto-marked `failed` by the Verifier with EVIDENCE
  `grep -c '^## OUTCOME for PREDICTION #N' <this file> == 0`.
- Verifier is the only writer. Evolution and Critic may read but
  should not append outcomes (separation of powers).
