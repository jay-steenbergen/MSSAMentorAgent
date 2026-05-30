---
name: wbd-system-design-interview
description: |
  Whiteboarding track project #8. Learner runs 3 timed system design interview drills
  (URL shortener, Twitter feed, chat app) using a 6-step framework: requirements → API
  → data → high-level design → deep dive → trade-offs. Drills clarifying questions,
  back-of-envelope capacity estimation, and the "narrate while drawing" tempo. Auto-load
  when the learner is in `whiteboarding/wbd-system-design-interview` or asks about
  system design interviews, design TinyURL, design Twitter, scalability whiteboarding,
  or how to handle a 45-minute design interview.
---

# Project: `wbd-system-design-interview`

> **Track:** Whiteboarding · **Project:** 8 of 9 · **Time:** ~90 minutes
>
> The system design interview is whiteboarding under pressure. 45 minutes. One interviewer watching every move. A vague prompt ("design Twitter"). Most candidates fail not because they don't know the systems, but because they don't have a framework — they freeze, jump straight to a database, or never ask what's actually being asked. This project gives the learner a 6-step framework, three rehearsals, and the "narrate while drawing" tempo that makes interviewers comfortable.

## Project goal

When this project is done, the learner can:

- Walk into a 45-minute system design interview with a **6-step framework** memorized: Requirements → API → Data Model → High-Level Design → Deep Dive → Trade-offs.
- **Ask clarifying questions** in the first 5 minutes — read scale, identify what's in scope.
- Do **back-of-envelope capacity estimation** (QPS, storage, bandwidth) without panic.
- **Narrate while drawing** — the interviewer can follow the thinking, not just see the result.
- Recover from getting stuck by **stating the trade-off** rather than freezing.
- Self-score with a 5-point rubric and identify the weakest of the six steps.

## Scope guardrail

