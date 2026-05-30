---
name: wbd-whiteboard-foundations
description: |
  Whiteboarding track project #1. Learner stands at a whiteboard (or Excalidraw),
  drills the 5 shapes that actually matter (rectangle, rounded rectangle, cylinder,
  diamond, arrow), practices legibility under time pressure, and learns the layout
  rules (left-to-right flow, top-down hierarchy, label everything). Builds the
  muscle memory before any specific diagram type. Auto-load when the learner is in
  `whiteboarding/wbd-whiteboard-foundations` or asks how to start whiteboarding,
  draw clearly, layout a diagram, or use Excalidraw.
---

# Project: `wbd-whiteboard-foundations`

> **Track:** Whiteboarding · **Project:** 1 of 9 · **Time:** ~60 minutes
>
> Everyone thinks whiteboarding is about ideas. It's not — it's about **legibility under pressure.** A brilliant architecture rendered as a wall of unreadable scribbles loses the room. This project skips the diagram types and drills the 5 shapes you'll use 95% of the time, the layout rules that keep diagrams scannable, and the live-drawing rhythm that lets you talk while you draw.

## Project goal

When this project is done, the learner can:

- Draw 5 shapes (rectangle, rounded rectangle, cylinder, diamond, arrow) cleanly and quickly.
- Use **left-to-right flow** for processes and **top-down hierarchy** for systems.
- Label every shape and arrow — no anonymous boxes.
- Pick a **white area on the board** before starting, leaving room to extend.
- Draw while talking, without freezing or apologizing for the drawing quality.

## Scope guardrail

