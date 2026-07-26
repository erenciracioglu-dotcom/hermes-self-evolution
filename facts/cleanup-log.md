# Cleanup Log

Records `facts-cleanup.sh` invocations and what was archived/deleted.
Append-only.

## Format
```
## Cleanup Run — <ISO8601>
- Files deleted (>MAX_AGE_DAYS): <N>
- Files archived (>MAX_ARCHIVE_AGE_DAYS): <N>
- Total bytes freed: <N>
- Trigger: scheduled | manual
```