This is **3 timed drills + framework drill + recovery patterns**. We are not memorizing every system design pattern (consistent hashing, gossip protocols, vector clocks — exist, mention if relevant, don't drill). The point: own the framework and the tempo. The patterns come from reading System Design Interview Vol 1/2 (Alex Xu) AFTER this project.

If the learner asks "should I read the books before this?" — answer honestly: *no. Do this project first. The framework gives you a structure that makes the patterns from the books stick. Books first = facts in a vacuum*.

## Prerequisites

| Prereq | Verify with |
|---|---|
| Completed projects 2-5 (architecture, sequence, state, ER) — knows the diagram types | Can draw a 3-tier web app + a sequence diagram for one flow |
| Basic familiarity with REST APIs, SQL vs NoSQL, caching, queues | Can describe each in one sentence |
| A whiteboard or Excalidraw | — |
| A timer | Phone is fine |

## Phases

### Phase 1 — The 6-step framework (~10 min)

**Goal:** Memorize the framework. You'll use it for every interview.

**The 6 steps + recommended time-box for a 45-minute interview:**

| Step | Time | What you do |
|---|---|---|
| **1. Requirements** | 5 min | Ask functional + non-functional. Get scale numbers. Confirm scope. |
| **2. API** | 5 min | Sketch the public-facing API (REST endpoints, gRPC methods, or message contracts). |
| **3. Data model** | 5 min | Sketch entities (ER style) — what data exists, what relationships. |
| **4. High-level design** | 10 min | Box-and-arrow architecture: client, services, queues, DBs, caches, CDNs. |
| **5. Deep dive** | 15 min | Interviewer picks 1-2 components or scenarios; go deep — scale, failure modes, alternatives. |
| **6. Trade-offs + wrap-up** | 5 min | "What I'd do differently with more time, what I'd add, what concerns remain." |

**The opening monologue (rehearse this):**

When the interviewer says "design X," your FIRST words should be:

> *"Great. Before I jump in — let me ask a few questions to scope it. Then I'll sketch the API, then the data model, then the high-level architecture, then we can dive into whichever piece you want. Sound good?"*

This buys you:
- A moment to think.
- An explicit contract about HOW you'll use the time.
- A signal that you have a framework (most candidates don't).

**Drill — write the 6 steps on the board in big letters down the left margin:**

```
1. REQS
2. API
3. DATA
4. HLD
5. DEEP
6. TRADE
```

Now they're visible to you AND to the interviewer. You can't lose track.

**Concepts to name out loud:**
- *This is **the framework as the scaffolding*** — you're not making up the structure on the fly. The framework holds while you focus on the content.
- *This is **why the opening monologue matters*** — interviewers grade you on communication too. Signaling structure in the first 30 seconds shifts the room's posture from skepticism to following along.

**After-action prompt:** *"You memorized 6 steps. If the interviewer interrupts at step 3 and asks an unrelated question, you can say 'good question, I'll come back to that when we hit step 5 (deep dive).' That's what a framework lets you do."*

### Phase 2 — Drill #1: Design TinyURL (~25 min, timed)

**Goal:** First timed drill. The classic warm-up. Use the framework strictly.

**Set a 25-minute timer. Use the framework time-boxes (5 / 5 / 5 / 10 / — / — for this short version — skip deep-dive for the warm-up).**

**Step 1 — Requirements (5 min):**

Ask out loud (and answer for yourself, simulating an interviewer):

- **Functional:** Shorten a long URL into a short URL. Resolve a short URL back to the original (redirect). Maybe analytics?
- **Non-functional:** How many URLs created per day? (Assume **100M / day** = ~1,200 / sec.) How many redirects? (Assume 10x reads = **1B / day** = ~12,000 / sec). Latency? (< 100ms for redirect.) Availability? (99.99% — it's a redirect service.)
- **Scope:** custom aliases? Expiration? Analytics? (Decide what's in / out. Default: shortening + redirect + 5-year persistence; analytics is stretch.)

**Step 2 — API (5 min):**

```
POST /shorten
  body: { url: string, custom_alias?: string }
  → 200 { short_url: string }

GET /{short_code}
  → 301 redirect to original
```

**Step 3 — Data model (5 min):**

```
URL_MAPPING
  short_code  (PK, varchar(8))
  long_url    (text)
  created_at  (timestamp)
  created_by  (user_id, nullable)
  click_count (bigint)
  expires_at  (timestamp, nullable)
```

Mention: ~100M new URLs/day × 5 years = ~180B rows. Storage per row ~500 bytes → ~90 TB. Need sharding.

**Step 4 — High-level design (10 min):**

```
[Client] → [Load Balancer] → [API Servers] ──► [Redis Cache (short → long)]
                                          ──► [URL Database (sharded by short_code)]
                                          ──► [ID Generator (Snowflake or counter)]
                              [Analytics Pipeline] ◄── async events from API
```

**Key design decisions to mention:**
- **Short code generation:** counter-based (sequential, then base62-encode) OR hash-based (MD5 of URL, take first N chars). Counter is simpler; hash allows dedup of identical URLs. Mention both.
- **Cache:** Redis in front of the DB for hot URLs. ~90% of reads hit cache.
- **Sharding:** by short_code (consistent hashing), since lookups are by short_code.
- **CDN for the redirect endpoint:** the response is tiny (a 301), often cached at the edge for popular URLs.

**Step 5 + 6 (skip for the warm-up, or do a 5-min lightning trade-offs round):**

- "If we used hash-based codes, we'd avoid storing duplicates but lose custom aliases. I chose counter-based for simplicity."
- "Cache hit rate determines latency. If it drops below 90%, we'd see DB pressure."
- "Sharding by short_code means range queries (find all my URLs) are slow. We'd need a secondary index by user_id."

**Stop the timer. How did you do?**

**Concepts to name out loud:**
- *This is **scale numbers as a forcing function*** — once you say "100M/day," it forces "sharded DB" rather than "single Postgres." Numbers drive architecture.
- *This is **how the framework saves you*** — even if you've never thought about URL shortening, the 6 steps give you a path. Don't deviate.

**After-action prompt:** *"You ran the framework on a familiar problem. Where did you slow down? That's the weakest step. Drill that step before drill #2."*

### Phase 3 — Drill #2: Design Twitter feed (~25 min, timed) (~25 min)

**Goal:** Harder problem. The big trade-off: fan-out-on-read vs fan-out-on-write.

**Set a 25-minute timer.**

**Step 1 — Requirements (5 min):**

- **Functional:** Users post tweets. Users follow other users. Users see a feed of tweets from people they follow.
- **Non-functional:** 300M monthly active users. 200M tweets/day = ~2,300/sec write. Feed reads ~10B/day = ~115K/sec read. Latency < 200ms for feed load. Eventual consistency OK.
- **Scope:** Just the home feed. No DMs, no retweets, no media (for the interview).

**Step 2 — API:**

```
POST /tweets        body: { text } → 201 { tweet_id }
GET  /feed          → list of recent tweets from followed users
POST /follow/{user_id}
DELETE /follow/{user_id}
```

**Step 3 — Data model:**

```
USER (id, username, ...)
TWEET (id, user_id, text, created_at)
FOLLOW (follower_id, followee_id, since)
```

**Step 4 — High-level design:**

```
[Client] → [LB] → [API Servers]
                       │
                       ├──► [TWEET DB] (sharded by user_id)
                       ├──► [USER DB]
                       └──► [FOLLOW DB]

  [Feed Service] ◄── reads from TIMELINE CACHE (Redis) ── pre-computed per user
  [Fan-Out Workers] ◄── consume TweetPosted events ── push tweet to followers' timeline cache
```

**Step 5 — Deep dive (15 min) — the BIG question: fan-out-on-write vs fan-out-on-read.**

**Approach A: Fan-out-on-write (push)**
- When user tweets, push the tweet ID into the timeline cache of every follower.
- Reads are cheap (just `LRANGE` from Redis).
- Writes are expensive — celebrity with 50M followers = 50M cache writes per tweet.
- Storage: each user has a timeline cache (~ 1KB × users × cache_depth).

**Approach B: Fan-out-on-read (pull)**
- When user loads feed, query "tweets from people I follow, sorted by time, limit 100."
- Writes are cheap (just store the tweet).
- Reads are expensive — for a user following 1000 people, that's a 1000-way merge.
- No celebrity problem on write.

**Approach C: Hybrid (the real answer)**
- Push for most users (cheap writes, cheap reads).
- Pull for celebrities (avoid the 50M-write storm).
- At read time, merge pre-pushed timeline with celebrity-pulled tweets.

**Trade-offs to articulate:**
- "Pure push doesn't scale for celebrities. Pure pull doesn't meet read latency. Hybrid is the answer most production systems converge on."
- "What's the threshold for 'celebrity'? Some teams use follower count (>10K?), some use cost-model. It's tuned operationally."

**Step 6 — Trade-offs + wrap-up:**

- "Eventually consistent — users might see a tweet 30 seconds late. Acceptable for social feeds, not for banking."
- "Hot-spotting on celebrities — special handling needed."
- "Search isn't covered; would need Elasticsearch or similar."

**Concepts to name out loud:**
- *This is **fan-out as the canonical social-graph trade-off*** — every social product (Twitter, Instagram, Facebook) faces this. Knowing the three options is mandatory.
- *This is **the celebrity problem*** — power-law distributions break naive designs. Always ask: "what does the long tail look like? what does the head look like?"

**After-action prompt:** *"You ran the framework on a harder problem. Did you hit time pressure in step 5 (deep dive)? That's the most-time-consuming step; budget for it in real interviews."*

### Phase 4 — Drill #3: Design a chat app (~20 min, timed)

**Goal:** Different problem class (real-time push instead of batch reads). Same framework.

**Set a 20-minute timer.**

**Step 1 — Requirements (3 min):**

- **Functional:** 1:1 and group chat. Real-time delivery. Read receipts (skip if time short).
- **Non-functional:** 100M users, 50M concurrent. Messages should arrive within 1 second. Persist messages for history.
- **Scope:** Text only. No voice/video. No file attachments.

**Step 2 — API (2 min):**

- WebSocket connection: client opens persistent connection to chat server.
- Messages over WebSocket: `{ type: 'message', to: user_id_or_group, text: string }`.
- REST for history: `GET /conversations/{id}/messages?before=...`.

**Step 3 — Data model (2 min):**

```
USER (id, ...)
CONVERSATION (id, type: 'direct'|'group')
PARTICIPANT (conversation_id, user_id)
MESSAGE (id, conversation_id, sender_id, text, sent_at)
```

**Step 4 — High-level design (8 min):**

```
[Client] ─WebSocket─► [Chat Server Pool] ─► [Message Queue (Kafka)] ─► [Message DB]
                              │
                              └─► [Presence Service] (who's online)
                              │
                              └─► [Notification Service] (push for offline users)
```

**Key design decisions:**
- **WebSocket vs long-poll vs SSE:** WebSocket for bi-directional real-time.
- **Routing:** which chat server holds the user's connection? Consistent hashing on user_id, with a "user → server" registry (Redis or ZooKeeper).
- **Delivery to recipient:** sender's chat server enqueues message; recipient's chat server picks it up and pushes via WebSocket. If recipient is offline, queue for later + send push notification.

**Step 5 — Deep dive (3 min): How do we know if a message was delivered?**
- Recipient's client ACKs the message back over its WebSocket.
- ACK propagates back to sender → "delivered" indicator turns blue.
- If no ACK in N seconds → mark "pending."
- If recipient is offline → message is in the DB; will deliver when they reconnect.

**Step 6 — Trade-offs (2 min):**
- "WebSocket connections are sticky — load balancers need to handle long-lived connections. Use a TCP load balancer (L4) not HTTP (L7)."
- "Scaling chat servers: each holds N connections. Horizontal scale = more servers + routing."
- "End-to-end encryption is a whole separate design (Signal protocol). Out of scope for this conversation."

**Concepts to name out loud:**
- *This is **WebSocket as the right primitive for real-time*** — bi-directional, persistent, low-overhead per message. Long-poll is the fallback for environments that can't do WebSocket.
- *This is **the offline-user problem*** — real-time systems must gracefully degrade to async (notifications, message queue). Without this, offline users miss messages.

**After-action prompt:** *"You ran the framework on a 3rd problem class. Notice: the framework didn't change. The CONTENT changed. That's the win — the framework transfers."*

### Phase 5 — Self-score + recovery patterns (~10 min)

**Goal:** Self-assess against a rubric. Internalize how to recover from getting stuck.

**5-point rubric (score each interview drill 1-5):**

| Dimension | 1 (poor) | 3 (ok) | 5 (strong) |
|---|---|---|---|
| **Clarifying questions** | Jumped to design without asking | Asked 1-2 questions | Asked functional + non-functional + scope, got scale numbers |
| **API + data model** | Skipped or hand-waved | Sketched both, mostly correct | Specific endpoints, explicit primary keys, cardinality clear |
| **Architecture** | Vague boxes, no labels | Components + arrows | Clear shapes, labeled arrows, sync vs async distinguished |
| **Trade-offs articulated** | "I'd use X" with no reasoning | Mentioned 1 alternative | Discussed 2-3 alternatives with explicit pros/cons |
| **Communication / narration** | Silent while drawing, mumbled | Talked through some moves | Continuous narration, signposted each step, paused for interviewer input |

**Score your 3 drills. Identify the weakest dimension.**

**Recovery patterns — when you get stuck:**

1. **"Let me state the trade-off."** Even if you don't know the right answer, naming the trade-off (consistency vs availability, push vs pull, sync vs async) shows judgment.
2. **"What I'd want to know more about is..."** Names a gap honestly — better than bluffing.
3. **"I'll come back to that — let me finish this section first."** Gives you time. Don't get derailed.
4. **"Can I sketch and explain at the same time?"** Resets the tempo — gets you drawing again.
5. **"I don't know X, but I'd approach it by..."** Honest > bluffed. Interviewers can smell a bluff.

**Concepts to name out loud:**
- *This is **interviews as performance + content*** — content gets you to 60%. Communication + framework get you to 90%.
- *This is **why the rubric beats vibes*** — "I think it went well" is unactionable. "Communication was a 2 because I went silent for 5 minutes" is fixable.

**After-action prompt:** *"You self-scored 3 interviews. Your weakest dimension is your homework. Drill that dimension for 30 min/week until it's a 4+."*

## When to break the method

- Learner has interviewed before → skip Phase 1 framework explanation, go straight to Phase 2 drills.
- Learner is going for FAANG-style 60-minute interviews → add a 4th drill (design Uber, design Dropbox) and emphasize Phase 5 deep dive.
- Learner is going for IC roles (not senior) → spend more time on Phase 2 (URL shortener); deep architecture in step 5 is less critical at IC level.

## Definition of done

Observable, the learner can:

- [ ] Recite the 6-step framework with time-boxes.
- [ ] Run the framework on a brand-new problem (interviewer-supplied) in 25 minutes.
- [ ] Ask functional + non-functional clarifying questions in the first 5 minutes.
- [ ] Estimate QPS, storage, and bandwidth using back-of-envelope math.
- [ ] Articulate at least 2 trade-offs per design (with pros/cons each).
- [ ] Self-score against the 5-point rubric and name the weakest dimension.

## Next project

→ [`wbd-capstone-present-a-system`](../wbd-capstone-present-a-system/SKILL.md) — capstone. Pick a real system you've built or used, draw all 4 diagram types for it, present it live to another human, take their feedback, redraw. The whiteboarding skill graduates from drills into real communication.
