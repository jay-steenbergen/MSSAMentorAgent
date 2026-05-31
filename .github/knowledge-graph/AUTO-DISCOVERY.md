# Knowledge Graph Auto-Discovery System

**Problem Solved:** Previously, adding new components to the Mentor agent required creating one-off scripts like `add-feature-6-and-7.ps1`. This doesn't scale.

**Solution:** Automatic discovery and extraction for all new components.

---

## How It Works Now

### **1. Code Graph (Automatic Extraction)**

The `data/code/extract.ps1` script now automatically discovers and indexes:

**New Locations Scanned:**
- ✅ `.github/knowledge-graph/lib/` - PowerShell modules
- ✅ `.github/knowledge-graph/cli/` - CLI scripts  
- ✅ `extensions/` - VS Code extensions
- ✅ TypeScript files (`.ts`, `.tsx`)

**What It Extracts:**
- File nodes for all tracked files
- Function nodes from PowerShell, TypeScript, C#
- Import/dependency edges
- Parameter nodes
- Sections from markdown files

**Example:** When you add a new CLI script like `show-progress.ps1`, it's automatically:
1. Discovered on next rebuild
2. Added as a `code-file` node
3. Functions inside it extracted as `code-func` nodes
4. Edges created showing what it calls

---

### **2. System Graph (Pattern-Based Discovery)**

The new `data/system/auto-discover-features.ps1` script automatically finds:

**CLI Tools:**
- Scans `.github/knowledge-graph/cli/*.ps1`
- Creates `cli-tool:` nodes
- Connects to `agent:mentor` with `uses` edge

**PowerShell Functions:**
- Scans `.github/knowledge-graph/lib/*.psm1`
- Extracts exported functions from `Export-ModuleMember`
- Creates `code-func:` nodes for each export

**VS Code Extensions:**
- Scans `extensions/*/package.json`
- Creates `extension:` nodes
- Uses package.json description for metadata
- Connects to `agent:mentor` with `extends` edge

**Idempotent:** Only adds nodes/edges that don't already exist. Safe to run repeatedly.

---

### **3. Automated Rebuild Pipeline**

The `build/core/rebuild-if-stale.ps1` orchestrator now runs a 5-step process:

```
[0/5] Auto-discover features (system graph)
       ↓
[1/5] Extract code graph
       ↓
[2/5] Merge layers (system + code → merged)
       ↓
[3/5] Health check
       ↓
[4/5] Gap analysis
```

**Trigger:** Runs automatically when:
- Source files modified after last build
- Build scripts modified
- `merged-graph.json` missing
- `-Force` flag used

**Called by:** The `query.psm1` module calls this automatically when loading the graph (see `Get-KnowledgeGraph` function).

---

## Usage

### **Adding New Components**

**Just create the files — no extra scripts needed:**

```powershell
# Add a new CLI tool
New-Item .github/knowledge-graph/cli/my-new-tool.ps1

# Add a new VS Code extension
mkdir extensions/my-extension
New-Item extensions/my-extension/package.json

# Add a new PowerShell function to query.psm1
function Get-MyNewFeature { ... }
Export-ModuleMember -Function Get-MyNewFeature
```

**The graph updates automatically** next time it's loaded or rebuilt.

---

### **Manual Rebuild**

Force a rebuild anytime:

```powershell
pwsh .github/knowledge-graph/build/core/rebuild-if-stale.ps1 -Force
```

Test discovery only (dry-run):

```powershell
pwsh .github/knowledge-graph/data/system/auto-discover-features.ps1 -DryRun
```

---

### **Check What's New**

After adding files, see what was discovered:

```powershell
pwsh .github/knowledge-graph/data/system/auto-discover-features.ps1 -DryRun
# Shows what WOULD be added (preview)

pwsh .github/knowledge-graph/data/system/auto-discover-features.ps1
# Actually adds the nodes
```

---

## Files Changed

### **Modified:**
- ✅ `data/code/extract.ps1` - Added extensions/, lib/, cli/ scanning + TypeScript parser
- ✅ `build/core/rebuild-if-stale.ps1` - Added Step 0 auto-discovery

### **Created:**
- ✅ `data/system/auto-discover-features.ps1` - Pattern-based feature discovery

### **Deleted:**
- ❌ `data/system/add-feature-6-and-7.ps1` (one-off, no longer needed)
- ❌ `data/code/add-feature-6-and-7.ps1` (one-off, no longer needed)

---

## Before vs After

### **Before** (Manual Process):
```powershell
# Every time you add a feature:
1. Create add-feature-X.ps1 script
2. Manually list all nodes to add
3. Manually list all edges to add
4. Run the script
5. Run rebuild-if-stale.ps1
6. Delete or keep the one-off script (clutter)
```

### **After** (Automatic):
```powershell
# Just create the files:
1. Add your code/extension/CLI tool
2. (Optional) Run rebuild-if-stale.ps1 -Force
3. Done — graph is updated
```

---

## Conventions to Follow

For auto-discovery to work, follow these conventions:

**CLI Tools:**
- Place in `.github/knowledge-graph/cli/`
- Use `.ps1` extension
- Avoid `add-*.ps1` or `auto-*.ps1` prefixes (reserved for internal tools)

**PowerShell Functions:**
- Place in `.github/knowledge-graph/lib/*.psm1`
- Export via `Export-ModuleMember -Function YourFunction`

**VS Code Extensions:**
- Place in `extensions/{extension-name}/`
- Include `package.json` with `name` and `description` fields

**TypeScript Functions:**
- Use standard patterns: `export function name()` or `const name = () => {}`
- Relative imports will be tracked

---

## Limitations

**Not Auto-Discovered:**
- High-level feature concepts (need manual `feature:` nodes in system graph)
- Relationships between features (need manual edges)
- Skill recommendations (need manual `recommends` edges)

**Workaround:** For complex features, you can still add manual nodes/edges to `data/system/mentor-graph.json`, but the code-level implementation will be auto-discovered.

---

## Result

**Before:** 20-minute manual process to add a feature to the graph.  
**After:** 0 seconds — it happens automatically.

The graph stays in sync with your codebase without manual intervention.
