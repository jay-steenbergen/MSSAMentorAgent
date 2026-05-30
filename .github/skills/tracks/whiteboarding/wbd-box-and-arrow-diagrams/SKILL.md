---
name: wbd-box-and-arrow-diagrams
description: |
  Whiteboarding track project #2. Learner draws three architecture diagrams (monolith,
  service-oriented, event-driven) using boxes, cylinders, queues, and labeled arrows.
  Learns the C4 model levels (system / container / component), when to use a cloud icon
  for "external," and why every arrow needs a verb. Auto-load when the learner is in
  `whiteboarding/wbd-box-and-arrow-diagrams` or asks how to draw an architecture diagram,
  component diagram, system diagram, or service topology.
---

# Project: `wbd-box-and-arrow-diagrams`

> **Track:** Whiteboarding · **Project:** 2 of 9 · **Time:** ~75 minutes
>
> The architecture diagram is the most-drawn whiteboard artifact in software engineering. It opens every design discussion and ends most arguments. By the end of this project the learner has drawn three real architectures, learned the C4 model's zoom levels, and developed the discipline of "every arrow has a verb."

## Project goal

When this project is done, the learner can:

- Draw a clear architecture diagram showing components, data stores, queues, and external systems.
- Pick the right shape for the right concept: rectangle (service), cylinder (datastore), queue (asynchronous bus), cloud (external system you don't own).
- Apply the **C4 model's** zoom levels — System → Container → Component → Code — and know which level the audience needs.
- Write **arrow labels as verbs** ("queries", "writes", "publishes") that describe the action, not the noun.
- Distinguish **synchronous calls** (solid arrow) from **asynchronous events** (dashed or thick arrow).

## Scope guardrail

This is **3 architectures drawn + C4 zoom drill + arrow-as-verb discipline**. We are not learning sequence diagrams (project #3) or state machines (project #4). The point: build the architecture-diagram muscle that's used in every PR review and design doc.

If the learner asks "but isn't this just UML?" — answer honestly: *no. UML is a formal spec most engineers don't use. The 80% of working architecture diagrams use boxes, cylinders, arrows, and a few conventions. We're learning the 80%*.

## Prerequisites

| Prereq | Verify with |
|---|---|
| Completed [`wbd-whiteboard-foundations`](../wbd-whiteboard-foundations/SKILL.md) — the 5 shapes are muscle memory | Can draw a clean rectangle and labeled arrow in 5 seconds |
| A whiteboard or [Excalidraw](https://excalidraw.com) | Can erase and redraw |

## Phases

### Phase 1 — The component shape catalog (~10 min)

**Goal:** Memorize the visual vocabulary used in 90% of architecture diagrams.

**The catalog:**

| Shape | Means | Example |
|---|---|---|
| **Rectangle** | A service, app, or component you own | `USER SERVICE`, `WEB APP` |
| **Rounded rectangle** | A client (browser, mobile app, CLI) | `WEB BROWSER`, `MOBILE APP` |
| **Cylinder** | A datastore (SQL, NoSQL, blob store) | `POSTGRES`, `S3`, `REDIS` |
| **Queue (3 stacked rectangles, or just a labeled rectangle saying "queue")** | An asynchronous message bus | `KAFKA`, `SQS`, `EVENT BUS` |
| **Cloud** (a fluffy outline) | An external system you don't own | `STRIPE`, `GOOGLE OAUTH`, `THIRD-PARTY API` |
| **Person stick figure** (optional) | An actor / user / operator | `END USER`, `ADMIN` |

**Drill:**

On a clean board, draw and label one of each shape, with a 1-line description under each. Time yourself: 3 minutes. If you spend more than 3 minutes, the muscle memory from project #1 needs another pass.

**Concepts to name out loud:**
- *This is **shape-as-semantic-cue*** — when a reader sees a cylinder, they instantly know "data lives here." When they see a cloud, they instantly know "this isn't us." Save the audience the cognitive load of guessing.
- *This is **the "you don't own clouds" convention*** — clouds mark external dependencies (paid SaaS, public APIs, partner systems). It's a contract boundary worth flagging visually.

**After-action prompt:** *"You drew 6 shapes. If you handed this catalog to a teammate and asked them to draw their system, would they use the same shapes for the same concepts? If not, your catalog isn't a shared vocabulary yet."*

### Phase 2 — Architecture #1: a monolith (~15 min)

**Goal:** Draw the simplest architecture diagram. It's deceptively useful.

**The scenario:** A small e-commerce site, single deployable, single database.

**Components to include:**

- A user with a browser
- A load balancer
- The monolith application (one rectangle — really)
- A SQL database
- An external payment processor (Stripe)
- A CDN for static assets

**Draw it:**

```
[USER]─┐
       │
       ▼
   [BROWSER]
       │
       │ HTTPS
       ▼
   [LOAD BALANCER]
       │
       ▼
  [MONOLITH APP]──────────► [STRIPE] (cloud)
       │
       │ queries / writes
       ▼
   [POSTGRES] (cylinder)

   [CDN] ◄─── static asset requests from BROWSER
```

**Apply phase 1's catalog:**
- Browser = rounded rectangle
- Load balancer, monolith = rectangles
- Postgres = cylinder
- Stripe = cloud
- CDN = rectangle (it's a service you use — could also be cloud if it's e.g. Cloudflare you don't manage)

**Arrows are verbs:**
- USER → BROWSER: `uses`
- BROWSER → LOAD BALANCER: `requests`
- LOAD BALANCER → APP: `forwards`
- APP → POSTGRES: `queries / writes`
- APP → STRIPE: `charges`
- BROWSER → CDN: `fetches assets`

**Concepts to name out loud:**
- *This is **the monolith as a single rectangle*** — it's not lying. The deployable IS one app. Don't pretend it's microservices because that's trendy. Honest diagrams beat impressive ones.
- *This is **arrows as verbs, not nouns*** — "queries" beats "DB." The arrow's job is to describe the action; the shape's job is to describe the noun.

**Common gotchas:**
- Drawing arrows with no labels → the reader has to guess. Always label.
- Drawing a "data" arrow that's really 3 different operations → split it. `queries`, `writes`, `streams` are different things; collapsing them is dishonest.
- Putting Stripe in a regular rectangle → looks like you own it. Use a cloud.

**After-action prompt:** *"You drew a monolith. Imagine a reviewer asks 'what happens when Stripe is down?' Can you point to the diagram and show them the dependency? If yes, the diagram works."*

### Phase 3 — Architecture #2: service-oriented (~15 min)

**Goal:** Same e-commerce site, broken into services. Same shapes, more rectangles, careful arrows.

**Components:**

- User + browser (same)
- API gateway (rectangle — fronts everything)
- User service + users DB (rectangle + cylinder)
- Orders service + orders DB
- Inventory service + inventory DB
- Payments service (talks to Stripe)
- CDN (rectangle)
- Stripe (cloud)

**Draw it left-to-right:**

```
[USER]→[BROWSER]→[API GW]──┬──► [USER SVC] ──► [USERS DB]
                            │
                            ├──► [ORDERS SVC] ──► [ORDERS DB]
                            │           │
                            │           └──► [INVENTORY SVC] ──► [INVENTORY DB]
                            │           │
                            │           └──► [PAYMENTS SVC] ──► [STRIPE] (cloud)
                            │
                            └──► [CDN] for static
```

**Arrows as verbs:**

| Arrow | Verb |
|---|---|
| BROWSER → API GW | `HTTP requests` |
| API GW → USER SVC | `routes /users/*` |
| API GW → ORDERS SVC | `routes /orders/*` |
| ORDERS SVC → INVENTORY SVC | `reserves stock` |
| ORDERS SVC → PAYMENTS SVC | `charges` |
| PAYMENTS SVC → STRIPE | `submits payment` |
| each SVC → its DB | `reads / writes` |

**Concepts to name out loud:**
- *This is **the API gateway as the fan-out point*** — common pattern: one entry, many internal services. Drawing it this way makes the routing visible.
- *This is **why "ORDERS SVC calls INVENTORY SVC" is a design choice with consequences*** — synchronous service-to-service calls couple availability. If inventory is down, orders fail. The diagram makes the coupling visible — and that's the first step to addressing it (project #3 introduces async).
- *This is **one DB per service as a microservices principle*** — shared databases collapse services back into a monolith. The diagram showing 4 cylinders, not 1, is the proof you actually split things.

**After-action prompt:** *"You drew 4 services and 4 databases. If a reviewer asks 'why not one shared DB?' — what's the answer you'd say while pointing at the diagram?"*

### Phase 4 — Architecture #3: event-driven (~15 min)

**Goal:** Add asynchronous messaging. Solid arrows for sync, dashed (or different color) for async.

**Same scenario, now event-driven:** Orders service publishes events; inventory and payments react.

**Components:**

- Same services as Phase 3
- **NEW:** an event bus (queue shape — label `EVENT BUS` or `KAFKA`)
- INVENTORY SVC and PAYMENTS SVC subscribe to events
- A new `NOTIFICATIONS SVC` that sends emails on `OrderPlaced`

**Convention:** **solid arrow = sync request**. **Dashed arrow = async event**. Make this visually obvious.

**Draw:**

```
[USER]→[BROWSER]→[API GW]──► [ORDERS SVC] ──► [ORDERS DB]
                                  │
                                  │ publishes OrderPlaced
                                  ▼
                              [EVENT BUS] (queue shape)
                              ╱    │    ╲
                  consumes ╱       │       ╲ consumes
                          ▼        ▼        ▼
              [INVENTORY SVC] [PAYMENTS SVC] [NOTIFICATIONS SVC]
                      │              │                │
                      ▼              ▼                ▼
              [INVENTORY DB]   [STRIPE]         [EMAIL PROVIDER] (cloud)
```

**Arrows as verbs (and sync/async):**

| Arrow | Verb | Sync or async? |
|---|---|---|
| API GW → ORDERS SVC | `POST /orders` | sync (solid) |
| ORDERS SVC → ORDERS DB | `insert` | sync (solid) |
| ORDERS SVC → EVENT BUS | `publishes OrderPlaced` | async (dashed) |
| EVENT BUS → INVENTORY SVC | `consumes OrderPlaced` | async (dashed) |
| EVENT BUS → PAYMENTS SVC | `consumes OrderPlaced` | async (dashed) |
| EVENT BUS → NOTIFICATIONS SVC | `consumes OrderPlaced` | async (dashed) |
| PAYMENTS SVC → STRIPE | `charges` | sync (solid) |
| NOTIFICATIONS SVC → EMAIL PROVIDER | `sends email` | sync (solid) |

**Concepts to name out loud:**
- *This is **the event bus as the decoupler*** — orders no longer knows about payments or inventory. New consumers (notifications) plug in without modifying orders. The diagram makes this visible.
- *This is **why sync vs async is a critical visual distinction*** — sync means "if the callee is down, I am down." Async means "if the consumer is down, the event waits." Confusing them in a diagram leads to wrong availability analysis.
- *This is **why named events matter*** — `OrderPlaced` is a contract. Not "the event" — name it.

**Common gotchas:**
- Drawing event bus as a regular rectangle → use the queue shape (3 stacked rectangles) or at least label it `BUS / QUEUE`. The shape is the signal.
- Forgetting to mark sync vs async → reviewers can't tell what blocks. Always distinguish.
- Naming the event "the order event" → vague. `OrderPlaced` is the wire-format contract; treat it like a class name.

**After-action prompt:** *"You drew an event-driven version. If a reviewer asks 'what happens if payments is down for an hour?' — walk through the diagram with them. Does the system survive? How long?"*

### Phase 5 — The C4 zoom drill (~20 min)

**Goal:** Internalize that the same system has multiple correct diagrams — one per zoom level.

**The C4 model in 4 levels:**

| Level | Audience | Shapes are... | Example |
|---|---|---|---|
| **System Context** | exec, customer | the whole system as ONE box, plus external systems and actors | "ShopApp interacts with users, Stripe, SendGrid" |
| **Container** | architect, lead engineer | individual deployables — services, databases, queues | the Phase 3 / Phase 4 diagram you drew |
| **Component** | engineers in one service | internal modules within a single container | "OrderService has Controller, ServiceLayer, RepositoryLayer" |
| **Code** | the engineer doing the work | classes, methods | usually a UML class diagram (rare on a whiteboard) |

**The drill:** for the event-driven architecture from Phase 4, draw THREE diagrams:

**Diagram 1 — System Context:**
```
[USER]─►[SHOP APP]◄─►[STRIPE]
                 ◄─►[SENDGRID]
                 ◄─►[GOOGLE OAUTH]
```
Single box for the whole product. External systems as clouds.

**Diagram 2 — Container:** the Phase 4 diagram you already drew.

**Diagram 3 — Component (inside ORDERS SVC):**
```
[ORDERS SVC]
  │
  ├─► [OrdersController] (handles HTTP)
  │        │
  │        ▼
  ├─► [OrderApplicationService] (orchestrates use cases)
  │        │
  │        ├─► [OrderRepository] ──► [ORDERS DB]
  │        ├─► [OrderEventPublisher] ──► [EVENT BUS]
  │        └─► [PriceCalculator] (pure domain logic)
```

**The pitch:** show all three to imaginary audiences:
- Show System Context to an exec — they care that customers exist, money is collected, emails get sent. They don't care about Kafka.
- Show Container to a senior engineer — they want to know which services exist and which DBs.
- Show Component to a junior engineer joining the orders team — they want to know what classes to read.

**Concepts to name out loud:**
- *This is **C4 as a zoom function*** — same system, different magnifications. Pick the magnification the audience needs.
- *This is **why one diagram never serves all audiences*** — putting all 4 levels on one diagram makes it unreadable. Multiple diagrams beat one busy diagram.
- *This is **how to answer "can you draw the architecture?" intelligently*** — your first response should be "for which audience?" not "okay, give me a sec." The question reveals you understand zoom levels.

**After-action prompt:** *"You drew the same system 3 ways. For your next real architecture discussion, which level will the audience need? What's the cost of bringing the wrong level?"*

## When to break the method

- Learner already drew architecture diagrams as a sysadmin → they know the shapes. Spend more time on Phase 5 (C4 zoom) — that's the under-taught discipline.
- Learner is in CSO (security) track → emphasize the trust boundaries between shapes (clouds = external trust, rectangles = internal). Architecture is a security artifact too.
- Time short → phases 2-3-4 are the must-do. Phase 5 (C4) can be a follow-up.

## Definition of done

Observable, the learner can:

- [ ] Show 3 architecture diagrams (monolith, service-oriented, event-driven) with proper shapes.
- [ ] Every arrow has a verb label.
- [ ] Distinguish synchronous from asynchronous arrows visually.
- [ ] Draw the same system at 3 C4 zoom levels (system context, container, component).
- [ ] Explain in one sentence each: shape-as-semantic-cue, arrow-as-verb, sync vs async distinction, C4 as zoom function.

## Next project

→ [`wbd-sequence-diagrams`](../wbd-sequence-diagrams/SKILL.md) — architecture diagrams show *what exists*. Sequence diagrams show *what happens, in what order*. Learn lifelines, messages, and how to make time a dimension on the page.
