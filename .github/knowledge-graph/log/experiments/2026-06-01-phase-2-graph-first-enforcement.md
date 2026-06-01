# Experiment: Phase 2 — Graph-First Authoring Enforcement

**Date:** 2026-06-01
**Session:** 2026-06-01-graph-driven-setup
**Status:** Concluded

---

## Hypothesis

The graph and the filesystem disagree silently. Today:

- An author can drop a `SKILL.md` into `.github/skills/.../` without ever calling `mentor.ps1 add`.
- Auto-discovery may or may not pick it up depending on path + frontmatter shape.
- `find-drift.ps1` scans text fields for path references but had a regex too loose to be useful (24 false positives from prose containing slashes — "Given/When/Then", "Army/Navy/AF", "method/track").
- Nothing scans the inverse: files on disk with no graph node.

Phase 2 hypothesis: if we make the graph the ONLY valid entry point — orphan markdown blocks commits, drift warns — authors will be forced into `mentor.ps1 add` first. The graph stops being a downstream artifact and starts being the source of truth.

## What we measured first

Before writing anything, two baseline scans:

| Check | Count | Detail |
|---|---|---|
| Drift findings (loose regex) | 24 | Mostly false positives — prose like `Given/When/Then` matched the path regex |
| Orphan markdown files | 1 | `.github/skills/methods/TDD/tests/red-phase.test.md` — real orphan, not surfaced by anything |
| Stale graph nodes (node exists, file doesn't) | 0 | Healthy |

The single real orphan validated the gap: a test file lived next to its skill for days without anyone noticing the graph didn't know about it.

## Operations

1. **Tightened `find-drift.ps1` regex.** Added two cheap filters: candidate must either start with a dot-anchor (`.github/`, `.profiles/`, `.copilot/`, `extensions/`) OR end with a recognized file extension (`.md`, `.ps1`, `.json`, etc.). 24 → 1 finding, and the 1 is a real drift in `decision:profile-exists` referencing `mentors/{username}/profile.json` (no mentor profile directory populated yet).

2. **Built `find-orphan-markdown.ps1`.** Scans `.github/agents/*.agent.md`, `.github/skills/**/SKILL.md`, `.github/skills/**/*.test.md`, `.github/tests/*.test.md` and diffs against `node.file` fields in the system graph. Returns exit code 1 + per-file report when orphans exist.

3. **Wired both into the pre-commit hook as Step 5b.**
   - Orphan check: **BLOCKING** — `exit 1` on any orphan.
   - Drift check: **ADVISORY** — `Write-Warning` with count, never blocks.

4. **End-to-end test.** Created `.github/skills/_phase2-test-orphan.test.md`, staged it, ran the hook script directly. Hook reported 2 orphans (the test file + the pre-existing one), exit code 1, with the "Phase 2 rule" message. Confirmed the gate works under realistic commit conditions.

5. **Dogfood the workflow on the real orphan.**
   - First attempt: `mentor.ps1 add test tdd-red-phase ...` — failed, no `-File` parameter to override the default `.github/tests/$Slug.test.md` location.
   - Pivot: added `-File` parameter to `mentor.ps1` `Cmd-Add`. Now any caller can register a node whose `.md` file lives in a non-default location.
   - Re-ran: `mentor.ps1 add test tdd-red-phase ... -File .github/skills/methods/TDD/tests/red-phase.test.md -NoStub -NoBackup`. Node created.
   - Linked: `mentor.ps1 link test:tdd-red-phase tdd:phase-red tests`.

## What worked

- **Inverse direction matters.** `find-drift.ps1` walks graph text → filesystem. `find-orphan-markdown.ps1` walks filesystem → graph. Both directions are needed for the graph to be ground truth.
- **The end-to-end test paid off.** Running the hook on a real orphan was faster and more convincing than reading the script and reasoning about its behavior. Took ~10 seconds.
- **Dogfooding surfaced a real CLI gap.** The `-File` override wasn't on anyone's wishlist — it became necessary the moment we tried to use the CLI for its intended purpose. That's exactly the friction Phase 2 is supposed to expose.

## What didn't

- **First regex tightening pass was too tight in my head.** I almost added "must contain `.github/` or `.profiles/`" as the only rule. That would have killed the valid `mentors/{username}/profile.json` finding (it doesn't have a known prefix). The "ends with `.ext`" half of the filter is what kept that one.
- **`mentor.ps1 add`'s default file path is helpful but rigid.** Tests inside a method's `tests/` subdirectory don't fit the default. Without `-File`, the only escape hatch was hand-editing the graph JSON — exactly the workflow Phase 2 forbids.

## Findings deferred to later phases

- **56 untested skills** still flagged by audit-quality.ps1. Real coverage gap. Not Phase 2 scope.
- **`decision:profile-exists` references `mentors/{username}/profile.json`** which doesn't exist. The mentor-side profile directory was never populated. Either the description needs to be updated to point at the learner side, or mentor profiles need to be created. One-line fix when someone owns it.

## Decision / next move

Two decisions captured separately:

- `decision:2026-06-01-phase-2-gate-policy` — orphan blocks, drift warns
- `decision:2026-06-01-mentor-add-file-override` — `-File` parameter added to `mentor.ps1 add`

Phase 2 is complete. The graph is now the only valid entry point for new artifacts. Next phase candidates:

- **Phase 3:** Skill DAG enforcement — the agent's skill load list is computed from graph queries instead of being implicit in markdown.
- **Phase 4:** Agent self-query — agent uses `Get-AgentLoadList` (graph oracle) before deciding what to read.
- **Phase 5:** Hands-off graph-driven sessions.
