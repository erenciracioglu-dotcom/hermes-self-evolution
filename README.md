# hermes-self-evolution

A **self-evolving harness framework** for [Hermes Agent](https://github.com/hermes-agent).
Four scheduled cron jobs (Evolution, Critic, Verifier, Gardener) cooperate to make
your Hermes instance measurably more useful over time — without producing
harness-internal bookkeeping theatre.

The framework is generic. It ships **empty**: no preset friction database,
no real cron history, no operator-specific data. Every operator populates
their own `witness-log.md` and `known-failure-triage-db.md` from their
actual experience.

## Why this exists

Harness Evolution cycles are prone to three failure modes:

1. **Bookkeeping theatre** — Evolution produces internal cleanups
   (log rotates, version bumps) without observable improvement to
   any user-facing capability. Article II in `constitution.md`
   forbids this.
2. **Collusion between Evolution and Critic** — if both run the same
   model, they reinforce each other's blind spots. A diverse-model
   setup breaks this.
3. **Skill loader caveat** — In some Hermes cron setups (especially
   older v0.x builds and certain v1.x pre-release lines), the
   `skills=[...]` parameter on `cron create` has been observed to fail
   with qualified-name lookups. The framework's prompts therefore
   load skills at runtime via `read_file` / `terminal` rather than
   relying on the qualified-path loader. This is a deliberate
   portability hedge, not a Hermes bug — newer versions generally
   handle `skills=[...]` correctly. If your Hermes version is known
   to work with the native loader, you may pass `--skills` directly.

This framework ships patterns that mitigate all three.

## How this differs from Hermes' built-in learning loop

Hermes already ships a built-in learning loop (skill creation from
experience, in-session skill improvement, persistent user modelling).
That's not the problem this framework solves — `hermes-self-evolution`
operates on a different mechanism:

| Aspect | Hermes built-in learning loop | hermes-self-evolution |
|---|---|---|
| **Trigger timing** | In-session (while the user is interacting with the agent) | Offline (via cron-scheduled jobs when the user is absent) |
| **Learning focus** | Creating new skills and enhancing existing ones | Identifying friction from witness logs and updating capabilities in compliance with the Constitution |
| **Execution method** | LLM-curated during active agent usage | Four distinct cron loops (Evolution, Critic, Verifier, Gardener) using diverse models and falsifiable predictions |
| **Safety governance** | No formal amendment protocol (in-session, LLM-curated) | 6-Article Constitution, proposal-only amendments, mandatory human approval |
| **Output guarantee** | Skill improvement happens only on demand | Every cycle MUST produce a real report — even on no-op. Witness log is append-only ground truth. |

The two mechanisms are complementary: the built-in loop improves the
agent *during* use, while `hermes-self-evolution` audits and adjusts
the agent *between* sessions under a formal governance protocol.

## About

Built by [@erenciracioglu](https://x.com/erenciracioglu). If you install
this framework and it helps, mention [@erenciracioglu](https://x.com/erenciracioglu)
on X — organic feedback keeps the project alive.

## Layout

```
hermes-self-evolution/
├── README.md                          this file
├── LICENSE                            MIT
├── .gitignore                         excludes .tmp/, backups/, *.bak.*
├── install.sh                         one-shot setup
├── constitution.md                    binding rules (Articles I-VI)
├── prompts/
│   ├── evolution.md                   Evolution cron prompt
│   ├── critic.md                      Critic cron prompt
│   ├── verifier.md                    Verifier cron prompt
│   └── gardener.md                    Gardener cron prompt
├── scripts/
│   ├── execution-loop.sh              recommendation dispatcher (invoked by Evolution)
│   ├── harness-verify.sh              prediction printer (invoked by Verifier)
│   └── harness-gardener.sh            dormant-skill scanner (invoked by Gardener)
├── skills/
│   ├── known-failure-triage-db.md     empty template (you populate with your friction)
│   ├── memory-enrichment.md           facts/ append-only memory
│   └── harness-version-tracking.md    semver tracking for skills
└── facts/                             per-cycle logs (append-only)
    ├── recommendation.md              Evolution's current cycle commitment
    ├── witness-log.md                 real user friction (seed entries pre-populated)
    ├── predictions.md                 falsifiable predictions (Evolution writes)
    ├── prediction-outcomes.md         verdicts (Verifier writes)
    ├── harness-state.md               last-cycle snapshot
    ├── cleanup-log.md                 facts-cleanup.sh history
    └── credential-health.log          provider auth probe history
```

## Quick start

```bash
# 1. Clone the repository
git clone https://github.com/erenciracioglu-dotcom/hermes-self-evolution.git
cd hermes-self-evolution

# 2. Configure
export HERMES_BIN=/path/to/hermes           # Hermes CLI binary
export CHAT_ID=<your-telegram-chat-id>      # for delivery
export MODEL_EVOLUTION=<model-name>         # e.g. grok-4.5, gpt-5
export MODEL_CRITIC=<different-model>       # IMPORTANT: pick a different model

# 3. Run install
bash install.sh
```

`install.sh` will:
- Create `${HERMES_HOME}/harness/` (default `~/hermes-harness`)
- Copy the framework files into place
- Verify required files are present
- Create four cron jobs (Evolution, Critic, Verifier, Gardener)
- Write the initial `harness-state.md`

After the first cron tick (typically within an hour), the framework is
operational.

## Tuning

Override any default via env vars before `install.sh`:

| Variable | Default | Notes |
|---|---|---|
| `HERMES_HOME` | `~/hermes-harness` (POSIX) or `%USERPROFILE%\hermes-harness` (Windows) | Root of the framework |
| `HERMES_BIN` | (required) | Hermes CLI binary |
| `CHAT_ID` | (required) | Telegram chat ID for delivery |
| `MODEL_EVOLUTION` | `MODEL_EVOLUTION` | **Recommendation: pick a fast/cheap model** |
| `MODEL_CRITIC` | `MODEL_CRITIC` | **Recommendation: pick a different model from Evolution** to break collusion |
| `MODEL_VERIFIER` | same as Evolution | Verifier is mostly mechanical (read + grep), Evolution-class model is fine |
| `MODEL_GARDENER` | same as Evolution | Gardener is mostly mechanical too |
| `CRON_EVOLUTION` | `0 */4 * * *` | Evolution runs every 4 hours |
| `CRON_CRITIC` | `2 */4 * * *` | Critic runs every 4 hours, offset 2h from Evolution |
| `CRON_VERIFIER` | `0 4 */2 * *` | Verifier runs every 2 days at 04:00 |
| `CRON_GARDENER` | `0 4 1,8,15,22 * *` | Gardener runs every 4 days at 04:00 |
| `SELF_SUPERVISED` | `true` | If true, Evolution may amend `constitution.md` under Article VI traceability. Set to `false` to require human-only amendments. |

### Model diversity — anti-collusion

Running Evolution and Critic on the **same model** invites collusion: the
same blind spots, the same training biases, the same failure modes.
Pick two different providers if possible. Example setups:

| Setup | Evolution | Critic | Notes |
|---|---|---|---|
| Recommended | `grok-4.5` | `claude-sonnet-4` | Two providers, two training corpora |
| Cheapest viable | `gpt-4o-mini` | `claude-haiku-4` | Both fast, both cheap, both different |
| Single provider | `gpt-5` | `gpt-5-mini` | Different generations within one provider — still some diversity |

### Self-supervised mode and Article VI

Article VI of the constitution permits amendments by either the human
operator or an authorised agent (Harness Evolution), provided the
amendment is **traceable**: a proposal in `facts/amendment-proposal.md`,
a commit, and a Telegram notification, all in the same cycle.

Our recommendation (informational, not binding): **keep `SELF_SUPERVISED=true`
for development, set it to `false` once the harness is stable.** The
default is `true` because Evolution cycles are blocked from doing
useful work if every constitutional change needs a human commit. But
"constitutional change" includes subtle things like the gate protocol,
the [SILENT] rule, and the witness anchor requirement. If those have
settled, locking amendments to humans adds an extra safety rail.

## Troubleshooting

### "cron created but Telegram receives nothing"

Check the cron job's `last_status` and `last_delivery_error`:

```bash
${HERMES_BIN} cron list
```

If `last_status=ok` but Telegram received nothing, the issue is
almost always one of:

1. **Skill loader qualified-name crash.** If you passed
   `--skills=['software-development/known-failure-triage']` to
   `cron create`, the loader may silently fail. The framework's
   prompts deliberately use `terminal` + `read_file` to load skills
   at runtime. Re-create the cron jobs without `--skills`.
2. **Telegram bot missing `chat_id`.** The `cron create` call needs
   `--deliver telegram:<CHAT_ID>`. Verify with `${HERMES_BIN} config show`.
3. **Prompt produces `[SILENT]`.** The prompt must produce a real
   report even when there is no actionable work. See the
   `[SILENT]` rule below.

### "[SILENT] all the time — never any report"

The framework's prompts use `[SILENT]` only in narrow conditions
(verdict HEALTHY + severity <= low + no unaddressed critique). If
your Telegram is silent:

- Check the cron tick ran at all (`${HERMES_BIN} cron list` — last_run_at).
- Look at the cron output directory (`~/.local/share/hermes/cron/output/<job-id>/`)
  and check the most recent run's response.
- If the response is literally `[SILENT]`, something is bypassing the
  rule. Either your Evolution never produced an ACTION REPORT (it
  chose NO-OP every cycle), or the Critic is silently downgrading
  everything to HEALTHY.

### "Cron skill loader error"

If the cron output shows:

```
Error loading skill 'software-development/known-failure-triage':
no such skill
```

or similar qualified-name failures, the fix is to remove the
`--skills` parameter and let the prompt load skills at runtime
via `read_file` / `terminal`. The framework's prompts already do
this; if you copy them verbatim, you should not see this error.

### "Articles I-VI: which one is binding?"

All six are binding. Article II (Grounded Evolution) is the most
commonly violated — it forbids Evolution from changing anything
without real friction evidence. If Evolution is producing internal
hygiene cycles, your `facts/witness-log.md` is probably empty or
stale. Replace the seed entries with real friction.

## Conventions

### Every cycle MUST produce a real Telegram notification

Each cron prompt explicitly forbids bare `[SILENT]` reports. Telegram
**must** receive a message every cycle, even if the cycle produced
no actionable work. The NO-OP REPORT format is:

```
Harness Evolution — no-op cycle
Time: <ISO timestamp>
Gate: passed | halted
Reason: <one short reason>
Streak: <N consecutive no-op cycles>
Watch: <optional — what signal would unlock next action>
```

This rule exists because **silent failure modes are the dominant
harness bug**. If your harness stops producing reports, you cannot
tell whether it is healthy or stalled.

### Witness log is the source of truth

`facts/witness-log.md` is append-only. Evolution must cite a witness
timestamp in every ACTION REPORT. If there is no actionable witness,
Evolution produces a NO-OP REPORT (or, if the last 3 critiques are
unaddressed, addresses them first).

The framework ships two seed entries in `facts/witness-log.md` as
placeholders. **Replace them with your own real friction** as soon
as you encounter any.

### Constitution amendments are traceable

Article VI permits amendments by either the human operator or an
authorised agent (Harness Evolution), provided:
1. A proposal lands in `facts/amendment-proposal.md`.
2. The amendment is committed to the framework repository.
3. The user receives a Telegram notification in the same cycle.

If any of these is missing, the amendment is invalid and should be
reverted (Article V: Transparency of Influence).

## Changelog

### v1.2 — Clarify (2026-07-26)

Add a side-by-side comparison table to README (§"How this differs from
Hermes' built-in learning loop") in response to a recurring reader
question: "Hermes already has a learning loop, why do we need this?"

The two mechanisms are complementary, not redundant:

- Hermes' built-in loop improves the agent **in-session** (skill
  creation + improvement during use).
- `hermes-self-evolution` audits and adjusts the agent **between
  sessions** under a formal governance protocol (Constitution +
  diverse-model Critic + falsifiable predictions).

Also softens the previous framing of Hermes' safety posture from
"None" to "No formal amendment protocol (in-session, LLM-curated)" —
the built-in loop has implicit safety through in-session LLM
judgement; it just lacks the formal amendment protocol this
framework provides.

### v1.1 — Hardening (2026-07-26)

Address the review by [@hendrixfreire](https://github.com/hendrixfreire)
in [hermes-self-evolution-review](https://github.com/hendrixfreire/hermes-self-evolution-review):

- **F1 (review §1.5):** confirmed and documented — `scripts/execution-loop.sh`
  never passes the LLM-written `DETAIL` field to `bash`. The `eval` arm
  was removed in v2; this release makes the SECURITY comment explicit so
  the design choice is visible to contributors.
- **F2 (review §1.3):** `install.sh` now creates every facts file
  referenced by prompts or scripts on first run (was missing
  `enforcement-log.md`, `learning-log.md`, and a few others — first-cycle
  crash fixed).
- **F4 (review §1.4):** `scripts/execution-loop.sh` drops the hardcoded
  `known_arms` list (pure maintenance debt). `_print_unused_arms()` now
  reports only arms that have actually been dispatched, sourced from
  `DISPATCH_STATE_FILE`.
- **F5 (review §1.8):** portable `date` parser in
  `_print_unused_arms()` — GNU `date -d`, BSD `date -j -f`, then
  `stat` mtime fallback. Silent-failure path removed.
- **F6 (review §1.7):** README §"Why this exists" softened — the skill
  loader claim was overstated. Runtime loading is a deliberate
  portability hedge, not a Hermes bug.

Items in the review that this release **does not** change:

- `eval`-of-markdown (§1.5): already absent in v2; the SECURITY comment
  in `execution-loop.sh` makes this permanent by design.
- `SELF_SUPERVISED` / proposal-only-amendment (§1.6): the default
  (`PROPOSAL_ONLY_AMEND=true`) already requires a human git commit for
  constitutional amendments. The "agent amends its own constitution"
  risk is closed.
- Gardener cron (§4 redesign): kept. The reviewer proposed deleting it
  to simplify; we disagree — agent entropy is a real long-term risk and
  Gardener's "surface dormant skills for human archival" boundary is
  the right one (Constitution Article IV: anti-fragility over comfort).
- `SELF_SUPERVISED` rename (`PROPOSAL_ONLY_AMEND`): not changed — the
  install-time flag name reflects what the flag actually controls.

## License

MIT — see `LICENSE`.
