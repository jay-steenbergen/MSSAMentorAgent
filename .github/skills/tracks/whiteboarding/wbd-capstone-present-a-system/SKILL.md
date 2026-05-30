---
name: wbd-capstone-present-a-system
description: |
  Whiteboarding track project #9 (capstone). Learner picks a real system they've built
  or use heavily, prepares 4 diagrams (architecture, sequence, state, ER), presents it
  live to another human in 15 minutes, records the session, captures every question the
  audience asked, redraws v2, and compares v1 vs v2. The skill graduates from drills
  into real communication. Auto-load when the learner is in
  `whiteboarding/wbd-capstone-present-a-system` or asks about presenting an architecture,
  whiteboarding capstone, system walkthrough, or technical presentation prep.
---

# Project: `wbd-capstone-present-a-system` (capstone)

> **Track:** Whiteboarding · **Project:** 9 of 9 · **Time:** ~90 minutes (across 2-3 sittings)
>
> Drills don't ship. This capstone takes everything from projects #1-8 and points it at a real audience: pick a system you've built or use, prepare four diagrams, present them to another human for 15 minutes, capture every question they ask, then redraw the diagrams to address those questions. The questions reveal the gaps. The redraw is the proof you can iterate. By the end, the learner has a portfolio artifact AND has done the thing whiteboarding actually exists for: communicating a system to a human who didn't build it.

## Capstone goal

When this capstone is done, the learner has:

