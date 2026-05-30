---
name: ghc-code-review-with-copilot
description: |
  GitHub Copilot track project #5. Learner runs Copilot code review on a deliberately-flawed
  diff (security, perf, naming, dead code, missing test), scores each finding as
  true-positive / false-positive / missed, and builds a scorecard showing where AI review
  wins (style, docstring gaps, obvious dead code) and where it loses (business logic,
  architecture fit, novel security). Auto-load when the learner is in
  `github-copilot/ghc-code-review-with-copilot` or asks how to review PRs with Copilot,
  use Copilot for code review, evaluate AI review output, or compare AI review vs human.
---

# Project: `ghc-code-review-with-copilot`

> **Track:** GitHub Copilot · **Project:** 5 of 9 · **Time:** ~75 minutes
>
> Copilot can review code. So can a smart 15-year-old who reads Stack Overflow. The interesting question isn't "can it?" — it's "what does it catch and what does it miss?" By the end of this project the learner has run Copilot on a flawed diff, tallied findings against a known answer key, and walked away with a calibrated sense of when to trust the review and when to ignore it.

## Project goal

When this project is done, the learner can:

- Run Copilot review on a code diff using `/review` (in Chat) or the **Copilot code review** feature in pull requests on github.com.
- Classify each finding as **true positive** (real issue), **false positive** (noise), or **nitpick** (technically correct, not worth fixing).
- Identify the **missed** issues — real problems Copilot didn't surface.
- Compute a small **scorecard**: precision, recall, signal density.
- Articulate where AI review reliably beats human review (style, docstrings, dead code) and where humans still win (architecture fit, business logic, novel security).

## Scope guardrail

