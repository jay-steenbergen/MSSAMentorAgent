# Knowledge Graph Authoring Conventions

Rules for hand-editing `data/MentorAgent/system/mentor-graph.json` without tripping the pre-commit hook.

**Before every commit:** run `pwsh .github/knowledge-graph/cli/preflight.ps1`. It runs the same chain the hook runs (extract → merge → fix-dangling → health → drift) and reports all issues in one pass. If preflight is green, the commit will land.

## Node type conventions

| Type | `file:` attr | Notes |
|---|---|---|
| `behavior` | yes — `.github/agents/Mentor.agent.md` | Add `section:` field too (usually `"core_behavior (frontmatter)"`). Body lives in `cli/get-behavior.ps1` — both files must be updated atomically. |
| `concept` | yes — usually `.github/agents/Mentor.agent.md` | If it lives elsewhere, point `file:` at that file. |
| `level` | yes | The file that defines the proficiency ladder (e.g. an agent or skill md). |
| `rule` | yes | The file that contains the rule text. |
| `cli-tool` | yes — `.github/knowledge-graph/cli/<name>.ps1` | **The file must exist on disk before the graph references it.** Create the script (even as a stub that exits 0) in the same commit. |
| `field` | **NO** — omit `file:` entirely | Field nodes describe schema slots in profile JSON. Profile paths contain `{username}` templates that never resolve to a single disk file. Existing `field:profile.*` nodes all omit `file:`. |
| `data` | yes — point at the data file (`.json`, `.jsonl`) | Files under `knowledge-graph/data/` are excluded from extraction; drift checker disk-checks them. |

## Edge conventions

- Every node must have at least one edge or it's an **island** (blocks commit).
- Don't create dangling edges — both `source` and `target` must exist as node IDs in the graph after merge.
- The pre-commit hook auto-creates `defined_in` bridge edges from `cli-tool:*` → `code-file:*`. Don't add those manually.

## Path references in descriptions

The drift checker scans every string field in the system graph for path-like tokens and verifies each resolves to a real file.

- **Extracted files** (`.md`, `.ps1`, `.psm1`, `.json`, `.cs`, `.csproj`, `.ts`, `.tsx`) under indexed dirs resolve via `code-file:*` nodes.
- **Excluded dirs** (`knowledge-graph/data/`, `knowledge-graph/tests/`) are disk-checked — the file must exist on disk.
- **Templates** (`{username}`, `{project-id}`) are matched as wildcards against `code-file:*` IDs. They cannot be disk-checked.

If a description references a path that doesn't yet exist, either create the file in the same commit or rephrase the description.

## Cluster assignment

- New nodes need a `cluster:` field.
- The cluster ID must also appear in the graph's top-level `clusters[]` array.
- Reuse an existing cluster when topic matches; create a new one only if 3+ nodes share triggers no current cluster covers.

## The hook's silent surprises

These will look like the hook is rejecting valid edits — they aren't bugs in your edit:

1. **Auto-discovery runs first.** If you add a new `cli/*.ps1` or `lib/*.psm1`, the hook auto-adds a `cli-tool:` or other node before health checks. This is why a node you didn't add can suddenly appear.
2. **Extract → merge → dangling check happens after auto-discovery.** A `defined_in` edge the hook just created can fail the dangling check if the target `code-file:*` node hasn't been re-extracted yet. Running preflight ahead of time forces extraction so this never bites mid-commit.
3. **Stale-files check** fires when any node's `file:` attr points to a path not on disk. If you reference a future file, create the stub first.

## Recovery from a rejection

```pwsh
pwsh .github/knowledge-graph/cli/preflight.ps1   # see all issues at once
# fix issues
pwsh .github/knowledge-graph/cli/preflight.ps1   # confirm green
git add -A
git commit -m "..."
```

Bypassing the hook (`--no-verify`) is almost never the right answer — it's how the graph rots.
