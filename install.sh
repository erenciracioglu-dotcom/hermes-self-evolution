#! /usr/bin/env bash
# install.sh — One-shot setup for the hermes-self-evolution framework.
#
# Wires up four cron jobs (Evolution, Critic, Verifier, Gardener) against
# a local Hermes instance (tested against Hermes v0.19.0 schema).
# Idempotent: re-running skips jobs that already exist with matching
# prompt/mode.
#
# SECURITY model (v2):
#   - The Evolution cron does NOT modify constitution.md directly.
#     Constitutional amendments are proposal-only: agents draft into
#     facts/amendment-proposal.md, humans review and git-commit.
#   - execution-loop.sh no longer evaluates LLM-written strings
#     (allowlist dispatch only). See scripts/execution-loop.sh.
#
# Usage:
#   HERMES_BIN=hermes CHAT_ID=12345 bash install.sh
#
# Required environment variables:
#   HERMES_BIN   absolute path to the hermes CLI binary (or just "hermes"
#                if it is on PATH)
#   CHAT_ID      Telegram chat ID where Telegram delivery is wired
#
# Optional environment variables (with defaults):
#   HERMES_HOME          root of the framework
#                        default: ~/hermes-harness (POSIX) or %USERPROFILE%\hermes-harness (Windows)
#   MODEL_EVOLUTION      model name for Evolution (e.g. grok-4.5, gpt-5, claude-sonnet-4)
#                        default: MODEL_EVOLUTION
#   MODEL_CRITIC         model name for Critic — RECOMMEND different from Evolution
#                        default: MODEL_CRITIC
#   MODEL_VERIFIER       default: same as MODEL_EVOLUTION
#   MODEL_GARDENER       default: same as MODEL_EVOLUTION
#   CRON_EVOLUTION       cron expression, default "0 */4 * * *"
#   CRON_CRITIC          cron expression, default "2 */4 * * *"
#   CRON_VERIFIER        default "0 4 */2 * *"
#   CRON_GARDENER        default "0 4 1,8,15,22 * *"
#   PROPOSAL_ONLY_AMEND  "true" (default) requires human git-commit on
#                        constitution.md changes. Set to "false" only if
#                        you have a separate audit mechanism.

set -euo pipefail

if [[ -z "${HERMES_HOME:-}" ]]; then
    if [[ -n "${USERPROFILE:-}" ]]; then
        HERMES_HOME="${USERPROFILE}/hermes-harness"
    else
        HERMES_HOME="${HOME}/hermes-harness"
    fi
fi

HARNESS_DIR="${HERMES_HOME}/harness"

: "${HERMES_BIN:?HERMES_BIN is required (path to hermes CLI)}"
: "${CHAT_ID:?CHAT_ID is required (Telegram chat ID for delivery)}"

MODEL_EVOLUTION="${MODEL_EVOLUTION:-MODEL_EVOLUTION}"
MODEL_CRITIC="${MODEL_CRITIC:-MODEL_CRITIC}"
MODEL_VERIFIER="${MODEL_VERIFIER:-${MODEL_EVOLUTION}}"
MODEL_GARDENER="${MODEL_GARDENER:-${MODEL_EVOLUTION}}"
CRON_EVOLUTION="${CRON_EVOLUTION:-0 */4 * * *}"
CRON_CRITIC="${CRON_CRITIC:-2 */4 * * *}"
CRON_VERIFIER="${CRON_VERIFIER:-0 4 */2 * *}"
CRON_GARDENER="${CRON_GARDENER:-0 4 1,8,15,22 * *}"
PROPOSAL_ONLY_AMEND="${PROPOSAL_ONLY_AMEND:-true}"

if [[ "${PROPOSAL_ONLY_AMEND}" != "true" && "${PROPOSAL_ONLY_AMEND}" != "false" ]]; then
    echo "ERROR: PROPOSAL_ONLY_AMEND must be 'true' or 'false' (got: ${PROPOSAL_ONLY_AMEND})" >&2
    exit 1
fi

echo "== hermes-self-evolution install (v2 — security hardened) =="
echo "  HERMES_HOME           = ${HERMES_HOME}"
echo "  HERMES_BIN            = ${HERMES_BIN}"
echo "  CHAT_ID               = ${CHAT_ID}"
echo "  MODEL_EVOLUTION       = ${MODEL_EVOLUTION}"
echo "  MODEL_CRITIC          = ${MODEL_CRITIC}"
echo "  MODEL_VERIFIER        = ${MODEL_VERIFIER}"
echo "  MODEL_GARDENER        = ${MODEL_GARDENER}"
echo "  PROPOSAL_ONLY_AMEND   = ${PROPOSAL_ONLY_AMEND}"
echo "  CRON_EVOLUTION        = ${CRON_EVOLUTION}"
echo "  CRON_CRITIC           = ${CRON_CRITIC}"
echo "  CRON_VERIFIER         = ${CRON_VERIFIER}"
echo "  CRON_GARDENER         = ${CRON_GARDENER}"
echo ""

# 1. Lay out the directory
mkdir -p "${HERMES_HOME}"
mkdir -p "${HARNESS_DIR}/facts"
mkdir -p "${HARNESS_DIR}/skills"
mkdir -p "${HARNESS_DIR}/scripts"
mkdir -p "${HARNESS_DIR}/prompts"

