# Git Hooks — Automatic Knowledge Graph Updates

This directory contains git hooks that keep the knowledge graph synchronized with code changes automatically.

## What's Here

| File | Purpose |
|---|---|
| `pre-commit` | Runs before every commit — detects changes and updates graph |
| `install.ps1` | Installs the hook into `.git/hooks/` |

## Quick Start

```powershell
# Install the hook
pwsh .github/hooks/install.ps1

# Uninstall (if needed)
pwsh .github/hooks/install.ps1 -Uninstall
```

After installation, the hook runs automatically on every commit.

## How It Works

### Detection

The pre-commit hook scans staged files and detects:

| Change Type | Files Matched | Action Triggered |
|---|---|---|
| **New skill** | `.github/skills/*/SKILL.md` | Auto-discover |
| **New CLI tool** | `.github/knowledge-graph/cli/*.ps1` | Auto-discover |
| **New module** | `.github/knowledge-graph/lib/*.psm1` | Auto-discover + extract |
| **New extension** | `extensions/*/package.json` | Auto-discover |
| **Code changes** | `*.ts`, `*.tsx`, `*.ps1`, `*.psm1`, `*.cs` | Extract |

### Processing

When changes are detected, the hook runs:

1. **Auto-discover** (if needed) — Finds new features, skills, CLI tools, modules, extensions
2. **Extract** (if code changed) — Parses code artifacts into code graph
3. **Merge** — Combines system + code graphs into merged graph
4. **Fix dangling edges** — Auto-repairs references
5. **Verify health** — Ensures graph is fully connected with zero failures
6. **Stage graph files** — Adds updated graphs to your commit

**Health Check Gate:** The hook will **block the commit** if:
- Dangling edges cannot be fixed
- Graph health check reports any failures
- Critical connectivity warnings remain

This ensures every commit maintains a fully healthy, connected graph.

### Efficiency

- **Incremental only** — Only processes what changed, skips full rebuild
- **Fast** — Typically completes in 2-5 seconds
- **Idempotent** — Safe to run multiple times, won't duplicate nodes/edges

## What Gets Committed

When you commit changes that affect the graph, your commit will include:

```
✓ Your original changes (code, SKILL.md, etc.)
✓ .github/knowledge-graph/data/system/mentor-graph.json (if system changes)
✓ .github/knowledge-graph/data/code/code-graph.json (if code changes)
✓ .github/knowledge-graph/merged-graph.json (always)
```

The hook adds these files to your commit automatically — no manual `git add` needed.

## Example Output

```
🔍 Checking staged files...
  Detected changes: skill, CLI tool

🔎 Running auto-discovery...
✓ System graph updated

🔗 Merging graph layers...
✓ Graphs merged

🔧 Fixing dangling edges...
✓ Fixed 2 dangling edges

✅ Verifying graph health...
✓ Graph health: PASS 5 | WARN 0 | FAIL 0

➕ Staging graph updates...
  Staged: mentor-graph.json
  Staged: merged-graph.json
✓ Graph is up to date and staged
```

## Bypass (Emergency)

If you need to commit without running the hook:

```bash
git commit --no-verify -m "Emergency fix"
```

Use sparingly — the graph will be out of sync until you run a manual rebuild.

## Troubleshooting

### Hook doesn't run

Check installation:
```powershell
Test-Path .git/hooks/pre-commit  # Should return True
```

Re-install:
```powershell
pwsh .github/hooks/install.ps1
```

### Hook fails on commit

Run manually to see full error:
```powershell
pwsh .github/hooks/pre-commit
```
If health check blocks the commit:
```powershell
# View detailed health report
pwsh .github/knowledge-graph/build/core/health.ps1

# Fix dangling edges manually
pwsh .github/knowledge-graph/build/fix-dangling-edges.ps1

# Run full rebuild if needed
pwsh .github/knowledge-graph/build/rebuild-if-stale.ps1
```
### Graph out of sync

Run full rebuild:
```powershell
pwsh .github/knowledge-graph/build/rebuild-if-stale.ps1
```

## Design Principles

1. **Everything in the graph** — All features, skills, CLI tools, modules, extensions must be discoverable
2. **No manual scripts** — Convention-based discovery eliminates the need for add-feature-X.ps1 scripts
3. **Commit what you change** — Graph updates are part of the same commit as the code that triggered them
4. **Fast feedback** — Hook completes in seconds, doesn't block your workflow
5. **Safe to bypass** — Use `--no-verify` if you need to commit without graph updates (emergency only)

## Related Files

- `.github/knowledge-graph/data/system/auto-discover-features.ps1` — Convention-based discovery
- `.github/knowledge-graph/data/code/extract.ps1` — Code artifact extraction
- `.github/knowledge-graph/build/merge.ps1` — Graph layer merger
- `.github/knowledge-graph/build/fix-dangling-edges.ps1` — Auto-repair dangling references
- `.github/knowledge-graph/build/rebuild-if-stale.ps1` — Full rebuild (manual)
