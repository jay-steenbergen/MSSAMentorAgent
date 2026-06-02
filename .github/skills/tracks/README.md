# Track skills

A **track skill** scaffolds the build progression for one MSSA learning path — the *what* the learner is building. Tracks supply the project sequence; the [`ride-along`](../methods/ride-along/SKILL.md) method supplies the *how* of teaching.

## MSSA tracks (official, 3 total)

| Code | Track | Stack | Role target |
|---|---|---|---|
| CAD  | Cloud Application Development  | C#, .NET, ASP.NET Core, SQL, Azure | Software Engineer |
| SCA  | Server & Cloud Administration  | Windows Server, AD, PowerShell, Azure admin | SysAdmin, Azure Admin |
| CSO  | Cybersecurity Operations       | Entra ID, Defender XDR, Sentinel, KQL | SOC Analyst |

Source: [military.microsoft.com/mssa/choose-your-learning-path](https://military.microsoft.com/mssa/choose-your-learning-path) (verified 2026-05-29).

## Bonus tracks (coming soon — not yet selectable)

| Code | Track | Stack | Why it's here | Status |
|---|---|---|---|---|
| GHC  | GitHub Copilot mastery | VS Code, GitHub Copilot, MCP | Force-multiplier on top of any MSSA track; targets the GH-300 cert | Planned — no projects yet |
| WBD  | Whiteboarding          | Whiteboard / Excalidraw, Mermaid, Draw.io | Communication craft — transfers to every MSSA track and every engineering role | Planned — no projects yet |

Bonus tracks will use the same `ride-along` method as MSSA tracks. They are not part of the MSSA curriculum; they exist because the skills transfer to every role MSSA prepares learners for. **Currently the agent's track picker only offers the 3 MSSA tracks above** — bonus tracks will appear once their first projects ship.

## When you add a track skill

1. Create `tracks/<short-name>/SKILL.md` (e.g. `cloud-app-dev/SKILL.md`).
2. The skill provides the **build progression** — what to build, phase by phase.
3. The skill does NOT redefine *how* to teach. That stays in `methods/ride-along/`.
4. If you need a different teaching shape, add a new method skill — do not override from a track.
