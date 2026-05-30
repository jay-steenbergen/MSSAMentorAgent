# 01 — Instructions vs. Agent Personas

**Date:** 2026-05-29

## What I was trying to do

Set up the MSSA Mentor repo with two things:
1. Repo-wide guidance so any AI working *on* the project knows the context
2. The Mentor persona itself — the thing learners would invoke

## What confused me

I created `AGENTS.md` at the repo root *and* `.github/agents/Mentor.agent.md`. Both had "agent" in the name. I couldn't tell why I needed two, and the root-level file felt out of place — shouldn't everything Copilot-related live under `.github/`?

## What I learned

They are different primitives serving different audiences:

| | `.github/copilot-instructions.md` | `.github/agents/Mentor.agent.md` |
|---|---|---|
| **What it is** | Repo-wide instructions | A named custom agent (persona) |
| **When loaded** | Always — every Copilot turn in this repo | Only when user picks `Mentor` from the agent picker / `@Mentor` |
| **Audience** | The AI working **on** the repo | The AI acting **as** the mentor |
| **Voice** | Third-person ("the mentor does X") | First-person ("**You** are the MSSA Mentor") |
| **Frontmatter** | None | YAML with `description`, `name`, `model` |

**Constitution vs. role.** The instructions file is the project's constitution — context everyone needs. The agent file is a specific role someone steps into.

**Why the path matters.** `.github/copilot-instructions.md` is the path Copilot looks for to auto-load repo guidance. `.github/agents/*.agent.md` is the path VS Code scans for personas to put in the picker. Moving either one breaks discovery silently — no error, just nothing happens.

**Why `AGENTS.md` at the root was tempting.** That filename is a cross-tool convention (Claude Code, Cursor, Codex, Copilot all check for it). It would have worked, but since this repo's audience is VS Code Copilot users specifically, the Copilot-only path is more precise. If I ever want cross-tool support, I can add a thin `AGENTS.md` at the root that just links to the real file.

**Intentional redundancy is OK.** Both files repeat the "no code dumps / no baby-talk" rule. That's on purpose: one warns contributors editing the mentor, the other instructs the mentor itself. Same rule, two altitudes.

## Rule of thumb

> `copilot-instructions.md` teaches the agent **about** the project. `*.agent.md` teaches the agent **to become** a role. If you're confused which file something belongs in, ask: *"Is this true while I'm building the mentor, or only while I'm being the mentor?"*
