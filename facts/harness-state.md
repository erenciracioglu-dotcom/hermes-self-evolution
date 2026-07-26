# Harness State

Initial state file for the framework. Evolution updates this on each
cycle with the current snapshot so a future cycle (or the human
operator) can see what changed.

## Schema
```
## State — <ISO8601>
- Last cycle: evolve-<N>
- Last verdict: HEALTHY | STAGNATION | DEGRADATION | GATE_HALT
- Last commit: <git SHA>
- Last recommendation: facts/recommendation.md
- Unaddressed critiques: <N>
- Stale predictions: <N> (past DUE, no verdict)
- Active skills: <N> (from skills/.registry)
- Dormant skills: <N> (>= 30 days, from gardener scan)
```

This file is regenerated each cycle. The first state is the
"installed" snapshot — write your installation timestamp here after
`install.sh` completes.