This is **drills on the 5 shapes + 4 layout rules + one timed practice run**. We are not learning specific diagram types (those start project #2). The point: muscle memory before vocabulary. A whiteboard expert with no diagrams beats a diagram expert who freezes at the board.

If the learner asks "but my drawing is terrible" — answer honestly: *good. Engineers don't need to draw well. They need to draw legibly and confidently. The second skill is taught here; the first doesn't matter*.

## Prerequisites

| Prereq | Verify with |
|---|---|
| A whiteboard (any size, even A4-paper-as-whiteboard works) and a marker, OR [Excalidraw](https://excalidraw.com) open in a browser | Can erase and redraw |
| 60 minutes of uninterrupted time | Not in a meeting |
| Willingness to look silly while practicing | The willingness is the prerequisite |

## Phases

### Phase 1 — The 5 shapes drill (~15 min)

**Goal:** Draw each shape 10 times until it looks consistent and takes <3 seconds.

**The 5 shapes:**

| Shape | Means | When to use |
|---|---|---|
| **Rectangle** | A discrete thing — a service, a component, a function | Default. Use this when in doubt. |
| **Rounded rectangle** | A user-facing thing — an app, a UI, an external system | Visually distinct from internal components. |
| **Cylinder** | A database, a store, a log | Anything that persists data. |
| **Diamond** | A decision — yes/no, true/false, route | Flowcharts and state transitions. |
| **Arrow** | A direction — data flow, call, transition | Always labeled. Arrowhead matters. |

**The drill:**

1. Draw 10 rectangles in a row. Width ~5cm, height ~3cm. Same size.
2. Draw 10 rounded rectangles. Same size.
3. Draw 10 cylinders. The top ellipse should look like an ellipse, not a wavy line.
4. Draw 10 diamonds. Same size, equal sides.
5. Draw 10 arrows of three types: straight, right-angle bent, curved. Arrowheads filled or open — pick one and be consistent.

**Common gotchas:**
- Rectangles are different sizes → bad. Train yourself to one default size. Variation in size means something visually (bigger = more important); use it on purpose, not by accident.
- Cylinders look like soup cans → top ellipse should be ~25% the height of the body, not 50%. Practice the ellipse.
- Arrows have no heads or two heads → pick a convention. One head = direction. Two heads = bidirectional (but most "bidirectional" things are actually two separate one-way arrows — say so on purpose).
- Diamonds are slanted or asymmetric → use a 4-point method: top, bottom, left, right, then connect. Symmetry sells the shape.

**Concepts to name out loud:**
- *This is **vocabulary before grammar*** — you can't make a sentence without words. You can't make a diagram without shapes you can draw on demand.
- *This is **why "I can't draw" doesn't apply*** — these are 5 shapes. You learned more than 5 letters in kindergarten. The skill is consistency, not artistry.

**After-action prompt:** *"Look at your 10 rectangles. Are they consistent? If a teammate looked at this drawing, would they think you're a careful drawer or a careless one?"*

### Phase 2 — Legibility rules (~10 min)

**Goal:** A label fits inside its shape and is readable from across the room.

**The rules:**

1. **Print, don't cursive.** Cursive is your enemy on a whiteboard.
2. **All caps for top-level labels** (component names, service names). Mixed case for sub-labels (descriptions, attributes).
3. **Letters at least 1.5cm tall** (or 18px+ in Excalidraw) for a normal-sized whiteboard. Big enough to read from the back of the room.
4. **No abbreviations the audience doesn't know.** "DB" is universal. "OWS" is not. Spell out anything proprietary.
5. **Center the label in the shape.** Off-center labels look sloppy.

**The drill:**

Draw 4 rectangles. Label them:

- `API GATEWAY`
- `USER SERVICE`
- `ORDERS DB`
- `EVENT QUEUE`

Step back 2 meters from the board. Can you read all 4 labels clearly? If not, the letters are too small.

**Concepts to name out loud:**
- *This is **the back-of-the-room test*** — if someone can't read your diagram from the back, you've lost half the room. Default to bigger.
- *This is **caps as visual hierarchy*** — caps for proper nouns of the system, mixed case for descriptions. The eye picks out caps first.

**After-action prompt:** *"Take a phone photo of the board from across the room. Zoom in to 100% — can you read every label? What would you change?"*

### Phase 3 — The 4 layout rules (~10 min)

**Goal:** Internalize where to start, which direction to flow, and how to leave room.

**The rules:**

1. **Left-to-right for processes** — input on the left, output on the right. Mirrors how English-speaking readers scan. (For RTL audiences: right-to-left.)
2. **Top-down for hierarchies** — the most important thing at top, dependencies below. Tree shape.
3. **Leave room before you start.** Look at the whole board, pick the area that gives you the most space to extend on the side you'll most likely need it. Most people start in the center; for left-to-right flow, start in the left third.
4. **One concept per area.** If you're drawing two diagrams (architecture + sequence), put them in different quadrants. Never overlap.

**The drill:**

On a clean board, draw this in **left-to-right flow** (don't worry about what it means yet):

```
[CLIENT] → [API] → [SERVICE] → [DATABASE]
```

Then on a clean board, draw this in **top-down hierarchy:**

```
        [ORCHESTRATOR]
        /      |      \
   [SVC A]  [SVC B]  [SVC C]
```

Now combine — on one board, top-half is the hierarchy, bottom-half is the flow. Don't let them touch.

**Concepts to name out loud:**
- *This is **layout as the silent communicator*** — before you say a word, the layout tells the audience how to read your diagram. Left-to-right = "this is a flow." Top-down = "this is a hierarchy."
- *This is **why "leave room" is the rule everyone breaks*** — first-time whiteboarders start in the middle. Then they need to draw 3 more things to the right. Then they erase. Start left.

**After-action prompt:** *"You drew two diagrams. Which one was easier to follow? What does that tell you about the layout rule for that diagram type?"*

### Phase 4 — Draw while talking (~10 min)

**Goal:** Combine drawing and explaining. Don't freeze.

**The drill — narrate as you draw a 5-shape diagram:**

Topic: "Order placement flow in a simple e-commerce site."

You should:

1. Say "We start with the user on the left." Draw a rounded rectangle, label `USER`.
2. Say "The user hits the API gateway." Draw a rectangle to the right, label `API GATEWAY`. Draw arrow from USER to API GATEWAY, label `place order`.
3. Say "The gateway calls the order service." Draw a rectangle, label `ORDER SERVICE`. Arrow with label `create`.
4. Say "Order service writes to the orders database." Draw a cylinder, label `ORDERS DB`. Arrow with label `insert`.
5. Say "And it emits an event." Draw a rectangle (or use a small queue icon), label `EVENT BUS`. Arrow with label `OrderPlaced`.

**Rules during the drill:**
- Never apologize for the drawing.
- Never erase mid-explanation (it breaks the flow). Erase between phases.
- Don't say "um, where do I put this?" Just put it somewhere; you can re-do it later.
- If you finish a shape and don't immediately know the label, say what it does first — the label comes from the description.

**Concepts to name out loud:**
- *This is **the talk-while-drawing tempo*** — explanation drives the diagram. The diagram is the visual proof of what you're saying. Talking first, drawing second, lets your words choose the shape.
- *This is **the no-apology rule*** — "sorry, my drawing is bad" is the most-said and most-useless whiteboard phrase. Drop it forever. Your drawing is fine if it's legible.
- *This is **why erasing kills momentum*** — every erase is a pause that costs audience attention. Plan rough, draw once, refine later.

**After-action prompt:** *"Record yourself doing the drill (phone video). Watch it back. How many times did you apologize, freeze, or erase? What's the count next time?"*

### Phase 5 — Timed practice — explain a system in 5 minutes (~15 min)

**Goal:** A real diagram drawn under time pressure with a real audience or recording.

**The exercise:**

Pick a system you understand well — for example:

- How email works (user, mail server, recipient mail server, recipient client)
- How a public website works (user, CDN, web server, app server, database)
- How signing in with Google works (user, your app, Google, redirect, token)
- How `git push` works (you, your local repo, the remote, the team)

**Constraints:**

- 5 minutes max. Set a timer.
- Use only the 5 shapes from Phase 1.
- Apply the layout rules from Phase 3.
- Talk while you draw (Phase 4).
- Audience: a real person (peer, family member, recording).

**Self-score after:**

| Question | Yes / No |
|---|---|
| Was every shape legible from 2 meters away? | |
| Was every shape labeled? | |
| Was every arrow labeled? | |
| Did the flow direction match a layout rule (LTR for process, TD for hierarchy)? | |
| Did you finish in 5 minutes? | |
| Did you apologize for your drawing zero times? | |
| Could your audience explain the system back to you after? | |

**Concepts to name out loud:**
- *This is **the only test that matters*** — can someone who didn't know the system explain it back? Diagrams are passed Turing tests. If they re-tell it, you taught them.
- *This is **time pressure as a forcing function*** — 5 minutes means you skip the perfect drawing and ship the legible one. Most production whiteboarding happens under similar pressure.

**After-action prompt:** *"You drew under time pressure. Did your hands get clammy? Did you skip the labels? Where did the pressure show up in the diagram? Name the failure mode."*

## When to break the method

- Learner already draws confidently → skip phases 1-2, go straight to phase 5 (timed practice). The drill is unnecessary if the muscle is already there.
- Learner has zero whiteboard access and no Excalidraw → use paper and pen. The shapes are the same. The drill works.
- Time short → phases 1-3-5 are the must-do. Phase 4 (draw-while-talk) is reinforced in every subsequent project.

## Definition of done

Observable, the learner can:

- [ ] Draw 5 shapes consistently in under 3 seconds each.
- [ ] Print labels readable from 2 meters away.
- [ ] Apply left-to-right flow OR top-down hierarchy on a fresh diagram.
- [ ] Draw a 5-shape system diagram in under 5 minutes while explaining it out loud.
- [ ] Explain in one sentence each: the back-of-the-room test, the no-apology rule, why "leave room" is the rule everyone breaks.

## Next project

→ [`wbd-box-and-arrow-diagrams`](../wbd-box-and-arrow-diagrams/SKILL.md) — the architecture diagram. Components, dependencies, data flow direction. When to use a cylinder vs a rectangle vs a cloud. The diagram that opens every architecture conversation.
