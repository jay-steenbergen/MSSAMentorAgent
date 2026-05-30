---
name: ghc-custom-agents
description: |
  GitHub Copilot track project #8. Learner builds a focused custom agent
  (`api-design-reviewer.agent.md`) with persona, anti-patterns, and a test session.
  Learns why the `tools:` field is RESTRICTIVE not declarative (default = omit, full
  toolset inherited), and tests the agent in a fresh chat to verify discoverability +
  behavior. Auto-load when the learner is in `github-copilot/ghc-custom-agents` or asks
  how to write a `.agent.md`, build a custom Copilot agent, scope agent tools, or test
  agent personas.
---

# Project: `ghc-custom-agents`

> **Track:** GitHub Copilot · **Project:** 8 of 9 · **Time:** ~90 minutes
>
> Custom agents are the heaviest customization Copilot offers — and the easiest to get wrong. The biggest landmine is the `tools:` field: most engineers think it ADDS tools and end up restricting their agent to 3 tools when they wanted 30. By the end of this project the learner has built a focused `api-design-reviewer` agent, tested it in a fresh chat, verified it has the tools it needs, and codified the "default omit `tools:`" rule.

## Project goal

When this project is done, the learner can:

- Create a `.github/agents/<name>.agent.md` with YAML frontmatter (`name`, `description`) and a behavioral persona in the body.
- Decide whether the agent needs `tools:` restriction (security/scope reason) or should inherit the full default toolset (no `tools:` field).
- Write a `description:` that is **discoverability metadata** — Copilot picks the agent when the description matches the task. Bad descriptions = invisible agents.
- Test the agent in a **fresh chat session** to verify it appears in the picker AND has the tools it claims to need.
- Iterate the persona based on test session output, naming anti-patterns explicitly.

## Scope guardrail

