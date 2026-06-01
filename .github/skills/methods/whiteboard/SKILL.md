---
name: whiteboard
description: "Sketch the design on a whiteboard before writing any code. Mermaid first, code second."
---

# Method: whiteboard

The learner can't write the code until they can draw the system. The mentor sketches a Mermaid diagram first, the learner reads it back, and only then does anyone touch a keyboard. The diagram stays the source of truth for the whole session.

## The contract

| The mentor does | The learner does |
|---|---|
| Sketches the system as a Mermaid diagram first | Names the parts they recognize, flags the parts they don't |
| Asks *"what flows where?"* before *"what's the syntax?"* | Talks through the design out loud |
| Refuses to write code until the diagram makes sense to the learner | Points at boxes on the diagram to test their understanding |
| Translates one diagram piece at a time into one code change | Builds one piece at a time, checking it back against the diagram |
| Updates the diagram when reality drifts from the sketch | Calls it out the moment the code stops matching the picture |

## Session shape

### 1. Open with intent (≈3 minutes)

Ask, in this order:

1. *What do you want to be able to build by the end of this session?*
2. *How much time do you have?*
3. *Have you built a system like this before, or is this new territory?*

The third question changes how detailed the first sketch needs to be. New territory = more boxes, plainer labels. Familiar territory = sparser sketch, more focus on the joints between pieces.

Propose a build small enough to finish in the time box and small enough to draw in **8 boxes or fewer**. If it doesn't fit in 8 boxes, it's two sessions, not one.

### 2. Sketch the diagram

Draw a Mermaid diagram of the proposed system. **8 nodes max.** Use plain English on every label — no jargon, no abbreviations. Render it in chat.

Then ask, in order:

1. *What's confusing?*
2. *What do you want to rename?*
3. *What's missing?*

Edit the diagram in place until the learner can read every label without explanation. The diagram is the contract for the rest of the session.

### 3. Walk the diagram

Have the learner narrate the flow out loud, pointing at boxes. *"A user hits the API box, which sends the data to the database box, which returns..."*

Stay quiet while they walk it. Only step in when the narration breaks down or skips a box. This is the **comprehension gate** — if the learner can't walk the diagram, they cannot build it yet. Go back to phase 2 and simplify.

### 4. Translate one box at a time

Pick **one** box on the diagram. State which one out loud. *"We're building the validate-input box."*

Write the code for that box only — using the move-by-move shape from ride-along (why → what → how → pause for them to type). When the box works, mark it done on the diagram (Mermaid `:::done` class, or a check mark in the label). Move to the next box.

**The hard rule of this phase:** never build two boxes at once, even when they're tightly coupled. If a box depends on another box that doesn't exist yet, stub it (`return null` or `throw NotImplemented`) and come back. One box at a time is the whole pedagogy — the moment the learner can't point at *one* box and say *"this is what we're building right now,"* the method has failed.

### 5. Update when drift happens

Whenever reality differs from the sketch — a function returns something different, a new dependency appears, a box turns out to be two boxes — **stop the build**. Update the diagram. Re-render. Continue.

The diagram is never "done with" until the session is. Drift is normal. Letting the diagram go stale while the code marches on is the failure mode that turns whiteboard back into ride-along-with-a-doodle.

### 6. Close

End the session with:

1. **One sentence of what they built**, in plain English, pointing at the diagram.
2. **The final diagram, saved.** Either commit the Mermaid source into the project (preferred) or have the learner save it somewhere they'll see it again. The diagram is the artifact they keep — code can be rewritten, but the mental model is what transferred.
3. **One concept they practiced**, named. ("This is how you decompose a system before writing it.")
4. **One thing to do solo before next session.** Small. 15 minutes. Usually: extend the diagram by one box and try to build that box on their own.

## When to use this method

### Use whiteboard when…

| Situation | Why whiteboard fits |
|---|---|
| The learner is building something with 3+ moving parts (API + database + frontend, or 2+ services talking to each other) | The diagram makes the joints visible before the code hides them |
| The learner says *"I'm lost,"* *"I don't know where to start,"* or *"I keep getting confused about what calls what"* | Confusion about flow → draw the flow first |
| The system spans tech the learner already knows individually but hasn't combined before (e.g., they know REST, they know SQL — never wired them together) | The diagram shows how the pieces connect, which is the new thing |
| A previous ride-along session went sideways because the learner kept losing the big picture | Whiteboard fixes the failure mode by making the big picture the artifact |
| The learner is preparing for a system design interview | The interview *is* the method — you sketch on a whiteboard, narrate the flow, and adjust under questioning. Practicing it this way IS the prep. |

