#! /usr/bin/env bash
# execution-loop.sh — Harness Meta-Learner Execution Engine
#
# Reads facts/recommendation.md, dispatches the recommended action,
# records the outcome in facts/execution-log.md. This is the framework's
# central executor — invoked by the Evolution cron job.
#
# Configuration:
#   HERMES_HOME   root of the framework (default: $HOME/hermes-harness)
#   HARNESS_DIR   $HERMES_HOME/harness (override to relocate)
#   DISPATCH_UNUSED_DAYS  dormant-arm threshold (default 30)

set -euo pipefail

HERMES_HOME="${HERMES_HOME:-$HOME/hermes-harness}"
HARNESS_DIR="${HERMES_HOME}/harness"
SKILLS_DIR="${HARNESS_DIR}/skills"
FACTS_DIR="${HARNESS_DIR}/facts"
DECISION_LOG="${FACTS_DIR}/decision-log.md"
STATE_FILE="${FACTS_DIR}/harness-state.md"
RECOMMENDATION_FILE="${FACTS_DIR}/recommendation.md"
EXECUTION_LOG="${FACTS_DIR}/execution-log.md"

# --report-only: skip action execution, print observability report only
REPORT_ONLY=false
if [[ "${1:-}" == "--report-only" ]]; then
    REPORT_ONLY=true
    shift
fi

# ANSI color codes (disabled when not a TTY)
if [[ -t 1 ]]; then
    RED=$'\033[0;31m'
    GREEN=$'\033[0;32m'
    YELLOW=$'\033[1;33m'
    BLUE=$'\033[0;34m'
    NC=$'\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' NC=''
fi

log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%dT%H:%M:%S%z')]${NC} $1"
}
log_success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%dT%H:%M:%S%z')] ✓${NC} $1"
}
log_warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%dT%H:%M:%S%z')] ⚠${NC} $1"
}
log_error() {
    echo -e "${RED}[$(date '+%Y-%m-%dT%H:%M:%S%z')] ✗${NC} $1"
}

# Auto-discover case arms from skill-automation.sh SKILL_REGISTRY
# Lets execute_action() fall back to generic dispatch for unknown
# action types when the registry already knows about them.
_discover_case_arms() {
    local skill_auto="${HARNESS_DIR}/skill-automation.sh"
    if [[ ! -f "$skill_auto" ]]; then
        return 0  # silently skip — fall back to "*"
    fi
    grep -oE '^\s*\["[^"]+"\]=' "$skill_auto" \
        | sed -E 's/^\s*\[//; s/"\]=//; s/"//g' \
        | tr '\n' ' '
}

DISCOVERED_ARMS=""
_init_discovered_arms() {
    DISCOVERED_ARMS="$(_discover_case_arms)"
}

# Per-arm dispatch observability — surface "dead code" in the dispatcher.
DISPATCH_STATE_FILE="${FACTS_DIR}/.dispatch-state"
DISPATCH_UNUSED_DAYS="${DISPATCH_UNUSED_DAYS:-30}"

_record_dispatch() {
    local arm="$1"
    local now=$(date -Iseconds)
    mkdir -p "$(dirname "$DISPATCH_STATE_FILE")"
    if [[ -f "$DISPATCH_STATE_FILE" ]] && grep -q "^${arm} " "$DISPATCH_STATE_FILE" 2>/dev/null; then
        local next_total dispatch_tmp
        next_total=$(awk -v arm="$arm" '$1 == arm && $3 ~ /^[0-9]+$/ && $3 > max { max = $3 } END { print max + 1 }' "$DISPATCH_STATE_FILE")
        dispatch_tmp="${DISPATCH_STATE_FILE}.tmp.$$"
        if awk -v arm="$arm" '$1 != arm { print }' "$DISPATCH_STATE_FILE" > "$dispatch_tmp"; then
            printf '%s %s %s\n' "$arm" "$now" "$next_total" >> "$dispatch_tmp"
            mv -f "$dispatch_tmp" "$DISPATCH_STATE_FILE"
        else
            rm -f "$dispatch_tmp"
            log_warn "dispatch-state rewrite failed for arm '$arm'"
            return 1
        fi
    else
        echo "${arm} ${now} 1" >> "$DISPATCH_STATE_FILE"
    fi
}

_print_unused_arms() {
    if [[ ! -f "$DISPATCH_STATE_FILE" ]]; then
        log "observability: no dispatch history yet (cold start)"
        return 0
    fi
    local now_epoch=$(date +%s)
    local threshold=$((DISPATCH_UNUSED_DAYS * 86400))
    local unused_count=0
    # v1.1: drop the hardcoded known_arms string (review §1.4 — pure maintenance
    # debt). We only report arms we have actually dispatched, sourced from
    # DISPATCH_STATE_FILE itself.
    local dispatched_arms
    dispatched_arms=$(awk 'NF >= 3 && $1 !~ /^#/ { print $1 }' "$DISPATCH_STATE_FILE" | sort -u)
    for arm in $dispatched_arms; do
        [[ -z "$arm" ]] && continue
        local last_dispatched=$(grep "^${arm} " "$DISPATCH_STATE_FILE" | awk '{print $2}' | tail -1)
        local last_epoch
        # v1.1: portable date parser — GNU `date -d`, BSD `date -j -f`, then
        # stat mtime fallback. Silent failure mode removed (review §1.8).
        last_epoch=$(date -d "$last_dispatched" +%s 2>/dev/null) \
            || last_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S%z" "$last_dispatched" +%s 2>/dev/null) \
            || last_epoch=$(stat -c %Y "$DISPATCH_STATE_FILE" 2>/dev/null) \
            || last_epoch=$(stat -f %m "$DISPATCH_STATE_FILE" 2>/dev/null) \
            || { log_warn "observability: cannot parse timestamp for arm '$arm' — skipping"; continue; }
        local age=$((now_epoch - last_epoch))
        if [[ $age -gt $threshold ]]; then
            local days=$((age / 86400))
            log_warn "observability: arm '$arm' stale (${days}d since last dispatch)"
            unused_count=$((unused_count + 1))
        fi
    done
    if [[ $unused_count -eq 0 ]]; then
        log_success "observability: all arms exercised within ${DISPATCH_UNUSED_DAYS}d"
    fi
    return 0
}