- A **real system** they understand well enough to explain in 15 minutes.
- **4 diagrams** of it: architecture (box-and-arrow), sequence (one critical flow), state machine (one entity's lifecycle), ER (the data model).
- A **recorded 15-minute presentation** to a real human (peer, study partner, mentor, family member who can ask "but why?").
- A **list of every question the audience asked** — the questions ARE the feedback.
- A **v2 of each diagram** that addresses the audience questions.
- A **written reflection** (~300 words) on what changed between v1 and v2 and why.

## Scope guardrail

This is **prep + present + capture feedback + redraw + reflect**. We are not making slides, not building a video, not editing for production. The point: the human-to-human communication loop, with diagrams as the medium.

If the learner says "I don't have a real system to use" — push back honestly: *you do. Pick one of: a project from CAD/SCA/CSO/GHC track, a system you used in the military (logistics, communications, scheduling), an open-source project you've contributed to, or even a system you use daily (your email client + the services behind it). The system doesn't need to be one you built — it needs to be one you can explain*.

## Prerequisites

| Prereq | Verify with |
|---|---|
| Completed projects 1-8 of this track | Can draw box-and-arrow, sequence, state, ER on demand |
| A real human willing to listen for 15 minutes + ask questions | Schedule before starting prep |
| Recording tool (phone, OBS, Loom — anything that captures audio + screen if using Excalidraw) | Test it before the presentation |
| A whiteboard, Excalidraw, or Mermaid | Whichever fits the audience and venue |

## Phases

### Phase 1 — Pick the system (~15 min)

**Goal:** Choose a system you can actually explain in 15 minutes.

**Decision criteria:**

| Criterion | Why it matters |
|---|---|
| You understand it well enough to answer "why?" questions | Otherwise the presentation falls apart at minute 6 |
| It has at least 3-5 components | Anything smaller doesn't need architectural explanation |
| It has at least one async or multi-step flow | Otherwise no sequence diagram is needed |
| It has at least one entity with a lifecycle | Otherwise no state machine is needed |
| It has at least 3-4 entities with relationships | Otherwise no ER diagram is needed |

**Candidate systems (pick ONE):**

1. **A project from a prior track:** the to-do API you built in CAD, the AD/DNS lab from SCA, the SIEM you tuned in CSO, the agent you built in GHC.
2. **A military system you used:** a logistics tracking system, a scheduling/duty roster system, a comms relay system. You don't need full technical detail — explain it at the level you understood it.
3. **An open-source project you've contributed to:** README + your contribution context. The README usually has an architecture section already; you'll redraw it your way.
4. **A consumer product you use daily:** Spotify (login → search → stream), Uber (request → match → trip → payment), GitHub (push → CI → review → merge). You don't know the real internals — make educated guesses and label them as guesses.
5. **A system from your work (if not under NDA):** the build pipeline at your company, the deployment process, an internal tool.

**Write down:**
- The name of the system.
- The 15-minute audience: who, and what do they already know?
- 3 sentences describing what the system DOES (in user-value terms, not technical terms).

**Concepts to name out loud:**
- *This is **the audience as the design constraint*** — your diagrams will differ if the audience is technical vs non-technical. Pick the audience first, then design for them.
- *This is **the "understand it well enough to answer 'why'"" filter*** — knowing WHAT exists is shallow. Knowing WHY each piece is there is deep. The audience will ask why; if you don't know, that's a gap to address before the presentation.

**After-action prompt:** *"You picked a system and an audience. If you presented to them tomorrow, what's the question they'd ask that you couldn't answer? That's your prep priority."*

### Phase 2 — Prepare the 4 diagrams (v1) (~30 min)

**Goal:** One of each diagram type, drawn well enough to use in the presentation.

**Diagram 1 — Architecture (box-and-arrow):**

- All major components as the right shapes (project #2 conventions).
- Clouds for external systems.
- Cylinders for data stores.
- Every arrow has a verb.
- Sync vs async distinguished if applicable.
- ~15 minutes to draw, including iteration.

**Diagram 2 — Sequence diagram of ONE critical flow:**

- Pick the most important user flow. Examples: "user logs in," "user places an order," "incident comes in and gets triaged," "agent receives task and completes it."
- Lifelines for the relevant actors only — don't include components that aren't in this flow.
- Use the happy-path-first discipline. If the flow has interesting failure modes, draw the failure path on a separate diagram (or skip — the audience can ask).

**Diagram 3 — State machine for ONE entity:**

- The entity should have a real lifecycle. Examples: "Order," "Incident," "Ticket," "DeploymentJob," "User Session," "TaskInstance."
- States as rounded rectangles, transitions as arrows labeled with events.
- Every state has an exit (terminals are fine).

**Diagram 4 — ER for the data model:**

- The 3-8 most important entities.
- Crow's foot for relationships.
- Primary keys marked.
- Junction tables for any many-to-many.

**Format choice — pick what fits the venue:**

- Presenting in person on a whiteboard → draw all 4 on the whiteboard during prep, photograph, then erase and redraw live for the audience.
- Presenting remotely → use Excalidraw (live, hand-drawn feel) OR Mermaid (pre-rendered) OR Draw.io (polished). Mix is fine.
- Recording solo for later review → Mermaid is easiest (you can paste into a markdown file, render, screenshot).

**Concepts to name out loud:**
- *This is **the 4 diagrams as 4 lenses on the same system*** — each answers a different question. Architecture: what exists. Sequence: what happens in time. State: what conditions an entity moves through. ER: how data is shaped.
- *This is **why presenting 4 small diagrams beats one giant one*** — each diagram fits the audience's attention budget. Switching between them gives the audience visual variety and lets them ask questions on the right surface.

**After-action prompt:** *"You drew 4 diagrams. Look at them as a set. Could someone who's never seen the system understand what it does, how it works, what its data looks like, and how it changes over time? If yes, the prep is done."*

### Phase 3 — Present + record (~15 min)

**Goal:** Run the 15-minute presentation. Record it.

**Setup:**

- Recording on. Phone propped up if in-person, screen recording (Loom, OBS, Teams) if remote.
- Audience knows: "I'll talk for ~15 minutes, then we'll have time for questions. Please interrupt with questions during, too — I want them."
- Diagrams visible (whiteboard, Excalidraw, README).

**The 15-minute structure:**

| Time | What you do |
|---|---|
| 0:00-1:00 | "Here's what this system does, who uses it, why it exists." (3 sentences from Phase 1.) |
| 1:00-5:00 | **Diagram 1 (Architecture).** Walk through every component. Name each shape. Explain why each arrow exists. |
| 5:00-9:00 | **Diagram 2 (Sequence).** Pick the critical flow. Walk through it step by step. Highlight what's fast / slow / async / can fail. |
| 9:00-12:00 | **Diagram 3 (State machine).** Pick the lifecycle entity. Walk through the states. Highlight the interesting transitions. |
| 12:00-14:00 | **Diagram 4 (ER).** Walk through the data model. Highlight relationships, not every column. |
| 14:00-15:00 | "What I'd change if I were building it from scratch / what's the next investment / what concerns me about it." Open for questions. |

**Rules during the presentation:**

- **Talk while drawing** (project #1, Phase 4 discipline). Silence is the killer.
- **Welcome interruptions.** "Good question — let me come back to that in 2 minutes when we hit the sequence diagram" is fine. "Good question — let me address that now" is also fine.
- **Don't apologize for the diagrams.** No "sorry this is messy." The audience evaluates the content, not your handwriting.
- **Write down every question** the audience asks, in real time, in a margin or notepad. These ARE the feedback.

**Concepts to name out loud:**
- *This is **the audience as the test*** — if the audience can repeat the system back to you after 15 minutes, the diagrams worked. If they can't, the diagrams need work.
- *This is **questions as gaps*** — every question reveals something the diagrams didn't make clear. Don't be defensive — write them down.

**After-action prompt:** *"You presented. How many questions did the audience ask? More than 5 is a sign the diagrams have room to improve. Zero questions means either the diagrams were perfect (unlikely) or the audience was lost and didn't know what to ask (more likely)."*

### Phase 4 — Capture feedback + redraw v2 (~25 min)

**Goal:** Address every question by improving the diagrams.

**Step 1 — list every question:**

Write each question the audience asked, verbatim. Examples:
- "Wait — why is X separate from Y?"
- "What happens if the DB goes down?"
- "Can a user have multiple of those?"
- "Is that synchronous or async?"
- "Where does the request actually start?"
- "What does 'X' mean?"

**Step 2 — categorize each question:**

| Category | Means | Fix in the diagram |
|---|---|---|
| **Missing component** | A component or interaction wasn't shown | Add it |
| **Ambiguous label** | A label was unclear or jargon-y | Rewrite the label |
| **Wrong shape choice** | The shape didn't match the concept | Change the shape |
| **Missing label on arrow** | The arrow had no verb | Add the verb |
| **Wrong diagram type** | The question was about state but you only drew architecture | Add or improve the missing diagram |
| **Out of scope** | The question was beyond what the system does | No diagram fix; address in narration |

**Step 3 — redraw v2:**

Go through each diagram and apply the fixes. Save v2 with a different filename or in a different file (e.g., `architecture-v1.png` and `architecture-v2.png`).

**Step 4 — re-rehearse (mentally or with a different audience):**

For each question in your list, can the new diagram now answer it without you needing to talk? If yes, the v2 worked. If no, iterate one more time.

**Concepts to name out loud:**
- *This is **iteration as the only path to clarity*** — first drafts of diagrams (like first drafts of writing) are never as clear as you think they are. The only way to find the gaps is to put the diagram in front of someone who doesn't already know the answer.
- *This is **why every question is a gift*** — the audience is doing free testing for you. Treat the question as data, not as judgment.

**After-action prompt:** *"You produced v2. If you presented again with v2, the same audience should ask fewer questions and different questions (deeper ones). That's progress."*

### Phase 5 — Written reflection (~10 min)

**Goal:** Produce ~300 words on what you learned. This is the artifact you'll come back to.

**Write down (in a `reflection.md` or in a journal):**

1. **The system you picked and why.**
2. **The 4 diagrams you drew (link them or describe them briefly).**
3. **The top 3 questions the audience asked.** What did each question reveal about the v1 diagrams?
4. **The most-impactful change from v1 to v2.** Which fix made the biggest difference?
5. **What you'll do differently next time you whiteboard a system.** One concrete change.

**Save this in a place you'll find again.** This reflection is the closure of the track — and the starting point for the next time you whiteboard something real.

**Concepts to name out loud:**
- *This is **the after-action review at track scale*** — every project ended with one. This capstone is the after-action review for the whole track.
- *This is **whiteboarding as a transferable skill*** — the diagrams change per role (CAD vs SCA vs CSO), but the skill of "explain a system to a human in 15 minutes" transfers to every engineering job, every promotion conversation, every customer call, every architecture review.

**After-action prompt:** *"You wrote the reflection. Read it again in 6 months. The version of you reading it will be a better whiteboarder because the version of you writing it did the work."*

## When to break the method

- Learner doesn't have a friendly audience available → record solo and "present to an empty room" using a phone camera. Replay it the next day with fresh eyes — your future self IS the audience.
- Learner has a real upcoming presentation (interview, customer call) → use that as the capstone. Real stakes beat practice every time.
- Time short → at minimum, do Phases 2-3 (prepare + present). Phases 4-5 (feedback + reflection) can come later.

## Definition of done

Observable, the learner has:

- [ ] Picked a real system and named the audience.
- [ ] Produced 4 diagrams (architecture, sequence, state, ER) at v1 quality.
- [ ] Delivered a 15-minute presentation to a real human, recorded.
- [ ] Captured every question the audience asked, categorized them, and redrawn each diagram to v2.
- [ ] Written a ~300-word reflection on what changed between v1 and v2 and what they'll do differently next time.

## Track complete

You have completed the **Whiteboarding** bonus track.

The skill you built here transfers to every other track. In every CAD/SCA/CSO/GHC project, you will whiteboard before you build. You will sketch architectures before writing code. You will draw sequence diagrams to debug a race condition. You will sketch a state machine before reaching for a database. You will whiteboard at interviews and in design reviews and in PRs and in customer meetings.

The whiteboard is the engineer's most-undervalued tool. You now use it deliberately.

→ Back to [Bonus tracks index](../README.md) · → Back to [All tracks](../../README.md)