This is **one agent built, one fresh-session test, one anti-pattern doc**. We are not building MCP-backed agents (project #9), not publishing agents (not a feature yet), not building agent fleets. The point: own the `.agent.md` primitive and avoid the `tools:` trap.

If the learner asks "why use an agent over a prompt file?" — answer honestly: *agents are right when you need a persistent persona over many turns ("be an API design reviewer for this whole conversation"). Prompt files are right when you want one specific transformation*.

## Prerequisites

| Prereq | Verify with |
|---|---|
| Completed [`ghc-prompt-files`](../ghc-prompt-files/SKILL.md) — understands YAML frontmatter, knows when to choose which surface | Can write a working prompt file |
| Familiarity with this MSSA repo's pattern: [`.github/agents/Mentor.agent.md`](../../../../../agents/Mentor.agent.md) is a working example | Has read it once |
| A throwaway repo with a small API codebase (use the C# API from project #6 or a Python equivalent) | Can run the API |

## Phases

### Phase 1 — Pick a focused role (~10 min)

**Goal:** One sentence: "this agent does X for Y."

**Bad agent ideas** (too broad — they overlap with default Copilot):

- "Senior engineer agent" — what's the actual job?
- "Code helper" — that's just Copilot.
- "DevOps agent" — too many domains.

**Good agent ideas** (focused — they specialize):

- "API design reviewer — critiques REST API endpoints for naming, status codes, idempotency, and resource modeling."
- "SQL query optimizer — explains query plans and suggests indexes/rewrites for given queries against the inventory DB."
- "Test failure triager — given a pytest failure, classifies as flaky / env / real bug / config and proposes a next action."

**For this project, build "API design reviewer."** Write the one-sentence value prop on paper: *"Reviews REST API endpoint designs against industry conventions (REST maturity model, HTTP semantics, OpenAPI standards) and surfaces issues humans tend to miss on first review."*

**Concepts to name out loud:**
- *This is **focus as the agent's edge*** — broad agents lose to default Copilot. The agent earns its keep when it's narrow enough to develop a perspective.
- *This is **why "agent for everything" doesn't work*** — Copilot's discoverability picks the most-specific match. A generic agent never wins the picker against a focused one.

**After-action prompt:** *"You picked one focus. Write the value prop in one sentence. If you can't, the focus isn't tight enough."*

### Phase 2 — Write the agent file (~20 min)

**Goal:** `.github/agents/api-design-reviewer.agent.md` exists with proper frontmatter and a behavioral persona.

**Create `.github/agents/api-design-reviewer.agent.md`:**

```markdown
---
name: api-design-reviewer
description: |
  Reviews REST API endpoint designs for naming, HTTP method choice, status codes,
  idempotency, pagination, error responses, and resource modeling. Invoke when
  designing a new endpoint, reviewing a PR that adds/changes API surface, or
  evaluating an existing API for drift from REST conventions. Cites specific
  rules (Roy Fielding's REST constraints, RFC 7231 HTTP semantics, JSON:API
  spec) when it pushes back.
---

# API Design Reviewer

You are an API design reviewer. Your job is to look at REST API endpoints
(proposed or existing) and surface design issues using concrete, citable
standards.

## What you do

When the user shows you an endpoint (controller code, OpenAPI spec, or just a
description), review against this checklist in order:

1. **Resource modeling** — is the URL a noun? Plural? Hierarchical where it should be?
2. **HTTP method semantics** — GET (safe, idempotent), POST (create), PUT (full replace, idempotent), PATCH (partial update), DELETE (idempotent). Flag misuse.
3. **Status codes** — 200 vs 201 vs 204, 400 vs 422, 401 vs 403, 404 vs 410. Cite RFC 7231.
4. **Idempotency** — can the client safely retry on network failure? POST endpoints that aren't idempotent need an idempotency key.
5. **Pagination** — list endpoints need cursor or page+size + total. Flag missing.
6. **Error responses** — consistent envelope? Cites the error code? Helpful to a debugging client?
7. **Versioning** — URL path version, header, or none? Flag breaking changes without version bump.
8. **Naming** — snake_case in JSON? camelCase? consistent across the codebase?

For each issue you raise, structure as:

```
[Severity: Critical | Important | Suggestion]
Issue: <one sentence>
Why: <reference to standard / RFC / convention>
Fix: <concrete suggestion>
```

## What you do NOT do

- You do not write the implementation. You review the design. If the user
  asks for implementation, redirect: "I'm here for design review. For the
  implementation, switch to the default Copilot agent."
- You do not propose new endpoints unprompted. You only review what's asked.
- You do not nitpick style (variable names, formatting) — that's a code reviewer's job.
- You do not block on missing tests — that's a test review.

## When to push back

- User insists on using POST for a read operation → push back with "GET is safe and cacheable; POST loses CDN caching and breaks safe-retry."
- User wants 200 for a created resource → push back with "201 + Location header is the standard for resource creation per RFC 7231."
- User omits pagination on a list endpoint → push back with "this will paginate itself in production when the dataset grows. Add it now."

Always cite the source. "Because I said so" is not an answer. The source is the lever.

## Anti-patterns (do not let yourself do these)

- Generic feedback ("consider clearer naming") without a concrete suggestion
- Listing all 8 checklist items even when only 2 apply
- Reviewing implementation code instead of API surface
- Being aggressive — design discussions are collaborative, not adversarial
```

**Note: no `tools:` field.** This is on purpose. See phase 3.

**Save. Commit.**

**Concepts to name out loud:**
- *This is **the `description` as discoverability metadata*** — VS Code uses it to decide when to surface the agent in the picker. "Reviews REST API endpoint designs..." matches user queries like "review my API design" or "is this endpoint good?" — automatic discovery.
- *This is **the behavioral persona*** — not "you are an expert in APIs" (vibes), but "review against this 8-point checklist" (behavior). Behavior is testable; vibes are not.
- *This is **the "what you do NOT do" section*** — most agent failures are scope creep. Explicit scope guardrails inside the persona file keep the agent honest.

**Common gotchas:**
- Description too vague → agent never shows up in picker. Make it specific and use keywords the user would type.
- Description too long → VS Code may truncate. Aim for 3-4 sentences max.
- Forgetting `name:` → file invalid. Required field.

**After-action prompt:** *"You wrote the persona. Read it as if you'd never seen this agent before. Could a stranger predict what it will and won't do? If not, the persona needs more behavior, fewer vibes."*

### Phase 3 — The `tools:` field trap (~20 min)

**Goal:** Understand why omitting `tools:` is the default, and only restrict when you have a real reason.

**Read this carefully:**

> The `tools:` field on a custom agent is **restrictive, not declarative**. When you include it, you tell VS Code "the agent gets ONLY these tools." When you omit it, the agent inherits the full default Copilot toolset.

**The trap:** engineers think `tools:` lets them ADD tools or DECLARE which they need. It does neither. It RESTRICTS.

**Concrete failure mode:** You add `tools: ['mcp_github_*', 'read_file']` thinking you're being explicit. Now your agent CANNOT use `grep_search`, `semantic_search`, `replace_string_in_file`, etc. The agent silently has fewer capabilities than the default Copilot — and worse, you don't notice because no error fires.

**The Kimberly rule (verbatim from this repo's instructions):**

> Default to omitting the `tools:` field entirely so the agent inherits the full default Copilot toolset, exactly like the main chat session. ONLY add `tools:` when you have a specific security or scope reason to drop capability (read-only audit agent, planning-only agent, destructive-only agent). WHEN you do restrict, use VS Code's tool-registry / tool-set names — not the API names from chat output — and invoke the agent in a fresh session to verify each listed tool actually surfaces.

**Decide for the API design reviewer agent:** does it need a `tools:` restriction?

- The agent reads files (controller code, OpenAPI specs) → needs `read_file`.
- The agent searches the codebase to find related endpoints → needs `grep_search` and `semantic_search`.
- The agent does NOT write code (per persona) → could restrict writes.
- The agent does NOT run code → could restrict terminal.

**Should you add `tools:` to restrict writes/terminal?**

The honest answer: **no, not for this agent.** Here's why:

1. The persona says "do not write the implementation." Persona steers behavior. Tool restriction is belt-and-suspenders for an agent that doesn't have a security concern.
2. Restricting tools means future flexibility is gone. If someday you want the agent to write a single line of feedback into a comment in the source file, you'll have to update tools.
3. The downside of NOT restricting is zero — the agent won't write code because the persona says not to, and you can correct it if it tries.

**The rule of thumb:** restrict `tools:` ONLY if (a) it's a read-only audit/review agent operating on sensitive data, (b) you're building a planning-only agent that must never execute, or (c) you're building a destructive-only agent (DB purge, force-push) where you want to limit what else it can do for safety.

For everything else: **omit `tools:`.**

**Concepts to name out loud:**
- *This is **restrictive not declarative*** — the most-named landmine in custom-agent design.
- *This is **why "more is more" doesn't work*** — listing every tool you can think of makes the agent EITHER (a) fail because VS Code doesn't recognize the name OR (b) silently work fine and you waste the effort. Default omit avoids both.
- *This is **VS Code's tool registry vs API names*** — if you DO restrict, the names in `tools:` must match VS Code's internal tool-set names, NOT the API names you see in chat output. Use the picker's tool list as the source of truth.

**After-action prompt:** *"You decided not to restrict tools. Walk through 3 hypothetical agents and decide for each whether to restrict: (1) a database migration agent that runs DDL, (2) a code archaeology agent that only reads, (3) a deployment agent that can `git push --force`."*

### Phase 4 — Test in a fresh session (~20 min)

**Goal:** Open a new chat, verify the agent appears in the picker, verify it behaves as the persona says, verify the tools it needs actually surface.

**Steps:**
1. Open a **new VS Code Chat session** (`Ctrl+L` or click the new-chat icon in the chat panel).
2. Click the agent picker. The `api-design-reviewer` should appear in the list.
   - If it doesn't → restart VS Code, check the file path is `.github/agents/`, check frontmatter is valid YAML.
3. Select the agent.
4. **Test 1 — confirms behavior:** paste an endpoint:
   ```
   POST /api/getUser
   Body: { "userId": 123 }
   Returns: 200 with { "user": {...} }
   ```
   Expected output: the agent should flag (a) POST for a read operation, (b) URL contains verb "getUser" not noun, (c) 200 for read is fine but the whole endpoint is misdesigned. Should cite RFC / REST principles. Should NOT propose an implementation.
5. **Test 2 — confirms scope guardrail:** ask: "Now write the C# controller for the corrected endpoint."
   Expected: agent declines, redirects to default Copilot per the "do NOT" section.
6. **Test 3 — confirms tool inheritance:** ask: "Find any other endpoints in this repo that use POST for a read operation."
   Expected: agent uses `grep_search` (or similar) to look. If it can't, the `tools:` decision was wrong.

**Document what you found** in a notes file `agent-test-log.md`:
```markdown
# api-design-reviewer test session

## Discoverability
- Appeared in picker: ✅
- Selected via name: ✅

## Test 1 — endpoint review
- Flagged POST-for-read: ✅
- Flagged verb-in-URL: ✅
- Cited RFC/REST: ✅
- Did NOT propose implementation: ✅

## Test 2 — scope guardrail
- Declined implementation request: ✅
- Redirected to default agent: ✅

## Test 3 — tool surface
- Used grep_search successfully: ✅
- Found 0 matches in this repo (expected — repo has no controllers with that pattern)
```

**Concepts to name out loud:**
- *This is **the fresh-session test*** — your current chat has context, history, momentum. None of that exists for the next user. Test the agent the way a stranger would meet it.
- *This is **what "verify tools surface" means*** — actually try to use the tool. If the agent tries `grep_search` and you see a successful grep result, the tool is there. If the agent says "I can't search the codebase," the tool isn't there — fix it.
- *This is **the test log as documentation*** — the test log proves the agent works AND captures the test cases for next time you change the persona.

**Common gotchas:**
- Agent appears in picker but selecting it does nothing → check frontmatter is valid YAML (use a YAML linter).
- Agent behaves identically to default Copilot → persona too vague. Add more behavioral rules.
- Agent uses tools but very poorly → that's a model issue, not a config issue. Re-prompt with more context in the persona.

**After-action prompt:** *"You tested the agent. Did anything surprise you? If something is off, what's the smallest change you'd make to fix it?"*

### Phase 5 — Iterate the persona from real use (~20 min)

**Goal:** Based on the test session, refine the persona file.

**Common refinements after first test:**

- Agent was too verbose → add to persona: "Keep each issue's `Why` to one sentence. Bullet points beat paragraphs."
- Agent missed an obvious issue → add it to the checklist explicitly (the agent works from the checklist, not implicit knowledge).
- Agent was too aggressive → add to "When to push back": "Frame as 'here's the standard / here's what your code does / here's the gap.' Avoid 'you should' — say 'consider' or 'the convention is.'"
- Agent volunteered scope creep ("by the way, your tests are also missing...") → strengthen the "What you do NOT do" section.

**Make 1-2 real refinements based on YOUR test session.** Commit.

**Re-run the test session.** Verify the refinements improved behavior without breaking what worked.

**Repeat as needed.** Most agents need 3-5 iterations before they're solid.

**Concepts to name out loud:**
- *This is **personas as living code*** — the file is version-controlled. Every refinement is a commit. Over 6 months the agent gets better through use.
- *This is **why "anti-patterns" sections work*** — naming the failure mode in the persona prevents it. The agent reads its own anti-patterns and avoids them.
- *This is **how the Mentor.agent.md in this repo grew*** — same process. Test, find a failure mode, name it, add it to the anti-patterns list, retest.

**After-action prompt:** *"You iterated the persona twice. Which refinement had the most impact? What does that tell you about which kinds of persona rules matter most?"*

## When to break the method

- Learner is building an agent for a real production use case → use that agent, not the API reviewer. Real use yields better personas.
- Learner is brand-new to YAML and frontmatter → spend extra time on phase 2's validation step. A broken YAML file is invisible to VS Code.
- Time short → phases 2-3-4 are the must-do. Phase 5 (iteration) can be over the next week.

## Definition of done

Observable, the learner can:

- [ ] Show `.github/agents/api-design-reviewer.agent.md` with valid frontmatter and a behavioral persona.
- [ ] Confirm the agent appears in a fresh chat session's agent picker.
- [ ] Confirm the agent behaves per the persona on 3 test prompts.
- [ ] Articulate why `tools:` is RESTRICTIVE not declarative, and when to use it.
- [ ] Show an updated persona file with 1-2 refinements based on real test session output.
- [ ] Explain in one sentence each: agent vs prompt file vs instruction, description as discoverability metadata, the fresh-session test.

## Next project

→ [`ghc-mcp-tools-integration`](../ghc-mcp-tools-integration/SKILL.md) — capstone. Connect the GitHub MCP server to VS Code, use it from Chat to do real cross-repo work, and learn the security boundary (MCP servers run with YOUR credentials).
