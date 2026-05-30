---
name: wbd-state-machines-and-flowcharts
description: |
  Whiteboarding track project #4. Learner draws state machines (for entities with
  lifecycle — order, ticket, user account) and flowcharts (for decision logic —
  triage runbooks, validation rules) and learns when each wins. Drills states vs steps,
  guard conditions, terminal states, and the "every state must have an exit" rule.
  Auto-load when the learner is in `whiteboarding/wbd-state-machines-and-flowcharts`
  or asks how to draw a state machine, flowchart, lifecycle diagram, or decision tree.
---

# Project: `wbd-state-machines-and-flowcharts`

> **Track:** Whiteboarding · **Project:** 4 of 9 · **Time:** ~75 minutes
>
> State machines and flowcharts look similar — they're both boxes and arrows — but they answer different questions. A state machine answers "what states can this thing be in, and how does it move between them?" A flowchart answers "what should we DO, step by step?" Confusing the two leads to ambiguous diagrams. This project drills the distinction and produces three diagrams of each kind.

## Project goal

When this project is done, the learner can:

- Draw a state machine with states (rounded rectangles), transitions (arrows labeled with the event that causes them), and terminal states.
- Draw a flowchart with steps (rectangles), decisions (diamonds), and start/end markers (rounded rectangles or pills).
- Distinguish a state machine (about an entity's lifecycle) from a flowchart (about a process's logic).
- Apply the **"every state must have an exit"** rule — no orphan states except terminals.
- Use **guard conditions** on transitions (`[order_total > $50]`) to express conditional state changes.

## Scope guardrail

This is **3 state machines + 3 flowcharts + 1 decision drill**. We are not learning full UML state machine notation (hierarchical states, parallel regions, history pseudo-states). The point: the 80% used in working teams to model order lifecycle, ticket workflows, retry logic, and triage runbooks.

If the learner asks "what about Petri nets / process algebra?" — answer honestly: *useful in academic and embedded contexts, rare in working engineering teams. Skip them unless you're doing safety-critical work*.

## Prerequisites

| Prereq | Verify with |
|---|---|
| Completed [`wbd-whiteboard-foundations`](../wbd-whiteboard-foundations/SKILL.md) — the 5 shapes (especially the diamond) are muscle memory | Can draw a symmetric diamond in 3 seconds |
| A whiteboard, paper, or Excalidraw | Can draw and label freely |

## Phases

### Phase 1 — Anatomy of a state machine (~10 min)

**Goal:** Draw and label every part on a blank board.

**The parts:**

| Part | Shape | Means |
|---|---|---|
| **State** | Rounded rectangle, label like `PENDING` (capital, noun-form) | A condition the entity can be in |
| **Initial state** | A solid filled circle with an arrow into the first state | Where instances start |
| **Terminal state** | A circle with a smaller filled circle inside (double-ring), OR a rounded rectangle labeled `COMPLETED` / `CANCELLED` | The entity reached the end |
| **Transition** | Arrow from one state to another, labeled `event[guard]/action` | What event causes the move |
| **Self-transition** | Arrow that loops back to the same state | An event that doesn't change state but does something |

**Drill — draw the anatomy of a simple light switch state machine:**

```
   ●─────►( OFF )──────turn_on──────►( ON )
              ▲                           │
              │                           │
              └────────turn_off───────────┘
```

(Use rounded rectangles instead of parentheses on the actual board.)

**Concepts to name out loud:**
- *This is **states as conditions, not actions*** — `PENDING` is a state (the entity is in this condition). `verify_payment` is an action, not a state. If your label is a verb, you have a flowchart, not a state machine.
- *This is **transitions as events that cause change*** — the arrow's label is what HAPPENED. `payment_received`, `cancellation_requested`, `timer_expired`. Not "go to next state" — name the event.

**After-action prompt:** *"Look at your light switch. Could a programmer write a `LightSwitch` class with two methods (`turn_on`, `turn_off`) and one field (`state: str`) from this diagram alone? If yes, the diagram is complete."*

### Phase 2 — State machine #1: order lifecycle (~15 min)

**Goal:** Model an e-commerce order's full lifecycle.

**The states:**

- `PENDING` (just placed)
- `PAID` (payment cleared)
- `FULFILLING` (warehouse picking)
- `SHIPPED` (in transit)
- `DELIVERED` (terminal)
- `CANCELLED` (terminal — could happen from any non-terminal state)
- `REFUNDED` (terminal — only reachable from `PAID` / `SHIPPED` / `DELIVERED`)

**Transitions:**

```
   ●─►( PENDING )──payment_received─►( PAID )──stock_reserved─►( FULFILLING )──handed_to_carrier─►( SHIPPED )──carrier_confirms_delivery─►(( DELIVERED ))
              │                          │                              │                              │                              │
              │ cancellation_requested   │ cancellation_requested       │ shipper_failure              │ undeliverable                 │ refund_requested
              │                          │                              │                              │                              │
              ▼                          ▼                              ▼                              ▼                              ▼
       (( CANCELLED ))            (( CANCELLED ))                (( CANCELLED ))               (( REFUNDED ))                 (( REFUNDED ))
```

