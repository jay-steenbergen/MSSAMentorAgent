# Knowledge Graph Gap Analysis
**Date:** May 30, 2026  
**Graph Size:** 1,233 nodes | 1,283 edges  
**Status:** ⚠️ 11 issues found

---

## 🔴 Critical Issues (Must Fix)

### 1. Dangling Edges (4 edges → 3 missing nodes)

| From | Edge Type | To (MISSING) | Impact |
|---|---|---|---|
| `cli-tool:show-progress` | `calls` | `code-func:Get-LearnerProgress` | CLI tool references non-existent function |
| `feature:hybrid-loading` | `optimizes` | `rule:dynamic-skill-loading` | Feature references non-existent rule |
| Unknown | Unknown | `code-func:Get-AgentLoadList` | Function reference exists but node missing |

**Root Cause:**  
System graph (mentor-graph.json) references nodes that should exist in the code graph but were never extracted.

**Fix:**
```powershell
# Option 1: Add missing nodes to system graph (if they're conceptual)
# Edit .github/knowledge-graph/data/system/mentor-graph.json

# Option 2: Create the actual code (if they should be implemented)
# Create .github/knowledge-graph/lib/profile.psm1 with Get-LearnerProgress
# Create .github/knowledge-graph/lib/query.psm1 with Get-AgentLoadList

# Option 3: Remove the dangling edges (if references are stale)
# Edit system graph to remove edges pointing to non-existent nodes
```

---

### 2. Orphan Nodes (7 nodes with 0 edges)

| Node ID | Type | Why Orphaned |
|---|---|---|
| `code-file:.github/knowledge-graph/cli/audit-quality.ps1` | code-file | File discovered but no relationships |
| `code-file:.github/knowledge-graph/cli/check-skill-exists.ps1` | code-file | File discovered but no relationships |
| `code-file:.github/knowledge-graph/cli/recommend-next-skills.ps1` | code-file | File discovered but no relationships |
| `code-file:.github/knowledge-graph/cli/show-progress.ps1` | code-file | File discovered but no relationships |
| `code-file:.github/knowledge-graph/cli/show-skill-impact.ps1` | code-file | File discovered but no relationships |
| 1 more code-file | code-file | Unknown |
| `code-func:@(` | code-func | Parsing error (invalid function name) |

**Root Cause:**  
Code extraction (extract.ps1) creates file nodes but doesn't create edges connecting them to their parent CLI tools.

**Fix:**
```powershell
# In extract.ps1, when creating cli-tool nodes, also add:
Add-Edge "cli-tool:$toolName" "code-file:$filePath" 'implemented_by'
```

---

## 🟡 Logical Gaps (Should Fix)

### 3. CLI Tools Not Connected to Skills (5 tools)

All CLI tools have **NO** `invokes` edges to skills:

- `show-progress.ps1` - should invoke `skill:learner-profile`
- `audit-quality.ps1` - should invoke skill for quality checks
- `check-skill-exists.ps1` - should invoke skill validation
- `recommend-next-skills.ps1` - should invoke recommendation engine
- `show-skill-impact.ps1` - should invoke analytics skill

**Root Cause:**  
CLI tools were auto-discovered and connected to `agent:mentor`, but no edges were created showing which skills they invoke.

**Fix:**
```powershell
# In auto-discover-features.ps1, add logic to infer skill relationships:
# - Parse CLI script for Import-Module or skill file reads
# - Add 'invokes' edges from cli-tool to skill nodes
```

---

### 4. Features Without Implementation (2 features)

| Feature | Description | Missing |
|---|---|---|
| `feature:progress-dashboard` | Progress Dashboard | No `implemented_by` edges |
| `feature:hybrid-loading` | Hybrid Runtime Integration | No `implemented_by` edges |

**Root Cause:**  
Features were added to system graph manually, but no edges were created connecting them to their implementations (CLI tools, extensions, modules).

**Fix:**
```powershell
# In .github/knowledge-graph/data/system/mentor-graph.json, add edges:
{
  "source": "feature:progress-dashboard",
  "target": "cli-tool:show-progress",
  "type": "implemented_by"
}
{
  "source": "feature:hybrid-loading",
  "target": "extension:mentor-context-loader",
  "type": "implemented_by"
}
```

---

### 5. Extension Not Connected to Agent (1 extension)

