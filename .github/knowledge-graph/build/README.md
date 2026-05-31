# Knowledge Graph Build Scripts

**START HERE** if you're maintaining or building the knowledge graph.

---

## Quick Start

**First time?** Run this:
```powershell
.\core\rebuild-if-stale.ps1
```

**After making changes?** The pre-commit hook runs automatically. Or manually:
```powershell
.\core\extract-code-graph.ps1   # Extract code structure
.\core\merge.ps1                 # Merge all graph fragments
.\core\health.ps1                # Validate the graph
```

**Graph broken?** See [Repair Scripts](#repair-scripts) below.

---

## Daily Workflow (Core Scripts)

These are the scripts you'll use most:

| Script | What it does | When to run |
|---|---|---|
| **rebuild-if-stale.ps1** | Checks if code changed, rebuilds if needed | First run of the day |
| **extract-code-graph.ps1** | Scans code, creates graph fragments | After adding/moving files |
| **merge.ps1** | Combines all fragments into one graph | After extraction |
| **health.ps1** | Validates graph integrity | After merge, before commit |

**Typical flow:**
```
Code changes → Extract → Merge → Health check → Commit
```

The pre-commit hook runs this automatically.

---

## Repair Scripts

**When the health check fails**, these fix common issues:

| Script | Fixes | Run when |
|---|---|---|
| **fix-dangling-edges.ps1** | Edges pointing to missing nodes | Health reports dangling edges |
| **fix-remaining-gaps.ps1** | Missing descriptions, incomplete data | Health reports gaps |

**Example:**
```powershell
# Health check failed with dangling edges
.\repair\fix-dangling-edges.ps1
.\core\merge.ps1   # Re-merge after fix
.\core\health.ps1  # Verify
```

---

## Advanced Scripts

**For graph maintenance and scaffolding:**

| Script | What it does | When you need it |
|---|---|---|
| **scaffold-node-type.ps1** | Generate template for new node types | Adding new graph concepts |
| **split-code-graph.ps1** | Break large graph into smaller fragments | Graph file too large |
| **auto-discover-features.ps1** | Find features in code, add to graph | Initial setup, major refactor |
| **add-tracks-and-skills.ps1** | Add MSSA tracks/skills to graph | New curriculum content |
| **extract-infrastructure.ps1** | Extract build system structure | Analyzing build dependencies |
| **generate-call-flow-nodes.ps1** | Create call flow documentation | Understanding script relationships |
| **gap-analysis.ps1** | Find missing graph data | Quality audit |
| **audit-system-graph.ps1** | Full graph validation | Before major release |

---

## Understanding the Graph

The knowledge graph maps how everything in this repo connects:

- **Nodes:** Files, functions, skills, tracks, tests, concepts
- **Edges:** Calls, uses, implements, tests, related_to

**Query examples:**
```powershell
# See what calls a script
..\queries\Get-CallFlow.ps1 -NodeName "merge.ps1"

# Find skills related to a track
..\queries\Get-Related.ps1 -NodeName "track:cloud-app-dev" -EdgeType "contains"
```

---

## Folder Structure

```
build/
├── README.md          ← You are here
├── core/              ← Daily workflow scripts
├── repair/            ← Fix broken graphs
└── advanced/          ← Scaffolding & utilities
```

---

## Troubleshooting

**"Node not found" errors:**
- Run `.\repair\fix-dangling-edges.ps1`
- Check if the file was deleted or moved

**"Graph is stale" warnings:**
- Run `.\core\rebuild-if-stale.ps1`
- Or manually: extract → merge → health

**"Missing description" errors:**
- Run `.\repair\fix-remaining-gaps.ps1`
- Or manually add descriptions to nodes in the graph JSON

**Pre-commit hook failing:**
- Check `.\core\health.ps1` output
- Fix reported issues
- Re-run health check
- Commit again

---

## Need Help?

- **Graph architecture:** See `.github/knowledge-graph/README.md`
- **Query examples:** See `.github/knowledge-graph/queries/`
- **Add to graph:** Run `.\advanced\scaffold-node-type.ps1` for templates