(Use double-circle or "((" notation for terminal states.)

**Apply the "every state must have an exit" rule:**

For each state, walk through: "what events can happen here, and where do they take us?" If a state has no outgoing arrows AND isn't terminal, you have a bug — instances can get stuck.

**Concepts to name out loud:**
- *This is **the dead-letter test*** — can an order get stuck somewhere it can't leave? If yes, you have a stuck-order bug in production that the diagram caught.
- *This is **terminal states as contracts*** — `DELIVERED`, `CANCELLED`, `REFUNDED` are the END. Nothing leaves. Engineers should treat anything in a terminal state as immutable.
- *This is **why "PAID → SHIPPED" without going through "FULFILLING" would be a bug*** — sequence matters. The state machine enforces order.

**Common gotchas:**
- Drawing transitions labeled with state names ("PAID → SHIPPED") → wrong. Transitions are labeled with EVENTS, not destinations.
- Missing cancellation paths → in real systems, most non-terminal states need a cancellation transition. Don't omit them.
- Creating a state called `PROCESSING` → vague. What is being processed? `FULFILLING` is better. States should describe the entity's actual condition.

**After-action prompt:** *"You drew 7 states. Walk through each one and ask: can the order get stuck here? Are all the events covered? If you find a gap, the state machine is incomplete."*

### Phase 3 — State machine #2: support ticket with reopens (~15 min)

**Goal:** Practice self-transitions and re-entry patterns.

**The states:**

