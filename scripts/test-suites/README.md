# MSSA Mentor Agent — Test Harness

Single entry point for running every test in the repo.

## Quick start

```powershell
pwsh scripts/test.ps1                  # run everything
pwsh scripts/test.ps1 -Suite graph     # just one suite
pwsh scripts/test.ps1 -Quick           # skip the slow extension suite
pwsh scripts/test.ps1 -Coverage        # include coverage report for the extension
```

## Suites

| Suite        | Runs                                              | Failure exits non-zero? |
|--------------|---------------------------------------------------|-------------------------|
| `graph`      | `.github/knowledge-graph/build/health.ps1`        | Yes (any FAIL)          |
| `profiles`   | `dotnet test` on `.profiles/ProfileTests/` + `.profiles/validate-profile.ps1` over every mentee profile | Yes |
| `extension`  | `npm test` in `extensions/mssa-mentor/` (Mocha via @vscode/test-electron) | Yes |
| `behavioral` | Scans every `*.test.md` and reports fresh / stale / never-run counts | No — info only |

## Behavioral freshness

A spec is **stale** if any file it covers was modified (per `git log`) after the spec's
`Actual Result → Date run` field. There's no day-count threshold; freshness is mechanically
derived from git history.

A spec is **never run** when its `Actual Result → Date run` field is empty.

The behavioral suite never fails the build — it surfaces which specs need a manual re-run
so you can plan that work, not block on it.
