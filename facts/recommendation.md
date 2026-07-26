# Recommendation

## Purpose
Evolution's current-cycle commitment. Written **before** execution (STEP 0
pre-registration in the Evolution prompt). Append-only — Evolution writes
each cycle, then `execution-loop.sh evolve` consumes this file.

## Format
```
# Recommendation — Run #N
Timestamp: <ISO8601>
Cycle: evolve-N
WITNESS_ANCHOR: <timestamp of witness entry being addressed>
WITNESS_SECONDARY: <optional — earlier witness if layered>

## STEP 0 — Chosen capability gap (pre-registered, then grounded)

**Weak capability:** <one-sentence capability whose weakness surfaces>
**Evidence (STEP 1):**
- witness:<timestamp> — <what the user actually hit>
- <additional evidence, file:line>

**One measurable improvement:**
1. <first concrete change>
2. <second concrete change>

RECOMMENDED_ACTION: <action type, e.g. bash_command | skill_automation | ...>
DETAIL: <one-line shell command, prose-guard compatible>
REASONING: <one sentence tying the witness to the action>

<!-- supervised-mode nonce: <int> | audit-enforcement-log @ <ISO8601> -->
```

## Operating rules
- One recommendation per Evolution cycle. Do not stack.
- Pre-registration is mandatory — write to this file before reading
  other facts files (forces commitment to a direction, not reaction).
- If STEP 1 evidence doesn't support STEP 0, switch to NO-OP REPORT
  in the Telegram message — do not delete this file, leave it as a
  recorded attempt.