This is **one flawed diff, one Copilot review, one scorecard**. We are not configuring Copilot review for an org (that's repo settings), not building custom review rules (that's project #6 territory). The point: build a calibrated mental model in 75 minutes.

If the learner asks "should we let Copilot block PRs that don't pass its review?" — answer honestly: *no — yet. Use it as a first-pass filter, not a gate. The false-positive rate is too high to gate merges*.

## Prerequisites

| Prereq | Verify with |
|---|---|
| Completed [`ghc-chat-driven-debugging`](../ghc-chat-driven-debugging/SKILL.md) — Chat panel comfortable | Can run a slash command |
| A throwaway GitHub repo where you can push a branch and open a PR | A public repo you own |
| GitHub Copilot subscription that includes code review (Individual / Business / Enterprise all include this as of 2026) | github.com/settings/copilot shows it enabled |

## Phases

### Phase 1 — Set up the flawed diff (~15 min)

**Goal:** A branch with a PR-sized diff containing 8 known issues.

**Create `user_service.py` on `main`:**
```python
"""User service stub."""

def get_user(id):
    return {"id": id, "name": "Alice"}
```

Commit, push to main. Now create a feature branch and add this NEW file `auth.py`:

```python
"""Authentication for the user service."""
import hashlib

# Module-level secret — copilot should flag this
SECRET = "supersecret123"


def hash_password(password):
    # Issue 1: MD5 is broken for passwords
    return hashlib.md5(password.encode()).hexdigest()


def check_password(stored, attempt):
    # Issue 2: string equality is timing-attack vulnerable
    return stored == hash_password(attempt)


def get_user_by_email(email, db):
    # Issue 3: SQL injection — string concatenation
    query = "SELECT * FROM users WHERE email = '" + email + "'"
    return db.execute(query)


def list_users(db, page=1, per_page=10):
    # Issue 4: no upper bound on per_page → user can request 10 million rows
    offset = (page - 1) * per_page
    return db.execute(f"SELECT * FROM users LIMIT {per_page} OFFSET {offset}")


def reset_password(user_id, new_password, db):
    # Issue 5: no authorization check — anyone can reset anyone's password
    hashed = hash_password(new_password)
    db.execute(f"UPDATE users SET password='{hashed}' WHERE id={user_id}")


def get_user_full(id, db):
    """Get user with all fields including PII."""
    # Issue 6: dead code below — unreachable
    user = db.execute(f"SELECT * FROM users WHERE id={id}").fetchone()
    return user
    db.commit()  # never runs


def encode_jwt(payload):
    # Issue 7: no signature — token is forgeable
    import json, base64
    return base64.b64encode(json.dumps(payload).encode()).decode()


# Issue 8: no docstring on a public function
def make_session(user):
    return {"user": user, "token": encode_jwt({"uid": user["id"]})}
```

**Answer key — 8 known issues (don't show this to the learner yet):**

| # | Issue | Severity | Hard for AI to spot? |
|---|---|---|---|
| 1 | MD5 for passwords | Critical | No — pattern-match |
| 2 | Timing-attack-vulnerable equality | High | Sometimes — context-sensitive |
| 3 | SQL injection via string concat | Critical | No — pattern-match |
| 4 | Unbounded `per_page` | Medium | Yes — needs to reason about caller behavior |
| 5 | Missing authorization check | Critical | Yes — business logic, needs context |
| 6 | Unreachable code after return | Low | No — easy to flag |
| 7 | Unsigned JWT | Critical | No — pattern-match |
| 8 | Missing docstring on public function | Low | No — easy to flag |

Commit, push the branch. Open a PR on github.com.

**After-action prompt:** *"The diff has 8 issues you planted. Before you ask Copilot, predict: how many will it find? Write the number down. We'll check at the end."*

### Phase 2 — Run Copilot review and collect findings (~15 min)

**Goal:** Copilot's review output is captured and tallied.

**Two ways to invoke:**

**Path A — In VS Code Chat:**
1. Check out the feature branch locally.
2. Open `auth.py`.
3. In Chat: `/review`
4. Wait for the response. Copy each finding into a notes file `review-scorecard.md`.

**Path B — On github.com (richer):**
1. Open the PR on github.com.
2. **Reviewers panel → request review from "Copilot"**.
3. Wait 30-60 seconds for Copilot's review to appear as comments on the diff.
4. Copy each finding into `review-scorecard.md`.

**Format your notes:**
```markdown
# Copilot review findings on PR #N (auth.py)

| # | Line | Copilot's finding | My classification |
|---|---|---|---|
| 1 | 8 | MD5 not safe for password hashing | TP |
| 2 | 14 | (whatever Copilot says) | ? |
| ... | ... | ... | ... |
```

Leave the "My classification" column empty for now.

**Concepts to name out loud:**
- *This is **two surfaces, same engine*** — `/review` in Chat and "Request review from Copilot" on github.com produce broadly the same kind of output. The PR surface is richer (inline comments) but slower to iterate.
- *This is **Copilot's review as a single shot*** — it doesn't iterate, doesn't read other files (much), doesn't have your team's coding standards (yet — project #6). What you see is its first attempt with default context.

**After-action prompt:** *"You captured the findings. How many did Copilot raise? Higher or lower than you predicted?"*

### Phase 3 — Classify each finding (~20 min)

**Goal:** Every finding has a label and a one-line rationale.

**Classifications:**

| Label | Definition |
|---|---|
| **TP** (True Positive) | Real issue. Worth fixing. |
| **FP** (False Positive) | Not actually a problem in this context. |
| **Nit** | Technically correct, not worth fixing now (style preference, micro-optimization). |
| **Useful but vague** | Identified a real area of concern but the description is hand-wavy. |

**Go finding-by-finding. For each:**
1. Re-read Copilot's text.
2. Decide if the issue is real, fake, or a nit.
3. Write one line of rationale.
4. Note the line number.

**Then build the "missed" list:**
- Cross-reference the 8 planted issues against the findings.
- For each planted issue Copilot did NOT raise, add a row to the table marked "MISSED."

**Expected result (depending on the day Copilot runs):**
- Issues 1, 3, 6, 7, 8 — almost always caught (pattern-match wins).
- Issue 2 (timing attack) — sometimes caught, sometimes missed.
- Issue 4 (unbounded per_page) — usually missed (needs reasoning about caller).
- Issue 5 (missing authz) — almost always missed (needs business context).
- Plus 1-3 findings that are FPs or nits (style, suggested type hints, "consider adding logging").

**Concepts to name out loud:**
- *This is **the precision-vs-recall trade-off*** — Copilot is high-precision on pattern-match issues (SQL injection, MD5 — when it flags them, they're real). Lower recall on contextual issues (missing authz — needs to know the business rules).
- *This is **why FP rate matters*** — a review tool with too many false positives gets ignored. Engineers stop reading the output. The signal-to-noise ratio is what determines adoption.

**After-action prompt:** *"You labeled every finding. Look at the MISSED list. What kind of issues are missing? Pattern-match issues, or context-requiring issues?"*

### Phase 4 — Compute the scorecard (~10 min)

**Goal:** Numbers, not vibes.

**Add a summary table to `review-scorecard.md`:**

```markdown
## Scorecard

| Metric | Value | Formula |
|---|---|---|
| Findings raised | <N> | count of Copilot's findings |
| True positives | <TP> | count classified as TP |
| False positives + nits | <FP + Nit> | count classified as FP or Nit |
| Planted issues caught | <X of 8> | of the 8 known issues, how many Copilot raised |
| Precision | <TP / (TP + FP)> | of what Copilot flagged, what fraction was real |
| Recall (vs planted) | <caught / 8> | of the planted bugs, what fraction Copilot found |
| Signal density | <TP / total findings> | TP rate including nits in denominator |
```

**Example outcome (your numbers will differ):**

| Metric | Value |
|---|---|
| Findings raised | 9 |
| True positives | 6 |
| False positives + nits | 3 |
| Planted issues caught | 5 of 8 |
| Precision | 67% |
| Recall (vs planted) | 63% |
| Signal density | 67% |

**Concepts to name out loud:**
- *This is **precision and recall as the two dimensions every review tool trades off*** — perfect recall (catches everything) usually means low precision (lots of noise). Perfect precision (zero false positives) usually means low recall (misses subtle issues).
- *This is **why you'd USE Copilot review in production*** — not because it's perfect. Because it's faster than a human at the boring 80% (style, dead code, common security patterns) and lets humans spend time on the hard 20% (architecture, business logic, novel attack surfaces).

**After-action prompt:** *"Your precision is X%, recall is Y%. If you had to defend using Copilot review to a skeptical senior engineer, what would you say? If they pushed back saying 'I'd rather just review it myself,' what would you say?"*

### Phase 5 — Where humans still win (~15 min)

**Goal:** Hand-write the review findings Copilot missed, especially the business-logic and architecture ones.

**Look at your MISSED list. Walk through each:**

- **Issue 4 (unbounded per_page):** would you catch this in a human review? Yes — by thinking "what does a malicious caller do?" Copilot needs explicit prompting to think adversarially.
- **Issue 5 (missing authz):** would you catch this? Yes — by asking "who is allowed to call this function?" Copilot doesn't know your auth model.

**Now: write 3 review comments YOU would post on this PR that Copilot didn't:**

```markdown
# Comment 1 — line N
This endpoint resets a password without checking that the caller is authorized
to reset that specific user's password. As written, anyone who can call this
function can reset anyone's password. Should fetch the current authenticated
user and verify `user_id == current_user.id` OR `current_user.is_admin`.

# Comment 2 — line N
`per_page` is unbounded. A caller can request 1,000,000 rows and DOS the DB.
Cap it at e.g. 100 server-side, ignore values above the cap.

# Comment 3 — (architecture, not line-specific)
This module mixes password hashing, SQL queries, and JWT encoding. Consider
splitting into auth/passwords.py, auth/sessions.py, auth/queries.py so each
concern can be tested and audited separately.
```

**Concepts to name out loud:**
- *This is **the human moat*** — architecture fit, business-rule violations, "who can do what to whom" reasoning. These need context Copilot doesn't have (yet — projects #6 and #8 narrow this gap).
- *This is **why "Copilot does code review" doesn't replace humans*** — it shifts the human's job. Humans stop catching missing docstrings. Humans now spend their review time on the architectural and security issues that matter most.

**After-action prompt:** *"You wrote 3 comments Copilot didn't. What's the common theme — what kind of thinking did each one require?"*

## When to break the method

- Learner is a working engineer who reviews PRs daily → spend more time on phase 5. Their intuition for "what humans catch" is already strong; this is about codifying it.
- Learner is brand new to code review → start with a smaller diff (3 issues, not 8). Walk slowly.
- Time short → phases 1-2-4 are the must-do. Phase 5 is depth.

## Definition of done

Observable, the learner can:

- [ ] Show `review-scorecard.md` with at least 6 findings classified.
- [ ] Show the MISSED list — at least 2 planted issues Copilot didn't catch.
- [ ] Compute precision and recall numbers from their own tally.
- [ ] Hand-write 3 review comments Copilot didn't surface.
- [ ] Explain in one sentence each: precision vs recall, false positive cost, where humans beat AI in review.

## Next project

→ [`ghc-custom-instructions`](../ghc-custom-instructions/SKILL.md) — flip from "use Copilot as-is" to "customize Copilot for your repo." Write `.github/copilot-instructions.md` for a small C# Web API and verify Copilot follows your team's conventions automatically.