- `NEW` (just submitted)
- `TRIAGED` (a human looked at it, assigned priority)
- `IN_PROGRESS` (someone is working it)
- `WAITING_ON_CUSTOMER` (we asked a question)
- `RESOLVED` (we believe it's done)
- `CLOSED` (terminal — customer confirmed or 7 days passed)

**Transitions to capture:**

- `NEW → TRIAGED`: `agent_picks_up`
- `TRIAGED → IN_PROGRESS`: `agent_starts_work`
- `IN_PROGRESS → WAITING_ON_CUSTOMER`: `agent_asks_question`
- `WAITING_ON_CUSTOMER → IN_PROGRESS`: `customer_responds`
- `WAITING_ON_CUSTOMER → CLOSED`: `7_days_no_response`  (timer-based)
- `IN_PROGRESS → RESOLVED`: `agent_marks_resolved`
- `RESOLVED → IN_PROGRESS`: `customer_says_not_resolved` (**the reopen!**)
- `RESOLVED → CLOSED`: `customer_confirms` OR `7_days_no_response`

**Concepts to name out loud:**
- *This is **the reopen as a loop back to a non-initial state*** — `RESOLVED → IN_PROGRESS` is the "this isn't fixed" case. Without it, customers have to file a new ticket and lose context.
- *This is **timer-based transitions as a real category*** — `7_days_no_response` isn't a customer action. It's an automated event. Distinguish these (some teams use a different arrow style for time-based transitions).
- *This is **why a ticket system without a reopen is bad UX*** — the diagram makes the missing transition obvious. Drawing it forces the conversation.

**Common gotchas:**
- Forgetting the reopen → "the customer can just file a new ticket" is a UX failure disguised as a missing transition.
- Confusing `WAITING_ON_CUSTOMER` with `CLOSED` → they're different. Waiting means active engagement; closed means terminated. The diagram clarifies.
- Drawing every transition twice (one each direction) → only draw the transitions that actually exist. `CLOSED → IN_PROGRESS` would mean reopening a closed ticket — only valid if your system supports it. Decide first.

**After-action prompt:** *"You drew the reopen. If a product manager asks 'should we allow re-opening closed tickets too?' — your diagram is the answer. Add the transition or argue against it."*

### Phase 4 — Anatomy of a flowchart + flowchart #1: deployment runbook (~15 min)

**Goal:** Switch gears to flowcharts — about logic and decisions, not state.

**Flowchart parts:**

| Part | Shape | Means |
|---|---|---|
| **Start / End** | Rounded rectangle or pill | The beginning / end of the process |
| **Step / action** | Rectangle, label as a verb phrase | A thing the operator does |
| **Decision** | Diamond, label as a yes/no question | Branch point |
| **Connector** | Small circle with a letter (A, B...) | Used to avoid drawing long arrows across the page |

**Flowchart #1 — deployment runbook:**

```
                        ( START )
                            │
                            ▼
                  [ Read change log ]
                            │
                            ▼
                  <  Tests passing?  >
                   ╱           ╲
                 yes            no
                  │              │
                  ▼              ▼
       [ Tag release ]   [ Stop. Fix tests. ]
                  │
                  ▼
       [ Deploy to staging ]
                  │
                  ▼
       <  Smoke tests pass?  >
            ╱           ╲
          yes            no
            │              │
            ▼              ▼
  [ Deploy to prod ]   [ Rollback staging ]
            │              │
            ▼              ▼
  [ Monitor for 30 min ]  ( END )
            │
            ▼
  < Errors > baseline? >
       ╱           ╲
     yes            no
      │              │
      ▼              ▼
[ Rollback prod ] ( END )
      │
      ▼
   ( END )
```

**Concepts to name out loud:**
- *This is **the diamond as a yes/no fork*** — diamonds always have ≥ 2 outgoing arrows, one per answer. Label every outgoing arrow with the answer (`yes`/`no` or specific values).
- *This is **why every flowchart has a single START and one or more END*** — bounded processes are testable. Unbounded loops are bugs (usually).
- *This is **how flowcharts model runbooks*** — the diagram IS the procedure. An operator can follow it without explanation. That's the test.

**Common gotchas:**
- Forgetting to label both outcomes of a decision → readers guess. Always label.
- Using rectangles where diamonds belong → "Test result is X" should be a decision, not a step. If the next move depends on the answer, it's a decision.
- Cycles without exit conditions → infinite loop. Every cycle needs at least one decision that can break out.

**After-action prompt:** *"You drew a deployment runbook. Hand it to someone who's never deployed — could they follow it? If they ask questions, those questions are the gaps in your flowchart."*

### Phase 5 — When state machine vs when flowchart (~20 min)

**Goal:** Internalize the distinction so you never confuse them again.

**The test:**

| Question | Diagram |
|---|---|
| "What conditions can an Order be in?" | **State machine** (about an entity's lifecycle) |
| "How does an operator deploy to production?" | **Flowchart** (about a process's logic) |
| "How does a support ticket flow through statuses?" | **State machine** |
| "How does our triage team decide severity of an incident?" | **Flowchart** |
| "What happens when a payment fails?" | **State machine** (if you're modeling Payment's lifecycle) OR **flowchart** (if you're modeling the operator's response process) |
| "What's the validation logic for a new user signup?" | **Flowchart** |
| "What's the lifecycle of a feature flag?" | **State machine** |

**The acid test:**
- If you would say "the entity moves from state X to state Y" → state machine.
- If you would say "first do X, then if Y do Z" → flowchart.

**Drill — for each scenario, draw the right diagram:**

1. **The lifecycle of a job posting on a hiring site** (`DRAFT → OPEN → INTERVIEWING → OFFERED → FILLED` or `CLOSED`).
2. **The triage procedure for a new IcM incident** (severity question, customer-facing question, escalation question).
3. **The lifecycle of a software bug** (`NEW → ASSIGNED → IN_PROGRESS → IN_REVIEW → FIXED` or `WONTFIX`).
4. **The procedure for handling a production database failover** (steps + decisions).
5. **The lifecycle of an Azure VM** (`CREATING → RUNNING → STOPPING → STOPPED → TERMINATED`).

For each, decide: state machine or flowchart? Then draw it (briefly — 3 minutes each).

**Concepts to name out loud:**
- *This is **the entity-vs-process distinction*** — state machines describe things; flowcharts describe processes. Each has a job; mixing them produces ambiguity.
- *This is **why hybrid diagrams confuse readers*** — drawing decisions (diamonds) on a state machine OR drawing states (rounded rectangles) on a flowchart breaks the visual convention. Stick to one shape vocabulary per diagram.

**After-action prompt:** *"You drew 5 diagrams across both types. Which one was hardest to classify? What does that tell you about the gray area?"*

## When to break the method

- Learner is in CSO track → state machines are great for modeling attack chains (entity = "attack progress", states = `RECON / INITIAL_ACCESS / EXECUTION / EXFILTRATION`). Flowcharts are great for IR runbooks. Both transfer directly.
- Learner has used drawio extensively → they may already know diamond conventions. Skim Phase 4, drill Phase 5 (the distinction is the harder skill).
- Time short → phases 2-4-5 are the must-do. Phase 3 (ticket reopens) reinforces.

## Definition of done

Observable, the learner can:

- [ ] Show 2 state machines (order lifecycle, support ticket with reopen).
- [ ] Show 1 flowchart (deployment runbook).
- [ ] Articulate the entity-vs-process distinction in one sentence.
- [ ] For 5 mixed scenarios, correctly pick state machine or flowchart and draw it.
- [ ] Explain in one sentence each: every-state-must-have-an-exit, transitions-as-events, decisions-have-≥2-labeled-outgoing-arrows.

## Next project

→ [`wbd-entity-relationship-diagrams`](../wbd-entity-relationship-diagrams/SKILL.md) — when the question is "how is the data modeled?", you need an ER diagram. Learn entities, attributes, relationships, and cardinality (one-to-one, one-to-many, many-to-many) — and how to spot a missing junction table.
