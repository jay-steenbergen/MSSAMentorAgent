---
id: 2026-06-01-clean-state-before-concluding
type: decision
description: "When a test fails after partially passing, suspect state pollution before suspecting code — hash-compare round-trip tests only work from a clean baseline"
decided_at: 2026-06-01
---

# Decision: 2026-06-01-clean-state-before-concluding

Produced by `experiment:2026-06-01-state-pollution-red-herring`. Codifies the lesson that emerged from chasing a state-pollution failure as if it were a code bug.

## Chose

When a test fails after passing through earlier stages successfully, suspect **state pollution before code**. Steps:

1. Dump nodes / files in the namespace the failing test touches.
2. Look for orphans from prior debug or test runs.
3. Clean them.
4. Re-run.
5. **Only then** start reading the code under suspicion.

## Over

- Default debugging instinct ("the code I just wrote must be wrong, re-read it line by line"). Sometimes correct, but the order matters: state inspection is faster and more decisive than code reading when the test was working seconds ago.

## Because

Hash-compare round-trip tests are the most expensive assertion we have — they only pass when the entire graph and every touched file is byte-identical to its pre-test state. That makes them maximally informative when they pass and **maximally noisy when they fail from a dirty baseline**. The failure message points at the layer where the conflict manifested (file creation), not the layer that caused it (orphan state from a prior run).

This pattern will recur. Every test that mutates the graph or scaffolds files is vulnerable to the same trap. Codifying it as a decision means future-Jay (and future-Mentor) can route around it instead of re-living it.

## Affects

- Debugging discipline for graph-mutating tests.
- Pending follow-up: extend e2e test harness to assert clean baseline (no orphan nodes matching test prefixes) before running. Tracked as a Phase 1 cleanup task.
- Should generalize to any future test that creates and removes graph entities.

## Revisit if

- We add a transactional graph layer that auto-rolls-back failed tests. At that point the orphan problem disappears at the substrate.
- The clean-state check itself becomes flaky or expensive enough that it's worse than the original problem.
