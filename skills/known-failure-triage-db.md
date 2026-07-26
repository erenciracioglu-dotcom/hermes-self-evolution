---
name: known-failure-triage-db
description: Fast path from error string → known cause → diagnostic → fix. Load this skill FIRST when a third-party tool, GPU stack, or API provider fails. Seeded from real friction, not internal bookkeeping.
triggers:
  - "third-party crash"
  - "provider error"
  - "CUDA error"
  - "401 429 500"
  - "OAuth can't reach API"
---

# known-failure-triage-db

## Purpose
Fast path from error string → known cause → diagnostic → fix.
Load this skill FIRST when a third-party tool, GPU stack, or API provider fails.
Article II: seeded from real witness friction (not internal bookkeeping).

## When to use
- Import/runtime crash in any local inference or content-generation tool (image, video, audio, LLM runtime)
- Provider errors: any HTTP 401/429/500, OAuth, "can't reach API"
- Agent about to start multi-step exploratory diagnosis on a seen-before failure class

## Lookup protocol
1. Capture the primary error line (first Exception / HTTP status / stderr signature).
2. `grep -iE '<key tokens>' "${HERMES_HOME}/harness/skills/known-failure-triage-db.md"` (or `skill_view` this file).
3. On KFT hit: run `diagnostic_cmd`, then `fix_action`. Skip open-ended theory loops.
4. On miss: diagnose normally, then **APPEND a new KFT row** (same schema) before session end.

## Schema
```
## KFT-<id> | <error_pattern> | <known_cause> | <diagnostic_cmd> | <fix_action> | <regression_check> | <witness_ref>
```

## How to populate this DB
The DB ships **empty** for a reason: every operator's environment fails differently. Common starting points:

- Local inference runtimes (text, image, video, audio) — driver / CUDA / model-format errors
- Provider APIs — auth (401), rate limit (429), network (curl/probe failures)
- GPU stack — driver death, OOM, device-not-ready states
- Agent-specific runtime — failed tool invocations, missing dependencies

For each row you add, the `witness_ref` should point to a real friction entry in `facts/witness-log.md` — never invent a witness.

## Usage notes for Hermes agents

- Skill name: `known-failure-triage` (top-level Hermes skill)
- Prefer this file over ad-hoc web search when an error matches a row.
- Never claim a KFT match without running `diagnostic_cmd` (or showing why it was skipped).
- After a novel failure is solved, append a KFT row with `witness_ref = <session timestamp>`.

## Environment
- `HERMES_HOME` — root of the framework; default `~/hermes-harness` (Linux/Mac) or `C:\Users\<user>\hermes-harness` (Windows)
- All paths in this skill use `${HERMES_HOME}/harness/...`

## Example row (template only — replace with your own observed failure)
```
## KFT-XXX | <your error pattern here> | <root cause> | <one-liner diagnostic> | <fix steps> | <how to verify it stays fixed> | witness:<your-session-timestamp>
```
