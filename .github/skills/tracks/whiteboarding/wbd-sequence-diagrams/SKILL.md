---
name: wbd-sequence-diagrams
description: |
  Whiteboarding track project #3. Learner draws sequence diagrams to show what happens
  over time across actors and components. Drills lifelines, messages, sync vs async,
  return arrows, activation bars, and the "happy path then failure path" discipline.
  Walks 3 scenarios: login, place-order, retry-on-failure. Auto-load when the learner
  is in `whiteboarding/wbd-sequence-diagrams` or asks how to draw a sequence diagram,
  show interactions over time, model a request flow, or diagram an API conversation.
---

# Project: `wbd-sequence-diagrams`

> **Track:** Whiteboarding · **Project:** 3 of 9 · **Time:** ~75 minutes
>
> Architecture diagrams (project #2) answer "what exists." Sequence diagrams answer "what happens, in what order." When the question is "walk me through what happens when a user logs in" — the right answer is a sequence diagram, not a box-and-arrow diagram. By the end of this project the learner can draw a sequence diagram for any request flow in under 5 minutes.

## Project goal

When this project is done, the learner can:

- Draw a sequence diagram with **lifelines** (vertical lines under each actor/component) and **messages** (horizontal arrows between lifelines).
- Distinguish **synchronous calls** (solid arrow with filled head) from **asynchronous events** (open arrowhead or dashed) and **return values** (dashed arrow).
- Use **activation bars** (thin rectangles on lifelines) to show when a component is "busy."
- Always draw the **happy path first**, then add the **failure path** on a separate diagram or in a different color.
- Articulate when a sequence diagram beats an architecture diagram (multi-step flow, timing matters, async coordination) and vice versa.

## Scope guardrail

This is **3 sequence diagrams + activation bar drill + happy-path-first discipline**. We are not learning UML sequence diagrams in their full formal glory (alt/opt/loop fragments — covered briefly but not drilled). The point: master the 90% used in real engineering conversations.

If the learner asks "should I always draw activation bars?" — answer honestly: *no — they're optional. On a whiteboard most engineers skip them. Use them when timing or concurrency is the topic; skip them otherwise*.

## Prerequisites

| Prereq | Verify with |
|---|---|
| Completed [`wbd-box-and-arrow-diagrams`](../wbd-box-and-arrow-diagrams/SKILL.md) — sync vs async distinction clear | Can draw an architecture with correct shapes |
| A whiteboard, paper, or [Excalidraw](https://excalidraw.com) | Can draw vertical lines and horizontal arrows |

## Phases

### Phase 1 — The anatomy of a sequence diagram (~10 min)

**Goal:** Draw and label every part of a sequence diagram on a blank board.

**The parts:**

| Part | What it looks like | Means |
|---|---|---|
| **Actor / lifeline head** | A box at the top (or a stick figure for a person) with a name | One participant in the conversation |
| **Lifeline** | A vertical dashed (or solid) line dropping from the actor box | The actor's existence over time |
| **Message** | A horizontal arrow from one lifeline to another, labeled | A call, send, or event |
| **Return** | A dashed horizontal arrow going back | A response or return value |
| **Activation bar** | A thin vertical rectangle on a lifeline | "This actor is actively processing right now" |
| **Time axis** | Implicit — top is earliest, bottom is latest | Time flows downward |

**Drill — draw the anatomy:**

```
  [USER]          [API]          [DB]
    │              │              │
    │  login(u,p)  │              │
    ├─────────────►│              │
    │              ├─┐            │
    │              │ │ (active)   │
    │              │ │   query   │
    │              │ ├───────────►│
    │              │ │            │
    │              │ │   row     │
    │              │ │◄ ─ ─ ─ ─ ─│
    │              │ │            │
    │   token      │ │            │
    │◄ ─ ─ ─ ─ ─ ─ │ │            │
    │              │ │            │
    │              ▼ ▼            ▼
```

Note:
- Actors at top (rectangles, or stick figure for the USER).
- Lifelines drop straight down.
- Arrows are horizontal, labeled with the action.
- Returns are dashed.
- Activation bar (thin vertical rectangle) shows when API is processing.
- Time flows top-to-bottom.

**Concepts to name out loud:**
- *This is **time as a dimension on the page*** — architecture diagrams have no time. Sequence diagrams use vertical position to mean "later." This is the whole difference.
- *This is **why arrows are horizontal, not diagonal*** — diagonal arrows imply some other meaning (slow? lossy?). Horizontal = instantaneous (or at least, sequential). Keep them horizontal.
- *This is **why returns are dashed*** — visually distinct from sends. Without this convention, readers can't tell call-and-response from two separate calls.

**After-action prompt:** *"You drew the anatomy. Cover the labels and look at it — can you still tell which arrows are calls and which are returns? If not, your conventions aren't visually distinct enough."*

### Phase 2 — Sequence #1: user login (~15 min)

**Goal:** A full login flow as a sequence diagram, drawn in under 5 minutes.

**The scenario:** User submits username + password. API validates, queries DB, returns a token.

**Actors:**
- USER (stick figure)
- BROWSER (rounded rectangle)
- API
- DB

**Messages (in order):**

1. USER → BROWSER: `submits login form`
2. BROWSER → API: `POST /login {user, pass}`
3. API → DB: `SELECT * FROM users WHERE email=?`
4. DB → API: `user row (with hashed_password)` (dashed return)
5. API → API: `verify password hash` (self-message, an arrow looping back)
6. API → BROWSER: `200 OK { token }` (dashed return)
7. BROWSER → USER: `redirect to dashboard`

**Draw:**

```
[USER]   [BROWSER]   [API]    [DB]
  │         │         │        │
  │ submit  │         │        │
  ├────────►│         │        │
  │         │ POST    │        │
  │         ├────────►│        │
  │         │         │ SELECT │
  │         │         ├───────►│
  │         │         │  row   │
  │         │         │◄ ─ ─ ─ │
  │         │         ├─┐      │  (self-msg: verify hash)
  │         │         │◄┘      │
  │         │  token  │        │
  │         │◄ ─ ─ ─ ─│        │
  │ redirect│         │        │
  │◄────────│         │        │
  ▼         ▼         ▼        ▼
```

**Concepts to name out loud:**
- *This is **self-messages as in-process work*** — `verify hash` doesn't leave the API. The looped arrow on the API's own lifeline shows internal work that took time. Useful for showing "this is where the latency comes from."
- *This is **why the order of actors left-to-right matters*** — convention is initiator on the left. USER initiated the login → USER goes leftmost. The eye reads left-to-right; the action flow generally follows.

**Common gotchas:**
- Arrows that go up instead of down → time goes DOWN. Late arrows below early arrows. Reversing this confuses everyone.
- Crossing arrows (e.g., API → DB drawn through BROWSER's lifeline) → reorder actors to minimize crossings. Put actors that talk to each other adjacent.
- Forgetting returns → if the call gets a response, draw the dashed return. Otherwise the reader can't tell if the call is sync or fire-and-forget.

**After-action prompt:** *"You drew the login flow. If your audience asks 'where does the latency come from?' — can you point to the parts of the diagram that show it? The self-message helps here."*

### Phase 3 — Sequence #2: place order in event-driven system (~20 min)

**Goal:** Same event-driven architecture from project #2, but now showing the temporal flow.

**The scenario:** User places an order. Order is saved. Event is published. Three async consumers react.

**Actors:**
- USER
- API GATEWAY (`API GW`)
- ORDERS SVC
- ORDERS DB
- EVENT BUS
- INVENTORY SVC
- PAYMENTS SVC
- NOTIFICATIONS SVC

**Messages:**

1. USER → API GW: `POST /orders`
2. API GW → ORDERS SVC: `forward request`
3. ORDERS SVC → ORDERS DB: `INSERT order`
4. ORDERS DB → ORDERS SVC: `order_id` (dashed)
5. ORDERS SVC → EVENT BUS: `publish OrderPlaced(order_id)` — **async (open arrowhead)**
6. ORDERS SVC → API GW: `201 Created { order_id }` (dashed)
7. API GW → USER: `201 Created` (dashed)

— Now the user has already gotten their response. The rest is async. Draw it BELOW the user response with a small visual gap or a horizontal separator line:

8. EVENT BUS → INVENTORY SVC: `OrderPlaced` (async, fans out)
9. EVENT BUS → PAYMENTS SVC: `OrderPlaced` (async)
10. EVENT BUS → NOTIFICATIONS SVC: `OrderPlaced` (async)
11. INVENTORY SVC → INVENTORY SVC: `reserve stock` (self-message)
12. PAYMENTS SVC → STRIPE: `charge` (sync)
13. NOTIFICATIONS SVC → EMAIL: `send confirmation` (sync)

**Concepts to name out loud:**
- *This is **the user's response time vs the system's total work time*** — the user got 201 Created in 3 messages. The other 6 messages happen AFTER the user is gone. This is the value proposition of event-driven systems, and the diagram makes it visible.
- *This is **how fan-out looks in a sequence*** — three separate arrows from EVENT BUS at roughly the same vertical position, going to three different consumers.
- *This is **why a horizontal separator line is useful*** — visually marks "below this line, the user is no longer waiting." Some teams call this the "sync/async fence."

**Common gotchas:**
- Drawing the event publishing as sync (filled arrowhead) → wrong signal. Async needs visual distinction (open arrowhead, or dashed line, or different color).
- Putting the user response AT the bottom → wrong. The user got their response after step 7. Async work continues, but the user is gone. Show that.
- Trying to draw all 3 consumer-side actions in detail → on a whiteboard, you'll run out of room. Pick the ONE consumer that matters for the conversation; mention the others.

**After-action prompt:** *"You drew the async fence. If a reviewer asks 'how fast does the user see a response?' — can you point to the diagram and tell them how many steps the user waits for? That's the latency story."*

### Phase 4 — Sequence #3: failure path with retry (~15 min)

**Goal:** Show what happens when something fails. Draw on a fresh diagram or in a different color.

**The scenario:** Same place-order flow, but PAYMENTS SVC fails on first attempt. System retries 3 times with exponential backoff, succeeds on attempt 2.

**Why on a separate diagram:** the happy path is the contract; failure paths are the exceptions. Mixing them makes the diagram unreadable. Convention: one diagram for happy path, one (or more) per failure mode.

**Messages on the failure path (focus on the relevant subsystem):**

1. EVENT BUS → PAYMENTS SVC: `OrderPlaced` (from happy-path diagram, repeated as starting point)
2. PAYMENTS SVC → STRIPE: `charge`
3. STRIPE → PAYMENTS SVC: `500 Internal Error` (dashed)
4. PAYMENTS SVC → PAYMENTS SVC: `wait 1s` (self-message, label the duration)
5. PAYMENTS SVC → STRIPE: `charge (retry 1)`
6. STRIPE → PAYMENTS SVC: `200 OK { txn_id }` (dashed)
7. PAYMENTS SVC → ORDERS SVC: `PaymentCompleted` (event, async)

— OR — failure path where retries exhaust:

1-4. Same as above
5. PAYMENTS SVC → STRIPE: `charge (retry 1)`
6. STRIPE → PAYMENTS SVC: `500 Error`
7. PAYMENTS SVC → PAYMENTS SVC: `wait 2s`
8. PAYMENTS SVC → STRIPE: `charge (retry 2)`
9. STRIPE → PAYMENTS SVC: `500 Error`
10. PAYMENTS SVC → EVENT BUS: `publish PaymentFailed(order_id, reason)`
11. ORDERS SVC: subscribes to PaymentFailed → marks order as `payment_failed` → notifies user

**Concepts to name out loud:**
- *This is **the failure path as a first-class artifact*** — most systems handle the happy path correctly. Most outages happen in failure paths. Drawing the failure path explicitly is how you ensure the team has thought through it.
- *This is **retry-with-backoff as a visible pattern*** — the increasing `wait Xs` self-messages make the strategy obvious. Without drawing them, "we retry" is just words.
- *This is **why the dead-letter path matters*** — what happens after all retries fail? `PaymentFailed` event lets ORDERS SVC compensate. Without this, the order sits in limbo forever.

**Common gotchas:**
- Drawing the failure path on the same diagram in the same color → unreadable. Use a different color or a different diagram.
- Skipping the retry waits → understates how long the failure path takes. Annotate the durations.
- Forgetting the compensating action (PaymentFailed event, user notification) → the diagram shows the failure but not the recovery. Always show recovery, or admit "there is none — we'll log and humans investigate."

**After-action prompt:** *"You drew a failure path. Does your audience now know (a) what happens during the retry, and (b) what happens after retries exhaust? If yes, the diagram works."*

### Phase 5 — When to use sequence vs architecture vs other (~15 min)

**Goal:** Codify which diagram type fits which question.

**The decision tree:**

| If the question is... | Use... |
|---|---|
| "What are the parts of the system?" | Architecture diagram (project #2) |
| "What depends on what?" | Architecture diagram |
| "What happens when a user does X?" | **Sequence diagram** |
| "What's the order of operations?" | **Sequence diagram** |
| "How does this async flow work?" | **Sequence diagram with sync/async fence** |
| "What's the failure mode and recovery?" | **Sequence diagram (failure path)** |
| "What states does this entity go through?" | State diagram (project #4) |
| "How is the data modeled?" | ER diagram (project #5) |
| "What's the decision logic?" | Flowchart (project #4) |

**The drill:**

For each of these questions, decide which diagram type and (briefly) sketch it:

1. "Walk me through what happens when an order is placed." → sequence
2. "Show me how the services connect." → architecture
3. "What does an order look like? What fields?" → ER
4. "What's the flow if payment fails 3 times?" → sequence (failure path)
5. "When can an order be cancelled?" → state diagram

**Concepts to name out loud:**
- *This is **diagram type as answer-shape*** — every diagram type answers a different question well. Picking the wrong type leads to unreadable answers.
- *This is **why drawing the wrong diagram type wastes the audience's time*** — drawing an architecture when they asked about a flow forces them to mentally translate. They might or might not.

**After-action prompt:** *"You have a decision tree for diagram type. Walk through your last design discussion — which questions came up? Which diagrams would have served best?"*

## When to break the method

- Learner is going into an SRE/oncall role → spend more time on Phase 4 (failure paths). Failure-path diagrams are the bread and butter of incident response.
- Learner has used UML before → skip Phase 1 anatomy drill, go straight to Phase 2.
- Time short → phases 2-3-5 are the must-do. Phase 4 (failure path) is depth.

## Definition of done

Observable, the learner can:

- [ ] Draw the anatomy of a sequence diagram (lifelines, messages, returns, activation bars) on a blank board.
- [ ] Show 3 sequence diagrams: login, place-order (with async fence), failure path with retry.
- [ ] Distinguish sync (solid arrow, filled head) from async (open head or dashed) from return (dashed).
- [ ] Walk through the decision tree and pick the right diagram type for 5 different questions.
- [ ] Explain in one sentence each: time as a dimension, the sync/async fence, why failure paths get their own diagram.

## Next project

→ [`wbd-state-machines-and-flowcharts`](../wbd-state-machines-and-flowcharts/SKILL.md) — when the question is "what states can this entity be in?" or "what's the decision logic?", you reach for state machines and flowcharts. Learn the difference, when each wins, and why most engineers confuse them.
