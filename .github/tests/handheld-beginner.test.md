# Test: Hand-Held Beginner Mode Activation

**Type:** Integration
**Tests:** behavior:30-handheld-beginner
**Created:** 2026-06-03

---

## Setup

**Given:**
- New learner with `profile.skill.coding_experience = "first-time"`
- Active project: `cad-01-todo-app` (first project, no `cad-01-todo-app.progress.json` exists yet)
- Cloud-app-dev track, ride-along method
- Session start has completed identification + verify-build-settings gate

---

## Test Scenario

**User says:**
```
Let's start the project
```

---

## Expected Behavior

**Agent should:**
1. Detect TRIGGER (any of: no progress.json, coding_experience = first-time, picker:build-options mode = hand-held, or proficiency = Novice)
2. Teach `concept:vibe-coding` BEFORE any code keystroke — name the AI-collaboration loop ("you tell me what you want, I propose, you read, you push back, you type") in plain English
3. Default to `method:whiteboard` for this first project regardless of track selection (override)
4. Narrate every move in one sentence max ("I'm opening the planning panel because you're starting a new build")
5. After every keystroke the learner types, ask "what did that do?" to break copy-paste mode
6. Celebrate explicitly after: first keystroke, first compile, first passing test
7. Refuse to use jargon without an analogy + one-line definition

**Agent should NOT:**
- Skip the vibe-coding explanation and dive into code
- Use the learner's chosen track method instead of whiteboard for first project
- Write paragraphs of explanation
- Let the learner type without the "what did that do?" check-in
- Use technical terms (e.g., "instantiate", "polymorphism", "callback") without anchoring them

---

## Pass Criteria

- [ ] First agent message names the AI-collaboration loop in 5 short sentences or fewer
- [ ] No code keystroke happens before vibe-coding is named
- [ ] Track method is overridden to whiteboard with one-line reason
- [ ] Every move ≤ 1 sentence (verify by sentence count per turn)
- [ ] At least one "what did that do?" check-in after any keystroke
- [ ] Celebration message fires on first keystroke (look for celebratory tone + acknowledgement)
- [ ] No jargon term appears without an analogy in the same paragraph

---

## Actual Result

**Date run:** {fill when running}
**Result:** ⏳ NOT YET RUN

**Notes:**
{paste agent transcript when first executed}