`extension:mentor-context-loader` has **NO** `extends` edge to `agent:mentor`.

**Root Cause:**  
Auto-discovery script (auto-discover-features.ps1) creates extension nodes but the `extends` edge creation may have failed.

**Fix:**
```powershell
# In auto-discover-features.ps1, verify this line executes:
Add-Edge $extId 'agent:mentor' 'extends'
```

---

### 6. Parsing Error (1 node)

`code-func:@(` is an invalid function name — likely a regex parsing error in extract.ps1.

**Root Cause:**  
PowerShell function extraction regex matched a false positive (array syntax `@(` interpreted as function name).

**Fix:**
```powershell
# In extract.ps1, improve function regex to exclude:
# - Array literals: @(
# - Hash tables: @{
# - Special variables: $@

# Current pattern:
'(?m)^\s*function\s+([A-Za-z_][A-Za-z0-9_-]*)'

# Should exclude @ at start or require valid identifier pattern
```

---

## 📊 Summary by Priority

| Priority | Issue | Count | Impact |
|---|---|---|---|
| **P0** | Dangling edges | 4 | Breaks graph queries, references non-existent nodes |
| **P1** | Orphan CLI files | 6 | Files exist but unreachable via graph traversal |
| **P1** | CLI tools without skills | 5 | Can't trace CLI → skill relationships |
| **P2** | Features without impl | 2 | Can't find code for features |
| **P2** | Extension not connected | 1 | Extension exists but not linked to agent |
| **P3** | Parsing error | 1 | Noise node, doesn't break anything |

---

## 🔧 Recommended Fixes (In Order)

### Phase 1: Fix Critical Dangling Edges
**Time:** 15 minutes  
**Action:** Decide per edge:
- Remove stale reference, OR
- Create missing node, OR  
- Implement missing code

### Phase 2: Connect Orphan CLI Files
**Time:** 10 minutes  
**Action:** Modify `extract.ps1` to add `implemented_by` edges from `cli-tool:` nodes to their `code-file:` nodes.

### Phase 3: Connect CLI Tools to Skills
**Time:** 30 minutes  
**Action:** Modify `auto-discover-features.ps1` to infer skill invocations by parsing CLI scripts for skill file reads or module imports.

### Phase 4: Connect Features to Implementations
**Time:** 5 minutes  
**Action:** Add 2 edges in `system/mentor-graph.json`:
- `feature:progress-dashboard` → `cli-tool:show-progress`
- `feature:hybrid-loading` → `extension:mentor-context-loader`

### Phase 5: Fix Extension Connection
**Time:** 5 minutes  
**Action:** Debug why `auto-discover-features.ps1` didn't create the `extends` edge. Re-run auto-discovery.

### Phase 6: Fix Parsing Error
**Time:** 10 minutes  
**Action:** Improve regex in `extract.ps1` to exclude false positives like `@(`.

---

## 📈 Expected Results After Fixes

| Metric | Before | After | Change |
|---|---|---|---|
| Dangling edges | 4 | 0 | -4 ✅ |
| Orphan nodes | 7 | 1 | -6 ✅ |
| CLI tools with skills | 0 | 5 | +5 ✅ |
| Features with impl | 0 | 2 | +2 ✅ |
| Parsing errors | 1 | 0 | -1 ✅ |

**Total issues:** 11 → 1 (parsing error may remain if low priority)

---

## 🧪 Validation Commands

After fixes, run:

```powershell
# 1. Check dangling edges
pwsh .github/knowledge-graph/build/core/health.ps1 -Layer merged

# 2. Check orphans
pwsh .github/knowledge-graph/build/gap-analysis.ps1 -Layer merged

# 3. Query specific relationships
pwsh .github/knowledge-graph/cli/query-graph.ps1 -From "cli-tool:show-progress" -Depth 2

# 4. Rebuild and verify
pwsh .github/knowledge-graph/build/core/rebuild-if-stale.ps1 -Force
```

---

## 📝 Notes

- **Auto-discovery is working** — files and functions are being found
- **Manual edges are missing** — relationships between layers need to be defined
- **Extract.ps1 needs enhancement** — should create more edges during extraction
- **System graph is stale** — references nodes that don't exist yet (or never will)

The graph is structurally valid (no crashes) but semantically incomplete (missing logical relationships).
