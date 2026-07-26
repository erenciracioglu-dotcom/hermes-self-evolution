# Witness Log — Real User Friction

Append-only ledger of friction the user has actually experienced.
Source of ground truth for Evolution under Constitution Article II.

Agents MUST NOT modify past entries. Add new entries at the top.

## Format
```
## Witness Entry YYYY-MM-DDTHH:MM±TZ
Source: (active session | observation | external)
Friction: <observable capability gap the user actually hit>
Capability gap: <one-sentence capability whose weakness surfaced>
User signal: <the user's literal words, if any, or the correction they forced>
```

---

## Seed entries — placeholder examples
The framework ships with these seed entries so Evolution has at least one
witness anchor on first run. **Replace them with your own real friction
as soon as you encounter it** — they are deliberately generic and do
not reflect any specific user's experience.

## Witness Entry 2026-01-01T00:00
Source: (seed)
Friction: agent took multiple investigative turns before identifying a
recurring third-party tool failure that had a known fix in the harness's
own `known-failure-triage-db.md`.
Capability gap: error-string-to-known-fix lookup — agent did not load the
triage skill first.
User signal: (placeholder — replace with your real friction)

## Witness Entry 2026-01-01T00:00
Source: (seed)
Friction: Evolution produced several internal-hygiene cycles (bookkeeping
cleanups, log rotates) without observable improvement to any user-facing
capability.
Capability gap: Evolution can change harness internals without ever asking
"what user friction does this address" — bookkeeping theatre.
User signal: (placeholder — replace with your real friction)