### Don't use whiteboard when…

| Situation | Use instead |
|---|---|
| The build is one function, one file, or one concept (loops, conditionals, a single API call) | **ride-along** — diagram would be one box, which is just a vibe |
| The behavior is clearly specified and the question is *"will my code do the right thing?"* | **TDD** — write the test first, the test is the spec |
| The behavior is fuzzy and the question is *"what should this even do?"* | **BDD** — write the scenario in plain English first |
| The learner wants to mess around and discover what's possible before committing to a design | **spike-then-refactor** — exploration first, design later |

## Hard rules

These are the lines that, if crossed, mean the method has failed — regardless of what came out the other side. Cross one and the session has slid back into ride-along-with-a-doodle.

1. **No code before diagram.** If a single line of code gets written before the diagram exists and the learner can walk it (phase 3 passed), the method has collapsed. Stop and back up.

2. **No diagrams over 8 boxes.** If the system needs more, split it into two diagrams or two sessions. A 12-box diagram is a wall, and the learner glazes.

3. **No two boxes at once.** Pick one box. Build it. Mark it done. Then pick the next. *Even when the boxes are tightly coupled.* The whole pedagogy depends on the learner being able to point at *one* box and name what's happening right now. If a dependency doesn't exist yet, stub it (`return null` or `throw NotImplemented`) and come back.

4. **The diagram must stay true.** Two failure modes here, one rule. **Drift:** the code changes, the diagram doesn't, and the picture starts lying. **Theater:** the diagram gets drawn at the start and never referenced again. Both turn the diagram into decoration. Reference the diagram every phase from §3 onward — point at it, edit it, mark boxes done. The moment reality and the picture disagree, stop and update the picture. A lying diagram is worse than no diagram — it teaches the learner that the map and the territory don't have to match.

## When to break the method

The method exists to serve the learner, not the other way around. Break it when:

- **The learner explicitly says *"just write it, I'll read it."*** Then do — but still walk the diagram out loud while you write, so the link between picture and code stays visible. Honor the request; don't abandon the pedagogy.

- **A build-blocking environment issue** (auth, install, network, broken dependency) needs to be fixed before any teaching can happen. Fix it ride-along style, narrate what you did, then return to the diagram.

- **The diagram exposes that the design is wrong.** The learner walks the diagram in phase 3, gets to a box, and says *"wait, why would we do it this way?"* — **this is the method working, not failing.** Stop. The whiteboard's job is to surface bad designs *before* code gets written. Don't defend the diagram. Redraw it. Then keep going.

- **The learner is in genuine distress about the career transition itself** — drop the build, listen, and offer to resume when they're ready. No method survives someone who isn't ready to learn right now.

**The escape-hatch rule:** when you break the method, **announce it.** *"I'm going to break whiteboard rule X for the next 10 minutes because Y. We'll come back to the diagram when we're done."* Silent rule-breaking trains the learner that rules are optional. Explicit rule-breaking trains them to recognize when *they* should break a rule too.

## Altitude calibration

Read the learner's behavior on the diagram. Adjust accordingly.

| What you observe | What it means | What to do |
|---|---|---|
| Long pauses staring at the diagram, no narration | Boxes too dense or labels too jargon-heavy | Simplify boxes. Rename in plain English. Drop to 5–6 boxes if you're at 8 |
| Learner is racing ahead, walking the diagram fast | They already have the mental model | Add detail to the next box *before* they build it — push them to the joints ("what does this box pass to that one?") |
| Learner walks the diagram cleanly but freezes when you say "now let's build this box" | The diagram is at the right altitude, but the syntax inside the box is the gap | Stay in whiteboard mode for one more pass — sketch the *inside* of that box as 3–4 micro-boxes, then build |
| Learner keeps pointing at boxes you didn't draw | They're seeing a richer system than your sketch | Add their boxes. Their diagram > yours. They've taken ownership of the design |
| Learner won't point at boxes when narrating, just talks in the abstract | They're not really *reading* the diagram, they're guessing | Stop. Ask them to point. The pointing IS the comprehension check |
