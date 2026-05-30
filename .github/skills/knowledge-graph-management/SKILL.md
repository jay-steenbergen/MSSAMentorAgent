---
name: knowledge-graph-management
description: Interactive knowledge graph health monitoring and maintenance workflow. Runs health check, displays results, and offers actionable next steps.
---

# Knowledge Graph Management Skill

## Purpose

Provides an interactive workflow for checking knowledge graph health and taking action on issues. This skill:
- Runs health and gap analysis checks
- Displays results in a clear format
- Offers clickable action options based on findings
- Guides you through fixing issues

## When to use this skill

USE when:
- User asks to "check the graph"
- User wants to "manage the knowledge graph"
- User says "graph health"
- After making changes to skills, agents, or graph infrastructure
- When debugging graph connectivity issues

## Workflow

### Phase 1: Run Checks

Execute both health check and gap analysis:

```powershell
# Health check
pwsh -NoProfile -File .github/knowledge-graph/build/health.ps1 -Layer merged

# Gap analysis  
pwsh -NoProfile -File .github/knowledge-graph/build/gap-analysis.ps1 -Layer merged
```

### Phase 2: Display Summary

Present findings in this format:

```
========================================
 Knowledge Graph Status
========================================

📊 Stats:
  Nodes:    [count]
  Edges:    [count]
  Clusters: [count]

✅ Critical Checks:
  ✓/✗ Dangling edges:     [count]
  ✓/✗ Duplicate node IDs: [count]
  ✓/✗ Stub nodes:         [count]

⚠️  Warnings:
  • [warning details]

📋 Gaps:
  REAL GAP:       [count]
  EXPECTED:      [count]
  NEEDS REVIEW:  [count]
```

### Phase 3: Offer Actions

Based on findings, present clickable options using `vscode_askQuestions`:

**IF dangling edges > 0:**
```typescript
{
  header: "Dangling Edges Found",
  question: "Found X dangling edges. What would you like to do?",
  options: [
    { label: "Auto-fix", description: "Run fix-dangling-edges.ps1 to fix automatically" },
    { label: "Show details", description: "List all dangling edges" },
    { label: "Skip for now", description: "Continue to other issues" }
  ]
}
```

**IF orphan nodes > 0:**
```typescript
{
  header: "Orphan Nodes Found",
  question: "Found X orphan nodes (zero connections). What would you like to do?",
  options: [
    { label: "Show list", description: "See all orphan nodes" },
    { label: "Auto-discover connections", description: "Run extraction to find missing connections" },
    { label: "Skip for now", description: "Continue to other issues" }
  ]
}
```

**IF unclustered nodes > 0:**
```typescript
{
  header: "Unclustered Nodes Found",
  question: "Found X nodes without cluster assignments. What would you like to do?",
  options: [
    { label: "Show list", description: "See unclustered nodes" },
    { label: "Assign clusters", description: "Guide me through cluster assignment" },
    { label: "Skip for now", description: "Continue to other issues" }
  ]
}
```

**IF all checks pass:**
```typescript
{
  header: "Graph is Healthy",
  question: "All critical checks passed. What would you like to do next?",
  options: [
    { label: "Full rebuild", description: "Force rebuild with -Force flag" },
    { label: "View details", description: "Show full health report" },
    { label: "Done", description: "Exit graph management" }
  ]
}
```

### Phase 4: Execute Actions

**For "Auto-fix" (dangling edges):**
```powershell
pwsh -NoProfile -File .github/knowledge-graph/build/fix-dangling-edges.ps1
```
Then re-run Phase 1 to verify fixes.

**For "Show details" (any issue):**
Re-run the relevant check without `-Quiet` flag:
```powershell
pwsh -NoProfile -File .github/knowledge-graph/build/health.ps1 -Layer merged
```

**For "Auto-discover connections" (orphan nodes):**
```powershell
pwsh -NoProfile -File .github/knowledge-graph/build/rebuild-if-stale.ps1 -Force
```

**For "Assign clusters" (unclustered nodes):**
1. List unclustered nodes
2. For each node, show available clusters
3. Guide user to add cluster assignment in the appropriate graph file

**For "Full rebuild":**
```powershell
pwsh -NoProfile -File .github/knowledge-graph/build/rebuild-if-stale.ps1 -Force
```

**For "View details":**
Show the full output from Phase 1 (unfiltered).

## Action Loop

After executing an action:
1. Re-run Phase 1 (checks)
2. Display new summary
3. If issues remain, offer actions again
4. If all pass, offer "Done" option

Continue until user selects "Done" or "Skip for now" on all issues.

## Output Guidelines

- Use emojis for status: ✅ (pass), ✗ (fail), ⚠️ (warning), 📊 (stats), 📋 (list)
- Color-code terminal output: Green (pass), Red (fail), Yellow (warning), Cyan (headers)
- Keep summaries concise — details available on demand
- Always offer a way out ("Skip for now", "Done")
- Track state: which issues have been addressed, which remain

## Example Session

```
User: "check the graph"

Agent: [Runs checks]

========================================
 Knowledge Graph Status
========================================

📊 Stats:
  Nodes:    1249
  Edges:    1310
  Clusters: 16

✅ Critical Checks: All PASS
  ✓ Dangling edges: 0
  ✓ Duplicate IDs:  0

⚠️  Warnings:
  • 7 orphan nodes (CLI files)
  • 1 unclustered node

[Presents picker for orphan nodes]

User: [Selects "Show list"]

Agent: [Shows orphan nodes]
  - code-file:.github/knowledge-graph/cli/audit-quality.ps1
  - code-file:.github/knowledge-graph/cli/show-progress.ps1
  - ...

[Presents next action picker]

User: [Selects "Skip for now"]

[Moves to unclustered nodes picker]
```

## Integration Notes

- This skill works with the existing build pipeline scripts
- Does NOT modify graph files directly — delegates to existing tools
- Safe to run repeatedly — read-only checks, write-only on explicit user action
- Can be invoked standalone or as part of a development workflow

## Exit Criteria

Skill exits when:
- All critical checks pass AND user selects "Done"
- User selects "Skip for now" on all remaining issues
- User explicitly says "stop", "cancel", or "exit"
