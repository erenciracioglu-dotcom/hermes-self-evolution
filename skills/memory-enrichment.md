---
name: memory-enrichment
description: Persist facts extracted from harness cycles to file-based memory in facts/ (v1.5.0)
triggers:
  - "harness memory"
  - "fact extraction"
  - "memory enrichment"
---

# Memory Enrichment — Harness Fact Extraction (v1.5.0)

## Purpose
Persist knowledge collected during harness cycles (system capabilities, learned strategies, recurring failures) to durable memory — file-based, append-only, no external tool dependency.

## Why file-based
1. The `memory` tool is **DISABLED in cron contexts** (hermes-agent constraint).
2. The `facts/` directory is already the harness's file-based memory (see `harness-state.md`).
3. `session_search` / `read_file` can query `facts/*.md` across sessions — preserves the v1.4.0 design intent.
4. `facts-cleanup.sh` retention policy (`MAX_AGE_DAYS=7`, `MAX_ARCHIVE_AGE_DAYS=30`) handles lifecycle automatically.

## Strategy
Every harness cycle extracts facts from logs. Persisted via append to `facts/*.md` files. Future cycles query via `session_search` / `read_file`.

## Implementation

### Extracted facts
- System capabilities (tool versions, available skills)
- Strategy results (what worked, what did not)
- Failure patterns (recurring failure modes)
- Configuration notes
- Tool quirks (Windows/MSYS specific behaviors)

### File-based memory write format
```bash
# Append a single fact to facts/learning-log.md (no memory tool)
TS=$(date '+%Y-%m-%dT%H:%M:%S%z')
CATEGORY="harness_learning"
TYPE="capability"   # capability|strategy|error|config
SOURCE="<origin>"  # source file or session
FACT="<short fact sentence>"

mkdir -p "${HERMES_HOME}/harness/facts"
{
  echo "| Timestamp | Category | Type | Source | Fact |"
  echo "|---|---|---|---|---|"
  echo "| ${TS} | ${CATEGORY} | ${TYPE} | ${SOURCE} | ${FACT} |"
} >> "${HERMES_HOME}/harness/facts/learning-log.md"
```

### Example extraction
```bash
FACTS=(
  "hermes send CLI works for Telegram, but cron context cannot use it; final response is delivered automatically"
  "gh CLI not installed — using GitHub API via curl instead (skill: github-api-via-curl)"
  "backup_restore.sh is critical — if seed.md is corrupted, all progress is lost"
  "memory tool disabled in this harness environment — using file-based memory (facts/*.md)"
)

for FACT in "${FACTS[@]}"; do
  TS=$(date '+%Y-%m-%dT%H:%M:%S%z')
  echo "| $TS | harness_learning | capability | seed.md | $FACT |" \
    >> "${HERMES_HOME}/harness/facts/learning-log.md"
done
```

## Skill automation
This skill runs at the end of every harness cycle:
1. Read seed.md / recommendation.md / execution-log.md
2. Extract new facts (regex-based)
3. Append to `facts/learning-log.md`
4. Cross-check failure patterns in `facts/enforcement-log.md`

## Cron integration
```bash
# Append-only fact writes — no external memory tool dependency
TS=$(date '+%Y-%m-%dT%H:%M:%S%z')
{
  echo "| ${TS} | harness_learning | capability | seed.md | <extracted fact> |"
} >> "${HERMES_HOME}/harness/facts/learning-log.md"
```

## Backwards compatibility (v1.4.0 → v1.5.0)
- v1.4.0 `memory(action='add', ...)` calls → v1.5.0 `>> facts/learning-log.md` append
- `facts-cleanup.sh` retention (7d delete / 30d archive) preserves long-term patterns
- `session_search` / `read_file` remain the query path — Hermes agent scans `facts/*.md`

## Validation criteria
- [x] Fact extraction from seed.md runs (bash for-loop, regex-based)
- [x] **Append to `facts/learning-log.md`** for durable storage (memory tool NOT used)
- [x] Next cycle can query via `read_file` / `session_search`
- [x] `facts-cleanup.sh` retention policy (7d / 30d) integrated

## Environment
- `HERMES_HOME` — root of the framework (default `~/hermes-harness` or `C:\Users\<user>\hermes-harness`)
- All paths in this skill use `${HERMES_HOME}/harness/...` — never hardcoded
