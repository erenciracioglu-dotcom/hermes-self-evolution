# Harness Version Tracking

## Purpose
Track versions of harness-created skills — which skill, what version, when updated.

## How it works
Version tracking is file-based. Each skill has a `.version` file next to it in the `harness/skills/` directory.

### Version file format (`<skill-name>.md.version`)
```
VERSION=1.0.0
CREATED=<ISO8601>
LAST_UPDATED=<ISO8601>
UPDATES=<int>
LAST_ACTION="<short action label>"
STATUS=active
```

## Version increment rules
- **Major (X.0.0):** Complete rewrite, new architecture
- **Minor (0.X.0):** New features, expanded capabilities
- **Patch (0.0.X):** Bug fix, documentation update

## Version tracking commands

### Check skill version
```bash
cat "${HERMES_HOME}/harness/skills/<skill-name>.md.version"
```

### Update skill version
```bash
# Read current version
VERSION=$(grep VERSION= "${HERMES_HOME}/harness/skills/<skill-name>.md.version" | cut -d= -f2)

# Increment minor (e.g. 1.0.0 → 1.1.0)
NEW_VERSION=$(echo "$VERSION" | awk -F. '{print $1"."$2+1".0"}')

# Update file
sed -i "s/VERSION=.*/VERSION=$NEW_VERSION/" \
  "${HERMES_HOME}/harness/skills/<skill-name>.md.version"
sed -i "s/LAST_UPDATED=.*/LAST_UPDATED=$(date -Iseconds)/" \
  "${HERMES_HOME}/harness/skills/<skill-name>.md.version"
```

## Skill version registry (`harness/skills/.registry`)
A generated index of all skills and their current version/status. Build with:

```bash
bash "${HERMES_HOME}/harness/scripts/skill-automation.sh" build_registry
```

The registry is regenerated automatically after each skill update. Sample format:

```markdown
# Harness Skill Version Registry

| Skill | Version | Status | Last Updated | Last Action |
|---|---|---|---|---|
| memory-enrichment.md | 1.0.0 | active | <ISO> | initial_created |
```

## Configuration
- `HERMES_HOME` — root of the framework; override if installed in a non-default location.
- All paths in this skill use `${HERMES_HOME}/harness/...`.
