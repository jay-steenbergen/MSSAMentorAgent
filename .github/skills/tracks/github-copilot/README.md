---
name: github-copilot-track
description: |
  Index and tracker for the GitHub Copilot mastery track. Lists the 9 projects in
  recommended order, each project's status, and the target Microsoft/GitHub certification.
  Auto-load when the learner is in `tracks/github-copilot/` (any project) or asks
  "what's the Copilot track" or "teach me GitHub Copilot from scratch" or "how do I
  customize Copilot."
---

# Track: GitHub Copilot mastery

> **Note:** This is a **bonus track** — not part of the official MSSA curriculum. It targets a separate audience: anyone (veteran or not) who wants to become genuinely effective with GitHub Copilot, not just a tab-accepter.
>
> **Target cert:** GitHub Copilot Certification (GH-300)
> **Stack:** VS Code · GitHub Copilot Chat, Inline, Edit · Custom instructions · Prompt files · Custom agents · MCP

## What this track teaches

By the end of this track, the learner can drive Copilot from "autocomplete tool I sometimes use" to "second pair of hands I actually steer." The progression mirrors how a real engineer learns Copilot — start with inline completions, learn to prompt them on purpose, then move into chat-driven debugging and review, then customize the assistant itself with instructions, prompts, agents, and MCP tools.

The teaching method is `methods/ride-along` — explained at three altitudes (why, what, how), concepts named out loud, after-action review at each milestone. The learner stays at the keyboard.

## Projects (in order)

| # | Project | What you build | Time | Status |
|---|---|---|---|---|
| 1 | [`ghc-copilot-foundations`](ghc-copilot-foundations/SKILL.md) | Install Copilot, sign in, build a tiny calculator with inline completions — accept/reject/cycle/partial-accept | ~60 min | **ready** |
| 2 | [`ghc-prompting-for-completions`](ghc-prompting-for-completions/SKILL.md) | Steer inline completions with comments, signatures, and naming — 5 small functions, each one prompted on purpose | ~75 min | **ready** |
| 3 | [`ghc-chat-driven-debugging`](ghc-chat-driven-debugging/SKILL.md) | Take a buggy program, use `/fix` and `/explain` to walk diagnosis → hypothesis → fix → verify | ~75 min | **ready** |
| 4 | [`ghc-test-generation`](ghc-test-generation/SKILL.md) | Have Copilot generate tests for a function, find the tests pass on a buggy version, then write the bug-revealing test yourself | ~75 min | **ready** |
| 5 | [`ghc-code-review-with-copilot`](ghc-code-review-with-copilot/SKILL.md) | Run Copilot on a flawed PR diff, score findings as true-positive / false-positive / missed | ~75 min | **ready** |
| 6 | [`ghc-custom-instructions`](ghc-custom-instructions/SKILL.md) | Write `.github/copilot-instructions.md` for a small C# API and verify Copilot follows your conventions | ~75 min | **ready** |
| 7 | [`ghc-prompt-files`](ghc-prompt-files/SKILL.md) | Create a `.github/prompts/*.prompt.md` reusable prompt with parameters and run it from chat | ~75 min | **ready** |
| 8 | [`ghc-custom-agents`](ghc-custom-agents/SKILL.md) | Build a focused custom `.agent.md` (e.g. an API design reviewer) with scoped tools and a tested persona | ~90 min | **ready** |
| 9 | [`ghc-mcp-tools-integration`](ghc-mcp-tools-integration/SKILL.md) | Wire a real MCP server (GitHub MCP) into VS Code and use it from Copilot Chat to do real work | ~90 min | **ready** |

**Status legend:** **ready** = drafted, self-reviewed, runs end-to-end · *drafted* = first pass, not reviewed · *planned* = scoped, not written

## Lab requirements

| Requirement | Why | How |
|---|---|---|
| **GitHub account with Copilot license** | Required for all projects | [Copilot Free](https://github.com/features/copilot) (limited) or paid Individual / Business |
| **VS Code** with the GitHub Copilot + Copilot Chat extensions | The lab IDE | Install from the marketplace |
| **A language of choice** for projects #1-#5 | Sample code | Python, TypeScript, C#, or PowerShell all work — examples in the SKILLs use Python primarily |
| **.NET 8 SDK** for project #6 | Small C# Web API | `winget install Microsoft.DotNet.SDK.8` |
| **Node.js 20+** for project #9 | MCP servers usually ship as npm packages | `winget install OpenJS.NodeJS.LTS` |
| **Personal GitHub repo** you can experiment in | Customization files live next to code | Create a throwaway public repo |

**Cost discipline:** Copilot is a monthly subscription. The free tier covers projects #1-#5 with quota to spare. Paid Individual ($10/mo) covers everything. No cloud bills involved.

## How the mentor uses this

1. Learner says what they want to learn (e.g. *"I want to customize Copilot for my team's coding style"*).
2. Mentor scans the table — matches to project #6 (`ghc-custom-instructions`).
3. Mentor checks prerequisites — #6 assumes #1 (basic Copilot loop) is comfortable. Mentor offers the right starting point.
4. Mentor loads the project SKILL.md and runs a [ride-along](../../methods/ride-along/SKILL.md) session.

## Out of scope

The Copilot track does NOT teach:

- **General software engineering** — variables, control flow, debugging. Use the CAD or SCA tracks if those are gaps.
- **GitHub Actions in depth** — Actions is a separate skill set. We touch CI in passing if needed.
- **Building MCP servers from scratch** — project #9 *uses* one. Building one is a follow-on capstone.
- **LLM internals / how Copilot's model is trained** — black box on purpose.
- **Prompt engineering for chatbots generally** — Copilot-specific patterns only.

## When you finish

You will be able to:

- Drive inline completions with intent, not luck.
- Use Copilot Chat as a debugger / reviewer / pair, not a magic box.
- Customize Copilot's behavior per repo via instructions, prompts, agents, and MCP.
- Recognize when Copilot is wrong and have a workflow for catching it.

That is the bar most working engineers never reach — most use 10% of Copilot. You'll be using 80%.