# 2. Verify required files exist
missing=0
for f in constitution.md scripts/execution-loop.sh scripts/harness-verify.sh \
         scripts/harness-gardener.sh scripts/skill-automation.sh \
         prompts/evolution.md prompts/critic.md \
         prompts/verifier.md prompts/gardener.md \
         skills/known-failure-triage-db.md skills/memory-enrichment.md \
         skills/harness-version-tracking.md; do
    if [[ ! -f "${HERMES_HOME}/${f}" ]]; then
        echo "MISSING: ${HERMES_HOME}/${f}" >&2
        missing=$((missing + 1))
    fi
done
if [[ $missing -gt 0 ]]; then
    echo "" >&2
    echo "Framework files are missing from ${HERMES_HOME}." >&2
    echo "Copy the contents of this repository into ${HERMES_HOME}/ preserving" >&2
    echo "the directory layout, then re-run install.sh." >&2
    exit 1
fi

# 3. Touch runtime log files referenced by execution-loop.sh and prompts.
# v1.1: every file referenced by a prompt or script MUST exist on first run.
# See hendrixfreire/hermes-self-evolution-review §1.3 (missing files).
for f in recommendation.md witness-log.md predictions.md prediction-outcomes.md \
         harness-state.md cleanup-log.md credential-health.log \
         critique-log.md decision-log.md execution-log.md amendment-proposal.md \
         enforcement-log.md learning-log.md; do
    [[ -f "${HARNESS_DIR}/facts/${f}" ]] || touch "${HARNESS_DIR}/facts/${f}"
done

# 4. Helper: create or skip a cron job.
#    Hermes v0.19.0 schema: prompts are passed inline (NOT via --prompt-file).
#    model + provider are separate parameters. See
#    tools/cronjob_tools.py: cronjob(action='create', schedule=..., model=..., provider=..., prompt=...)
create_or_skip() {
    local name="$1"
    local schedule="$2"
    local model="$3"
    local provider="$4"
    local prompt_file="$5"

    if ${HERMES_BIN} cron list 2>/dev/null | grep -q "name: ${name}"; then
        echo "  SKIP: ${name} already exists"
        return 0
    fi

    # Inline the prompt body — Hermes v0.19.0 cron.create does not support
    # --prompt-file. We read the file and pass it via --prompt instead.
    local prompt_body
    prompt_body=$(cat "${HERMES_HOME}/${prompt_file}")

    # HERMES_HOME, CHAT_ID, and PROPOSAL_ONLY_AMEND are exported so the
    # prompt body can reference them at run time.
    HERMES_HOME="${HERMES_HOME}" \
    CHAT_ID="${CHAT_ID}" \
    PROPOSAL_ONLY_AMEND="${PROPOSAL_ONLY_AMEND}" \
    HERMES_BIN="${HERMES_BIN}" \
    ${HERMES_BIN} cron create \
        --name "${name}" \
        --schedule "${schedule}" \
        --model "${model}" \
        --provider "${provider}" \
        --prompt "${prompt_body}" \
        --deliver "telegram:${CHAT_ID}"
    echo "  CREATED: ${name}"
}

echo "Creating cron jobs..."
create_or_skip "Harness Evolution" "${CRON_EVOLUTION}" "${MODEL_EVOLUTION}" "${MODEL_EVOLUTION_PROVIDER:-openrouter}" "prompts/evolution.md"
create_or_skip "Harness Critic"    "${CRON_CRITIC}"    "${MODEL_CRITIC}"    "${MODEL_CRITIC_PROVIDER:-openrouter}"    "prompts/critic.md"
create_or_skip "Harness Verifier"  "${CRON_VERIFIER}"  "${MODEL_VERIFIER}"  "${MODEL_VERIFIER_PROVIDER:-openrouter}"  "prompts/verifier.md"
create_or_skip "Harness Gardener"  "${CRON_GARDENER}"  "${MODEL_GARDENER}"  "${MODEL_GARDENER_PROVIDER:-openrouter}"  "prompts/gardener.md"

# 5. Write the initial harness-state.md
cat > "${HARNESS_DIR}/facts/harness-state.md" <<EOF
## State — $(date -Iseconds)
- Last cycle: (none yet — first run after install)
- Last verdict: (none yet)
- Last commit: (none yet)
- Unaddressed critiques: 0
- Stale predictions: 0
- Active skills: $(ls "${HARNESS_DIR}/skills/"*.md 2>/dev/null | wc -l)
- Dormant skills: 0
- PROPOSAL_ONLY_AMEND: ${PROPOSAL_ONLY_AMEND}
EOF

echo ""
echo "== install complete =="
echo "Next steps:"
echo "  1. Tail ${HARNESS_DIR}/facts/execution-log.md to watch the first Evolution cycle"
echo "  2. After the first cycle, check ${HARNESS_DIR}/facts/witness-log.md and replace"
echo "     the seed entries with your own real friction entries"
echo "  3. Review ${HARNESS_DIR}/facts/amendment-proposal.md for any constitutional"
echo "     amendments the agents propose (PROPOSAL_ONLY_AMEND=${PROPOSAL_ONLY_AMEND})"
echo "  4. Tune schedule and models per README.md 'Tuning' section"