# Knowledge Graph Test Infrastructure

This directory hosts the graph and tooling test suite. Tests use a tiny PowerShell harness ([`_harness.psm1`](./_harness.psm1)) and a runner ([`run-tests.ps1`](./run-tests.ps1)) that auto-discovers any `*.test.ps1` file under the subdirectories below.

## Layout

```
tests/
├── README.md                ← this file
├── _harness.psm1            ← Assert-* helpers, shared graph cache
├── run-tests.ps1            ← discovery + reporter
├── unit/                    ← single-function / single-rule (sub-second)
├── integration/             ← multi-component (graph + audit + scoring)
├── gate/                    ← pre-commit gate logic (validate-paths, validate-pwsh, UX-tag)
└── e2e/                     ← full extract + hook cycles (slow, not in pre-commit)
```

## Running

```powershell
# Everything (unit + integration + gate; skips e2e by default)
pwsh .github/knowledge-graph/tests/run-tests.ps1

# One bucket
pwsh .github/knowledge-graph/tests/run-tests.ps1 -Filter gate

# Just the fast ones (unit only)
pwsh .github/knowledge-graph/tests/run-tests.ps1 -Tag fast

# Include slow e2e too
pwsh .github/knowledge-graph/tests/run-tests.ps1 -IncludeE2E

# One specific file
pwsh .github/knowledge-graph/tests/run-tests.ps1 -Pattern "*audit*"

# JSON output (for CI)
pwsh .github/knowledge-graph/tests/run-tests.ps1 -Json
```

## Pre-commit integration

When `.github/knowledge-graph/**` or `.github/hooks/**` is staged, the pre-commit hook runs `run-tests.ps1 -Filter unit,integration,gate` (everything except e2e). Failure blocks the commit.

## Writing a new test

1. Pick a bucket (unit / integration / gate / e2e).
2. Copy `unit/_template.test.ps1` to `unit/your-thing.test.ps1` (or matching bucket).
3. Each test file looks like this:

```powershell
#!/usr/bin/env pwsh
#Requires -Version 7.0
[CmdletBinding()] param([switch]$Quiet)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot '..' '_harness.psm1') -Force

Begin-TestFile -Name 'Your thing' -Quiet:$Quiet

Test-Case 'description of what you are asserting' {
    Assert-NodeExists 'agent:mentor'
    Assert-EdgeExists -Source 'agent:mentor' -Type 'follows' -Target 'behavior:01-identify-learner'
}

End-TestFile
```

4. Run `pwsh .github/knowledge-graph/tests/run-tests.ps1 -Pattern "*your-thing*"` — the runner picks it up.

## Available assertions (from `_harness.psm1`)

| Assertion | Use when |
|---|---|
| `Assert-True $expr -Message ...` | Generic boolean assertion |
| `Assert-Equal $expected $actual` | Compare two values |
| `Assert-NodeExists $id` | Graph must contain the node id |
| `Assert-NodeNotExists $id` | Graph must NOT contain the node id |
| `Assert-EdgeExists -Source X -Type T -Target Y` | Graph must contain the edge |
| `Assert-AuditRateAtLeast $minPercent` | Edge-claim audit verification rate is ≥ N% |
| `Assert-NoIslands` | Graph has no disconnected components |
| `Assert-NoDanglingEdges` | All edge endpoints resolve to real nodes |
| `Assert-FileResolves $path` | A repo-relative path exists on disk |
| `Assert-ScriptExitCode -Path X -Args @(...) -Expected N` | Run a script, assert exit code |
| `Assert-OutputContains -Path X -Args @(...) -Pattern ...` | Run + assert pattern in output |

## Caching

The harness loads the merged graph ONCE per `run-tests.ps1` invocation and caches it. Tests that just query the graph are sub-millisecond. Tests that spawn subprocesses (`Assert-ScriptExitCode`) are slower — use sparingly and tag them.

## Tags

Frontmatter-style tags at the top of each test file control which run modes include the test:

```powershell
# @tags: fast, graph
```

- `fast` — runs in `-Tag fast` mode (default unit + integration)
- `slow` — excluded from default runs (use for tests > 1s)
- `gate` — included when pre-commit invokes the runner
- `e2e` — excluded unless `-IncludeE2E` is passed

If a test has no `@tags:` line, the bucket directory name is used as the implicit tag (`unit`, `integration`, `gate`, `e2e`).
