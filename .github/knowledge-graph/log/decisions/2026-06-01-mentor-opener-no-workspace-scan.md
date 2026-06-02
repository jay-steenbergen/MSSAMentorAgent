---
id: 2026-06-01-mentor-opener-no-workspace-scan
type: decision
description: "Mentor opens with two-option choice (your idea or hello world in the chosen track) and never says 'I'll scan the workspace'"
decided_at: 2026-06-01
---

# Decision: Mentor opener — no workspace scan

After loading the learner profile and showing the method/track pickers, the Mentor opens the actual build conversation with two concrete starter options for the chosen track, and never tells the learner "I'll scan the workspace and suggest something."

## Chose

A fixed two-option opener tied to the resolved track:

1. **"Do you have an idea you want to build?"** — learner-driven; Mentor follows.
2. **"Or do you want to start with a hello-world style project in {track}?"** — Mentor-driven; uses track knowledge.

Wording is asserted in three sync'd places:
- `behavior:02-open-with-intent` in `.github/agents/Mentor.agent.md`
- `Get-Behavior open-with-intent` in `.github/knowledge-graph/cli/get-behavior.ps1`
- Session-start protocol in `.github/skills/learner-profile/SKILL.md`

An explicit antipattern bans the phrase "scan the workspace" (and equivalents like "let me look around your workspace") in the opener.

## Over

- **Single open-ended prompt** like "What do you want to build?" — too unstructured for someone new to the track; the option to start from a known-good Mentor pitch matters.
- **"I'll scan the workspace and suggest something"** — the original bug. The Mentor already has track-level knowledge loaded via the knowledge graph at this point; pretending it needs to scan files is both a lie and skips the Mentor's actual value-add.
- **A long menu of project ideas** — picker fatigue. Two options keeps the decision under cognitive overhead.
- **Auto-starting hello world without asking** — strips agency from the learner.

## Because

The opener is the moment the Mentor either feels like a mentor or like a generic code assistant. "I'll scan the workspace" is what a generic assistant says when it has no context — but the Mentor *does* have context (loaded track + method + profile via the knowledge graph). Surfacing that context as a concrete pitch ("hello-world in {track}") is the proof-of-life that distinguishes the Mentor from an autocomplete.

A real mentee tested the agent and got the "scan the workspace" response. That's a credibility hit on the first interaction — the kind of thing that decides whether someone comes back tomorrow.

Two options also matches how human mentors actually open: they offer a default while leaving room for the learner's own goal. One option is too directive; an open question is too unstructured.

## Affects

- `.github/agents/Mentor.agent.md` — `behavior:02-open-with-intent` rewritten + antipattern added.
- `.github/knowledge-graph/cli/get-behavior.ps1` — `open-with-intent` case rewritten to return the new two-option script.
- `.github/skills/learner-profile/SKILL.md` — session-start steps updated.
- Future learners interacting with the Mentor — opener is now deterministic and uses the loaded track context.
- Commit `f0bc55a` pushed to master.

## Revisit if

- The "hello-world" framing feels too elementary for learners further along the track. May need a per-track default pitch that scales with proficiency (e.g. show the next milestone for a returning learner instead of hello world).
- A track gets so many starter ideas that two options aren't enough — could grow to three but no more.
- The Mentor regresses and starts inventing wording like "let me check what files you have" — at that point add more explicit forbidden phrases to the antipattern.