# Parse the recommendation file. Single source of truth for field
# extraction (avoids regex drift across field names).
_parse_field() {
    local name="$1"
    awk -v name="$name" '
        tolower($0) ~ "^" tolower(name) ":" {
            sub(/^[^:]+:[ \t]*/, "")
            sub(/[ \t]+$/, "")
            print
            exit
        }
    ' "$RECOMMENDATION_FILE"
}

# Pre-execution guard: read external critique feedback (Article II).
# If Evolution has ignored a high/critical counter-recommendation,
# abort before executing further bookkeeping.
read-external-feedback() {
    local critique_log="${FACTS_DIR}/critique-log.md"
    [[ -f "$critique_log" ]] || { log "no critique-log.md — first run"; return 0; }

    local last_verdict last_severity last_action
    last_verdict=$(grep -E '^- (verdict|Verdict):' "$critique_log" | tail -1 | awk '{print $2}')
    last_severity=$(grep -E '^- (severity|Severity):' "$critique_log" | tail -1 | awk '{print $2}')
    last_action=$(grep -E '^- (action|Action):' "$critique_log" | tail -1 | awk '{print $2}')

    log "external feedback: verdict=${last_verdict:-NONE} severity=${last_severity:-NONE}"

    if [[ "${last_severity:-low}" =~ ^(critical|high)$ ]] \
        && [[ "${last_action:-NONE}" != "ADDRESSED" ]] \
        && grep -q "^## Critique Entry" "$critique_log"; then
        log_error "must_act=true — unaddressed ${last_severity} critique"
        echo "ABORTED: ${last_verdict:-unknown} ${last_severity} unaddressed" >&2
        return 2
    fi
    return 0
}

# Top-level execution — invoked as: bash execution-loop.sh evolve
main() {
    local cmd="${1:-evolve}"
    case "$cmd" in
        evolve)
            _init_discovered_arms
            _print_unused_arms
            if ! read-external-feedback; then
                return 2
            fi
            execute_action
            ;;
        report)
            _init_discovered_arms
            _print_unused_arms
            ;;
        *)
            log_error "unknown command: $cmd (use evolve|report)"
            return 1
            ;;
    esac
}

# Dispatcher: parse the recommendation, run the action, log the outcome.
execute_action() {
    [[ -f "$RECOMMENDATION_FILE" ]] || {
        log_error "no recommendation file at $RECOMMENDATION_FILE"
        return 1
    }

    local action_type action_detail action_confidence action_reasoning
    action_type=$(_parse_field "RECOMMENDED_ACTION")
    action_detail=$(_parse_field "DETAIL")
    action_confidence=$(_parse_field "CONFIDENCE")
    action_reasoning=$(_parse_field "REASONING")

    if [[ -z "$action_type" ]]; then
        log_error "could not parse RECOMMENDED_ACTION from recommendation"
        return 1
    fi

    log "action: type=${action_type} confidence=${action_confidence:-?}"
    log "detail: ${action_detail:0:80}"

    if [[ "$REPORT_ONLY" == "true" ]]; then
        log "REPORT_ONLY set — skipping action execution"
        _record_dispatch "${action_type}_report_only"
        return 0
    fi

    _record_dispatch "$action_type"

    # SECURITY (v1.1, hardened from v1): the LLM-written DETAIL field in
        # facts/recommendation.md is NEVER passed to bash. There is no `eval`
        # arm in this dispatcher. Each action_type maps to a fixed call into
        # skill-automation.sh or a fixed dispatcher script. To add a new action,
        # edit this case statement — never trust DETAIL.
        # (hendrixfreire/hermes-self-evolution-review §1.5 fix was already
        # applied in v2; this comment exists so the design choice is visible
        # to any future contributor who reads the file.)

    case "$action_type" in
        bash_command|generic_action|skill_automation*)
            log "delegating to skill-automation.sh (action_type)"
            bash "${HARNESS_DIR}/skill-automation.sh" "$action_type" 2>&1 | tail -15
            ;;
        update_script|create_skill|analyze|integrate_config|smoke_test|\
        facts-cleanup|cleanup_and_integration_test|backup_scheduler|backup-scheduler|\
        test_mechanism|version_bump|version_registry|skill_version_registry)
            log "delegating to skill-automation.sh (known action)"
            bash "${HARNESS_DIR}/skill-automation.sh" "$action_type" 2>&1 | tail -15
            ;;
        *)
            # Unknown action type — try the discovered-arms fallback
            if [[ " $DISCOVERED_ARMS " == *" $action_type "* ]]; then
                log "delegating to skill-automation.sh (discovered arm)"
                bash "${HARNESS_DIR}/skill-automation.sh" "$action_type" 2>&1 | tail -15
            else
                log_warn "unknown action_type '$action_type' — skipping (no eval, no shell)"
                return 0
            fi
            ;;
    esac

    local rc=$?
    if [[ $rc -eq 0 ]]; then
        log_success "action dispatched"
    else
        log_error "action failed with rc=$rc"
    fi
    return $rc
}

main "$@"
