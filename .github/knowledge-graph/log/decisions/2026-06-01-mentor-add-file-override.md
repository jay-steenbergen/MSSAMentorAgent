# Decision: `mentor.ps1 add` gains `-File` parameter for path override

**Date:** 2026-06-01
**Session:** 2026-06-01-graph-driven-setup
**Experiment:** 2026-06-01-phase-2-graph-first-enforcement
**Status:** Active

---

## Chose

Added `-File <path>` parameter to `mentor.ps1`. When provided, it overrides the type-specific default file path used when creating a node.

```powershell
# Before — file path fixed by type:
mentor.ps1 add test red-phase   # → .github/tests/red-phase.test.md (always)

# After — caller can point at where the artifact actually lives:
mentor.ps1 add test tdd-red-phase -File .github/skills/methods/TDD/tests/red-phase.test.md -NoStub
```

Backwards compatible — when `-File` is absent, behavior is identical to before.

## Over

- **Move the file to match the default.** Would have moved `red-phase.test.md` out of `.github/skills/methods/TDD/tests/` into `.github/tests/`, separating the test from the skill it belongs to. Wrong direction.
- **Hand-edit the graph JSON.** Defeats the entire Phase 2 thesis (graph-first authoring through the CLI).
- **Add a new verb (`add-with-file`).** Verb proliferation. The override is the same operation, just with a different file location.
- **Make `-File` a required parameter.** Breaking change to existing usage. Default-derived paths are correct for ~90% of new artifacts.

## Because

- **The CLI should not impose layout.** Tests inside a method's `tests/` subdirectory are a legitimate, common pattern. The CLI was assuming a flat structure that doesn't match reality.
- **Dogfood pressure surfaced it.** The instant we tried to use `mentor.ps1 add` for its declared purpose on a real artifact, the gap was obvious. That's exactly the friction Phase 2 should expose.
- **The change is tiny.** One parameter declaration + one ternary in `Cmd-Add`. Low blast radius.

## Affects

- `.github/knowledge-graph/cli/mentor.ps1` — `param()` block (+1 line), `Cmd-Add` file computation (~6 lines).
- Future artifacts in non-default locations (method tests, track tests, multi-file skills) — now registerable through the standard CLI.

## Revisit if

- **Default-path heuristic stops matching reality for new types.** If we keep adding `-File` for every new node, the defaults are wrong. Fix the defaults, then drop `-File`.
- **Scaffold stub generation needs to match the override.** Today `-File` requires `-NoStub` when the file already exists. If we add scaffold-to-custom-path support, this restriction goes away.
