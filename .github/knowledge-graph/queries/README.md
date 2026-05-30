# Knowledge Graph Query Scripts

PowerShell scripts for querying the MSSA Mentor knowledge graph. Used by the `knowledge-graph-management` skill to answer user questions.

## Available Scripts

| Script | Purpose | Example |
|---|---|---|
| `Get-CallFlow.ps1` | Trace execution path from a node | `.\Get-CallFlow.ps1 -NodeName "Mentor"` |
| `Get-Dependencies.ps1` | Show what a node uses | `.\Get-Dependencies.ps1 -NodeName "learner-profile"` |
| `Get-Dependents.ps1` | Show what uses a node | `.\Get-Dependents.ps1 -NodeName "query.psm1"` |
| `Get-SkillPath.ps1` | Find path between two nodes | `.\Get-SkillPath.ps1 -From "Mentor.agent.md" -To "query.psm1"` |
| `Get-SkillRecommendations.ps1` | Get skills for an intent | `.\Get-SkillRecommendations.ps1 -Intent "build a REST API"` || `Get-Subgraph.ps1` | Export subgraph for analysis | `.\Get-Subgraph.ps1 -RootNode "Mentor" -OutputFormat GraphML` |
## Usage Pattern

All scripts follow the same pattern:

```powershell
# From repo root
cd .github/knowledge-graph/queries

# Call any script
.\Get-CallFlow.ps1 -NodeName "Mentor"

# Pipe to JSON for programmatic use
.\Get-CallFlow.ps1 -NodeName "Mentor" -AsJson | ConvertFrom-Json
```

## Script Behavior

- **Fuzzy matching**: Node names are matched with `-like` patterns
- **Colored output**: Green for outgoing, Yellow for incoming, Gray for metadata
- **Exit codes**: 0 = success, 1 = node not found, 2 = invalid parameters
- **Structured output**: Use `-AsJson` flag for machine-readable output
- **Pre-computed call flows**: `Get-CallFlow.ps1` uses cached call-flow nodes when available (instant lookup)

## Pre-Computed Call Flows

Call flows are pre-computed during graph rebuild for instant lookup:

```powershell
# Generate call-flow nodes (run during graph rebuild)
pwsh .github/knowledge-graph/build/generate-call-flow-nodes.ps1

# Get-CallFlow.ps1 automatically uses pre-computed flows
.\Get-CallFlow.ps1 -NodeName "Mentor"  # Instant (uses cache)

# Force live traversal
.\Get-CallFlow.ps1 -NodeName "Mentor" -Force  # Slower (ignores cache)
```

**Benefits:**
- **Instant lookup** — no graph traversal needed
- **Queryable** — "Which call flows use authentication?" becomes a graph query
- **Versioned** — stored in `data/call-flow-nodes.json`, tracked in Git

## Integration with Skill

The `knowledge-graph-management` skill calls these scripts when user queries match patterns:

| User says | Script called |
|---|---|
| "show me the call flow for X" | `Get-CallFlow.ps1 -NodeName "X"` |
| "what uses X?" | `Get-Dependents.ps1 -NodeName "X"` |
| "what does X use?" | `Get-Dependencies.ps1 -NodeName "X"` |
| "how do I get from A to B?" | `Get-SkillPath.ps1 -From "A" -To "B"` |
| "what skills load for [intent]?" | `Get-SkillRecommendations.ps1 -Intent "[intent]"` |

## Development

## Subgraph Export

`Get-Subgraph.ps1` extracts portions of the graph for external analysis:

```powershell
# Export Mentor's neighborhood as GraphML for Gephi
.\Get-Subgraph.ps1 -RootNode "Mentor" -MaxDepth 2 -OutputFormat GraphML -OutputPath mentor.graphml

# Export all skills and agents as JSON
.\Get-Subgraph.ps1 -NodeTypes "skill","agent" -OutputFormat JSON -OutputPath skills-agents.json

# Export all call-flow nodes and what they reference
.\Get-Subgraph.ps1 -NodeTypes "call-flow" -EdgeTypes "references" -OutputFormat DOT -OutputPath call-flows.dot

# Export to console (pipe to other tools)
.\Get-Subgraph.ps1 -NodeTypes "agent" -OutputFormat JSON | ConvertFrom-Json
```

**Supported formats:**
- **JSON** — Standard graph format, easy to parse
- **GraphML** — XML-based, for Gephi, yEd, Neo4j import
- **DOT** — GraphViz format for rendering diagrams

Each script:
1. Validates parameters
2. Loads `.github/knowledge-graph/lib/query.psm1`
3. Calls appropriate query function
4. Formats output via `_Format-GraphOutput.ps1`
5. Returns exit code

**Testing:**
```powershell
# Quick test all scripts
@("Mentor", "learner-profile", "query.psm1") | ForEach-Object {
    .\Get-CallFlow.ps1 -NodeName $_
}
```

**Adding a new script:**
1. Copy an existing script as template
2. Update parameters and query logic
3. Add to tables above
4. Update skill's intent recognition to call it
